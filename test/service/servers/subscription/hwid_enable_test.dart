import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/servers/outbound/state_db.dart';
import 'package:onexray/service/servers/subscription/model.dart';
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

  SubscriptionData row({required bool hwidEnabled}) => SubscriptionData(
    id: 1,
    name: 'Provider',
    url: 'https://example.com/sub',
    hwidEnabled: hwidEnabled,
    timestamp: DateTime(2026),
  );

  test('the button is offered only when the ID is off and could help', () {
    final off = row(hwidEnabled: false);
    final on = row(hwidEnabled: true);
    expect(
      SubscriptionService.offersHwidEnable(
        off,
        SubscriptionUpdateResult.hwidRequired,
      ),
      isTrue,
    );
    expect(
      SubscriptionService.offersHwidEnable(
        off,
        SubscriptionUpdateResult.hwidRejected,
      ),
      isTrue,
    );
    expect(
      SubscriptionService.offersHwidEnable(
        off,
        SubscriptionUpdateResult.hwidLimitReached,
      ),
      isFalse,
    );
    expect(
      SubscriptionService.offersHwidEnable(
        on,
        SubscriptionUpdateResult.hwidRequired,
      ),
      isFalse,
    );
    expect(
      SubscriptionService.offersHwidEnable(
        off,
        SubscriptionUpdateResult.downloadFailed,
      ),
      isFalse,
    );
  });

  test('turning the ID on sends it with the retry and keeps it', () async {
    final sent = <(bool, String?)>[];
    final subscriptions = SubscriptionService.forTesting(
      database: database,
      loadRows: (input) async {
        sent.add((input.hwidEnabled, input.hwid));
        if (!input.hwidEnabled) {
          return const SubscriptionLoadResult(
            status: SubscriptionUpdateResult.hwidRequired,
          );
        }
        return SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [
            outboundCompanion({'protocol': 'socks', 'tag': 'node'}),
          ],
        );
      },
      schedulePing: (_) {},
      readReferences: () => const SubscriptionNodeReferences(),
    );
    final id = await database.subscriptionDao.insertRow(
      SubscriptionCompanion.insert(
        name: 'Provider',
        url: 'https://example.com/sub',
        timestamp: DateTime(2026),
      ),
    );
    final before = (await database.subscriptionDao.searchRow(id))!;
    // The user had switched the ID off for this subscription in its editor.
    await database.subscriptionDao.updateRow(
      before.copyWith(hwid: const Value('kept-id')),
    );

    final result = await subscriptions.enableHwidAndRefresh(id);
    expect(result.success, isTrue);
    expect(sent.last, (true, 'kept-id'));
    final after = (await database.subscriptionDao.searchRow(id))!;
    expect(after.hwidEnabled, isTrue);
    expect(after.hwid, 'kept-id');
  });

  test('a missing subscription is reported, nothing is downloaded', () async {
    var downloads = 0;
    final subscriptions = SubscriptionService.forTesting(
      database: database,
      loadRows: (_) async {
        downloads++;
        return const SubscriptionLoadResult(
          status: SubscriptionUpdateResult.downloadFailed,
        );
      },
      schedulePing: (_) {},
      readReferences: () => const SubscriptionNodeReferences(),
    );
    final result = await subscriptions.enableHwidAndRefresh(42);
    expect(result.status, SubscriptionUpdateResult.notFound);
    expect(downloads, 0);
  });
}
