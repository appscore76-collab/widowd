import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:widowd/main.dart';

void main() {
  // Never reaches the network: these tests only exercise the signed-out UI.
  GoTrueClient newAuth() =>
      GoTrueClient(url: 'http://localhost/auth/v1', autoRefreshToken: false);

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WidowdApp(auth: newAuth()));
  }

  testWidgets('Signed-out visitors see the landing page', (tester) async {
    await pumpApp(tester);

    expect(find.text('Companionship, when you are ready'), findsOneWidget);
    expect(find.text('Join free'), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
    expect(find.text('Daily match suggestions'), findsOneWidget);
    expect(find.text('Private video calls with your matches'), findsOneWidget);
  });

  testWidgets('Join free opens account creation', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Join free'));
    await tester.pump();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
  });

  testWidgets('Sign in opens sign-in, and back returns', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('I already have an account'));
    await tester.pump();

    expect(find.text('Sign in to widowd'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pump();

    expect(find.text('Companionship, when you are ready'), findsOneWidget);
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
