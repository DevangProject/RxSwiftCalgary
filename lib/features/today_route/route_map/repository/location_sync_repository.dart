// ============================================================================
// lib/features/today_route/route_map/repository/location_sync_repository.dart
//
// CHANGES from original:
//   • Added syncWithPosition(DriverPosition) — called by the sync timer with
//     the latest position already known from the live stream, avoiding a
//     redundant Geolocator.getCurrentPosition() call.
//   • syncOnce() is kept unchanged for backwards compatibility.
// ============================================================================

import 'package:geolocator/geolocator.dart';

import '../../../../core/network/api_result.dart';
import '../../model/location_sync_model.dart';
import '../data/location_sync_remote_datasource.dart';
import '../provider/driver_location_provider.dart';  // ← DriverPosition

// ── Typed result for the permission check ─────────────────────────────────

enum LocationReadiness {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
}

class LocationSyncRepository {
  LocationSyncRepository(this._remote);
  final LocationSyncRemoteDataSource _remote;

  // ── Permission & service check ────────────────────────────────────────────

  Future<LocationReadiness> checkReadiness() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return LocationReadiness.serviceDisabled;
    final permission = await Geolocator.checkPermission();
    return _permissionToReadiness(permission);
  }

  Future<LocationReadiness> requestPermission() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return LocationReadiness.serviceDisabled;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return _permissionToReadiness(permission);
  }

  LocationReadiness _permissionToReadiness(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationReadiness.ready;
      case LocationPermission.deniedForever:
        return LocationReadiness.permissionPermanentlyDenied;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationReadiness.permissionDenied;
    }
  }

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  // ── Location sync ─────────────────────────────────────────────────────────

  /// Sync using an already-known [DriverPosition] from the live stream.
  /// Preferred over syncOnce() — avoids a redundant GPS read.
  Future<void> syncWithPosition(DriverPosition pos) async {
    print("Api""Location Update");
    try {
      final request = LocationSyncRequest(
        latitude: pos.latLng.latitude,
        longitude: pos.latLng.longitude,
        speedKph: pos.speedKph,
        heading: pos.bearing,
      );
      await _remote.updateLocation(request);
    } catch (_) {
      // Silent failure — next interval will retry.
    }
  }

  /// Fallback: reads GPS independently and pushes to API.
  /// Kept for backward compatibility; used when no stream position is available.
  Future<void> syncOnce() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      final request = LocationSyncRequest(
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedKph: (pos.speed < 0 ? 0.0 : pos.speed) * 3.6,
        heading: pos.heading < 0 ? 0.0 : pos.heading,
      );
      await _remote.updateLocation(request);
    } catch (_) {
      // Silent failure.
    }
  }
}