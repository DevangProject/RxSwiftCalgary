// ============================================================================
// lib/features/delivery_confirm/domain/delivery_state.dart
// ============================================================================

import 'package:flutter/foundation.dart';

// ── DeliveryOrder ─────────────────────────────────────────────────────────

@immutable
class DeliveryOrder {
  const DeliveryOrder({
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.pharmacyName,
    required this.statusLabel,
  });

  /// UUID from RouteStop.id — used as the API path parameter.
  final String orderId;
  final String customerName;
  final String address;
  final String pharmacyName;
  final String statusLabel;
}

// ── DeliveryStatus ────────────────────────────────────────────────────────

enum DeliveryStatus {
  initial,
  cameraOpening,
  photoCaptured,
  uploading,
  uploadSuccess,
  uploadFailed,
  offlinePendingUpload,
}

// ── DeliveryState ─────────────────────────────────────────────────────────

@immutable
class DeliveryState {
  const DeliveryState({
    this.status = DeliveryStatus.initial,
    this.photoPath,
    this.errorMessage,
    this.uploadProgress = 0.0,
    this.qrCode,
  });

  final DeliveryStatus status;
  final String? photoPath;
  final String? errorMessage;
  final double uploadProgress;
  final String? qrCode;

  // ── Getters ───────────────────────────────────────────────────────────────

  bool get hasPhoto      => photoPath != null;
  bool get hasQrCode     => qrCode != null && qrCode!.isNotEmpty;
  bool get isUploading   => status == DeliveryStatus.uploading;
  bool get isSuccess     => status == DeliveryStatus.uploadSuccess;
  bool get isOfflinePending => status == DeliveryStatus.offlinePendingUpload;

  bool get canComplete =>
      hasPhoto &&
          status != DeliveryStatus.uploading &&
          status != DeliveryStatus.uploadSuccess;

  // ── copyWith ──────────────────────────────────────────────────────────────

  DeliveryState copyWith({
    DeliveryStatus? status,
    String? photoPath,
    String? errorMessage,
    double? uploadProgress,
    String? qrCode,
    bool clearError = false,
  }) {
    return DeliveryState(
      status: status ?? this.status,
      photoPath: photoPath ?? this.photoPath,
      errorMessage:
      clearError ? null : (errorMessage ?? this.errorMessage),
      uploadProgress: uploadProgress ?? this.uploadProgress,
      qrCode: qrCode ?? this.qrCode,
    );
  }
}
