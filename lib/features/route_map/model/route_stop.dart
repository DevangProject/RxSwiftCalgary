import 'package:flutter/foundation.dart';

/// Whether a stop is a pickup (collect from pharmacy) or a drop (deliver to patient).
enum StopType { pickup, drop }

/// Lifecycle of a single stop.
enum StopStatus { pending, active, completed, failed }

extension StopTypeX on StopType {
  bool get isPickup => this == StopType.pickup;
  bool get isDrop => this == StopType.drop;

  /// Address label shown above the address line ("Pickup From" / "Deliver To").
  String get addressLabel => isPickup ? 'Pickup From' : 'Deliver To';

  String get badgeLabel => isPickup ? 'Pickup' : 'Drop';
}

@immutable
class RouteStop {
  const RouteStop({
    required this.stopId,
    required this.stopNumber,
    required this.orderId,
    required this.orderNumber,
    required this.patientName,
    required this.patientPhone,
    required this.address,
    required this.pharmacyName,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.notes,
    required this.distanceKm,
    required this.mapX,
    required this.mapY,
  });

  final String stopId;
  final int stopNumber;
  final String orderId;
  final String orderNumber;
  final String patientName;
  final String patientPhone;
  final String address;
  final String pharmacyName;
  final StopType type;
  final double latitude;
  final double longitude;
  final StopStatus status;
  final String notes;
  final double distanceKm;

  /// Normalized 0..1 position on the prototype map canvas.
  final double mapX;
  final double mapY;

  /// True when the action button should be enabled — i.e. the driver is
  /// within the 1 km radius of this stop.
  bool get isWithinActionRange => distanceKm <= 1.0;

  RouteStop copyWith({
    StopStatus? status,
    double? distanceKm,
  }) {
    return RouteStop(
      stopId: stopId,
      stopNumber: stopNumber,
      orderId: orderId,
      orderNumber: orderNumber,
      patientName: patientName,
      patientPhone: patientPhone,
      address: address,
      pharmacyName: pharmacyName,
      type: type,
      latitude: latitude,
      longitude: longitude,
      status: status ?? this.status,
      notes: notes,
      distanceKm: distanceKm ?? this.distanceKm,
      mapX: mapX,
      mapY: mapY,
    );
  }
}

/// Immutable UI state for the Route Map screen.
@immutable
class RouteMapState {
  const RouteMapState({
    required this.stops,
    required this.selectedIndex,
    required this.sheetExpanded,
    this.justPickedUp = false,
  });

  final List<RouteStop> stops;

  /// Index of the stop currently shown in the bottom sheet.
  final int selectedIndex;

  /// Bottom sheet open (true) or collapsed to the peek state (false).
  final bool sheetExpanded;

  /// Transient flag that drives the "Picked Up!" success overlay.
  final bool justPickedUp;

  RouteStop get selectedStop => stops[selectedIndex];

  int get totalStops => stops.length;
  int get pickupCount => stops.where((s) => s.type.isPickup).length;
  int get completedCount =>
      stops.where((s) => s.status == StopStatus.completed).length;

  /// The first not-yet-finished stop — used for the header "Next:" chip.
  RouteStop? get nextActiveStop {
    for (final s in stops) {
      if (s.status == StopStatus.pending || s.status == StopStatus.active) {
        return s;
      }
    }
    return null;
  }

  RouteMapState copyWith({
    List<RouteStop>? stops,
    int? selectedIndex,
    bool? sheetExpanded,
    bool? justPickedUp,
  }) {
    return RouteMapState(
      stops: stops ?? this.stops,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      sheetExpanded: sheetExpanded ?? this.sheetExpanded,
      justPickedUp: justPickedUp ?? this.justPickedUp,
    );
  }
}