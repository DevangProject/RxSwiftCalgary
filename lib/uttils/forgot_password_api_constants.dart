// lib/utils/forgot_password_api_constants.dart
//
// Centralises all forgot-password endpoint paths.
// Mirrors the pattern in RouteApiConstants so every URL lives in one place
// and is never scattered across datasource files.

class ForgotPasswordApiConstants {
  ForgotPasswordApiConstants._();

  /// POST  /api/auth/forgot-password
  static const String forgotPassword = '/auth/forgot-password';

  /// POST  /api/auth/verify-otp
  static const String verifyOtp = '/auth/verify-reset-otp';

  /// POST  /api/auth/reset-password
  static const String resetPassword = '/auth/reset-password';
}