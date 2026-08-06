import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────
//  Login State
// ─────────────────────────────────────────────────────────────

enum LoginStatus { idle, loading, success, error }

class LoginState {
  const LoginState({
    this.username = '',
    this.password = '',
    this.status = LoginStatus.idle,
    this.errorMessage,
  });

  final String username;
  final String password;
  final LoginStatus status;
  final String? errorMessage;

  bool get isLoading => status == LoginStatus.loading;
  bool get hasError => status == LoginStatus.error;
  bool get isSuccess => status == LoginStatus.success;

  bool get isValid =>
      username.trim().isNotEmpty && password.isNotEmpty;

  LoginState copyWith({
    String? username,
    String? password,
    LoginStatus? status,
    String? errorMessage,
  }) {
    return LoginState(
      username: username ?? this.username,
      password: password ?? this.password,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Login Notifier
// ─────────────────────────────────────────────────────────────

class LoginNotifier extends StateNotifier<LoginState> {
  LoginNotifier() : super(const LoginState());

  void onUsernameChanged(String value) {
    state = state.copyWith(
      username: value,
      status: LoginStatus.idle,
      errorMessage: null,
    );
  }

  void onPasswordChanged(String value) {
    state = state.copyWith(
      password: value,
      status: LoginStatus.idle,
      errorMessage: null,
    );
  }

  Future<void> login() async {

    if (state.username.trim().isEmpty) {
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: 'Please enter your username.',
      );
      return;
    }
    if (state.password.isEmpty) {
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: 'Please enter your password.',
      );
      return;
    }

    state = state.copyWith(status: LoginStatus.loading);

    try {
      await Future.delayed(const Duration(seconds: 2));

      state = state.copyWith(status: LoginStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: 'Invalid username or password.',
      );
    }
  }

  void reset() {
    state = const LoginState();
  }
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

final loginProvider =
StateNotifierProvider.autoDispose<LoginNotifier, LoginState>(
      (ref) => LoginNotifier(),
);