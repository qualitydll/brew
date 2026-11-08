import 'dart:io';

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../widgets/common.dart';

class BypassPage extends StatelessWidget {
  const BypassPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isAndroid = Platform.isAndroid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'Обход VPN',
          subtitle: 'Выберите приложения для прямого доступа без VPN',
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

class _AndroidBypassSection extends StatefulWidget {
  const _AndroidBypassSection({required this.state});
  final AppState state;

  @override
  State<_AndroidBypassSection> createState() => _AndroidBypassSectionState();
}

class _AndroidBypassSectionState extends State<_AndroidBypassSection> {
  final List<String> _selectedApps = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedApps.addAll(widget.state.settings.androidBypassApps);
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    // Simulate loading apps - in real implementation this would use
    // platform channel to query Android PackageManager
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
    
    // Show app selector dialog
    if (!mounted) return;
    _showAppSelector();
  }

  void _showAppSelector() {
    final commonApps = [
      'com.android.chrome',
      'com.whatsapp',
      'com.instagram.android',
      'com.facebook.katana',
      'com.twitter.android',
      'com.discord',
      'com.tencent.mm',
      'com.spotify.music',
      'com.netflix.mediaclient',
      'com.youtube',
      'com.google.android.youtube',
      'com.vkontakte.android',
      'com.google.android.gm',
      'com.slack',
      'com.microsoft.teams',
      'com.skype.raider',
      'com.zoom.us',
      'ru.yandex.mail',
      'ru.yandex.disk',
      'ru.yandex.taxi',
      'ru.yandex.metro',
      'ru.yandex.music',
      'ru.yandex.browser',
      'com.sberbankmobile',
      'ru.tinkoff.mobile',
      'ru.tcsbank.mb',
      'com.vkontakte.bdev',
      'ru.ozon.app.android',
      'com.wildberries.ru',
      'com.avito.android',
    ];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Выберите приложения'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ListView.builder(
            itemCount: commonApps.length,
            itemBuilder: (context, index) {
              final app = commonApps[index];
              final isSelected = _selectedApps.contains(app);
              return CheckboxListTile(
                title: Text(_getAppName(app)),
                subtitle: Text(app, style: const TextStyle(fontSize: 11)),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedApps.add(app);
                    } else {
                      _selectedApps.remove(app);
                    }
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              widget.state.setAndroidBypassApps(_selectedApps);
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  String _getAppName(String packageName) {
    final nameMap = {
      'com.android.chrome': 'Chrome',
      'com.whatsapp': 'WhatsApp',
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.twitter.android': 'Twitter',
      'com.discord': 'Discord',
      'com.tencent.mm': 'WeChat',
      'com.spotify.music': 'Spotify',
      'com.netflix.mediaclient': 'Netflix',
      'com.youtube': 'YouTube',
      'com.google.android.youtube': 'YouTube',
      'com.vkontakte.android': 'VK',
      'com.google.android.gm': 'Gmail',
      'com.slack': 'Slack',
      'com.microsoft.teams': 'Microsoft Teams',
      'com.skype.raider': 'Skype',
      'com.zoom.us': 'Zoom',
      'ru.yandex.mail': 'Yandex Mail',
      'ru.yandex.disk': 'Yandex Disk',
      'ru.yandex.taxi': 'Yandex Taxi',
      'ru.yandex.metro': 'Yandex Metro',
      'ru.yandex.music': 'Yandex Music',
      'ru.yandex.browser': 'Yandex Browser',
      'com.sberbankmobile': 'СберБанк',
      'ru.tinkoff.mobile': 'Тинькофф',
      'ru.tcsbank.mb': 'Т-Банк',
      'com.vkontakte.bdev': 'VK Клипы',
      'ru.ozon.app.android': 'Ozon',
      'com.wildberries.ru': 'Wildberries',
      'com.avito.android': 'Авито',
    };
    return nameMap[packageName] ?? packageName;
  }

  @override
  Widget build(BuildContext context) {
    final bypassApps = widget.state.settings.androidBypassApps;
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
              FilledButton.icon(
                onPressed: _isLoading ? null : _loadApps,
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_rounded),
                label: const Text('Добавить'),
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
                    title: Text(_getAppName(app)),
                    subtitle: Text(app, style: const TextStyle(fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _removeApp(widget.state, app),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _removeApp(AppState state, String app) {
    final apps = state.settings.androidBypassApps.where((a) => a != app).toList();
    state.setAndroidBypassApps(apps);
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
    final commonProcesses = [
      'chrome.exe',
      'firefox.exe',
      'msedge.exe',
      'opera.exe',
      'discord.exe',
      'spotify.exe',
      'telegram.exe',
      'WhatsApp.exe',
      'Skype.exe',
      'Teams.exe',
      'Zoom.exe',
      'Steam.exe',
      'EpicGamesLauncher.exe',
      'Origin.exe',
      'Uplay.exe',
      'Battle.net.exe',
      'vlc.exe',
      'notepad++.exe',
      'code.exe',
      'explorer.exe',
    ];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Выберите процесс'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ListView.builder(
            itemCount: commonProcesses.length,
            itemBuilder: (context, index) {
              final process = commonProcesses[index];
              final isSelected = state.settings.windowsBypassProcesses.contains(process);
              return CheckboxListTile(
                title: Text(process),
                value: isSelected,
                onChanged: (value) {
                  final processes = List<String>.of(state.settings.windowsBypassProcesses);
                  if (value == true) {
                    processes.add(process);
                  } else {
                    processes.remove(process);
                  }
                  state.setWindowsBypassProcesses(processes);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _removeProcess(AppState state, String process) {
    final processes = state.settings.windowsBypassProcesses.where((p) => p != process).toList();
    state.setWindowsBypassProcesses(processes);
  }
}
