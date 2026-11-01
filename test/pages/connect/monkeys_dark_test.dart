import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/pages/connect/monkeys.dart';
import 'package:onexray/pages/theme/theme.dart';

// 3 APES: in the dark theme the monkeys are dimmed (90% brightness, 97%
// saturation) and stand on a soft light; the light theme shows them as is.
void main() {
  Widget app(ThemeData theme) => MaterialApp(
    theme: theme,
    home: const Scaffold(
      body: Center(child: ConnectMonkeys(covered: false, haptic: false)),
    ),
  );

  testWidgets('dark theme dims the monkeys and adds the light under them', (
    tester,
  ) async {
    await tester.pumpWidget(app(AppTheme.material(Brightness.dark)));
    await tester.pump();
    expect(find.byType(ColorFiltered), findsNWidgets(3));
    expect(find.byKey(const ValueKey('monkeys-glow')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('light theme shows the monkeys as they are', (tester) async {
    await tester.pumpWidget(app(AppTheme.light));
    await tester.pump();
    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.byKey(const ValueKey('monkeys-glow')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
