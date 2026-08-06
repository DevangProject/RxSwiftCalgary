// lib/features/forgot_password/provider/forgot_password_provider.dart
//
// State + Notifier for the full forgot-password flow (3 screens):
//   1. ForgotPasswordScreen   → sendOtp()
//   2. VerifyResetOtpScreen   → verifyOtp()
//   3. ResetPasswordScreen    → resetPassword()
//
// Architecture mirrors TodayRouteNotifier:
//   • Single state class with copyWith
//   • Named status enums (no boolean soup)
//   • Repository injected via constructor
//   • ApiResult pattern-matched with switch
//   • autoDispose — provider cleaned up when all screens pop

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../data/forgot_password_repository.dart';
import '../model/forgot_password_models.dart';

// ─────────────────────────────────────────────────────────────
//  Enums
// ─────────────────────────────────────────────────────────────

enum ForgotPasswordStatus { initial, loading, success, error, noInternet }

enum VerifyOtpStatus { initial, loading, success, error, noInternet }

enum ResetPasswordStatus { initial, loading, success, error, noInternet }

// ─────────────────────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────────────────────

class ForgotPasswordState {
  const ForgotPasswordState({
    // ── Forgot Password (step 1) ──
    this.forgotStatus = ForgotPasswordStatus.initial,
    this.forgotErrorMessage,

    // ── Verify OTP (step 2) ──
    this.verifyStatus = VerifyOtpStatus.initial,
    this.verifyErrorMessage,

    // ── Reset Password (step 3) ──
    this.resetStatus = ResetPasswordStatus.initial,
    this.resetErrorMessage,
  });

  final ForgotPasswordStatus forgotStatus;
  final String? forgotErrorMessage;

  final VerifyOtpStatus verifyStatus;
  final String? verifyErrorMessage;

  final ResetPasswordStatus resetStatus;
  final String? resetErrorMessage;

  // ── Convenience getters (mirrors TodayRouteState pattern) ──

  bool get isForgotLoading    => forgotStatus == ForgotPasswordStatus.loading;
  bool get isForgotSuccess    => forgotStatus == ForgotPasswordStatus.success;
  bool get isForgotError      => forgotStatus == ForgotPasswordStatus.error;
  bool get isForgotNoInternet => forgotStatus == ForgotPasswordStatus.noInternet;

  bool get isVerifyLoading    => verifyStatus == VerifyOtpStatus.loading;
  bool get isVerifySuccess    => verifyStatus == VerifyOtpStatus.success;
  bool get isVerifyError      => verifyStatus == VerifyOtpStatus.error;
  bool get isVerifyNoInternet => verifyStatus == VerifyOtpStatus.noInternet;

  bool get isResetLoading    => resetStatus == ResetPasswordStatus.loading;
  bool get isResetSuccess    => resetStatus == ResetPasswordStatus.success;
  bool get isResetError      => resetStatus == ResetPasswordStatus.error;
  bool get isResetNoInternet => resetStatus == ResetPasswordStatus.noInternet;

  ForgotPasswordState copyWith({
    ForgotPasswordStatus? forgotStatus,
    String? forgotErrorMessage,
    bool clearForgotError = false,

    VerifyOtpStatus? verifyStatus,
    String? verifyErrorMessage,
    bool clearVerifyError = false,

    ResetPasswordStatus? resetStatus,
    String? resetErrorMessage,
    bool clearResetError = false,
  }) {
    return ForgotPasswordState(
      forgotStatus: forgotStatus ?? this.forgotStatus,
      forgotErrorMessage: clearForgotError
          ? null
          : (forgotErrorMessage ?? this.forgotErrorMessage),

      verifyStatus: verifyStatus ?? this.verifyStatus,
      verifyErrorMessage: clearVerifyError
          ? null
          : (verifyErrorMessage ?? this.verifyErrorMessage),

      resetStatus: resetStatus ?? this.resetStatus,
      resetErrorMessage: clearResetError
          ? null
          : (resetErrorMessage ?? this.resetErrorMessage),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────────────────────

class ForgotPasswordNotifier extends StateNotifier<ForgotPasswordState> {
  ForgotPasswordNotifier(this._repository)
      : super(const ForgotPasswordState());

  final ForgotPasswordRepository _repository;

  // ── Step 1: Send OTP ──────────────────────────────────────
  Future<void> sendOtp(String email) async {
    state = state.copyWith(
      forgotStatus: ForgotPasswordStatus.loading,
      clearForgotError: true,
    );

    final result = await _repository.sendOtp(
      ForgotPasswordRequest(email: email),
    );

    switch (result) {
      case ApiSuccess():
        state = state.copyWith(forgotStatus: ForgotPasswordStatus.success);

      case ApiFailure(:final exception):
        final isNoInternet = exception.message
            .toLowerCase()
            .contains('internet');            // matches NoInternetException.message
        state = state.copyWith(
          forgotStatus: isNoInternet
              ? ForgotPasswordStatus.noInternet
              : ForgotPasswordStatus.error,
          forgotErrorMessage: exception.message,
        );
    }
  }

  // ── Step 2: Verify OTP ────────────────────────────────────
  Future<void> verifyOtp({required String email, required String otp}) async {
    state = state.copyWith(
      verifyStatus: VerifyOtpStatus.loading,
      clearVerifyError: true,
    );

    final result = await _repository.verifyOtp(
      VerifyOtpRequest(email: email, otp: otp),
    );

    switch (result) {
      case ApiSuccess():
        state = state.copyWith(verifyStatus: VerifyOtpStatus.success);

      case ApiFailure(:final exception):
        final isNoInternet = exception.message
            .toLowerCase()
            .contains('internet');
        state = state.copyWith(
          verifyStatus: isNoInternet
              ? VerifyOtpStatus.noInternet
              : VerifyOtpStatus.error,
          verifyErrorMessage: exception.message,
        );
    }
  }

  // ── Step 3: Reset Password ────────────────────────────────
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    state = state.copyWith(
      resetStatus: ResetPasswordStatus.loading,
      clearResetError: true,
    );

    final result = await _repository.resetPassword(
      ResetPasswordRequest(
        email:           email,
        otp:             otp,
        newPassword:     newPassword,
        confirmPassword: confirmPassword,
      ),
    );

    switch (result) {
      case ApiSuccess():
        state = state.copyWith(resetStatus: ResetPasswordStatus.success);

      case ApiFailure(:final exception):
        final isNoInternet = exception.message
            .toLowerCase()
            .contains('internet');
        state = state.copyWith(
          resetStatus: isNoInternet
              ? ResetPasswordStatus.noInternet
              : ResetPasswordStatus.error,
          resetErrorMessage: exception.message,
        );
    }
  }

  void reset() => state = const ForgotPasswordState();
}

// ─────────────────────────────────────────────────────────────
//  Provider
//
//  autoDispose: provider is cleaned up when all 3 screens are
//  popped — no stale state leaks back to the Login screen.
// ─────────────────────────────────────────────────────────────

final forgotPasswordProvider = StateNotifierProvider.autoDispose<
    ForgotPasswordNotifier, ForgotPasswordState>(
      (ref) => ForgotPasswordNotifier(ref.watch(forgotPasswordRepositoryProvider)),
);