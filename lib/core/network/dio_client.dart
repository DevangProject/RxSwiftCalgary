import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../uttils/app_constants.dart';
import '../utils/connectivity_service.dart';
import '../utils/token_storage.dart';
import 'api_result.dart';
import 'network_exception.dart';


/// Central Dio instance — single source of truth for HTTP in the app.
///
/// Every feature's remote datasource receives this via Riverpod injection.
/// Do NOT create a bare [Dio] anywhere else in the app.
class DioClient {
  DioClient({
    required Dio dio,
    required TokenStorage tokenStorage,
    required ConnectivityService connectivity,
  })  : _dio = dio,
        _tokenStorage = tokenStorage,
        _connectivity = connectivity {
    _setupInterceptors();
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final ConnectivityService _connectivity;

  // ── Interceptor setup ──────────────────────────────────────

  void _setupInterceptors() {
    _dio.options = BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    );

    // Auth token injection
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) => handler.next(response),
        onError: (error, handler) => handler.next(error),
      ),
    );

    // Pretty logging — debug builds only
    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
        ),
      );
    }
  }

  // ── Connectivity guard ─────────────────────────────────────

  Future<void> _assertConnected() async {
    if (!await _connectivity.isConnected) {
      throw const NoInternetException();
    }
  }

  // ── Public HTTP methods ────────────────────────────────────

  /// Generic GET request.
  Future<ApiResult<T>> get<T>(
      String endpoint, {
        Map<String, dynamic>? queryParameters,
        required T Function(dynamic json) fromJson,
      }) async {
    try {
      await _assertConnected();
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
      );
      return ApiSuccess(fromJson(_extractData(response)));
    } catch (e) {
      return ApiFailure(networkExceptionFromError(e));
    }
  }

  /// Generic POST request.
  Future<ApiResult<T>> post<T>(
      String endpoint, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        required T Function(dynamic json) fromJson,
      }) async {
    try {
      await _assertConnected();
      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );
      return ApiSuccess(fromJson(_extractData(response)));
    } catch (e) {
      return ApiFailure(networkExceptionFromError(e));
    }
  }

  /// Generic PUT request.
  Future<ApiResult<T>> put<T>(
      String endpoint, {
        dynamic data,
        required T Function(dynamic json) fromJson,
      }) async {
    try {
      await _assertConnected();
      final response = await _dio.put(endpoint, data: data);
      return ApiSuccess(fromJson(_extractData(response)));
    } catch (e) {
      return ApiFailure(networkExceptionFromError(e));
    }
  }

  /// Generic DELETE request.
  Future<ApiResult<T>> delete<T>(
      String endpoint, {
        required T Function(dynamic json) fromJson,
      }) async {
    try {
      await _assertConnected();
      final response = await _dio.delete(endpoint);
      return ApiSuccess(fromJson(_extractData(response)));
    } catch (e) {
      return ApiFailure(networkExceptionFromError(e));
    }
  }

  /// Generic PATCH request.
  Future<ApiResult<T>> patch<T>(
      String endpoint, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        required T Function(dynamic json) fromJson,
      }) async {
    try {
      await _assertConnected();
      final response = await _dio.patch(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );
      return ApiSuccess(fromJson(_extractData(response)));
    } catch (e) {
      return ApiFailure(networkExceptionFromError(e));
    }
  }

  // ── Response envelope unwrapper ────────────────────────────
  dynamic _extractData(Response response) {
    final body = response.data;

    if (body is Map<String, dynamic>) {
      // ── Server-side failure returned with HTTP 200 ─────────
      if (body['success'] == false) {
        final message = (body['message'] as String?)?.trim();
        throw ServerException(
          message?.isNotEmpty == true
              ? message
              : 'Something went wrong. Please try again.',
        );
      }

      // ── Happy path — unwrap the data envelope ──────────────
      if (body.containsKey('data')) {
        return body['data'];
      }
    }

    // Defensive fallback for non-enveloped responses.
    return body;
  }
}

// ── Provider ──────────────────────────────────────────────────

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    dio: Dio(),
    tokenStorage: ref.watch(tokenStorageProvider),
    connectivity: ref.watch(connectivityProvider),
  );
});