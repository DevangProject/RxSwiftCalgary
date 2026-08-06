import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_result.dart';
import '../../../../core/network/dio_client.dart';
import '../../model/login/login_req_model.dart';
import '../../model/login/login_response_model.dart';
import '../../uttils/app_constants.dart';


/// Responsible ONLY for HTTP calls related to Auth.
/// Has no business logic — that belongs in the repository.
class AuthRemoteDatasource {
  const AuthRemoteDatasource(this._dioClient);
  final DioClient _dioClient;

  Future<ApiResult<LoginResponseModel>> login(LoginRequestModel request) {
    return _dioClient.post<LoginResponseModel>(
      ApiConstants.login,
      data: request.toJson(),
      fromJson: (json) =>
          LoginResponseModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// The API's LogoutRequestDto requires a non-empty `refreshToken` so it
  /// can revoke that specific token server-side.
  Future<ApiResult<void>> logout({required String refreshToken}) {
    return _dioClient.post<void>(
      ApiConstants.logout,
      data: {'refreshToken': refreshToken},
      fromJson: (_) {},
    );
  }
}

// ── Provider ──────────────────────────────────────────────────

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(ref.watch(dioClientProvider));
});