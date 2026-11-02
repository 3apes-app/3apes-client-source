import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/view.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

// 3 APES: the security check card — only on «Нет подписки» (with «без
// подписки»); the main screen has the «Проверка» tab instead.
void main() {
  const card = ValueKey('connect-security-check');

  Widget app({
    required bool hasServers,
    ConnectionView view = const ConnectionView(),
    VoidCallback? onSecurityCheck,
  }) => MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ru'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalePolicy.localizationsDelegates,
    builder: (context, child) => LayoutBuilder(
      builder: (context, constraints) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: constraints.biggest),
        child: child!,
      ),
    ),
    home: ShadTheme(
      data: AppTheme.shad(Brightness.light),
      child: Scaffold(
        body: ConnectView(
          view: view,
          hasServers: hasServers,
          expert: false,
          raws: const [],
          activeRawId: null,
          location: 'Автовыбор',
          method: 'Smart Routing',
          onConnection: () {},
          onAddServers: () {},
          onExpert: (_) {},
          onServer: () {},
          onMethod: () {},
          onWhy: () {},
          onRawAdd: () {},
          onRawSelect: (_) {},
          onRawActions: (_) {},
          onSecurityCheck: onSecurityCheck,
        ),
      ),
    ),
  );

  testWidgets(
    'no-subscription screen offers the check without a subscription',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = false;
      await tester.pumpWidget(
        app(hasServers: false, onSecurityCheck: () => opened = true),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(ConnectView)))!;
      expect(find.text(l.securityPromoTitle), findsOneWidget);
      expect(find.text(l.securityPromoHintFree), findsOneWidget);
      await tester.ensureVisible(find.byKey(card));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(card));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('main screen no longer shows the check card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(hasServers: true, onSecurityCheck: () {}));
    await tester.pumpAndSettle();
    expect(find.byKey(card), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
