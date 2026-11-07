import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/system_proxy.dart';
import '../../core/routing_rules.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.settings;
    final sections = <Widget>[
      _Section(
        icon: Icons.palette_rounded,
        title: 'Внешний вид',
        children: [
          _Row(
            title: 'Тема',
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('Авто'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Светлая'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Тёмная'),
                ),
              ],
              selected: {s.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (v) => state.setThemeMode(v.first),
            ),
          ),
          const SizedBox(height: 20),
          Text('Цвет', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Swatch(
                color: null,
                selected: s.systemColor,
                onTap: () => state.setSystemColor(true),
              ),
              for (final c in seedPalette)
                _Swatch(
                  color: c,
                  selected:
                      !s.systemColor && s.seedColor.toARGB32() == c.toARGB32(),
                  onTap: () => state.setSeed(c),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Стиль палитры', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in variantNames.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: s.schemeVariant == e.key,
                  onSelected: (_) => state.setVariant(e.key),
                ),
            ],
          ),
        ],
      ),
      _Section(
        icon: Icons.router_rounded,
        title: 'Подключение',
        children: [
          if (Platform.isAndroid) ...[
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Android VPN'),
              subtitle: Text('Весь трафик проходит через системный VpnService.'),
            ),
            _SniSpoofingTile(state: state),
          ] else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Системный прокси'),
              subtitle: const Text(
                'Браузеры и большинство программ пойдут через brew',
              ),
              value: s.systemProxy,
              onChanged: state.setSystemProxy,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Режим TUN (весь трафик устройства)'),
              subtitle: Text(
                state.isAdmin
                    ? 'Виртуальный сетевой адаптер — работают даже игры и мессенджеры'
                    : 'Требуются права администратора',
              ),
              value: s.tun,
              onChanged: state.setTun,
            ),
            if (s.tun && !state.isAdmin && Platform.isWindows)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    await state.shutdown();
                    if (await Elevation.relaunchAsAdmin()) exit(0);
                  },
                  icon: const Icon(Icons.admin_panel_settings_rounded),
                  label: const Text('Перезапустить от администратора'),
                ),
              ),
          ],
          if (Platform.isAndroid)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apps_rounded),
              title: const Text('Приложения вне VPN'),
              subtitle: Text(
                s.excludedApps.isEmpty
                    ? 'Все приложения используют VPN'
                    : '${s.excludedApps.length} приложений используют прямое подключение',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showAndroidAppPicker(context, state),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Разрешить подключения из локальной сети'),
            value: s.allowLan,
            onChanged: state.setAllowLan,
          ),
        ],
      ),
      _Section(
        icon: Icons.alt_route_rounded,
        title: 'Маршрутизация доменов',
        children: [
          if (Platform.isWindows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.desktop_windows_rounded),
              title: const Text('Маршрутизация приложений Windows'),
              subtitle: Text(
                !s.tun
                    ? 'Включите TUN, чтобы маршрутизировать отдельные программы'
                    : s.appRules.isEmpty
                        ? 'Выбрать запущенные приложения и назначить им маршрут'
                        : '${s.appRules.length} правил PROCESS-NAME',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              enabled: s.tun,
              onTap: () async {
                try {
                  final actions = await state.routingActionsForActiveProfile();
                  if (!context.mounted) return;
                  await _showWindowsAppPicker(context, state, actions);
                } catch (e) {
                  if (context.mounted) showSnack(context, 'Не удалось открыть список: $e');
                }
              },
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Добавить правило'),
            subtitle: Text(
              s.domainRules.isEmpty
                  ? 'Домен или зона (.ru) → VPN, напрямую или блокировать'
                  : '${s.domainRules.length} правил — раньше правил подписки',
            ),
            trailing: const Icon(Icons.add_rounded),
            onTap: () async {
              try {
                final actions = await state.routingActionsForActiveProfile();
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (_) => _DomainRuleDialog(
                    actions: actions,
                    onSave: state.addDomainRule,
                  ),
                );
              } catch (e) {
                if (context.mounted) showSnack(context, 'Не удалось открыть правила: $e');
              }
            },
          ),
          if (s.domainRules.isNotEmpty)
            for (final rule in s.domainRules)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 12),
                leading: const Icon(Icons.language_rounded),
                title: Text(rule),
                trailing: IconButton(
                  tooltip: 'Удалить правило',
                  onPressed: () => state.removeDomainRule(rule),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
        ],
      ),
      if (Platform.isWindows)
        _Section(
          icon: Icons.power_settings_new_rounded,
          title: 'Автозапуск',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Автозапуск при входе в систему'),
              subtitle: const Text('Автоматически запускать приложение при входе в Windows'),
              value: s.autostart,
              onChanged: state.setAutostart,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Запускать свернутым'),
              subtitle: const Text('При автозапуске приложение будет свернуто в трей'),
              value: s.autostartMinimized,
              onChanged: s.autostart ? state.setAutostartMinimized : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Протокол при автозапуске'),
              subtitle: Text(
                s.autostartProtocol == null
                    ? 'Использовать последний выбранный'
                    : s.autostartProtocol!,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: s.autostart
                  ? () async {
                      final protocols = ['rule', 'global', 'direct'];
                      final selected = await showDialog<String>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Выберите протокол'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final p in protocols)
                                ListTile(
                                  title: Text(
                                    p == 'rule'
                                        ? 'Умный режим'
                                        : p == 'global'
                                            ? 'Весь трафик'
                                            : 'Напрямую',
                                  ),
                                  trailing: s.autostartProtocol == p
                                      ? const Icon(Icons.check_rounded)
                                      : null,
                                  onTap: () => Navigator.pop(context, p),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (selected != null) {
                        await state.setAutostartProtocol(selected);
                      }
                    }
                  : null,
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Порт прокси'),
            subtitle: Text('HTTP + SOCKS5 на 127.0.0.1:${s.mixedPort}'),
            trailing: const Icon(Icons.edit_rounded),
            onTap: () async {
              final v = await _prompt(context, 'Порт прокси', '${s.mixedPort}');
              final port = int.tryParse(v ?? '');
              if (port != null && port > 0 && port < 65536) {
                await state.setMixedPort(port);
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Правила вручную · Advanced'),
            subtitle: Text(
              s.userRules.trim().isEmpty
                  ? 'Дополнительные правила Mihomo отключены'
                  : '${s.userRules.split('\n').where((rule) => rule.trim().isNotEmpty).length} '
                        'строк — применяются раньше правил подписки',
            ),
            trailing: const Icon(Icons.edit_rounded),
            onTap: () async {
              final rules = await _promptMultiline(
                context,
                'Расширенные правила Mihomo',
                s.userRules,
              );
              if (rules != null) await state.setUserRules(rules);
            },
          ),
        ],
      ),
      _Section(
        icon: Icons.memory_rounded,
        title: 'Ядро',
        children: [
          if (Platform.isAndroid)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('mihomo ${state.coreVersion ?? ''}'),
              subtitle: const Text('Встроенное ядро, устанавливается вместе с приложением.'),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('mihomo ${state.coreVersion ?? ''}'),
              subtitle: Text(
                state.corePath ??
                    'Не найдено — положите mihomo рядом с программой в папку core',
              ),
              trailing: const Icon(Icons.folder_open_rounded),
              onTap: () async {
                final v = await _prompt(
                  context,
                  'Путь к mihomo',
                  state.corePath ?? '',
                );
                if (v != null) {
                  await state.setCorePath(v.trim().isEmpty ? null : v.trim());
                }
              },
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Папка данных'),
            subtitle: Text(state.dataDir),
            trailing: const Icon(Icons.copy_rounded),
            onTap: () {
              Clipboard.setData(ClipboardData(text: state.dataDir));
              showSnack(context, 'Путь скопирован');
            },
          ),
        ],
      ),
      const _Section(
        icon: Icons.info_rounded,
        title: 'О программе',
        children: [
          Text(
            'brew 0.1.0 — VPN-клиент на базе mihomo с дизайном Material You.',
          ),
        ],
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(title: 'Настройки'),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, i) =>
                StaggeredEntrance(index: i, child: sections[i]),
          ),
        ),
      ],
    );
  }
}



