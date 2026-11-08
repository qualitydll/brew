import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../widgets/common.dart';

class BypassPage extends StatelessWidget {
  const BypassPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'Обход VPN',
          subtitle: 'Выберите приложения или процессы для прямого доступа',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            children: [
              if (isAndroid) _AndroidBypassSection(state: state),
              if (!isAndroid) _WindowsBypassSection(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

class _AndroidBypassSection extends StatelessWidget {
  const _AndroidBypassSection({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final bypassApps = state.settings.androidBypassApps;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.android_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Приложения Android',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _showAppSelector(context, state),
                tooltip: 'Добавить приложение',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (bypassApps.isEmpty)
            const Text('Нет приложений для обхода')
          else
            Column(
              children: [
                for (final app in bypassApps)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.apps_rounded),
                    title: Text(app),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _removeApp(state, app),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _showAppSelector(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Добавить приложение'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Имя пакета (например: com.example.app)',
            hintText: 'com.example.app',
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              final apps = [...state.settings.androidBypassApps];
              if (!apps.contains(value)) {
                apps.add(value);
                state.settings.androidBypassApps = apps;
                state.notifyListeners();
              }
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  void _removeApp(AppState state, String app) {
    final apps = state.settings.androidBypassApps.where((a) => a != app).toList();
    state.settings.androidBypassApps = apps;
    state.notifyListeners();
  }
}

class _WindowsBypassSection extends StatelessWidget {
  const _WindowsBypassSection({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final bypassProcesses = state.settings.windowsBypassProcesses;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.computer_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Процессы Windows',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _showProcessSelector(context, state),
                tooltip: 'Добавить процесс',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (bypassProcesses.isEmpty)
            const Text('Нет процессов для обхода')
          else
            Column(
              children: [
                for (final process in bypassProcesses)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.terminal_rounded),
                    title: Text(process),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _removeProcess(state, process),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _showProcessSelector(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Добавить процесс'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Имя процесса (например: chrome.exe)',
            hintText: 'chrome.exe',
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              final processes = [...state.settings.windowsBypassProcesses];
              if (!processes.contains(value)) {
                processes.add(value);
                state.settings.windowsBypassProcesses = processes;
                state.notifyListeners();
              }
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  void _removeProcess(AppState state, String process) {
    final processes = state.settings.windowsBypassProcesses.where((p) => p != process).toList();
    state.settings.windowsBypassProcesses = processes;
    state.notifyListeners();
  }
}
