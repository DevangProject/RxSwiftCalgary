import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:rxswift/features/navigation/provider/navigation_provider.dart';
import '../../model/navigation/navigation_model.dart';
import '../../service/navigation_marker_factory.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text.dart';
import '../today_route/today_route_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Navigation Map Screen
// ─────────────────────────────────────────────────────────────

class NavigationMapScreen extends ConsumerStatefulWidget {
  const NavigationMapScreen({super.key});

  @override
  ConsumerState<NavigationMapScreen> createState() =>
      _NavigationMapScreenState();
}

class _NavigationMapScreenState extends ConsumerState<NavigationMapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bottomCardController;
  late final Animation<Offset> _bottomCardSlide;
  late final Animation<double> _bottomCardFade;

  @override
  void initState() {
    super.initState();
    _bottomCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _bottomCardSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _bottomCardController, curve: Curves.easeOut));
    _bottomCardFade = CurvedAnimation(
        parent: _bottomCardController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _bottomCardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(navigationProvider);

    // Reveal the bottom card the moment we're actually navigating.
    if (state.status.isReadyForMap &&
        _bottomCardController.status == AnimationStatus.dismissed) {
      _bottomCardController.forward();
    }

    // Listen for trip ended — pop back to route list.
    ref.listen<NavigationState>(navigationProvider, (prev, next) {
      if (next.isEnded && prev?.isEnded != true && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const TodayRouteScaffold(),
            transitionsBuilder: (_, anim, _, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            // 1. Google Map (full screen) — only built when ready
            if (state.status.isReadyForMap) _MapView(state: state),

            // 2. Top navigation header
            _TopHeader(currentStop: state.currentStop),

            // 3. Blocking overlay (loading / permission / error)
            if (state.status.isBlocking)
              _StatusOverlay(state: state)
            else if (state.status.isReadyForMap)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _bottomCardSlide,
                  child: FadeTransition(
                    opacity: _bottomCardFade,
                    child: _BottomInfoCard(state: state),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Google Map View — with custom markers
// ─────────────────────────────────────────────────────────────

class _MapView extends ConsumerStatefulWidget {
  const _MapView({required this.state});
  final NavigationState state;

  @override
  ConsumerState<_MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<_MapView> {
  final Map<MarkerId, Marker> _markers = {};
  bool _markersLoaded = false;

  @override
  void initState() {
    super.initState();
    _rebuildMarkers();
  }

  @override
  void didUpdateWidget(covariant _MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.currentStopIndex != widget.state.currentStopIndex ||
        oldWidget.state.driverLocation != widget.state.driverLocation ||
        oldWidget.state.stops != widget.state.stops) {
      _rebuildMarkers();
    }
  }

  Future<void> _rebuildMarkers() async {
    final factory = NavigationMarkerFactory.instance;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final markers = <MarkerId, Marker>{};

    for (int i = 0; i < widget.state.stops.length; i++) {
      final stop = widget.state.stops[i];
      final BitmapDescriptor icon;
      final double zIndex;

      switch (stop.status) {
        case StopStatus.delivered:
          icon = await factory.deliveredStopMarker(stop.stopNumber,
              devicePixelRatio: dpr);
          zIndex = 1;
          break;
        case StopStatus.current:
          icon = await factory.currentStopMarker(stop.stopNumber,
              devicePixelRatio: dpr);
          zIndex = 3;
          break;
        case StopStatus.pending:
        case StopStatus.skipped:
          icon = await factory.pendingStopMarker(stop.stopNumber,
              devicePixelRatio: dpr);
          zIndex = 2;
          break;
      }

      final id = MarkerId('stop_${stop.id}');
      markers[id] = Marker(
        markerId: id,
        position: stop.location,
        icon: icon,
        zIndex: zIndex,
        anchor: const Offset(0.5, 1.0),
        infoWindow: InfoWindow(
          title: '${stop.stopNumber}. ${stop.patientName}',
          snippet: stop.address,
        ),
      );
    }

    // Driver marker
    if (widget.state.driverLocation != null) {
      final driverIcon = await factory.driverMarker(devicePixelRatio: dpr);
      const id = MarkerId('driver');
      markers[id] = Marker(
        markerId: id,
        position: widget.state.driverLocation!,
        icon: driverIcon,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        rotation: widget.state.driverHeading ?? 0,
        zIndexInt: 5,
      );
    }

    if (!mounted) return;
    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
      _markersLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final target = state.driverLocation ??
        state.currentStop?.location ??
        const LatLng(0, 0);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: target, zoom: 14),
      onMapCreated: (controller) {
        ref.read(navigationProvider.notifier).onMapCreated(controller);
        controller.setMapStyle(_navigationMapStyle);
      },
      markers: _markersLoaded ? Set<Marker>.of(_markers.values) : const {},
      polylines: _buildPolyline(state),
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      trafficEnabled: false,
      padding: EdgeInsets.only(
        top: 130,
        bottom: MediaQuery.of(context).size.height * 0.28,
      ),
    );
  }

  Set<Polyline> _buildPolyline(NavigationState state) {
    if (state.polylinePoints.isEmpty) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: state.polylinePoints,
        color: AppColors.mapRouteBlue,
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }
}

// ─────────────────────────────────────────────────────────────
//  Top Header
// ─────────────────────────────────────────────────────────────

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.currentStop});
  final NavigationStop? currentStop;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20),
                      color: AppColors.primary,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Expanded(
                      child:
                      AppText(
                        'Navigate',
                        textAlign: TextAlign.center,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      )
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              if (currentStop != null)
                Container(
                  width: double.infinity,
                  color: AppColors.teal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color:  Colors.white.withAlpha(64),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.turn_right_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentStop!.address,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              currentStop!.patientName,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
//  Status Overlay — handles loading / permission / GPS / error
// ─────────────────────────────────────────────────────────────

class _StatusOverlay extends ConsumerWidget {
  const _StatusOverlay({required this.state});
  final NavigationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(navigationProvider.notifier);
    final theme = _statusContent(state.status, state.errorMessage);

    return Container(
      color:  AppColors.mapOverlayBg,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.status.isLoading) ...[
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.teal),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
            ] else ...[
              Icon(theme.icon, size: 56, color: AppColors.teal),
              const SizedBox(height: 16),
            ],
            AppText(
              theme.title,
              textAlign: TextAlign.center,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            const SizedBox(height: 8),
            AppText(
              theme.message,
              textAlign: TextAlign.center,
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            if (theme.primaryLabel != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    switch (state.status) {
                      case NavigationStatus.locationServiceDisabled:
                        notifier.openLocationSettingsAndRetry();
                        break;
                      case NavigationStatus.locationPermissionPermanentlyDenied:
                        notifier.openAppSettingsAndRetry();
                        break;
                      default:
                        notifier.retry();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child:AppText(
                    theme.primaryLabel!,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _StatusTheme _statusContent(NavigationStatus status, String? errorMessage) {
    switch (status) {
      case NavigationStatus.initial:
      case NavigationStatus.checkingLocation:
        return _StatusTheme(
          icon: Icons.my_location_rounded,
          title: 'Getting your location…',
          message: 'Please wait while we locate you.',
        );
      case NavigationStatus.fetchingRoute:
        return _StatusTheme(
          icon: Icons.alt_route_rounded,
          title: 'Calculating route…',
          message: 'Finding the best path to your customer.',
        );
      case NavigationStatus.locationServiceDisabled:
        return _StatusTheme(
          icon: Icons.location_off_rounded,
          title: 'Turn on location',
          message: errorMessage ??
              'Please enable GPS / Location services to start delivery.',
          primaryLabel: 'Open Location Settings',
        );
      case NavigationStatus.locationPermissionDenied:
        return _StatusTheme(
          icon: Icons.lock_outline_rounded,
          title: 'Permission needed',
          message: errorMessage ??
              'Allow location access so we can guide you to customers.',
          primaryLabel: 'Grant Permission',
        );
      case NavigationStatus.locationPermissionPermanentlyDenied:
        return _StatusTheme(
          icon: Icons.lock_outline_rounded,
          title: 'Permission blocked',
          message: errorMessage ??
              'Location permission is blocked. Enable it from the system settings.',
          primaryLabel: 'Open App Settings',
        );
      case NavigationStatus.error:
        return _StatusTheme(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          message: errorMessage ?? 'Please try again.',
          primaryLabel: 'Retry',
        );
      default:
        return _StatusTheme(
          icon: Icons.info_outline_rounded,
          title: 'Please wait…',
          message: '',
        );
    }
  }
}

class _StatusTheme {
  final IconData icon;
  final String title;
  final String message;
  final String? primaryLabel;
  _StatusTheme({
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
  });
}

// ─────────────────────────────────────────────────────────────
//  Bottom Info Card
// ─────────────────────────────────────────────────────────────

class _BottomInfoCard extends ConsumerWidget {
  const _BottomInfoCard({required this.state});
  final NavigationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isAtStop = state.status == NavigationStatus.reachedStop;
    final isCompleted = state.status == NavigationStatus.tripCompleted;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag pill
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),

          // Reached-stop banner
          if (isAtStop) ...[
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:  AppColors.successBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: const [
                  Icon(Icons.location_on_rounded,
                      color: AppColors.successDark, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: AppText(
                      'You\'ve arrived at the delivery location',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.successDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Completed banner
          if (isCompleted) ...[
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4EA),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: const [
                  Icon(Icons.celebration_rounded,
                      color: AppColors.successDark, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: AppText(
                      'All deliveries completed. Great work!',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.successDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ETA info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: AppText(
                        isCompleted
                            ? 'Done'
                            : '${state.estimatedMinutes} min',
                        key: ValueKey(
                          '${state.estimatedMinutes}-${state.status}',
                        ),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: AppText(
                            '${state.distanceKm.toStringAsFixed(1)} km',
                            key: ValueKey(state.distanceKm.toStringAsFixed(1)),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('•',
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.textHint)),
                        ),
                        AppText(
                          '${state.etaTime} ETA',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Primary action: Mark Delivered (when at stop) OR End Trip
              if (isAtStop)
                _PrimaryActionButton(
                  label: state.hasNextStop
                      ? 'Mark Delivered & Next'
                      : 'Mark Delivered',
                  color: AppColors.teal,
                  icon: Icons.check_circle_rounded,
                  onPressed: () => ref
                      .read(navigationProvider.notifier)
                      .markCurrentStopDelivered(),
                )
              else if (isCompleted)
                _PrimaryActionButton(
                  label: 'Finish',
                  color: AppColors.teal,
                  icon: Icons.flag_rounded,
                  onPressed: () =>
                      ref.read(navigationProvider.notifier).endTrip(),
                )
              else
                _PrimaryActionButton(
                  label: 'End Trip',
                  color: const Color(0xFFD32F2F),
                  icon: Icons.close_rounded,
                  onPressed: () async {
                    final confirmed = await _showEndTripDialog(context);
                    if (confirmed == true) {
                      ref.read(navigationProvider.notifier).endTrip();
                    }
                  },
                ),
            ],
          ),

          const SizedBox(height: 16),
          _StopProgressRow(state: state),
        ],
      ),
    );
  }

  Future<bool?> _showEndTripDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: AppText(
        'End Trip?',
        fontWeight: FontWeight.w700,
      ),

        content: AppText(
          'Are you sure you want to end the current trip? Any undelivered stops will remain pending.',
          fontSize: 14,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(
                    fontFamily: 'Poppins', color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              elevation: 0,
            ),
            child: AppText(
            'End Trip',
    fontWeight: FontWeight.w600,
    color: Colors.white,
    ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Primary action button (unified)
// ─────────────────────────────────────────────────────────────

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Stop Progress Row
// ─────────────────────────────────────────────────────────────

class _StopProgressRow extends StatelessWidget {
  const _StopProgressRow({required this.state});
  final NavigationState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < state.stops.length; i++) ...[
          _StopDot(
            stop: state.stops[i],
            isCurrent: state.stops[i].status == StopStatus.current,
            isPast: state.stops[i].status == StopStatus.delivered,
          ),
          if (i < state.stops.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: state.stops[i].status == StopStatus.delivered
                    ? AppColors.teal
                    : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}

class _StopDot extends StatelessWidget {
  const _StopDot({
    required this.stop,
    required this.isCurrent,
    required this.isPast,
  });
  final NavigationStop stop;
  final bool isCurrent;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final color = isPast
        ? AppColors.teal
        : isCurrent
        ? AppColors.primary
        : AppColors.border;

    return Tooltip(
      message: stop.patientName,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: isCurrent ? 0.15 : isPast ? 0.12 : 0.06,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: isPast
              ? Icon(Icons.check_rounded, size: 14, color: color)
              : Text(
            '${stop.stopNumber}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Custom map style (kept from previous version)
// ─────────────────────────────────────────────────────────────

const _navigationMapStyle = '''
[
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "stylers": [{"visibility": "simplified"}]},
  {"featureType": "landscape.natural", "elementType": "geometry.fill",
    "stylers": [{"color": "#dde8d8"}]},
  {"featureType": "water", "elementType": "geometry.fill",
    "stylers": [{"color": "#b3d4e8"}]},
  {"featureType": "road.highway", "elementType": "geometry.fill",
    "stylers": [{"color": "#f5e6b2"}]},
  {"featureType": "road.local", "elementType": "geometry.fill",
    "stylers": [{"color": "#ffffff"}]},
  {"featureType": "administrative.neighborhood", "elementType": "labels.text.fill",
    "stylers": [{"color": "#777777"}]}
]
''';