// ============================================================================
// lib/features/delivery_confirm/provider/delivery_confirmation_provider.dart
// ============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../data/delivery_remote_datasource.dart';
import '../domain/delivery_state.dart';
import '../repository/delivery_repository.dart';

// ── Infrastructure providers ──────────────────────────────────────────────

final deliveryRemoteDataSourceProvider =
Provider<DeliveryRemoteDataSource>((ref) {
  return DeliveryRemoteDataSource(ref.watch(dioClientProvider));
});

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return DeliveryRepository(
    remoteDataSource: ref.watch(deliveryRemoteDataSourceProvider),
  );
});

// ── Order provider (family) ───────────────────────────────────────────────

final deliveryOrderProvider =
Provider.family<DeliveryOrder, DeliveryOrderArgs>((ref, args) {
  return DeliveryOrder(
    orderId:      args.orderId,
    customerName: args.customerName,
    address:      args.address,
    pharmacyName: args.pharmacyName,
    statusLabel:  args.statusLabel,
  );
});

class DeliveryOrderArgs {
  const DeliveryOrderArgs({
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.pharmacyName,
    this.statusLabel = 'Arrived at destination',
  });

  final String orderId;
  final String customerName;
  final String address;
  final String pharmacyName;
  final String statusLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DeliveryOrderArgs && other.orderId == orderId;

  @override
  int get hashCode => orderId.hashCode;
}

// ── StateNotifier ─────────────────────────────────────────────────────────

class DeliveryController extends StateNotifier<DeliveryState> {
  DeliveryController(this._repo, this._order) : super(const DeliveryState()) {
    _watchConnectivity();
  }

  final DeliveryRepository _repo;
  final DeliveryOrder _order;
  StreamSubscription<bool>? _connSub;
  String? _rawPhotoPath;

  void _watchConnectivity() {
    _connSub = _repo.onConnectivityChanged.listen((online) {
      if (online && state.status == DeliveryStatus.offlinePendingUpload) {
        retryPendingUpload();
      }
    });
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<void> openCamera() async {
    state = state.copyWith(
      status: DeliveryStatus.cameraOpening,
      clearError: true,
      clearLocationWarning: true,
    );
    try {
      final path = await _repo.captureFromCamera();
      if (path == null) {
        state = state.copyWith(
          status: state.hasPhoto
              ? DeliveryStatus.photoCaptured
              : DeliveryStatus.initial,
        );
        return;
      }

      CaptureLocation? loc;
      String? warning;
      try {
        loc = await _repo.getCurrentLocation();
      } on LocationException catch (e) {
        warning = e.message;
      } catch (_) {
        warning = 'Could not capture location. You can retry or proceed.';
      }

      _rawPhotoPath = path;
      String finalPath = path;
      if (loc != null) {
        try {
          finalPath = await _repo.stampLocationOnImage(
            photoPath: path,
            location: loc,
          );
        } catch (_) {
          finalPath = path;
        }
      }

      state = state.copyWith(
        status: DeliveryStatus.photoCaptured,
        photoPath: finalPath,
        location: loc,
        locationWarning: warning,
        clearLocation: loc == null,
        clearLocationWarning: warning == null,
        uploadProgress: 0.0,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: DeliveryStatus.initial,
        errorMessage: 'Could not open the camera. Please try again.',
      );
    }
  }

  Future<void> retakePhoto() => openCamera();

  // ── QR scan ────────────────────────────────────────────────────────────────

  void setQrCode(String code) => state = state.copyWith(qrCode: code);

  // ── Location retry ────────────────────────────────────────────────────────

  Future<void> retryLocation() async {
    if (!state.hasPhoto) return;
    try {
      final loc = await _repo.getCurrentLocation();
      final raw = _rawPhotoPath ?? state.photoPath!;
      String path = raw;
      try {
        path = await _repo.stampLocationOnImage(photoPath: raw, location: loc);
      } catch (_) {
        path = raw;
      }
      state = state.copyWith(
        photoPath: path,
        location: loc,
        clearLocationWarning: true,
      );
    } on LocationException catch (e) {
      state = state.copyWith(locationWarning: e.message);
    } catch (_) {
      state = state.copyWith(
        locationWarning: 'Could not capture location. You can retry or proceed.',
      );
    }
  }

  // ── Upload ────────────────────────────────────────────────────────────────
  //
  // onProgress removed — DioClient.post() does not expose onSendProgress.
  // Loading is indicated via DeliveryStatus.uploading in the UI.

  Future<void> uploadAndComplete() async {
    if (!state.hasPhoto) return;

    state = state.copyWith(
      status: DeliveryStatus.uploading,
      uploadProgress: 0.0,
      clearError: true,
    );

    try {
      await _repo.uploadDeliveryPhoto(
        orderId: _order.orderId,
        photoPath: state.photoPath!,
        location: state.location,
        // onProgress removed
      );
      state = state.copyWith(
        status: DeliveryStatus.uploadSuccess,
        uploadProgress: 1.0,
      );
    } on NoInternetException {
      state = state.copyWith(
        status: DeliveryStatus.offlinePendingUpload,
        errorMessage:
        'Photo saved locally. It will upload when internet is restored.',
      );
    } on UploadFailedException catch (e) {
      state = state.copyWith(
        status: DeliveryStatus.uploadFailed,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: DeliveryStatus.uploadFailed,
        errorMessage: 'Something went wrong. Please retry.',
      );
    }
  }

  Future<void> retryUpload() => uploadAndComplete();

  Future<void> retryPendingUpload() async {
    final pending = await _repo.getPending();
    if (pending == null) return;
    state = state.copyWith(
      status: DeliveryStatus.photoCaptured,
      photoPath: pending.photoPath,
      location: pending.location,
      clearLocation: pending.location == null,
    );
    await uploadAndComplete();
  }

  void reset() => state = const DeliveryState();

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
}

// ── Controller provider (family keyed on orderId) ─────────────────────────

final deliveryControllerProvider =
StateNotifierProvider.family<DeliveryController, DeliveryState, String>(
        (ref, orderId) {
      final repo  = ref.watch(deliveryRepositoryProvider);
      final order = DeliveryOrder(
        orderId:      orderId,
        customerName: '',
        address:      '',
        pharmacyName: '',
        statusLabel:  '',
      );
      return DeliveryController(repo, order);
    });