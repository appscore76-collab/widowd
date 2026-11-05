import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../chat/chat_repository.dart';
import '../members/member.dart';
import '../members/members_repository.dart';
import '../push/push_service.dart';

/// Supabase Auth. Overridden in [WidowdApp] (and in tests).
final authClientProvider = Provider<GoTrueClient>(
  (ref) => throw UnimplementedError('authClientProvider is not overridden'),
);

/// The members data layer. Overridden in [WidowdApp] (and in tests).
final membersRepositoryProvider = Provider<MembersRepository>(
  (ref) =>
      throw UnimplementedError('membersRepositoryProvider is not overridden'),
);

/// Members the signed-in member has liked. Drives the "blurred until you like
/// them" photo unlock across Discover, Search and profiles, and updates
/// instantly when a like happens.
final likedIdsProvider = NotifierProvider<LikedIdsNotifier, Set<String>>(
  LikedIdsNotifier.new,
);

class LikedIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    try {
      state = await ref.read(membersRepositoryProvider).likedMemberIds();
    } catch (_) {
      // Keep whatever we have; photos just stay blurred until a reload.
    }
  }

  /// Records a like locally so the member's photo unlocks immediately.
  void add(String id) => state = {...state, id};

  /// Undoes a local like (e.g. when a like-back turned out to need Plus).
  void remove(String id) => state = {...state}..remove(id);
}

/// Whether the signed-in member has active Widowd Plus. Loads in the
/// background; defaults to false (and for tests without the RPC).
final plusStatusProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.read(membersRepositoryProvider).myPlusStatus();
  } catch (_) {
    return false;
  }
});

/// How many people have liked the signed-in member, for the Discover "Likes
/// you" badge. Loads in the background; failures leave it at 0.
final likesYouCountProvider =
    NotifierProvider<LikesYouCountNotifier, int>(LikesYouCountNotifier.new);

class LikesYouCountNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    try {
      state = (await ref.read(membersRepositoryProvider).likers()).length;
    } catch (_) {
      // Keep the current count; the badge just doesn't update this time.
    }
  }

  /// Recomputes the badge, e.g. after acting on a liker.
  Future<void> refresh() => _load();
}

/// The chat data layer. Overridden in [WidowdApp] (and in tests).
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => throw UnimplementedError('chatRepositoryProvider is not overridden'),
);

/// Members the signed-in member is matched with, mapped to their conversation
/// id. Drives both the photo unlock (a match reveals the photo, like a like
/// does) and the "Message" shortcut from Discover and profiles. Loads in the
/// background; failures (and tests without a chat repository) leave it empty.
final matchedConversationsProvider =
    NotifierProvider<MatchedConversationsNotifier, Map<String, int>>(
      MatchedConversationsNotifier.new,
    );

class MatchedConversationsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    try {
      final conversations = await ref
          .read(chatRepositoryProvider)
          .conversations();
      state = {for (final c in conversations) c.peer.id: c.id};
    } catch (_) {
      // Keep what we have; photos just stay as they are until a reload.
    }
  }

  /// Reloads after a new match (so the new conversation is known).
  Future<void> refresh() => _load();
}

/// Total unread messages across all conversations, for the Chats tab badge.
/// Starts at 0 and loads in the background; failures leave it at 0 so the app
/// (and tests without a chat repository) keep working.
final totalUnreadProvider = NotifierProvider<TotalUnreadNotifier, int>(
  TotalUnreadNotifier.new,
);

class TotalUnreadNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    try {
      final conversations = await ref
          .read(chatRepositoryProvider)
          .conversations();
      state = conversations.fold(0, (sum, c) => sum + c.unreadCount);
    } catch (_) {
      // Keep the current count; the badge just doesn't update this time.
    }
  }

  /// Recomputes the badge, e.g. after opening or reading a conversation.
  Future<void> refresh() => _load();
}

/// Keeps this device's FCM token saved for the signed-in member.
final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref.watch(membersRepositoryProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Who is signed in, and whether they arrived from a password-reset link.
/// The router listens to it to decide which pages can be shown.
final authSessionProvider = Provider<AuthSession>((ref) {
  final session = AuthSession(ref.watch(authClientProvider));
  ref.onDispose(session.dispose);
  return session;
});

/// The signed-in member's own profile. Reloads when a different member
/// signs in; call `ref.invalidate(myProfileProvider)` after saving.
final myProfileProvider = FutureProvider<Member?>((ref) {
  final session = ref.watch(authSessionProvider);
  var userId = session.userId;
  void onChange() {
    if (session.userId != userId) {
      userId = session.userId;
      ref.invalidateSelf();
    }
  }

  session.addListener(onChange);
  ref.onDispose(() => session.removeListener(onChange));
  if (userId == null) return Future.value(null);
  return ref.read(membersRepositoryProvider).myProfile();
});

class AuthSession extends ChangeNotifier {
  AuthSession(GoTrueClient auth) : userId = auth.currentUser?.id {
    _subscription = auth.onAuthStateChange.listen(
      (state) {
        final nextUser = state.session?.user.id;
        var nextRecovering = recovering;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          nextRecovering = true;
        } else if (state.event == AuthChangeEvent.userUpdated ||
            state.event == AuthChangeEvent.signedOut) {
          nextRecovering = false;
        }
        if (nextUser != userId || nextRecovering != recovering) {
          userId = nextUser;
          recovering = nextRecovering;
          notifyListeners();
        }
      },
      // Errors from a bad or expired sign-in link arrive here; the visitor
      // simply stays signed out.
      onError: (Object error) => debugPrint('Auth error: $error'),
    );
  }

  /// A session that never changes, for tests.
  AuthSession.fixed({this.userId, this.recovering = false});

  StreamSubscription<AuthState>? _subscription;

  String? userId;
  bool recovering = false;

  bool get signedIn => userId != null;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
