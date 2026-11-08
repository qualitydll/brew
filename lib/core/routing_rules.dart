import 'config_builder.dart';
import 'link_parser.dart';

/// Builds a Mihomo domain rule from user input.
///
/// Besides a full domain (`example.com`), this accepts a bare-zone shortcut
/// such as `.ru`: a leading dot means "match the whole zone", which turns
/// into a single-label `DOMAIN-SUFFIX` rule that matches every domain ending
/// in that zone, subdomains included.
String normalizeDomainRule(
  String input, {
  required bool includeSubdomains,
  required String action,
  required List<String> allowedActions,
}) {
  final trimmed = input.trim().toLowerCase();
  final isZoneShortcut = trimmed.startsWith('.');
  final domain = (isZoneShortcut ? trimmed.substring(1) : trimmed)
      .replaceFirst(RegExp(r'\.$'), '');
  final labels = domain.split('.');
  final minLabels = isZoneShortcut ? 1 : 2;
  final valid = labels.length >= minLabels &&
      labels.every(
        (label) =>
            label.isNotEmpty &&
            label.length <= 63 &&
            RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label),
      ) &&
      domain.length <= 253;
  if (!valid) {
    throw FormatException(
      isZoneShortcut
          ? 'Введите зону одним словом, например .ru.'
          : 'Введите домен без схемы и пути, например example.com, '
                'или зону вида .ru, чтобы обойти её целиком.',
    );
  }
  if (!allowedActions.contains(action)) {
    throw ArgumentError.value(action, 'action');
  }
  // A bare zone only makes sense as a suffix match.
  final useSuffix = includeSubdomains || isZoneShortcut;
  return '${useSuffix ? 'DOMAIN-SUFFIX' : 'DOMAIN'},$domain,$action';
}

/// Normalizes a process name/path for app-based routing (Windows).
///
/// Accepts a bare name (`steam`), a name with extension (`steam.exe`) or a
/// full path pasted from a file picker (`C:\Games\Steam\steam.exe`); the
/// result is always a bare executable file name, which is what Mihomo's
/// `PROCESS-NAME` rule matches on Windows.
String normalizeProcessName(String input) {
  var name = input.trim().replaceAll('/', r'\');
  if (name.isEmpty) {
    throw FormatException('Введите имя процесса, например steam.exe.');
  }
  if (name.contains(r'\')) {
    name = name.substring(name.lastIndexOf(r'\') + 1).trim();
  }
  if (name.isEmpty) {
    throw FormatException('Введите имя процесса, например steam.exe.');
  }
  if (!name.toLowerCase().endsWith('.exe')) {
    name = '$name.exe';
  }
  return name;
}

/// Builds a Mihomo `PROCESS-NAME` rule for app-based routing (Windows).
///
/// [input] is normalized through [normalizeProcessName] first, so a bare
/// name, a name with extension, or a full path all work the same way as
/// they do for a single process name.
String normalizeAppRule(
  String input, {
  required String action,
  required List<String> allowedActions,
}) {
  final name = normalizeProcessName(input);
  if (!allowedActions.contains(action)) {
    throw ArgumentError.value(action, 'action');
  }
  return 'PROCESS-NAME,$name,$action';
}

/// The process name an app rule built by [normalizeAppRule] matches, e.g.
/// `steam.exe` for `PROCESS-NAME,steam.exe,DIRECT`. Returns null if [rule]
/// isn't a `PROCESS-NAME` rule.
String? processNameFromAppRule(String rule) {
  final parts = rule.split(',');
  if (parts.length < 2 || parts[0] != 'PROCESS-NAME') return null;
  return parts[1];
}

List<String> routingActionsFor(ParsedSubscription subscription) {
  final config = baseConfigFor(subscription);
  final groups = config['proxy-groups'];
  final groupNames = <String>[
    if (groups is List)
      for (final group in groups)
        if (group is Map && group['name'] is String)
          (group['name'] as String).trim(),
  ];
  final actions = <String>{
    'DIRECT',
    'REJECT',
    ...groupNames.where((name) => name.isNotEmpty && name != 'GLOBAL'),
  }.toList();
  actions.sort((a, b) {
    if (a == 'DIRECT') return -1;
    if (b == 'DIRECT') return 1;
    if (a == 'REJECT') return -1;
    if (b == 'REJECT') return 1;
    if (a == kMainGroup) return -1;
    if (b == kMainGroup) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  });
  return actions;
}
