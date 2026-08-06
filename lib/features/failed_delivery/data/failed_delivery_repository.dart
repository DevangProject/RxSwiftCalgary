// ============================================================================
// lib/features/failed_delivery/data/failed_delivery_repository.dart
//
// Thin orchestration layer between the controller and:
//   • FailedDeliveryRemoteDataSource  (real API via DioClient)
//   • ImagePicker                     (camera capture)
//   • SharedPreferences               (offline queue)
//   • Connectivity                    (network watch)
//
// Mirrors DeliveryRepository from the delivery_confirm feature exactly.
// ============================================================================

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_result.dart';
import 'failed_delivery_remote_datasource.dart';

// ── Typed exceptions ──────────────────────────────────────────────────────
// Kept identical to DeliveryRepository so the controller's catch blocks
// are consistent across both features.

class NoInternetException implements Exception {
  const NoInternetException();
}

class SubmitFailedException implements Exception {
  const SubmitFailedException(this.message);
  final String message;
}

// ── Offline queue value object ────────────────────────────────────────────

class FailedDeliveryReport {
  const FailedDeliveryReport({
    required this.orderId,
    required this.reasonCode,
    required this.notes,
    this.photoPath,
  });

  final String  orderId;
  final String  reasonCode;
  final String  notes;
  final String? photoPath;      // single photo path (optional)

  Map<String, dynamic> toJson() => {
    'order_id':    orderId,
    'reason_code': reasonCode,
    'notes':       notes,
    if (photoPath != null) 'photo_path': photoPath,
  };

  factory FailedDeliveryReport.fromJson(Map<String, dynamic> json) {
    return FailedDeliveryReport(
      orderId:    json['order_id']    as String,
      reasonCode: json['reason_code'] as String,
      notes:      json['notes']       as String? ?? '',
      photoPath:  json['photo_path']  as String?,
    );
  }
}

// ── Repository ────────────────────────────────────────────────────────────

class FailedDeliveryRepository {
  FailedDeliveryRepository({
    required FailedDeliveryRemoteDataSource remoteDataSource,
    ImagePicker?   picker,
    Connectivity?  connectivity,
  })  : _remote       = remoteDataSource,
        _picker       = picker       ?? ImagePicker(),
        _connectivity = connectivity ?? Connectivity();

  final FailedDeliveryRemoteDataSource _remote;
  final ImagePicker   _picker;
  final Connectivity  _connectivity;

  static const String _pendingKey = 'pending_failed_delivery_report';

  // ── Connectivity ──────────────────────────────────────────────────────

  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged
          .map((results) => !results.contains(ConnectivityResult.none));

  Future<bool> hasInternet() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  // ── Camera ────────────────────────────────────────────────────────────
  // Camera source only — gallery is intentionally never exposed.

  Future<String?> captureFromCamera() async {
    final XFile? file = await _picker.pickImage(
      source:               ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality:         72,     // first-pass; datasource compresses further
      maxWidth:             1920,
    );
    return file?.path;
  }

  // ── Submit ────────────────────────────────────────────────────────────

  Future<void> submitReport(FailedDeliveryReport report) async {
    if (!await hasInternet()) {
      await savePending(report);
      throw const NoInternetException();
    }

    final result = await _remote.submitFailedDelivery(
      orderId:   report.orderId,
      reason:    report.reasonCode,
      notes:     report.notes,
      photoPath: report.photoPath,
    );

    switch (result) {
      case ApiSuccess():
        await clearPending();

      case ApiFailure(:final exception):
        final msg = exception.message.toLowerCase();
        final isOffline = msg.contains('internet') ||
            msg.contains('connection') ||
            msg.contains('network');

        if (isOffline) {
          await savePending(report);
          throw const NoInternetException();
        }

        final readable = exception.message.isNotEmpty
            ? exception.message
            : 'Submit failed. Please retry.';
        throw SubmitFailedException(readable);
    }
  }

  // ── Offline queue ─────────────────────────────────────────────────────

  Future<void> savePending(FailedDeliveryReport report) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, jsonEncode(report.toJson()));
  }

  Future<FailedDeliveryReport?> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_pendingKey);
    if (raw == null) return null;
    return FailedDeliveryReport.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }
}