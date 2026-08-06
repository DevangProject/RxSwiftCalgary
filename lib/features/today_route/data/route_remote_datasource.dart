// ============================================================================
// lib/features/today_route/data/route_remote_datasource.dart
//
// Uses the central DioClient — NOT a raw Dio instance.
//
// CHANGE: pickupOrder() now sends multipart/form-data (PATCH) with:
//   Photo     — compressed JPEG (case-sensitive, PascalCase)
//   Latitude  — driver latitude  as string
//   Longitude — driver longitude as string
// ============================================================================

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../uttils/RouteApiConstants.dart';
import '../model/route_model.dart';

// ── Pickup confirmation response ──────────────────────────────────────────
// Maps the inner `data` object returned by the new pickup API.

class PickupConfirmationResponse {
  const PickupConfirmationResponse({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.pickupImageUrl,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.pickedUpAt,
  });

  final String  id;
  final String  orderNumber;
  final String  status;
  final String  statusLabel;
  final String  pickupImageUrl;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? pickedUpAt;

  factory PickupConfirmationResponse.fromJson(Map<String, dynamic> json) {
    return PickupConfirmationResponse(
      id:              json['id']             as String?  ?? '',
      orderNumber:     json['orderNumber']    as String?  ?? '',
      status:          json['status']         as String?  ?? '',
      statusLabel:     json['statusLabel']    as String?  ?? '',
      pickupImageUrl:  json['pickupImageUrl'] as String?  ?? '',
      pickupLatitude:  (json['pickupLatitude']  as num?)?.toDouble(),
      pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble(),
      pickedUpAt:      json['pickedUpAt']     as String?,
    );
  }
}

// ── Datasource ────────────────────────────────────────────────────────────

class RouteRemoteDatasource {
  RouteRemoteDatasource(this._dioClient);
  final DioClient _dioClient;

  // ── Image compression ──────────────────────────────────────────────────
  static const int _targetBytes  = 8 * 1024 * 1024; // 8 MB
  static const int _startQuality = 85;
  static const int _minQuality   = 40;
  static const int _qualityStep  = 15;

  Future<File> _compressImage(File source) async {
    final originalSize = await source.length();
    if (originalSize <= _targetBytes) {
      debugPrint(
        '📷 [Pickup] Already under limit '
            '(${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB), skipping.',
      );
      return source;
    }

    debugPrint(
      '📷 [Pickup] Compressing '
          '(${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB)...',
    );

    final tempDir    = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/pickup_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    int    quality = _startQuality;
    XFile? result;

    do {
      result = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        targetPath,
        quality:   quality,
        format:    CompressFormat.jpeg,
        minWidth:  1920,
        minHeight: 1920,
      );

      if (result == null) {
        debugPrint('⚠️ [Pickup] Compression failed, using original.');
        return source;
      }

      final size = await result.length();
      debugPrint(
        '📷 [Pickup] Quality $quality → '
            '${(size / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      if (size <= _targetBytes) break;
      quality -= _qualityStep;
    } while (quality >= _minQuality);

    return File(result.path);
  }

  // ── Today's route ──────────────────────────────────────────────────────

  Future<ApiResult<TodayRoute>> getTodayRoute() {
    return _dioClient.get<TodayRoute>(
      RouteApiConstants.todayRoute,
      fromJson: (json) => TodayRoute.fromJson(json as Map<String, dynamic>),
    );
  }

  // ── Update driver status ────────────────────────────────────────────────

  Future<ApiResult<bool>> updateDriverStatus({required String status}) {
    return _dioClient.patch<bool>(
      RouteApiConstants.driverStatus,
      data:     {'status': status},
      fromJson: (_) => true,
    );
  }

  // ── Update driver availability  PATCH /api/driver/availability ────────

  Future<ApiResult<void>> updateDriverAvailability({
    required bool isAvailable,
  }) {
    return _dioClient.patch<void>(
      RouteApiConstants.driverAvailability,
      data:     {'status': isAvailable ? '1' : '0'},
      fromJson: (_) {},
    );
  }



  // ── Unaccepted orders  GET /api/driver/orders/unaccepted ──────────────

  Future<ApiResult<List<UnacceptedOrder>>> getUnacceptedOrders() {
    return _dioClient.get<List<UnacceptedOrder>>(
      RouteApiConstants.unacceptedOrders,
      fromJson: (json) => (json as List? ?? const [])
          .map((e) => UnacceptedOrder.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // ── Bulk-accept unaccepted orders  PATCH /api/driver/orders/accept-bulk ──

  Future<ApiResult<bool>> acceptUnacceptedOrders(List<String> orderIds) {
    return _dioClient.patch<bool>(
      RouteApiConstants.acceptOrdersBulk,
      data: {'orderIds': orderIds},
      fromJson: (_) => true,
    );
  }

  Future<ApiResult<PickupConfirmationResponse>> pickupOrder({
    required String orderId,
    required String photoPath,
    required double latitude,
    required double longitude,
  }) async {
    // Compress before building the multipart body.
    final compressed = await _compressImage(File(photoPath));

    final formData = FormData.fromMap({
      'Photo': await MultipartFile.fromFile(
        compressed.path,
        filename:    'pickup_photo.jpg',
        contentType: DioMediaType.parse('image/jpeg'),
      ),
      'Latitude':  latitude.toString(),
      'Longitude': longitude.toString(),
    });

    return _dioClient.patch<PickupConfirmationResponse>(
      RouteApiConstants.pickupOrder(orderId),
      data:     formData,
      fromJson: (json) =>
          PickupConfirmationResponse.fromJson(json as Map<String, dynamic>),
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final routeRemoteDatasourceProvider = Provider<RouteRemoteDatasource>(
      (ref) => RouteRemoteDatasource(ref.watch(dioClientProvider)),
);