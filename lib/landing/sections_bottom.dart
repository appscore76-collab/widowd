import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'landing_style.dart';
import 'sections_top.dart';

const contactEmail = 'hello@widowd.app';

Future<void> _emailUs() => launchUrl(Uri(scheme: 'mailto', path: contactEmail));

class _Plan {
  const _Plan({
    required this.name,
    required this.price,
    required this.per,
    required this.note,
    required this.items,
    required this.cta,
    this.tag,
    this.highlighted = false,
  });

  final String name;
  final String price;
  final String per;
  final String note;
  final List<String> items;
  final String cta;
  final String? tag;
  final bool highlighted;
}

const _plans = [
  _Plan(
    name: 'Free',
    price: '£0',
    per: 'forever',
    note: 'Join, like and match',
    items: [
      'Free registration',
      'Peer-support community',
      'Suggestions, likes & matches',
    ],
    cta: 'Get started',
  ),
  _Plan(
    name: 'Weekly',
    price: '[PRICE]',
    per: 'per week',
    note: 'Try Plus, cancel anytime',
    items: [
      'Everything in Free',
      'Message & video chat',
      'Share my date & location',
      'Verification badges',
    ],
    cta: 'Try Weekly',
  ),
  _Plan(
    name: 'Monthly',
    price: '[PRICE]',
    per: 'per month',
    note: 'Billed every month',
    items: [
      'Everything in Free',
      'Message & video chat',
      'Share my date & location',
      'Photo verified & ID badges',
      'Incognito & view-once photos',
    ],
    cta: 'Choose Monthly',
    tag: 'Most popular',
    highlighted: true,
  ),
  _Plan(
    name: '6 months',
    price: '[PRICE]',
    per: 'per month',
    note: '[PRICE] billed every 6 months',
    items: [
      'Everything in Monthly',
      'Our best value',
      'Verified-only search',
      'See who likes you',
    ],
    cta: 'Choose 6 months',
    tag: 'Best value',
  ),
];

