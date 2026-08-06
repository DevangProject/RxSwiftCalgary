import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxswift/features/today_route/provider/today_route_provider.dart';

import '../../core/network/auth_repository_impl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_progress_dialoug.dart';
import '../auth/login_screen.dart';
import '../route_details/route_detail_screen.dart';
import 'model/route_model.dart';

const _weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _formatTodayLabel() {
  final now = DateTime.now();
  return '${_weekdayNames[now.weekday - 1]}, ${now.day} ${_monthNames[now.month - 1]}';
}

/// Clears the session (tokens + this screen's cached route state) and sends
/// the driver back to the login screen, wiping the navigation stack.
///
/// Used both by the manual "log out" action and by the automatic sign-out
/// that fires when an API call reports the session has expired.
Future<void> _signOutAndGoToLogin(BuildContext context, WidgetRef ref) async {
  // Reset first so a later login never sees the previous driver's route,
  // availability or stale session-expired flag (the provider is not
  // autoDispose, so its state outlives this screen).
  ref.read(todayRouteProvider.notifier).reset();

  // Call the repository directly rather than going through the login-form's
  // `authProvider` (an autoDispose StateNotifier scoped to LoginScreen) —
  // nothing here keeps that notifier alive, so it can get disposed mid-flight
  // while this awaits the network call, throwing
  // "Tried to use AuthNotifier after dispose was called."
  await ref.read(authRepositoryProvider).logout();
  if (!context.mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      pageBuilder: (_, _, _) => const LoginScreen(),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ),
        (route) => false,
  );
}


class TodayRouteScreen extends ConsumerWidget {
  const TodayRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayRouteProvider);
    final notifier = ref.read(todayRouteProvider.notifier);

    ref.listen<TodayRouteState>(todayRouteProvider, (previous, next) {
      // ── Session expired (e.g. availability call came back 401) ──
      // Sign the driver out and bounce them to the login screen. Nothing
      // else on this screen is usable without a valid token, so this takes
      // priority over the error SnackBars below.
      if (next.isSessionExpired && previous?.isSessionExpired != true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Session expired. Please log in again.',
                    style: TextStyle(fontFamily: 'Poppins')),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          _signOutAndGoToLogin(context, ref);
        }
        return;
      }

      final msg = next.availabilityErrorMessage;
      if (msg != null &&
          msg != previous?.availabilityErrorMessage &&
          context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }

      final acceptMsg = next.acceptErrorMessage;
      if (acceptMsg != null &&
          acceptMsg != previous?.acceptErrorMessage &&
          context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content:
              Text(acceptMsg, style: const TextStyle(fontFamily: 'Poppins')),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App bar: profile, notifications, availability ──
              _HomeAppBar(state: state, notifier: notifier),

              // ── Page header ───────────────────────────────────
              if (state.isAvailable && state.isLoaded)
                _PageHeader(
                  totalStops: state.hasUnacceptedOrders
                      ? state.unacceptedOrders.length
                      : (state.route?.totalStops ?? 0),
                  completedStops: state.completedStops,
                ),

              // ── Body ──────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: _buildBody(context, state, notifier, ref),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: (state.isAvailable &&
                state.isLoaded &&
                state.hasUnacceptedOrders)
            ? _AcceptOrderBottomBar(
                state: state,
                onAccept: notifier.acceptAllUnacceptedOrders,
              )
            : null,
      ),
    );
  }

  Widget _buildBody(BuildContext context, TodayRouteState state,
      TodayRouteNotifier notifier, WidgetRef ref) {
    if (!state.isAvailable) {
      return _AvailabilityRequiredView(
        key: const ValueKey('unavailable'),
        onRetry: notifier.refresh,
      );
    }
    if (state.isLoading) {
      return const _LoadingView(key: ValueKey('loading'));
    }
    if (state.isError) {
      return _ErrorView(
        key: const ValueKey('error'),
        message: state.errorMessage ?? 'Something went wrong.',
        onRetry: notifier.refresh,
      );
    }
    if (state.isLoaded) {
      if (state.hasUnacceptedOrders) {
        return _UnacceptedOrdersBody(
          key: const ValueKey('unaccepted'),
          orders: state.unacceptedOrders,
        );
      }
      return _RouteBody(key: const ValueKey('body'), state: state);
    }
    return const _LoadingView(key: ValueKey('loading-fallback'));
  }
}

