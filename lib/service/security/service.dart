import 'dart:io';

import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/security/device.dart';
import 'package:onexray/service/security/dns.dart';
import 'package:onexray/service/security/model.dart';
import 'package:onexray/service/security/network.dart';

typedef TraceFetcher = Future<TraceInfo?> Function(InternetAddressType family);

/// 3 APES: runs the security check. Works without a subscription and
/// without VPN; results are not sent anywhere.
class SecurityCheckService {
  final TraceFetcher _trace;
  final Future<bool> Function() _vpnActive;
  final Future<DnsInfo?> Function() _dns;
  final Future<DeviceInfo?> Function() _device;
  final DateTime Function() _now;

  SecurityCheckService({
    TraceFetcher? trace,
    Future<bool> Function()? vpnActive,
    Future<DnsInfo?> Function()? dns,
    Future<DeviceInfo?> Function()? device,
    DateTime Function()? now,
  }) : _trace = trace ?? const TraceClient().fetch,
       _vpnActive = vpnActive ?? defaultVpnActive,
       _dns = dns ?? DnsInfo.read,
       _device = device ?? DeviceInfo.read,
       _now = now ?? DateTime.now;

  Future<List<SecurityItem>> run() async {
    final results = await Future.wait([
      _vpnActive(),
      _trace(InternetAddressType.IPv4),
      _trace(InternetAddressType.IPv6),
      _dns(),
      _device(),
    ]);
    final vpnExpected = results[0] as bool;
    final dns = results[3] as DnsInfo?;
    final dnsItem = evaluateDns(dns, vpnExpected: vpnExpected);
    return [
      ...evaluateNetwork(
        NetworkSnapshot(
          vpn: vpnExpected || dns?.vpn == true,
          v4: results[1] as TraceInfo?,
          v6: results[2] as TraceInfo?,
        ),
      ),
      ?dnsItem,
      ...evaluateDevice(results[4] as DeviceInfo?, now: _now()),
    ];
  }

  /// Our VPN is connected, or any VPN interface is up (another app's VPN
  /// also changes what sites see).
  static Future<bool> defaultVpnActive() async {
    if (ConnectionCoordinator.instance.state.value.phase ==
        ConnectionPhase.connected) {
      return true;
    }
    // iOS and macOS keep system utun/ipsec interfaces up with no VPN at all
    // (iCloud, Wi-Fi calling), so interface names tell nothing there.
    if (AppPlatform.isIOS || AppPlatform.isMacOS) return false;
    try {
      final interfaces = await NetworkInterface.list(includeLinkLocal: true);
      return interfaces.any((i) => isVpnInterface(i.name));
    } catch (_) {
      return false;
    }
  }

  static bool isVpnInterface(String name) {
    final n = name.toLowerCase();
    return n.startsWith('tun') ||
        n.startsWith('ppp') ||
        n.startsWith('ipsec') ||
        n.startsWith('wg');
  }
}
