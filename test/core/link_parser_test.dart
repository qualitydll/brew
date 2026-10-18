import 'package:brew/core/link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses HyL URI into a local SOCKS proxy and pinned sidecar config', () {
    const pin = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    final parsed = parseSubscription(
      'hyl://my%3Apassword@vpn.example:443?pin=$pin#Home%20HyL',
    );

    expect(parsed.proxyCount, 1);
    final proxy = parsed.proxies.single;
    expect(proxy['type'], 'socks5');
    expect(proxy['name'], 'Home HyL');
    expect(proxy['server'], '127.0.0.1');
    expect(proxy['port'], 10808);
    expect(proxy['_hyl'], {
      'server': 'vpn.example:443',
      'password': 'my:password',
      'sni': 'vpn.example',
      'pin_sha256': pin,
    });
  });

  test('rejects malformed HyL certificate pins', () {
    expect(parseLink('hyl://secret@vpn.example:443?pin=not-a-pin'), isNull);
  });

  test('recognizes provider-only Mihomo YAML without inline proxies', () {
    const yaml = '''
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
rules:
  - MATCH,PROXY
''';

    final parsed = parseSubscription(yaml);

    expect(parsed.clashConfig, isNotNull);
    expect(parsed.clashConfig!['proxy-providers'], isA<Map>());
    expect(parsed.clashConfig!['proxy-groups'], isA<List>());
    expect(parsed.clashConfig!['rules'], ['MATCH,PROXY']);
    expect(parsed.proxyCount, 0);
  });
}
