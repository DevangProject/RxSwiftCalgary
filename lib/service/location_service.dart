import 'dart:async';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Result of a permission/availability check.
enum LocationCheckResult {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
}

class LocationService {
  /// Performs both the service-enabled check and the permission check.
  Future<LocationCheckResult> ensureLocationAvailable() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationCheckResult.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationCheckResult.permissionDenied;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationCheckResult.permissionPermanentlyDenied;
    }
    return LocationCheckResult.ready;
  }

  Future<LatLng> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
    return LatLng(position.latitude, position.longitude);
  }

  /// On iOS, background updates are enabled directly here: given "Always"
  /// permission and the `UIBackgroundModes: location` Info.plist entry, this
  /// keeps CoreLocation delivering updates (and keeps the app process alive)
  /// while backgrounded — no extra plugin needed.
  ///
  /// Android has no equivalent single-isolate trick (backgrounding the
  /// activity suspends the Dart isolate regardless of stream settings), so
  /// background continuity there is handled separately by
  /// [BackgroundLocationService], not by this stream.
  Stream<Position> liveLocationStream({int distanceFilterMeters = 10}) {
    final LocationSettings settings = Platform.isIOS
        ? AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: distanceFilterMeters,
            allowBackgroundLocationUpdates: true,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
          )
        : LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: distanceFilterMeters,
          );
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  double distanceBetweenMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  /// Open device location settings (used when service is disabled).
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Open the app's settings page (used when permission is permanently denied).
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}