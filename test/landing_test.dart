import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

import 'package:widowd/landing/landing_page.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpLanding(
    WidgetTester tester, {
    Size size = const Size(1440, 2400),
    VoidCallback? onJoin,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LandingPage(
          onJoin: onJoin ?? () {},
          onSignIn: () {},
          videosEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (name, size) in [
    ('desktop', const Size(1440, 2400)),
    ('tablet', const Size(800, 2400)),
    ('phone', const Size(390, 2400)),
  ]) {
    testWidgets('Lays out without overflow on $name', (tester) async {
      await pumpLanding(tester, size: size);

      expect(tester.takeException(), isNull);
      expect(find.text('Good to know.'), findsOneWidget);
      expect(find.text('Ready when you are.'), findsOneWidget);
    });
  }

  testWidgets('The before/after toggle swaps the caption', (tester) async {
    await pumpLanding(tester);

    expect(
      find.text('Her words, family and values come first. Photos are locked.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('After you like'));
    await tester.tap(find.text('After you like'));
    await tester.pump();

    expect(
      find.text('One like later — her photos unlock, just for you.'),
      findsOneWidget,
    );
  });

  testWidgets('Picking a feature shows its details', (tester) async {
    await pumpLanding(tester);

    await tester.ensureVisible(find.text('Video chat'));
    await tester.tap(find.text('Video chat'));
    await tester.pump();

    expect(find.text('Never recorded'), findsOneWidget);
  });

  testWidgets('FAQ answers open one at a time', (tester) async {
    await pumpLanding(tester);

    expect(find.textContaining('only for widows and widowers'), findsOneWidget);
    await tester.ensureVisible(find.text('Why are photos blurred?'));
    await tester.tap(find.text('Why are photos blurred?'));
    await tester.pump();

    expect(find.textContaining('So people like you'), findsOneWidget);
    expect(find.textContaining('only for widows and widowers'), findsNothing);
  });

  testWidgets('Pricing buttons lead to joining', (tester) async {
    var joined = 0;
    await pumpLanding(tester, onJoin: () => joined++);

    await tester.ensureVisible(find.text('Choose Monthly'));
    await tester.tap(find.text('Choose Monthly'));

    expect(joined, 1);
  });

  testWidgets('Pause videos toggles to Play videos', (tester) async {
    await pumpLanding(tester);

    await tester.tap(find.text('Pause videos'));
    await tester.pump();

    expect(find.text('Play videos'), findsOneWidget);
  });
}
