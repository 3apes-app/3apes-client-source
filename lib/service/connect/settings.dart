import 'package:onexray/service/connect/routing/dns.dart';

enum ConnectionPlatform { ios, macos, android, windows, linux }

enum SelectionKind { automatic, region, source, server }

enum TrafficMode { smart, allVpn, custom }

/// 3 APES: the user-facing mode on the phone's main screen, applied on top of
/// the stored traffic method when a connection is prepared; it never
/// overwrites the stored method.
///
/// Home and Protect keep standby servers in one connection (regular and
/// mobile-whitelist ones) and let Xray move traffic to a live one, so moving
/// from Wi-Fi to mobile internet with whitelists needs no switch.
enum ConnectionMode {
  /// Russian sites directly, the rest through the VPN.
  home,

  /// Everything through the VPN, ads blocked, a filtering DNS.
  protect,

  /// For people abroad: Russian sites through servers in Russia, the rest
  /// directly.
  abroad;

  /// Unknown names, including the retired `mobile`, mean [home].
  static ConnectionMode fromName(String? name) =>
      values.where((mode) => mode.name == name).firstOrNull ?? home;
}

class ServerSelection {
  final SelectionKind kind;
  final int? id;
  final String? region;

  const ServerSelection.automatic()
    : kind = SelectionKind.automatic,
      id = null,
      region = null;
  const ServerSelection.server(int this.id)
    : kind = SelectionKind.server,
      region = null;
  const ServerSelection.source(int this.id)
    : kind = SelectionKind.source,
      region = null;
  const ServerSelection.region(String this.region)
    : kind = SelectionKind.region,
      id = null;

  factory ServerSelection.fromJson(Map<String, dynamic> value) {
    final kind = SelectionKind.values.byName(value['kind'] as String);
    return switch (kind) {
      SelectionKind.automatic => const ServerSelection.automatic(),
      SelectionKind.server => ServerSelection.server(value['id'] as int),
      SelectionKind.source => ServerSelection.source(value['id'] as int),
      SelectionKind.region => ServerSelection.region(value['region'] as String),
    };
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    if (id != null) 'id': id,
    if (region != null) 'region': region,
  };
}

class SmartRoutingSettings {
  final int entryCount;
  final int? finalExitId;
  final List<String> directRegions;
  final bool directPrivate;
  final bool directApple;
  final bool directWindows;
  final bool directDns;
  final String directDnsAddress;
  final bool fakeDns;
  final bool fragment;
  final bool blockAds;

  SmartRoutingSettings({
    this.entryCount = 1,
    this.finalExitId,
    Iterable<String> directRegions = const ['CN'],
    this.directPrivate = true,
    this.directApple = true,
    this.directWindows = true,
    this.directDns = true,
    this.directDnsAddress = RoutingDns.defaultAddress,
    this.fakeDns = false,
    this.fragment = false,
    this.blockAds = false,
  }) : directRegions = List.unmodifiable(directRegions) {
    if (entryCount < 1 || entryCount > 3) {
      throw const FormatException('Entry count must be 1–3');
    }
  }

  factory SmartRoutingSettings.fromJson(Map<String, dynamic> value) =>
      SmartRoutingSettings(
        entryCount: value['entryCount'] as int? ?? 1,
        finalExitId: value['finalExitId'] as int?,
        directRegions:
            (value['directRegions'] as List?)?.cast<String>() ?? ['CN'],
        directPrivate: value['directPrivate'] as bool? ?? true,
        directApple: value['directApple'] as bool? ?? true,
        directWindows: value['directWindows'] as bool? ?? true,
        directDns: value['directDns'] as bool? ?? true,
        directDnsAddress:
            value['directDnsAddress'] as String? ?? RoutingDns.defaultAddress,
        fakeDns: value['fakeDns'] as bool? ?? false,
        fragment: value['fragment'] as bool? ?? false,
        blockAds: value['blockAds'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'entryCount': entryCount,
    'finalExitId': finalExitId,
    'directRegions': directRegions,
    'directPrivate': directPrivate,
    'directApple': directApple,
    'directWindows': directWindows,
    'directDns': directDns,
    'directDnsAddress': directDnsAddress,
    'fakeDns': fakeDns,
    'fragment': fragment,
    'blockAds': blockAds,
  };

  String get effectiveDirectDnsAddress =>
      directDns ? directDnsAddress.trim() : RoutingDns.defaultAddress;
}

/// Retains the normal selection while Raw is active. The coordinator stores
/// this value together with tunnel/log settings in one database transaction.
class ConnectionSettings {
  final bool expert;
  final int? rawId;
  final ServerSelection selection;
  final TrafficMode trafficMode;
  final int? customId;
  final SmartRoutingSettings smart;
  final ConnectionMode mode;

