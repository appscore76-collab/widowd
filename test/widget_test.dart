import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:widowd/main.dart';

void main() {
  // Never reaches the network: these tests only exercise the signed-out UI.
  GoTrueClient newAuth() =>
      GoTrueClient(url: 'http://localhost/auth/v1', autoRefreshToken: false);

  testWidgets('Signed-out visitors see the sign-in page', (tester) async {
    await tester.pumpWidget(WidowdApp(auth: newAuth()));

    expect(find.text('Sign in to widowd'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('Email me a sign-in link instead'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('Switches to account creation', (tester) async {
    await tester.pumpWidget(WidowdApp(auth: newAuth()));

    await tester.ensureVisible(find.text('New to widowd? Create an account'));
    await tester.tap(find.text('New to widowd? Create an account'));
    await tester.pump();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
  });

  testWidgets('Validates the form before contacting Supabase', (tester) async {
    await tester.pumpWidget(WidowdApp(auth: newAuth()));

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('Asks for an email before sending a magic link', (tester) async {
    await tester.pumpWidget(WidowdApp(auth: newAuth()));

    await tester.ensureVisible(find.text('Email me a sign-in link instead'));
    await tester.tap(find.text('Email me a sign-in link instead'));
    await tester.pump();

    expect(
      find.text('Enter your email address above to get a sign-in link'),
      findsOneWidget,
    );
  });
}
