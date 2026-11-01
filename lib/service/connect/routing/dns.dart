import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/shared/xray/fake_dns.dart';

abstract final class RoutingDns {
  static const defaultAddress = '8.8.8.8';

  /// 3 APES protect mode: Cloudflare's DNS that refuses known malware sites.
  static const protectAddress = '1.1.1.2';
  static const proxyTag = 'app-dns-proxy';
  static const directTag = 'app-dns-direct';

  /// DNS only knows the queried domain, not the later connection's conditions.
  static List<String> directDomains(Iterable<XrayRoutingRule> rules) => {
    for (final rule in rules)
      if (rule.outboundTag == 'direct' &&
          (rule.ip?.isEmpty ?? true) &&
          rule.port == null &&
          rule.network == null &&
          (rule.protocol?.isEmpty ?? true) &&
          (rule.localOS?.isEmpty ?? true) &&
          (rule.inboundTag?.isEmpty ?? true))
        ...?rule.domain,
  }.toList();

  static XrayDns compile({
    String? directAddress,
    Iterable<String> directDomains = const [],
    bool ipv6 = true,
    bool fakeDns = false,
    String proxyAddress = defaultAddress,
    Iterable<String> proxyDomains = const [],
  }) {
    // 3 APES abroad mode: only the listed domains are resolved through the VPN;
    // the direct server becomes the default for everything else.
    final proxyOnly = proxyDomains.toSet().toList();
    final queryStrategy = ipv6 ? 'UseIP' : 'UseIPv4';
    return XrayDns(
      servers: [
        if (fakeDns)
          XrayDnsServer(
            address: FakeDns.address,
            tag: FakeDns.tag,
            queryStrategy: queryStrategy,
          ),
        XrayDnsServer(
          address: proxyAddress,
          tag: proxyTag,
          domains: proxyOnly.isEmpty ? null : proxyOnly,
          skipFallback: proxyOnly.isEmpty ? null : true,
          queryStrategy: queryStrategy,
        ),
        if (directAddress != null)
          XrayDnsServer(
            address: directAddress,
            tag: directTag,
            domains: proxyOnly.isEmpty ? directDomains.toSet().toList() : null,
            skipFallback: proxyOnly.isEmpty ? true : null,
            queryStrategy: queryStrategy,
          ),
      ],
    );
  }
}
