import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'members/members_repository.dart';
import 'ui/app_theme.dart';

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

/// Error reporting is off unless a DSN is given at build time with
/// --dart-define=SENTRY_DSN=...
const sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Which environment this build talks to, as reported to Sentry.
const appEnvironment = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean web URLs (/app/search rather than /#/app/search).
  usePathUrlStrategy();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  final app = WidowdApp(auth: Supabase.instance.client.auth);
  if (sentryDsn.isEmpty) {
    runApp(app);
  } else {
    await SentryFlutter.init((options) {
      options.dsn = sentryDsn;
      options.environment = appEnvironment;
      // No names, emails or IP addresses leave the app.
      options.sendDefaultPii = false;
    }, appRunner: () => runApp(app));
  }
}

class WidowdApp extends StatelessWidget {
  const WidowdApp({
    super.key,
    required this.auth,
    this.repository,
    this.session,
    this.landingVideos = true,
  });

  final GoTrueClient auth;

  /// Overrides the Supabase-backed members data layer, for tests.
  final MembersRepository Function()? repository;

  /// Overrides who is signed in, for tests.
  final AuthSession? session;

  /// Plays the landing page's screen recordings; tests turn this off.
  final bool landingVideos;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        authClientProvider.overrideWithValue(auth),
        membersRepositoryProvider.overrideWith(
          (ref) =>
              repository?.call() ??
              SupabaseMembersRepository(Supabase.instance.client),
        ),
        if (session != null) authSessionProvider.overrideWithValue(session!),
        landingVideosEnabledProvider.overrideWithValue(landingVideos),
      ],
      child: const _RouterApp(),
    );
  }
}

class _RouterApp extends ConsumerWidget {
  const _RouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'widowd',
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
