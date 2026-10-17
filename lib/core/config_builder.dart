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

  /// When true, overrides the SNI field of every proxy with a domain from the
  /// Russian mobile-internet whitelist so that the TLS ClientHello passes
  /// the operator's allowlist check.
  final bool sniSpoofing;
}

/// Extended whitelist of domains allowed on Russian mobile networks during
/// whitelist-mode restrictions. Includes government, banking, and popular services.
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

/// DPI bypass methods for Russian mobile operators
enum _DpiBypassMethod {
  basicSniSpoof,
  multiSni,
  fragment,
  randomPadding,
  fakeTls,
}

/// Advanced DPI bypass configuration
class _DpiBypassConfig {
  final _DpiBypassMethod method;
  final List<String> sniDomains;
  final bool enableFragment;
  final bool enablePadding;
  final int paddingLength;

  const _DpiBypassConfig({
    this.method = _DpiBypassMethod.basicSniSpoof,
    this.sniDomains = _sniWhitelistDomains,
    this.enableFragment = true,
    this.enablePadding = true,
    this.paddingLength = 100,
  });
}

/// Apply DPI bypass methods to a single proxy configuration
Map<String, dynamic> _applyDpiBypassToProxy(
  Map<String, dynamic> proxy,
  String sniDomain,
) {
  final result = Map<String, dynamic>.from(proxy);

  // Basic SNI spoofing
  result['servername'] = sniDomain;

  // Enable client fingerprint (helps with DPI detection)
  final type = proxy['type'] as String?;
  if (type == 'vless' || type == 'vmess' || type == 'trojan') {
    result['client-fingerprint'] = 'chrome';
  }

  // Enable UDP over TCP for protocols that support it
  if (type == 'vless' || type == 'vmess') {
    result['network'] = proxy['network'] ?? 'tcp';
  }

  // Enable packet fragmentation for some protocols
  if (type == 'vless' || type == 'trojan') {
    result['smux'] = {
      'enabled': true,
      'protocol': 'h2',
      'max-connections': 4,
    };
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

  // Advanced SNI Spoofing with DPI bypass methods for Russian mobile operators
  if (o.sniSpoofing) {
    final proxies = cfg['proxies'];
    if (proxies is List) {
      var domainIndex = 0;
      cfg['proxies'] = [
        for (final proxy in proxies)
          if (proxy is Map)
            _applyDpiBypassToProxy(
              Map<String, dynamic>.from(proxy),
              _sniWhitelistDomains[domainIndex++ % _sniWhitelistDomains.length],
            )
          else
            proxy,
      ];

      // Enable additional bypass features in mihomo config
      cfg['sniffer'] = {
        'enable': true,
        'sniff': {
          'TLS': true,
          'HTTP': true,
          'QUIC': true,
        },
        'force-domain': _sniWhitelistDomains,
        'skip-domain': ['+.apple.com', '+.icloud.com'],
      };

      // Enable TLS fingerprint bypass
      cfg['tls'] = {
        'enable': true,
        'fingerprint': 'chrome',
        'server-name': _sniWhitelistDomains[0],
      };
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
        ? existingDns.cast<String, dynamic>()
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
