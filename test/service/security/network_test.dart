import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/security/model.dart';
import 'package:onexray/service/security/network.dart';
import 'package:onexray/service/security/service.dart';

// 3 APES security check: IP and IPv6 verdicts.

const nl = TraceInfo('185.10.10.10', 'NL');
const nl6 = TraceInfo('2a01:4f8::1', 'NL');
const th6 = TraceInfo('2405:9800::1', 'TH');

SecurityVerdict verdictOf(List<SecurityItem> items, SecurityCheckId id) =>
    items.firstWhere((i) => i.id == id).verdict;

void main() {
  group('TraceInfo.parse', () {
    test('reads ip and country', () {
      final info = TraceInfo.parse(
        'fl=1\nh=one.one.one.one\nip=185.10.10.10\nts=1\nloc=nl\ncolo=AMS\n',
      )!;
      expect(info.ip, '185.10.10.10');
      expect(info.country, 'NL');
    });

    test('rejects a body without a valid ip', () {
      expect(TraceInfo.parse('<html>blocked</html>'), isNull);
      expect(TraceInfo.parse('ip=not-an-ip\nloc=NL'), isNull);
    });

    test('unknown or malformed country is dropped', () {
      expect(TraceInfo.parse('ip=1.2.3.4\nloc=XX')!.country, isNull);
      expect(TraceInfo.parse('ip=1.2.3.4\nloc=Netherlands')!.country, isNull);
      expect(TraceInfo.parse('ip=2a01:4f8::1')!.country, isNull);
    });
  });

  group('evaluateNetwork', () {
    test('VPN on, no IPv6: all green', () {
      final items = evaluateNetwork(const NetworkSnapshot(vpn: true, v4: nl));
      expect(verdictOf(items, SecurityCheckId.ip), SecurityVerdict.ipViaVpn);
      expect(verdictOf(items, SecurityCheckId.ipv6), SecurityVerdict.ipv6Off);
      expect(items.where((i) => i.isIssue), isEmpty);
    });

    test('VPN on, IPv6 from the same country: through VPN', () {
      final items = evaluateNetwork(
        const NetworkSnapshot(vpn: true, v4: nl, v6: nl6),
      );
      expect(
        verdictOf(items, SecurityCheckId.ipv6),
        SecurityVerdict.ipv6ViaVpn,
      );
    });

    test('VPN on, IPv6 from another country: leak', () {
      final items = evaluateNetwork(
        const NetworkSnapshot(vpn: true, v4: nl, v6: th6),
      );
      final ipv6 = items.firstWhere((i) => i.id == SecurityCheckId.ipv6);
      expect(ipv6.verdict, SecurityVerdict.ipv6Leak);
      expect(ipv6.level, SecurityLevel.danger);
      expect(ipv6.address, th6.ip);
    });

    test('IPv6 request answered over IPv4 by the VPN server: no leak', () {
      final items = evaluateNetwork(
        const NetworkSnapshot(vpn: true, v4: nl, v6: nl),
      );
      final ipv6 = items.firstWhere((i) => i.id == SecurityCheckId.ipv6);
      expect(ipv6.verdict, SecurityVerdict.ipv6ViaVpn);
      expect(ipv6.address, isNull);
      expect(verdictOf(items, SecurityCheckId.ip), SecurityVerdict.ipViaVpn);
    });

    test('VPN on, IPv4 fails but IPv6 works: leak', () {
      final items = evaluateNetwork(const NetworkSnapshot(vpn: true, v6: th6));
      expect(verdictOf(items, SecurityCheckId.ip), SecurityVerdict.failed);
      expect(verdictOf(items, SecurityCheckId.ipv6), SecurityVerdict.ipv6Leak);
    });

    test('VPN off: real address is a warning, IPv6 is info', () {
      final items = evaluateNetwork(
        const NetworkSnapshot(vpn: false, v4: nl, v6: th6),
      );
      expect(verdictOf(items, SecurityCheckId.ip), SecurityVerdict.ipDirect);
      expect(
        verdictOf(items, SecurityCheckId.ipv6),
        SecurityVerdict.ipv6Direct,
      );
      expect(items.where((i) => i.isIssue).length, 1);
    });

    test('nothing answers: both unknown', () {
      final items = evaluateNetwork(const NetworkSnapshot(vpn: true));
      expect(items.every((i) => i.level == SecurityLevel.unknown), isTrue);
    });
  });

  group('SecurityCheckService', () {
    test('asks both address families and the VPN state', () async {
      final asked = <InternetAddressType>[];
      final service = SecurityCheckService(
        vpnActive: () async => true,
        trace: (family) async {
          asked.add(family);
          return family == InternetAddressType.IPv4 ? nl : null;
        },
      );
      final items = await service.run();
      expect(
        asked,
        containsAll([InternetAddressType.IPv4, InternetAddressType.IPv6]),
      );
      expect(verdictOf(items, SecurityCheckId.ip), SecurityVerdict.ipViaVpn);
    });

    test('VPN interface names', () {
      for (final name in ['tun0', 'ppp0', 'ipsec0', 'wg0']) {
        expect(SecurityCheckService.isVpnInterface(name), isTrue, reason: name);
      }
      for (final name in ['wlan0', 'rmnet_data0', 'lo', 'en0']) {
        expect(
          SecurityCheckService.isVpnInterface(name),
          isFalse,
          reason: name,
        );
      }
    });
  });
}
