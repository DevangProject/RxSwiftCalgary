import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/failed_delivery_remote_datasource.dart';
import '../../data/failed_delivery_repository.dart';
import '../../domain/failed_delivery_state.dart';

// ── Infrastructure providers ──────────────────────────────────────────────

class FailedDeliveryArgs {
  final String orderId;
  final String customerName;
  final String address;
  final String pharmacyName;

  const FailedDeliveryArgs({
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.pharmacyName,
  });
}


final failedDeliveryRepositoryProvider =
Provider<FailedDeliveryRepository>((ref) {
  return FailedDeliveryRepository(
    remoteDataSource: ref.watch(failedDeliveryRemoteDataSourceProvider),
  );
});


final failedDeliveryOrderProvider =
Provider.family<DeliveryOrder, FailedDeliveryArgs>((ref, args) {
  return DeliveryOrder(
    orderId: args.orderId,
    customerName: args.customerName,
    address: args.address,
    pharmacyName: args.pharmacyName,
    statusLabel: 'Attempt failed',
  );
});

// ── StateNotifier ─────────────────────────────────────────────────────────

class FailedDeliveryController extends StateNotifier<FailedDeliveryState> {
  FailedDeliveryController(this._repo, this._order)
      : super(const FailedDeliveryState()) {
    _watchConnectivity();
  }

  final FailedDeliveryRepository _repo;
  final DeliveryOrder             _order;
  StreamSubscription<bool>?       _connSub;

  void _watchConnectivity() {
    _connSub = _repo.onConnectivityChanged.listen((online) {
      if (online && state.status == SubmitStatus.offlinePending) {
        retryPendingSubmit();
      }
    });
  }

  // ── Form edits ────────────────────────────────────────────────────────

  void selectReason(FailureReason reason) {
    state = state.copyWith(reason: reason, clearError: true);
  }

  void updateNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  // ── Photos (camera only) ──────────────────────────────────────────────

  Future<void> addPhoto() async {
    final prevStatus = state.status;
    state = state.copyWith(status: SubmitStatus.capturingPhoto);
    try {
      final path = await _repo.captureFromCamera();
      if (path == null) {
        state = state.copyWith(status: prevStatus);
        return;
      }
      state = state.copyWith(
        status:     SubmitStatus.initial,
        photoPaths: [...state.photoPaths, path],
      );
    } catch (_) {
      state = state.copyWith(
        status:       prevStatus,
        errorMessage: 'Could not open the camera. Please try again.',
      );
    }
  }

  void removePhoto(int index) {
    if (index < 0 || index >= state.photoPaths.length) return;
    final updated = [...state.photoPaths]..removeAt(index);
    state = state.copyWith(photoPaths: updated);
  }

  // ── Submit ────────────────────────────────────────────────────────────

  Future<void> submit() async {
    if (!state.canSubmit) return;

    state = state.copyWith(
      status:         SubmitStatus.submitting,
      uploadProgress: 0.0,
      clearError:     true,
    );

    // API accepts a single Photo field — use the first captured photo.
    final report = FailedDeliveryReport(
      orderId:    _order.orderId,
      reasonCode: state.reason!.label,   // server expects human-readable label
      notes:      state.notes,
      photoPath:  state.photoPaths.isNotEmpty ? state.photoPaths.first : null,
    );

    try {
      await _repo.submitReport(report);
      state = state.copyWith(
        status:         SubmitStatus.submitSuccess,
        uploadProgress: 1.0,
      );
    } on NoInternetException {
      state = state.copyWith(
        status:       SubmitStatus.offlinePending,
        errorMessage: 'Report saved locally. It will submit when internet is restored.',
      );
    } on SubmitFailedException catch (e) {
      state = state.copyWith(
        status:       SubmitStatus.submitFailed,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status:       SubmitStatus.submitFailed,
        errorMessage: 'Something went wrong. Please retry.',
      );
    }
  }

  Future<void> retrySubmit() => submit();

  Future<void> retryPendingSubmit() async {
    final pending = await _repo.getPending();
    if (pending == null) return;

    state = state.copyWith(status: SubmitStatus.submitting);
    try {
      await _repo.submitReport(pending);
      state = state.copyWith(
        status:         SubmitStatus.submitSuccess,
        uploadProgress: 1.0,
      );
    } on NoInternetException {
      state = state.copyWith(status: SubmitStatus.offlinePending);
    } on SubmitFailedException catch (e) {
      state = state.copyWith(
        status:       SubmitStatus.submitFailed,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status:       SubmitStatus.submitFailed,
        errorMessage: 'Something went wrong. Please retry.',
      );
    }
  }

  void reset() => state = const FailedDeliveryState();

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
}

// ── Controller provider (family keyed on orderId) ─────────────────────────

final failedDeliveryControllerProvider = StateNotifierProvider.family<
    FailedDeliveryController,
    FailedDeliveryState,
    FailedDeliveryArgs>((ref, args) {

  final repo = ref.watch(failedDeliveryRepositoryProvider);
  final order = ref.watch(failedDeliveryOrderProvider(args));

  return FailedDeliveryController(repo, order);
});