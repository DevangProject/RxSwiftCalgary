// ============================================================================
// lib/features/today_route/route_map/provider/live_route_provider.dart
//
// Fetches the real road route from driver's CURRENT location to the next
// unfinished stop. Re-fetched automatically whenever the driver moves
// (throttled — only calls API when driver moves ≥ 30 m from last fetch point
// to avoid hammering the Directions API on every GPS tick).
// ============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:rxswift/features/navigation/provider/navigation_provider.dart'
    show directionsServiceProvider;
import 'package:rxswift/service/directions_service.dart';

// ── Model ─────────────────────────────────────────────────────────────────

class LiveRoute {
  const LiveRoute({required this.points});
  final List<LatLng> points; // real road points from Directions API
  static const empty = LiveRoute(points: []);
}

// ── Notifier ──────────────────────────────────────────────────────────────
// Holds the latest road-route polyline from driver → next stop.
// Call updateTarget(driverPos, destination) whenever either changes.

class LiveRouteNotifier extends StateNotifier<LiveRoute> {
  LiveRouteNotifier(this._directions) : super(LiveRoute.empty);

  final dynamic _directions; // DirectionsService

  LatLng? _lastFetchedFrom; // driver position at last successful API call
  LatLng? _currentDestination;
  bool _fetching = false;
  bool _disposed = false;

  // Minimum metres driver must move before we re-fetch the route.
  static const _refetchThresholdMeters = 30.0;

  /// Call this on every GPS update from driverLocationProvider.
  /// [from]   = driver's current LatLng
  /// [to]     = next unfinished stop's LatLng
  void updateTarget(LatLng from, LatLng to) {
    final destinationChanged = _currentDestination == null ||
        _currentDestination!.latitude != to.latitude ||
        _currentDestination!.longitude != to.longitude;

    final movedFarEnough = _lastFetchedFrom == null ||
        Geolocator.distanceBetween(
          _lastFetchedFrom!.latitude,
          _lastFetchedFrom!.longitude,
          from.latitude,
          from.longitude,
        ) >=
            _refetchThresholdMeters;

    if (!destinationChanged && !movedFarEnough) return; // skip — not worth re-fetching

    _currentDestination = to;
    _fetchRoute(from, to);
  }

  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    if (_fetching || _disposed) return;
    _fetching = true;

    try {
      final result = await _directions.getRoute(
        origin: from,
        destination: to,
      );
      if (_disposed) return;
      _lastFetchedFrom = from;
      state = LiveRoute(points: result.polylinePoints);
    } on DirectionsException {
      // Silently ignore — keep showing last known route
    } catch (_) {
      // Silently ignore
    } finally {
      _fetching = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────

final liveRouteProvider =
StateNotifierProvider.autoDispose<LiveRouteNotifier, LiveRoute>(
      (ref) => LiveRouteNotifier(ref.read(directionsServiceProvider)),
);