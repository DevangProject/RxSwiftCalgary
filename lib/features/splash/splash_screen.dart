import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/services/auth_status_service.dart';
import '../auth/login_screen.dart';
import '../today_route/today_route_screen.dart';
import 'splash_controller.dart';

/// Path to the bundled intro video. Must be listed under `flutter/assets`
/// in pubspec.yaml.
const String _kSplashVideoAsset = 'assets/videos/logo_intro.mp4';

/// Background shown behind/before the video and in any letterboxed edges
/// left by BoxFit.cover. Swap to Colors.white if the intro video has a
/// white (rather than black) backdrop, so there's no color mismatch flash.
const Color _kSplashBackground = Colors.black;

/// Full-screen splash video that plays once on launch, then routes to
/// [TodayRouteScreen] (logged in) or [LoginScreen] (not logged in).
///
/// All playback/lifecycle logic lives in [SplashController] — this widget
/// only renders state and reacts to lifecycle callbacks.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with WidgetsBindingObserver {
  late final SplashController _controller;

  /// Guards against navigating more than once — e.g. the video-finished
  /// callback and a stray lifecycle event both trying to push the next
  /// screen.
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Video is full-bleed and dark by default; keep status bar icons light.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _controller = SplashController(
      assetPath: _kSplashVideoAsset,
      onFinished: _handleFinished,
    )..addListener(_onControllerChanged);

    // Kick off asset load/playback immediately so there's no idle frame
    // before the first video frame is ready.
    _controller.initialize();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// Called once by [SplashController] when the video finishes (or fails).
  /// On error we skip straight to login; otherwise we resolve the login
  /// state and route accordingly.
  Future<void> _handleFinished({required bool hadError}) async {
    if (hadError) {
      _navigateTo(const LoginScreen());
      return;
    }

    final isLoggedIn =
        await ref.read(authStatusServiceProvider).isLoggedIn();
    if (!mounted) return;

    _navigateTo(isLoggedIn ? const TodayRouteScaffold() : const LoginScreen());
  }

  void _navigateTo(Widget screen) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _controller.pause();
        break;
      case AppLifecycleState.resumed:
        _controller.resume();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _controller.videoController;
    final isReady = _controller.isReady && video != null;

    // PopScope(canPop: false) blocks the Android back button so the intro
    // can't be dismissed/skipped.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _kSplashBackground,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (isReady) _CoverVideo(controller: video),
            // Only shown once init has exceeded the 2s threshold, so fast
            // loads never flash a spinner.
            if (_controller.showLoader && !isReady)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Renders [controller]'s video scaled to fully cover the available space
/// (no letterbox bars) while cropping the *minimum* amount necessary to do
/// so, based on the video's true display aspect ratio.
///
/// Deliberately uses [VideoPlayerValue.aspectRatio] — which video_player
/// normalizes for any rotation metadata on the source file — rather than
/// the raw [VideoPlayerValue.size]. Reading raw pixel width/height directly
/// can report the pre-rotation frame size for portrait-shot videos, which
/// silently feeds the wrong ratio into the cover calculation and makes the
/// crop look far more aggressive ("too zoomed in") than it needs to be.
class _CoverVideo extends StatelessWidget {
  const _CoverVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Actual on-screen box the video must fill, taken directly from
        // the incoming layout constraints (equivalent to screen
        // width/height here, since the parent Stack uses StackFit.expand).
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final screenAspectRatio = screenWidth / screenHeight;
        final videoAspectRatio = controller.value.aspectRatio;

        double renderWidth;
        double renderHeight;
        if (screenAspectRatio > videoAspectRatio) {
          // Screen is proportionally wider than the video: match width
          // exactly, let height overflow — crops only top/bottom.
          renderWidth = screenWidth;
          renderHeight = renderWidth / videoAspectRatio;
        } else {
          // Screen is proportionally taller than the video: match height
          // exactly, let width overflow — crops only left/right.
          renderHeight = screenHeight;
          renderWidth = renderHeight * videoAspectRatio;
        }

        return ClipRect(
          child: OverflowBox(
            maxWidth: renderWidth,
            maxHeight: renderHeight,
            child: SizedBox(
              width: renderWidth,
              height: renderHeight,
              // IgnorePointer + no controls widget => no scrubbing,
              // pausing, or tapping is possible.
              child: IgnorePointer(
                child: VideoPlayer(controller),
              ),
            ),
          ),
        );
      },
    );
  }
}
