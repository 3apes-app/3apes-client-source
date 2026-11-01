import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/security/page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/security/device.dart';
import 'package:onexray/service/security/network.dart';
import 'package:onexray/service/security/service.dart';
import 'package:onexray/service/settings/language/locale.dart';

Widget _app(SecurityCheckService service) => MaterialApp(
  theme: AppTheme.material(Brightness.dark, mobile: true),
  locale: const Locale('ru'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalePolicy.localizationsDelegates,
  home: SecurityCheckPage(service: service),
);

// 3 APES: the page is a lazy list; a tall test screen builds all sections.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('runs on open and shows all good with VPN', (tester) async {
    _tall(tester);
    var runs = 0;
    final service = SecurityCheckService(
      vpnActive: () async => true,
      trace: (family) async {
        runs++;
        return family == InternetAddressType.IPv4
            ? const TraceInfo('185.10.10.10', 'NL')
            : const TraceInfo('2a01:4f8::1', 'NL');
      },
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(SecurityCheckPage)),
    )!;
    expect(runs, 2);
    expect(find.text(l.securityCheckAllGood), findsOneWidget);
    expect(find.text(l.securityIpViaVpn), findsOneWidget);
    expect(find.text(l.securityIpv6ViaVpn), findsOneWidget);
    expect(
      find.text('185.10.10.10 · ${l.countryRegionName('NL')}'),
      findsOneWidget,
    );
    expect(
      find.text('2a01:4f8::1 · ${l.countryRegionName('NL')}'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('security-check-again')));
    await tester.pumpAndSettle();
    expect(runs, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing answers: offline summary', (tester) async {
    _tall(tester);
    final service = SecurityCheckService(
      vpnActive: () async => false,
      trace: (family) async => null,
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(SecurityCheckPage)),
    )!;
    expect(find.text(l.securityCheckOffline), findsOneWidget);
    expect(find.text(l.securityCheckFailed), findsNWidgets(2));
  });

  testWidgets('device rows go under their own section with actions', (
    tester,
  ) async {
    _tall(tester);
    final service = SecurityCheckService(
      vpnActive: () async => true,
      trace: (family) async => null,
      device: () async =>
          const DeviceInfo(screenLock: false, securityPatch: '2026-09-01'),
      now: () => DateTime(2026, 10, 16),
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(SecurityCheckPage)),
    )!;
    expect(find.text(l.securityNetworkSection.toUpperCase()), findsOneWidget);
    expect(find.text(l.securityDeviceSection.toUpperCase()), findsOneWidget);
    expect(find.text(l.securityLockOff), findsOneWidget);
    expect(find.text(l.securityPatchFresh), findsOneWidget);
    expect(
      find.byKey(const ValueKey('security-action-screenLock')),
      // Settings buttons exist only on Android (iOS opens nothing).
      Platform.isAndroid ? findsOneWidget : findsNothing,
    );
    expect(
      find.byKey(const ValueKey('security-action-securityPatch')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
