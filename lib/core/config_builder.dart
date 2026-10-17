import 'dart:io';

import 'link_parser.dart';

const kMainGroup = 'PROXY';
const kAutoGroup = 'AUTO';
const kTestUrl = 'https://cp.cloudflare.com/generate_204';

class CoreOptions {
  const CoreOptions({
    required this.mixedPort,
    required this.apiPort,
    required this.secret,
    required this.mode,
    required this.tun,
    required this.allowLan,
    this.externalTun = false,
    this.userRules = const [],
    this.sniSpoofing = false,
  });

  final int mixedPort;
  final int apiPort;
  final String secret;
  final String mode;
  final bool tun;
  final bool allowLan;
  final bool externalTun;
  final List<String> userRules;

  /// When true, overrides SNI only on supported non-Reality proxy types.
  /// This does not bypass certificate validation; the server must be configured
  /// for the chosen name or the proxy must explicitly permit insecure TLS.
  final bool sniSpoofing;
}

/// Candidate SNI hostnames used by the optional override. Availability varies
/// by operator and none of these names is guaranteed to pass every allowlist.
const _sniWhitelistDomains = [
  'gosuslugi.ru',
  'vk.com',
  'yandex.ru',
  'sberbank.ru',
  'mail.ru',
  'ok.ru',
  'ru.wikipedia.org',
  'russianpost.ru',
  'mvd.ru',
  'fssp.gov.ru',
  'nalog.ru',
  'pfr.gov.ru',
  'gks.ru',
  'rosreestr.gov.ru',
  'rzd.ru',
  'aeroflot.ru',
  'telegram.org',
  'tinkoff.ru',
  'alfa-bank.ru',
  'vtb.ru',
  'ozon.ru',
  'wildberries.ru',
  'avito.ru',
  'lamoda.ru',
];

/// Apply SNI override only to outbound types with a supported SNI field.
/// Reality configurations deliberately keep their original servername: it is
/// part of the Reality handshake and replacing it usually breaks the tunnel.
/// Do not mutate unrelated transport fields or inject global config keys.
Map<String, dynamic> _applyDpiBypassToProxy(
  Map<dynamic, dynamic> proxy,
  String sniDomain,
) {
  final result = <String, dynamic>{
    for (final entry in proxy.entries) entry.key.toString(): entry.value,
  };
  final type = result['type']?.toString().toLowerCase() ?? '';

  // Reality server names are negotiated with the server and cannot be
  // replaced by a generic allowlist hostname.
  if (result.containsKey('reality-opts')) return result;

  switch (type) {
    case 'vless':
    case 'vmess':
      // These protocols need an explicitly enabled TLS layer.
      if (result['tls'] != true) return result;
      result['servername'] = sniDomain;
      result.putIfAbsent('client-fingerprint', () => 'chrome');
      break;
    case 'trojan':
      result['sni'] = sniDomain;
      break;
    case 'hysteria2':
    case 'tuic':
    case 'anytls':
    case 'shadowquic':
      result['sni'] = sniDomain;
      break;
    default:
      // No SNI field for plaintext protocols such as Shadowsocks.
      break;
  }
  return result;
}

const _privateRules = [
  'IP-CIDR,127.0.0.0/8,DIRECT,no-resolve',
  'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
  'IP-CIDR,172.16.0.0/12,DIRECT,no-resolve',
  'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve',
  'IP-CIDR,100.64.0.0/10,DIRECT,no-resolve',
  'DOMAIN-SUFFIX,local,DIRECT',
  'DOMAIN-SUFFIX,lan,DIRECT',
];

/// Builds a minimal but complete config around a list of share-link proxies.
Map<String, dynamic> configFromProxies(List<Map<String, dynamic>> proxies) {
  final names = [for (final p in proxies) p['name'] as String];
  return {
    'proxies': proxies,
    'proxy-groups': [
      {
        'name': kMainGroup,
        'type': 'select',
        'proxies': [kAutoGroup, ...names, 'DIRECT'],
      },
      {
        'name': kAutoGroup,
        'type': 'url-test',
        'proxies': names,
        'url': kTestUrl,
        'interval': 300,
        'tolerance': 50,
        'lazy': true,
      },
    ],
    'rules': [..._privateRules, 'MATCH,$kMainGroup'],
  };
}