  /// Set only by [effectiveForMode] for one connection; never stored.
  final bool _standby;

  ConnectionSettings({
    this.expert = false,
    this.rawId,
    this.selection = const ServerSelection.automatic(),
    this.trafficMode = TrafficMode.smart,
    this.customId,
    SmartRoutingSettings? smart,
    this.mode = ConnectionMode.home,
  }) : smart = smart ?? SmartRoutingSettings(),
       _standby = false;

  ConnectionSettings._standby(ConnectionSettings source)
    : expert = source.expert,
      rawId = source.rawId,
      selection = source.selection,
      trafficMode = source.trafficMode,
      customId = source.customId,
      smart = source.smart,
      mode = source.mode,
      _standby = true;

  factory ConnectionSettings.fromJson(Map<String, dynamic> value) =>
      ConnectionSettings(
        expert: value['expert'] as bool? ?? false,
        rawId: value['rawId'] as int?,
        selection: ServerSelection.fromJson(
          value['selection'] as Map<String, dynamic>? ?? {'kind': 'automatic'},
        ),
        trafficMode: TrafficMode.values.byName(
          value['trafficMode'] as String? ?? 'smart',
        ),
        customId: value['customId'] as int?,
        smart: SmartRoutingSettings.fromJson(
          value['smart'] as Map<String, dynamic>? ?? {},
        ),
        mode: ConnectionMode.fromName(value['mode'] as String?),
      );

  Map<String, dynamic> toJson() => {
    'expert': expert,
    'rawId': rawId,
    'selection': selection.toJson(),
    'trafficMode': trafficMode.name,
    'customId': customId,
    'smart': smart.toJson(),
    'mode': mode.name,
  };

  /// The settings a connection actually uses for [mode]. Raw configurations
  /// and custom routes are returned unchanged.
  ConnectionSettings effectiveForMode() {
    if (expert || trafficMode == TrafficMode.custom) return this;
    final json = toJson();
    final effective = switch (mode) {
      // Russia is always direct; other chosen regions stay direct too.
      ConnectionMode.home => ConnectionSettings.fromJson({
        ...json,
        'trafficMode': TrafficMode.smart.name,
        'smart': {
          ...smart.toJson(),
          'finalExitId': null,
          'entryCount': 1,
          'directRegions': {'RU', ...smart.directRegions}.toList(),
        },
      }),
      ConnectionMode.protect => ConnectionSettings.fromJson({
        ...json,
        'trafficMode': TrafficMode.allVpn.name,
        'smart': {...smart.toJson(), 'finalExitId': null, 'entryCount': 1},
      }),
      ConnectionMode.abroad => ConnectionSettings.fromJson({
        ...json,
        'trafficMode': TrafficMode.smart.name,
        'smart': {
          ...smart.toJson(),
          'finalExitId': null,
          'entryCount': 1,
          'directRegions': ['RU'],
        },
      }),
    };
    return effective.mode == ConnectionMode.abroad
        ? effective
        : ConnectionSettings._standby(effective);
  }

  /// 3 APES: automatic selection in Home or Protect connects to several
  /// standby servers at once; Xray picks a live one (see the compiler).
  bool get usesStandbyPool =>
      _standby &&
      !expert &&
      selection.kind == SelectionKind.automatic &&
      trafficMode != TrafficMode.custom &&
      (mode == ConnectionMode.home || mode == ConnectionMode.protect);

  /// At most this many regular and this many mobile-whitelist standby servers.
  static const standbyPerGroup = 3;

  int requiredEntries({int? customEntryCount}) {
    if (expert) return 0;
    if (usesStandbyPool) return 1;
    if (selection.kind == SelectionKind.server ||
        trafficMode == TrafficMode.allVpn) {
      return 1;
    }
    return switch (trafficMode) {
      TrafficMode.smart => smart.entryCount,
      TrafficMode.allVpn => 1,
      TrafficMode.custom =>
        customEntryCount ?? (throw StateError('Custom route is required')),
    };
  }

  int? get finalExitId =>
      !expert && trafficMode == TrafficMode.smart ? smart.finalExitId : null;
}