Future<List<String>> _windowsRunningApps() async {
  final result = await Process.run(
    'powershell.exe',
    [
      '-NoProfile',
      '-Command',
      r"Get-Process | Where-Object { $_.Path -and $_.MainWindowHandle -ne 0 } | Select-Object -ExpandProperty ProcessName | Sort-Object -Unique | ConvertTo-Json -Compress",
    ],
  );
  if (result.exitCode != 0) {
    throw StateError((result.stderr as String).trim().isEmpty
        ? 'PowerShell не смог получить список приложений.'
        : (result.stderr as String).trim());
  }
  final output = (result.stdout as String).trim();
  if (output.isEmpty) return const [];
  final decoded = jsonDecode(output);
  final names = decoded is List ? decoded : [decoded];
  return names
      .map((name) => name.toString().trim())
      .where((name) => RegExp(r'^[A-Za-z0-9_. -]+
  final appsFuture = state.androidVpn.installedApps();
  final selected = state.settings.excludedApps.toSet();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Приложения вне VPN'),
        content: SizedBox(
          width: 460,
          height: 520,
          child: FutureBuilder<List<Map<String, String>>>(
            future: appsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Не удалось получить список приложений: ${snapshot.error}');
              }
              final apps = snapshot.data ?? const [];
              if (apps.isEmpty) return const Text('Не найдено приложений с ярлыками запуска.');
              return ListView.builder(
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index];
                  final packageName = app['packageName']!;
                  return CheckboxListTile(
                    value: selected.contains(packageName),
                    title: Text(app['label']!.isEmpty ? packageName : app['label']!),
                    subtitle: Text(packageName),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (checked) => setDialogState(() {
                      if (checked == true) {
                        selected.add(packageName);
                      } else {
                        selected.remove(packageName);
                      }
                    }),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              await state.setExcludedApps(selected.toList());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}

class _DomainRuleDialog extends StatefulWidget {
  const _DomainRuleDialog({
    required this.actions,
    required this.onSave,
  });

  final List<String> actions;
  final Future<void> Function(String rule) onSave;

  @override
  State<_DomainRuleDialog> createState() => _DomainRuleDialogState();
}

class _DomainRuleDialogState extends State<_DomainRuleDialog> {
  final _domain = TextEditingController();
  late String _action = widget.actions.contains('PROXY')
      ? 'PROXY'
      : widget.actions.first;
  bool _includeSubdomains = true;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _domain.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final rule = normalizeDomainRule(
        _domain.text,
        includeSubdomains: _includeSubdomains,
        action: _action,
        allowedActions: widget.actions,
      );
      await widget.onSave(rule);
      if (mounted) Navigator.pop(context);
    } on FormatException catch (e) {
      setState(() => _error = e.message.toString());
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Маршрутизация сайта'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _domain,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Домен',
                hintText: 'example.com',
                helperText: 'Домен или зона вроде .ru; без https:// и пути',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeSubdomains,
              onChanged: (value) =>
                  setState(() => _includeSubdomains = value ?? false),
              title: const Text('Включая поддомены'),
              subtitle: const Text('Например, api.example.com'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _action,
              decoration: const InputDecoration(
                labelText: 'Действие',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final action in widget.actions)
                  DropdownMenuItem(value: action, child: Text(actionLabel(action))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _action = value);
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Добавить'),
        ),
      ],
    );
  }
}

String actionLabel(String action) => switch (action) {
  'DIRECT' => 'Напрямую',
  'REJECT' => 'Блокировать',
  _ => 'Через $action',
};

Future<String?> _prompt(BuildContext context, String title, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: c,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

Future<String?> _promptMultiline(
  BuildContext context,
  String title,
  String initial,
) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: c,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: 'DOMAIN-SUFFIX,example.com,PROXY',
            helperText:
                'Одна Mihomo rule на строку. Они проверяются раньше правил подписки.',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

class _SniSpoofingTile extends StatelessWidget {
  const _SniSpoofingTile({required this.state});
  final AppState state;

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.security_rounded),
        title: const Text('SNI Spoofing'),
        content: const SizedBox(
          width: 400,
          child: Text(
            'Когда мобильный оператор включает белые списки, '
            'он проверяет поле SNI в TLS-запросе — открытое поле, '
            'которое видно до шифрования.\n\n'
            'SNI Spoofing заменяет это поле на домен из белого списка '
            '(например, gosuslugi.ru), поэтому оператор думает, что вы '
            'обращаетесь к разрешённому сайту, и пропускает трафик.\n\n'
            'Реальное соединение при этом идёт к вашему VPN-серверу — '
            'данные зашифрованы и защищены.\n\n'
            'Помогает, если оператор фильтрует только по SNI, '
            'не проверяя IP-адрес назначения.',
            style: TextStyle(height: 1.55),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          const Text('SNI Spoofing'),
          const SizedBox(width: 4),
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Что это?',
            icon: Icon(
              Icons.help_outline_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      subtitle: const Text(
        'Маскирует VPN-трафик под разрешённые сайты при блокировке оператором',
      ),
      value: state.settings.sniSpoofing,
      onChanged: state.setSniSpoofing,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 8,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        child,
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: color == null ? 'Цвет системы' : '',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            width: 48,
            height: 48,
            decoration: ShapeDecoration(
              color: color,
              gradient: color == null
                  ? const SweepGradient(
                      colors: [
                        Color(0xFFEF5350),
                        Color(0xFFFFCA28),
                        Color(0xFF66BB6A),
                        Color(0xFF42A5F5),
                        Color(0xFFAB47BC),
                        Color(0xFFEF5350),
                      ],
                    )
                  : null,
              shape: selected
                  ? const StarBorder(
                      points: 8,
                      innerRadiusRatio: 0.84,
                      pointRounding: 0.6,
                      valleyRounding: 0.4,
                    )
                  : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
              shadows: selected
                  ? [
                      BoxShadow(
                        color: (color ?? scheme.primary).withValues(alpha: 0.4),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey(1),
                      color: Colors.white,
                    )
                  : (color == null
                        ? const Icon(
                            Icons.auto_awesome_rounded,
                            key: ValueKey(2),
                            color: Colors.white,
                            size: 20,
                          )
                        : const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}
).hasMatch(name))
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

Future<void> _showWindowsAppPicker(
  BuildContext context,
  AppState state,
  List<String> actions,
) async {
  final appsFuture = _windowsRunningApps();
  final selected = <String>{};
  String action = actions.contains('DIRECT') ? 'DIRECT' : actions.first;
  for (final rule in state.settings.appRules) {
    final parts = rule.split(',');
    if (parts.length == 3 && parts.first == 'PROCESS-NAME') {
      selected.add(parts[1].replaceFirst(RegExp(r'\.exe
  final appsFuture = state.androidVpn.installedApps();
  final selected = state.settings.excludedApps.toSet();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Приложения вне VPN'),
        content: SizedBox(
          width: 460,
          height: 520,
          child: FutureBuilder<List<Map<String, String>>>(
            future: appsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Не удалось получить список приложений: ${snapshot.error}');
              }
              final apps = snapshot.data ?? const [];
              if (apps.isEmpty) return const Text('Не найдено приложений с ярлыками запуска.');
              return ListView.builder(
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index];
                  final packageName = app['packageName']!;
                  return CheckboxListTile(
                    value: selected.contains(packageName),
                    title: Text(app['label']!.isEmpty ? packageName : app['label']!),
                    subtitle: Text(packageName),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (checked) => setDialogState(() {
                      if (checked == true) {
                        selected.add(packageName);
                      } else {
                        selected.remove(packageName);
                      }
                    }),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              await state.setExcludedApps(selected.toList());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}

class _DomainRuleDialog extends StatefulWidget {
  const _DomainRuleDialog({
    required this.actions,
    required this.onSave,
  });

  final List<String> actions;
  final Future<void> Function(String rule) onSave;

  @override
  State<_DomainRuleDialog> createState() => _DomainRuleDialogState();
}

class _DomainRuleDialogState extends State<_DomainRuleDialog> {
  final _domain = TextEditingController();
  late String _action = widget.actions.contains('PROXY')
      ? 'PROXY'
      : widget.actions.first;
  bool _includeSubdomains = true;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _domain.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final rule = normalizeDomainRule(
        _domain.text,
        includeSubdomains: _includeSubdomains,
        action: _action,
        allowedActions: widget.actions,
      );
      await widget.onSave(rule);
      if (mounted) Navigator.pop(context);
    } on FormatException catch (e) {
      setState(() => _error = e.message.toString());
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Маршрутизация сайта'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _domain,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Домен',
                hintText: 'example.com',
                helperText: 'Домен или зона вроде .ru; без https:// и пути',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeSubdomains,
              onChanged: (value) =>
                  setState(() => _includeSubdomains = value ?? false),
              title: const Text('Включая поддомены'),
              subtitle: const Text('Например, api.example.com'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _action,
              decoration: const InputDecoration(
                labelText: 'Действие',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final action in widget.actions)
                  DropdownMenuItem(value: action, child: Text(actionLabel(action))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _action = value);
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Добавить'),
        ),
      ],
    );
  }
}

String actionLabel(String action) => switch (action) {
  'DIRECT' => 'Напрямую',
  'REJECT' => 'Блокировать',
  _ => 'Через $action',
};

Future<String?> _prompt(BuildContext context, String title, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: c,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

Future<String?> _promptMultiline(
  BuildContext context,
  String title,
  String initial,
) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: c,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: 'DOMAIN-SUFFIX,example.com,PROXY',
            helperText:
                'Одна Mihomo rule на строку. Они проверяются раньше правил подписки.',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

class _SniSpoofingTile extends StatelessWidget {
  const _SniSpoofingTile({required this.state});
  final AppState state;

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.security_rounded),
        title: const Text('SNI Spoofing'),
        content: const SizedBox(
          width: 400,
          child: Text(
            'Когда мобильный оператор включает белые списки, '
            'он проверяет поле SNI в TLS-запросе — открытое поле, '
            'которое видно до шифрования.\n\n'
            'SNI Spoofing заменяет это поле на домен из белого списка '
            '(например, gosuslugi.ru), поэтому оператор думает, что вы '
            'обращаетесь к разрешённому сайту, и пропускает трафик.\n\n'
            'Реальное соединение при этом идёт к вашему VPN-серверу — '
            'данные зашифрованы и защищены.\n\n'
            'Помогает, если оператор фильтрует только по SNI, '
            'не проверяя IP-адрес назначения.',
            style: TextStyle(height: 1.55),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          const Text('SNI Spoofing'),
          const SizedBox(width: 4),
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Что это?',
            icon: Icon(
              Icons.help_outline_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      subtitle: const Text(
        'Маскирует VPN-трафик под разрешённые сайты при блокировке оператором',
      ),
      value: state.settings.sniSpoofing,
      onChanged: state.setSniSpoofing,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 8,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        child,
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: color == null ? 'Цвет системы' : '',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            width: 48,
            height: 48,
            decoration: ShapeDecoration(
              color: color,
              gradient: color == null
                  ? const SweepGradient(
                      colors: [
                        Color(0xFFEF5350),
                        Color(0xFFFFCA28),
                        Color(0xFF66BB6A),
                        Color(0xFF42A5F5),
                        Color(0xFFAB47BC),
                        Color(0xFFEF5350),
                      ],
                    )
                  : null,
              shape: selected
                  ? const StarBorder(
                      points: 8,
                      innerRadiusRatio: 0.84,
                      pointRounding: 0.6,
                      valleyRounding: 0.4,
                    )
                  : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
              shadows: selected
                  ? [
                      BoxShadow(
                        color: (color ?? scheme.primary).withValues(alpha: 0.4),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey(1),
                      color: Colors.white,
                    )
                  : (color == null
                        ? const Icon(
                            Icons.auto_awesome_rounded,
                            key: ValueKey(2),
                            color: Colors.white,
                            size: 20,
                          )
                        : const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}
, caseSensitive: false), ''));
    }
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Приложения Windows'),
        content: SizedBox(
          width: 460,
          height: 520,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: action,
                decoration: const InputDecoration(labelText: 'Маршрут'),
                items: [
                  for (final item in actions)
                    DropdownMenuItem(value: item, child: Text(actionLabel(item))),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => action = value);
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<String>>(
                  future: appsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('Не удалось получить приложения: ${snapshot.error}');
                    }
                    final apps = snapshot.data ?? const [];
                    if (apps.isEmpty) {
                      return const Text('Нет запущенных приложений с видимыми окнами. Запустите нужную программу и откройте этот список снова.');
                    }
                    return ListView(
                      children: [
                        for (final app in apps)
                          CheckboxListTile(
                            value: selected.contains(app),
                            title: Text(app),
                            subtitle: Text('$app.exe'),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (checked) => setDialogState(() {
                              if (checked == true) {
                                selected.add(app);
                              } else {
                                selected.remove(app);
                              }
                            }),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final rules = selected
                  .map((name) => 'PROCESS-NAME,$name.exe,$action')
                  .toList();
              await state.setAppRules(rules);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showAndroidAppPicker(BuildContext context, AppState state) async {
  final appsFuture = state.androidVpn.installedApps();
  final selected = state.settings.excludedApps.toSet();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Приложения вне VPN'),
        content: SizedBox(
          width: 460,
          height: 520,
          child: FutureBuilder<List<Map<String, String>>>(
            future: appsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Не удалось получить список приложений: ${snapshot.error}');
              }
              final apps = snapshot.data ?? const [];
              if (apps.isEmpty) return const Text('Не найдено приложений с ярлыками запуска.');
              return ListView.builder(
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index];
                  final packageName = app['packageName']!;
                  return CheckboxListTile(
                    value: selected.contains(packageName),
                    title: Text(app['label']!.isEmpty ? packageName : app['label']!),
                    subtitle: Text(packageName),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (checked) => setDialogState(() {
                      if (checked == true) {
                        selected.add(packageName);
                      } else {
                        selected.remove(packageName);
                      }
                    }),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              await state.setExcludedApps(selected.toList());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}

class _DomainRuleDialog extends StatefulWidget {
  const _DomainRuleDialog({
    required this.actions,
    required this.onSave,
  });

  final List<String> actions;
  final Future<void> Function(String rule) onSave;

  @override
  State<_DomainRuleDialog> createState() => _DomainRuleDialogState();
}

class _DomainRuleDialogState extends State<_DomainRuleDialog> {
  final _domain = TextEditingController();
  late String _action = widget.actions.contains('PROXY')
      ? 'PROXY'
      : widget.actions.first;
  bool _includeSubdomains = true;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _domain.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final rule = normalizeDomainRule(
        _domain.text,
        includeSubdomains: _includeSubdomains,
        action: _action,
        allowedActions: widget.actions,
      );
      await widget.onSave(rule);
      if (mounted) Navigator.pop(context);
    } on FormatException catch (e) {
      setState(() => _error = e.message.toString());
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Маршрутизация сайта'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _domain,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Домен',
                hintText: 'example.com',
                helperText: 'Домен или зона вроде .ru; без https:// и пути',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeSubdomains,
              onChanged: (value) =>
                  setState(() => _includeSubdomains = value ?? false),
              title: const Text('Включая поддомены'),
              subtitle: const Text('Например, api.example.com'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _action,
              decoration: const InputDecoration(
                labelText: 'Действие',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final action in widget.actions)
                  DropdownMenuItem(value: action, child: Text(actionLabel(action))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _action = value);
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Добавить'),
        ),
      ],
    );
  }
}

String actionLabel(String action) => switch (action) {
  'DIRECT' => 'Напрямую',
  'REJECT' => 'Блокировать',
  _ => 'Через $action',
};

Future<String?> _prompt(BuildContext context, String title, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: c,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

Future<String?> _promptMultiline(
  BuildContext context,
  String title,
  String initial,
) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: c,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: 'DOMAIN-SUFFIX,example.com,PROXY',
            helperText:
                'Одна Mihomo rule на строку. Они проверяются раньше правил подписки.',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

class _SniSpoofingTile extends StatelessWidget {
  const _SniSpoofingTile({required this.state});
  final AppState state;

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.security_rounded),
        title: const Text('SNI Spoofing'),
        content: const SizedBox(
          width: 400,
          child: Text(
            'Когда мобильный оператор включает белые списки, '
            'он проверяет поле SNI в TLS-запросе — открытое поле, '
            'которое видно до шифрования.\n\n'
            'SNI Spoofing заменяет это поле на домен из белого списка '
            '(например, gosuslugi.ru), поэтому оператор думает, что вы '
            'обращаетесь к разрешённому сайту, и пропускает трафик.\n\n'
            'Реальное соединение при этом идёт к вашему VPN-серверу — '
            'данные зашифрованы и защищены.\n\n'
            'Помогает, если оператор фильтрует только по SNI, '
            'не проверяя IP-адрес назначения.',
            style: TextStyle(height: 1.55),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          const Text('SNI Spoofing'),
          const SizedBox(width: 4),
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Что это?',
            icon: Icon(
              Icons.help_outline_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      subtitle: const Text(
        'Маскирует VPN-трафик под разрешённые сайты при блокировке оператором',
      ),
      value: state.settings.sniSpoofing,
      onChanged: state.setSniSpoofing,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 8,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        child,
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: color == null ? 'Цвет системы' : '',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            width: 48,
            height: 48,
            decoration: ShapeDecoration(
              color: color,
              gradient: color == null
                  ? const SweepGradient(
                      colors: [
                        Color(0xFFEF5350),
                        Color(0xFFFFCA28),
                        Color(0xFF66BB6A),
                        Color(0xFF42A5F5),
                        Color(0xFFAB47BC),
                        Color(0xFFEF5350),
                      ],
                    )
                  : null,
              shape: selected
                  ? const StarBorder(
                      points: 8,
                      innerRadiusRatio: 0.84,
                      pointRounding: 0.6,
                      valleyRounding: 0.4,
                    )
                  : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
              shadows: selected
                  ? [
                      BoxShadow(
                        color: (color ?? scheme.primary).withValues(alpha: 0.4),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey(1),
                      color: Colors.white,
                    )
                  : (color == null
                        ? const Icon(
                            Icons.auto_awesome_rounded,
                            key: ValueKey(2),
                            color: Colors.white,
                            size: 20,
                          )
                        : const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}
