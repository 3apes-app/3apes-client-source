import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/servers/outbound/state_db.dart';
import 'package:onexray/service/servers/subscription/model.dart';
import 'package:onexray/service/servers/subscription/provider_info.dart';
import 'package:onexray/service/servers/subscription/service.dart';
import 'package:onexray/service/shared/event_bus/service.dart';

const _main = 'https://sub.old.example/token';
const _reserve = 'https://reserve.example/token';
const _next = 'https://sub.new.example/token';

SubscriptionLoadResult _ok(String tag, {SubscriptionProviderInfo? info}) =>
    SubscriptionLoadResult(
      status: SubscriptionUpdateResult.success,
      rows: [
        outboundCompanion({'protocol': 'socks', 'tag': tag}),
      ],
      providerInfo: info ?? const SubscriptionProviderInfo(),
    );

const _failed = SubscriptionLoadResult(
  status: SubscriptionUpdateResult.downloadFailed,
);

void main() {
  late AppDatabase database;
  late Map<String, SubscriptionLoadResult> answers;
  late List<String> requested;
  late SubscriptionService subscriptions;

  setUp(() {
    final bus = AppEventBus();
    addTearDown(bus.close);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    answers = {};
    requested = [];
    subscriptions = SubscriptionService.forTesting(
      database: database,
      loadRows: (input) async {
        requested.add(input.url);
        return answers[input.url] ?? _failed;
      },
      schedulePing: (_) {},
      readReferences: () => const SubscriptionNodeReferences(),
    );
  });

  Future<int> addSubscription({String? fallback}) async {
    answers[_main] = _ok(
      'first',
      info: SubscriptionProviderInfo(fallbackUrl: fallback),
    );
    final result = await subscriptions.insertSubscription(
      const SubscriptionInput(name: 'Provider', url: _main),
    );
    requested.clear();
    return result.subId;
  }

  Future<SubscriptionData> refresh(int id) async {
    final row = (await database.subscriptionDao.searchRow(id))!;
    await subscriptions.refreshSubscriptionResult(row);
    return (await database.subscriptionDao.searchRow(id))!;
  }

  Future<List<String>> tags(int id) async => [
    for (final row
        in await database.coreConfigDao.allOutboundRowsWithDataBySubId(id))
      row.name,
  ];

  test('insert stores the fallback address', () async {
    final id = await addSubscription(fallback: _reserve);
    final row = (await database.subscriptionDao.searchRow(id))!;
    expect(row.fallbackUrl, _reserve);
  });

  test('a failed main address falls back and keeps the link', () async {
    final id = await addSubscription(fallback: _reserve);
    answers[_main] = _failed;
    answers[_reserve] = _ok('from reserve');
    final row = await refresh(id);
    expect(requested, [_main, _reserve]);
    expect(row.url, _main);
    expect(row.fallbackUrl, _reserve);
    expect(await tags(id), ['from reserve']);
  });

  test('a block page on the main address also falls back', () async {
    final id = await addSubscription(fallback: _reserve);
    answers[_main] = const SubscriptionLoadResult(
      status: SubscriptionUpdateResult.invalidContent,
    );
    answers[_reserve] = _ok('from reserve');
    await refresh(id);
    expect(requested, [_main, _reserve]);
    expect(await tags(id), ['from reserve']);
  });

  test('device ID refusals never go to the reserve address', () async {
    final id = await addSubscription(fallback: _reserve);
    answers[_main] = const SubscriptionLoadResult(
      status: SubscriptionUpdateResult.hwidLimitReached,
    );
    answers[_reserve] = _ok('from reserve');
    await refresh(id);
    expect(requested, [_main]);
    expect(await tags(id), ['first']);
  });

  test('new-url moves the subscription when the new address works', () async {
    final id = await addSubscription();
    answers[_main] = _ok(
      'old',
      info: const SubscriptionProviderInfo(newUrl: _next),
    );
    answers[_next] = _ok(
      'new',
      info: const SubscriptionProviderInfo(fallbackUrl: _reserve),
    );
    final row = await refresh(id);
    expect(requested, [_main, _next]);
    expect(row.url, _next);
    expect(row.fallbackUrl, _reserve);
    expect(await tags(id), ['new']);
  });

  test('a broken new-url keeps the old address and its nodes', () async {
    final id = await addSubscription();
    answers[_main] = _ok(
      'old',
      info: const SubscriptionProviderInfo(newUrl: _next),
    );
    final row = await refresh(id);
    expect(requested, [_main, _next]);
    expect(row.url, _main);
    expect(await tags(id), ['old']);
  });

  test('new-url to an address already added is skipped', () async {
    final id = await addSubscription();
    await database.subscriptionDao.insertRow(
      SubscriptionCompanion.insert(
        name: 'Other',
        url: _next,
        timestamp: DateTime(2026),
      ),
    );
    answers[_main] = _ok(
      'old',
      info: const SubscriptionProviderInfo(newUrl: _next),
    );
    final row = await refresh(id);
    expect(requested, [_main]);
    expect(row.url, _main);
  });

  test('only one move per refresh', () async {
    final id = await addSubscription();
    answers[_main] = _ok(
      'old',
      info: const SubscriptionProviderInfo(newUrl: _next),
    );
    answers[_next] = _ok(
      'new',
      info: const SubscriptionProviderInfo(newUrl: _main),
    );
    final row = await refresh(id);
    expect(requested, [_main, _next]);
    expect(row.url, _next);
  });

  test('a missing fallback header keeps the saved reserve', () async {
    final id = await addSubscription(fallback: _reserve);
    answers[_main] = _ok('again');
    final row = await refresh(id);
    expect(row.fallbackUrl, _reserve);
  });

  test('changing the link by hand forgets the reserve', () async {
    final id = await addSubscription(fallback: _reserve);
    answers[_next] = _ok('typed');
    final saved = await subscriptions.saveSubscriptionInput(
      id,
      const SubscriptionInput(name: 'Provider', url: _next),
    );
    expect(saved, SubscriptionUpdateResult.success);
    final row = (await database.subscriptionDao.searchRow(id))!;
    expect(row.url, _next);
    expect(row.fallbackUrl, isNull);
  });
}
