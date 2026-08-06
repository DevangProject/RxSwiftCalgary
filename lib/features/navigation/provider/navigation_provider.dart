import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../model/navigation/navigation_model.dart';
import '../../../service/background_location_service.dart';
import '../../../service/directions_service.dart';
import '../../../service/location_service.dart';
import '../../today_route/route_map/provider/location_sync_provider.dart';
import '../../today_route/route_map/repository/location_sync_repository.dart';

// ─────────────────────────────────────────────────────────────
//  Service providers (overridable in tests)
// ─────────────────────────────────────────────────────────────

final locationServiceProvider =
Provider<LocationService>((ref) => LocationService());

final directionsServiceProvider = Provider<DirectionsService>((ref) {
  final service = DirectionsService();
  ref.onDispose(service.dispose);
  return service;
});

// ─────────────────────────────────────────────────────────────
//  Demo data — replace with real stops from your trip API.
//  These are kept ONLY as seed data; nothing about the navigation
//  flow itself is mock anymore.
// ─────────────────────────────────────────────────────────────

const _demoStops = <NavigationStop>[
  NavigationStop(
    id: '1',
    stopNumber: 1,
    patientName: 'John Smith',
    address: 'Satellite Road, Ahmedabad',
    scheduledTime: '12:30 PM',
    location: LatLng(23.0225, 72.5714),
  ),
  NavigationStop(
    id: '2',
    stopNumber: 2,
    patientName: 'Sarah Johnson',
    address: 'SG Highway, Ahmedabad',
    scheduledTime: '01:15 PM',
    location: LatLng(23.0588, 72.5247),
  ),
  NavigationStop(
    id: '3',
    stopNumber: 3,
    patientName: 'Robert Brown',
    address: 'Maninagar, Ahmedabad',
    scheduledTime: '02:00 PM',
    location: LatLng(22.9951, 72.6040),
  ),
  NavigationStop(
    id: '4',
    stopNumber: 4,
    patientName: 'Linda Wilson',
    address: 'Bopal, Ahmedabad',
    scheduledTime: '02:45 PM',
    location: LatLng(23.0300, 72.4630),
  ),
];

