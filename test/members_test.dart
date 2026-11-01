import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:go_router/go_router.dart';
import 'package:widowd/app/providers.dart';
import 'package:widowd/main.dart';
import 'package:widowd/members/member.dart';
import 'package:widowd/members/members_repository.dart';

import 'test_fonts.dart';

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
  BrowseFilter? lastFilter;

  @override
  String get currentUserId => 'me';

  @override
  Future<Member?> myProfile() async => me;

  @override
  Future<Member?> member(String id) async {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

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
  Future<List<Member>> browse({
    int offset = 0,
    int limit = 24,
    BrowseFilter filter = const BrowseFilter(),
  }) async {
    lastFilter = filter;
    final q = filter.query.trim().toLowerCase();
    return members
        .where((m) => !filter.photoVerified || m.photoVerified)
        .where((m) => !filter.idVerified || m.idVerified)
        .where(
          (m) =>
              q.isEmpty ||
              '${m.displayName} ${m.city} ${m.bio}'.toLowerCase().contains(q),
        )
        .skip(offset)
        .take(limit)
        .toList();
  }

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
  photoVerified: true,
  listed: true,
);

void main() {
  setUpAll(loadAppFonts);

  GoTrueClient newAuth() =>
      GoTrueClient(url: 'http://localhost/auth/v1', autoRefreshToken: false);

  Future<void> pumpShell(
    WidgetTester tester,
    MembersRepository repo, {
    Size size = const Size(1200, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WidowdApp(
        auth: newAuth(),
        repository: () => repo,
        session: AuthSession.fixed(userId: 'me'),
        landingVideos: false,
      ),
    );
    await tester.pumpAndSettle();
  }

  String currentPath(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .routerDelegate
          .currentConfiguration
          .uri
          .path;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  group('Onboarding', () {
    testWidgets('starts at step 1 of 4 without the tabs', (tester) async {
      await pumpShell(
        tester,
        FakeMembersRepository(me: const Member(id: 'me')),
      );

      expect(find.text('Tell us about you'), findsOneWidget);
      expect(find.text('1 of 4'), findsOneWidget);
      expect(find.text('Discover'), findsNothing);
    });

    testWidgets('checks each step before moving on', (tester) async {
      await pumpShell(
        tester,
        FakeMembersRepository(me: const Member(id: 'me')),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Year of birth'),
        '${DateTime.now().year - 10}',
      );
      await tapText(tester, 'Continue');

      expect(find.text('Enter your name'), findsOneWidget);
      expect(find.text('You must be 18 or over to join'), findsOneWidget);
      expect(find.text('1 of 4'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'),
        'Ann',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Year of birth'),
        '1962',
      );
      await tapText(tester, 'Continue');
      expect(find.text('Who are you hoping to meet?'), findsOneWidget);

      await tapText(tester, 'Continue');
      expect(find.text('Choose one'), findsOneWidget);
      expect(find.text('Choose at least one'), findsOneWidget);
      expect(find.text('2 of 4'), findsOneWidget);
    });

    testWidgets('walks through every step and saves', (tester) async {
      final repo = FakeMembersRepository(
        me: const Member(id: 'me', photoPath: 'me/old.jpg'),
      );
      await pumpShell(tester, repo);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'),
        ' Ann ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Year of birth'),
        '1962',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Town or city (optional)'),
        'Leeds',
      );
      await tapText(tester, 'Continue');
      await tapText(tester, 'Woman');
      await tapText(tester, 'Men');
      await tapText(tester, 'Continue');
      expect(find.text('Share your story'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Hello there');
      await tapText(tester, 'Continue');
      expect(find.text('Add your photo'), findsOneWidget);

      // Going back keeps what was typed.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Hello there'), findsOneWidget);
      await tapText(tester, 'Continue');

      await tapText(tester, 'Finish');

      expect(repo.saved!.displayName, 'Ann');
      expect(repo.saved!.birthYear, 1962);
      expect(repo.saved!.city, 'Leeds');
      expect(repo.saved!.gender, 'woman');
      expect(repo.saved!.interestedIn, ['man']);
      expect(repo.saved!.bio, 'Hello there');
      expect(repo.saved!.photoPath, 'me/old.jpg');
    });

    testWidgets('asks for a photo on the last step', (tester) async {
      final repo = FakeMembersRepository(
        me: const Member(
          id: 'me',
          displayName: 'Ann',
          birthYear: 1962,
          gender: 'woman',
          interestedIn: ['man'],
        ),
      );
      await pumpShell(tester, repo);

      await tapText(tester, 'Continue');
      await tapText(tester, 'Continue');
      await tapText(tester, 'Continue');
      await tapText(tester, 'Finish');

      expect(find.text('Add a photo of yourself'), findsOneWidget);
      expect(repo.saved, isNull);
    });
  });

  group('Signed-in app', () {
    testWidgets('shows today’s suggestions and opens a profile', (
      tester,
    ) async {
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
      expect(find.text('Today’s suggestions'), findsOneWidget);
      expect(find.text('Robert, $age'), findsOneWidget);
      expect(find.text('Also lives in Leeds'), findsOneWidget);
      expect(find.text('ID checked'), findsOneWidget);

      await tapText(tester, 'Robert, $age');

      expect(find.text('Why we suggested Robert'), findsOneWidget);
      expect(
        find.text('Retired teacher who loves walking the Dales.'),
        findsOneWidget,
      );
    });

    testWidgets('explains when there are no suggestions', (tester) async {
      await pumpShell(tester, FakeMembersRepository(me: listedMe));

      expect(find.text('No suggestions yet'), findsOneWidget);
    });

    testWidgets('search lists members and filters them', (tester) async {
      final repo = FakeMembersRepository(
        me: listedMe,
        members: const [robert, david],
      );
      await pumpShell(tester, repo);

      await tapText(tester, 'Search');
      expect(find.textContaining('Robert, '), findsOneWidget);
      expect(find.textContaining('David, '), findsOneWidget);

      await tapText(tester, 'Photo verified');
      expect(repo.lastFilter!.photoVerified, isTrue);
      expect(find.textContaining('Robert, '), findsNothing);
      expect(find.textContaining('David, '), findsOneWidget);

      await tapText(tester, 'Photo verified');
      await tester.enterText(find.byType(TextField), 'leeds');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.lastFilter!.query, 'leeds');
      expect(find.textContaining('Robert, '), findsOneWidget);
      expect(find.textContaining('David, '), findsNothing);
    });

    testWidgets('Me shows the profile editor and saves', (tester) async {
      final repo = FakeMembersRepository(me: listedMe);
      // Tall enough that typing doesn't scroll the save button away.
      await pumpShell(tester, repo, size: const Size(1200, 2400));

      await tapText(tester, 'Me');
      expect(find.text('My profile'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Town or city (optional)'),
        'York',
      );
      await tapText(tester, 'Save changes');

      expect(repo.saved!.city, 'York');
      expect(repo.saved!.displayName, 'Ann');
    });

    for (final (name, size) in [
      ('phone', const Size(390, 844)),
      ('desktop', const Size(1440, 900)),
    ]) {
      testWidgets('lays out without overflow on $name', (tester) async {
        await pumpShell(
          tester,
          FakeMembersRepository(
            me: listedMe,
            members: const [robert, david],
            suggested: [
              Suggestion(
                matchId: 1,
                member: robert,
                status: 'suggested',
                reasons: const ['Also lives in Leeds', 'Close to you in age'],
                createdAt: DateTime(2026, 10, 31),
              ),
            ],
          ),
          size: size,
        );
        expect(tester.takeException(), isNull);
        await tapText(tester, 'Search');
        expect(tester.takeException(), isNull);
        await tapText(tester, 'Me');
        expect(tester.takeException(), isNull);
        await tapText(tester, 'Discover');
        await tapText(tester, 'Robert, ${DateTime.now().year - 1959}');
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Routing', () {
    testWidgets('signed-in members land on /app/discover', (tester) async {
      await pumpShell(tester, FakeMembersRepository(me: listedMe));

      expect(currentPath(tester), '/app/discover');
      await tapText(tester, 'Search');
      expect(currentPath(tester), '/app/search');
      await tapText(tester, 'Me');
      expect(currentPath(tester), '/app/me');
    });

    testWidgets('signed-out visitors are sent from /app to sign in', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        WidowdApp(
          auth: newAuth(),
          repository: FakeMembersRepository.new,
          session: AuthSession.fixed(),
          landingVideos: false,
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/app/search');
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/sign-in');
      expect(find.text('Sign in to widowd'), findsOneWidget);
    });

    testWidgets('a profile link loads the member by id', (tester) async {
      await pumpShell(
        tester,
        FakeMembersRepository(me: listedMe, members: const [robert]),
      );
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/app/members/robert');
      await tester.pumpAndSettle();

      expect(
        find.text('Retired teacher who loves walking the Dales.'),
        findsOneWidget,
      );

      // With nothing to go back to, Back returns to Discover.
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(currentPath(tester), '/app/discover');
    });

    testWidgets('an unknown profile link explains itself', (tester) async {
      await pumpShell(tester, FakeMembersRepository(me: listedMe));
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/app/members/nobody');
      await tester.pumpAndSettle();

      expect(find.text('This profile isn’t available'), findsOneWidget);
    });
  });
}
