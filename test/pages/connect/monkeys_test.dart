import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/pages/connect/monkeys.dart';

// 3 APES: the monkeys cover eyes, mouth and ears one after another.

String? _frameOf(WidgetTester tester, String color) {
  final image = tester.widget<Image>(find.byKey(ValueKey('monkey-$color')));
  return (image.image as AssetImage).assetName;
}

Widget _app(bool covered) => MaterialApp(
  home: Scaffold(
    body: Center(child: ConnectMonkeys(covered: covered, haptic: false)),
  ),
);

void main() {
  test('frame names', () {
    expect(
      ConnectMonkeys.frame('green', 3),
      'assets/monkeys/green/green_03.webp',
    );
    expect(ConnectMonkeys.total, const Duration(milliseconds: 1400));
  });

  testWidgets('cascade: green first, red last, and back', (tester) async {
    await tester.pumpWidget(_app(false));
    for (final color in ConnectMonkeys.colors) {
      expect(_frameOf(tester, color), ConnectMonkeys.frame(color, 0));
    }

    await tester.pumpWidget(_app(true));
    await tester.pump(const Duration(milliseconds: 300));
    // Green is moving, red has not started yet.
    expect(_frameOf(tester, 'green'), isNot(ConnectMonkeys.frame('green', 0)));
    expect(_frameOf(tester, 'red'), ConnectMonkeys.frame('red', 0));

    await tester.pumpAndSettle();
    for (final color in ConnectMonkeys.colors) {
      expect(
        _frameOf(tester, color),
        ConnectMonkeys.frame(color, ConnectMonkeys.frames - 1),
      );
    }

    await tester.pumpWidget(_app(false));
    await tester.pump(ConnectMonkeys.uncoverDelay);
    await tester.pumpAndSettle();
    for (final color in ConnectMonkeys.colors) {
      expect(_frameOf(tester, color), ConnectMonkeys.frame(color, 0));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion jumps to the pose', (tester) async {
    Widget app(bool covered) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: ConnectMonkeys(covered: covered, haptic: false),
      ),
    );
    await tester.pumpWidget(app(false));
    await tester.pumpWidget(app(true));
    await tester.pump();
    expect(
      _frameOf(tester, 'blue'),
      ConnectMonkeys.frame('blue', ConnectMonkeys.frames - 1),
    );
  });

  testWidgets('words appear under each monkey as it covers up', (
    tester,
  ) async {
    Widget app(bool covered) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConnectMonkeys(
            covered: covered,
            haptic: false,
            labels: const ['SEE', 'TELL', 'HEAR'],
          ),
        ),
      ),
    );
    double opacity(String color) => tester
        .widget<Opacity>(find.byKey(ValueKey('monkey-label-$color')))
        .opacity;

    await tester.pumpWidget(app(false));
    for (final color in ConnectMonkeys.colors) {
      expect(opacity(color), 0);
    }
    expect(find.text('TELL'), findsOneWidget);

    await tester.pumpWidget(app(true));
    await tester.pump(const Duration(milliseconds: 900));
    // Green is done, red is still moving.
    expect(opacity('green'), 1);
    expect(opacity('red'), lessThan(1));

    await tester.pumpAndSettle();
    for (final color in ConnectMonkeys.colors) {
      expect(opacity(color), 1);
    }
    await tester.pumpWidget(app(false));
    await tester.pump(ConnectMonkeys.uncoverDelay);
    await tester.pumpAndSettle();
    for (final color in ConnectMonkeys.colors) {
      expect(opacity(color), 0);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a quick reconnect keeps the hands up', (tester) async {
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    final last = ConnectMonkeys.frames - 1;
    // Mode switch: off for half a second, then connected again.
    await tester.pumpWidget(_app(false));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(_app(true));
    await tester.pump(ConnectMonkeys.uncoverDelay);
    await tester.pumpAndSettle();
    for (final color in ConnectMonkeys.colors) {
      expect(_frameOf(tester, color), ConnectMonkeys.frame(color, last));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning the VPN off by hand opens them at once', (
    tester,
  ) async {
    Widget app(bool covered) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConnectMonkeys(
            covered: covered,
            haptic: false,
            holdOnDrop: false,
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    for (final color in ConnectMonkeys.colors) {
      expect(_frameOf(tester, color), ConnectMonkeys.frame(color, 0));
    }
  });

  testWidgets('words fade out while it reconnects', (tester) async {
    Widget app(bool words) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConnectMonkeys(
            covered: true,
            haptic: false,
            labels: const ['SEE', 'TELL', 'HEAR'],
            showLabels: words,
          ),
        ),
      ),
    );
    double opacity(String color) => tester
        .widget<Opacity>(find.byKey(ValueKey('monkey-label-$color')))
        .opacity;
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(opacity('blue'), 1);
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    expect(opacity('blue'), 0);
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(opacity('blue'), 1);
  });
}
