import 'package:dio/dio.dart';

/// Converts raw Dio / socket errors into user-friendly messages.
/// Extend the [NetworkException] sealed class to add new error categories.
sealed class NetworkException implements Exception {
  const NetworkException(this.message);
  final String message;

  @override
  String toString() => message;
}

class NoInternetException extends NetworkException {
  const NoInternetException()
      : super('No internet connection. Please check your network.');
}

class TimeoutException extends NetworkException {
  const TimeoutException()
      : super('Request timed out. Please try again.');
}

class UnauthorisedException extends NetworkException {
  const UnauthorisedException()
      : super('Session expired. Please log in again.');
}

class ForbiddenException extends NetworkException {
  const ForbiddenException()
      : super('You do not have permission to perform this action.');
}

class NotFoundException extends NetworkException {
  const NotFoundException()
      : super('The requested resource was not found.');
}

class BadRequestException extends NetworkException {
  const BadRequestException([String? detail])
      : super(detail ?? 'Invalid request. Please check your input.');
}

class ServerException extends NetworkException {
  // Optional [detail] lets callers surface the server's own message
  // (e.g. "Invalid credentials") instead of the generic fallback.
  const ServerException([String? detail])
      : super(detail ?? 'Server error. Please try again later.');
}

class UnknownException extends NetworkException {
  const UnknownException([String? detail])
      : super(detail ?? 'An unexpected error occurred.');
}

/// Factory — call this with any caught error to get a [NetworkException].
NetworkException networkExceptionFromError(Object error) {
  if (error is NetworkException) return error;

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();

      case DioExceptionType.connectionError:
        return const NoInternetException();

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final serverMsg  = _extractServerMessage(error.response);

        return switch (statusCode) {
          400 => BadRequestException(serverMsg),
          401 => const UnauthorisedException(),
          403 => const ForbiddenException(),
          404 => const NotFoundException(),
          500 => ServerException(serverMsg),
          _   => UnknownException(serverMsg),
        };

      default:
        return UnknownException(error.message);
    }
  }

  return UnknownException(error.toString());
}

String? _extractServerMessage(Response? response) {
  try {
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      return (data['message'] as String?) ??
          (data['errors']?.toString());
    }
  } catch (_) {}
  return null;
}