// ─────────────────────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────────────────────

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier(
      this._locationService,
      this._directionsService,
      this._backgroundLocationService,
      this._locationSyncRepository,
      {List<NavigationStop>? initialStops})
      : super(NavigationState(
    stops: (initialStops ?? _demoStops)
        .asMap()
        .entries
        .map((e) => e.value.copyWith(
      status:
      e.key == 0 ? StopStatus.current : StopStatus.pending,
    ))
        .toList(),
  )) {
    start();
  }

  final LocationService _locationService;
  final DirectionsService _directionsService;
  final BackgroundLocationService _backgroundLocationService;
  final LocationSyncRepository _locationSyncRepository;

  StreamSubscription<Position>? _positionSub;
  Timer? _iosBackgroundSyncTimer;
  DateTime _lastRouteRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  static const _iosBackgroundSyncInterval = Duration(minutes: 1);


  static const _refreshDistanceMeters = 150.0;
  static const _refreshCooldown = Duration(seconds: 20);

  /// Distance (m) within which the driver is considered "arrived" at a stop.
  static const _arrivalThresholdMeters = 40.0;

  // ── Public API ──────────────────────────────────────────────

  /// Kicks off the entire flow. Safe to call again after an error to retry.
  Future<void> start() async {
    state = state.copyWith(
      status: NavigationStatus.checkingLocation,
      clearError: true,
    );

    final check = await _locationService.ensureLocationAvailable();
    switch (check) {
      case LocationCheckResult.serviceDisabled:
        state = state.copyWith(
          status: NavigationStatus.locationServiceDisabled,
          errorMessage:
          'Location services are turned off. Please enable GPS to start delivery.',
        );
        return;
      case LocationCheckResult.permissionDenied:
        state = state.copyWith(
          status: NavigationStatus.locationPermissionDenied,
          errorMessage:
          'Location permission is required to navigate to your deliveries.',
        );
        return;
      case LocationCheckResult.permissionPermanentlyDenied:
        state = state.copyWith(
          status: NavigationStatus.locationPermissionPermanentlyDenied,
          errorMessage:
          'Location permission has been permanently denied. Please enable it from app settings.',
        );
        return;
      case LocationCheckResult.ready:
        break;
    }

    // Fetch initial location
    final LatLng currentLocation;
    try {
      currentLocation = await _locationService.getCurrentLocation();
    } catch (e) {
      state = state.copyWith(
        status: NavigationStatus.error,
        errorMessage: 'Could not get your current location. Please try again.',
      );
      return;
    }

    state = state.copyWith(driverLocation: currentLocation);

    // Calculate route to current stop
    await _fetchRouteToCurrentStop(from: currentLocation);

    // Begin live tracking (only if route fetch succeeded)
    if (state.status == NavigationStatus.navigating) {
      _startLiveLocationTracking();
    }
  }

  /// Called from the screen once the GoogleMap controller exists.
  void onMapCreated(GoogleMapController controller) {
    state = state.copyWith(mapController: controller);
  }

  /// Driver marks the current stop as delivered and moves to the next one.
  Future<void> markCurrentStopDelivered() async {
    final updated = [...state.stops];
    if (state.currentStopIndex >= updated.length) return;

    updated[state.currentStopIndex] =
        updated[state.currentStopIndex].copyWith(status: StopStatus.delivered);

    if (!state.hasNextStop) {
      // All deliveries done
      state = state.copyWith(
        stops: updated,
        status: NavigationStatus.tripCompleted,
        polylinePoints: const [],
        estimatedMinutes: 0,
        distanceKm: 0,
      );
      _positionSub?.cancel();
      _stopBackgroundLocationSync();
      return;
    }

    final nextIndex = state.currentStopIndex + 1;
    updated[nextIndex] = updated[nextIndex].copyWith(status: StopStatus.current);

    state = state.copyWith(
      stops: updated,
      currentStopIndex: nextIndex,
      status: NavigationStatus.fetchingRoute,
    );

    if (state.driverLocation != null) {
      await _fetchRouteToCurrentStop(from: state.driverLocation!);
    }
  }

  /// User explicitly ended the trip.
  Future<void> endTrip() async {
    _positionSub?.cancel();
    _stopBackgroundLocationSync();
    state = state.copyWith(status: NavigationStatus.ended);
  }

  /// Manual retry after an error / permission denial.
  Future<void> retry() => start();

  /// Re-check after the user has been sent to settings.
  Future<void> openLocationSettingsAndRetry() async {
    await _locationService.openLocationSettings();
    // Give the OS a moment, then retry.
    await Future.delayed(const Duration(milliseconds: 500));
    await start();
  }

  Future<void> openAppSettingsAndRetry() async {
    await _locationService.openAppSettings();
    await Future.delayed(const Duration(milliseconds: 500));
    await start();
  }

  // ── Internal ────────────────────────────────────────────────

  Future<void> _fetchRouteToCurrentStop({required LatLng from}) async {
    final destination = state.currentStop?.location;
    if (destination == null) return;

    state = state.copyWith(status: NavigationStatus.fetchingRoute);

    try {
      final route = await _directionsService.getRoute(
        origin: from,
        destination: destination,
      );

      _lastRouteRefresh = DateTime.now();

      state = state.copyWith(
        status: NavigationStatus.navigating,
        polylinePoints: route.polylinePoints,
        distanceKm: route.distanceKm,
        estimatedMinutes: route.durationMinutes,
        etaTime: _formatEtaTime(route.durationMinutes),
        clearError: true,
      );

      // Frame the camera to show the whole route.
      _animateCameraToRoute(route.polylinePoints);
    } on DirectionsException catch (e) {
      state = state.copyWith(
        status: NavigationStatus.error,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: NavigationStatus.error,
        errorMessage:
        'Could not fetch the delivery route. Check your connection and try again.',
      );
    }
  }

  void _startLiveLocationTracking() {
    _positionSub?.cancel();
    _positionSub = _locationService.liveLocationStream().listen(
      _onPositionUpdate,
      onError: (_) {
        // Don't blow up the screen on transient GPS errors.
      },
    );
    _startBackgroundLocationSync();
  }

  /// Keeps the backend updated with the driver's position for the rest of
  /// the navigation session, including while the app is backgrounded.
  /// Android: a persistent foreground-service isolate (survives the main
  /// isolate being suspended). iOS: a periodic timer is enough because
  /// LocationService's AppleSettings already keep the main isolate alive
  /// in the background.
  void _startBackgroundLocationSync() {
    if (Platform.isAndroid) {
      _backgroundLocationService.start();
    } else if (Platform.isIOS) {
      _iosBackgroundSyncTimer?.cancel();
      _iosBackgroundSyncTimer = Timer.periodic(
        _iosBackgroundSyncInterval,
        (_) {
          final loc = state.driverLocation;
          print('[BackgroundLocation] ${DateTime.now()} lat: ${loc?.latitude}, lng: ${loc?.longitude}');
          _locationSyncRepository.syncOnce();
        },
      );
    }
  }

  void _stopBackgroundLocationSync() {
    _iosBackgroundSyncTimer?.cancel();
    _iosBackgroundSyncTimer = null;
    _backgroundLocationService.stop();
  }

  void _onPositionUpdate(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);
    state = state.copyWith(
      driverLocation: newLocation,
      driverHeading: position.heading,
    );

    final currentStop = state.currentStop;
    if (currentStop == null) return;

    // 1) Arrived?
    final distanceToStop =
    _locationService.distanceBetweenMeters(newLocation, currentStop.location);
    if (distanceToStop <= _arrivalThresholdMeters &&
        state.status != NavigationStatus.reachedStop) {
      state = state.copyWith(status: NavigationStatus.reachedStop);
      return;
    }

    // 2) Need a fresh route? Only if we've drifted notably and cooled down.
    final drift = state.polylinePoints.isNotEmpty
        ? _locationService.distanceBetweenMeters(
        newLocation, state.polylinePoints.first)
        : double.infinity;
    final cooledDown =
        DateTime.now().difference(_lastRouteRefresh) > _refreshCooldown;
    if (drift > _refreshDistanceMeters && cooledDown) {
      _fetchRouteToCurrentStop(from: newLocation);
      return;
    }

    // 3) Otherwise just nudge the camera to follow the driver.
    _animateCameraToDriver(newLocation, position.heading);

    // 4) Cheaply decrement displayed distance/ETA based on how far we've moved
    //    along the polyline (approximation — full refresh happens on drift).
    if (state.polylinePoints.isNotEmpty) {
      final remainingKm = _approxRemainingKm(newLocation);
      if (remainingKm < state.distanceKm) {
        state = state.copyWith(distanceKm: remainingKm);
      }
    }
  }

  double _approxRemainingKm(LatLng from) {
    double total = 0;
    var prev = from;
    for (final p in state.polylinePoints) {
      total += _locationService.distanceBetweenMeters(prev, p);
      prev = p;
    }
    return total / 1000.0;
  }

  String _formatEtaTime(int durationMinutes) {
    final arrival = DateTime.now().add(Duration(minutes: durationMinutes));
    final hour12 = arrival.hour == 0
        ? 12
        : (arrival.hour > 12 ? arrival.hour - 12 : arrival.hour);
    final period = arrival.hour >= 12 ? 'PM' : 'AM';
    final mm = arrival.minute.toString().padLeft(2, '0');
    return '${hour12.toString().padLeft(2, '0')}:$mm $period';
  }

  void _animateCameraToRoute(List<LatLng> points) {
    final controller = state.mapController;
    if (controller == null || points.isEmpty) return;
    final bounds = _boundsFromLatLngList(points);
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _animateCameraToDriver(LatLng driver, double heading) {
    final controller = state.mapController;
    if (controller == null) return;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: driver,
          zoom: 16,
          bearing: heading.isNaN ? 0 : heading,
          tilt: 35,
        ),
      ),
    );
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double minLat = list.first.latitude;
    double maxLat = list.first.latitude;
    double minLng = list.first.longitude;
    double maxLng = list.first.longitude;
    for (final p in list) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stopBackgroundLocationSync();
    state.mapController?.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

final navigationProvider =
StateNotifierProvider.autoDispose<NavigationNotifier, NavigationState>(
      (ref) => NavigationNotifier(
    ref.read(locationServiceProvider),
    ref.read(directionsServiceProvider),
    ref.read(backgroundLocationServiceProvider),
    ref.read(locationSyncRepositoryProvider),
  ),
);