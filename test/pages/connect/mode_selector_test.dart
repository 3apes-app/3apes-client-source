import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/settings/language/locale.dart';

void main() {
  testWidgets('three mode buttons; a mode without servers is "Soon"', (
    tester,
  ) async {
    final chosen = <ConnectionMode>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.material(Brightness.dark, mobile: true),
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalePolicy.localizationsDelegates,
        home: Scaffold(
          body: ConnectModeSelector(
            current: ConnectionMode.home,
            available: const {ConnectionMode.home, ConnectionMode.protect},
            busy: false,
            onSelected: chosen.add,
          ),
        ),
      ),
    );
    final l = AppLocalizations.of(
      tester.element(find.byType(ConnectModeSelector)),
    )!;
    for (final title in [l.modeHome, l.modeProtect, l.modeAbroad]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(
      find.text('${l.modeHomeTagline}. ${l.modeHomeHint}'),
      findsOneWidget,
    );
    expect(find.text(l.securityCheckSoon), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('connect-mode-abroad')));
    await tester.tap(find.byKey(const ValueKey('connect-mode-protect')));
    expect(chosen, [ConnectionMode.protect]);
    expect(tester.takeException(), isNull);
  });
}
