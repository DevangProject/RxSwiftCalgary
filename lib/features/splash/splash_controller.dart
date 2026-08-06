import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Signature for the one-shot "the splash flow is done" callback.
///
/// [hadError] is `true` when the video failed to initialize/play, in which
/// case the caller should skip the login check and go straight to login.
typedef SplashFinishedCallback = void Function({required bool hadError});

/// Drives the splash video: asset loading, the "taking too long" fallback
/// spinner, playback-completion detection, and app-lifecycle pause/resume.
///
/// This is deliberately a plain [ChangeNotifier] rather than logic inlined
/// in the widget's State — it keeps [SplashScreen] a dumb view and makes
/// the playback/lifecycle rules easy to reason about (and test) in
/// isolation, per Clean Architecture separation of concerns.
class SplashController extends ChangeNotifier {
  SplashController({
    required String assetPath,
    required this.onFinished,
    this.slowInitThreshold = const Duration(seconds: 2),
  }) : _assetPath = assetPath;

  final String _assetPath;
  final SplashFinishedCallback onFinished;

  /// How long initialization is allowed to run before the loading
  /// indicator is shown to the user (requirement: show a spinner only if
  /// init takes longer than 2 seconds).
  final Duration slowInitThreshold;

  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;

  bool _isReady = false;
  bool get isReady => _isReady;

  bool _showLoader = false;
  bool get showLoader => _showLoader;

  Timer? _slowInitTimer;

  /// Guards [onFinished] so it can only ever fire once, even if the video's
  /// position listener fires more than once near end-of-playback or a
  /// lifecycle event races with an in-flight completion.
  bool _finished = false;

  /// Loads and starts the splash video. Safe to call once per controller
  /// instance (called from `initState`).
  Future<void> initialize() async {
    // Only surface the spinner if init is still running after the
    // threshold — this avoids a flash of loader on fast devices.
    _slowInitTimer = Timer(slowInitThreshold, () {
      if (!_isReady) {
        _showLoader = true;
        notifyListeners();
      }
    });

    try {
      final controller = VideoPlayerController.asset(_assetPath);
      _videoController = controller;

      await controller.initialize();
      _slowInitTimer?.cancel();

      _isReady = true;
      _showLoader = false;
      notifyListeners();

      controller.addListener(_onVideoTick);
      await controller.play();
    } catch (error, stackTrace) {
      _slowInitTimer?.cancel();
      debugPrint('SplashController: failed to initialize video: $error');
      debugPrintStack(stackTrace: stackTrace);
      _finish(hadError: true);
    }
  }

  void _onVideoTick() {
    final value = _videoController?.value;
    if (value == null || !value.isInitialized) return;

    // Playback has reached (or passed) the end and is no longer playing —
    // this is the single natural-completion signal we act on.
    final reachedEnd = value.duration > Duration.zero &&
        value.position >= value.duration &&
        !value.isPlaying;

    if (reachedEnd) {
      _finish(hadError: false);
    }
  }

  void _finish({required bool hadError}) {
    if (_finished) return;
    _finished = true;
    onFinished(hadError: hadError);
  }

  /// Pauses playback — called when the app goes to background.
  void pause() {
    if (_videoController?.value.isInitialized == true) {
      _videoController?.pause();
    }
  }

  /// Resumes playback — called when the app returns to foreground.
  /// No-ops once navigation has already been triggered.
  void resume() {
    if (_finished) return;
    if (_videoController?.value.isInitialized == true) {
      _videoController?.play();
    }
  }

  @override
  void dispose() {
    _slowInitTimer?.cancel();
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    super.dispose();
  }
}
