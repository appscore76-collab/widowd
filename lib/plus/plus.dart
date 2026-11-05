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
            const SizedBox(height: 12),
            for (final line in const [
              'Like back to match, and see each other’s photos',
              'Message, video call and plan a date',
              'Anyone you like can like you back free',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        line,
                        style: jakarta(14, color: AppColors.ink, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Plans and payment are coming soon — we’ll let you know the moment '
              'it’s ready.',
              style: jakarta(13, color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('See plans'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    ),
  );
}
