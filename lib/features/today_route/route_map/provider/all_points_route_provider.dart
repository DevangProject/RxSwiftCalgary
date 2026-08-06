// ============================================================================
// lib/features/today_route/route_map/provider/all_points_route_provider.dart
//
// CHANGES from original:
//   • Exposes per-leg polylines (List<LegRoute>) in addition to the merged
//     polylinePoints — so the map can draw each stop-to-stop segment
//     individually with its own color/style.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:rxswift/features/navigation/provider/navigation_provider.dart'
    show directionsServiceProvider;
import 'package:rxswift/service/directions_service.dart';

import '../../model/route_model.dart';

// ── Per-leg model ─────────────────────────────────────────────────────────

class LegRoute {
  const LegRoute({
    required this.from,
    required this.to,
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });

  final LatLng from;
  final LatLng to;
  final List<LatLng> points;        // road-following points for this leg
  final double distanceKm;
  final int durationMinutes;
}

// ── AllPointsRoute ────────────────────────────────────────────────────────

class AllPointsRoute {
  const AllPointsRoute({
    required this.legs,
    required this.polylinePoints,
    required this.totalDistanceKm,
    required this.totalMinutes,
  });

  final List<LegRoute> legs;         // ← NEW: one entry per stop-to-stop segment
  final List<LatLng> polylinePoints; // merged (kept for backward compat)
  final double totalDistanceKm;
  final int totalMinutes;

  static const empty = AllPointsRoute(
    legs: [],
    polylinePoints: [],
    totalDistanceKm: 0,
    totalMinutes: 0,
  );
}

// ── Waypoints ─────────────────────────────────────────────────────────────

List<LatLng> _waypoints(TodayRoute route) {
  final pts = <LatLng>[];
  if (route.startLatitude != 0 && route.startLongitude != 0) {
    pts.add(LatLng(route.startLatitude, route.startLongitude));
  }
  for (final s in route.stops) {
    if (s.hasCoordinates) pts.add(LatLng(s.latitude, s.longitude));
  }
  return pts;
}

// ── Provider ──────────────────────────────────────────────────────────────

final allPointsRouteProvider = FutureProvider.autoDispose
    .family<AllPointsRoute, TodayRoute>((ref, route) async {
  final directions = ref.read(directionsServiceProvider);
  final waypoints = _waypoints(route);

  if (waypoints.length < 2) return AllPointsRoute.empty;

  final legs = <LegRoute>[];
  final combined = <LatLng>[];
  double totalKm = 0;
  int totalMin = 0;

  for (int i = 0; i < waypoints.length - 1; i++) {
    final from = waypoints[i];
    final to   = waypoints[i + 1];

    try {
      final leg = await directions.getRoute(
        origin: from,
        destination: to,
      );

      legs.add(LegRoute(
        from: from,
        to: to,
        points: leg.polylinePoints,
        distanceKm: leg.distanceKm,
        durationMinutes: leg.durationMinutes,
      ));

      // Merge into combined list (skip first point of each leg after the first
      // to avoid duplicating the shared vertex).
      if (combined.isNotEmpty && leg.polylinePoints.isNotEmpty) {
        combined.addAll(leg.polylinePoints.skip(1));
      } else {
        combined.addAll(leg.polylinePoints);
      }

      totalKm  += leg.distanceKm;
      totalMin += leg.durationMinutes;
    } on DirectionsException {
      // Leg failed — add a straight-line fallback so the route stays continuous.
      legs.add(LegRoute(
        from: from,
        to: to,
        points: [from, to],
        distanceKm: 0,
        durationMinutes: 0,
      ));
      if (combined.isNotEmpty) {
        combined.add(to);
      } else {
        combined.addAll([from, to]);
      }
    }
  }

  return AllPointsRoute(
    legs: legs,
    polylinePoints: combined,
    totalDistanceKm: totalKm,
    totalMinutes: totalMin,
  );
});