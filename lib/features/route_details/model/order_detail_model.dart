// ============================================================================
// lib/features/route_details/model/order_detail_model.dart
//
// Domain model for GET /api/driver/orders/{orderId} — the full order detail
// shown on the route detail screen (pickup or drop task).
// ============================================================================

import 'package:flutter/foundation.dart';

/// A single entry in an order's status [OrderDetail.timeline].
@immutable
class OrderTimelineEntry {
  const OrderTimelineEntry({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String status;
  final String statusLabel;
  final String notes;
  final DateTime? createdAt;

  factory OrderTimelineEntry.fromJson(Map<String, dynamic> json) {
    return OrderTimelineEntry(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusLabel: json['statusLabel']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

/// Full detail for a single order, as returned by the order-detail endpoint.
@immutable
class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.orderNumber,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.pharmacyPhone,
    required this.pharmacyAddress,
    required this.pharmacyLatitude,
    required this.pharmacyLongitude,
    required this.patientId,
    required this.patientName,
    required this.patientPhone,
    required this.assignedDriverId,
    required this.driverName,
    required this.driverPhone,
    required this.driverLatitude,
    required this.driverLongitude,
    required this.driverLastLocationAt,
    required this.status,
    required this.statusLabel,
    required this.pickupWindow,
    required this.pickupWindowLabel,
    required this.handlingType,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.deliveryNotes,
    required this.showLiveTracking,
    required this.copayAmount,
    required this.currency,
    required this.priority,
    required this.isAcceptOrder,
    required this.dailySequenceOrderNo,
    required this.rxNumber,
    required this.createdAt,
    required this.deliveredAt,
    required this.pickedUpAt,
    required this.onRouteAt,
    required this.failedAt,
    required this.failureReason,
    required this.pickupImageUrl,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.timeline,
  });

  final String id;
  final String orderNumber;

  final String pharmacyId;
  final String pharmacyName;
  final String pharmacyPhone;
  final String pharmacyAddress;
  final double? pharmacyLatitude;
  final double? pharmacyLongitude;

  final String patientId;
  final String patientName;
  final String patientPhone;

  final String assignedDriverId;
  final String driverName;
  final String driverPhone;
  final double? driverLatitude;
  final double? driverLongitude;
  final DateTime? driverLastLocationAt;

  final String status;
  final String statusLabel;
  final String pickupWindow;
  final String pickupWindowLabel;
  final String handlingType;

  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String deliveryNotes;

  final bool showLiveTracking;
  final double copayAmount;
  final String currency;
  final bool priority;
  final bool isAcceptOrder;
  final int? dailySequenceOrderNo;
  final String? rxNumber;

  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final DateTime? pickedUpAt;
  final DateTime? onRouteAt;
  final DateTime? failedAt;
  final String? failureReason;

  final String? pickupImageUrl;
  final double? pickupLatitude;
  final double? pickupLongitude;

  final List<OrderTimelineEntry> timeline;

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final timelineJson = (json['timeline'] as List?) ?? const [];
    return OrderDetail(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      pharmacyId: json['pharmacyId']?.toString() ?? '',
      pharmacyName: json['pharmacyName']?.toString() ?? '',
      pharmacyPhone: json['pharmacyPhone']?.toString() ?? '',
      pharmacyAddress: json['pharmacyAddress']?.toString() ?? '',
      pharmacyLatitude: (json['pharmacyLatitude'] as num?)?.toDouble(),
      pharmacyLongitude: (json['pharmacyLongitude'] as num?)?.toDouble(),
      patientId: json['patientId']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? '',
      patientPhone: json['patientPhone']?.toString() ?? '',
      assignedDriverId: json['assignedDriverId']?.toString() ?? '',
      driverName: json['driverName']?.toString() ?? '',
      driverPhone: json['driverPhone']?.toString() ?? '',
      driverLatitude: (json['driverLatitude'] as num?)?.toDouble(),
      driverLongitude: (json['driverLongitude'] as num?)?.toDouble(),
      driverLastLocationAt:
          DateTime.tryParse(json['driverLastLocationAt']?.toString() ?? ''),
      status: json['status']?.toString() ?? '',
      statusLabel: json['statusLabel']?.toString() ?? '',
      pickupWindow: json['pickupWindow']?.toString() ?? '',
      pickupWindowLabel: json['pickupWindowLabel']?.toString() ?? '',
      handlingType: json['handlingType']?.toString() ?? '',
      deliveryAddress: json['deliveryAddress']?.toString() ?? '',
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
      deliveryNotes: json['deliveryNotes']?.toString() ?? '',
      showLiveTracking: json['showLiveTracking'] == true,
      copayAmount: (json['copayAmount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? '',
      priority: json['priority'] == true,
      isAcceptOrder: json['isAcceptOrder'] == true,
      dailySequenceOrderNo: (json['dailySequenceOrderNo'] as num?)?.toInt(),
      rxNumber: json['rxNumber']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      deliveredAt: DateTime.tryParse(json['deliveredAt']?.toString() ?? ''),
      pickedUpAt: DateTime.tryParse(json['pickedUpAt']?.toString() ?? ''),
      onRouteAt: DateTime.tryParse(json['onRouteAt']?.toString() ?? ''),
      failedAt: DateTime.tryParse(json['failedAt']?.toString() ?? ''),
      failureReason: json['failureReason']?.toString(),
      pickupImageUrl: json['pickupImageUrl']?.toString(),
      pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble(),
      pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble(),
      timeline: timelineJson
          .map((e) => OrderTimelineEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
