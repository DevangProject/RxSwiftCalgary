import '../../today_route/model/route_model.dart';


/// ─────────────────────────────────────────────────────────────
///  Projects real lat/lng coordinates onto the stylised map canvas.
///
///  Computes the bounding box of the driver start + all stops, then
///  maps each point into a 0..1 (x, y) space with padding, flipping
///  the Y axis (latitude grows north/up, screen Y grows down).
///
///  This replaces the hardcoded mapX/mapY from the prototype so markers
///  reflect the actual API coordinates. When you swap in a real GoogleMap,
///  delete this and use lat/lng directly.
/// ─────────────────────────────────────────────────────────────
class MapProjection {
  MapProjection._(this._minLat, this._maxLat, this._minLng, this._maxLng);

  final double _minLat, _maxLat, _minLng, _maxLng;

  /// Fraction of the canvas reserved as padding on each edge.
  static const _pad = 0.12;

  factory MapProjection.fromRoute(TodayRoute route) {
    final lats = <double>[route.startLatitude];
    final lngs = <double>[route.startLongitude];
    for (final s in route.stops) {
      if (s.hasCoordinates) {
        lats.add(s.latitude);
        lngs.add(s.longitude);
      }
    }
    // Guard against a degenerate (single-point or empty) box.
    double minLat = lats.reduce((a, b) => a < b ? a : b);
    double maxLat = lats.reduce((a, b) => a > b ? a : b);
    double minLng = lngs.reduce((a, b) => a < b ? a : b);
    double maxLng = lngs.reduce((a, b) => a > b ? a : b);

    if ((maxLat - minLat).abs() < 1e-6) {
      minLat -= 0.01;
      maxLat += 0.01;
    }
    if ((maxLng - minLng).abs() < 1e-6) {
      minLng -= 0.01;
      maxLng += 0.01;
    }
    return MapProjection._(minLat, maxLat, minLng, maxLng);
  }

  double _norm(double v, double min, double max) =>
      ((v - min) / (max - min)).clamp(0.0, 1.0);

  /// Returns normalized (x, y) in 0..1 for a given coordinate.
  ({double x, double y}) project(double lat, double lng) {
    final nx = _norm(lng, _minLng, _maxLng);
    final ny = _norm(lat, _minLat, _maxLat);
    final x = _pad + nx * (1 - 2 * _pad);
    // Flip Y: higher latitude → smaller screen Y (towards top).
    final y = _pad + (1 - ny) * (1 - 2 * _pad);
    return (x: x, y: y);
  }
}