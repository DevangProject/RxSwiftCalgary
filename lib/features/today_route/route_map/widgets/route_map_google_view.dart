// ============================================================================
// features/today_route/route_map/widgets/route_map_google_view.dart
//
// Responsibilities:
//   • Draw all stop markers (numbered pins, unchanged)
//   • Draw driver marker (animated, smooth movement with bearing)
//   • Draw live road route from liveRouteProvider (managed by screen)
//   • Camera follows driver with heading
//
// Does NOT manage: GPS stream, API sync timer, route fetching.
// All of that is owned by route_map_screen.dart.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../route_map/theme/route_map_theme.dart';
import '../../../route_map/widgets/route_map_atoms.dart';
import '../../model/route_model.dart';
import '../../numbered_marker_factory.dart';
import '../provider/all_points_route_provider.dart';
import '../provider/driver_location_provider.dart';
import '../provider/live_route_provider.dart';
import 'driver_marker_factory.dart';

class RouteMapGoogleView extends ConsumerStatefulWidget {
  const RouteMapGoogleView({
    super.key,
    required this.route,
    required this.selectedIndex,
    required this.onMarkerTap,
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final TodayRoute route;
  final int selectedIndex;
  final ValueChanged<int> onMarkerTap;
  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  ConsumerState<RouteMapGoogleView> createState() =>
      _RouteMapGoogleViewState();
}

class _RouteMapGoogleViewState extends ConsumerState<RouteMapGoogleView>
    with TickerProviderStateMixin {
  GoogleMapController? _controller;

  // ── Stop markers ──────────────────────────────────────────────────────────
  final Map<MarkerId, Marker> _markers = {};
  bool _markersLoaded = false;

  // ── Driver marker ─────────────────────────────────────────────────────────
  static const _driverMarkerId = MarkerId('driver_current_location');
  Marker? _driverMarker;
  BitmapDescriptor? _driverIcon;

  // ── Smooth animation ──────────────────────────────────────────────────────
  AnimationController? _animController;
  static const _animDuration = Duration(milliseconds: 800);

  double _animFromLat = 0, _animFromLng = 0, _animFromBearing = 0;
  double _animToLat   = 0, _animToLng   = 0, _animToBearing   = 0;
  double _curLat = 0, _curLng = 0, _curBearing = 0;
  bool _hasFirstFix = false;

  // ── Camera ────────────────────────────────────────────────────────────────
  bool _followDriver = true;
  bool _programmingCamera = false;
  double _currentZoom = 16.0;

  @override
  void initState() {
    super.initState();
    _rebuildMarkers();
    _loadDriverIcon();
    _animController =
    AnimationController(vsync: this, duration: _animDuration)
      ..addListener(_onAnimTick);
  }

  @override
  void didUpdateWidget(covariant RouteMapGoogleView old) {
    super.didUpdateWidget(old);
    if (old.route != widget.route ||
        old.selectedIndex != widget.selectedIndex) {
      _rebuildMarkers();
    }
  }

  @override
  void dispose() {
    _animController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // ── Driver icon ───────────────────────────────────────────────────────────

  Future<void> _loadDriverIcon() async {
    final icon = await DriverMarkerFactory.instance.icon;
    if (!mounted) return;
    setState(() => _driverIcon = icon);
  }

  // ── Stop markers (unchanged from original) ────────────────────────────────

  Future<void> _rebuildMarkers() async {
    final factory = NumberedMarkerFactory.instance;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final stops = widget.route.stops;
    final markers = <MarkerId, Marker>{};

    for (int i = 0; i < stops.length; i++) {
      final s = stops[i];
      if (!s.hasCoordinates) continue;

      final icon = await factory.stopPin(
        s,
        devicePixelRatio: dpr,
        selected: i == widget.selectedIndex,
      );

      final active = s.status == StopStatus.inProgress;
      final id = MarkerId('stop_${s.id}');
      markers[id] = Marker(
        markerId: id,
        position: LatLng(s.latitude, s.longitude),
        icon: icon,
        anchor: const Offset(0.5, 1.0),
        zIndex: active ? 3 : i == widget.selectedIndex ? 2 : 1,
        infoWindow: InfoWindow(
          title: '${s.stopNumber}. ${s.patientName}',
          snippet: '${s.stopType.label} · ${s.pharmacyName}',
        ),
        onTap: () => widget.onMarkerTap(i),
      );
    }

    final r = widget.route;
    if (r.startLatitude != 0 && r.startLongitude != 0) {
      final startIcon = await factory.startPin(devicePixelRatio: dpr);
      const id = MarkerId('start');
      markers[id] = Marker(
        markerId: id,
        position: LatLng(r.startLatitude, r.startLongitude),
        icon: startIcon,
        anchor: const Offset(0.5, 0.5),
        zIndex: 4,
        infoWindow: const InfoWindow(title: 'Start'),
      );
    }

    if (!mounted) return;
    setState(() {
      _markers..clear()..addAll(markers);
      _markersLoaded = true;
    });
  }

  // ── GPS fix — animate marker + camera ────────────────────────────────────
  // Note: liveRouteProvider.updateTarget is NOT called here.
  // That is the screen's responsibility (route_map_screen.dart).

  void _onNewPosition(DriverPosition pos) {
    if (!mounted) return;

    if (!_hasFirstFix) {
      _hasFirstFix = true;
      _curLat = pos.latLng.latitude;
      _curLng = pos.latLng.longitude;
      _curBearing = pos.bearing;
      _animFromLat = _curLat;
      _animFromLng = _curLng;
      _animFromBearing = _curBearing;
      _animToLat = _curLat;
      _animToLng = _curLng;
      _animToBearing = _curBearing;
      _applyMarker();
      _moveCameraToDriver();
      return;
    }

    _animFromLat     = _curLat;
    _animFromLng     = _curLng;
    _animFromBearing = _curBearing;
    _animToLat       = pos.latLng.latitude;
    _animToLng       = pos.latLng.longitude;
    _animToBearing   = _shortestBearingTarget(_animFromBearing, pos.bearing);

    _animController!
      ..reset()
      ..forward();
  }

  void _onAnimTick() {
    if (!mounted) return;
    final t = _easeInOut(_animController!.value);
    _curLat     = _lerp(_animFromLat,     _animToLat,     t);
    _curLng     = _lerp(_animFromLng,     _animToLng,     t);
    _curBearing = _lerp(_animFromBearing, _animToBearing, t);
    _applyMarker();
    if (_followDriver) _moveCameraToDriver();
  }

  void _applyMarker() {
    final icon = _driverIcon;
    if (icon == null || !mounted) return;
    setState(() {
      _driverMarker = Marker(
        markerId: _driverMarkerId,
        position: LatLng(_curLat, _curLng),
        icon: icon,
        flat: true,
        rotation: _curBearing,
        anchor: const Offset(0.5, 0.5),
        zIndex: 10,
        consumeTapEvents: false,
      );
    });
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  void _moveCameraToDriver() {
    if (_curLat == 0 && _curLng == 0) return;
    _programmingCamera = true;
    _controller
        ?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target:  LatLng(_curLat, _curLng),
      zoom:    _currentZoom,
      bearing: _curBearing,
      tilt:    30.0,
    )))
        .then((_) { if (mounted) _programmingCamera = false; });
  }

  void _moveCamera(CameraUpdate update) {
    _programmingCamera = true;
    _controller?.animateCamera(update)
        .then((_) { if (mounted) _programmingCamera = false; });
  }

  // ── Markers ───────────────────────────────────────────────────────────────

  Set<Marker> get _allMarkers {
    final all = <Marker>{};
    if (_markersLoaded) all.addAll(_markers.values);
    if (_driverMarker != null) all.add(_driverMarker!);
    return all;
  }

  // ── Polyline — live road route from screen-managed liveRouteProvider ──────

  Set<Polyline> _buildPolylines(List<LatLng> livePoints) {
    if (livePoints.length < 2) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('live_route'),
        points: livePoints,
        color: RouteColors.teal,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  // ── Camera fit ────────────────────────────────────────────────────────────

  LatLng _initialTarget() {
    final r = widget.route;
    if (r.startLatitude != 0 && r.startLongitude != 0) {
      return LatLng(r.startLatitude, r.startLongitude);
    }
    final first = r.stops.firstWhere(
          (s) => s.hasCoordinates,
      orElse: () => r.stops.first,
    );
    return LatLng(first.latitude, first.longitude);
  }

  Future<void> _fitToRoute(List<LatLng> pts) async {
    final c = _controller;
    if (c == null || pts.isEmpty) return;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _programmingCamera = true;
    await c.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        64,
      ),
    );
    if (mounted) _programmingCamera = false;
  }

