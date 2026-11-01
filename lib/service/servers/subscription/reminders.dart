import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/servers/subscription/user_info.dart';
import 'package:onexray/service/settings/language/service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// What a reminder is about.
enum ReminderKind { threeDays, tomorrow, expired, trafficLow, trafficOut }

/// One planned reminder: shown at [at], or right away when [at] is null.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.name,
    this.at,
    this.onceKey,
  });

  final int id;
  final ReminderKind kind;
  final String name;
  final DateTime? at;

  /// Shown-once marker for immediate reminders (null for scheduled ones).
  final String? onceKey;
}

/// 3 APES: local reminders from what the provider reports in the
/// subscription — no server. Three days and one day before the end (at noon,
/// local time), when it ends, and once when traffic drops below 10% or runs
/// out. A reminder whose moment has passed while the app was closed is shown
/// once when the app opens.
abstract final class SubscriptionReminderPlan {
  static const idBase = 7100;
  static const _slots = 5;

  static int idFor(int subscriptionId, ReminderKind kind) =>
      idBase + subscriptionId * _slots + kind.index;

  static bool ownsId(int id) => id >= idBase;

  static List<PlannedReminder> plan(
    Iterable<SubscriptionData> rows,
    DateTime now,
  ) {
    final result = <PlannedReminder>[];
    for (final row in rows) {
      final info = SubscriptionUserInfo.fromSubscription(row);
      if (info == null) continue;
      final name = row.name.trim().isEmpty ? '3 APES' : row.name.trim();
      final expiresAt = info.expiresAt;
      if (expiresAt != null && expiresAt.isAfter(now)) {
        final period = info.expireTimestamp;
        var immediate = false;
        for (final (kind, before) in const [
          (ReminderKind.tomorrow, Duration(days: 1)),
          (ReminderKind.threeDays, Duration(days: 3)),
        ]) {
          final day = expiresAt.toLocal().subtract(before);
          var at = DateTime(day.year, day.month, day.day, 12);
          if (!at.isBefore(expiresAt)) at = expiresAt.subtract(before);
          final id = idFor(row.id, kind);
          if (at.isAfter(now)) {
            result.add(PlannedReminder(id: id, kind: kind, name: name, at: at));
          } else if (!immediate) {
            // The most urgent stage that has already come: once.
            immediate = true;
            result.add(
              PlannedReminder(
                id: id,
                kind: kind,
                name: name,
                onceKey: 'app2.reminder.${row.id}.${kind.name}.$period',
              ),
            );
          }
        }
        result.add(
          PlannedReminder(
            id: idFor(row.id, ReminderKind.expired),
            kind: ReminderKind.expired,
            name: name,
            at: expiresAt,
          ),
        );
      }
      final total = info.totalBytes;
      final used = info.usedBytes;
      if (total != null &&
          total > 0 &&
          used != null &&
          used * 10 >= total * 9) {
        final kind = info.exhausted
            ? ReminderKind.trafficOut
            : ReminderKind.trafficLow;
        result.add(
          PlannedReminder(
            id: idFor(row.id, kind),
            kind: kind,
            name: name,
            onceKey:
                'app2.reminder.${row.id}.${kind.name}.$total.${info.expireTimestamp}',
          ),
        );
      }
    }
    return result;
  }

  static String title(AppLocalizations l, PlannedReminder reminder) =>
      switch (reminder.kind) {
        ReminderKind.threeDays => l.reminderExpiresInThreeDays(reminder.name),
        ReminderKind.tomorrow => l.reminderExpiresTomorrow(reminder.name),
        ReminderKind.expired => l.reminderExpired(reminder.name),
        ReminderKind.trafficLow => l.reminderTrafficLow(reminder.name),
        ReminderKind.trafficOut => l.reminderTrafficOut(reminder.name),
      };
}

/// Keeps the reminders in step with the subscriptions (Android and iOS).
final class SubscriptionReminderService {
  static final SubscriptionReminderService _instance =
      SubscriptionReminderService._();
  factory SubscriptionReminderService() => _instance;
  SubscriptionReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _prefs = SharedPreferencesAsync();
  StreamSubscription<List<SubscriptionData>>? _stream;
  Timer? _debounce;

  static const _accent = Color(0xFF23784A);

  Future<void> start() async {
    if (!(AppPlatform.isAndroid || AppPlatform.isIOS) || _stream != null) {
      return;
    }
    _stream = AppDatabase().subscriptionDao.allRowsStream.listen((rows) {
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(seconds: 2),
        () => unawaited(sync(rows)),
      );
    }, onError: (Object error) => ygLogger('Reminder stream failed: $error'));
  }

  NotificationDetails _details(AppLocalizations l) => NotificationDetails(
    android: AndroidNotificationDetails(
      'app.threeapes.reminders',
      l.reminderChannel,
      channelDescription: l.reminderChannel,
      icon: 'ic_notification',
      color: _accent,
      largeIcon: const DrawableResourceAndroidBitmap('notification_monkeys'),
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    // Shown as a banner even while the app is open.
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
  );

  /// iOS asks once, when there is first something to remind about (not at
  /// launch); later calls get the answer without a prompt.
  Future<bool> _iosAllowed() async =>
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true) ??
      false;

  Future<void> sync(List<SubscriptionData> rows) async {
    try {
      final l = appLocalizationsNoContext();
      final now = DateTime.now();
      final plan = SubscriptionReminderPlan.plan(rows, now);
      // Not allowed on iOS: keep the shown-once reminders for later.
      if (AppPlatform.isIOS && plan.isNotEmpty && !await _iosAllowed()) {
        return;
      }
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (SubscriptionReminderPlan.ownsId(request.id)) {
          await _plugin.cancel(id: request.id);
        }
      }
      final details = _details(l);
      for (final reminder in plan) {
        final title = SubscriptionReminderPlan.title(l, reminder);
        final at = reminder.at;
        if (at != null) {
          if (!at.isAfter(DateTime.now())) continue;
          await _plugin.zonedSchedule(
            id: reminder.id,
            title: title,
            body: l.reminderHint,
            scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
          continue;
        }
        final key = reminder.onceKey;
        if (key == null || await _prefs.getBool(key) == true) continue;
        await _prefs.setBool(key, true);
        await _plugin.show(
          id: reminder.id,
          title: title,
          body: l.reminderHint,
          notificationDetails: details,
        );
      }
    } catch (error, stackTrace) {
      ygLogger('Subscription reminders failed: $error\n$stackTrace');
    }
  }
}
