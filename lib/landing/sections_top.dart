import 'package:flutter/material.dart';

import 'landing_style.dart';
import 'landing_video.dart';

/// Sections the header and buttons can scroll to.
enum LandingSection {
  top,
  how,
  features,
  dates,
  safety,
  pricing,
  faq,
  download,
}

typedef ScrollToSection = void Function(LandingSection section);

class LandingHeader extends StatelessWidget {
  const LandingHeader({
    super.key,
    required this.scrollTo,
    required this.onJoin,
    required this.onSignIn,
  });

  final ScrollToSection scrollTo;
  final VoidCallback onJoin;
  final VoidCallback onSignIn;

  static const _links = [
    ('How it works', LandingSection.how),
    ('Features', LandingSection.features),
    ('Dates', LandingSection.dates),
    ('Safety', LandingSection.safety),
    ('Pricing', LandingSection.pricing),
    ('FAQ', LandingSection.faq),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1020;
    final logo = Semantics(
      link: true,
      label: 'Widowd home',
      child: InkWell(
        onTap: () => scrollTo(LandingSection.top),
        borderRadius: BorderRadius.circular(8),
        child: const ExcludeSemantics(child: WidowdLogo()),
      ),
    );
    final nav = Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final (label, section) in _links)
          TextButton(
            onPressed: () => scrollTo(section),
            style: TextButton.styleFrom(
              foregroundColor: LandingColors.inkSoft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: const Size(0, 44),
            ),
            child: Text(
              label,
              style: jakarta(15, weight: 600, color: LandingColors.inkSoft),
            ),
          ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: onSignIn,
          style: TextButton.styleFrom(
            foregroundColor: LandingColors.ink,
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: Text('Sign in', style: jakarta(15, weight: 700)),
        ),
        const SizedBox(width: 6),
        PillButton(
          onPressed: onJoin,
          background: LandingColors.ink,
          foreground: Colors.white,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_border_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Join free',
                style: jakarta(15, weight: 700, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: LandingColors.mist,
        border: Border(bottom: BorderSide(color: LandingColors.line)),
      ),
      child: LandingContainer(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: wide
            ? Row(
                children: [
                  logo,
                  const SizedBox(width: 28),
                  Expanded(child: nav),
                  const SizedBox(width: 28),
                  actions,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 12,
                    children: [logo, actions],
                  ),
                  const SizedBox(height: 8),
                  nav,
                ],
              ),
      ),
    );
  }
}

/// The primary "Create your profile" button used in the hero and final CTA.
class JoinButton extends StatelessWidget {
  const JoinButton({super.key, required this.onPressed, this.light = false});

  final VoidCallback onPressed;

  /// White button for the teal call-to-action panel.
  final bool light;

