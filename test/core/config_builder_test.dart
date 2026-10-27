import 'package:brew/core/config_builder.dart';
import 'package:brew/core/link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VLESS CDN XHTTP GET preserves full XHTTP transport settings', () {
    const link = 'vless://00000000-0000-4000-8000-000000000001@cdn.example:443'
        '?security=tls&sni=cdn.example&type=xhttp&host=cdn.example'
        '&path=%2Fupload&alpn=h2%2Chttp%2F1.1'
        '&extra=%7B%22mode%22%3A%22packet-up%22%2C%22uplinkHTTPMethod%22%3A%22GET%22%2C%22uplinkDataPlacement%22%3A%22header%22%2C%22uplinkDataKey%22%3A%22X-Playback-Token%22%2C%22uplinkChunkSize%22%3A%2264-128%22%2C%22sessionIDPlacement%22%3A%22cookie%22%2C%22sessionIDKey%22%3A%22media_sid%22%2C%22seqPlacement%22%3A%22query%22%2C%22seqKey%22%3A%22offset%22%2C%22xPaddingObfsMode%22%3Atrue%2C%22xPaddingPlacement%22%3A%22queryInHeader%22%2C%22xPaddingKey%22%3A%22_dc%22%2C%22xPaddingHeader%22%3A%22X-Cache%22%2C%22xPaddingMethod%22%3A%22tokenish%22%2C%22scMaxEachPostBytes%22%3A%22131072-262144%22%2C%22scMinPostsIntervalMs%22%3A%225-10%22%2C%22headers%22%3A%7B%22X-Forwarded-For%22%3A%22%22%7D%7D'
        '#CDN-XHTTP-GET';

    final proxy = parseSubscription(link).proxies.single;
    expect(proxy['type'], 'vless');
    expect(proxy['network'], 'xhttp');
    expect(proxy['xhttp-opts'], {
      'path': '/upload',
      'host': 'cdn.example',
      'mode': 'packet-up',
      'uplink-http-method': 'GET',
      'uplink-data-placement': 'header',
      'uplink-data-key': 'X-Playback-Token',
      'uplink-chunk-size': 64,
      'session-placement': 'cookie',
      'session-key': 'media_sid',
      'seq-placement': 'query',
      'seq-key': 'offset',
      'x-padding-obfs-mode': true,
      'x-padding-placement': 'queryInHeader',
      'x-padding-key': '_dc',
      'x-padding-header': 'X-Cache',
      'x-padding-method': 'tokenish',
      'sc-max-each-post-bytes': '131072-262144',
      'sc-min-posts-interval-ms': '5-10',
      'headers': {'X-Forwarded-For': ''},
    });
  });

  test('Android external TUN keeps Mihomo TUN disabled and enables DNS', () {
    final config = applyCoreOptions(
      const <String, dynamic>{},
      const CoreOptions(
        mixedPort: 7890,
        apiPort: 9097,
        secret: 'test-secret',
        mode: 'rule',
        tun: false,
        allowLan: false,
        externalTun: true,
      ),
    );

    expect(config['tun'], {'enable': false});
    expect(config['dns'], isA<Map<String, dynamic>>());
    expect((config['dns'] as Map<String, dynamic>)['enable'], isTrue);
  });

  test('Mihomo provider rules survive subscription parsing and config setup', () {
    const subscription = '''
mixed-port: 7890
proxy-providers:
  locations:
    type: http
    url: https://example.org/locations.yaml
    path: ./providers/locations.yaml
    interval: 3600
proxy-groups:
  - name: PROXY
    type: select
    use:
      - locations
rule-providers:
  ads:
    type: http
    behavior: domain
    url: https://example.org/ads.yaml
    path: ./rules/ads.yaml
    interval: 3600
rules:
  - DOMAIN-SUFFIX,example.org,DIRECT
  - RULE-SET,ads,REJECT
  - MATCH,PROXY
''';

    final parsed = parseSubscription(subscription);
    expect(parsed.clashConfig, isNotNull);

    final config = applyCoreOptions(
      baseConfigFor(parsed),
      const CoreOptions(
        mixedPort: 7890,
        apiPort: 9097,
        secret: 'test-secret',
        mode: 'rule',
        tun: false,
        allowLan: false,
        externalTun: true,
      ),
    );

    expect(config['rules'], [
      'DOMAIN-SUFFIX,example.org,DIRECT',
      'RULE-SET,ads,REJECT',
      'MATCH,PROXY',
    ]);
    expect(
      ((config['proxy-providers'] as Map)['locations'] as Map)['url'],
      'https://example.org/locations.yaml',
    );
    expect(
      ((config['rule-providers'] as Map)['ads'] as Map)['url'],
      'https://example.org/ads.yaml',
    );
  });

  test('user rules precede subscription rules without replacing them', () {
    final config = applyCoreOptions(
      const {
        'rules': [
          'DOMAIN-SUFFIX,provider.example,DIRECT',
          'MATCH,PROXY',
        ],
      },
      const CoreOptions(
        mixedPort: 7890,
        apiPort: 9097,
        secret: 'test-secret',
        mode: 'rule',
        tun: false,
        allowLan: false,
        userRules: [
          'DOMAIN-SUFFIX,custom.example,PROXY',
          'IP-CIDR,203.0.113.0/24,DIRECT,no-resolve',
        ],
      ),
    );

    expect(config['rules'], [
      'DOMAIN-SUFFIX,custom.example,PROXY',
      'IP-CIDR,203.0.113.0/24,DIRECT,no-resolve',
      'DOMAIN-SUFFIX,provider.example,DIRECT',
      'MATCH,PROXY',
    ]);
  });

  test('VLESS URI preserves PQ encryption, packet encoding, Reality and Vision', () {
    const link = 'vless://00000000-0000-4000-8000-000000000001@node.example:443'
        '?encryption=mlkem768x25519plus.native%2Fxorpub%2Frandom.1rtt'
        '&security=reality&pbk=public-key-placeholder&sid=abcd1234'
        '&sni=example.org&fp=chrome&flow=xtls-rprx-vision'
        '&packet-encoding=xudp&type=tcp#pq-test';

    final parsed = parseSubscription(link);
    expect(parsed.proxyCount, 1);
    final proxy = parsed.proxies.single;
    expect(proxy['type'], 'vless');
    expect(proxy['flow'], 'xtls-rprx-vision');
    expect(proxy['encryption'], 'mlkem768x25519plus.native/xorpub/random.1rtt');
    expect(proxy['packet-encoding'], 'xudp');
    expect(proxy['client-fingerprint'], 'chrome');
    expect(proxy['servername'], 'example.org');
    expect(proxy['reality-opts'], {
      'public-key': 'public-key-placeholder',
      'short-id': 'abcd1234',
    });
  });

  test('AnyTLS URI preserves SNI, ALPN, fingerprint and verification setting', () {
    const link = 'anytls://test-password@node.example:443'
        '?sni=example.org&alpn=h2%2Chttp%2F1.1&fp=chrome&insecure=0#anytls-test';

    final parsed = parseSubscription(link);
    expect(parsed.proxyCount, 1);
    final proxy = parsed.proxies.single;
    expect(proxy['type'], 'anytls');
    expect(proxy['password'], 'test-password');
    expect(proxy['sni'], 'example.org');
    expect(proxy['alpn'], ['h2', 'http/1.1']);
    expect(proxy['client-fingerprint'], 'chrome');
    expect(proxy.containsKey('skip-cert-verify'), isFalse);
  });

  test('VLESS XHTTP preserves the transport mode', () {
    const link = 'vless://00000000-0000-4000-8000-000000000001@node.example:443'
        '?security=tls&sni=example.org&type=xhttp&path=%2Fedge&mode=auto#xhttp-test';

    final proxy = parseSubscription(link).proxies.single;
    expect(proxy['network'], 'xhttp');
    expect(proxy['xhttp-opts'], {'path': '/edge', 'mode': 'auto'});
  });

  test('VLESS XHTTP CDN extras are preserved in Mihomo xhttp-opts', () {
    const link = 'vless://00000000-0000-4000-8000-000000000001@cdn.example:443'
        '?security=tls&sni=example.org&type=xhttp&host=cdn.example'
        '&path=%2Fedge&mode=stream-one'
        '&extra=%7B%22xPaddingBytes%22%3A%22100-1000%22%2C%22uplinkHTTPMethod%22%3A%22POST%22%2C%22headers%22%3A%7B%22X-Test%22%3A%22cdn%22%7D%7D'
        '#cdn-xhttp-get';

    final proxy = parseSubscription(link).proxies.single;
    expect(proxy['network'], 'xhttp');
    expect(proxy['xhttp-opts'], {
      'path': '/edge',
      'host': 'cdn.example',
      'mode': 'stream-one',
      'x-padding-bytes': '100-1000',
      'uplink-http-method': 'POST',
      'headers': {'X-Test': 'cdn'},
    });
  });

  test('Android TUN enables DNS while preserving provider DNS options', () {
    final config = applyCoreOptions(
      const {
        'dns': {
          'enable': false,
          'nameserver': ['https://dns.example/dns-query'],
          'fallback': ['1.1.1.1'],
          'respect-rules': true,
        },
      },
      const CoreOptions(
        mixedPort: 7890,
        apiPort: 9097,
        secret: 'test-secret',
        mode: 'rule',
        tun: false,
        allowLan: false,
        externalTun: true,
      ),
    );

    expect(config['dns'], {
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
      'nameserver': ['https://dns.example/dns-query'],
      'fallback': ['1.1.1.1'],
      'respect-rules': true,
    });
  });


  test('SNI spoofing is disabled by default and preserves original SNI', () {
    const original = <String, dynamic>{
      'proxies': [
        {'name': 'TLS server', 'type': 'trojan', 'server': 'node.example', 'servername': 'real.example'},
      ],
    };
    final config = applyCoreOptions(
      original,
      const CoreOptions(
        mixedPort: 7890,
        apiPort: 9097,
        secret: 'test-secret',
        mode: 'rule',
        tun: false,
        allowLan: false,
      ),
    );

    expect(config['proxies'], original['proxies']);
    expect(
      ((config['proxies'] as List).single as Map)['servername'],
      'real.example',
    );
  });

}
