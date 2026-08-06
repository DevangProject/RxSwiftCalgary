// ============================================================================
// domain/failed_delivery_state.dart
// Failure reasons, status enum, and the immutable form state.
// ============================================================================

import 'package:flutter/foundation.dart';

/// Standard, selectable reasons a delivery attempt failed.
enum FailureReason {
  customerNotHome,
  addressNotFound,
  customerRefused,
  wrongOrIncompleteAddress,
  other,
}

extension FailureReasonLabel on FailureReason {
  String get label {
    switch (this) {
      case FailureReason.customerNotHome:
        return 'Customer not home';
      case FailureReason.addressNotFound:
        return 'Address not found';
      case FailureReason.customerRefused:
        return 'Customer refused delivery';
      case FailureReason.wrongOrIncompleteAddress:
        return 'Wrong / incomplete address';
      case FailureReason.other:
        return 'Other';
    }
  }

  /// Server-friendly snake_case code.
  String get code => name;
}

/// Lifecycle of the failed-delivery report submission.
enum SubmitStatus {
  initial,
  capturingPhoto,
  submitting,
  submitSuccess,
  submitFailed,
  offlinePending,
}

@immutable
class FailedDeliveryState {
  const FailedDeliveryState({
    this.status = SubmitStatus.initial,
    this.reason,
    this.notes = '',
    this.photoPaths = const [],
    this.errorMessage,
    this.uploadProgress = 0.0,
  });

  final SubmitStatus status;

  /// Selected failure reason (required before submit is enabled).
  final FailureReason? reason;

  /// Free-text notes (optional).
  final String notes;

  /// Local file paths of camera-captured photos (optional).
  final List<String> photoPaths;

  final String? errorMessage;
  final double uploadProgress;

  // -- Getters -------------------------------------------------------------

  bool get hasReason => reason != null;

  bool get isSubmitting => status == SubmitStatus.submitting;

  bool get isSuccess => status == SubmitStatus.submitSuccess;

  bool get isOfflinePending => status == SubmitStatus.offlinePending;

  bool get isCapturing => status == SubmitStatus.capturingPhoto;

  /// Submit is enabled only when a reason is chosen and we're not mid-submit
  /// or already done.
  bool get canSubmit =>
      hasReason &&
      status != SubmitStatus.submitting &&
      status != SubmitStatus.submitSuccess;

  // -- copyWith ------------------------------------------------------------

  FailedDeliveryState copyWith({
    SubmitStatus? status,
    FailureReason? reason,
    String? notes,
    List<String>? photoPaths,
    String? errorMessage,
    double? uploadProgress,
    bool clearError = false,
    bool clearReason = false,
  }) {
    return FailedDeliveryState(
      status: status ?? this.status,
      reason: clearReason ? null : (reason ?? this.reason),
      notes: notes ?? this.notes,
      photoPaths: photoPaths ?? this.photoPaths,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailedDeliveryState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          reason == other.reason &&
          notes == other.notes &&
          listEquals(photoPaths, other.photoPaths) &&
          errorMessage == other.errorMessage &&
          uploadProgress == other.uploadProgress;

  @override
  int get hashCode => Object.hash(
        status,
        reason,
        notes,
        Object.hashAll(photoPaths),
        errorMessage,
        uploadProgress,
      );
}

/// Order shown in the summary card.
@immutable
class DeliveryOrder {
  const DeliveryOrder({
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.pharmacyName,
    this.statusLabel = 'Attempt failed',
  });

  final String orderId;
  final String customerName;
  final String address;
  final String pharmacyName;
  final String statusLabel;
}
