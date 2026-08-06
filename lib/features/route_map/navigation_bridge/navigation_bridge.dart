// ============================================================================
// features/today_route/route_map/navigation_bridge/navigation_bridge.dart
//
// Bridges the REAL Today's Route (todayRouteProvider) into the existing GPS
// navigation engine (NavigationNotifier / navigationProvider) WITHOUT editing
// either side.
//
// How it works:
//  • `_toNavigationStops` converts our API `RouteStop`s into the engine's
//    `NavigationStop`s (it only needs id / number / name / address / LatLng).
//  • `buildNavigationOverride()` returns a ProviderScope override so the old
//    NavigationMapScreen — which reads the global `navigationProvider` — runs
//    against the REAL route stops (seeded via the engine's own location +
//    directions services) instead of the engine's built-in demo data.
//
// The old screen and old provider are NOT modified.
//
// IMPORTANT: confirm the two engine import paths below against your project.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── Engine imports (old, unchanged) ──────────────────────────
// The screen imports the provider as a package path:
//   package:rxswift/features/navigation/provider/navigation_provider.dart
// and the provider imports the model as `../../../model/navigation/...`,
// which resolves to lib/model/navigation/ (NOT under the feature folder).
import 'package:rxswift/features/navigation/provider/navigation_provider.dart'
as engine;
import 'package:rxswift/model/navigation/navigation_model.dart' as engine_model;
import 'package:rxswift/service/background_location_service.dart';
import 'package:rxswift/features/today_route/route_map/provider/location_sync_provider.dart';

import '../../today_route/model/route_model.dart' as api;

// ── Our real route data ──────────────────────────────────────

/// Maps our API stops → engine `NavigationStop`s.
///
/// Skips stops without usable coordinates (the engine routes by LatLng).
/// The engine assigns `current` to index 0 and `pending` to the rest itself,
/// so we leave status as the engine default here.
List<engine_model.NavigationStop> _toNavigationStops(
    List<api.RouteStop> stops) {
  final result = <engine_model.NavigationStop>[];
  var n = 1;
  for (final s in stops) {
    if (!s.hasCoordinates) continue;
    result.add(
      engine_model.NavigationStop(
        id: s.id,
        stopNumber: n++,
        patientName: s.patientName,
        // Prefix with type so the driver sees Pickup/Drop context.
        address: '${s.stopType.label} · ${s.address}',
        scheduledTime: s.pharmacyName, // engine shows this as a sub-label
        location: LatLng(s.latitude, s.longitude),
      ),
    );
  }
  return result;
}

/// Override that makes the old screen's global `navigationProvider` resolve to
/// our real-route engine while inside a ProviderScope.
///
/// Pass the stops captured from `todayRouteProvider` BEFORE navigating — this
/// avoids re-reading providers across the nested scope boundary entirely.
Override buildNavigationOverride(List<api.RouteStop> apiStops) {
  final navStops = _toNavigationStops(apiStops);
  return engine.navigationProvider.overrideWith(
        (ref) => engine.NavigationNotifier(
      ref.read(engine.locationServiceProvider),
      ref.read(engine.directionsServiceProvider),
      ref.read(backgroundLocationServiceProvider),
      ref.read(locationSyncRepositoryProvider),
      initialStops: navStops.isEmpty ? null : navStops,
    ),
  );
}