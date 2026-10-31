import 'package:flutter/material.dart';

import 'member.dart';
import 'member_widgets.dart';

/// A member's full profile.
class MemberDetailPage extends StatelessWidget {
  const MemberDetailPage({super.key, required this.member, this.reasons});

  final Member member;

  /// Why the system suggested this member, when opened from a suggestion.
  final List<String>? reasons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bio = member.bio?.trim();
    return Scaffold(
      appBar: AppBar(title: Text(member.displayName ?? 'Member')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: MemberPhoto(
                    member: member,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  memberHeadline(member),
                  style: theme.textTheme.headlineSmall,
                ),
                if (member.city != null && member.city!.isNotEmpty)
                  Text(member.city!, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                VerificationBadges(member: member),
                if (reasons != null && reasons!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Why we suggested', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in reasons!) Chip(label: Text(r)),
                    ],
                  ),
                ],
                if (bio != null && bio.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('About', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(bio, style: theme.textTheme.bodyLarge),
                ],
                if (member.interestedIn.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Interested in', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(member.interestedIn.map(genderPluralLabel).join(', ')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
