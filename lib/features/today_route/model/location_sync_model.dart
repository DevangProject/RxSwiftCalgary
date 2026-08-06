// ============================================================================
// lib/features/today_route/route_map/model/location_sync_model.dart
//
// Pure data model for the driver live-location API payload.
// No UI dependencies — safe to use from any layer.
// ============================================================================

class LocationSyncRequest {
  const LocationSyncRequest({
    required this.latitude,
    required this.longitude,
    required this.speedKph,
    required this.heading,
  });

  final double latitude;
  final double longitude;
  final double speedKph;
  final double heading;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'speedKph': speedKph,
    'heading': heading,
  };
}