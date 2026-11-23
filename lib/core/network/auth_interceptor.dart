import 'package:dio/dio.dart';

import '../../uttils/app_constants.dart';
import '../utils/token_storage.dart';

/// Keeps the driver signed in for as long as the app is in use.
///
/// - Attaches the access token to every request.
/// - Refreshes it via `/Auth/refresh` *before* a request when the stored
///   expiry has passed, and again whenever the API answers 401 — then
///   retries the original request with the new token.
///
/// A [QueuedInterceptor] processes requests one at a time, so concurrent
/// calls that all hit an expired token trigger a single refresh, not one each.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required TokenStorage tokenStorage, required Dio dio})
      : _tokenStorage = tokenStorage,
        _dio = dio;

  final TokenStorage _tokenStorage;

  /// The main Dio, used to replay the failed request.
  final Dio _dio;

  /// Bare Dio for the refresh call itself, so it never re-enters this
  /// interceptor.
  late final Dio _refreshDio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ),
  );

  static const _retriedKey = 'auth_retried';

  static const _publicPaths = {
    ApiConstants.login,
    ApiConstants.logout,
    ApiConstants.refreshToken,
  };

  bool _isPublic(RequestOptions options) =>
      _publicPaths.any((p) => options.path.endsWith(p));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options) && await _tokenStorage.isAccessTokenExpired) {
      await _refresh();
    }
    final token = await _tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isUnauthorised = err.response?.statusCode == 401;

    if (!isUnauthorised ||
        _isPublic(options) ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    // Another queued request may already have refreshed the token while this
    // one was in flight — only hit /Auth/refresh if it's still the old one.
    final sentToken = (options.headers['Authorization'] as String?)
        ?.replaceFirst('Bearer ', '');
    final currentToken = await _tokenStorage.readToken();
    final refreshed = (currentToken != null && currentToken != sentToken) ||
        await _refresh();
    if (!refreshed) return handler.next(err);

    try {
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] =
          'Bearer ${await _tokenStorage.readToken()}';
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Exchanges the stored refresh token for a new token pair.
  /// Returns false when there's no refresh token or the server rejects it —
  /// the caller then surfaces the original 401 (→ "Session expired").
  Future<bool> _refresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _refreshDio.post<dynamic>(
        ApiConstants.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      final body = response.data;
      if (body is! Map<String, dynamic> || body['success'] == false) {
        return false;
      }
      final data = body['data'] is Map<String, dynamic>
          ? body['data'] as Map<String, dynamic>
          : body;

      final accessToken = data['accessToken'] as String?;
      if (accessToken == null || accessToken.isEmpty) return false;
      await _tokenStorage.saveToken(accessToken);

      final newRefresh = data['refreshToken'] as String?;
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await _tokenStorage.saveRefreshToken(newRefresh);
      }
      final accessExpiry =
          DateTime.tryParse(data['accessTokenExpiresAt'] as String? ?? '');
      if (accessExpiry != null) {
        await _tokenStorage.saveAccessTokenExpiry(accessExpiry);
      }
      final refreshExpiry =
          DateTime.tryParse(data['refreshTokenExpiresAt'] as String? ?? '');
      if (refreshExpiry != null) {
        await _tokenStorage.saveRefreshTokenExpiry(refreshExpiry);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
