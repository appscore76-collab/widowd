import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../landing/landing_style.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';
import '../ui/welcome_layout.dart';

/// Where Supabase sends members back to after Google, Apple, a confirmation
/// email or a password-reset email. On the web that's whichever site is
/// running (widowd.pages.dev, a preview deploy or localhost), and each one
/// must be in the project's redirect URL allow list.
String? get authRedirectUrl => kIsWeb ? Uri.base.origin : null;

enum _Mode { signIn, signUp }

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    required this.auth,
    this.startWithSignUp = false,
    this.onBack,
  });

  final GoTrueClient auth;

  /// Opens on account creation instead of sign-in.
  final bool startWithSignUp;

  /// Returns to the landing page.
  final VoidCallback? onBack;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late _Mode _mode = widget.startWithSignUp ? _Mode.signUp : _Mode.signIn;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Something went wrong. Check your connection and try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final password = _password.text;
    await _run(() async {
      if (_mode == _Mode.signIn) {
        await widget.auth.signInWithPassword(email: email, password: password);
      } else {
        final response = await widget.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: authRedirectUrl,
        );
        // With email confirmation on, there's no session until the member
        // follows the link in the email.
        if (response.session == null) {
          _notice = 'Check $email for a link to confirm your account.';
        }
      }
    });
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!_isEmail(email)) {
      setState(() {
        _error = 'Enter your email address above, then tap "Forgot password?"';
        _notice = null;
      });
      return;
    }
    await _run(() async {
      await widget.auth.resetPasswordForEmail(
        email,
        redirectTo: authRedirectUrl,
      );
      _notice =
          'If $email has an account, a link to reset the password '
          'is on its way.';
    });
  }

  Future<void> _oauth(OAuthProvider provider) => _run(() async {
    await widget.auth.signInWithOAuth(
      provider,
      redirectTo: authRedirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  });

  static bool _isEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  @override
  Widget build(BuildContext context) {
    final signingUp = _mode == _Mode.signUp;

    return WelcomeLayout(
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  signingUp ? 'Create your account' : 'Sign in to widowd',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: .center,
                ),
              ),
              const SizedBox(height: 20),
              _ProviderButton(
                onPressed: _busy ? null : () => _oauth(OAuthProvider.google),
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
              ),
              const SizedBox(height: 12),
              _ProviderButton(
                onPressed: _busy ? null : () => _oauth(OAuthProvider.apple),
                icon: Icons.apple,
                label: 'Continue with Apple',
                dark: true,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or with email',
                      style: jakarta(13, weight: 600, color: AppColors.muted),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: (value) => _isEmail(value?.trim() ?? '')
                    ? null
                    : 'Enter a valid email address',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                autofillHints: [
                  signingUp
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                onFieldSubmitted: (_) => _busy ? null : _submit(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your password';
                  }
                  if (signingUp && value.length < 8) {
                    return 'Use at least 8 characters';
                  }
                  return null;
                },
              ),
              if (!signingUp)
                Align(
                  alignment: .centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                )
              else
                const SizedBox(height: 16),
              if (_error != null) ...[
                FormMessage(_error!),
                const SizedBox(height: 12),
              ],
              if (_notice != null) ...[
                FormMessage(_notice!, isError: false),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(signingUp ? 'Create account' : 'Sign in'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _mode = signingUp ? _Mode.signIn : _Mode.signUp;
                        _error = null;
                        _notice = null;
                      }),
                child: Text(
                  signingUp
                      ? 'Already have an account? Sign in'
                      : 'New to widowd? Create an account',
                  style: jakarta(
                    15,
                    weight: 600,
                    color: AppColors.teal,
                  ).copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Continue with Google" (white) and "Continue with Apple" (black).
class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.dark = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return SizedBox(
      height: 56,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: dark ? 22 : 30, color: fg),
        label: Text(label, style: jakarta(17, weight: 600, color: fg)),
        style: TextButton.styleFrom(
          backgroundColor: dark ? Colors.black : Colors.white,
          foregroundColor: fg,
          shape: StadiumBorder(
            side: dark
                ? BorderSide.none
                : const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}
