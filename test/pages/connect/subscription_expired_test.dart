import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/subscription_expired.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/settings/language/locale.dart';

void main() {
  final now = DateTime.utc(2026, 10, 18, 12);
  int at(Duration offset) => now.add(offset).millisecondsSinceEpoch ~/ 1000;

  SubscriptionData row({
    int id = 1,
    int? expire,
    int? total,
    int? used,
    bool info = true,
    String? webPageUrl,
    String? supportUrl,
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
    webPageUrl: webPageUrl,
    supportUrl: supportUrl,
  );

  group('reason', () {
    test('nothing without subscriptions or provider data', () {
      expect(SubscriptionExpiredGate.reason([], now), isNull);
      expect(SubscriptionExpiredGate.reason([row(info: false)], now), isNull);
    });

    test('expired by date', () {
      expect(
        SubscriptionExpiredGate.reason([
          row(expire: at(const Duration(days: -1))),
        ], now),
        SubscriptionEndReason.expired,
      );
    });

    test('out of traffic', () {
      expect(
        SubscriptionExpiredGate.reason([
          row(expire: at(const Duration(days: 5)), total: 100, used: 100),
        ], now),
        SubscriptionEndReason.traffic,
      );
    });

    test('one usable subscription keeps the main screen', () {
      expect(
        SubscriptionExpiredGate.reason([
          row(expire: at(const Duration(days: -1))),
          row(id: 2, expire: at(const Duration(days: 3))),
        ], now),
        isNull,
      );
    });

    test('no end date and unlimited never end', () {
      expect(
        SubscriptionExpiredGate.reason([row(expire: 0, total: 0)], now),
        isNull,
      );
    });
  });

  group('renewUri', () {
    test('provider page first, then support, then the bot', () {
      expect(
        SubscriptionExpiredGate.renewUri([
          row(webPageUrl: 'https://t.me/x', supportUrl: 'https://s.example'),
        ]).toString(),
        'https://t.me/x',
      );
      expect(
        SubscriptionExpiredGate.renewUri([
          row(
            webPageUrl: 'javascript:alert(1)',
            supportUrl: 'https://s.example',
          ),
        ]).toString(),
        'https://s.example',
      );
      expect(
        SubscriptionExpiredGate.renewUri([row()]).toString(),
        SubscriptionExpiredGate.botUrl,
      );
    });

    test('telegram links are recognised', () {
      expect(
        SubscriptionExpiredGate.telegram(Uri.parse('https://t.me/a')),
        isTrue,
      );
      expect(
        SubscriptionExpiredGate.telegram(Uri.parse('tg://resolve?domain=a')),
        isTrue,
      );
      expect(
        SubscriptionExpiredGate.telegram(Uri.parse('https://example.com')),
        isFalse,
      );
    });
  });

  // 3 APES: store builds have no «Продлить» (no payment outside the store);
  // «Я уже продлил — обновить» becomes the main button.
  group('view', () {
    Widget app(Widget child) => MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalePolicy.localizationsDelegates,
      home: Scaffold(body: child),
    );

    testWidgets('site build shows renew and refresh', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var renewed = false;
      await tester.pumpWidget(
        app(
          SubscriptionExpiredView(
            reason: SubscriptionEndReason.expired,
            telegram: true,
            refreshing: false,
            onRenew: () => renewed = true,
            onRefresh: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(SubscriptionExpiredView)),
      )!;
      expect(find.text(l.subscriptionExpiredHint), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('subscription-expired-renew')),
      );
      expect(renewed, isTrue);
      expect(
        find.byKey(const ValueKey('subscription-expired-refresh')),
        findsOneWidget,
      );
    });

    testWidgets('store build has no renew link', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var refreshed = false;
      await tester.pumpWidget(
        app(
          SubscriptionExpiredView(
            reason: SubscriptionEndReason.expired,
            telegram: true,
            refreshing: false,
            onRenew: null,
            onRefresh: () => refreshed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(SubscriptionExpiredView)),
      )!;
      expect(
        find.byKey(const ValueKey('subscription-expired-renew')),
        findsNothing,
      );
      expect(find.text(l.subscriptionExpiredRenewTelegram), findsNothing);
      expect(find.text(l.subscriptionExpiredHintStore), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('subscription-expired-refresh')),
      );
      expect(refreshed, isTrue);
    });
  });
}
