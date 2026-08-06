import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Forgot Password State ────────────────────────────────────────────────────

enum ForgotPasswordStatus { idle, loading, success, error }

class ForgotPasswordState {
  final ForgotPasswordStatus status;
  final String? errorMessage;

  const ForgotPasswordState({
    this.status = ForgotPasswordStatus.idle,
    this.errorMessage,
  });

  ForgotPasswordState copyWith({
    ForgotPasswordStatus? status,
    String? errorMessage,
  }) {
    return ForgotPasswordState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ForgotPasswordNotifier extends StateNotifier<ForgotPasswordState> {
  ForgotPasswordNotifier() : super(const ForgotPasswordState());

  Future<bool> sendOtp(String email) async {
    state = state.copyWith(status: ForgotPasswordStatus.loading);
    try {
      // TODO: Replace with real API call
      // final response = await http.post(
      //   Uri.parse('https://api.rxswift.ca/auth/forgot-password'),
      //   body: {'email': email},
      // );
      await Future.delayed(const Duration(seconds: 2)); // simulate network
      state = state.copyWith(status: ForgotPasswordStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: ForgotPasswordStatus.error,
        errorMessage: 'Failed to send OTP. Please try again.',
      );
      return false;
    }
  }

  void reset() => state = const ForgotPasswordState();
}

final forgotPasswordProvider =
    StateNotifierProvider<ForgotPasswordNotifier, ForgotPasswordState>(
  (ref) => ForgotPasswordNotifier(),
);

// ─── Verify OTP State ─────────────────────────────────────────────────────────

enum VerifyOtpStatus { idle, loading, success, error, resending }

class VerifyOtpState {
  final VerifyOtpStatus status;
  final int timerSeconds;
  final String? errorMessage;

  const VerifyOtpState({
    this.status = VerifyOtpStatus.idle,
    this.timerSeconds = 59,
    this.errorMessage,
  });

  VerifyOtpState copyWith({
    VerifyOtpStatus? status,
    int? timerSeconds,
    String? errorMessage,
  }) {
    return VerifyOtpState(
      status: status ?? this.status,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get timerDisplay {
    final mins = (timerSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (timerSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  bool get canResend => timerSeconds == 0;
}

class VerifyOtpNotifier extends StateNotifier<VerifyOtpState> {
  VerifyOtpNotifier() : super(const VerifyOtpState());

  Future<bool> verifyOtp(String email, String otp) async {
    state = state.copyWith(status: VerifyOtpStatus.loading);
    try {
      // TODO: Replace with real API call
      await Future.delayed(const Duration(seconds: 2));
      state = state.copyWith(status: VerifyOtpStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: VerifyOtpStatus.error,
        errorMessage: 'Invalid OTP. Please try again.',
      );
      return false;
    }
  }

  Future<bool> resendOtp(String email) async {
    state = state.copyWith(status: VerifyOtpStatus.resending, timerSeconds: 59);
    try {
      await Future.delayed(const Duration(seconds: 1));
      state = state.copyWith(status: VerifyOtpStatus.idle);
      return true;
    } catch (e) {
      return false;
    }
  }

  void tickTimer() {
    if (state.timerSeconds > 0) {
      state = state.copyWith(timerSeconds: state.timerSeconds - 1);
    }
  }

  void reset() => state = const VerifyOtpState();
}

final verifyOtpProvider =
    StateNotifierProvider<VerifyOtpNotifier, VerifyOtpState>(
  (ref) => VerifyOtpNotifier(),
);

// ─── Reset Password State ─────────────────────────────────────────────────────

enum ResetPasswordStatus { idle, loading, success, error }

class ResetPasswordState {
  final ResetPasswordStatus status;
  final String? errorMessage;

  const ResetPasswordState({
    this.status = ResetPasswordStatus.idle,
    this.errorMessage,
  });

  ResetPasswordState copyWith({
    ResetPasswordStatus? status,
    String? errorMessage,
  }) {
    return ResetPasswordState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ResetPasswordNotifier extends StateNotifier<ResetPasswordState> {
  ResetPasswordNotifier() : super(const ResetPasswordState());

  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    state = state.copyWith(status: ResetPasswordStatus.loading);
    try {
      // TODO: Replace with real API call
      // final response = await http.post(
      //   Uri.parse('https://api.rxswift.ca/auth/reset-password'),
      //   body: {'email': email, 'otp': otp, 'password': newPassword},
      // );
      await Future.delayed(const Duration(seconds: 2));
      state = state.copyWith(status: ResetPasswordStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: ResetPasswordStatus.error,
        errorMessage: 'Failed to reset password. Please try again.',
      );
      return false;
    }
  }

  void reset() => state = const ResetPasswordState();
}

final resetPasswordProvider =
    StateNotifierProvider<ResetPasswordNotifier, ResetPasswordState>(
  (ref) => ResetPasswordNotifier(),
);
