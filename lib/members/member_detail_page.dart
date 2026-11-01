import 'package:flutter/material.dart';

import '../landing/landing_style.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';
import 'member.dart';
import 'member_widgets.dart';

/// A member's full profile: photo on top, details on a rounded sheet.
class MemberDetailPage extends StatelessWidget {
  const MemberDetailPage({super.key, required this.member, this.reasons});

  final Member member;

  /// Why the system suggested this member, when opened from a suggestion.
  final List<String>? reasons;

  @override
  Widget build(BuildContext context) {
    final bio = member.bio?.trim();
    final city = member.city?.trim();
    // Badges already show above, so leave them out of the reasons.
    final reasons = this.reasons
        ?.where((r) => r != 'ID verified' && r != 'Photo verified')
        .toList();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            memberHeadline(member),
            style: jakarta(26, weight: 800, letterSpacingEm: -0.4 / 26),
          ),
        ),
        if (city != null && city.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(city, style: jakarta(14, color: AppColors.muted)),
        ],
        if (member.photoVerified || member.idVerified) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              if (member.photoVerified)
                const Expanded(
                  child: _BadgeCard(
                    icon: Icons.verified_rounded,
                    iconColor: AppColors.verifiedIcon,
                    title: 'Photo verified',
                    note: 'Selfie matches photos',
                    background: AppColors.verifiedBg,
                    titleColor: AppColors.verifiedTextDark,
                    noteColor: AppColors.verifiedText,
                  ),
                ),
              if (member.photoVerified && member.idVerified)
                const SizedBox(width: 8),
              if (member.idVerified)
                const Expanded(
                  child: _BadgeCard(
                    icon: Icons.badge_outlined,
                    iconColor: AppColors.teal,
                    title: 'ID checked',
                    note: 'Real name & age',
                    background: AppColors.tealTint,
                    titleColor: AppColors.tealDark,
                    noteColor: AppColors.teal,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  label: 'Age',
                  value: member.age?.toString() ?? '–',
                  note: member.birthYear == null
                      ? null
                      : 'Born ${member.birthYear}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Gender',
                  value: member.gender == null
                      ? '–'
                      : genderLabel(member.gender!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Looking for',
                  value: member.interestedIn.isEmpty
                      ? '–'
                      : member.interestedIn.map(genderPluralLabel).join(', '),
                ),
              ),
            ],
          ),
        ),
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: 14),
          InfoBox(label: 'About me', text: bio, outlined: true),
        ],
        if (reasons != null && reasons.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Why we suggested ${member.displayName ?? 'them'}',
            style: jakarta(14, weight: 700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final r in reasons) Tag.sand(r, size: 13)],
          ),
        ],
        const SizedBox(height: 32),
      ],
    );

    final backButton = Padding(
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          color: AppColors.ink,
        ),
      ),
    );

    if (wide) {
      // Photo beside the details on desktop.
      return Scaffold(
        backgroundColor: AppColors.mist,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Back'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 420,
                          child: AspectRatio(
                            aspectRatio: 4 / 5,
                            child: MemberPhoto(
                              member: member,
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: AppCard(
                            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                            radius: 28,
                            child: details,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Stack(
              children: [
                SizedBox(
                  height: 360,
                  width: double.infinity,
                  child: MemberPhoto(member: member),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 336),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                    child: details,
                  ),
                ),
                SafeArea(child: backButton),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.note,
    required this.background,
    required this.titleColor,
    required this.noteColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String note;
  final Color background;
  final Color titleColor;
  final Color noteColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: jakarta(13, weight: 800, color: titleColor)),
              Text(note, style: jakarta(11, color: noteColor)),
            ],
          ),
        ),
      ],
    ),
  );
}