Map<String, dynamic> baseConfigFor(ParsedSubscription sub) {
  if (sub.clashConfig != null) {
    return Map<String, dynamic>.from(sub.clashConfig!);
  }
  return configFromProxies(sub.proxies);
}

/// Overrides the parts of the config the launcher owns (ports, API, TUN, DNS).
Map<String, dynamic> applyCoreOptions(
  Map<String, dynamic> base,
  CoreOptions o,
) {
  final cfg = Map<String, dynamic>.from(base);
  for (final key in [
    'port',
    'socks-port',
    'redir-port',
    'tproxy-port',
    'external-ui',
    'external-controller-tls',
  ]) {
    cfg.remove(key);
  }
  cfg['mixed-port'] = o.mixedPort;
  cfg['allow-lan'] = o.allowLan;
  cfg['bind-address'] = '*';
  cfg['mode'] = o.mode;
  // Mihomo's verbose info stream can flood the UI/log pipeline on Windows.
  // Keep Android's existing detail while reducing desktop background work.
  cfg['log-level'] = Platform.isWindows ? 'warning' : 'info';
  cfg['ipv6'] = cfg['ipv6'] ?? true;
  cfg['external-controller'] = '127.0.0.1:${o.apiPort}';
  cfg['secret'] = o.secret;
  cfg['unified-delay'] = true;
  cfg['tcp-concurrent'] = true;
  cfg['find-process-mode'] = 'off';
  cfg['profile'] = {'store-selected': true, 'store-fake-ip': true};

  // Only change supported per-proxy SNI fields. The old implementation also
  // injected a top-level "tls" map (not a Mihomo core option) and unrelated
  // smux/network options, which could make Android config validation fail.
  if (o.sniSpoofing) {
    final proxies = cfg['proxies'];
    if (proxies is List) {
      var domainIndex = 0;
      cfg['proxies'] = [
        for (final proxy in proxies)
          if (proxy is Map)
            _applyDpiBypassToProxy(
              proxy,
              _sniWhitelistDomains[domainIndex++ % _sniWhitelistDomains.length],
            )
          else
            proxy,
      ];
    }
  }

  if (o.userRules.isNotEmpty) {
    // Mihomo uses first-match semantics, so custom rules take precedence.
    final providerRules = cfg['rules'];
    cfg['rules'] = [
      ...o.userRules,
      if (providerRules is List) ...providerRules,
    ];
  }

  if (o.tun) {
    cfg['tun'] = {
      'enable': true,
      'stack': 'mixed',
      'auto-route': true,
      'auto-redirect': false,
      'auto-detect-interface': true,
      'strict-route': true,
      'dns-hijack': ['any:53', 'tcp://any:53'],
    };
  } else {
    cfg['tun'] = {'enable': false};
  }

  if (o.tun || o.externalTun) {
    // Supply DNS defaults only for missing keys. Provider DNS settings (even
    // when the provider explicitly disabled DNS) are otherwise retained.
    final existingDns = cfg['dns'];
    final dns = existingDns is Map
        ? <String, dynamic>{
            for (final entry in existingDns.entries)
              if (entry.key is String) entry.key as String: entry.value,
          }
        : <String, dynamic>{};
    final mergedDns = <String, dynamic>{
      'enable': true,
      'ipv6': true,
      'enhanced-mode': 'fake-ip',
      'fake-ip-range': '198.18.0.1/16',
      'fake-ip-filter': [
        '*.lan',
        '*.local',
        'localhost.ptlogin2.qq.com',
        '+.msftconnecttest.com',
        '+.msftncsi.com',
      ],
      'default-nameserver': ['1.1.1.1', '8.8.8.8'],
      'nameserver': [
        'https://1.1.1.1/dns-query',
        'https://dns.google/dns-query',
      ],
      ...dns,
    };
    // DNS must be active for the Android external TUN path to resolve
    // queries; preserve all other provider-supplied DNS options.
    mergedDns['enable'] = true;
    cfg['dns'] = mergedDns;
  }
  return cfg;
}
