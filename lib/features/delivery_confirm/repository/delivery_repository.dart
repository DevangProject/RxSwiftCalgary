// ============================================================================
// lib/features/delivery_confirm/repository/delivery_repository.dart
// ============================================================================

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_result.dart';
import '../data/delivery_remote_datasource.dart';

// ── Typed exceptions ──────────────────────────────────────────────────────

class NoInternetException implements Exception {}

class UploadFailedException implements Exception {
  UploadFailedException(this.message);
  final String message;
}

// ── Offline-queue value object ────────────────────────────────────────────

class PendingUpload {
  const PendingUpload({required this.photoPath});
  final String photoPath;
}

// ── Repository ────────────────────────────────────────────────────────────

class DeliveryRepository {
  DeliveryRepository({required DeliveryRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource;

  final DeliveryRemoteDataSource _remote;
  final _picker = ImagePicker();

  static const _kPendingPhoto = 'pending_delivery_photo';

  // ── Connectivity stream ───────────────────────────────────────────────────

  Stream<bool> get onConnectivityChanged => Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<String?> captureFromCamera() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 72,   // first-pass reduction before upload compression
    );
    return xFile?.path;
  }

  // ── Upload ────────────────────────────────────────────────────────────────
  //
  // onProgress parameter removed — DioClient.post() does not expose
  // onSendProgress. The loading indicator is still shown via DeliveryStatus.uploading.

  Future<void> uploadDeliveryPhoto({
    required String orderId,
    required String photoPath,
  }) async {
    final result = await _remote.uploadDeliveryPhoto(
      orderId: orderId,
      photoPath: photoPath,
    );

    result.when(
      success: (_) async {
        await _clearPending();
      },
      failure: (exception) {
        final msg = exception.toString().toLowerCase();
        if (exception.runtimeType.toString().contains('NoInternet') ||
            msg.contains('internet') ||
            msg.contains('connection') ||
            msg.contains('network')) {
          _savePending(photoPath: photoPath);
          throw NoInternetException();
        }
        String? readable;
        try {
          readable = (exception as dynamic).message as String?;
        } catch (_) {}
        final message = (readable != null && readable.isNotEmpty)
            ? readable
            : (exception.toString().isNotEmpty
            ? exception.toString()
            : 'Upload failed. Please retry.');

        throw UploadFailedException(message);
      },
    );
  }

  // ── Offline queue ─────────────────────────────────────────────────────────

  Future<void> _savePending({required String photoPath}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingPhoto, photoPath);
  }

  Future<void> _clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingPhoto);
  }

  Future<PendingUpload?> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final path  = prefs.getString(_kPendingPhoto);
    if (path == null) return null;
    return PendingUpload(photoPath: path);
  }
}
