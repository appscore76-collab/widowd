import 'package:flutter/material.dart';

import '../landing/landing_style.dart';
import 'app_theme.dart';

/// The teal Welcome screen from the app design, with a white card holding
/// the page's form. Used by sign-in, account creation and password reset.
class WelcomeLayout extends StatelessWidget {
  const WelcomeLayout({
    super.key,
    required this.child,
    this.onBack,
    this.showTagline = true,
  });

  final Widget child;
  final VoidCallback? onBack;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.teal,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: WidowdRings(
                          width: 96,
                          left: AppColors.gold,
                          right: Colors.white,
                          strokeWidth: 5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'widowd',
                        textAlign: TextAlign.center,
                        style: jakarta(
                          44,
                          weight: 800,
                          color: Colors.white,
                          letterSpacingEm: -1.5 / 48,
                        ),
                      ),
                      if (showTagline) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Love again, at your own pace.',
                          textAlign: TextAlign.center,
                          style: jakarta(
                            20,
                            weight: 600,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: child,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'By continuing you agree to our Terms and Privacy '
                        'Policy. Members must be 18+.',
                        textAlign: TextAlign.center,
                        style: jakarta(
                          12,
                          color: AppColors.onTeal,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onBack != null)
              Positioned(
                left: 8,
                top: 8,
                child: IconButton(
                  onPressed: onBack,
                  tooltip: 'Back',
                  icon: const Icon(Icons.chevron_left_rounded, size: 30),
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
