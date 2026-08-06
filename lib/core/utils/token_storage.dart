import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles secure persistence of the JWT access token, refresh token, and
/// their expiries.
///
/// Uses [FlutterSecureStorage] (AES-256 on Android, Keychain on iOS).
/// For anything less sensitive (e.g. user prefs) use shared_preferences instead.
class TokenStorage {
  TokenStorage(this._storage);
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _accessExpiryKey = 'access_token_expires_at';
  static const _refreshExpiryKey = 'refresh_token_expires_at';
  static const _userIdKey = 'user_id';

  // ── Access token ─────────────────────────────────────────────

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<bool> get hasToken async {
    final t = await readToken();
    return t != null && t.isNotEmpty;
  }

  // ── Refresh token ────────────────────────────────────────────

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> deleteRefreshToken() => _storage.delete(key: _refreshTokenKey);

  // ── Expiries (optional, for proactive refresh) ───────────────

  Future<void> saveAccessTokenExpiry(DateTime expiry) => _storage.write(
    key: _accessExpiryKey,
    value: expiry.toIso8601String(),
  );

  Future<DateTime?> readAccessTokenExpiry() async {
    final raw = await _storage.read(key: _accessExpiryKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveRefreshTokenExpiry(DateTime expiry) => _storage.write(
    key: _refreshExpiryKey,
    value: expiry.toIso8601String(),
  );

  Future<DateTime?> readRefreshTokenExpiry() async {
    final raw = await _storage.read(key: _refreshExpiryKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// True when an access token exists but its stored expiry is in the past.
  /// Returns false if no expiry was stored (can't determine staleness).
  Future<bool> get isAccessTokenExpired async {
    final expiry = await readAccessTokenExpiry();
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  // ── User ID (convenience) ────────────────────────────────────

  Future<void> saveUserId(String id) =>
      _storage.write(key: _userIdKey, value: id);

  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  // ── Clear all (logout) ───────────────────────────────────────

  Future<void> clearAll() => _storage.deleteAll();
}

// ── Provider ──────────────────────────────────────────────────

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return TokenStorage(storage);
});
