import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/connect/compiler.dart';
import 'package:onexray/service/connect/mode_servers.dart';
import 'package:onexray/service/connect/resolver.dart';
import 'package:onexray/service/connect/routing/dns.dart';
import 'package:onexray/service/connect/routing/region_catalog.dart';
import 'package:onexray/service/connect/settings.dart';

// 3 APES connection modes: home, protect, abroad and mobile.

final catalog = RegionCatalog.fromJson(
  {
    'geosite': {
      'RU': ['CATEGORY-RU'],
    },
    'geoip': {
      'RU': ['RU'],
    },
  },
  geositeCodes: ['CATEGORY-RU'],
  geoipCodes: ['RU'],
);

RuntimeOptions options() => RuntimeOptions(
  platform: ConnectionPlatform.android,
  sessionDirectory: '/unused-session',
  metricsPort: 18186,
  socksPort: 18187,
  ipv6: true,
  interfaceName: '',
  tunDnsIpv4Address: '8.8.8.8',
  tunDnsIpv6Address: '2001:4860:4860::8888',
);

ResolvedServer node(int id) => ResolvedServer(
  id: id,
  sourceId: 1,
  outbound: {'tag': 'n$id', 'protocol': 'freedom'},
);

CoreConfigData row(int id, String name, {int delay = 50, String? country}) =>
    CoreConfigData(
      id: id,
      name: name,
      type: 'outbound',
      tags: 'vless',
      delay: delay,
      subId: 1,
      countryCode: country,
      favorite: false,
      data: base64Encode(
        utf8.encode(
          jsonEncode({
            'outbounds': [
              {
                'tag': name,
                'protocol': 'socks',
                'settings': {'address': '127.0.0.1', 'port': 1080},
              },
            ],
          }),
        ),
      ),
    );

Map<String, dynamic> compile(ConnectionMode mode) => ConnectionCompiler.compile(
  settings: ConnectionSettings(
    mode: mode,
    smart: SmartRoutingSettings(directRegions: const ['RU']),
  ).effectiveForMode(),
  entries: [node(1)],
  regions: catalog,
  options: options(),
).config;

List<Map<String, dynamic>> rules(Map<String, dynamic> config) =>
    (config['routing']['rules'] as List).cast<Map<String, dynamic>>();

List<Map<String, dynamic>> dnsServers(Map<String, dynamic> config) =>
    (config['dns']['servers'] as List).cast<Map<String, dynamic>>();

