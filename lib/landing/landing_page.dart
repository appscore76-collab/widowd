import 'package:flutter/material.dart';

/// The public front page for signed-out visitors.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key, required this.onJoin, required this.onSignIn});

  /// Opens account creation.
  final VoidCallback onJoin;

  /// Opens sign-in for existing members.
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            _Section(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.spa_outlined, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'widowd',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: onSignIn, child: const Text('Sign in')),
                ],
              ),
            ),
            // Hero
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [scheme.primaryContainer, scheme.surface],
                ),
              ),
              child: _Section(
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 72),
                child: Column(
                  children: [
                    Text(
                      'Companionship, when you are ready',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: .center,
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        'widowd is a dating community for widows and '
                        'widowers. Meet people who understand what you have '
                        'been through, at your own pace.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                        textAlign: .center,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: .center,
                      children: [
                        FilledButton(
                          onPressed: onJoin,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 18,
                            ),
                          ),
                          child: const Text('Join free'),
                        ),
                        OutlinedButton(
                          onPressed: onSignIn,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 18,
                            ),
                          ),
                          child: const Text('I already have an account'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // How it works
            _Section(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
              child: Column(
                children: [
                  Text(
                    'How it works',
                    style: theme.textTheme.headlineSmall,
                    textAlign: .center,
                  ),
                  const SizedBox(height: 24),
                  const _ResponsiveRow(
                    children: [
                      _Step(
                        icon: Icons.person_add_alt_outlined,
                        title: 'Create your profile',
                        body:
                            'Add a photo and a little about yourself. Only '
                            'your first name, age and town are shown.',
                      ),
                      _Step(
                        icon: Icons.people_outline,
                        title: 'Browse members',
                        body:
                            'Look through profiles of other widowed people '
                            'whenever you like.',
                      ),
                      _Step(
                        icon: Icons.auto_awesome_outlined,
                        title: 'Get suggestions',
                        body:
                            'Each day we suggest people who could be a good '
                            'fit, based on age, location and who you are '
                            'each looking for.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Free and Plus
            ColoredBox(
              color: scheme.surfaceContainerLow,
              child: _Section(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 48,
                ),
                child: Column(
                  children: [
                    Text(
                      'Free to join',
                      style: theme.textTheme.headlineSmall,
                      textAlign: .center,
                    ),
                    const SizedBox(height: 24),
                    const _ResponsiveRow(
                      children: [
                        _Plan(
                          name: 'Free',
                          highlighted: true,
                          features: [
                            'A profile with your photo',
                            'Browse members',
                            'Daily match suggestions',
                          ],
                        ),
                        _Plan(
                          name: 'Plus',
                          features: [
                            'Everything in Free',
                            'Private video calls with your matches',
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: onJoin,
                      child: const Text('Create your free profile'),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            _Section(
              padding: const EdgeInsets.all(24),
              child: Text(
                '© ${DateTime.now().year} widowd',
                style: theme.textTheme.bodySmall,
                textAlign: .center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centers content at a readable width.
class _Section extends StatelessWidget {
  const _Section({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Side by side on wide screens, stacked on phones.
class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: .stretch,
            children: [
              for (final (i, c) in children.indexed) ...[
                if (i > 0) const SizedBox(height: 16),
                c,
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: .stretch,
            children: [
              for (final (i, c) in children.indexed) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: c),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body),
          ],
        ),
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({
    required this.name,
    required this.features,
    this.highlighted = false,
  });

  final String name;
  final List<String> features;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: highlighted ? scheme.primaryContainer : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: highlighted ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Text(name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: .start,
                  children: [
                    Icon(Icons.check, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
