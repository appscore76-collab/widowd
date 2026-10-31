import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:widowd/members/home_shell.dart';
import 'package:widowd/members/member.dart';
import 'package:widowd/members/members_repository.dart';
import 'package:widowd/members/profile_editor_page.dart';

class FakeMembersRepository implements MembersRepository {
  FakeMembersRepository({
    this.me,
    this.members = const [],
    this.suggested = const [],
  });

  Member? me;
  final List<Member> members;
  final List<Suggestion> suggested;
  ProfileDraft? saved;

  @override
  String get currentUserId => 'me';

  @override
  Future<Member?> myProfile() async => me;

  @override
  Future<void> saveProfile(ProfileDraft draft) async => saved = draft;

  @override
  Future<String> uploadPhoto(
    Uint8List bytes, {
    required String contentType,
  }) async => 'me/photo.jpg';

  @override
  Future<void> deletePhoto(String path) async {}

  @override
  Future<List<Member>> browse({int offset = 0, int limit = 24}) async =>
      members.skip(offset).take(limit).toList();

  @override
  Future<List<Suggestion>> suggestions() async => suggested;
}

const listedMe = Member(
  id: 'me',
  displayName: 'Ann',
  birthYear: 1962,
  gender: 'woman',
  interestedIn: ['man'],
  photoPath: 'me/photo.jpg',
  listed: true,
);

const robert = Member(
  id: 'robert',
  displayName: 'Robert',
  birthYear: 1959,
  gender: 'man',
  interestedIn: ['woman'],
  city: 'Leeds',
  bio: 'Retired teacher who loves walking the Dales.',
  idVerified: true,
  listed: true,
);

const david = Member(
  id: 'david',
  displayName: 'David',
  birthYear: 1965,
  gender: 'man',
  interestedIn: ['woman'],
  city: 'York',
  listed: true,
);

void main() {
  GoTrueClient newAuth() =>
      GoTrueClient(url: 'http://localhost/auth/v1', autoRefreshToken: false);

  Future<void> pumpShell(WidgetTester tester, MembersRepository repo) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(auth: newAuth(), repository: repo),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('A member without a complete profile is asked to create one', (
    tester,
  ) async {
    await pumpShell(tester, FakeMembersRepository(me: const Member(id: 'me')));

    expect(find.text('Create your profile'), findsOneWidget);
    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('The profile form requires a photo and the key details', (
    tester,
  ) async {
    final repo = FakeMembersRepository(me: const Member(id: 'me'));
    await pumpShell(tester, repo);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Year of birth'),
      '${DateTime.now().year - 10}',
    );
    await tester.tap(find.text('Save and continue'));
    await tester.pump();

    expect(find.text('Add a photo of yourself'), findsOneWidget);
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('You must be 18 or over to join'), findsOneWidget);
    expect(find.text('Choose one'), findsOneWidget);
    expect(find.text('Choose at least one'), findsOneWidget);
    expect(repo.saved, isNull);
  });

  testWidgets('Saving keeps the existing photo and sends the details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var saved = false;
    final repo = FakeMembersRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileEditorPage(
            repository: repo,
            initial: const Member(id: 'me', photoPath: 'me/old.jpg'),
            onSaved: () => saved = true,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      ' Ann ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Year of birth'),
      '1962',
    );
    await tester.tap(find.text('Woman'));
    await tester.tap(find.text('Men'));
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(repo.saved!.displayName, 'Ann');
    expect(repo.saved!.birthYear, 1962);
    expect(repo.saved!.gender, 'woman');
    expect(repo.saved!.interestedIn, ['man']);
    expect(repo.saved!.photoPath, 'me/old.jpg');
    expect(repo.saved!.city, isNull);
  });

  testWidgets('Listed members see their system suggestions', (tester) async {
    await pumpShell(
      tester,
      FakeMembersRepository(
        me: listedMe,
        suggested: [
          Suggestion(
            matchId: 1,
            member: robert,
            status: 'suggested',
            reasons: const ['Also lives in Leeds', 'ID verified'],
            createdAt: DateTime(2026, 10, 31),
          ),
        ],
      ),
    );

    final age = DateTime.now().year - 1959;
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Robert, $age'), findsOneWidget);
    expect(find.text('Also lives in Leeds'), findsOneWidget);
    expect(find.text('ID verified'), findsOneWidget);

    await tester.tap(find.text('Robert, $age'));
    await tester.pumpAndSettle();

    expect(find.text('Why we suggested'), findsOneWidget);
    expect(
      find.text('Retired teacher who loves walking the Dales.'),
      findsOneWidget,
    );
  });

  testWidgets('Shows a friendly message when there are no suggestions', (
    tester,
  ) async {
    await pumpShell(tester, FakeMembersRepository(me: listedMe));

    expect(find.text('No suggestions yet'), findsOneWidget);
  });

  testWidgets('Browse lists other members', (tester) async {
    await pumpShell(
      tester,
      FakeMembersRepository(me: listedMe, members: const [robert, david]),
    );

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Robert, '), findsOneWidget);
    expect(find.textContaining('David, '), findsOneWidget);
    expect(find.text('York'), findsOneWidget);
  });
}
