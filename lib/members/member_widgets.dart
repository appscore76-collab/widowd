import 'package:flutter/material.dart';

import 'member.dart';
import 'member_detail_page.dart';

/// A member's photo, or their initial while it loads or if there isn't one.
class MemberPhoto extends StatelessWidget {
  const MemberPhoto({super.key, required this.member, this.borderRadius});

  final Member member;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.secondaryContainer,
      child: Center(
        child: Text(
          (member.displayName ?? '?').characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
    final url = member.photoUrl;
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: url == null
          ? placeholder
          : Image.network(
              url,
              fit: BoxFit.cover,
              semanticLabel: 'Photo of ${member.displayName ?? 'member'}',
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : placeholder,
            ),
    );
  }
}

/// "ID verified" and "Photo verified" badges.
class VerificationBadges extends StatelessWidget {
  const VerificationBadges({super.key, required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    if (!member.idVerified && !member.photoVerified) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (member.idVerified)
          const _Badge(icon: Icons.verified_user_outlined, label: 'ID verified'),
        if (member.photoVerified)
          const _Badge(icon: Icons.face_outlined, label: 'Photo verified'),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(icon, size: 14, color: scheme.onTertiaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Margaret, 62" with the city underneath.
String memberHeadline(Member m) =>
    [m.displayName ?? 'Member', if (m.age != null) '${m.age}'].join(', ');

/// A photo card that opens the member's profile.
class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.member,
    this.reasons,
    this.footer,
  });

  final Member member;

  /// Why the system suggested this member, shown on their profile.
  final List<String>? reasons;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                MemberDetailPage(member: member, reasons: reasons),
          ),
        ),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            AspectRatio(aspectRatio: 1, child: MemberPhoto(member: member)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    memberHeadline(member),
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                  if (member.city != null && member.city!.isNotEmpty)
                    Text(
                      member.city!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                  if (member.idVerified || member.photoVerified) ...[
                    const SizedBox(height: 8),
                    VerificationBadges(member: member),
                  ],
                  if (footer != null) ...[const SizedBox(height: 8), footer!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered message for empty and error states.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: .min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: .center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: .center),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
  }
}
