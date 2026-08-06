import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_result.dart';
import '../../model/login/login_req_model.dart';
import '../../model/login/login_response_model.dart';
import '../utils/token_storage.dart';
import 'auth_repository.dart';
import 'auth_repository_datasource.dart';

/// Concrete implementation of [AuthRepository].
///
/// Responsibilities:
///  1. Delegate HTTP to the datasource.
///  2. On success, persist tokens + user id via [TokenStorage].
///  3. Return the result unchanged to the caller.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDatasource datasource,
    required TokenStorage tokenStorage,
  })  : _datasource = datasource,
        _tokenStorage = tokenStorage;

  final AuthRemoteDatasource _datasource;
  final TokenStorage _tokenStorage;

  @override
  Future<ApiResult<LoginResponseModel>> login(LoginRequestModel request) async {
    final result = await _datasource.login(request);

    // DioClient already unwrapped the envelope, so `data` is the flattened
    // LoginResponseModel with tokens directly on it.
    if (result case ApiSuccess(:final data)) {
      await _tokenStorage.saveToken(data.accessToken);
      await _tokenStorage.saveRefreshToken(data.refreshToken);
      await _tokenStorage.saveAccessTokenExpiry(data.accessTokenExpiresAt);
      await _tokenStorage.saveRefreshTokenExpiry(data.refreshTokenExpiresAt);
      await _tokenStorage.saveUserId(data.user.id);
    }

    return result;
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _datasource.logout(refreshToken: refreshToken);
    }
    await _tokenStorage.clearAll();
  }
}

// ── Provider ──────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    datasource: ref.watch(authRemoteDatasourceProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});
