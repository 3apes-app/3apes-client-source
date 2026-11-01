import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/servers/subscription/reminders.dart';

// 3 APES: local subscription reminders are planned from the provider data.
void main() {
  final now = DateTime(2026, 10, 19, 15);
  int at(Duration offset) => now.add(offset).millisecondsSinceEpoch ~/ 1000;

  SubscriptionData row({
    int id = 1,
    int? expire,
    int? total,
    int? used,
    bool info = true,
  }) => SubscriptionData(
    id: id,
    name: 'Sub $id',
    url: 'https://example.com/sub/$id',
    hwidEnabled: false,
    timestamp: now,
    uploadBytes: used == null ? null : 0,
    downloadBytes: used,
    totalBytes: total,
    expireTimestamp: expire,
    userInfoUpdatedAt: info ? now : null,
  );

  test('ten days left: three-days, tomorrow and ended are scheduled', () {
    final plan = SubscriptionReminderPlan.plan([
      row(expire: at(const Duration(days: 10))),
    ], now);
    expect(plan.map((r) => r.kind), [
      ReminderKind.tomorrow,
      ReminderKind.threeDays,
      ReminderKind.expired,
    ]);
    expect(plan.every((r) => r.at != null && r.at!.isAfter(now)), isTrue);
    expect(plan.first.at!.hour, 12);
  });

  test('two days left: three-days is shown once now, tomorrow scheduled', () {
    final plan = SubscriptionReminderPlan.plan([
      row(expire: at(const Duration(days: 2))),
    ], now);
    final now3 = plan.singleWhere((r) => r.kind == ReminderKind.threeDays);
    expect(now3.at, isNull);
    expect(now3.onceKey, isNotNull);
    expect(
      plan.singleWhere((r) => r.kind == ReminderKind.tomorrow).at,
      isNotNull,
    );
  });

  test('hours left: only the most urgent stage is shown now', () {
    final plan = SubscriptionReminderPlan.plan([
      row(expire: at(const Duration(hours: 5))),
    ], now);
    expect(plan.where((r) => r.at == null).map((r) => r.kind), [
      ReminderKind.tomorrow,
    ]);
  });

  test('ended, unlimited or no provider data: nothing about the date', () {
    expect(
      SubscriptionReminderPlan.plan([
        row(expire: at(const Duration(days: -1))),
        row(id: 2, expire: 0, total: 0),
        row(id: 3, expire: at(const Duration(days: 2)), info: false),
      ], now),
      isEmpty,
    );
  });

  test('traffic: below 10% and run out', () {
    final plan = SubscriptionReminderPlan.plan([
      row(total: 100, used: 95),
      row(id: 2, total: 100, used: 100),
      row(id: 3, total: 100, used: 50),
    ], now);
    expect(plan.map((r) => r.kind), [
      ReminderKind.trafficLow,
      ReminderKind.trafficOut,
    ]);
  });

  test('ids do not collide between subscriptions and kinds', () {
    final ids = {
      for (final sub in [1, 2, 3])
        for (final kind in ReminderKind.values)
          SubscriptionReminderPlan.idFor(sub, kind),
    };
    expect(ids.length, 3 * ReminderKind.values.length);
  });
}
