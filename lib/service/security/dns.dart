import 'package:flutter/services.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/security/model.dart';

/// 3 APES: DNS of the active network as Android reports it.
class DnsInfo {
  /// The active network is a VPN (ours or another app's).
  final bool vpn;
  final List<String> servers;

  /// Android "Private DNS" (DNS over TLS) is in use.
  final bool privateDns;
  final String? privateDnsName;

  const DnsInfo({
    required this.vpn,
    this.servers = const [],
    this.privateDns = false,
    this.privateDnsName,
  });

  static DnsInfo? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final servers = raw['servers'];
    final name = raw['privateDnsName'];
    return DnsInfo(
      vpn: raw['vpn'] == true,
      servers: servers is List
          ? servers.whereType<String>().where((s) => s.isNotEmpty).toList()
          : const [],
      privateDns: raw['privateDns'] == true,
      privateDnsName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : null,
    );
  }

  static const _channel = MethodChannel('app.threeapes.client/device');

  /// Null off Android or when Android does not answer.
  static Future<DnsInfo?> read() async {
    if (!AppPlatform.isAndroid) return null;
    try {
      return fromMap(await _channel.invokeMethod<Object?>('networkDns'));
    } catch (_) {
      return null;
    }
  }
}

/// [vpnExpected]: our VPN is connected or a VPN interface is up.
/// Returns null when the platform has no DNS data (the row is hidden).
SecurityItem? evaluateDns(DnsInfo? info, {required bool vpnExpected}) {
  if (info == null) return null;
  if (info.vpn) {
    return const SecurityItem(SecurityCheckId.dns, SecurityVerdict.dnsViaVpn);
  }
  if (vpnExpected) {
    // VPN is up, but Android sends traffic, DNS included, past it.
    return SecurityItem(
      SecurityCheckId.dns,
      SecurityVerdict.dnsBypass,
      address: _servers(info),
    );
  }
  if (info.privateDns) {
    return SecurityItem(
      SecurityCheckId.dns,
      SecurityVerdict.dnsPrivate,
      address: info.privateDnsName,
    );
  }
  return SecurityItem(
    SecurityCheckId.dns,
    SecurityVerdict.dnsProvider,
    address: _servers(info),
  );
}

String? _servers(DnsInfo info) =>
    info.servers.isEmpty ? null : info.servers.join(', ');
