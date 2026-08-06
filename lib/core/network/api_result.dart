

import 'package:rxswift/core/network/network_exception.dart';

sealed class ApiResult<T> {
  const ApiResult();
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data);
  final T data;
}

final class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure(this.exception);
  final NetworkException exception;
}

// ── Convenience extension ────────────────────────────────────

extension ApiResultX<T> on ApiResult<T> {
  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailure<T>;

  T? get dataOrNull =>
      isSuccess ? (this as ApiSuccess<T>).data : null;

  NetworkException? get exceptionOrNull =>
      isFailure ? (this as ApiFailure<T>).exception : null;

  R when<R>({
    required R Function(T data) success,
    required R Function(NetworkException exception) failure,
  }) {
    return switch (this) {
      ApiSuccess<T> s => success(s.data),
      ApiFailure<T> f => failure(f.exception),
    };
  }

  /// Maps the success value, leaving failures untouched.
  ApiResult<R> map<R>(R Function(T) transform) => switch (this) {
    ApiSuccess<T> s => ApiSuccess(transform(s.data)),
    ApiFailure<T> f => ApiFailure<R>(f.exception),
  };
}