class PricingSection extends StatelessWidget {
  const PricingSection({super.key, required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LandingColors.mist,
      child: LandingContainer(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 104),
        child: Column(
          children: [
            const Eyebrow('Pricing'),
            const SizedBox(height: 14),
            const SectionHeading(
              'Start free. Upgrade when you’re ready.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(
                'Registration, suggestions, likes and matches are always '
                'free. Widowd Plus adds messaging, video, Share my date, '
                'verification badges and more privacy.',
                textAlign: TextAlign.center,
                style: jakarta(17, color: LandingColors.inkSoft, height: 1.6),
              ),
            ),
            const SizedBox(height: 44),
            AutoGrid(
              minItemWidth: 250,
              gapX: 18,
              gapY: 18,
              stretch: true,
              children: [
                for (final plan in _plans)
                  _PlanCard(plan: plan, onPressed: onJoin),
              ],
            ),
            const SizedBox(height: 44),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Text(
                'Prices shown in the app. Subscriptions are billed through '
                'your Apple ID and renew automatically unless cancelled at '
                'least 24 hours before the period ends.',
                textAlign: TextAlign.center,
                style: jakarta(13, color: LandingColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onPressed});

  final _Plan plan;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hi = plan.highlighted;
    final fg = hi ? Colors.white : LandingColors.ink;
    final soft = hi ? LandingColors.onDark : LandingColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: hi ? LandingColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: hi ? null : Border.all(color: LandingColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 26),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: jakarta(20, weight: 800, color: fg),
                  ),
                ),
                if (plan.tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: hi ? LandingColors.gold : LandingColors.sand,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      plan.tag!.toUpperCase(),
                      style: jakarta(
                        11,
                        weight: 800,
                        color: hi ? LandingColors.ink : LandingColors.brown,
                        letterSpacingEm: 0.4 / 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(
                plan.price,
                style: jakarta(
                  36,
                  weight: 800,
                  color: fg,
                  letterSpacingEm: -0.03,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  plan.per,
                  style: jakarta(15, weight: 600, color: soft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(plan.note, style: jakarta(14, color: soft)),
          const SizedBox(height: 16),
          for (final item in plan.items) ...[
            TickLine(
              item,
              tickSize: 16,
              tickColor: hi ? LandingColors.gold : LandingColors.teal,
              style: jakarta(14, weight: 600, color: fg, height: 1.45),
            ),
            const SizedBox(height: 9),
          ],
          const Spacer(),
          const SizedBox(height: 14),
          PillButton(
            onPressed: onPressed,
            expand: true,
            height: 52,
            background: hi ? LandingColors.gold : Colors.white,
            foreground: LandingColors.ink,
            borderColor: hi ? null : LandingColors.ink,
            child: Text(plan.cta, style: jakarta(16, weight: 800)),
          ),
        ],
      ),
    );
  }
}

const _faqs = [
  (
    'Who can join Widowd?',
    'Widowd is only for widows and widowers aged 18 and over. You tell us '
        'about your journey when you sign up, and members can add photo '
        'verification and an ID check for extra trust.',
  ),
  (
    'Why are photos blurred?',
    'So people like you for who you are. Your photos stay blurred for each '
        'person until they like your profile — then they unlock for them '
        'only.',
  ),
  (
    'Is Widowd free?',
    'Yes. Registration, daily suggestions, likes and matches are free, and '
        'so is the separate peer-support Community. Widowd Plus — weekly, '
        'monthly or every 6 months — adds messaging, video chat, Share my '
        'date, verification badges, Incognito and view-once photos.',
  ),
  (
    'Can people screenshot my photos or chats?',
    'Widowd hides photos and chats when a screenshot or screen recording is '
        'taken, and lets the sender know. No app can stop someone '
        'photographing a screen with another device, so only share what '
        'you’re comfortable with.',
  ),
  (
    'How does Share my date work?',
    'Share my date is part of Widowd Plus. Choose trusted contacts and '
        'Widowd sends them the date details. You can share your live '
        'location during the date only, set a check-in time, and alert your '
        'contacts if you don’t respond.',
  ),
  (
    'Is the Community part of dating?',
    'No. The Community is a separate, free peer-support space for talking '
        'about grief, family and everyday life. Your dating profile, photos '
        'and likes are never shown there, you post under a random nickname, '
        'and dating requests, contact details and private messages aren’t '
        'allowed.',
  ),
  (
    'How do I block someone?',
    'Open the chat, tap ⋯ and choose Block. They can’t message, call or find '
        'you in search, any planned date is cancelled, and they aren’t told. '
        'You can unblock from the Blocked filter in Chats.',
  ),
];

class FaqSection extends StatefulWidget {
  const FaqSection({super.key});

  @override
  State<FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<FaqSection> {
  int _open = 0;

  @override
  Widget build(BuildContext context) {
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Questions'),
        const SizedBox(height: 14),
        const SectionHeading('Good to know.'),
        const SizedBox(height: 14),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Can’t find your answer? Email ',
              style: jakarta(16, color: LandingColors.inkSoft, height: 1.6),
            ),
            Semantics(
              link: true,
              child: InkWell(
                onTap: _emailUs,
                child: Text(
                  contactEmail,
                  style: jakarta(
                    16,
                    color: LandingColors.teal,
                    height: 1.6,
                  ).copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (q, a)) in _faqs.indexed)
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: LandingColors.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  expanded: _open == i,
                  child: InkWell(
                    onTap: () => setState(() => _open = _open == i ? -1 : i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 68),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(q, style: jakarta(18, weight: 800)),
                            ),
                            const SizedBox(width: 16),
                            AnimatedRotation(
                              turns: _open == i ? 0.125 : 0,
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _open == i
                                      ? LandingColors.teal
                                      : LandingColors.tabTrack,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 20,
                                  color: _open == i
                                      ? Colors.white
                                      : LandingColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_open == i)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Text(
                        a,
                        style: jakarta(
                          16,
                          color: LandingColors.inkSoft,
                          height: 1.65,
                        ),
                      ),
                    ),
                  ),
              ],
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
          gapY: 32,
          crossAxisAlignment: CrossAxisAlignment.start,
          items: [
            FlexItem(basis: 320, child: intro),
            FlexItem(basis: 560, grow: 2, child: list),
          ],
        ),
      ),
    );
  }
}