class TodayRouteScaffold extends StatelessWidget {
  const TodayRouteScaffold({super.key});

  @override
  Widget build(BuildContext context) => const TodayRouteScreen();
}

// ─────────────────────────────────────────────────────────────
//  Home App Bar  (profile, greeting, notifications, availability)
// ─────────────────────────────────────────────────────────────

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar({required this.state, required this.notifier});
  final TodayRouteState state;
  final TodayRouteNotifier notifier;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Log out?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text(
          'You will need to sign in again to access your routes.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text('Log out',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await _signOutAndGoToLogin(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOn = state.isAvailable;
    final isUpdating = state.isAvailabilityUpdating;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F1A1A1A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Profile avatar ──────────────────────────────────
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _logout(context, ref),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 12),

              // ── Greeting ─────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _formatTodayLabel(),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Notifications ────────────────────────────────────
              _NotificationButton(),
            ],
          ),

          const SizedBox(height: 16),

          // ── Availability pill ───────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOn
                  ? AppColors.success.withValues(alpha: 0.10)
                  : AppColors.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isOn
                    ? AppColors.success.withValues(alpha: 0.25)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isUpdating
                      ? const SizedBox(
                    key: ValueKey('spinner'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  )
                      : Icon(
                    key: ValueKey(isOn),
                    isOn
                        ? Icons.bolt_rounded
                        : Icons.pause_circle_outline_rounded,
                    size: 18,
                    color: isOn ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOn ? "You're online" : "You're offline",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isOn ? AppColors.successDark : AppColors.textSecondary,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch.adaptive(
                    value: isOn,
                    onChanged: isUpdating ? null : notifier.toggleAvailability,
                    activeThumbColor: AppColors.success,
                    inactiveThumbColor: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Notification bell with badge
// ─────────────────────────────────────────────────────────────

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('No new notifications',
                  style: TextStyle(fontFamily: 'Poppins')),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 20, color: AppColors.textSecondary),
          ),
          Positioned(
            top: 8,
            right: 9,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Page Header  "Tasks / Today (N)"
// ─────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.totalStops, required this.completedStops});
  final int totalStops;
  final int completedStops;

  @override
  Widget build(BuildContext context) {
    final progress = totalStops == 0 ? 0.0 : (completedStops / totalStops).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tasks',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Today ($totalStops routes)',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.route_rounded,
                      label: 'Total routes',
                      value: totalStops,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.check_circle_rounded,
                      label: 'Done',
                      value: completedStops,
                      color: AppColors.success,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (totalStops > 0)
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Stat Chip  (e.g. "Total routes: 17" / "Done: 5")
// ─────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Availability Required View
// ─────────────────────────────────────────────────────────────

class _AvailabilityRequiredView extends StatelessWidget {
  const _AvailabilityRequiredView({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _OfflineIllustration(),
            const SizedBox(height: 28),
            const Text(
              'You are currently offline',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please turn on availability to find today\'s task list.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _TryAgainButton(onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Offline illustration  (wifi bubble + floating accents)
// ─────────────────────────────────────────────────────────────

class _OfflineIllustration extends StatelessWidget {
  const _OfflineIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(top: 8, left: 16, child: _FloatingDiamond(size: 14)),
          const Positioned(top: 30, right: 10, child: _FloatingDiamond(size: 10)),
          const Positioned(bottom: 36, left: 4, child: _FloatingDiamond(size: 10)),
          const Positioned(bottom: 10, right: 30, child: _FloatingDiamond(size: 14)),

          // Outer soft halo
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.10),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),

          // Inner circle
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.14),
                  AppColors.teal.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.wifi_rounded,
              size: 56,
              color: AppColors.primary,
            ),
          ),

          // "Offline" badge
          Positioned(
            bottom: 26,
            right: 50,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 3),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingDiamond extends StatelessWidget {
  const _FloatingDiamond({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398, // 45°
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  "Try Again" pill button
// ─────────────────────────────────────────────────────────────

class _TryAgainButton extends StatelessWidget {
  const _TryAgainButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.full),
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.teal],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Loading
// ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppProgressLoader(
      message: "Loading today's route...",
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Error
// ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry',
                  style: TextStyle(fontFamily: 'Poppins')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Main Body  (grouped list)
// ─────────────────────────────────────────────────────────────

class _RouteBody extends ConsumerWidget {
  const _RouteBody({super.key, required this.state});
  final TodayRouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = state.route!;
    final stops = route.stops;

    // Split into three sections so "done", "running", and "upcoming" stops
    // are never mixed together in the same visual group.
    final running =
        stops.where((s) => s.status == StopStatus.inProgress).toList();
    final upcoming =
        stops.where((s) => s.status == StopStatus.pending).toList();
    final done = stops
        .where((s) =>
            s.status == StopStatus.completed || s.status == StopStatus.skipped)
        .toList();

    final List<_ListItem> items = [
      if (running.isNotEmpty)
        ..._buildSection(
          label: 'Running',
          icon: Icons.local_shipping_rounded,
          color: AppColors.teal,
          stops: running,
        ),
      if (upcoming.isNotEmpty)
        ..._buildSection(
          label: 'Upcoming',
          icon: Icons.schedule_rounded,
          color: AppColors.primary,
          stops: upcoming,
        ),
      if (done.isNotEmpty)
        ..._buildSection(
          label: 'Done',
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          stops: done,
        ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        switch (item) {
          case _SectionHeaderItem(:final label, :final icon, :final color, :final count):
            return _SectionHeader(
              label: label,
              icon: icon,
              color: color,
              count: count,
              topSpacing: index == 0 ? 0 : 20,
            );
          case _StopItem(:final stop, :final isFirst, :final isLast):
            return _TaskCard(
              stop: stop,
              isFirst: isFirst,
              isLast: isLast,
              isRouteActive: state.isRouteActive,
              onMarkDone: () => ref
                  .read(todayRouteProvider.notifier)
                  .markStopCompleted(stop.id),
              onTap: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => RouteDetailScreen(stop: stop),
                  ),
                );
                if (result == true) {
                  ref.read(todayRouteProvider.notifier).markStopCompleted(stop.id);
                }
              },
            );
          case _CollapseItem(:final count, :final groupLabel):
            return _MoreTasksDivider(count: count, label: groupLabel);
        }
      },
    );
  }

  List<_ListItem> _buildSection({
    required String label,
    required IconData icon,
    required Color color,
    required List<RouteStop> stops,
  }) {
    return [
      _SectionHeaderItem(label: label, icon: icon, color: color, count: stops.length),
      ..._buildItems(stops),
    ];
  }

  List<_ListItem> _buildItems(List<RouteStop> stops) {
    if (stops.isEmpty) return [];

    // Group consecutive stops that share the same store/patient name.
    final groups = <_StopGroup>[];
    _StopGroup? current;

    for (final stop in stops) {
      final key = stop.patientName; // use patientName as group key
      if (current == null || current.key != key) {
        current = _StopGroup(key: key, stops: [stop]);
        groups.add(current);
      } else {
        current.stops.add(stop);
      }
    }

    final items = <_ListItem>[];
    for (final group in groups) {
      final groupStops = group.stops;
      for (int i = 0; i < groupStops.length; i++) {
        final isFirst = i == 0;
        final isLast = i == groupStops.length - 1;

        // After the first stop in a group, insert the "X more tasks" banner
        // before the remaining stops (only when the group has > 1 stop).
        if (i == 1 && groupStops.length > 1) {
          items.add(_CollapseItem(
            count: groupStops.length - 1,
            groupLabel: group.key,
          ));
        }

        items.add(_StopItem(
          stop: groupStops[i],
          isFirst: isFirst,
          isLast: isLast,
        ));
      }
    }
    return items;
  }
}

// ── List item sealed types ────────────────────────────────────

sealed class _ListItem {}

class _SectionHeaderItem extends _ListItem {
  _SectionHeaderItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
  });
  final String label;
  final IconData icon;
  final Color color;
  final int count;
}

