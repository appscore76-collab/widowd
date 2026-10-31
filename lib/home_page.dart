import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Placeholder for the signed-in app.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.auth});

  final GoTrueClient auth;

  @override
  Widget build(BuildContext context) {
    final email = auth.currentUser?.email;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('widowd'),
        actions: [
          TextButton(onPressed: auth.signOut, child: const Text('Sign out')),
        ],
      ),
      body: Center(
        child: Text(
          email == null ? 'You are signed in.' : 'Signed in as $email',
        ),
      ),
    );
  }
}
