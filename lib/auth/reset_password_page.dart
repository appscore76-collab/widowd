import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shown after a member follows a password-reset link.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.auth});

  final GoTrueClient auth;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Fires userUpdated, which takes the gate on to the app.
      await widget.auth.updateUser(UserAttributes(password: _password.text));
    } on AuthException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Something went wrong. Check your connection and try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  Text(
                    'Choose a new password',
                    style: theme.textTheme.headlineSmall,
                    textAlign: .center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _busy ? null : _save(),
                    validator: (value) => (value ?? '').length < 8
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: const Text('Save password'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : widget.auth.signOut,
                    child: const Text('Cancel and sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
