import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/subscriptions_view.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/settings/language/locale.dart';

// 3 APES: the phone «Подписки» tab without subscriptions offers only
// «Подключиться» (to the main screen), no import options, and is centered.
void main() {
  testWidgets('empty subscriptions tab sends to the main screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var connect = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalePolicy.localizationsDelegates,
        home: Scaffold(
          body: SubscriptionsEmptyView(onConnect: () => connect = true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(SubscriptionsEmptyView)),
    )!;
    expect(find.text(l.subscriptionsEmptyTitle), findsOneWidget);
    expect(find.text(l.subscriptionsEmptyHint), findsOneWidget);
    expect(find.text(l.prototypeAddServer), findsNothing);
    final button = find.byKey(const ValueKey('subscriptions-empty-connect'));
    expect(tester.getCenter(button).dx, closeTo(195, 1));
    await tester.tap(button);
    expect(connect, isTrue);
    expect(tester.takeException(), isNull);
  });
}
