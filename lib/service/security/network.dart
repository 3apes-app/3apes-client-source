import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:onexray/service/security/model.dart';

/// 3 APES: what a public trace service sees for one address family.
class TraceInfo {
  final String ip;
  final String? country;

  const TraceInfo(this.ip, this.country);

  bool get isIPv6 =>
      InternetAddress.tryParse(ip)?.type == InternetAddressType.IPv6;

  /// Parses Cloudflare `cdn-cgi/trace` ("key=value" lines).
  static TraceInfo? parse(String body) {
    final values = <String, String>{};
    for (final line in const LineSplitter().convert(body)) {
      final index = line.indexOf('=');
      if (index <= 0) continue;
      values[line.substring(0, index).trim()] = line
          .substring(index + 1)
          .trim();
    }
    final ip = values['ip'];
    if (ip == null || InternetAddress.tryParse(ip) == null) return null;
    final loc = values['loc']?.toUpperCase();
    final country = loc != null && RegExp(r'^[A-Z]{2}$').hasMatch(loc)
        ? loc
        : null;
    return TraceInfo(ip, country == 'XX' ? null : country);
  }
}

class NetworkSnapshot {
  final bool vpn;
  final TraceInfo? v4;
  final TraceInfo? v6;

  const NetworkSnapshot({required this.vpn, this.v4, this.v6});
}

/// Turns what was seen into verdicts. Pure, so it is easy to test.
List<SecurityItem> evaluateNetwork(NetworkSnapshot s) {
  final v4 = s.v4;
  final v6Raw = s.v6;
  // The IPv6 request was carried by the VPN and left the server over IPv4
  // (Xray dials by domain, the server has no IPv6): no IPv6 leaves the
  // device, and an IPv4 address must not be shown as the IPv6 one.
  if (v6Raw != null && !v6Raw.isIPv6) {
    return [
      ..._ipRow(s.vpn, v4),
      SecurityItem(
        SecurityCheckId.ipv6,
        s.vpn ? SecurityVerdict.ipv6ViaVpn : SecurityVerdict.ipv6Off,
      ),
    ];
  }
  final v6 = v6Raw;
  final ip = _ipRow(s.vpn, v4).single;
  final SecurityItem ipv6;
  if (v6 == null) {
    // Neither family answered: the device is offline or the service is down.
    ipv6 = SecurityItem(
      SecurityCheckId.ipv6,
      v4 == null ? SecurityVerdict.failed : SecurityVerdict.ipv6Off,
    );
  } else {
    final SecurityVerdict verdict;
    if (!s.vpn) {
      verdict = SecurityVerdict.ipv6Direct;
    } else if (v4 == null ||
        (v4.country != null &&
            v6.country != null &&
            v4.country != v6.country)) {
      // IPv6 answers from another country than the VPN's IPv4 (or IPv4
      // through the VPN fails while IPv6 works): IPv6 goes around the tunnel.
      verdict = SecurityVerdict.ipv6Leak;
    } else {
      verdict = SecurityVerdict.ipv6ViaVpn;
    }
    ipv6 = SecurityItem(
      SecurityCheckId.ipv6,
      verdict,
      address: v6.ip,
      country: v6.country,
    );
  }
  return [ip, ipv6];
}

List<SecurityItem> _ipRow(bool vpn, TraceInfo? v4) => [
  v4 == null
      ? const SecurityItem(SecurityCheckId.ip, SecurityVerdict.failed)
      : SecurityItem(
          SecurityCheckId.ip,
          vpn ? SecurityVerdict.ipViaVpn : SecurityVerdict.ipDirect,
          address: v4.ip,
          country: v4.country,
        ),
];

/// Fetches `cdn-cgi/trace` over one address family: the host is resolved
/// here, the connection goes to that address, TLS still checks the host name.
class TraceClient {
  /// Public endpoints for now; swapped for our own service later.
  static const hosts = ['one.one.one.one', 'www.cloudflare.com'];
  static const path = '/cdn-cgi/trace';
  static const timeout = Duration(seconds: 6);

  const TraceClient();

  Future<TraceInfo?> fetch(InternetAddressType family) async {
    for (final host in hosts) {
      try {
        final info = await _fetch(host, family).timeout(timeout);
        if (info != null) return info;
      } catch (_) {
        // Try the next host; a failure here is a result, not an error.
      }
    }
    return null;
  }

  Future<TraceInfo?> _fetch(String host, InternetAddressType family) async {
    final addresses = await InternetAddress.lookup(host, type: family);
    final usable = addresses.where((a) => a.type == family).toList();
    if (usable.isEmpty) return null;
    final client = HttpClient()..connectionTimeout = timeout;
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) =>
        SecureSocket.startConnect(usable.first, 443);
    try {
      final request = await client.getUrl(Uri.https(host, path));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return TraceInfo.parse(body);
    } finally {
      client.close(force: true);
    }
  }
}