  // ── Math ──────────────────────────────────────────────────────────────────

  double _lerp(double a, double b, double t) => a + (b - a) * t;
  double _easeInOut(double t) =>
      t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
  double _shortestBearingTarget(double from, double to) {
    double diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return from + diff;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // allPointsRouteProvider — initial camera bounds only.
    final allRouteAsync = ref.watch(allPointsRouteProvider(widget.route));

    // liveRouteProvider — real road route driver → next stop (updated by screen).
    final livePoints = ref.watch(liveRouteProvider).points;

    // Fit camera to full route on first load (before driver GPS arrives).
    ref.listen(allPointsRouteProvider(widget.route), (_, next) {
      next.whenData((r) {
        if (!_hasFirstFix) _fitToRoute(r.polylinePoints);
      });
    });

    // Animate driver marker + camera on every GPS fix.
    ref.listen<AsyncValue<DriverPosition>>(driverLocationProvider, (_, next) {
      next.whenData(_onNewPosition);
    });

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition:
            CameraPosition(target: _initialTarget(), zoom: 16),
            onMapCreated: (c) {
              _controller = c;
              final pts = allRouteAsync.valueOrNull?.polylinePoints ?? [];
              if (pts.isNotEmpty && !_hasFirstFix) _fitToRoute(pts);
            },
            onCameraMove: (pos) {
              if (_programmingCamera) return;
              _currentZoom = pos.zoom;
              if (_followDriver) setState(() => _followDriver = false);
            },
            markers: _allMarkers,
            polylines: _buildPolylines(livePoints),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            trafficEnabled: false,
            padding: EdgeInsets.only(
              top: 12,
              bottom: MediaQuery.of(context).size.height * 0.28,
            ),
          ),
        ),

        if (allRouteAsync.isLoading)
          const Positioned(
            top: 16, left: 0, right: 0,
            child: Center(child: _RouteLoadingChip()),
          ),

        const Positioned(top: 12, left: 12, child: MapLegend()),

        // Follow chip.
        if (!_followDriver)
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                setState(() => _followDriver = true);
                _moveCameraToDriver();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: RouteShadows.floating,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.navigation_rounded,
                        size: 14, color: RouteColors.teal),
                    SizedBox(width: 4),
                    Text('Follow',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: RouteColors.teal,
                        )),
                  ],
                ),
              ),
            ),
          ),

        // Zoom controls.
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            children: [
              MapControlButton(
                icon: Icons.add,
                onTap: () {
                  _currentZoom = (_currentZoom + 1).clamp(1.0, 21.0);
                  _moveCamera(CameraUpdate.zoomIn());
                  widget.onZoomIn();
                },
              ),
              const SizedBox(height: 6),
              MapControlButton(
                icon: Icons.remove,
                onTap: () {
                  _currentZoom = (_currentZoom - 1).clamp(1.0, 21.0);
                  _moveCamera(CameraUpdate.zoomOut());
                  widget.onZoomOut();
                },
              ),
            ],
          ),
        ),

        // Recenter.
        Positioned(
          left: 12,
          bottom: 12,
          child: MapControlButton(
            icon: Icons.my_location_rounded,
            iconColor: RouteColors.teal,
            onTap: () {
              if (_hasFirstFix) {
                setState(() => _followDriver = true);
                _moveCameraToDriver();
              } else {
                final pts =
                    allRouteAsync.valueOrNull?.polylinePoints ?? [];
                _fitToRoute(pts);
              }
              widget.onRecenter();
            },
          ),
        ),
      ],
    );
  }
}

// ── Loading chip ──────────────────────────────────────────────────────────

class _RouteLoadingChip extends StatelessWidget {
  const _RouteLoadingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(RouteRadius.full),
        boxShadow: RouteShadows.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: RouteColors.teal),
          ),
          SizedBox(width: 8),
          Text('Building route…',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: RouteColors.textPrimary,
              )),
        ],
      ),
    );
  }
}