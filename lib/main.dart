import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_gate.dart';

// The publishable key is safe to ship in the app; row-level security decides
// what each member can read and write. Defaults point at widowd-dev; build
// against another project with
//   --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://gzgrbbeohcerznezawna.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_vd3Dbxz9k39gx976DbJ1cg_y67vdSqU',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(WidowdApp(auth: Supabase.instance.client.auth));
}

class WidowdApp extends StatelessWidget {
  const WidowdApp({super.key, required this.auth});

  final GoTrueClient auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'widowd',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: AuthGate(auth: auth),
    );
  }
}
