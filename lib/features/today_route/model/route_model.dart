// ============================================================================
// features/today_route/model/route_model.dart
//
// Domain models for "Today's Route", mapped from the trip API response.
//
// NOTE: If you already have this file in your project, KEEP YOURS and delete
// this one — it is reconstructed to match how today_route_provider.dart and
// today_route_screen.dart use it, so the route_map screen can share the exact
// same types. The JSON keys below mirror the sample API response.
// ============================================================================

import 'package:flutter/foundation.dart';

/// Pickup (collect from pharmacy) vs Drop (deliver to patient).
enum StopType { pickup, drop }

extension StopTypeX on StopType {
  /// Chip label used across the UI.
  String get label => this == StopType.pickup ? 'Pickup' : 'Drop';

  bool get isPickup => this == StopType.pickup;
  bool get isDrop => this == StopType.drop;

  /// "Pickup From" / "Deliver To" address heading.
  String get addressLabel => isPickup ? 'Pickup From' : 'Deliver To';

  static StopType fromApi(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'PICKUP':
        return StopType.pickup;
      case 'DROP':
        return StopType.drop;
      default:
        return StopType.drop;
    }
  }
}

/// Lifecycle of a single stop.
enum StopStatus { pending, inProgress, completed, skipped }

extension StopStatusX on StopStatus {
  static StopStatus fromApi(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'PENDING':
        return StopStatus.pending;
      case 'INPROGRESS':
      case 'IN_PROGRESS':
      case 'IN-PROGRESS':
        return StopStatus.inProgress;
      case 'COMPLETED':
      case 'DELIVERED':
      case 'PICKED_UP':
        return StopStatus.completed;
      case 'SKIPPED':
      case 'FAILED':
        return StopStatus.skipped;
      default:
        return StopStatus.pending;
    }
  }
}

/// A single stop on the route.
@immutable
class RouteStop {
  const RouteStop({
    required this.id,
    required this.stopNumber,
    required this.stopType,
    required this.orderId,
    required this.orderNumber,
    required this.patientName,
    required this.patientPhone,
    required this.pharmacyName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.statusLabel,
    required this.priority,
    required this.distanceKm,
    required this.notes,
  });

  /// Stable identity. The API doesn't send a dedicated stop id, so we derive a
  /// unique one from sequence + orderId + type (an order appears twice: once as
  /// pickup, once as drop).
  final String id;

  /// 1-based sequence number (== API `sequence`).
  final int stopNumber;

  final StopType stopType;
  final String orderId;
  final String orderNumber;
  final String patientName;
  final String patientPhone;
  final String pharmacyName;
  final String address;
  final double latitude;
  final double longitude;
  final StopStatus status;
  final String statusLabel;
  final bool priority;

  /// API `distanceKmFromPreviousStop`.
  final double distanceKm;

  final String notes;

  bool get hasCoordinates => latitude != 0 && longitude != 0;

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    final seq = (json['sequence'] as num?)?.toInt() ?? 0;
    final orderId = json['orderId']?.toString() ?? '';
    final type = StopTypeX.fromApi(json['stopType']?.toString());
    return RouteStop(
      id: '$seq-$orderId-${type.name}',
      stopNumber: seq,
      stopType: type,
      orderId: orderId,
      orderNumber: json['orderNumber']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? '',
      patientPhone: json['patientPhone']?.toString() ?? '',
      pharmacyName: json['pharmacyName']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      status: StopStatusX.fromApi(json['status']?.toString()),
      statusLabel: json['statusLabel']?.toString() ?? '',
      priority: json['priority'] == true,
      distanceKm:
      (json['distanceKmFromPreviousStop'] as num?)?.toDouble() ?? 0,
      notes: json['notes']?.toString() ?? '',
    );
  }

  RouteStop copyWith({StopStatus? status}) {
    return RouteStop(
      id: id,
      stopNumber: stopNumber,
      stopType: stopType,
      orderId: orderId,
      orderNumber: orderNumber,
      patientName: patientName,
      patientPhone: patientPhone,
      pharmacyName: pharmacyName,
      address: address,
      latitude: latitude,
      longitude: longitude,
      status: status ?? this.status,
      statusLabel: statusLabel,
      priority: priority,
      distanceKm: distanceKm,
      notes: notes,
    );
  }
}

