import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../landing/landing_page.dart';
import '../members/home_shell.dart';
import '../members/members_repository.dart';
import 'reset_password_page.dart';
import 'sign_in_page.dart';

/// Shows the landing and sign-in pages to signed-out visitors and the app to
/// members.
///
/// A password-reset link signs the member in with a recovery session, so the
/// gate asks for a new password before letting them into the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth, required this.repository});

  final GoTrueClient auth;

  /// Builds the members data layer once someone is signed in.
  final MembersRepository Function() repository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Session? _session = widget.auth.currentSession;
  bool _recovering = false;

  /// Which sign-in screen a signed-out visitor chose from the landing page;
  /// null shows the landing page.
  bool? _signUp;
  MembersRepository? _repository;
  late final StreamSubscription<AuthState> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.auth.onAuthStateChange.listen(
      (state) {
        setState(() {
          _session = state.session;
          if (_session == null) {
            _repository = null;
          } else {
            _signUp = null;
          }
          if (state.event == AuthChangeEvent.passwordRecovery) {
            _recovering = true;
          } else if (state.event == AuthChangeEvent.userUpdated ||
              state.event == AuthChangeEvent.signedOut) {
            _recovering = false;
          }
        });
      },
      // Errors from a bad or expired sign-in link arrive here; the visitor
      // simply stays on the sign-in page.
      onError: (Object error) => debugPrint('Auth error: $error'),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      final signUp = _signUp;
      if (signUp == null) {
        return LandingPage(
          onJoin: () => setState(() => _signUp = true),
          onSignIn: () => setState(() => _signUp = false),
        );
      }
      return SignInPage(
        // A new key resets the form when switching between the two buttons.
        key: ValueKey(signUp),
        auth: widget.auth,
        startWithSignUp: signUp,
        onBack: () => setState(() => _signUp = null),
      );
    }
    if (_recovering) return ResetPasswordPage(auth: widget.auth);
    return HomeShell(
      // A different account gets a fresh shell and fresh data.
      key: ValueKey(_session!.user.id),
      auth: widget.auth,
      repository: _repository ??= widget.repository(),
    );
  }
}
