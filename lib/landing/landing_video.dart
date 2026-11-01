import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'landing_style.dart';

/// Whether the landing page's screen recordings are playing, shared by every
/// [LoopingVideo] and the "Pause videos" button.
class LandingMotion extends InheritedNotifier<ValueNotifier<bool>> {
  const LandingMotion({
    super.key,
    required ValueNotifier<bool> paused,
    required this.videosEnabled,
    required super.child,
  }) : super(notifier: paused);

  /// False in tests and anywhere video playback isn't available; the
  /// recordings then show their poster frames.
  final bool videosEnabled;

  static LandingMotion of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LandingMotion>()!;

  bool get paused => notifier!.value;
}

/// A muted, looping screen recording that shows its poster until it can play.
class LoopingVideo extends StatefulWidget {
  const LoopingVideo({
    super.key,
    required this.video,
    required this.poster,
    required this.label,
    this.background = LandingColors.mist,
  });

  final String video;
  final String poster;
  final String label;
  final Color background;

  @override
  State<LoopingVideo> createState() => _LoopingVideoState();
}

class _LoopingVideoState extends State<LoopingVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = LandingMotion.of(context);
    if (motion.videosEnabled && _controller == null) {
      final controller = VideoPlayerController.asset(
        'assets/landing/${widget.video}',
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      controller
          .initialize()
          .then((_) async {
            await controller.setVolume(0);
            await controller.setLooping(true);
            if (!mounted) return;
            setState(() => _ready = true);
            _sync();
          })
          .catchError((Object _) {
            // Keep showing the poster frame.
          });
    }
    _sync();
  }

  void _sync() {
    final controller = _controller;
    if (controller == null || !_ready) return;
    if (LandingMotion.of(context).paused) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Semantics(
      label: widget.label,
      image: true,
      child: ColoredBox(
        color: widget.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Screenshot(widget.poster, label: ''),
            if (_ready && controller != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: ExcludeSemantics(child: VideoPlayer(controller)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
