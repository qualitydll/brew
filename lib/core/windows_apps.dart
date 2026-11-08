import 'dart:convert';
import 'dart:io';

/// A running Windows app, as shown in the app-routing picker.
class WindowsAppEntry {
  const WindowsAppEntry({required this.processName, required this.title});

  /// Executable file name, e.g. `chrome.exe`. This is what Mihomo's
  /// `PROCESS-NAME` rule matches against.
  final String processName;

  /// Window title, shown to the user alongside [processName].
  final String title;
}

/// Lists currently running apps that have a visible window, so the person can
/// pick one for app-based routing without typing its process name by hand.
///
/// Windows-only; returns an empty list on any other platform or on failure
/// (no PowerShell, nothing running with a window, etc).
Future<List<WindowsAppEntry>> listRunningWindowsApps() async {
  if (!Platform.isWindows) return const [];
  try {
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'Get-Process | '
          r'Where-Object { $_.MainWindowTitle -and $_.ProcessName } | '
          r'Select-Object -Property ProcessName, MainWindowTitle -Unique | '
          r'ConvertTo-Json -Compress',
    ]).timeout(const Duration(seconds: 10));
    if (result.exitCode != 0) return const [];
    final out = (result.stdout as String).trim();
    if (out.isEmpty) return const [];
    final decoded = jsonDecode(out);
    // ConvertTo-Json returns a bare object (not a list) when there's only
    // one match, so both shapes have to be handled.
    final items = decoded is List ? decoded : [decoded];
    final seen = <String>{};
    final apps = <WindowsAppEntry>[];
    for (final item in items) {
      if (item is! Map) continue;
      final process = item['ProcessName']?.toString();
      final title = item['MainWindowTitle']?.toString();
      if (process == null || process.isEmpty) continue;
      final exe = '$process.exe';
      if (!seen.add(exe.toLowerCase())) continue;
      apps.add(WindowsAppEntry(processName: exe, title: title ?? process));
    }
    apps.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return apps;
  } catch (_) {
    return const [];
  }
}

/// Opens the native "choose a file" dialog filtered to `.exe` files and
/// returns the chosen executable's file name (not the full path), or null if
/// the person cancelled or the dialog could not be shown.
///
/// Windows-only. Uses PowerShell + WinForms instead of a Flutter plugin, so
/// no extra native build step is needed.
Future<String?> pickWindowsExecutableName() async {
  if (!Platform.isWindows) return null;
  try {
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-STA',
      '-Command',
      r'Add-Type -AssemblyName System.Windows.Forms; '
          r'$f = New-Object System.Windows.Forms.OpenFileDialog; '
          r'$f.Filter = "Executable (*.exe)|*.exe"; '
          r'$f.Title = "Выберите приложение"; '
          r'if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) '
          r'{ Write-Output $f.FileName }',
    ]).timeout(const Duration(minutes: 5));
    if (result.exitCode != 0) return null;
    final path = (result.stdout as String).trim();
    if (path.isEmpty) return null;
    final name = path.replaceAll('/', r'\').split(r'\').last.trim();
    return name.isEmpty ? null : name;
  } catch (_) {
    return null;
  }
}
