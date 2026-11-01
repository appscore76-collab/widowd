import 'package:flutter/material.dart';

import 'landing_style.dart';
import 'landing_video.dart';

class _Feature {
  const _Feature({
    required this.image,
    required this.title,
    required this.short,
    required this.badge,
    required this.alt,
    required this.desc,
    required this.points,
  });

  final String image;
  final String title;
  final String short;
  final String badge;
  final String alt;
  final String desc;
  final List<String> points;
}

const _features = [
  _Feature(
    image: 'intent.webp',
    title: 'Dating intent',
    short: 'Say what you’re hoping for',
    badge: 'Free',
    alt: 'Dating intent screen with five options',
    desc:
        'Companionship, something casual, a long-term partner, marriage — or '
        'not sure yet. Your intent shows on your profile and shapes who we '
        'suggest.',
    points: [
      'Change it any time',
      'Optional “where are you in your journey”',
      'Suggestions match your intent',
    ],
  ),
  _Feature(
    image: 'family.webp',
    title: 'Family & children',
    short: 'Number of children on every profile',
    badge: 'Free',
    alt: 'Tell us about your family screen with a children counter',
    desc:
        'Family matters here. Share how many children you have, their ages '
        'and whether they live at home — and whether you’re open to a partner '
        'with children.',
    points: [
      'Shown on profiles and in search',
      'Ages and living arrangements',
      'Filter by family preferences',
    ],
  ),
  _Feature(
    image: 'photos.webp',
    title: 'Private profile photos',
    short: 'Blurred until someone likes you',
    badge: 'Free',
    alt: 'Add your photos screen with blurred photos',
    desc:
        'Upload up to six photos. They stay blurred for everyone until that '
        'person likes your profile — so you’re liked for you.',
    points: [
      'Preview how others see you',
      'Unlocks per person, after a like',
      'Screenshots blocked everywhere',
    ],
  ),
  _Feature(
    image: 'search.webp',
    title: 'Search with trust filters',
    short: 'Verified and ID-checked badges',
    badge: 'Plus filters',
    alt: 'Search screen with photo verified and ID checked filters',
    desc:
        'Search by interests, town or keyword. Badges show who has '
        'photo-verified or ID-checked — and Plus members can show only '
        'verified people.',
    points: [
      'Distance and age filters',
      'Children shown in results',
      'Verified-only search with Plus',
    ],
  ),
  _Feature(
    image: 'chats.webp',
    title: 'Every chat, kept',
    short: 'Pick up any conversation',
    badge: 'Plus to message',
    alt: 'Chats screen listing six conversations',
    desc:
        'Every person you’ve talked to is logged in one place. Search, '
        'filter unread chats or upcoming dates, and open any conversation to '
        'carry on.',
    points: [
      'Unread counts and date markers',
      'Search all your chats',
      'Blocked chats kept separately',
    ],
  ),
  _Feature(
    image: 'view_once.webp',
    title: 'View-once photos',
    short: 'Share up to 10 at a time',
    badge: 'Plus',
    alt: 'Send private photos screen with three photos selected',
    desc:
        'Share everyday moments — the garden, a holiday, the dog — privately. '
        'Each photo opens once, for a few seconds or until closed, then '
        'disappears.',
    points: [
      'Multi-select with numbered order',
      'Choose the viewing time',
      'Screenshots and recording blocked',
    ],
  ),
  _Feature(
    image: 'video_call.webp',
    title: 'Video chat',
    short: 'Meet face to face, from home',
    badge: 'Plus',
    alt: 'Video call screen with mute, camera and end call buttons',
    desc:
        'See each other before you meet. Calls happen inside Widowd, so your '
        'phone number stays private, and they are never recorded.',
    points: [
      'Number stays private',
      'Never recorded',
      'Mute or turn the camera off any time',
    ],
  ),
  _Feature(
    image: 'incognito.webp',
    title: 'Incognito & privacy',
    short: 'Only people you like see you',
    badge: 'Plus',
    alt: 'Privacy settings screen with incognito mode switched on',
    desc:
        'Browse at your own pace. With Incognito on, only people you’ve liked '
        'can see your profile. Hide your exact age or distance, or take a '
        'break.',
    points: [
      'Hide age or exact distance',
      'Read receipts on or off',
      'Pause your profile, keep matches',
    ],
  ),
];

class FeaturesSection extends StatefulWidget {
  const FeaturesSection({super.key, required this.onJoin});

  final VoidCallback onJoin;

  @override
  State<FeaturesSection> createState() => _FeaturesSectionState();
}

