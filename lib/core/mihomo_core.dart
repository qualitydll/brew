import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'mihomo_api.dart';

/// Runs the mihomo binary as a child process.
class MihomoCore {
  Process? _process;
  final _output = <String>[];
  void Function(String line)? onLine;
  void Function(int code)? onExit;

  bool get isRunning => _process != null;

  static String get binaryName => Platform.isWindows ? 'mihomo.exe' : 'mihomo';

  static Future<String?> locate({
    String? customPath,
    required String dataDir,
  }) async {
    final candidates = <String>[
      if (customPath != null && customPath.isNotEmpty) customPath,
      if (Platform.environment['BREW_CORE'] != null)
        Platform.environment['BREW_CORE']!,
      // Check core folder next to executable first (where we bundled mihomo.exe)
      p.join(p.dirname(Platform.resolvedExecutable), 'core', binaryName),
      p.join(p.dirname(Platform.resolvedExecutable), binaryName),
      p.join(dataDir, 'core', binaryName),
      // Also check current directory for development
      p.join(Directory.current.path, 'core', binaryName),
    ];
    // A path existing on disk does not mean the native executable is usable.
    // On Windows, a stale custom path can point at a broken/unsupported
    // mihomo.exe that crashes even for "-v". Probe each candidate and fall
    // back to the next one (notably the bundled core) instead of selecting it
    // solely because the file exists.
    for (final c in candidates) {
      if (!await File(c).exists()) continue;
      try {
        final probe = await Process.run(c, ['-v']).timeout(
          const Duration(seconds: 6),
          onTimeout: () => ProcessResult(-1, -1, '', 'version probe timed out'),
        );
        if (probe.exitCode == 0) return c;
      } catch (_) {
        // Continue to the next candidate if the executable cannot start.
      }
    }
    try {
      final res = await Process.run(Platform.isWindows ? 'where' : 'which', [
        'mihomo',
      ]).timeout(
        const Duration(seconds: 6),
        onTimeout: () => ProcessResult(-1, -1, '', 'path lookup timed out'),
      );
      if (res.exitCode == 0) {
        for (final candidate in (res.stdout as String)
            .split(RegExp(r'[\r\n]+'))
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)) {
          try {
            final probe = await Process.run(candidate, ['-v']).timeout(
              const Duration(seconds: 6),
              onTimeout: () =>
                  ProcessResult(-1, -1, '', 'version probe timed out'),
            );
            if (probe.exitCode == 0) return candidate;
          } catch (_) {
            // Ignore unusable PATH entries and keep looking.
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Validates a config with `mihomo -t`. Returns null when valid, otherwise
  /// the core's error message (e.g. `proxy 3: invalid REALITY public key`).
  static Future<String?> check({
    required String binary,
    required String homeDir,
    required String configPath,
  }) async {
    final res = await Process.run(binary, [
      '-t',
      '-d',
      homeDir,
      '-f',
      configPath,
    ]);
    if (res.exitCode == 0) return null;
    final out = '${res.stdout}\n${res.stderr}'.trim();

    // 0xC0000005 is STATUS_ACCESS_VIOLATION. This is a native process crash,
    // not a normal configuration rejection, and by itself does not prove that
    // Defender or SmartScreen blocked the binary.
    if (Platform.isWindows && res.exitCode == -1073741819) {
      final version = await Process.run(binary, ['-v']).timeout(
        const Duration(seconds: 8),
        onTimeout: () => ProcessResult(-1, -1, '', 'Timed out running mihomo -v'),
      );
      final versionOutput = '${version.stdout}\n${version.stderr}'.trim();
      final versionLine = versionOutput.isEmpty
          ? 'версия не выведена'
          : versionOutput.split('\n').first;
      final versionSummary = version.exitCode == 0
          ? 'Сам бинарный файл запускается: $versionLine. '
          : 'Даже команда mihomo -v не прошла (код ${version.exitCode}); проверьте целостность и совместимость файла ядра. ';
      return 'mihomo.exe аварийно завершился с кодом 0xC0000005 '
          '(нарушение доступа) во время проверки конфигурации. '
          '$versionSummary'
          'Это не обычная ошибка YAML и не доказывает блокировку Defender. '
          'Проверьте, что используется официальный x64 mihomo.exe и повторите '
          'проверку с тем же конфигом на свежем ядре.';
    }

    final msgs = RegExp(r'level=(?:error|fatal) msg="((?:[^"\\\\]|\\\\.)*)"')
        .allMatches(out)
        .map((m) => m.group(1)!)
        .map((message) => message.trim())
        .where((message) => message.isNotEmpty)
        .toList();
    // Some Mihomo builds emit an empty structured message while writing the
    // useful validation reason to another output line. Never hide that reason.
    if (msgs.isNotEmpty) return msgs.last;
    if (out.isNotEmpty) return out;
    return 'Mihomo завершил проверку с кодом ${res.exitCode}, но не вывел причину. '
        'Проверьте вывод команды mihomo -v, путь и целостность файла ядра, '
        'а также запустите проверку конфигурации вручную, чтобы увидеть '
        'полный вывод процесса. Не добавляйте файл в исключения антивируса, '
        'пока не проверите его происхождение.';
  }

  Future<void> start({
    required String binary,
    required String homeDir,
    required String configPath,
    required MihomoApi api,
  }) async {
    await stop();
    _output.clear();
    final proc = await Process.start(binary, [
      '-d',
      homeDir,
      '-f',
      configPath,
    ], workingDirectory: homeDir);
    _process = proc;
    var exited = false;
    int? exitCode;
    void handle(String line) {
      _output.add(line);
      if (_output.length > 50) _output.removeAt(0);
      onLine?.call(line);
    }

    proc.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(handle);
    proc.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(handle);
    unawaited(
      proc.exitCode.then((code) {
        exited = true;
        exitCode = code;
        if (identical(_process, proc)) {
          _process = null;
          onExit?.call(code);
        }
      }),
    );

    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      if (exited) {
        throw CoreStartException(
          'Ядро завершилось с кодом $exitCode',
          _output.join('\n'),
        );
      }
      try {
        await api.version();
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    await stop();
    throw CoreStartException(
      'Ядро не ответило за 15 секунд',
      _output.join('\n'),
    );
  }

  Future<void> stop() async {
    final proc = _process;
    if (proc == null) return;
    _process = null;
    proc.kill();
    try {
      await proc.exitCode.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      proc.kill(ProcessSignal.sigkill);
    }
  }
}

class CoreStartException implements Exception {
  CoreStartException(this.message, this.output);
  final String message;
  final String output;
  @override
  String toString() => output.isEmpty ? message : '$message\n$output';
}

class CoreConfigException implements Exception {
  CoreConfigException(this.message);
  final String message;
  @override
  String toString() => 'Ядро не приняло конфигурацию: $message';
}
