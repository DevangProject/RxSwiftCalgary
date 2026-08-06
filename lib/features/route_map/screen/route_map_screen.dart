// ============================================================================
// features/today_route/route_map/screen/route_map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery_confirm/delivery_confirm_screen.dart';
import '../../delivery_confirm/provider/delivery_confirmation_provider.dart';
import '../../failed_delivery/presentation/screens/failed_delivery_screen.dart';
import '../../navigation/navigation_screen.dart';
import '../../today_route/model/route_model.dart';
import '../../today_route/provider/today_route_provider.dart';
import '../navigation_bridge/navigation_bridge.dart';
import '../provider/map_projection.dart';
import '../provider/route_map_provider.dart';
import '../theme/route_map_theme.dart';
import '../widgets/route_header.dart';
import '../widgets/route_map_view.dart';
import '../widgets/stop_bottom_sheet.dart';

class RouteMapScreen extends ConsumerWidget {
  const RouteMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = ref.watch(todayRouteProvider);

    return Scaffold(
      backgroundColor: RouteColors.tealDark,
      body: switch (routeState.loadStatus) {
        RouteLoadStatus.loading || RouteLoadStatus.idle =>
        const _CenteredOnTeal(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        RouteLoadStatus.error => _ErrorView(
          message:
          routeState.errorMessage ?? 'Could not load your route.',
          onRetry: () =>
              ref.read(todayRouteProvider.notifier).refresh(),
          onBack: () => Navigator.of(context).maybePop(),
        ),
        RouteLoadStatus.loaded => routeState.route == null ||
            routeState.route!.stops.isEmpty
            ? _EmptyView(onBack: () => Navigator.of(context).maybePop())
            : _LoadedBody(routeState: routeState),
      },
    );
  }
}

class _LoadedBody extends ConsumerWidget {
  const _LoadedBody({required this.routeState});
  final TodayRouteState routeState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = routeState.route!;
    final ui = ref.watch(routeMapUiProvider);
    final uiNotifier = ref.read(routeMapUiProvider.notifier);
    final routeNotifier = ref.read(todayRouteProvider.notifier);

    final selectedIndex = ui.selectedIndex.clamp(0, route.stops.length - 1);
    final stop = route.stops[selectedIndex];
    final projection = MapProjection.fromRoute(route);

    Future<void> completeAndAdvance(RouteStop s) async {
      routeNotifier.markStopCompleted(s.id);
      uiNotifier.syncSelectionToProgress();
    }

    return Column(
      children: [
        RouteHeader(
          state: routeState,
          onBack: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: RouteMapView(
                  route: route,
                  selectedIndex: selectedIndex,
                  projection: projection,
                  onMarkerTap: uiNotifier.selectStop,
                  onRecenter: () =>
                      _toast(context, 'Centering on your location'),
                  onZoomIn: () => _toast(context, 'Zoom in'),
                  onZoomOut: () => _toast(context, 'Zoom out'),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: StopBottomSheet(
                  stop: stop,
                  indexLabel:
                  'Stop ${selectedIndex + 1} of ${route.stops.length}',
                  expanded: ui.sheetExpanded,
                  canGoPrev: selectedIndex > 0,
                  canGoNext: selectedIndex < route.stops.length - 1,
                  isPickupLoading: routeState.isPickupLoading &&
                      routeState.activePickupOrderId == stop.id,
                  onToggle: uiNotifier.toggleSheet,
                  onPrev: uiNotifier.prevStop,
                  onNext: uiNotifier.nextStop,
                  onNavigate: () =>
                      _startTurnByTurnNavigation(context, route.stops),
                  onPickup: () async {
                    if (stop.id.isEmpty) {
                      _toast(context,
                          'Invalid order. Please refresh and try again.');
                      return;
                    }
                    final success = true;
                    /* final success = await ref
                        .read(todayRouteProvider.notifier)
                        .pickupOrder(stop.id);*/
                    if (!context.mounted) return;
                    if (success) {
                      await _showPickupSuccess(context);
                      if (!context.mounted) return;
                      await completeAndAdvance(stop);
                    } else {
                      final errorMessage =
                          ref.read(todayRouteProvider).pickupErrorMessage ??
                              'Unable to pickup order. Please try again.';
                      _toast(context, errorMessage);
                    }
                  },

                  // ── Delivered: now passes orderId + order info ──────────
                  onDelivered: () => _openDeliveryConfirmation(
                    context,
                    stop,
                    onConfirmed: () => completeAndAdvance(stop),
                  ),

                  onFailed: () => _openFailedDelivery(context, stop),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: RouteColors.tealDark,
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }

  Future<void> _showPickupSuccess(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: RouteColors.teal.withOpacity(0.96),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => const _PickupSuccessContent(),
    );
  }

  void _startTurnByTurnNavigation(
      BuildContext context, List<RouteStop> stops) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderScope(
          overrides: [buildNavigationOverride(stops)],
          child: const NavigationMapScreen(),
        ),
      ),
    );
  }

  // ── Delivered → DeliveryConfirmationScreen ────────────────────────────────
  //
  // CHANGE: we now build DeliveryOrderArgs from the live RouteStop and pass
  //         orderId explicitly so the upload hits the correct API endpoint.
  Future<void> _openDeliveryConfirmation(
      BuildContext context,
      RouteStop stop, {
        required VoidCallback onConfirmed,
      }) async {
    final args = DeliveryOrderArgs(
      orderId: stop.id,
      customerName: stop.patientName,
      address: stop.address,
      pharmacyName: stop.pharmacyName,
      statusLabel: 'Arrived at destination',
    );

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DeliveryConfirmationScreen(
          orderId: stop.id,
          orderArgs: args,
          deliveryAddress: '',
          pharmacyName: '', customerName: '',
        ),
      ),
    );

    if (result == true) onConfirmed();
  }

  // ── Failed → FailedDeliveryScreen ─────────────────────────────────────────
  Future<void> _openFailedDelivery(
      BuildContext context, RouteStop stop) async {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FailedDeliveryScreen(
        orderId:      stop.orderId,
        customerName: stop.patientName,
        address:      stop.address,
        pharmacyName: stop.pharmacyName,
      ),
    ));
  }
}

// ── Loading / error / empty scaffolds ─────────────────────────────────────

class _CenteredOnTeal extends StatelessWidget {
  const _CenteredOnTeal({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Container(color: RouteColors.tealDark, child: Center(child: child));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RouteColors.tealDark,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                ),
              ),
              const Spacer(),
              const Icon(Icons.cloud_off_rounded,
                  size: 56, color: Colors.white70),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: RouteColors.tealDark,
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RouteColors.tealDark,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                ),
              ),
              const Spacer(),
              const Icon(Icons.inbox_rounded,
                  size: 56, color: Colors.white70),
              const SizedBox(height: 14),
              const Text(
                'No stops on your route yet.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickupSuccessContent extends StatefulWidget {
  const _PickupSuccessContent();

  @override
  State<_PickupSuccessContent> createState() => _PickupSuccessContentState();
}

class _PickupSuccessContentState extends State<_PickupSuccessContent> {
  @override
  void initState() {
    super.initState();
    Future.delayed(
      const Duration(milliseconds: 1500),
          () { if (mounted) Navigator.of(context).pop(); },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 38, color: Colors.white),
          ),
          const SizedBox(height: 14),
          const Text(
            'Picked Up!',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Moving to next stop…',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}