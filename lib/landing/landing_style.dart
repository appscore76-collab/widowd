import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colors from the landing page design.
abstract final class LandingColors {
  static const ink = Color(0xFF14201D);
  static const inkSoft = Color(0xFF3B4744);
  static const muted = Color(0xFF4F5C58);
  static const mutedAlt = Color(0xFF5B6763);
  static const teal = Color(0xFF1E5A57);
  static const tealDark = Color(0xFF133B39);
  static const tealTint = Color(0xFFEAF1EE);
  static const tealTintAlt = Color(0xFFE3ECE8);
  static const tabTrack = Color(0xFFEEF3F1);
  static const mist = Color(0xFFF4F7F6);
  static const line = Color(0xFFE3E9E6);
  static const lineStrong = Color(0xFFD5DFDB);
  static const circle = Color(0xFFDCE8E4);
  static const phone = Color(0xFF0F1614);
  static const amber = Color(0xFFC9852C);
  static const amberText = Color(0xFF8A5A16);
  static const gold = Color(0xFFF2C27B);
  static const sand = Color(0xFFFBF0DF);
  static const sandBorder = Color(0xFFE9CF9E);
  static const sandChipBorder = Color(0xFFE4D3B4);
  static const brown = Color(0xFF7A4B0E);
  static const brownDark = Color(0xFF5A3608);
  static const cream = Color(0xFFF4EEE4);
  static const onDark = Color(0xFFC9D6D2);
  static const onDarkSoft = Color(0xFFB7C7C2);
  static const onTeal = Color(0xFFD6E6E2);
  static const onTealSoft = Color(0xFFCFE0DB);
  static const darkCard = Color(0xFF1E2C28);
  static const darkCardEdge = Color(0xFF2E3C38);
  static const verifiedBlue = Color(0xFF2563EB);
  static const verifiedText = Color(0xFF1E3A8A);
}

const landingFont = 'PlusJakartaSans';

/// Plus Jakarta Sans at a size and weight (400, 500, 600, 700 or 800).
TextStyle jakarta(
  double size, {
  int weight = 400,
  Color color = LandingColors.ink,
  double? height,
  double letterSpacingEm = 0,
  FontStyle? style,
}) => TextStyle(
  fontFamily: landingFont,
  fontSize: size,
  fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
  color: color,
  height: height,
  letterSpacing: letterSpacingEm * size,
  fontStyle: style,
);

/// CSS `clamp(min, vw * width, max)`.
double clampVw(BuildContext context, double min, double vw, double max) {
  final width = MediaQuery.sizeOf(context).width;
  return (width * vw / 100).clamp(min, max);
}

/// Centers a section's content at the design's 1200 px max width.
class LandingContainer extends StatelessWidget {
  const LandingContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: child,
      ),
    ),
  );
}

/// One item in a [FlexWrap]: CSS `flex: <grow> 1 <basis>px`.
class FlexItem {
  const FlexItem({required this.basis, required this.child, this.grow = 1});

  final double basis;
  final double grow;
  final Widget child;
}

/// CSS `display: flex; flex-wrap: wrap` for two or three blocks: side by side
/// when their bases fit, otherwise stacked.
class FlexWrap extends StatelessWidget {
  const FlexWrap({
    super.key,
    required this.items,
    this.gapX = 0,
    this.gapY = 0,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.stackedAlignment = CrossAxisAlignment.stretch,
  });

  final List<FlexItem> items;
  final double gapX;
  final double gapY;
  final CrossAxisAlignment crossAxisAlignment;
  final CrossAxisAlignment stackedAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gaps = gapX * (items.length - 1);
        final bases = items.fold<double>(0, (sum, i) => sum + i.basis);
        if (bases + gaps <= width) {
          final extra = width - bases - gaps;
          final totalGrow = items.fold<double>(0, (sum, i) => sum + i.grow);
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              for (final (index, item) in items.indexed) ...[
                if (index > 0) SizedBox(width: gapX),
                SizedBox(
                  width:
                      item.basis +
                      (totalGrow == 0 ? 0 : extra * item.grow / totalGrow),
                  child: item.child,
                ),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: stackedAlignment,
          children: [
            for (final (index, item) in items.indexed) ...[
              if (index > 0) SizedBox(height: gapY),
              item.child,
            ],
          ],
        );
      },
    );
  }
}

/// CSS `grid-template-columns: repeat(auto-fit, minmax(<min>px, 1fr))`.
class AutoGrid extends StatelessWidget {
  const AutoGrid({
    super.key,
    required this.minItemWidth,
    required this.children,
    this.gapX = 0,
    this.gapY = 0,
    this.stretch = false,
  });

  final double minItemWidth;
  final List<Widget> children;
  final double gapX;
  final double gapY;

