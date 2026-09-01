// ============================================================================
// widgets/connectivity_banner.dart
// App-wide reaction to the device losing/regaining internet. Wrapped around
// the whole app (see MaterialApp.builder in main.dart) so every screen gets
// the same treatment for free, without each feature wiring up connectivity
// itself:
//   - offline  -> the entire app is blocked behind a "No internet" popup
//   - restored -> popup drops, a brief "Back online" strip confirms it
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/connectivity_service.dart';
import '../theme/app_theme.dart';

class ConnectivityBanner extends ConsumerStatefulWidget {
  const ConnectivityBanner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConnectivityBanner> createState() =>
      _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner> {
  bool? _wasConnected;
  bool _showRestored = false;
  Timer? _restoredTimer;

  @override
  void dispose() {
    _restoredTimer?.cancel();
    super.dispose();
  }

  void _handleStatusChange(bool isConnected) {
    if (_wasConnected == false && isConnected) {
      _restoredTimer?.cancel();
      setState(() => _showRestored = true);
      _restoredTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showRestored = false);
      });
    }
    _wasConnected = isConnected;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(connectivityStatusProvider, (_, next) {
      final isConnected = next.valueOrNull;
      if (isConnected != null) _handleStatusChange(isConnected);
    });

    final isConnected =
        ref.watch(connectivityStatusProvider).valueOrNull ?? true;

    return Stack(
      children: [
        // Fully disable interaction with the app while offline — nothing
        // underneath can be tapped, scrolled, or navigated.
        IgnorePointer(
          ignoring: !isConnected,
          child: widget.child,
        ),
        if (!isConnected) const _OfflineOverlay(),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_showRestored,
            child: SafeArea(
              bottom: false,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                offset: _showRestored ? Offset.zero : const Offset(0, -1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showRestored ? 1 : 0,
                  child: const _RestoredStrip(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen blocking popup shown while the device has no internet.
class _OfflineOverlay extends StatelessWidget {
  const _OfflineOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.errorBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: AppColors.error,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'No Internet Connection',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Please check your network settings. You'll be able to "
                  'continue as soon as you\'re back online.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Transient top strip confirming the connection came back.
class _RestoredStrip extends StatelessWidget {
  const _RestoredStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.success,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Back online',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
