// ============================================================================
// lib/features/today_route/provider/route_location_service.dart
//
// Thin wrapper around Geolocator's static API so TodayRouteNotifier depends
// on an injectable interface (swappable in tests) rather than calling the
// platform plugin directly. Foreground, one-shot fixes only — no background
// tracking here (that's handled separately by route_map's location sync).
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class RouteLocationService {
  const RouteLocationService();

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  /// One-shot high-accuracy fix, capped so the caller never hangs forever
  /// waiting on a GPS lock with no signal.
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

final routeLocationServiceProvider = Provider<RouteLocationService>(
  (ref) => const RouteLocationService(),
);
