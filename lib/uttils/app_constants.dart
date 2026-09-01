/// Central place for all API-related constants.
/// Add new endpoint strings here — never hardcode URLs in datasources.
class ApiConstants {
  ApiConstants._();

  // ── Base ────────────────────────────────────────────────────
  static const String baseUrl = 'https://api.rxswift.ca/api';

  // ── Media ───────────────────────────────────────────────────
  // Root the API serves uploaded files (pickup/delivery photos) from.
  // `baseUrl` can't be reused directly since it carries the `/api` suffix.
  static const String imageBaseUrl = 'https://api.rxswift.ca';

  /// Prefixes a relative image path (e.g. "/uploads/pickup/xxx.jpg") returned
  /// by the API with [imageBaseUrl]. Already-absolute URLs pass through
  /// unchanged so this stays safe if the backend switches to full URLs later.
  static String? resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$imageBaseUrl${path.startsWith('/') ? path : '/$path'}';
  }

  // ── Timeouts ────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout    = Duration(seconds: 30);

  // ── Auth ────────────────────────────────────────────────────
  static const String login = '/Auth/login';
  static const String logout = '/Auth/logout';
  static const String refreshToken = '/Auth/refresh';

// ── Add future endpoints below ───────────────────────────────
// static const String profile  = '/User/profile';
// static const String routes   = '/Route/list';

  // Driver Update Status
  static const String driverActiveStatus = '1';
  static const String driverOnRouteStatus = '2';
  static const String driverOfflineStatus = '3';
  static const String driverInActiveStatus = '4';
}