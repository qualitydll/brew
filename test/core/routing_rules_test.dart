import 'package:brew/core/link_parser.dart';
import 'package:brew/core/routing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('domain rules are normalized and include subdomains by default', () {
    expect(
      normalizeDomainRule(
        ' Example.COM. ',
        includeSubdomains: true,
        action: 'PROXY',
        allowedActions: const ['PROXY', 'DIRECT', 'REJECT'],
      ),
      'DOMAIN-SUFFIX,example.com,PROXY',
    );
  });

  test('exact-domain rules do not include subdomains', () {
    expect(
      normalizeDomainRule(
        'example.com',
        includeSubdomains: false,
        action: 'DIRECT',
        allowedActions: const ['DIRECT', 'REJECT'],
      ),
      'DOMAIN,example.com,DIRECT',
    );
  });

  test('rejects URLs and actions not present in the profile', () {
    expect(
      () => normalizeDomainRule(
        'https://example.com/path',
        includeSubdomains: true,
        action: 'PROXY',
        allowedActions: const ['DIRECT'],
      ),
      throwsFormatException,
    );
    expect(
      () => normalizeDomainRule(
        'example.com',
        includeSubdomains: true,
        action: 'PROXY',
        allowedActions: const ['DIRECT'],
      ),
      throwsArgumentError,
    );
  });

  test('profile routing actions include available groups', () {
    final subscription = parseSubscription('''
proxies: []
proxy-groups:
  - name: Secure
    type: select
    proxies: [DIRECT]
rules:
  - MATCH,Secure
''');

    expect(
      routingActionsFor(subscription),
      containsAll(['Secure', 'DIRECT', 'REJECT']),
    );
  });

  test('process names are normalized from bare names and full paths', () {
    expect(normalizeProcessName('steam'), 'steam.exe');
    expect(normalizeProcessName('Steam.EXE'), 'Steam.EXE');
    expect(
      normalizeProcessName(r'C:\Games\Steam\steam.exe'),
      'steam.exe',
    );
    expect(normalizeProcessName('C:/Games/Steam/steam.exe'), 'steam.exe');
    expect(() => normalizeProcessName('   '), throwsFormatException);
  });

  test('app rules build a PROCESS-NAME rule and default to bypass', () {
    expect(
      normalizeAppRule(
        'steam.exe',
        action: 'DIRECT',
        allowedActions: const ['DIRECT', 'REJECT', 'PROXY'],
      ),
      'PROCESS-NAME,steam.exe,DIRECT',
    );
    expect(
      () => normalizeAppRule(
        'steam.exe',
        action: 'PROXY',
        allowedActions: const ['DIRECT'],
      ),
      throwsArgumentError,
    );
  });

  test('the process name can be read back from an app rule', () {
    expect(
      processNameFromAppRule('PROCESS-NAME,steam.exe,DIRECT'),
      'steam.exe',
    );
    expect(processNameFromAppRule('DOMAIN-SUFFIX,example.com,DIRECT'), null);
  });
}
