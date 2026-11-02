import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../landing/landing_style.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';
import 'member.dart';

/// A member's photo, or a person outline while it loads or if there isn't one.
///
/// When [locked], the photo is blurred with a lock overlay — the "blurred
/// until you like them" rule. Liking a member clears it.
class MemberPhoto extends StatelessWidget {
  const MemberPhoto({
    super.key,
    required this.member,
    this.borderRadius,
    this.locked = false,
  });

  final Member member;
  final BorderRadius? borderRadius;
  final bool locked;

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
    Widget image = url == null
        ? placeholder
        : Image.network(
            url,
            fit: BoxFit.cover,
            semanticLabel: locked
                ? null
                : 'Photo of ${member.displayName ?? 'member'}',
            excludeFromSemantics: locked,
            errorBuilder: (_, _, _) => placeholder,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : placeholder,
          );
    if (locked) {
      image = Semantics(
        label: 'Photo hidden — like to view',
        image: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url == null)
              placeholder
            else
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: image,
              ),
            const ColoredBox(color: Color(0x1A0F1614)),
            LayoutBuilder(
              builder: (context, c) => Center(
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: (c.biggest.shortestSide * 0.32).clamp(16.0, 48.0),
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: image,
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
