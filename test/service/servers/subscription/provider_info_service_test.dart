import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/advanced/xray/data_update/state.dart';
import 'package:onexray/service/servers/outbound/state_db.dart';
import 'package:onexray/service/servers/subscription/model.dart';
import 'package:onexray/service/servers/subscription/provider_info.dart';
import 'package:onexray/service/servers/subscription/service.dart';
import 'package:onexray/service/shared/event_bus/service.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    final bus = AppEventBus();
    addTearDown(bus.close);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
  });

  SubscriptionService service(SubscriptionProviderInfo Function() info) =>
      SubscriptionService.forTesting(
        database: database,
        loadRows: (input) async => SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [
            outboundCompanion({'protocol': 'socks', 'tag': input.name}),
          ],
          providerInfo: info(),
        ),
        schedulePing: (_) {},
        readReferences: () => const SubscriptionNodeReferences(),
      );

  test('insert stores provider data and takes the title as name', () async {
    final result = await service(
      () => const SubscriptionProviderInfo(
        title: '3 APES',
        announce: 'Hello',
        supportUrl: 'https://t.me/support',
        webPageUrl: 'https://3apes.app',
        updateIntervalHours: 1,
      ),
    ).insertSubscription(
      const SubscriptionInput(
        name: 'sub.3apes.online',
        url: 'https://sub.3apes.online/abc',
      ),
    );
    final row = (await database.subscriptionDao.searchRow(result.subId))!;
    expect(row.name, '3 APES');
    expect(row.providerTitle, '3 APES');
    expect(row.announce, 'Hello');
    expect(row.supportUrl, 'https://t.me/support');
    expect(row.webPageUrl, 'https://3apes.app');
    expect(row.updateIntervalHours, 1);
  });

  test('refresh follows a new title, clears a removed announce, '
      'keeps a user name', () async {
    var info = const SubscriptionProviderInfo(title: 'Old', announce: 'News');
    final subscriptions = service(() => info);
    final id = (await subscriptions.insertSubscription(
      const SubscriptionInput(
        name: 'example.com',
        url: 'https://example.com/sub',
      ),
    )).subId;

    info = const SubscriptionProviderInfo(title: 'New');
    var row = (await database.subscriptionDao.searchRow(id))!;
    expect((await subscriptions.refreshSubscriptionResult(row)).success, isTrue);
    row = (await database.subscriptionDao.searchRow(id))!;
    expect(row.name, 'New');
    expect(row.announce, isNull);

    await database.subscriptionDao.updateRow(row.copyWith(name: 'Mine'));
    info = const SubscriptionProviderInfo(title: 'Newer');
    row = (await database.subscriptionDao.searchRow(id))!;
    await subscriptions.refreshSubscriptionResult(row);
    row = (await database.subscriptionDao.searchRow(id))!;
    expect(row.name, 'Mine');
    expect(row.providerTitle, 'Newer');
  });

  test('provider interval wins over the global interval', () async {
    final now = DateTime.now();
    for (final entry in {
      // Refreshed 58 min ago with a 1 h provider interval: due (slack).
      'Hourly': (const Duration(minutes: 58), 1),
      'Hourly fresh': (const Duration(minutes: 20), 1),
      // 25 h old, global is 3 days, no provider interval: not due.
      'Global': (const Duration(hours: 25), null),
    }.entries) {
      await database.subscriptionDao.insertRow(
        SubscriptionCompanion.insert(
          name: entry.key,
          url: 'https://example.com/${Uri.encodeComponent(entry.key)}',
          timestamp: now.subtract(entry.value.$1),
          updateIntervalHours: Value(entry.value.$2),
        ),
      );
    }
    final downloads = <String>[];
    final subscriptions = SubscriptionService.forTesting(
      database: database,
      loadRows: (input) async {
        downloads.add(input.name);
        return SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [
            outboundCompanion({'protocol': 'socks', 'tag': input.name}),
          ],
        );
      },
      schedulePing: (_) {},
      readReferences: () => const SubscriptionNodeReferences(),
    );
    await subscriptions.refreshOutdatedSubscription(
      autoUpdateState: AutoUpdateState()
        ..subscriptionEnabled = true
        ..subscriptionInterval = AutoUpdateInterval.threeDays,
    );
    expect(downloads, ['Hourly']);
  });
}
