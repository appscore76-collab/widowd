import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:widowd/main.dart';

void main() {
  setUpAll(loadAppFonts);

  // Never reaches the network: these tests only exercise the signed-out UI.
  GoTrueClient newAuth() =>
      GoTrueClient(url: 'http://localhost/auth/v1', autoRefreshToken: false);

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WidowdApp(auth: newAuth(), landingVideos: false));
  }

  testWidgets('Signed-out visitors see the landing page', (tester) async {
    await pumpApp(tester);

    expect(find.textContaining('Love again,'), findsOneWidget);
    expect(find.text('Made for widows and widowers'), findsOneWidget);
    expect(find.text('Create your profile'), findsWidgets);
    expect(find.text('Only for the widowed'), findsOneWidget);
  });

  testWidgets('Join free opens account creation', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Join free').first);
    await tester.pump();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
  });

  testWidgets('The hero button also opens account creation', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Create your profile').first);
    await tester.pump();

    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('Sign in opens sign-in, and back returns', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Sign in').first);
    await tester.pump();

    expect(find.text('Sign in to widowd'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(find.textContaining('Love again,'), findsOneWidget);
  });

  testWidgets('Switches to account creation', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sign in').first);
    await tester.pump();

    await tester.tap(find.text('New to widowd? Create an account'));
    await tester.pump();

    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('Validates the form before contacting Supabase', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sign in').first);
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}