/// The whole day's route.
@immutable
class TodayRoute {
  const TodayRoute({
    required this.driverId,
    required this.driverName,
    required this.startLatitude,
    required this.startLongitude,
    required this.routeDate,
    required this.totalStops,
    required this.totalOrders,
    required this.estimatedDistanceKm,
    required this.stops,
  });

  final String driverId;
  final String driverName;
  final double startLatitude;
  final double startLongitude;
  final DateTime? routeDate;
  final int totalStops;
  final int totalOrders;
  final double estimatedDistanceKm;
  final List<RouteStop> stops;

  /// Count of pickup stops — surfaced as "… Pickup" in the summary line.
  int get pickupTime => stops.where((s) => s.stopType.isPickup).length;

  factory TodayRoute.fromJson(Map<String, dynamic> json) {
    final stopsJson = (json['stops'] as List?) ?? const [];
    return TodayRoute(
      driverId: json['driverId']?.toString() ?? '',
      driverName: json['driverName']?.toString() ?? '',
      startLatitude: (json['startLatitude'] as num?)?.toDouble() ?? 0,
      startLongitude: (json['startLongitude'] as num?)?.toDouble() ?? 0,
      routeDate: DateTime.tryParse(json['routeDate']?.toString() ?? ''),
      totalStops: (json['totalStops'] as num?)?.toInt() ?? stopsJson.length,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      estimatedDistanceKm:
      (json['estimatedDistanceKm'] as num?)?.toDouble() ?? 0,
      stops: stopsJson
          .map((e) => RouteStop.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  TodayRoute copyWith({List<RouteStop>? stops}) {
    return TodayRoute(
      driverId: driverId,
      driverName: driverName,
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      routeDate: routeDate,
      totalStops: totalStops,
      totalOrders: totalOrders,
      estimatedDistanceKm: estimatedDistanceKm,
      stops: stops ?? this.stops,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Unaccepted order — GET /api/driver/orders/unaccepted
// ─────────────────────────────────────────────────────────────

/// An order assigned to the driver that is still awaiting acceptance, shown
/// before today's route is loaded.
@immutable
class UnacceptedOrder {
  const UnacceptedOrder({
    required this.id,
    required this.orderNumber,
    required this.patientName,
    required this.patientPhone,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.deliveryNotes,
    required this.pharmacyName,
    required this.pharmacyAddress,
    required this.pharmacyPhone,
    required this.pharmacyLatitude,
    required this.pharmacyLongitude,
    required this.status,
    required this.statusLabel,
    required this.pickupWindowLabel,
    required this.handlingType,
    required this.copayAmount,
    required this.priority,
    required this.rxNumber,
    required this.sortOrder,
  });

  final String id;
  final String orderNumber;
  final String patientName;
  final String patientPhone;
  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String deliveryNotes;
  final String pharmacyName;
  final String pharmacyAddress;
  final String pharmacyPhone;
  final double? pharmacyLatitude;
  final double? pharmacyLongitude;
  final String status;
  final String statusLabel;
  final String pickupWindowLabel;
  final String handlingType;
  final double copayAmount;
  final bool priority;
  final String? rxNumber;
  final int sortOrder;

  factory UnacceptedOrder.fromJson(Map<String, dynamic> json) {
    return UnacceptedOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? '',
      patientPhone: json['patientPhone']?.toString() ?? '',
      deliveryAddress: json['deliveryAddress']?.toString() ?? '',
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
      deliveryNotes: json['deliveryNotes']?.toString() ?? '',
      pharmacyName: json['pharmacyName']?.toString() ?? '',
      pharmacyAddress: json['pharmacyAddress']?.toString() ?? '',
      pharmacyPhone: json['pharmacyPhone']?.toString() ?? '',
      pharmacyLatitude: (json['pharmacyLatitude'] as num?)?.toDouble(),
      pharmacyLongitude: (json['pharmacyLongitude'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? '',
      statusLabel: json['statusLabel']?.toString() ?? '',
      pickupWindowLabel: json['pickupWindowLabel']?.toString() ?? '',
      handlingType: json['handlingType']?.toString() ?? '',
      copayAmount: (json['copayAmount'] as num?)?.toDouble() ?? 0,
      priority: json['priority'] == true,
      rxNumber: json['rxNumber']?.toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}