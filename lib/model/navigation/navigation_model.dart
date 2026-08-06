import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  Navigation lifecycle states
// ─────────────────────────────────────────────────────────────

enum NavigationStatus {
  initial,
  checkingLocation,
  locationPermissionDenied,
  locationPermissionPermanentlyDenied,
  locationServiceDisabled,
  fetchingRoute,
  navigating,
  reachedStop,
  tripCompleted,
  ended,
  error,
}

extension NavigationStatusX on NavigationStatus {
  bool get isBlocking =>
      this == NavigationStatus.initial ||
          this == NavigationStatus.checkingLocation ||
          this == NavigationStatus.locationPermissionDenied ||
          this == NavigationStatus.locationPermissionPermanentlyDenied ||
          this == NavigationStatus.locationServiceDisabled ||
          this == NavigationStatus.fetchingRoute ||
          this == NavigationStatus.error;

  bool get isLoading =>
      this == NavigationStatus.initial ||
          this == NavigationStatus.checkingLocation ||
          this == NavigationStatus.fetchingRoute;

  bool get isReadyForMap =>
      this == NavigationStatus.navigating ||
          this == NavigationStatus.reachedStop ||
          this == NavigationStatus.tripCompleted;
}

// ─────────────────────────────────────────────────────────────
//  Delivery stop
// ─────────────────────────────────────────────────────────────

enum StopStatus { pending, current, delivered, skipped }

@immutable
class NavigationStop {
  final String id;
  final int stopNumber;
  final String patientName;
  final String address;
  final String scheduledTime;
  final LatLng location;
  final StopStatus status;

  const NavigationStop({
    required this.id,
    required this.stopNumber,
    required this.patientName,
    required this.address,
    required this.scheduledTime,
    required this.location,
    this.status = StopStatus.pending,
  });

  NavigationStop copyWith({StopStatus? status}) => NavigationStop(
    id: id,
    stopNumber: stopNumber,
    patientName: patientName,
    address: address,
    scheduledTime: scheduledTime,
    location: location,
    status: status ?? this.status,
  );
}

// ─────────────────────────────────────────────────────────────
//  Route information returned by DirectionsService
// ─────────────────────────────────────────────────────────────

@immutable
class RouteInfo {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final int durationMinutes;

  const RouteInfo({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

// ─────────────────────────────────────────────────────────────
//  Main navigation state
// ─────────────────────────────────────────────────────────────

@immutable
class NavigationState {
  final NavigationStatus status;
  final List<NavigationStop> stops;
  final int currentStopIndex;
  final LatLng? driverLocation;
  final double? driverHeading;
  final List<LatLng> polylinePoints;
  final int estimatedMinutes;
  final double distanceKm;
  final String etaTime;
  final String? errorMessage;
  final GoogleMapController? mapController;

  const NavigationState({
    this.status = NavigationStatus.initial,
    this.stops = const [],
    this.currentStopIndex = 0,
    this.driverLocation,
    this.driverHeading,
    this.polylinePoints = const [],
    this.estimatedMinutes = 0,
    this.distanceKm = 0.0,
    this.etaTime = '--:--',
    this.errorMessage,
    this.mapController,
  });

  NavigationStop? get currentStop {
    if (stops.isEmpty || currentStopIndex >= stops.length) return null;
    return stops[currentStopIndex];
  }

  bool get hasNextStop => currentStopIndex < stops.length - 1;

  int get completedStopsCount =>
      stops.where((s) => s.status == StopStatus.delivered).length;

  bool get isLoadingMap => status.isLoading;

  bool get isEnded =>
      status == NavigationStatus.ended ||
          status == NavigationStatus.tripCompleted;

  NavigationState copyWith({
    NavigationStatus? status,
    List<NavigationStop>? stops,
    int? currentStopIndex,
    LatLng? driverLocation,
    double? driverHeading,
    List<LatLng>? polylinePoints,
    int? estimatedMinutes,
    double? distanceKm,
    String? etaTime,
    String? errorMessage,
    bool clearError = false,
    GoogleMapController? mapController,
  }) {
    return NavigationState(
      status: status ?? this.status,
      stops: stops ?? this.stops,
      currentStopIndex: currentStopIndex ?? this.currentStopIndex,
      driverLocation: driverLocation ?? this.driverLocation,
      driverHeading: driverHeading ?? this.driverHeading,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
      etaTime: etaTime ?? this.etaTime,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      mapController: mapController ?? this.mapController,
    );
  }
}