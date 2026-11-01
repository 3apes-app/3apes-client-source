import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/security/dns.dart';
import 'package:onexray/service/security/model.dart';
import 'package:onexray/service/security/network.dart';
import 'package:onexray/service/security/service.dart';

// 3 APES security check: DNS verdicts.

void main() {
  group('DnsInfo.fromMap', () {
    test('reads what Android sends', () {
      final info = DnsInfo.fromMap({
        'vpn': false,
        'servers': ['192.168.1.1', '', 7],
        'privateDns': true,
        'privateDnsName': ' dns.google ',
      })!;
      expect(info.vpn, isFalse);
      expect(info.servers, ['192.168.1.1']);
      expect(info.privateDns, isTrue);
      expect(info.privateDnsName, 'dns.google');
    });

    test('anything else is no data', () {
      expect(DnsInfo.fromMap(null), isNull);
      expect(DnsInfo.fromMap('x'), isNull);
      expect(DnsInfo.fromMap(<String, Object?>{})!.vpn, isFalse);
    });
  });

  group('evaluateDns', () {
    test('no data: row hidden', () {
      expect(evaluateDns(null, vpnExpected: true), isNull);
    });

    test('active network is VPN: green', () {
      final item = evaluateDns(
        const DnsInfo(vpn: true, servers: ['8.8.8.8']),
        vpnExpected: true,
      )!;
      expect(item.verdict, SecurityVerdict.dnsViaVpn);
      expect(item.address, isNull);
    });

    test('VPN up but active network is not VPN: leak', () {
      final item = evaluateDns(
        const DnsInfo(vpn: false, servers: ['192.168.1.1', '10.0.0.1']),
        vpnExpected: true,
      )!;
      expect(item.verdict, SecurityVerdict.dnsBypass);
      expect(item.level, SecurityLevel.danger);
      expect(item.address, '192.168.1.1, 10.0.0.1');
    });

    test('no VPN, Private DNS: green with its name', () {
      final item = evaluateDns(
        const DnsInfo(
          vpn: false,
          privateDns: true,
          privateDnsName: 'dns.google',
        ),
        vpnExpected: false,
      )!;
      expect(item.verdict, SecurityVerdict.dnsPrivate);
      expect(item.address, 'dns.google');
    });

    test('no VPN, plain DNS: provider sees requests', () {
      final item = evaluateDns(
        const DnsInfo(vpn: false, servers: ['192.168.1.1']),
        vpnExpected: false,
      )!;
      expect(item.verdict, SecurityVerdict.dnsProvider);
      expect(item.isIssue, isTrue);
      expect(item.address, '192.168.1.1');
    });
  });

  test('service adds the DNS row and treats a VPN network as VPN', () async {
    final service = SecurityCheckService(
      vpnActive: () async => false,
      trace: (_) async => const TraceInfo('185.10.10.10', 'NL'),
      dns: () async => const DnsInfo(vpn: true),
    );
    final items = await service.run();
    expect(items.map((i) => i.id), [
      SecurityCheckId.ip,
      SecurityCheckId.ipv6,
      SecurityCheckId.dns,
    ]);
    expect(items.first.verdict, SecurityVerdict.ipViaVpn);
    expect(items.last.verdict, SecurityVerdict.dnsViaVpn);
  });
}
