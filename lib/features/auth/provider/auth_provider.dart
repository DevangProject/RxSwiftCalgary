import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/auth_repository.dart';
import '../../../core/network/auth_repository_impl.dart';
import '../../../core/network/network_exception.dart';
import '../../../model/login/login_req_model.dart';
import '../../../model/login/login_response_model.dart';


// ── State ─────────────────────────────────────────────────────

enum AuthStatus { initial, loading, success, error, noInternet }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.loginResponse,
    this.errorMessage,
  });

  final AuthStatus status;
  final LoginResponseModel? loginResponse;
  final String? errorMessage;

  bool get isLoading    => status == AuthStatus.loading;
  bool get isSuccess    => status == AuthStatus.success;
  bool get isError      => status == AuthStatus.error;
  bool get isNoInternet => status == AuthStatus.noInternet;

  AuthState copyWith({
    AuthStatus? status,
    LoginResponseModel? loginResponse,
    String? errorMessage,
  }) {
    return AuthState(
      status:        status        ?? this.status,
      loginResponse: loginResponse ?? this.loginResponse,
      errorMessage:  errorMessage,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository) : super(const AuthState());

  final AuthRepository _repository;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    final request = LoginRequestModel(email: email, password: password);
    final result  = await _repository.login(request);

    result.when(
      success: (data) {
        state = state.copyWith(
          status:        AuthStatus.success,
          loginResponse: data,
          errorMessage:  null,
        );
      },
      failure: (exception) {
        final isNoInternet = exception is NoInternetException;
        state = state.copyWith(
          status:       isNoInternet ? AuthStatus.noInternet : AuthStatus.error,
          errorMessage: exception.message,
        );
      },
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }

  void reset() => state = const AuthState();
}

// ── Provider ──────────────────────────────────────────────────
final authProvider =
StateNotifierProvider.autoDispose<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});