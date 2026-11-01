import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../landing/landing_style.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';
import 'member.dart';

/// A member's photo, or a person outline while it loads or if there isn't one.
class MemberPhoto extends StatelessWidget {
  const MemberPhoto({super.key, required this.member, this.borderRadius});

  final Member member;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = LayoutBuilder(
      builder: (context, constraints) => ColoredBox(
        color: AppColors.photoTint,
        child: Center(
          child: Icon(
            Icons.person_outline_rounded,
            size: constraints.biggest.shortestSide * 0.6,
            color: AppColors.photoIcon,
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

/// "Photo verified" and "ID checked" tags, or nothing.
class BadgeRow extends StatelessWidget {
  const BadgeRow({super.key, required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    if (!member.idVerified && !member.photoVerified) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        if (member.photoVerified) const PhotoVerifiedTag(),
        if (member.idVerified) const IdCheckedTag(),
      ],
    );
  }
}

/// "Margaret, 58".
String memberHeadline(Member m) =>
    [m.displayName ?? 'Member', if (m.age != null) '${m.age}'].join(', ');

/// "Chester · Woman · Interested in men".
String memberMeta(Member m) => [
  if (m.city != null && m.city!.trim().isNotEmpty) m.city!.trim(),
  if (m.gender != null) genderLabel(m.gender!),
  if (m.interestedIn.isNotEmpty)
    'Interested in ${m.interestedIn.map(genderPluralLabel).join(', ').toLowerCase()}',
].join(' · ');

void openMember(BuildContext context, Member member, {List<String>? reasons}) {
  context.push(
    AppPaths.member(member.id),
    extra: MemberRouteArgs(member, reasons: reasons),
  );
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.tealTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: AppColors.teal),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: jakarta(20, weight: 800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: jakarta(15, color: AppColors.muted, height: 1.5),
              ),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}