class _FeaturesSectionState extends State<FeaturesSection> {
  int _active = 0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LandingColors.mist,
      child: LandingContainer(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 104),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('Everything in the app'),
                  SizedBox(height: 14),
                  SectionHeading('Thoughtful features for a second chapter.'),
                ],
              ),
            ),
            const SizedBox(height: 48),
            _CommunityCard(onJoin: widget.onJoin),
            const SizedBox(height: 48),
            FlexWrap(
              gapX: 64,
              gapY: 40,
              crossAxisAlignment: CrossAxisAlignment.start,
              items: [
                FlexItem(basis: 340, child: _featureTabs()),
                FlexItem(basis: 520, child: _FeaturePanel(_features[_active])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureTabs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, f) in _features.indexed) ...[
          if (i > 0) const SizedBox(height: 6),
          _FeatureTab(
            number: (i + 1).toString().padLeft(2, '0'),
            feature: f,
            selected: i == _active,
            onTap: () => setState(() => _active = i),
          ),
        ],
      ],
    );
  }
}

class _FeatureTab extends StatelessWidget {
  const _FeatureTab({
    required this.number,
    required this.feature,
    required this.selected,
    required this.onTap,
  });

  final String number;
  final _Feature feature;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? LandingColors.lineStrong : Colors.transparent,
          ),
        ),
        elevation: selected ? 3 : 0,
        shadowColor: LandingColors.phone.withValues(alpha: 0.3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? LandingColors.teal
                          : LandingColors.tealTintAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      number,
                      style: jakarta(
                        13,
                        weight: 800,
                        color: selected ? Colors.white : LandingColors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(feature.title, style: jakarta(17, weight: 800)),
                        const SizedBox(height: 2),
                        Text(
                          feature.short,
                          style: jakarta(
                            14,
                            color: selected
                                ? LandingColors.inkSoft
                                : LandingColors.mutedAlt,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturePanel extends StatelessWidget {
  const _FeaturePanel(this.feature);

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final free = feature.badge.startsWith('Free');
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: free ? LandingColors.tealTint : LandingColors.ink,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            feature.badge.toUpperCase(),
            style: jakarta(
              11,
              weight: 800,
              color: free ? LandingColors.teal : LandingColors.gold,
              letterSpacingEm: 0.6 / 11,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            feature.title,
            style: jakarta(
              28,
              weight: 800,
              height: 1.15,
              letterSpacingEm: -0.02,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          feature.desc,
          style: jakarta(16, color: LandingColors.inkSoft, height: 1.6),
        ),
        const SizedBox(height: 18),
        for (final p in feature.points) ...[
          TickLine(
            p,
            tickSize: 18,
            style: jakarta(15, weight: 600, height: 1.45),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(color: LandingColors.line, offset: Offset(0, 1)),
        ],
      ),
      child: FlexWrap(
        gapX: 32,
        gapY: 32,
        stackedAlignment: CrossAxisAlignment.center,
        items: [
          FlexItem(
            basis: 260,
            grow: 0,
            child: PhoneFrame(
              width: 260,
              padding: 8,
              radius: 42,
              shadow: [phoneShadow(30, 60, -26, 0.5)],
              child: Screenshot(
                feature.image,
                key: ValueKey(feature.image),
                label: feature.alt,
              ),
            ),
          ),
          FlexItem(basis: 220, child: text),
        ],
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final pad = clampVw(context, 28, 4, 48);
    final copy = Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Chip(
                'FREE',
                background: LandingColors.ink,
                color: LandingColors.gold,
                size: 15,
                letterSpacing: 1 / 15,
              ),
              const _Chip(
                'Peer support · separate from dating',
                background: Colors.white,
                color: LandingColors.brown,
                border: LandingColors.sandChipBorder,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Talk with people who understand.\n'),
                  const TextSpan(
                    text: 'Free, for every member.',
                    style: TextStyle(color: LandingColors.amberText),
                  ),
                ],
              ),
              style: jakarta(
                clampVw(context, 28, 3.2, 42),
                weight: 800,
                height: 1.08,
                letterSpacingEm: -0.03,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'A calm, separate space to share grief, family life and '
              'everyday wins under a random nickname. Nothing here is linked '
              'to your dating profile — no photos, no likes, no matching.',
              style: jakarta(17, color: LandingColors.inkSoft, height: 1.6),
            ),
          ),
          const SizedBox(height: 20),
          AutoGrid(
            minItemWidth: 200,
            gapX: 20,
            gapY: 10,
            children: [
              for (final line in const [
                'Random nickname, real name hidden',
                'Start or join discussions',
                'No dating requests or flirting',
                'No contact details or private messages',
              ])
                TickLine(
                  line,
                  tickColor: LandingColors.amberText,
                  style: jakarta(15, weight: 700),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final topic in const [
                'Grief & healing',
                'Family',
                'Everyday life',
                'Dating again',
              ])
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    topic,
                    style: jakarta(
                      13,
                      weight: 700,
                      color: LandingColors.brownDark,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PillButton(
                onPressed: onJoin,
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                background: LandingColors.ink,
                foreground: Colors.white,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Join free',
                      style: jakarta(16, weight: 800, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
              Text(
                'Included with free registration',
                style: jakarta(14, weight: 600, color: LandingColors.brownDark),
              ),
            ],
          ),
        ],
      ),
    );

    // The phone sits on the card's bottom edge, cut off at the bottom.
    final phone = ExcludeSemantics(
      child: SizedBox(
        height: 400,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 290,
            height: 368,
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 0),
            decoration: const BoxDecoration(
              color: LandingColors.phone,
              borderRadius: BorderRadius.vertical(top: Radius.circular(44)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(35),
              ),
              child: const Screenshot(
                'community.webp',
                label: '',
                alignment: Alignment.topCenter,
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: 'Free peer-support community',
      container: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: LandingColors.sand,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: LandingColors.sandBorder, width: 2),
        ),
        child: FlexWrap(
          crossAxisAlignment: CrossAxisAlignment.end,
          items: [
            FlexItem(basis: 460, child: copy),
            FlexItem(basis: 360, grow: 0, child: phone),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
    this.text, {
    required this.background,
    required this.color,
    this.border,
    this.size = 13,
    this.letterSpacing = 0,
  });

  final String text;
  final Color background;
  final Color color;
  final Color? border;
  final double size;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(17),
      border: border == null ? null : Border.all(color: border!),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(
        text,
        style: jakarta(
          size,
          weight: 800,
          color: color,
          letterSpacingEm: letterSpacing,
        ),
      ),
    ),
  );
}

class DatesSection extends StatelessWidget {
  const DatesSection({super.key});

  static const _cards = [
    (
      Icons.search_rounded,
      'Search any place',
      'Cafés, food, parks and culture, filtered as you type.',
    ),
    (
      Icons.join_inner_rounded,
      'Meet halfway',
      'Fair, public suggestions between you both.',
    ),
    (
      Icons.location_on_outlined,
      'Share my date',
      'Live location and a check-in, for people you trust.',
    ),
    (
      Icons.videocam_outlined,
      'Or a video date',
      'Meet face to face from home first.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Planning a date', color: LandingColors.gold),
        const SizedBox(height: 20),
        const SectionHeading(
          'From hello to coffee, without the awkward bits.',
          color: Colors.white,
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'Pick the kind of date, a day and a time. Search for a café, park '
            'or address — or tap a busy public place halfway between you. '
            'They accept, suggest another time, or kindly decline.',
            style: jakarta(18, color: LandingColors.onDark, height: 1.6),
          ),
        ),
        const SizedBox(height: 26),
        AutoGrid(
          minItemWidth: 190,
          gapX: 14,
          gapY: 14,
          stretch: true,
          children: [
            for (final (icon, title, body) in _cards)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: LandingColors.darkCard,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 24, color: LandingColors.gold),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: jakarta(16, weight: 800, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: jakarta(
                        14,
                        color: LandingColors.onDarkSoft,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );

    Widget figure(
      String video,
      String poster,
      String label,
      String caption,
      Color bg,
    ) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhoneFrame(
          width: 250,
          padding: 8,
          radius: 40,
          frameColor: Colors.black,
          shadow: const [
            BoxShadow(color: LandingColors.darkCardEdge, spreadRadius: 1),
          ],
          child: LoopingVideo(
            video: video,
            poster: poster,
            label: label,
            background: bg,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          caption,
          style: jakarta(14, weight: 700, color: LandingColors.onDark),
        ),
      ],
    );

    final phones = Wrap(
      alignment: WrapAlignment.center,
      spacing: 28,
      runSpacing: 28,
      children: [
        figure(
          'dates_plan.mp4',
          'dates_plan_poster.webp',
          'Screen recording: planning a dinner date and searching for a tea '
              'room',
          '1 · Plan it and pick a place',
          Colors.white,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: figure(
            'dates_share.mp4',
            'dates_share_poster.webp',
            'Screen recording: accepting a date invite and sharing the date '
                'with trusted contacts',
            '2 · They accept, you share it',
            LandingColors.teal,
          ),
        ),
      ],
    );

    return ColoredBox(
      color: LandingColors.ink,
      child: LandingContainer(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 104),
        child: FlexWrap(
          gapX: 72,
          gapY: 56,
          items: [
            FlexItem(basis: 400, child: copy),
            FlexItem(basis: 520, child: phones),
          ],
        ),
      ),
    );
  }
}

class SafetySection extends StatelessWidget {
  const SafetySection({super.key});

  static const _small = [
    (
      Icons.lock_outline_rounded,
      'No screenshots',
      'Photos and chats hide when a screenshot or screen recording is taken.',
    ),
    (
      Icons.filter_none_rounded,
      'View-once photos',
      'Send up to 10 at a time. Each opens once, then it’s gone.',
    ),
    (
      Icons.visibility_off_outlined,
      'Incognito',
      'Only people you’ve liked can see you. Browse quietly.',
    ),
    (
      Icons.flag_outlined,
      'Report anything',
      'Reports and repeated screenshot attempts go to our safety team.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    Widget bigCard({
      required Color background,
      String? tag,
      required String title,
      required String body,
      required Widget media,
      bool dark = false,
    }) => Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tag != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: LandingColors.ink,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                tag,
                style: jakarta(
                  11,
                  weight: 800,
                  color: LandingColors.gold,
                  letterSpacingEm: 0.6 / 11,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            title,
            style: jakarta(
              22,
              weight: 800,
              color: dark ? Colors.white : LandingColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: jakarta(
              15,
              color: dark ? LandingColors.onDark : LandingColors.inkSoft,
              height: 1.55,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 24),
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.78,
              child: Container(
                height: 412,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: dark ? Colors.black : LandingColors.phone,
                      width: 8,
                    ),
                    left: BorderSide(
                      color: dark ? Colors.black : LandingColors.phone,
                      width: 8,
                    ),
                    right: BorderSide(
                      color: dark ? Colors.black : LandingColors.phone,
                      width: 8,
                    ),
                  ),
                ),
                child: media,
              ),
            ),
          ),
        ],
      ),
    );

    return ColoredBox(
      color: Colors.white,
      child: LandingContainer(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 104),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FlexWrap(
              gapX: 48,
              gapY: 20,
              crossAxisAlignment: CrossAxisAlignment.end,
              items: [
                const FlexItem(
                  basis: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('Trust & safety'),
                      SizedBox(height: 14),
                      SectionHeading('Safe to be open again.'),
                    ],
                  ),
                ),
                FlexItem(
                  basis: 340,
                  child: Text(
                    'Know who you’re talking to, keep what you share private, '
                    'and step away from any conversation in two taps.',
                    style: jakarta(
                      17,
                      color: LandingColors.inkSoft,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            AutoGrid(
              minItemWidth: 300,
              gapX: 20,
              gapY: 20,
              stretch: true,
              children: [
                bigCard(
                  background: LandingColors.tealTint,
                  tag: 'WIDOWD PLUS',
                  title: 'Photo verification',
                  body:
                      'A posed selfie is matched to profile photos. The blue '
                      'badge shows in search and on profiles.',
                  media: const Screenshot(
                    'photo_verification.webp',
                    label:
                        'Get photo verified screen with a camera preview and '
                        'pose to copy',
                    alignment: Alignment.topCenter,
                  ),
                ),
                bigCard(
                  background: LandingColors.cream,
                  tag: 'WIDOWD PLUS · OPTIONAL',
                  title: 'ID check',
                  body:
                      'Confirm your real name and age with a passport, '
                      'licence or ID card. Others only see the badge.',
                  media: const Screenshot(
                    'id_check.webp',
                    label:
                        'Add an ID check screen with passport, driving '
                        'licence and ID card options',
                    alignment: Alignment.topCenter,
                  ),
                ),
                bigCard(
                  background: LandingColors.ink,
                  dark: true,
                  title: 'Block in two taps',
                  body:
                      'No more messages or calls, and they can’t find you in '
                      'search. They’re never told.',
                  media: const LoopingVideo(
                    video: 'block.mp4',
                    poster: 'block_poster.webp',
                    label:
                        'Screen recording: sending view-once photos, then '
                        'blocking a chat',
                    background: LandingColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AutoGrid(
              minItemWidth: 240,
              gapX: 20,
              gapY: 20,
              stretch: true,
              children: [
                for (final (icon, title, body) in _small)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: LandingColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 28, color: LandingColors.teal),
                        const SizedBox(height: 8),
                        Text(title, style: jakarta(17, weight: 800)),
                        const SizedBox(height: 8),
                        Text(
                          body,
                          style: jakarta(
                            14,
                            color: LandingColors.muted,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
