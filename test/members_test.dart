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

  /// Members whose id is in here will produce a match when liked.
  final Set<String> reciprocalLikers = {};

  /// Members the signed-in member has already matched with (Matched filter).
  final Set<String> matchedIds = {};
  final List<String> liked = [];
  final List<String> passed = [];

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
        .where((m) => !filter.matched || matchedIds.contains(m.id))
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
  Future<List<Suggestion>> suggestions({int offset = 0, int limit = 24}) async =>
      suggested
          .where((s) => s.status == 'suggested')
          .skip(offset)
          .take(limit)
          .toList();

  final savedTokens = <String>[];

  @override
  Future<bool> likeMember(String id) async {
    liked.add(id);
    return reciprocalLikers.contains(id);
  }

  @override
  Future<void> passMember(String id) async => passed.add(id);

  @override
  Future<Set<String>> likedMemberIds() async => liked.toSet();

  @override
  Future<void> saveDeviceToken({
    required String token,
    required String platform,
  }) async => savedTokens.add('$platform:$token');

  @override
  Future<void> deleteDeviceToken(String token) async =>
      savedTokens.remove(token);
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
      expect(find.text('ID checked'), findsOneWidget);

      await tapText(tester, 'Robert, $age');

      expect(find.text('Why we suggested Robert'), findsOneWidget);
      expect(
        find.text('Retired teacher who loves walking the Dales.'),
        findsOneWidget,
      );
    });

    Future<void> pumpDiscoverWith(
      WidgetTester tester,
      FakeMembersRepository repo,
    ) => pumpShell(tester, repo);

    FakeMembersRepository repoWithRobert({Set<String> reciprocal = const {}}) {
      final r = FakeMembersRepository(
        me: listedMe,
        members: const [robert],
        suggested: [
          Suggestion(
            matchId: 1,
            member: robert,
            status: 'suggested',
            reasons: const ['Also lives in Leeds'],
            createdAt: DateTime(2026, 10, 31),
          ),
        ],
      );
      r.reciprocalLikers.addAll(reciprocal);
      return r;
    }

    testWidgets('a like alone keeps the photo locked', (tester) async {
      await pumpDiscoverWith(tester, repoWithRobert());

      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      await tapText(tester, 'Like');
      // No reciprocal like, so no match — the photo stays locked.
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('a match unlocks the photo', (tester) async {
      await pumpDiscoverWith(tester, repoWithRobert(reciprocal: {'robert'}));

      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      await tapText(tester, 'Like');
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    });

    testWidgets('Pass removes the suggestion and records it', (tester) async {
      final repo = repoWithRobert();
      await pumpDiscoverWith(tester, repo);
      final age = DateTime.now().year - 1959;
      expect(find.text('Robert, $age'), findsOneWidget);

      await tapText(tester, 'Pass');

      expect(find.text('Robert, $age'), findsNothing);
      expect(repo.passed, ['robert']);
    });

    testWidgets('Like without a reciprocal shows Liked', (tester) async {
      final repo = repoWithRobert();
      await pumpDiscoverWith(tester, repo);

      await tapText(tester, 'Like');

      expect(repo.liked, ['robert']);
      expect(find.text('Liked'), findsOneWidget);
      expect(find.textContaining('matched'), findsNothing);
    });

    testWidgets('Like with a reciprocal matches and leaves the feed', (
      tester,
    ) async {
      final repo = repoWithRobert(reciprocal: {'robert'});
      await pumpDiscoverWith(tester, repo);
      final age = DateTime.now().year - 1959;
      expect(find.text('Robert, $age'), findsOneWidget);

      await tapText(tester, 'Like');

      // A match moves out of Discover (into Matches / Chats) with a toast.
      expect(find.text('Robert, $age'), findsNothing);
      expect(find.textContaining('match with Robert'), findsOneWidget);
    });

    testWidgets('explains when there are no suggestions', (tester) async {
      await pumpShell(tester, FakeMembersRepository(me: listedMe));

      expect(find.text('No suggestions right now'), findsOneWidget);
    });

    testWidgets('Discover card trims Work to before the comma and caps '
        'interests at three', (tester) async {
      const rich = Member(
        id: 'rich',
        displayName: 'Maggie',
        birthYear: 1961,
        gender: 'woman',
        interestedIn: ['man'],
        city: 'Chester',
        occupation: 'Nurse, retired',
        interests: ['Reading', 'Walking', 'Cooking', 'Gardening', 'Travel'],
        listed: true,
      );
      await pumpShell(
        tester,
        FakeMembersRepository(
          me: listedMe,
          suggested: [
            Suggestion(
              matchId: 7,
              member: rich,
              status: 'suggested',
              reasons: const [],
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
      );

      // Work shows "Nurse", not "Nurse, retired".
      expect(find.textContaining('Nurse'), findsOneWidget);
      expect(find.textContaining('retired'), findsNothing);
      // Only the first three interests appear.
      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('Walking'), findsOneWidget);
      expect(find.text('Cooking'), findsOneWidget);
      expect(find.text('Gardening'), findsNothing);
      expect(find.text('Travel'), findsNothing);
    });

    testWidgets('Discover paginates with Show more', (tester) async {
      final many = [
        for (var i = 0; i < 13; i++)
          Suggestion(
            matchId: i,
            member: Member(
              id: 'p$i',
              displayName: 'Person$i',
              birthYear: 1960,
              gender: 'man',
              interestedIn: const ['woman'],
              listed: true,
            ),
            status: 'suggested',
            reasons: const [],
            createdAt: DateTime(2026, 1, 1),
          ),
      ];
      await pumpShell(
        tester,
        FakeMembersRepository(me: listedMe, suggested: many),
      );

      // The first page holds 12; the 13th loads only on "Show more".
      expect(find.textContaining('Person12'), findsNothing);
      await tapText(tester, 'Show more');
      expect(find.textContaining('Person12'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
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

    testWidgets('Matched filter narrows Search to matched members', (
      tester,
    ) async {
      final repo = FakeMembersRepository(
        me: listedMe,
        members: const [robert, david],
      )..matchedIds.add('david');
      await pumpShell(tester, repo);

      await tapText(tester, 'Search');
      expect(find.textContaining('Robert, '), findsOneWidget);
      expect(find.textContaining('David, '), findsOneWidget);

      await tapText(tester, 'Matched');
      expect(repo.lastFilter!.matched, isTrue);
      expect(find.textContaining('Robert, '), findsNothing);
      expect(find.textContaining('David, '), findsOneWidget);
    });

    testWidgets('Me shows the profile editor and saves', (tester) async {
      final repo = FakeMembersRepository(me: listedMe);
      // Tall enough that the (now longer) editor's save button stays on screen.
      await pumpShell(tester, repo, size: const Size(1200, 4400));

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
