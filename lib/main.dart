import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import 'brand.dart';
import 'state/app_state.dart';
import 'ui/motion.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

bool get isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();

  // On Android, render a real Flutter startup surface before asynchronous
  // storage/profile initialization. Otherwise a slow or failed init leaves
  // the user staring at a blank screen after the native splash disappears.
  if (Platform.isAndroid) {
    runApp(_AndroidBootstrap(state: state));
    return;
  }

  await state.init();

  if (isDesktop) {
    await windowManager.ensureInitialized();
    // Fixed square window size (800x800) - non-resizable
    const windowSize = Size(800, 800);
    const options = WindowOptions(
      size: windowSize,
      minimumSize: windowSize,
      maximumSize: windowSize,
      center: true,
      title: kAppName,
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    );
    final closeHandler = _CloseHandler(state);
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    await windowManager.setPreventClose(true);
    await windowManager.setResizable(false);
    if (Platform.isWindows) {
      await closeHandler.initializeTray();
    }
    windowManager.addListener(closeHandler);
  }

  runApp(BrewApp(state: state));
}

class _CloseHandler with WindowListener, tray.TrayListener {
  _CloseHandler(this.state);

  final AppState state;
  bool _exiting = false;
  bool _trayReady = false;

  Future<void> initializeTray() async {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      p.join(executableDirectory, 'brew_tray.ico'),
      p.join(executableDirectory, 'resources', 'app_icon.ico'),
      p.join(Directory.current.path, 'windows', 'runner', 'resources', 'app_icon.ico'),
    ];
    String? iconPath;
    for (final path in candidates) {
      if (File(path).existsSync()) {
        iconPath = path;
        break;
      }
    }
    if (iconPath == null) return;

    await tray.trayManager.setIcon(iconPath);
    await tray.trayManager.setToolTip('brew — VPN');
    await tray.trayManager.setContextMenu(
      tray.Menu(
        items: [
          tray.MenuItem(key: 'show_window', label: 'Открыть brew'),
          tray.MenuItem.separator(),
          tray.MenuItem(key: 'exit_app', label: 'Полностью выйти'),
        ],
      ),
    );
    tray.trayManager.addListener(this);
    _trayReady = true;
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.restore();
    await windowManager.focus();
    Motion.setSuspended(false);
  }

  Future<void> _exitApplication() async {
    if (_exiting) return;
    _exiting = true;
    if (_trayReady) {
      tray.trayManager.removeListener(this);
      await tray.trayManager.destroy();
      _trayReady = false;
    }
    Motion.setSuspended(false);
    await state.shutdown();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  Future<void> onWindowClose() async {
    if (_exiting) return;
    if (Platform.isWindows && _trayReady) {
      // Keep the VPN core and connection alive; the tray Exit item performs a
      // full shutdown. Hiding also suspends expensive background UI animation.
      Motion.setSuspended(true);
      await windowManager.hide();
      return;
    }
    await _exitApplication();
  }

  @override
  void onWindowMinimize() {
    Motion.setSuspended(true);
  }

  @override
  void onWindowRestore() {
    Motion.setSuspended(false);
  }

  @override
  void onWindowFocus() {
    Motion.setSuspended(false);
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    tray.trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(tray.MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        _showWindow();
        break;
      case 'exit_app':
        _exitApplication();
        break;
    }
  }
}

class BrewApp extends StatelessWidget {
  const BrewApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            final s = state.settings;
            final seed = s.systemColor
                ? lightDynamic?.primary ?? kBrewOrange
                : s.seedColor;
            ColorScheme scheme(Brightness b) =>
                brewScheme(seed, b, s.schemeVariant);
            return MaterialApp(
              title: kAppName,
              debugShowCheckedModeBanner: false,
              themeMode: s.themeMode,
              theme: buildTheme(scheme(Brightness.light)),
              darkTheme: buildTheme(scheme(Brightness.dark)),
              themeAnimationDuration: const Duration(milliseconds: 200),
              themeAnimationCurve: Curves.easeInOutCubic,
              home: const Shell(),
            );
          },
        ),
      ),
    );
  }
}

class _AndroidBootstrap extends StatefulWidget {
  const _AndroidBootstrap({required this.state});

  final AppState state;

  @override
  State<_AndroidBootstrap> createState() => _AndroidBootstrapState();
}

class _AndroidBootstrapState extends State<_AndroidBootstrap> {
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await widget.state.init();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (error, stack) {
      debugPrint('Brew Android startup failed: $error\\n$stack');
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return BrewApp(state: widget.state);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kBrewOrange,
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _error == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text('Запускаем Brew…'),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 42),
                        const SizedBox(height: 16),
                        const Text(
                          'Не удалось запустить Brew',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          _error.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => setState(() {
                            _error = null;
                            _ready = false;
                            _initialize();
                          }),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
