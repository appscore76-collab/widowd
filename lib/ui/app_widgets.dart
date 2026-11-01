import 'package:flutter/material.dart';

import '../landing/landing_style.dart';
import 'app_theme.dart';

/// Back arrow, progress bar and "2 of 4", from the onboarding screens.
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.step,
    required this.total,
    this.onBack,
  });

  final int step;
  final int total;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: onBack == null
              ? null
              : IconButton(
                  onPressed: onBack,
                  tooltip: 'Back',
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  color: AppColors.ink,
                ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: step / total,
              minHeight: 6,
              backgroundColor: AppColors.line,
              color: AppColors.teal,
              semanticsLabel: 'Step $step of $total',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$step of $total',
          style: jakarta(13, weight: 600, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// Large heading and supporting line at the top of a screen.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineMedium),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: jakarta(15, color: AppColors.muted, height: 1.5),
          ),
        ],
      ],
    );
  }
}

/// A full-width option card with a radio dot or checkbox, as on the
/// "What are you hoping to find?" screen.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
    this.multiple = false,
  });

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;

  /// Shows a checkbox instead of a radio dot.
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    final indicator = multiple
        ? Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: selected ? AppColors.teal : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? AppColors.teal : AppColors.radioOff,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
          )
        : Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.teal : AppColors.radioOff,
                width: selected ? 7 : 2,
              ),
            ),
          );
    return Semantics(
      checked: multiple ? selected : null,
      inMutuallyExclusiveGroup: multiple ? null : true,
      selected: multiple ? null : selected,
      button: true,
      child: Material(
        color: selected ? AppColors.tealTint : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.teal : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: jakarta(16, weight: 700)),
                        if (hint != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            hint!,
                            style: jakarta(13, color: AppColors.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  indicator,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small rounded tag.
class Tag extends StatelessWidget {
  const Tag(
    this.text, {
    super.key,
    this.background = AppColors.tealTint,
    this.color = AppColors.teal,
    this.icon,
    this.size = 12,
  });

  /// A sand-colored interest or reason tag.
  const Tag.sand(this.text, {super.key, this.icon, this.size = 12})
    : background = AppColors.sand,
      color = AppColors.sandText;

  final String text;
  final Color background;
  final Color color;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: size - 2, vertical: size / 2.4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: size, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            style: jakarta(size, weight: 700, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// The blue "Photo verified" tag.
class PhotoVerifiedTag extends StatelessWidget {
  const PhotoVerifiedTag({super.key, this.size = 11});

  final double size;

  @override
  Widget build(BuildContext context) => Tag(
    'Photo verified',
    background: AppColors.verifiedBg,
    color: AppColors.verifiedText,
    icon: Icons.verified_rounded,
    size: size,
  );
}

/// The teal "ID checked" tag.
class IdCheckedTag extends StatelessWidget {
  const IdCheckedTag({super.key, this.size = 11});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Tag('ID checked', icon: Icons.badge_outlined, size: size);
}

/// Grey box with a small label over a sentence, like "What I'm ready for now".
class InfoBox extends StatelessWidget {
  const InfoBox({
    super.key,
    required this.label,
    required this.text,
    this.outlined = false,
    this.maxLines,
  });

  final String label;
  final String text;
  final bool outlined;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: outlined ? Colors.white : AppColors.mist,
      borderRadius: BorderRadius.circular(16),
      border: outlined ? Border.all(color: AppColors.line) : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: jakarta(12, weight: 700, color: AppColors.muted)),
        const SizedBox(height: 3),
        Text(
          text,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          style: jakarta(15, weight: 600, height: 1.45),
        ),
      ],
    ),
  );
}

/// A small stat tile: uppercase label, value and a note.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.note,
  });

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: AppColors.mist,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: jakarta(
            10,
            weight: 800,
            color: const Color(0xFF3F5A52),
            letterSpacingEm: 0.05,
          ),
        ),
        Text(value, style: jakarta(15, weight: 800)),
        if (note != null)
          Text(note!, style: jakarta(11, color: AppColors.muted)),
      ],
    ),
  );
}

/// A white rounded card with the design's soft shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A1B2421),
          blurRadius: 24,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

/// The design's error text style, for form-level messages.
class FormMessage extends StatelessWidget {
  const FormMessage(this.text, {super.key, this.isError = true});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFDECEA) : AppColors.tealTint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: jakarta(
        14,
        weight: 600,
        color: isError ? AppColors.error : AppColors.tealDark,
        height: 1.4,
      ),
    ),
  );
}

/// The two-ring mark and "widowd" wordmark used in app headers.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.fontSize = 24, this.onDark = false});

  final double fontSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      WidowdRings(
        width: fontSize * 1.4,
        left: onDark ? AppColors.gold : AppColors.amber,
        right: onDark ? Colors.white : AppColors.teal,
        strokeWidth: 7,
      ),
      const SizedBox(width: 8),
      Text(
        'widowd',
        style: jakarta(
          fontSize,
          weight: 800,
          color: onDark ? Colors.white : AppColors.teal,
          letterSpacingEm: -0.8 / 24,
        ),
      ),
    ],
  );
}
