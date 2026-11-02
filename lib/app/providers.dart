import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
