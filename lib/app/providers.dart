import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../members/member.dart';
import '../members/members_repository.dart';

/// Supabase Auth. Overridden in [WidowdApp] (and in tests).
final authClientProvider = Provider<GoTrueClient>(
  (ref) => throw UnimplementedError('authClientProvider is not overridden'),
);

/// The members data layer. Overridden in [WidowdApp] (and in tests).
final membersRepositoryProvider = Provider<MembersRepository>(
  (ref) =>
      throw UnimplementedError('membersRepositoryProvider is not overridden'),
);

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
