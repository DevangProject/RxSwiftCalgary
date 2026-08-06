// ============================================================================
// lib/features/failed_delivery/data/failed_delivery_remote_datasource.dart
//
// Network layer for the failed-delivery feature.
// Uses the shared DioClient — same pattern as DeliveryRemoteDataSource.
//
// API:  POST /api/driver/orders/{orderId}/fail
// Body: multipart/form-data
//   • Reason  (string, required)
//   • Notes   (string, optional)
//   • Photo   (file,   optional — compressed to ≤8 MB before upload)
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

// ── Response model ─────────────────────────────────────────────────────────
// Maps the `data` object from the API response. Only the fields the app
// actually needs are mapped — extras are silently ignored.

class FailedDeliveryResponse {
  const FailedDeliveryResponse({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.failureReason,
    required this.patientName,
    required this.pharmacyName,
    required this.failedAt,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final String statusLabel;
  final String failureReason;
  final String patientName;
  final String pharmacyName;
  final String? failedAt;

  /// DioClient already unwraps the outer envelope, so [json] is the inner
  /// `data` object directly.
  factory FailedDeliveryResponse.fromJson(Map<String, dynamic> json) {
    return FailedDeliveryResponse(
      orderId:       json['id']            as String? ?? '',
      orderNumber:   json['orderNumber']   as String? ?? '',
      status:        json['status']        as String? ?? '',
      statusLabel:   json['statusLabel']   as String? ?? '',
      failureReason: json['failureReason'] as String? ?? '',
      patientName:   json['patientName']   as String? ?? '',
      pharmacyName:  json['pharmacyName']  as String? ?? '',
      failedAt:      json['failedAt']      as String?,
    );
  }
}

// ── Data source ────────────────────────────────────────────────────────────

class FailedDeliveryRemoteDataSource {
  FailedDeliveryRemoteDataSource(this._dioClient);
  final DioClient _dioClient;

  // ── Compression (identical to DeliveryRemoteDataSource) ────────────────
  static const int _targetBytes  = 8 * 1024 * 1024; // 8 MB
  static const int _startQuality = 85;
  static const int _minQuality   = 40;
  static const int _qualityStep  = 15;

  Future<File> _compressImage(File source) async {
    final originalSize = await source.length();

    if (originalSize <= _targetBytes) {
      debugPrint(
        '📷 [FailedDelivery] Image already under limit '
            '(${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB), skipping.',
      );
      return source;
    }

    debugPrint(
      '📷 [FailedDelivery] Compressing photo '
          '(${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB)...',
    );

    final tempDir    = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/failed_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

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
        debugPrint('⚠️ [FailedDelivery] Compression failed, using original.');
        return source;
      }

      final compressedSize = await result.length();
      debugPrint(
        '📷 [FailedDelivery] Quality $quality → '
            '${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      if (compressedSize <= _targetBytes) break;
      quality -= _qualityStep;
    } while (quality >= _minQuality);

    return File(result.path);
  }

  // ── Submit failed delivery ─────────────────────────────────────────────
  //
  // Field names are case-sensitive (server uses PascalCase):
  //   Reason, Notes, Photo
  //
  // Only the first photo is sent (API accepts a single Photo field).
  // If you need multiple photos, duplicate the field name.

  Future<ApiResult<FailedDeliveryResponse>> submitFailedDelivery({
    required String orderId,
    required String reason,
    required String notes,
    String? photoPath,              // optional — screen allows no photo
  }) async {
    // Build multipart fields
    final Map<String, dynamic> fields = {
      'Reason': reason,
      if (notes.isNotEmpty) 'Notes': notes,
    };

    // Compress + attach photo if provided
    if (photoPath != null && photoPath.isNotEmpty) {
      final original   = File(photoPath);
      final compressed = await _compressImage(original);

      fields['Photo'] = await MultipartFile.fromFile(
        compressed.path,
        filename:    'failed_delivery_photo.jpg',
        contentType: DioMediaType.parse('image/jpeg'),
      );
    }

    final formData = FormData.fromMap(fields);

    return _dioClient.post<FailedDeliveryResponse>(
      RouteApiConstants.failOrder(orderId),
      data:     formData,
      fromJson: (json) =>
          FailedDeliveryResponse.fromJson(json as Map<String, dynamic>),
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final failedDeliveryRemoteDataSourceProvider =
Provider<FailedDeliveryRemoteDataSource>(
      (ref) => FailedDeliveryRemoteDataSource(ref.watch(dioClientProvider)),
);