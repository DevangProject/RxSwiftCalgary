import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../model/navigation/navigation_model.dart';



/// Thrown when the Directions API call fails or returns an error status.
class DirectionsException implements Exception {
  final String message;
  DirectionsException(this.message);
  @override
  String toString() => 'DirectionsException: $message';
}

/// Encapsulates calls to the Google Directions API and polyline decoding.
///
/// IMPORTANT: in production, never ship the API key in source. Load it from
/// `--dart-define`, secure storage, or a backend proxy. Example:
///   flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...
class DirectionsService {
  DirectionsService({String? apiKey, http.Client? client})
      : _apiKey = apiKey ??
      const String.fromEnvironment('GOOGLE_MAPS_API_KEY',
          defaultValue: ''),
        _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  static const _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  /// Fetch a route between [origin] and [destination]. Throws
  /// [DirectionsException] on any failure so the provider can surface a
  /// clean error to the UI.
  Future<RouteInfo> getRoute({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
  }) async {
    if (_apiKey.isEmpty) {
      throw DirectionsException(
        'Google Maps API key is missing. Pass it via --dart-define=GOOGLE_MAPS_API_KEY=...',
      );
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': mode,
      'key': _apiKey,
    });

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw DirectionsException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw DirectionsException(
          'HTTP ${response.statusCode} from Directions API.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String? ?? 'UNKNOWN';
    if (status != 'OK') {
      final msg = body['error_message'] as String? ?? status;
      throw DirectionsException('Directions API returned $status: $msg');
    }

    final routes = body['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw DirectionsException('No route found.');
    }
    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List?;
    if (legs == null || legs.isEmpty) {
      throw DirectionsException('Route contains no legs.');
    }
    final leg = legs.first as Map<String, dynamic>;

    final distanceMeters =
        (leg['distance']?['value'] as num?)?.toDouble() ?? 0.0;
    final durationSeconds =
        (leg['duration']?['value'] as num?)?.toInt() ?? 0;

    final encodedPolyline =
        route['overview_polyline']?['points'] as String? ?? '';
    final points = decodePolyline(encodedPolyline);

    return RouteInfo(
      polylinePoints: points,
      distanceKm: distanceMeters / 1000.0,
      durationMinutes: (durationSeconds / 60).ceil(),
    );
  }

  /// Pure-Dart polyline decoder (Google's encoded polyline algorithm).
  /// Kept inline to avoid an extra dependency; equivalent to
  /// `flutter_polyline_points`.
  static List<LatLng> decodePolyline(String encoded) {
    final result = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;
    final len = encoded.length;

    while (index < len) {
      int shift = 0;
      int b;
      int resultBits = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        resultBits |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (resultBits & 1) != 0 ? ~(resultBits >> 1) : (resultBits >> 1);
      lat += dlat;

      shift = 0;
      resultBits = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        resultBits |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (resultBits & 1) != 0 ? ~(resultBits >> 1) : (resultBits >> 1);
      lng += dlng;

      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }

  void dispose() => _client.close();
}