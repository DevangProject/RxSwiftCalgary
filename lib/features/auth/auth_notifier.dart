import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────
//  Login State
// ─────────────────────────────────────────────────────────────

class LoginState {
  const LoginState({
    this.username = '',
    this.password = '',
    this.isLoading = false,
    this.isSuccess = false,
    this.hasError = false,
    this.errorMessage,
  });

  final String username;
  final String password;
  final bool isLoading;
  final bool isSuccess;
  final bool hasError;
  final String? errorMessage;

  LoginState copyWith({
    String? username,
    String? password,
    bool? isLoading,
    bool? isSuccess,
    bool? hasError,
    String? errorMessage,
  }) {
    return LoginState(
      username: username ?? this.username,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage,
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
      hasError: false,
      errorMessage: null,
    );
  }

  void onPasswordChanged(String value) {
    state = state.copyWith(
      password: value,
      hasError: false,
      errorMessage: null,
    );
  }

  Future<void> login() async {
    final username = state.username;
    final password = state.password;
    // Basic validation
    if (username.trim().isEmpty) {
      state = state.copyWith(
        hasError: true,
        errorMessage: 'Please enter your username.',
      );
      return;
    }
    if (password.isEmpty) {
      state = state.copyWith(
        hasError: true,
        errorMessage: 'Please enter your password.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, hasError: false);

    try {
      await Future.delayed(const Duration(seconds: 1));

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
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

final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>(
      (ref) => LoginNotifier(),
);