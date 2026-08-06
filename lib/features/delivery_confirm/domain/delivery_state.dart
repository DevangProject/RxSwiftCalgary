// ============================================================================
// lib/features/delivery_confirm/domain/delivery_state.dart
// ============================================================================

import 'package:flutter/foundation.dart';

// ── CaptureLocation ───────────────────────────────────────────────────────

@immutable
class CaptureLocation {
  const CaptureLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.formattedAddress,
    this.address, // reverse-geocoded human address (optional)
  });

  final double latitude;
  final double longitude;
  final double accuracy; // metres
  final String formattedAddress;
  final String? address;

  /// "12.97163, 77.59369" — shown in LocationInfoCard as the coordinate line.
  String get coordinatesLabel =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
          '  ±${accuracy.toStringAsFixed(0)} m';

  @override
  String toString() => address ?? formattedAddress;
}

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
    this.location,
    this.locationWarning,
    this.errorMessage,
    this.uploadProgress = 0.0,
    this.qrCode,
  });

  final DeliveryStatus status;
  final String? photoPath;
  final CaptureLocation? location;
  final String? locationWarning;
  final String? errorMessage;
  final double uploadProgress;
  final String? qrCode;

  // ── Getters ───────────────────────────────────────────────────────────────

  bool get hasPhoto      => photoPath != null;
  bool get hasLocation   => location != null;   // ← used by LocationInfoCard
  bool get hasQrCode     => qrCode != null && qrCode!.isNotEmpty;
  bool get isUploading   => status == DeliveryStatus.uploading;
  bool get isSuccess     => status == DeliveryStatus.uploadSuccess;
  bool get isOfflinePending => status == DeliveryStatus.offlinePendingUpload;

  bool get canComplete =>
      hasPhoto &&
          hasQrCode &&
          status != DeliveryStatus.uploading &&
          status != DeliveryStatus.uploadSuccess;

  // ── copyWith ──────────────────────────────────────────────────────────────

  DeliveryState copyWith({
    DeliveryStatus? status,
    String? photoPath,
    CaptureLocation? location,
    String? locationWarning,
    String? errorMessage,
    double? uploadProgress,
    String? qrCode,
    bool clearLocation = false,
    bool clearLocationWarning = false,
    bool clearError = false,
  }) {
    return DeliveryState(
      status: status ?? this.status,
      photoPath: photoPath ?? this.photoPath,
      location: clearLocation ? null : (location ?? this.location),
      locationWarning: clearLocationWarning
          ? null
          : (locationWarning ?? this.locationWarning),
      errorMessage:
      clearError ? null : (errorMessage ?? this.errorMessage),
      uploadProgress: uploadProgress ?? this.uploadProgress,
      qrCode: qrCode ?? this.qrCode,
    );
  }
}