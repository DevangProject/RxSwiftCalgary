import '../../../../core/network/api_result.dart';
import '../../model/login/login_req_model.dart';
import '../../model/login/login_response_model.dart';

/// Contract for auth operations.
/// The presentation layer depends on this abstraction, not the implementation.
abstract class AuthRepository {
  Future<ApiResult<LoginResponseModel>> login(LoginRequestModel request);
  Future<void> logout();
}