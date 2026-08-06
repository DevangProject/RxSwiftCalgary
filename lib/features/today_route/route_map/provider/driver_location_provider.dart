// ============================================================================
// lib/features/today_route/route_map/provider/driver_location_provider.dart
// ============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── Model ─────────────────────────────────────────────────────────────────

class DriverPosition {
  const DriverPosition({
    required this.latLng,
    required this.bearing,
    required this.speedKph,
    required this.raw,
  });

  final LatLng latLng;
  final double bearing;
  final double speedKph;
  final Position raw;
}

// ── Bearing helper ────────────────────────────────────────────────────────

double calculateBearing(LatLng from, LatLng to) {
  final lat1 = _toRad(from.latitude);
  final lat2 = _toRad(to.latitude);
  final dLng  = _toRad(to.longitude - from.longitude);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (_toDeg(math.atan2(y, x)) + 360) % 360;
}

double _toRad(double deg) => deg * math.pi / 180;
double _toDeg(double rad) => rad * 180 / math.pi;

// ── Notifier ──────────────────────────────────────────────────────────────

class DriverLocationNotifier
    extends StateNotifier<AsyncValue<DriverPosition>> {
  DriverLocationNotifier() : super(const AsyncValue.loading()) {
    _start();
  }

  StreamSubscription<Position>? _sub;
  Position? _lastPosition;
  bool _disposed = false;

  void _start() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (Object e, StackTrace st) {
        if (_disposed) return;
        state = AsyncValue.error(e, st);
      },
      cancelOnError: false,
    );
  }

  void _onPosition(Position pos) {
    // Guard against already-queued microtasks arriving after dispose.
    if (_disposed) return;

    final current = LatLng(pos.latitude, pos.longitude);

    double bearing;
    if (pos.heading >= 0 && pos.heading <= 360) {
      bearing = pos.heading;
    } else if (_lastPosition != null) {
      bearing = calculateBearing(
        LatLng(_lastPosition!.latitude, _lastPosition!.longitude),
        current,
      );
    } else {
      bearing = 0.0;
    }

    _lastPosition = pos;

    state = AsyncValue.data(
      DriverPosition(
        latLng: current,
        bearing: bearing,
        speedKph: (pos.speed < 0 ? 0.0 : pos.speed) * 3.6,
        raw: pos,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;   // set FIRST — blocks any microtask still in flight
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────

final driverLocationProvider =
StateNotifierProvider.autoDispose<DriverLocationNotifier,
    AsyncValue<DriverPosition>>(
      (ref) => DriverLocationNotifier(),
);