  @override
  Widget build(BuildContext context) {
    final fg = light ? LandingColors.ink : Colors.white;
    return PillButton(
      onPressed: onPressed,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      background: light ? Colors.white : LandingColors.teal,
      foreground: fg,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border_rounded, size: 22, color: fg),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Free to join',
                style: jakarta(
                  12,
                  weight: 600,
                  color: light ? LandingColors.muted : LandingColors.onTeal,
                  height: 1.1,
                ),
              ),
              Text(
                'Create your profile',
                style: jakarta(18, weight: 800, color: fg, height: 1.1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeroSection extends StatelessWidget {
  const HeroSection({super.key, required this.onJoin, required this.scrollTo});

  final VoidCallback onJoin;
  final ScrollToSection scrollTo;

  @override
  Widget build(BuildContext context) {
    final copy = Padding(
      padding: const EdgeInsets.only(bottom: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: LandingColors.lineStrong),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: LandingColors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Made for widows and widowers',
                  style: jakarta(13, weight: 700, color: LandingColors.teal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Love again,\n'),
                  const TextSpan(
                    text: 'at your own pace.',
                    style: TextStyle(color: LandingColors.teal),
                  ),
                ],
              ),
              style: jakarta(
                clampVw(context, 44, 6.2, 84),
                weight: 800,
                height: 0.98,
                letterSpacingEm: -0.045,
              ),
            ),
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Widowd is an iPhone dating app for people who have lost a '
              'partner. You like someone for their story first — photos only '
              'unlock after you do — and every date can be planned and '
              'shared safely.',
              style: jakarta(
                clampVw(context, 17, 1.5, 20),
                color: LandingColors.inkSoft,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              JoinButton(onPressed: onJoin),
              PillButton(
                onPressed: () => scrollTo(LandingSection.how),
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                borderColor: LandingColors.ink,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 22),
                    const SizedBox(width: 8),
                    Text('See how it works', style: jakarta(16, weight: 700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          for (final line in const [
            'Photos stay blurred until someone likes your profile',
            'Photo-verified and ID-checked members',
            'Screenshots blocked in every chat',
          ]) ...[TickLine(line), const SizedBox(height: 10)],
        ],
      ),
    );

    return ColoredBox(
      color: LandingColors.mist,
      child: LandingContainer(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
        child: FlexWrap(
          gapX: 56,
          gapY: 40,
          items: [
            FlexItem(basis: 460, child: copy),
            const FlexItem(basis: 440, child: _HeroPhones()),
          ],
        ),
      ),
    );
  }
}

/// Three phones, a pair of floating cards and the pause button, laid out on
/// a 580 × 700 canvas and scaled down on narrow screens.
class _HeroPhones extends StatelessWidget {
  const _HeroPhones();

  @override
  Widget build(BuildContext context) {
    final card = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [phoneShadow(14, 30, -12, 0.3)],
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: AspectRatio(
          aspectRatio: 580 / 700,
          child: FittedBox(
            child: SizedBox(
              width: 580,
              height: 700,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 50,
                    top: 70,
                    child: Container(
                      width: 480,
                      height: 480,
                      decoration: const BoxDecoration(
                        color: LandingColors.circle,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 150,
                    child: Transform.rotate(
                      angle: -7 * 3.14159 / 180,
                      child: PhoneFrame(
                        width: 216,
                        padding: 7,
                        radius: 36,
                        shadow: [phoneShadow(24, 48, -18, 0.45)],
                        child: const Screenshot(
                          'intent.webp',
                          label:
                              'Widowd sign-up screen asking what you are '
                              'hoping to find',
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 150,
                    child: Transform.rotate(
                      angle: 7 * 3.14159 / 180,
                      child: PhoneFrame(
                        width: 216,
                        padding: 7,
                        radius: 36,
                        shadow: [phoneShadow(24, 48, -18, 0.45)],
                        child: const Screenshot(
                          'plan_date.webp',
                          label:
                              'Plan a date screen with date type, day, time '
                              'and meeting place',
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 145,
                    top: 24,
                    child: PhoneFrame(
                      width: 290,
                      shadow: [phoneShadow(40, 80, -24, 0.55)],
                      child: const LoopingVideo(
                        video: 'hero.mp4',
                        poster: 'hero_poster.webp',
                        label:
                            'Screen recording: liking Margaret unlocks her '
                            'photos, then opening her profile and chat',
                      ),
                    ),
                  ),
                  Positioned(
                    left: 23,
                    top: 560,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: card,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: LandingColors.teal,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'You liked Margaret',
                                style: jakarta(14, weight: 800),
                              ),
                              Text(
                                'Her photos are now unlocked',
                                style: jakarta(12, color: LandingColors.muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 92,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: card.copyWith(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: LandingColors.verifiedBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Photo verified · ID checked',
                            style: jakarta(
                              13,
                              weight: 800,
                              color: LandingColors.verifiedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(right: 0, bottom: 18, child: MotionButton()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Pause videos" / "Play videos".
class MotionButton extends StatelessWidget {
  const MotionButton({super.key});

  @override
  Widget build(BuildContext context) {
    final motion = LandingMotion.of(context);
    final paused = motion.paused;
    return Semantics(
      toggled: paused,
      child: PillButton(
        onPressed: () => motion.notifier!.value = !paused,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        background: Colors.white,
        borderColor: const Color(0xFFC9D3CF),
        borderWidth: 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              paused ? 'Play videos' : 'Pause videos',
              style: jakarta(13, weight: 700),
            ),
          ],
        ),
      ),
    );
  }
}

class PrinciplesBand extends StatelessWidget {
  const PrinciplesBand({super.key});

  static const _items = [
    (
      '01',
      'Only for the widowed',
      'A community where nobody needs your loss explained.',
    ),
    (
      '02',
      'Person before photo',
      'Likes are given to words, values and story — then photos unlock.',
    ),
    (
      '03',
      'Private by design',
      'Incognito, view-once photos and no screenshots.',
    ),
    ('04', 'Safer first dates', 'Public places, and family kept in the loop.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'What makes Widowd different',
      container: true,
      child: ColoredBox(
        color: LandingColors.tealDark,
        child: LandingContainer(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
          child: AutoGrid(
            minItemWidth: 240,
            gapX: 28,
            gapY: 28,
            children: [
              for (final (num, title, body) in _items)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      num,
                      style: jakarta(
                        13,
                        weight: 800,
                        color: LandingColors.gold,
                        letterSpacingEm: 1 / 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: jakarta(19, weight: 800, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: jakarta(
                        15,
                        color: LandingColors.onTealSoft,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two options in a rounded track, like iOS segmented tabs.
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: LandingColors.tabTrack,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, label) in labels.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            Semantics(
              selected: i == selected,
              child: PillButton(
                onPressed: () => onSelected(i),
                height: 44,
                background: i == selected
                    ? LandingColors.ink
                    : Colors.transparent,
                foreground: i == selected
                    ? Colors.white
                    : LandingColors.inkSoft,
                child: Text(
                  label,
                  style: jakarta(
                    14,
                    weight: 700,
                    color: i == selected ? Colors.white : LandingColors.inkSoft,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HowItWorksSection extends StatefulWidget {
  const HowItWorksSection({super.key});

  @override
  State<HowItWorksSection> createState() => _HowItWorksSectionState();
}

class _HowItWorksSectionState extends State<HowItWorksSection> {
  int _tab = 0;

  static const _steps = [
    (
      'Share your story',
      'Your intent, your family and what you’re ready for now.',
    ),
    ('Like who they are', 'Daily suggestions explain why you might get on.'),
    (
      'Photos unlock, conversation starts',
      'Chat, video call and plan a date when it feels right.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final before = _tab == 0;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('How it works'),
        const SizedBox(height: 20),
        const SectionHeading('Fall for who they are.\nThen see their face.'),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Text(
            'Every profile leads with what matters — what they’re ready for, '
            'how they spend a Sunday, their family. Photos stay softly '
            'blurred until you like the person. It takes the pressure off, '
            'for everyone.',
            style: jakarta(18, color: LandingColors.inkSoft, height: 1.6),
          ),
        ),
        const SizedBox(height: 28),
        for (final (i, (title, body)) in _steps.indexed) ...[
          if (i > 0) const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: LandingColors.tealTint,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: jakarta(16, weight: 800, color: LandingColors.teal),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: jakarta(17, weight: 800)),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: jakarta(
                        15,
                        color: LandingColors.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );

    final demo = Column(
      children: [
        PillTabs(
          labels: const ['Before you like', 'After you like'],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 22),
        PhoneFrame(
          width: 300,
          shadow: [phoneShadow(40, 80, -30, 0.5)],
          child: Screenshot(
            before ? 'like_before.webp' : 'like_after.webp',
            key: ValueKey(before),
            label: before
                ? 'Suggestion card with Margaret’s photos blurred and locked'
                : 'Suggestion card after liking Margaret, photos unlocked',
          ),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            before
                ? 'Her words, family and values come first. Photos are locked.'
                : 'One like later — her photos unlock, just for you.',
            textAlign: TextAlign.center,
            style: jakarta(14, weight: 600, color: LandingColors.muted),
          ),
        ),
      ],
    );

    return ColoredBox(
      color: Colors.white,
      child: LandingContainer(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 104),
        child: FlexWrap(
          gapX: 72,
          gapY: 48,
          items: [
            FlexItem(basis: 420, child: copy),
            FlexItem(basis: 420, child: demo),
          ],
        ),
      ),
    );
  }
}
