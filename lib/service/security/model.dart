/// 3 APES: results of the security check. Everything stays on the device.
enum SecurityCheckId {
  ip,
  ipv6,
  dns,
  screenLock,
  securityPatch,
  osVersion,
  developer,
  installers,
  alwaysOn;

  bool get isDevice => index >= SecurityCheckId.screenLock.index;
}

/// A system screen where the user fixes the item; see AndroidSettings.open.
enum SecurityAction {
  security('security'),
  developer('developer'),
  unknownSources('unknownSources'),
  vpn('vpn');

  final String settings;

  const SecurityAction(this.settings);
}

/// Green, yellow, red; info is neutral, unknown means the check failed.
enum SecurityLevel { ok, warning, danger, info, unknown }

enum SecurityVerdict {
  ipViaVpn(SecurityLevel.ok),
  ipDirect(SecurityLevel.warning),
  ipv6Off(SecurityLevel.ok),
  ipv6ViaVpn(SecurityLevel.ok),
  ipv6Leak(SecurityLevel.danger),
  ipv6Direct(SecurityLevel.info),
  dnsViaVpn(SecurityLevel.ok),
  dnsPrivate(SecurityLevel.ok),
  dnsProvider(SecurityLevel.warning),
  dnsBypass(SecurityLevel.danger),
  lockOn(SecurityLevel.ok),
  lockOff(SecurityLevel.danger, SecurityAction.security),
  patchFresh(SecurityLevel.ok),
  patchOld(SecurityLevel.warning),
  patchVeryOld(SecurityLevel.danger),
  osCurrent(SecurityLevel.ok),
  osPrevious(SecurityLevel.info),
  osOutdated(SecurityLevel.danger),
  developerOff(SecurityLevel.ok),
  developerOn(SecurityLevel.info, SecurityAction.developer),
  developerAdb(SecurityLevel.warning, SecurityAction.developer),
  installersStore(SecurityLevel.ok),
  installersOther(SecurityLevel.warning, SecurityAction.unknownSources),
  alwaysOnFull(SecurityLevel.ok),
  alwaysOnNoBlock(SecurityLevel.warning, SecurityAction.vpn),
  alwaysOnOff(SecurityLevel.info, SecurityAction.vpn),
  failed(SecurityLevel.unknown);

  final SecurityLevel level;
  final SecurityAction? action;

  const SecurityVerdict(this.level, [this.action]);
}

class SecurityItem {
  final SecurityCheckId id;
  final SecurityVerdict verdict;

  /// What was seen, e.g. an IP address or DNS servers. Shown only here.
  final String? address;

  /// ISO country code from the check service, e.g. "NL".
  final String? country;

  const SecurityItem(this.id, this.verdict, {this.address, this.country});

  SecurityLevel get level => verdict.level;

  bool get isIssue =>
      level == SecurityLevel.warning || level == SecurityLevel.danger;
}
