import 'package:brew/core/link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
