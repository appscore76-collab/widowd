import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home_page.dart';
import 'reset_password_page.dart';
import 'sign_in_page.dart';

/// Shows the sign-in page to signed-out visitors and the app to members.
///
/// A password-reset link signs the member in with a recovery session, so the
/// gate asks for a new password before letting them into the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth});

  final GoTrueClient auth;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Session? _session = widget.auth.currentSession;
  bool _recovering = false;
  late final StreamSubscription<AuthState> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.auth.onAuthStateChange.listen(
      (state) {
        setState(() {
          _session = state.session;
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
    if (_session == null) return SignInPage(auth: widget.auth);
    if (_recovering) return ResetPasswordPage(auth: widget.auth);
    return HomePage(auth: widget.auth);
  }
}
