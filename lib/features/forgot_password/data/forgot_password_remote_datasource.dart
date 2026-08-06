// lib/features/forgot_password/data/forgot_password_remote_datasource.dart
//
// Network layer for the forgot-password flow.
//
// Uses the shared DioClient — NOT a raw Dio instance — so every call
// automatically gets:
//   • Bearer token via the auth interceptor
//   • Connectivity guard (NoInternetException when offline)
//   • Envelope unwrapping ({success, message, data} → inner `data` field)
//   • DioException → NetworkException conversion
//
// Each method is a one-liner around DioClient.post<T> and returns
// ApiResult<T> directly, exactly like RouteRemoteDatasource.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../uttils/forgot_password_api_constants.dart';
import '../model/forgot_password_models.dart';

class ForgotPasswordRemoteDatasource {
  ForgotPasswordRemoteDatasource(this._dioClient);
  final DioClient _dioClient;

  // ── Send OTP  (POST /api/auth/forgot-password) ─────────────
  Future<ApiResult<bool>> sendOtp(ForgotPasswordRequest request) {
    return _dioClient.post<bool>(
      ForgotPasswordApiConstants.forgotPassword,
      data: request.toJson(),
      fromJson: _parseBoolResponse,
    );
  }

  // ── Verify OTP  (POST /api/auth/verify-reset-otp) ──────────
  Future<ApiResult<bool>> verifyOtp(VerifyOtpRequest request) {
    return _dioClient.post<bool>(
      ForgotPasswordApiConstants.verifyOtp,
      data: request.toJson(),
      fromJson: _parseBoolResponse,
    );
  }

  // ── Reset Password  (POST /api/auth/reset-password) ────────
  // Response on validation failure:
  //   { "success": false, "message": "Validation failed.",
  //     "data": null, "statusCode": 400,
  //     "errors": ["'ConfirmPassword' and 'NewPassword' do not match."] }
  // We parse the full envelope so errors[] can be surfaced in the UI.
  Future<ApiResult<bool>> resetPassword(ResetPasswordRequest request) {
    return _dioClient.post<bool>(
      ForgotPasswordApiConstants.resetPassword,
      data: request.toJson(),
      fromJson: (data) {
        if (data is Map<String, dynamic>) {
          if (data['success'] == true) return true;
          // Throw with the best available error message so ApiFailure
          // carries it through to the screen's error banner.
          throw _extractErrorMessage(data);
        }
        return _parseBoolResponse(data);
      },
    );
  }

  // ── Response parser ────────────────────────────────────────
  // Handles the API envelope shape:
  //   { "success": false, "message": "Validation failed.",
  //     "data": null, "statusCode": 400,
  //     "errors": ["'ConfirmPassword' and 'NewPassword' do not match."] }
  //
  // Returns true only when success:true. For false, DioClient will have
  // already thrown ApiFailure — this handles any 2xx edge cases.
  bool _parseBoolResponse(dynamic data) {
    if (data is bool) return data;
    if (data == null) return true;           // 2xx empty body → success
    if (data is Map<String, dynamic>) {
      if (data['success'] == true) return true;
      return false;
    }
    return true;
  }

  // Extracts the most useful error message from the API envelope.
  // Prefers errors[] items over the generic message field.
  String _extractErrorMessage(Map<String, dynamic> json) {
    final errors = json['errors'];
    if (errors is List && errors.isNotEmpty) {
      return errors.first.toString();
    }
    final message = json['message'];
    if (message is String && message.isNotEmpty) return message;
    return 'Something went wrong. Please try again.';
  }
}

// ─────────────────────────────────────────────────────────────
//  Provider
//
//  Passes the shared DioClient (with interceptors) — NOT a bare Dio().
//  Bare Dio bypasses auth + connectivity + envelope logic.
// ─────────────────────────────────────────────────────────────

final forgotPasswordRemoteDatasourceProvider =
Provider<ForgotPasswordRemoteDatasource>(
      (ref) => ForgotPasswordRemoteDatasource(ref.watch(dioClientProvider)),
);