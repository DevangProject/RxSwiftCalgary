// lib/features/forgot_password/data/forgot_password_repository.dart
//
// Thin pass-through layer between the notifier and the datasource.
// Mirrors RouteRepository exactly — exists so:
//   • The notifier never imports Dio/ApiResult plumbing directly.
//   • Swapping the datasource (e.g. a fake in tests) is one provider
//     override away.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../model/forgot_password_models.dart';
import 'forgot_password_remote_datasource.dart';

class ForgotPasswordRepository {
  ForgotPasswordRepository(this._datasource);
  final ForgotPasswordRemoteDatasource _datasource;

  Future<ApiResult<bool>> sendOtp(ForgotPasswordRequest request) =>
      _datasource.sendOtp(request);

  Future<ApiResult<bool>> verifyOtp(VerifyOtpRequest request) =>
      _datasource.verifyOtp(request);

  Future<ApiResult<bool>> resetPassword(ResetPasswordRequest request) =>
      _datasource.resetPassword(request);
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

final forgotPasswordRepositoryProvider = Provider<ForgotPasswordRepository>(
      (ref) => ForgotPasswordRepository(
    ref.watch(forgotPasswordRemoteDatasourceProvider),
  ),
);