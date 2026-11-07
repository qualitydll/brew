import 'config_builder.dart';
import 'link_parser.dart';

String normalizeDomainRule(
  String input, {
  required bool includeSubdomains,
  required String action,
  required List<String> allowedActions,
}) {
  final raw = input.trim().toLowerCase();
  // A leading dot means a complete DNS suffix/TLD, e.g. ".ru".
  final isZone = raw.startsWith('.');
  final domain = raw
      .replaceFirst(RegExp(r'^\.'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  final labels = domain.split('.');
  final validLabels = labels.isNotEmpty &&
      labels.every(
        (label) =>
            label.length <= 63 &&
            RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label),
      );
  final valid = validLabels &&
      (isZone || labels.length >= 2) &&
      domain.length <= 253;
  if (!valid) {
    throw FormatException(
      'Введите домен (example.com) или доменную зону (.ru) без схемы и пути.',
    );
  }
  if (!allowedActions.contains(action)) {
    throw ArgumentError.value(action, 'action');
  }
  return '${isZone || includeSubdomains ? 'DOMAIN-SUFFIX' : 'DOMAIN'},$domain,$action';
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
