// ============================================================================
// features/today_route/route_map/screen/route_map_screen.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rxswift/features/today_route/model/route_model.dart';

import '../../../delivery_confirm/delivery_confirm_screen.dart';
import '../../../failed_delivery/presentation/screens/failed_delivery_screen.dart';
import '../../../navigation/navigation_screen.dart';
import '../../../route_map/navigation_bridge/navigation_bridge.dart';
import '../../../route_map/provider/route_map_provider.dart';
import '../../../route_map/theme/route_map_theme.dart';
import '../../../route_map/widgets/route_header.dart';
import '../../../route_map/widgets/stop_bottom_sheet.dart';
import '../../provider/today_route_provider.dart';
import '../provider/driver_location_provider.dart';
import '../provider/live_route_provider.dart';
import '../provider/location_sync_provider.dart';
import '../repository/location_sync_repository.dart';
import '../widgets/pickup_photo_sheet.dart';
import '../widgets/route_map_google_view.dart';

class RouteMapScreen extends ConsumerStatefulWidget {
  const RouteMapScreen({super.key});

  @override
  ConsumerState<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends ConsumerState<RouteMapScreen> {

  // Manual subscription to driverLocationProvider — owned here so we can cancel it.
  // ref.listenManual works outside build(); ref.listen only works inside build().
  ProviderSubscription<AsyncValue<DriverPosition>>? _driverSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocationSync());
  }

  @override
  void dispose() {
    _driverSub?.close();
    ref.read(locationSyncProvider.notifier).stop();
    super.dispose();
  }

  // ── Location permission + start everything ────────────────────────────────

  Future<void> _initLocationSync() async {
    if (!mounted) return;

    final repo = ref.read(locationSyncRepositoryProvider);
    final readiness = await repo.requestPermission();
    if (!mounted) return;

    switch (readiness) {
      case LocationReadiness.ready:
        _startTracking();

      case LocationReadiness.serviceDisabled:
        await _showLocationServiceDialog(repo);

      case LocationReadiness.permissionDenied:
        _showPermissionBanner(
            'Location permission denied. Live tracking disabled.');

      case LocationReadiness.permissionPermanentlyDenied:
        await _showPermanentlyDeniedDialog(repo);
    }
  }

  /// Called once permission is granted.
  /// Wires up:
  ///   1. driverLocationProvider  → GPS stream starts
  ///   2. liveRouteProvider       → redraws route on every GPS fix
  ///   3. locationSyncProvider    → sends location to API every 1 min
  void _startTracking() {
    // Warm up the GPS stream.
    ref.read(driverLocationProvider);

    // Start 1-min API sync timer.
    ref.read(locationSyncProvider.notifier).start();

    // One listenManual subscription drives both:
    //   1. liveRouteProvider  — redraws route on every GPS fix
    //   2. locationSyncProvider — keeps latest position for 1-min timer
    _driverSub?.close();
    _driverSub = ref.listenManual<AsyncValue<DriverPosition>>(
      driverLocationProvider,
          (_, next) => next.whenData(_onDriverPosition),
    );
  }

  /// Called on every GPS fix.
  void _onDriverPosition(DriverPosition pos) {
    if (!mounted) return;

    // Feed latest position to the 1-min sync timer.
    ref.read(locationSyncProvider.notifier).updateLatestPosition(pos);

    // Find the next unfinished stop from live todayRouteProvider state.
    final stops = ref.read(todayRouteProvider).route?.stops ?? [];
    RouteStop? nextStop;
    for (final s in stops) {
      if (!s.hasCoordinates) continue;
      if (s.status == StopStatus.completed || s.status == StopStatus.skipped) {
        continue;
      }
      nextStop = s;
      break;
    }

    if (nextStop == null) return; // all stops done

    // Update live road route: driver → next stop.
    ref.read(liveRouteProvider.notifier).updateTarget(
      pos.latLng,
      LatLng(nextStop.latitude, nextStop.longitude),
    );
  }

  // ── Permission dialogs (unchanged from original) ─────────────────────────

  Future<void> _showLocationServiceDialog(LocationSyncRepository repo) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Location Required',
            style: TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text(
          'Location services are off. Please enable GPS so the app can track your route.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Skip')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: RouteColors.tealDark),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await repo.openLocationSettings();
      if (mounted) await _initLocationSync();
    }
  }

  Future<void> _showPermanentlyDeniedDialog(
      LocationSyncRepository repo) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Location Permission Needed',
            style: TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text(
          'Location permission was permanently denied. Please grant it in app settings.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Skip')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: RouteColors.tealDark),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('App Settings'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await repo.openAppSettings();
      if (mounted) await _initLocationSync();
    }
  }

  void _showPermissionBanner(String message) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: RouteColors.tealDark,
        content: Text(message,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context)
                .hideCurrentMaterialBanner(),
            child:
            const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(todayRouteProvider);

    return Scaffold(
      backgroundColor: RouteColors.tealDark,
      body: switch (routeState.loadStatus) {
        RouteLoadStatus.loading || RouteLoadStatus.idle =>
        const _CenteredOnTeal(
            child: CircularProgressIndicator(color: Colors.white)),
        RouteLoadStatus.error => _ErrorView(
          message:
          routeState.errorMessage ?? 'Could not load your route.',
          onRetry: () =>
              ref.read(todayRouteProvider.notifier).refresh(),
          onBack: () => Navigator.of(context).maybePop(),
        ),
        RouteLoadStatus.loaded =>
        routeState.route == null || routeState.route!.stops.isEmpty
            ? _EmptyView(onBack: () => Navigator.of(context).maybePop())
            : _LoadedBody(routeState: routeState),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LoadedBody — identical to uploaded file
// ─────────────────────────────────────────────────────────────────────────────

class _LoadedBody extends ConsumerWidget {
  const _LoadedBody({required this.routeState});
  final TodayRouteState routeState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = routeState.route!;
    final ui = ref.watch(routeMapUiProvider);
    final uiNotifier = ref.read(routeMapUiProvider.notifier);
    final routeNotifier = ref.read(todayRouteProvider.notifier);

    final selectedIndex =
    ui.selectedIndex.clamp(0, route.stops.length - 1);
    final stop = route.stops[selectedIndex];

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
                child: RouteMapGoogleView(
                  route: route,
                  selectedIndex: selectedIndex,
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
                  onToggle: uiNotifier.toggleSheet,
                  onPrev: uiNotifier.prevStop,
                  onNext: uiNotifier.nextStop,
                  onNavigate: () => _startTurnByTurnNavigation(
                      context, route.stops.cast<RouteStop>()),
                  onPickup: () => _handlePickup(
                    context,
                    ref,
                    stop,
                    onConfirmed: () => completeAndAdvance(stop),
                  ),
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

  // ── Pickup: show photo + location sheet, then call API ───────────────────
  Future<void> _handlePickup(
      BuildContext context,
      WidgetRef    ref,
      RouteStop    stop, {
        required VoidCallback onConfirmed,
      }) async {
    if (stop.id.isEmpty) {
      _toast(context, 'Invalid order. Please refresh and try again.');
      return;
    }

    // 1. Show the pickup photo + location popup.
    final result = await showPickupPhotoSheet(
      context,
      stopAddress: stop.address,
    );

    // Driver dismissed the sheet without confirming.
    if (result == null || !context.mounted) return;

    // 2. Call the API with photo + coordinates.
    final success = await ref.read(todayRouteProvider.notifier).pickupOrder(
      orderId:   stop.orderId,
      photoPath: result.photoPath,
      latitude:  result.latitude,
      longitude: result.longitude,
    );

    if (!context.mounted) return;

    // 3. Handle result.
    if (success) {
      await showPickupSuccess(context);
      if (!context.mounted) return;
      onConfirmed();
    } else {
      final errorMessage =
          ref.read(todayRouteProvider).pickupErrorMessage ??
              'Unable to confirm pickup. Please try again.';
      _toast(context, errorMessage);
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: RouteColors.tealDark,
        duration: const Duration(milliseconds: 1400),
      ));
  }

  void _startTurnByTurnNavigation(
      BuildContext context, List<RouteStop> stops) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProviderScope(
        overrides: [buildNavigationOverride(stops.cast<RouteStop>())],
        child: const NavigationMapScreen(),
      ),
    ));
  }

  Future<void> _openDeliveryConfirmation(
      BuildContext context,
      RouteStop stop, {
        required VoidCallback onConfirmed,
      }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) =>
              DeliveryConfirmationScreen(orderId: stop.orderId,customerName:"Patient Name:${stop.patientName}",deliveryAddress: stop.address,pharmacyName: stop.pharmacyName)),
    );
    if (result == true) onConfirmed();
  }

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

// ── Static scaffolds (unchanged) ─────────────────────────────────────────

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
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.white)),
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
              const Text('No stops on your route yet.',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.white)),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