void main() {
  group('server names from the provider', () {
    test('whitelist servers are mobile', () {
      for (final name in [
        'Белый список · 🇷🇸 RS · vless · 368ms · 02',
        'Белый список · 🇷🇺 RU · vless · 365ms · 32',
        'LTE·БС · 🇳🇱 NL · vless · 276ms · 03',
        'LTE·БС · ?? · vless · 01',
      ]) {
        expect(ModeServers.isMobile(name), isTrue, reason: name);
      }
      for (final name in [
        'Обычные · 🇷🇺 RU · vless · 1662ms · 65',
        '🇷🇺 Россия (MSK)',
        'Резерв 2',
        'Резерв new',
        'Бельгия 01',
      ]) {
        expect(ModeServers.isMobile(name), isFalse, reason: name);
      }
    });

    test('Russian exit needs an explicit marker, a measured country wins', () {
      // A 🇷🇺 flag marks the entry: "Обычные · 🇷🇺 RU" exits in Belgrade.
      for (final name in [
        'Обычные · 🇷🇺 RU · vless · 1662ms · 65',
        '🇷🇺 Россия (MSK)',
        'Белый список · 🇷🇺 RU · vless · 32',
        'Обычные · 🇳🇱 NL · vless · 7',
        'TRUSTED server',
      ]) {
        expect(ModeServers.isRussian(row(1, name)), isFalse, reason: name);
      }
      for (final name in [
        'Выход РФ · Москва 01',
        'Обычные · выход в России · 02',
        'RU-exit · Moscow',
        'msk ru_exit 3',
      ]) {
        expect(ModeServers.isRussian(row(1, name)), isTrue, reason: name);
      }
      expect(
        ModeServers.isRussian(row(5, 'Выход РФ 24', country: 'NL')),
        isFalse,
      );
      expect(ModeServers.isRussian(row(6, 'Amsterdam', country: 'RU')), isTrue);
    });
  });

  group('settings', () {
    test('mode round-trips; unknown and retired modes mean home', () {
      expect(ConnectionSettings().mode, ConnectionMode.home);
      expect(ConnectionSettings.fromJson({}).mode, ConnectionMode.home);
      for (final name in ['unknown', 'mobile']) {
        expect(
          ConnectionSettings.fromJson({'mode': name}).mode,
          ConnectionMode.home,
        );
      }
      for (final mode in ConnectionMode.values) {
        final json = ConnectionSettings(mode: mode).toJson();
        expect(ConnectionSettings.fromJson(json).mode, mode);
      }
    });

    test('modes never overwrite the stored method', () {
      final stored = ConnectionSettings(
        smart: SmartRoutingSettings(entryCount: 2, directRegions: ['TH']),
      );
      ConnectionSettings with_(ConnectionMode mode) =>
          ConnectionSettings.fromJson({...stored.toJson(), 'mode': mode.name})
              .effectiveForMode();
      final home = with_(ConnectionMode.home);
      expect(home.trafficMode, TrafficMode.smart);
      expect(home.smart.directRegions, containsAll(['RU', 'TH']));
      expect(home.smart.entryCount, 1);
      expect(with_(ConnectionMode.protect).trafficMode, TrafficMode.allVpn);
      final abroad = with_(ConnectionMode.abroad);
      expect(abroad.smart.directRegions, ['RU']);
      expect(stored.smart.directRegions, ['TH']);
      final custom = ConnectionSettings(
        trafficMode: TrafficMode.custom,
        customId: 7,
        mode: ConnectionMode.protect,
      );
      expect(identical(custom.effectiveForMode(), custom), isTrue);
      expect(
        ConnectionSettings(
          expert: true,
          mode: ConnectionMode.protect,
        ).effectiveForMode().trafficMode,
        TrafficMode.smart,
      );
    });

    test('home and protect keep standby servers only for automatic', () {
      for (final mode in [ConnectionMode.home, ConnectionMode.protect]) {
        expect(
          ConnectionSettings(mode: mode).effectiveForMode().usesStandbyPool,
          isTrue,
        );
        expect(
          ConnectionSettings(
            mode: mode,
            selection: const ServerSelection.server(1),
          ).effectiveForMode().usesStandbyPool,
          isFalse,
        );
      }
      expect(
        ConnectionSettings(mode: ConnectionMode.abroad)
            .effectiveForMode()
            .usesStandbyPool,
        isFalse,
      );
    });
  });

  group('routing', () {
    test('home keeps Smart Routing', () {
      final config = compile(ConnectionMode.home);
      expect((config['outbounds'] as List).first['tag'], 'app-entry-0');
      final tags = rules(config).map((rule) => rule['ruleTag']).toList();
      expect(tags, contains('app-smart-direct-domain'));
      expect(tags, isNot(contains('app-abroad-direct')));
      expect(dnsServers(config).first['address'], RoutingDns.defaultAddress);
    });

    test('protect sends everything through the VPN and blocks ads', () {
      final config = compile(ConnectionMode.protect);
      final ads = rules(config)
          .singleWhere((rule) => rule['ruleTag'] == 'app-protect-ads');
      expect(ads['outboundTag'], 'block');
      expect(
        rules(config).where(
          (rule) => rule['outboundTag'] == 'direct' && rule['domain'] != null,
        ),
        isEmpty,
      );
      expect(dnsServers(config).first['address'], RoutingDns.protectAddress);
      expect(config['routing']['domainStrategy'], 'AsIs');
    });

    test('abroad sends Russian sites to the VPN and the rest directly', () {
      final config = compile(ConnectionMode.abroad);
      final byTag = {for (final rule in rules(config)) rule['ruleTag']: rule};
      expect(byTag['app-abroad-ru-domain']!['domain'], ['geosite:CATEGORY-RU']);
      expect(byTag['app-abroad-ru-domain']!['balancerTag'], 'proxy');
      expect(byTag['app-abroad-ru-ip']!['ip'], ['geoip:RU']);
      // Unmatched traffic goes to the default (first) outbound, which must be
      // direct; a catch-all rule would bypass the IP check for Russian sites.
      expect(byTag.containsKey('app-abroad-direct'), isFalse);
      expect(
        rules(config).where(
          (rule) =>
              rule['outboundTag'] == 'direct' &&
              rule['domain'] == null &&
              rule['ip'] == null &&
              rule['inboundTag'] == null,
        ),
        isEmpty,
      );
      expect((config['outbounds'] as List).first['tag'], 'direct');
      expect(config['routing']['domainStrategy'], 'IPIfNonMatch');
      expect(byTag.containsKey('app-smart-direct-domain'), isFalse);
      final servers = dnsServers(config);
      final proxy = servers.singleWhere(
        (server) => server['tag'] == RoutingDns.proxyTag,
      );
      expect(proxy['domains'], ['geosite:CATEGORY-RU']);
      expect(proxy['skipFallback'], isTrue);
      final direct = servers.singleWhere(
        (server) => server['tag'] == RoutingDns.directTag,
      );
      expect(direct['domains'], isNull);
    });
  });

  group('standby servers', () {
    final rows = [
      row(1, 'Обычные · 🇳🇱 NL · vless · 7', delay: 80),
      row(2, 'Белый список · 🇷🇸 RS · vless · 02', delay: 10),
      row(3, 'Выход РФ · Москва 01', delay: 90),
      row(4, 'Белый список · Выход РФ · 32', delay: 5),
      row(5, 'Обычные · 🇩🇪 DE · vless · 8', delay: 30),
      row(6, 'Обычные · 🇫🇮 FI · vless · 9', delay: 40),
      row(7, 'Обычные · 🇵🇱 PL · vless · 10', delay: 50),
      row(8, 'LTE·БС · 🇫🇮 FI · vless · 04', delay: 10000),
      row(9, 'Белый список · 🇧🇬 BG · vless · 03', delay: 70),
      row(10, 'Обычные · 🇺🇸 US · vless · 11', delay: 11000),
    ];

    Future<List<int>> resolve(
      ConnectionMode mode, [
      List<CoreConfigData>? source,
      ServerSelection selection = const ServerSelection.automatic(),
    ]) async {
      final resolver = ConnectionResolver(
        rows: () => Stream.value(source ?? rows),
        probe: (_) async {},
      );
      final settings = ConnectionSettings(
        mode: mode,
        selection: selection,
      ).effectiveForMode();
      return [for (final server in await resolver.resolve(settings)) server.id];
    }

    test('3 fastest live regular, then 3 whitelist even if silent', () async {
      for (final mode in [ConnectionMode.home, ConnectionMode.protect]) {
        expect(await resolve(mode), [5, 6, 7, 4, 2, 9]);
      }
      // Live whitelist servers come before silent ones.
      expect(await resolve(ConnectionMode.home, [rows[0], rows[7], rows[8]]), [
        1,
        9,
        8,
      ]);
    });

    test('only whitelist servers answer: they lead', () async {
      expect(await resolve(ConnectionMode.home, [rows[9], rows[1], rows[7]]), [
        2,
        8,
      ]);
    });

    test('nothing answers: the connection fails', () async {
      await expectLater(
        resolve(ConnectionMode.home, [rows[9], rows[7]]),
        throwsA(isA<ConnectionResolutionException>()),
      );
    });

    test('abroad uses one Russian-exit server', () async {
      expect(await resolve(ConnectionMode.abroad), [3]);
      expect(await resolve(ConnectionMode.abroad, [rows[0], rows[3]]), [4]);
      // A Russian entry is not a Russian exit.
      await expectLater(
        resolve(ConnectionMode.abroad, [
          rows[0],
          row(11, 'Обычные · 🇷🇺 RU · vless · 65'),
        ]),
        throwsA(isA<ConnectionResolutionException>()),
      );
    });

    test('an explicit server is used in any mode', () async {
      expect(
        await resolve(
          ConnectionMode.protect,
          null,
          const ServerSelection.server(2),
        ),
        [2],
      );
    });

    test('Xray checks standby servers and never falls back to direct', () {
      final config = ConnectionCompiler.compile(
        settings: ConnectionSettings(mode: ConnectionMode.protect)
            .effectiveForMode(),
        entries: [node(1), node(2), node(3)],
        regions: catalog,
        options: options(),
      ).config;
      final observatory = config['observatory'] as Map<String, dynamic>;
      expect(observatory['subjectSelector'], [
        'app-entry-0',
        'app-entry-1',
        'app-entry-2',
      ]);
      expect(observatory['probeInterval'], '30m');
      expect(observatory['probeUrl'], ConnectionCompiler.standbyProbeUrl);
      final balancer = (config['routing']['balancers'] as List).single;
      expect(balancer['strategy'], {'type': 'leastPing'});
      expect(balancer['fallbackTag'], 'app-entry-0');
      final dnsOut = (config['outbounds'] as List).singleWhere(
        (outbound) => outbound['tag'] == 'dnsOut',
      );
      expect(jsonEncode(dnsOut), contains('app-entry-0'));
    });

    test('one server keeps the plain configuration', () {
      final config = compile(ConnectionMode.home);
      final balancer = (config['routing']['balancers'] as List).single;
      expect(balancer['strategy'], {'type': 'roundRobin'});
      expect(config['observatory']['probeUrl'], isNull);
    });
  });
}