  /// Gives every item in a row the height of the tallest.
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = ((constraints.maxWidth + gapX) / (minItemWidth + gapX))
            .floor();
        final columns = math.max(1, math.min(fit, children.length));
        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          final cells = <Widget>[];
          for (var c = 0; c < columns; c++) {
            if (c > 0) cells.add(SizedBox(width: gapX));
            final i = start + c;
            cells.add(
              Expanded(
                child: i < children.length ? children[i] : const SizedBox(),
              ),
            );
          }
          final row = Row(
            crossAxisAlignment: stretch
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            children: cells,
          );
          if (rows.isNotEmpty) rows.add(SizedBox(height: gapY));
          rows.add(stretch ? IntrinsicHeight(child: row) : row);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

/// Small uppercase label above a section heading.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = LandingColors.amberText});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: jakarta(13, weight: 800, color: color, letterSpacingEm: 1.2 / 13),
  );
}

/// A section heading at the design's `clamp(34px, 4vw, 54px)`.
class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.text, {
    super.key,
    this.color = LandingColors.ink,
    this.textAlign,
  });

  final String text;
  final Color color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      textAlign: textAlign,
      style: jakarta(
        clampVw(context, 34, 4, 54),
        weight: 800,
        color: color,
        height: 1.04,
        letterSpacingEm: -0.035,
      ),
    ),
  );
}

/// A tick and a line of text.
class TickLine extends StatelessWidget {
  const TickLine(
    this.text, {
    super.key,
    this.tickColor = LandingColors.teal,
    this.style,
    this.tickSize = 20,
  });

  final String text;
  final Color tickColor;
  final TextStyle? style;
  final double tickSize;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(Icons.check_rounded, size: tickSize, color: tickColor),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: style ?? jakarta(15, weight: 600))),
    ],
  );
}

/// The two-ring widowd mark.
class WidowdRings extends StatelessWidget {
  const WidowdRings({
    super.key,
    this.width = 40,
    this.left = LandingColors.amber,
    this.right = LandingColors.teal,
    this.strokeWidth = 7,
  });

  final double width;
  final Color left;
  final Color right;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * 64 / 96,
    child: CustomPaint(painter: _RingsPainter(left, right, strokeWidth)),
  );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.left, this.right, this.strokeWidth);

  final Color left;
  final Color right;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 96;
    canvas.scale(scale);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(const Offset(36, 32), 22, paint..color = left);
    canvas.drawCircle(const Offset(60, 32), 22, paint..color = right);
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.left != left || old.right != right;
}

/// The widowd mark and wordmark.
class WidowdLogo extends StatelessWidget {
  const WidowdLogo({super.key, this.ringWidth = 40, this.fontSize = 24});

  final double ringWidth;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      WidowdRings(width: ringWidth),
      const SizedBox(width: 10),
      Text(
        'widowd',
        style: jakarta(
          fontSize,
          weight: 800,
          color: LandingColors.teal,
          letterSpacingEm: -0.8 / 24,
        ),
      ),
    ],
  );
}

/// A rounded, pill-shaped button or link.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.background = Colors.transparent,
    this.foreground = LandingColors.ink,
    this.borderColor,
    this.borderWidth = 2,
    this.height = 46,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.expand = false,
  });

  final VoidCallback onPressed;
  final Widget child;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final double borderWidth;
  final double height;
  final EdgeInsets padding;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: padding,
          shape: StadiumBorder(
            side: borderColor == null
                ? BorderSide.none
                : BorderSide(color: borderColor!, width: borderWidth),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A phone screenshot in a dark rounded frame.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({
    super.key,
    required this.child,
    required this.width,
    this.padding = 9,
    this.radius = 46,
    this.frameColor = LandingColors.phone,
    this.shadow,
  });

  final Widget child;
  final double width;
  final double padding;
  final double radius;
  final Color frameColor;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: frameColor,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: shadow,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius - padding),
      child: AspectRatio(aspectRatio: 390 / 844, child: child),
    ),
  );
}

/// A screenshot from `assets/landing/`, with a description for screen readers.
class Screenshot extends StatelessWidget {
  const Screenshot(
    this.name, {
    super.key,
    required this.label,
    this.alignment = Alignment.center,
  });

  final String name;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/landing/$name',
    fit: BoxFit.cover,
    alignment: alignment,
    semanticLabel: label.isEmpty ? null : label,
    excludeFromSemantics: label.isEmpty,
    gaplessPlayback: true,
  );
}

BoxShadow phoneShadow(double y, double blur, double spread, double opacity) =>
    BoxShadow(
      color: LandingColors.phone.withValues(alpha: opacity),
      offset: Offset(0, y),
      blurRadius: blur,
      spreadRadius: spread,
    );
