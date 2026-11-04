import 'package:flutter/material.dart';

import '../landing/landing_style.dart';
import '../ui/app_theme.dart';

/// Widowd Plus upsell. Messaging, video dates and other premium features are
/// gated behind Plus (design screen 17). The full paywall and payments land in
/// a later phase; for now this explains the feature and that it's coming.
Future<void> showPlusSheet(
  BuildContext context, {
  required String feature,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.sandText,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Widowd Plus', style: jakarta(20, weight: 800)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '$feature is part of Widowd Plus.',
              style: jakarta(16, weight: 700),
            ),
            const SizedBox(height: 8),
            Text(
              'Plus also unlocks who likes you, verified-only search and video '
              'dates. Plans and payment are coming soon — we’ll let you know '
              'the moment it’s ready.',
              style: jakarta(14, color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    ),
  );
}
