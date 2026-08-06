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

class DeliveryPhotoResponse {
  const DeliveryPhotoResponse({
    required this.orderId,
    required this.orderNumber,
    required this.photoUrl,
  });

  final String orderId;
  final String orderNumber;
  final String photoUrl;

  /// DioClient already unwrapped the outer envelope, so [json] is the inner
  /// `data` object: { "orderId": "…", "orderNumber": "…", "photoUrl": "…" }
  factory DeliveryPhotoResponse.fromJson(Map<String, dynamic> json) {
    return DeliveryPhotoResponse(
      orderId:     json['orderId']     as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      photoUrl:    json['photoUrl']    as String? ?? '',
    );
  }
}

// ── Data source ────────────────────────────────────────────────────────────

class DeliveryRemoteDataSource {
  DeliveryRemoteDataSource(this._dioClient);
  final DioClient _dioClient;

  // ── Compression ────────────────────────────────────────────────────────
  // Target: 8 MB (safely under the server's 10 MB hard limit).
  // Reduces JPEG quality in steps until the file is small enough.
  static const int _targetBytes   = 8 * 1024 * 1024; // 8 MB
  static const int _startQuality  = 85;
  static const int _minQuality    = 40;
  static const int _qualityStep   = 15;

  Future<File> _compressImage(File source) async {
    final originalSize = await source.length();

    if (originalSize <= _targetBytes) {
      debugPrint(
        '📷 Image already under limit '
            '(${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB), skipping.',
      );
      return source;
    }

    debugPrint(
      '📷 Compressing delivery photo '
          '(${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB)...',
    );

    final tempDir    = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/delivery_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    int     quality = _startQuality;
    XFile?  result;

    do {
      result = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        targetPath,
        quality:   quality,
        format:    CompressFormat.jpeg,
        // Cap longest side at 1920 px — preserves aspect ratio.
        minWidth:  1920,
        minHeight: 1920,
      );

      if (result == null) {
        debugPrint('⚠️ Compression failed, using original file.');
        return source;
      }

      final compressedSize = await result.length();
      debugPrint(
        '📷 Quality $quality → '
            '${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      if (compressedSize <= _targetBytes) break;
      quality -= _qualityStep;
    } while (quality >= _minQuality);

    return File(result.path);
  }

  // ── Upload ─────────────────────────────────────────────────────────────

  /// Upload delivery proof photo for [orderId].
  /// Compresses the image before upload to stay under the 10 MB server limit.
  /// Field name is case-sensitive: must be exactly "Photo".
  Future<ApiResult<DeliveryPhotoResponse>> uploadDeliveryPhoto({
    required String orderId,
    required String photoPath,
  }) async {
    // Compress before building the multipart request.
    final original   = File(photoPath);
    final compressed = await _compressImage(original);

    final fileName = compressed.uri.pathSegments.last;
    final ext      = fileName.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    final formData = FormData.fromMap({
      'Photo': await MultipartFile.fromFile(
        compressed.path,
        filename: 'delivery_photo.jpg',          // always jpg after compression
        contentType: DioMediaType.parse(mimeType),
      ),
    });

    return _dioClient.post<DeliveryPhotoResponse>(
      RouteApiConstants.deliveryPhoto(orderId),
      data: formData,
      fromJson: (json) =>
          DeliveryPhotoResponse.fromJson(json as Map<String, dynamic>),
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final deliveryRemoteDataSourceProvider = Provider<DeliveryRemoteDataSource>(
      (ref) => DeliveryRemoteDataSource(ref.watch(dioClientProvider)),
);