class DownloadSection extends StatelessWidget {
  const DownloadSection({super.key, required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final copy = Padding(
      padding: const EdgeInsets.only(bottom: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WidowdRings(
            width: 72,
            left: LandingColors.gold,
            right: Colors.white,
            strokeWidth: 6,
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              'Ready when you are.',
              style: jakarta(
                clampVw(context, 36, 4.6, 60),
                weight: 800,
                color: Colors.white,
                height: 1.02,
                letterSpacingEm: -0.04,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              'There’s no right time to start again — only your time. Create '
              'a free profile in a few minutes.',
              style: jakarta(18, color: LandingColors.onTeal, height: 1.6),
            ),
          ),
          const SizedBox(height: 20),
          JoinButton(onPressed: onJoin, light: true),
          const SizedBox(height: 20),
          Text(
            'Members must be 18 or over.',
            style: jakarta(13, color: LandingColors.onTealSoft),
          ),
        ],
      ),
    );

    Widget phone(
      String image,
      String label,
      double w,
      double h,
      double r,
    ) => Container(
      width: w,
      height: h,
      padding: EdgeInsets.fromLTRB(r / 4.5, r / 4.5, r / 4.5, 0),
      decoration: BoxDecoration(
        color: LandingColors.phone,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r - r / 4.5)),
        child: Screenshot(image, label: label, alignment: Alignment.topCenter),
      ),
    );

    final phones = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        phone('chats.webp', 'Chats screen listing conversations', 170, 300, 32),
        const SizedBox(width: 18),
        phone(
          'welcome.webp',
          'Widowd welcome screen: Love again, at your own pace',
          200,
          380,
          36,
        ),
      ],
    );

    return ColoredBox(
      color: Colors.white,
      child: LandingContainer(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
        child: Container(
          clipBehavior: Clip.antiAlias,
          padding: EdgeInsets.fromLTRB(
            clampVw(context, 28, 6, 80),
            64,
            clampVw(context, 28, 6, 80),
            0,
          ),
          decoration: BoxDecoration(
            color: LandingColors.teal,
            borderRadius: BorderRadius.circular(40),
          ),
          child: FlexWrap(
            gapX: 56,
            gapY: 32,
            crossAxisAlignment: CrossAxisAlignment.end,
            items: [
              FlexItem(basis: 420, child: copy),
              FlexItem(
                basis: 388,
                grow: 0,
                child: FittedBox(fit: BoxFit.scaleDown, child: phones),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key, required this.scrollTo});

  final ScrollToSection scrollTo;

  @override
  Widget build(BuildContext context) {
    Widget link(String label, VoidCallback onTap) => TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: LandingColors.inkSoft,
        padding: const EdgeInsets.all(10),
        minimumSize: const Size(0, 44),
      ),
      child: Text(
        label,
        style: jakarta(
          14,
          weight: 600,
          color: LandingColors.inkSoft,
        ).copyWith(decoration: TextDecoration.underline),
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: LandingColors.line)),
      ),
      child: LandingContainer(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 40,
              runSpacing: 20,
              children: [
                const WidowdLogo(ringWidth: 34, fontSize: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    link('Safety tips', () => scrollTo(LandingSection.safety)),
                    link('Help', () => scrollTo(LandingSection.faq)),
                    link('Privacy', () => scrollTo(LandingSection.top)),
                    link('Terms', () => scrollTo(LandingSection.top)),
                    link('Contact', _emailUs),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '© ${DateTime.now().year} Widowd. iPhone is a trademark of Apple '
              'Inc.',
              style: jakarta(13, color: LandingColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
