import 'package:flutter/material.dart';

import 'landing_video.dart';
import 'sections_bottom.dart';
import 'sections_middle.dart';
import 'sections_top.dart';

/// The public front page for signed-out visitors.
class LandingPage extends StatefulWidget {
  const LandingPage({
    super.key,
    required this.onJoin,
    required this.onSignIn,
    this.videosEnabled = true,
  });

  /// Opens account creation.
  final VoidCallback onJoin;

  /// Opens sign-in for existing members.
  final VoidCallback onSignIn;

  /// Plays the screen recordings; tests turn this off and see posters.
  final bool videosEnabled;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _keys = {for (final s in LandingSection.values) s: GlobalKey()};
  final _paused = ValueNotifier(false);
  bool _motionChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "reduce motion" setting on first load.
    if (!_motionChecked) {
      _motionChecked = true;
      _paused.value = MediaQuery.disableAnimationsOf(context);
    }
  }

  @override
  void dispose() {
    _paused.dispose();
    super.dispose();
  }

  void _scrollTo(LandingSection section) {
    final context = _keys[section]!.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: MediaQuery.disableAnimationsOf(this.context)
          ? Duration.zero
          : const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _anchor(LandingSection section, Widget child) =>
      KeyedSubtree(key: _keys[section], child: child);

  @override
  Widget build(BuildContext context) {
    return LandingMotion(
      paused: _paused,
      videosEnabled: widget.videosEnabled,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _anchor(
                LandingSection.top,
                LandingHeader(
                  scrollTo: _scrollTo,
                  onJoin: widget.onJoin,
                  onSignIn: widget.onSignIn,
                ),
              ),
              HeroSection(onJoin: widget.onJoin, scrollTo: _scrollTo),
              const PrinciplesBand(),
              _anchor(LandingSection.how, const HowItWorksSection()),
              _anchor(
                LandingSection.features,
                FeaturesSection(onJoin: widget.onJoin),
              ),
              _anchor(LandingSection.dates, const DatesSection()),
              _anchor(LandingSection.safety, const SafetySection()),
              _anchor(
                LandingSection.pricing,
                PricingSection(onJoin: widget.onJoin),
              ),
              _anchor(LandingSection.faq, const FaqSection()),
              _anchor(
                LandingSection.download,
                DownloadSection(onJoin: widget.onJoin),
              ),
              LandingFooter(scrollTo: _scrollTo),
            ],
          ),
        ),
      ),
    );
  }
}
