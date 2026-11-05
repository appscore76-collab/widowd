import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/reset_password_page.dart';
import '../auth/sign_in_page.dart';
import '../chat/chat_page.dart';
import '../chat/chats_page.dart';
import '../landing/landing_page.dart';
import '../members/browse_page.dart';
import '../members/home_shell.dart';
import '../members/likes_you_page.dart';
import '../members/member.dart';
import '../members/member_detail_page.dart';
import '../members/my_profile_page.dart';
import '../members/suggestions_page.dart';
import 'providers.dart';

/// Paths in the app, so pages link to each other without string typos.
abstract final class AppPaths {
  static const landing = '/';
  static const signIn = '/sign-in';
  static const join = '/join';
  static const resetPassword = '/reset-password';
  static const discover = '/app/discover';
  static const search = '/app/search';
  static const chats = '/app/chats';
  static const me = '/app/me';
  static const likesYou = '/app/likes';
  static String member(String id) => '/app/members/$id';
  static String chat(int conversationId) => '/app/chat/$conversationId';
}

/// What a member page was opened with, so it can show without reloading.
class MemberRouteArgs {
  const MemberRouteArgs(this.member, {this.reasons});

  final Member member;
  final List<String>? reasons;
}

/// What a chat page was opened with, so it can show the peer straight away.
class ChatRouteArgs {
  const ChatRouteArgs({required this.conversationId, required this.peer});

  final int conversationId;
  final Member peer;
}

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authSessionProvider);
  final router = GoRouter(
    initialLocation: AppPaths.landing,
    refreshListenable: session,
    redirect: (context, state) => _redirect(session, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppPaths.landing,
        builder: (context, state) => LandingPage(
          onJoin: () => context.go(AppPaths.join),
          onSignIn: () => context.go(AppPaths.signIn),
          videosEnabled: ref.read(landingVideosEnabledProvider),
        ),
      ),
      for (final (path, signUp) in [
        (AppPaths.signIn, false),
        (AppPaths.join, true),
      ])
        GoRoute(
          path: path,
          builder: (context, state) => SignInPage(
            key: ValueKey(signUp),
            auth: ref.read(authClientProvider),
            startWithSignUp: signUp,
            onBack: () => context.go(AppPaths.landing),
          ),
        ),
      GoRoute(
        path: AppPaths.resetPassword,
        builder: (context, state) =>
            ResetPasswordPage(auth: ref.read(authClientProvider)),
      ),
      GoRoute(path: '/app', redirect: (_, _) => AppPaths.discover),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.discover,
                builder: (context, state) => SuggestionsPage(
                  repository: ref.read(membersRepositoryProvider),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.search,
                builder: (context, state) =>
                    BrowsePage(repository: ref.read(membersRepositoryProvider)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.chats,
                builder: (context, state) =>
                    ChatsPage(repository: ref.read(chatRepositoryProvider)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.me,
                builder: (context, state) => const MyProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/app/chat/:id',
        builder: (context, state) {
          final args = state.extra is ChatRouteArgs
              ? state.extra! as ChatRouteArgs
              : null;
          return ChatPage(
            repository: ref.read(chatRepositoryProvider),
            conversationId: int.parse(state.pathParameters['id']!),
            peer: args?.peer,
          );
        },
      ),
      GoRoute(
        path: AppPaths.likesYou,
        builder: (context, state) =>
            LikesYouPage(repository: ref.read(membersRepositoryProvider)),
      ),
      GoRoute(
        path: '/app/members/:id',
        builder: (context, state) {
          final args = state.extra is MemberRouteArgs
              ? state.extra! as MemberRouteArgs
              : null;
          return MemberDetailPage(
            memberId: state.pathParameters['id']!,
            member: args?.member,
            reasons: args?.reasons,
          );
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Whether the landing page plays its screen recordings. Tests turn it off.
final landingVideosEnabledProvider = Provider<bool>((ref) => true);

const _signedOutOnly = {AppPaths.landing, AppPaths.signIn, AppPaths.join};

String? _redirect(AuthSession session, String location) {
  // A password-reset link signs the member in with a recovery session, so
  // they choose a new password before anything else.
  if (session.recovering) {
    return location == AppPaths.resetPassword ? null : AppPaths.resetPassword;
  }
  if (session.signedIn) {
    if (_signedOutOnly.contains(location) ||
        location == AppPaths.resetPassword) {
      return AppPaths.discover;
    }
    return null;
  }
  if (location.startsWith('/app') || location == AppPaths.resetPassword) {
    return AppPaths.signIn;
  }
  return null;
}
