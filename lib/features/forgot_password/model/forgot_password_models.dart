// lib/features/forgot_password/model/forgot_password_models.dart
//
// All request and response models for the forgot-password flow in one file,
// matching the shape returned by the RxSwift API:
//
//   { "success": true, "message": "OTP sent to registered email.",
//     "data": true, "statusCode": 200, "errors": [] }

// ─────────────────────────────────────────────────────────────
//  Forgot Password  (POST /api/auth/forgot-password)
// ─────────────────────────────────────────────────────────────

class ForgotPasswordRequest {
  const ForgotPasswordRequest({required this.email});
  final String email;
  Map<String, dynamic> toJson() => {'email': email};
}

// DioClient unwraps the envelope, so `data` from the API (bool true)
// is what `fromJson` receives. We model the full envelope here for
// cases where you need the message text (e.g. show it in the UI).
class ForgotPasswordResponse {
  const ForgotPasswordResponse({
    required this.success,
    required this.message,
    required this.statusCode,
  });

  final bool success;
  final String message;
  final int statusCode;

  // Called on the raw envelope when DioClient does NOT unwrap,
  // or you can use fromData() for the inner `data` field only.
  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResponse(
      success:    json['success']    as bool? ?? false,
      message:    json['message']    as String? ?? '',
      statusCode: json['statusCode'] as int? ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Verify OTP  (POST /api/auth/verify-otp)
// ─────────────────────────────────────────────────────────────

class VerifyOtpRequest {
  const VerifyOtpRequest({required this.email, required this.otp});
  final String email;
  final String otp;             // 6-digit string e.g. "750378"
  Map<String, dynamic> toJson() => {
    'email': email,
    'otp': otp,
  };
}

class VerifyOtpResponse {
  const VerifyOtpResponse({
    required this.success,
    required this.message,
    required this.statusCode,
  });

  final bool success;
  final String message;
  final int statusCode;

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      success:    json['success']    as bool? ?? false,
      message:    json['message']    as String? ?? '',
      statusCode: json['statusCode'] as int? ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Reset Password  (POST /api/auth/reset-password)
// ─────────────────────────────────────────────────────────────

class ResetPasswordRequest {
  const ResetPasswordRequest({
    required this.email,
    required this.otp,
    required this.newPassword,
    required this.confirmPassword,
  });

  final String email;
  final String otp;
  final String newPassword;
  final String confirmPassword;

  Map<String, dynamic> toJson() => {
    'email':           email,
    'otp':             otp,
    'newPassword':     newPassword,
    'confirmPassword': confirmPassword,
  };
}

class ResetPasswordResponse {
  const ResetPasswordResponse({
    required this.success,
    required this.message,
    required this.statusCode,
  });

  final bool success;
  final String message;
  final int statusCode;

  factory ResetPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResponse(
      success:    json['success']    as bool? ?? false,
      message:    json['message']    as String? ?? '',
      statusCode: json['statusCode'] as int? ?? 0,
    );
  }
}