class _StopItem extends _ListItem {
  _StopItem({required this.stop, required this.isFirst, required this.isLast});
  final RouteStop stop;
  final bool isFirst;
  final bool isLast;
}

class _CollapseItem extends _ListItem {
  _CollapseItem({required this.count, required this.groupLabel});
  final int count;
  final String groupLabel;
}

class _StopGroup {
  _StopGroup({required this.key, required this.stops});
  final String key;
  final List<RouteStop> stops;
}

// ─────────────────────────────────────────────────────────────
//  Section header  ("Running (1)" / "Upcoming (5)" / "Done (3)")
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
    required this.topSpacing,
  });
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: color.withValues(alpha: 0.20), thickness: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  "X more tasks" divider row
// ─────────────────────────────────────────────────────────────

class _MoreTasksDivider extends StatelessWidget {
  const _MoreTasksDivider({required this.count, required this.label});
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            child: Divider(color: AppColors.border, thickness: 1),
          ),
          const SizedBox(width: 8),
          Text(
            '$count more task${count > 1 ? 's' : ''}',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Task Card  (matches target screenshot style)
// ─────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.stop,
    required this.isFirst,
    required this.isLast,
    required this.isRouteActive,
    required this.onMarkDone,
    required this.onTap,
  });

  final RouteStop stop;
  final bool isFirst;
  final bool isLast;
  final bool isRouteActive;
  final VoidCallback onMarkDone;
  final VoidCallback onTap;

  Color get _bubbleColor {
    switch (stop.status) {
      case StopStatus.completed:
        return AppColors.success;
      case StopStatus.inProgress:
        return AppColors.teal;
      case StopStatus.skipped:
        return AppColors.textSecondary;
      case StopStatus.pending:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = stop.status == StopStatus.completed;
    final isInProgress = stop.status == StopStatus.inProgress;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isInProgress
                    ? AppColors.teal.withValues(alpha: 0.35)
                    : AppColors.border.withValues(alpha: 0.70),
                width: isInProgress ? 1.2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: IntrinsicHeight(
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Status accent bar ──────────────────────────
                  Container(
                    width: 4,
                    color: _bubbleColor.withValues(alpha: isCompleted ? 0.35 : 1),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                // ── Status bubble ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _StatusBubble(
                    color: _bubbleColor,
                    isCompleted: isCompleted,
                  ),
                ),
                const SizedBox(width: 12),

                // ── Content ───────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store / patient name
                      Text(
                        stop.patientName,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Address
                      Text(
                        stop.address,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Service type row
                      Text(
                        'Service Type: - Regular',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Order number + chip + ready time
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '#${stop.orderId.length > 8 ? stop.orderId.substring(0, 8) : stop.orderId}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _TypeChip(
                              type: stop.stopType, dimmed: isCompleted),
                          const SizedBox(width: 6),
                          Text(
                            'Ready now',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: isCompleted
                                  ? AppColors.textHint
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      // Mark done button (only when in-progress)
                      if (isInProgress) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 30,
                          child: ElevatedButton.icon(
                            onPressed: onMarkDone,
                            icon:
                            const Icon(Icons.check_rounded, size: 14),
                            label: const Text(
                              'Mark as Done',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppRadius.full),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // ── Maps icon ─────────────────────────────────────
                Icon(
                  Icons.near_me_rounded,
                  size: 20,
                  color:
                  isCompleted ? AppColors.textHint : AppColors.textSecondary,
                ),
                        ],
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Status Bubble  (filled circle with ✓ or empty ring)
// ─────────────────────────────────────────────────────────────

class _StatusBubble extends StatelessWidget {
  const _StatusBubble({required this.color, required this.isCompleted});
  final Color color;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isCompleted ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: isCompleted ? null : Border.all(color: color, width: 2),
      ),
      child: isCompleted
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Pickup / Drop chip
// ─────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, required this.dimmed});
  final StopType type;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final isPickup = type == StopType.pickup;
    final base = isPickup ? AppColors.success : AppColors.primary;
    final color = dimmed ? AppColors.textHint : base;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Unaccepted Orders  (shown before today's route is loaded)
// ─────────────────────────────────────────────────────────────

class _UnacceptedOrdersBody extends StatelessWidget {
  const _UnacceptedOrdersBody({super.key, required this.orders});
  final List<UnacceptedOrder> orders;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: orders.length,
      itemBuilder: (context, index) =>
          _UnacceptedOrderCard(order: orders[index]),
    );
  }
}

class _UnacceptedOrderCard extends StatelessWidget {
  const _UnacceptedOrderCard({required this.order});
  final UnacceptedOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withOpacity(0.70)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.patientName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (order.priority) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: const Text(
                    'Priority',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _IconLine(
            icon: Icons.storefront_rounded,
            text: order.pharmacyName,
          ),
          const SizedBox(height: 4),
          _IconLine(
            icon: Icons.location_on_rounded,
            text: order.deliveryAddress,
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InfoChip(text: '#${order.orderNumber}'),
              if (order.handlingType.isNotEmpty)
                _InfoChip(text: order.handlingType),
              if (order.pickupWindowLabel.isNotEmpty)
                _InfoChip(text: order.pickupWindowLabel),
              if (order.statusLabel.isNotEmpty)
                _InfoChip(text: order.statusLabel, emphasize: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.maxLines = 1});
  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text, this.emphasize = false});
  final String text;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = emphasize ? AppColors.teal : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bottom Bar  (Accept Order — swipe)
// ─────────────────────────────────────────────────────────────

class _AcceptOrderBottomBar extends StatelessWidget {
  const _AcceptOrderBottomBar({required this.state, required this.onAccept});
  final TodayRouteState state;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: _SwipeToAcceptButton(
        label: 'Swipe to Accept Order',
        isLoading: state.isAccepting,
        onAccept: onAccept,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Swipe-to-accept slider control
// ─────────────────────────────────────────────────────────────

class _SwipeToAcceptButton extends StatefulWidget {
  const _SwipeToAcceptButton({
    required this.label,
    required this.isLoading,
    required this.onAccept,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onAccept;

  @override
  State<_SwipeToAcceptButton> createState() => _SwipeToAcceptButtonState();
}

class _SwipeToAcceptButtonState extends State<_SwipeToAcceptButton> {
  static const double _handleSize = 48;
  static const double _trackPadding = 4;
  static const double _acceptThreshold = 0.78;

  double _dragX = 0;
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant _SwipeToAcceptButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Snap the handle back once a (failed) accept call finishes. On success
    // the parent removes this order/rebuilds the list, so this widget is
    // typically disposed before it matters — this only covers the retry case.
    if (oldWidget.isLoading && !widget.isLoading) {
      setState(() => _dragX = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag =
            constraints.maxWidth - _handleSize - _trackPadding * 2;
        final progress =
        maxDrag <= 0 ? 0.0 : (_dragX / maxDrag).clamp(0.0, 1.0);

        return Container(
          height: 56,
          padding: const EdgeInsets.all(_trackPadding),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.10),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.success.withOpacity(0.25)),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: 1 - progress,
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: EdgeInsets.only(left: _dragX),
                width: _handleSize,
                height: _handleSize,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: GestureDetector(
                  onHorizontalDragStart: widget.isLoading
                      ? null
                      : (_) => setState(() => _dragging = true),
                  onHorizontalDragUpdate: widget.isLoading || maxDrag <= 0
                      ? null
                      : (details) {
                    setState(() {
                      _dragX =
                          (_dragX + details.delta.dx).clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: widget.isLoading
                      ? null
                      : (_) {
                    final accepted =
                        maxDrag > 0 && _dragX >= maxDrag * _acceptThreshold;
                    setState(() {
                      _dragging = false;
                      _dragX = accepted ? maxDrag : 0;
                    });
                    if (accepted) widget.onAccept();
                  },
                  child: widget.isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}