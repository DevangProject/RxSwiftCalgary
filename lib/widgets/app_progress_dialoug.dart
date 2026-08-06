import 'dart:ui';
import 'package:flutter/material.dart';

/// Source app icon, shared with the native launcher icon
/// (see flutter_launcher_icons config in pubspec.yaml).
const String _kAppIconAsset = 'assets/icon/app_icon.jpeg';

abstract class AppProgressDialog {
  static void show(
      BuildContext context, {
        String? message,
      }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => _ProgressDialogContent(message: message),
    );
  }

  /// Dismisses the topmost progress dialog, if one is present.
  static void hide(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

/// Reusable loader widget.
///
/// Use this when you want to show the same progress UI inside a screen,
/// for example in `today_route_screen.dart`.
///
/// Example:
/// return const AppProgressLoader(
///   message: "Loading today's route...",
/// );
class AppProgressLoader extends StatelessWidget {
  const AppProgressLoader({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = _DialogTokens.of(isDark);
    final screenSize = MediaQuery.sizeOf(context);

    final cardWidth = screenSize.width < 600
        ? screenSize.width * 0.82
        : 360.0;

    return Center(
      child: _DialogCard(
        width: cardWidth,
        tokens: tokens,
        message: message,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Internal widget
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressDialogContent extends StatefulWidget {
  const _ProgressDialogContent({this.message});

  final String? message;

  @override
  State<_ProgressDialogContent> createState() => _ProgressDialogContentState();
}

class _ProgressDialogContentState extends State<_ProgressDialogContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();

    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
    );

    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = _DialogTokens.of(isDark);
    final screenSize = MediaQuery.sizeOf(context);

    final cardWidth = screenSize.width < 600
        ? screenSize.width * 0.82
        : 360.0;

    return PopScope(
      canPop: false,
      child: FadeTransition(
        opacity: _fade,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.overlayColor,
                  ),
                ),
              ),
            ),
            Center(
              child: ScaleTransition(
                scale: _scale,
                child: _DialogCard(
                  width: cardWidth,
                  tokens: tokens,
                  message: widget.message,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Card body
// ─────────────────────────────────────────────────────────────────────────────

class _DialogCard extends StatelessWidget {
  const _DialogCard({
    required this.width,
    required this.tokens,
    required this.message,
  });

  final double width;
  final _DialogTokens tokens;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: tokens.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: tokens.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.shadowColor,
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: tokens.innerGlowColor,
            blurRadius: 0,
            spreadRadius: 0,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _BreathingLogo(),

          const SizedBox(height: 20),

          SizedBox(
            width: 48,
            height: 2.5,
            child: LinearProgressIndicator(
              borderRadius: BorderRadius.circular(4),
              valueColor: AlwaysStoppedAnimation<Color>(
                tokens.primaryColor,
              ),
              backgroundColor: tokens.primaryColor.withOpacity(0.15),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            message ?? 'Please wait while we complete\nthe operation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: tokens.subtitleColor,
              height: 1.55,
              decoration: TextDecoration.none,
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Animated logo
// ─────────────────────────────────────────────────────────────────────────────

class _BreathingLogo extends StatefulWidget {
  const _BreathingLogo();

  @override
  State<_BreathingLogo> createState() => _BreathingLogoState();
}

class _BreathingLogoState extends State<_BreathingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _breathe,
        curve: Curves.easeInOut,
      ),
    );

    _scale = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(
        parent: _breathe,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathe,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              _kAppIconAsset,
              width: 72,
              height: 72,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Design tokens
// ─────────────────────────────────────────────────────────────────────────────

class _DialogTokens {
  const _DialogTokens._({
    required this.primaryColor,
    required this.cardColor,
    required this.overlayColor,
    required this.borderColor,
    required this.shadowColor,
    required this.innerGlowColor,
    required this.titleColor,
    required this.subtitleColor,
  });

  final Color primaryColor;
  final Color cardColor;
  final Color overlayColor;
  final Color borderColor;
  final Color shadowColor;
  final Color innerGlowColor;
  final Color titleColor;
  final Color subtitleColor;

  factory _DialogTokens.of(bool isDark) {
    if (isDark) {
      return _DialogTokens._(
        primaryColor: const Color(0xFF0AA99B),
        cardColor: const Color(0xFF121C2B).withOpacity(0.92),
        overlayColor: const Color(0xFF0B1A33).withOpacity(0.55),
        borderColor: const Color(0xFF1E2D42),
        shadowColor: const Color(0xFF000000).withOpacity(0.45),
        innerGlowColor: Colors.transparent,
        titleColor: const Color(0xFFEDF2F7),
        subtitleColor: const Color(0xFF7A8BA0),
      );
    }

    return _DialogTokens._(
      primaryColor: const Color(0xFF0AA99B),
      cardColor: Colors.white.withOpacity(0.90),
      overlayColor: const Color(0xFF0B1A33).withOpacity(0.18),
      borderColor: const Color(0xFFDDE3EC),
      shadowColor: const Color(0xFF0B1A33).withOpacity(0.12),
      innerGlowColor: Colors.transparent,
      titleColor: const Color(0xFF0B1A33),
      subtitleColor: const Color(0xFF7A8BA0),
    );
  }
}