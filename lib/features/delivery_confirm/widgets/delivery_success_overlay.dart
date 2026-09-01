// ============================================================================
// lib/features/delivery_confirm/widgets/delivery_success_overlay.dart
//
// Full-screen "Delivered!" confirmation shown right after a delivery photo
// finishes uploading. Mirrors PickupSuccessContent (today_route/route_map/
// widgets/pickup_photo_sheet.dart) so the two success animations read as
// the same product — same layout, timing and auto-dismiss behaviour.
// ============================================================================

import 'package:flutter/material.dart';

import '../../route_map/theme/route_map_theme.dart';

/// Shows the full-screen "Delivered!" animation and resolves once it has
/// auto-dismissed itself (~1.7s later) — the caller then pops the delivery
/// confirmation screen so the driver lands back on today's route without
/// pressing anything.
Future<void> showDeliverySuccess(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: RouteColors.tealDarker.withValues(alpha: 0.98),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => const DeliverySuccessContent(),
  );
}

class DeliverySuccessContent extends StatefulWidget {
  const DeliverySuccessContent({super.key});

  @override
  State<DeliverySuccessContent> createState() =>
      _DeliverySuccessContentState();
}

class _DeliverySuccessContentState extends State<DeliverySuccessContent>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1700);

  late final AnimationController _controller;
  late final Animation<double> _iconScale;
  late final Animation<double> _ring;
  late final Animation<double> _titleFade;
  late final Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          Navigator.of(context).pop();
        }
      })
      ..forward();

    _iconScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    );
    _ring = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
    );
    _subtitleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [RouteColors.teal, RouteColors.tealDarker],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outward-fading pulse ring behind the badge.
                        Opacity(
                          opacity: (1 - _ring.value).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.6 + _ring.value * 0.8,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: _iconScale.value,
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 44,
                              color: RouteColors.tealDark,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _titleFade,
                child: const Text(
                  'Delivered!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FadeTransition(
                opacity: _subtitleFade,
                child: Text(
                  'Moving to next stop…',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _subtitleFade,
                child: SizedBox(
                  width: 120,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => LinearProgressIndicator(
                        value: _controller.value,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
