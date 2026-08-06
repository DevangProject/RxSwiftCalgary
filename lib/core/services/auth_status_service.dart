import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/token_storage.dart';

/// Thin abstraction the presentation layer uses to ask "is a user already
/// logged in?" without reaching into [TokenStorage] internals directly.
///
/// Keeping this as its own service (rather than calling [TokenStorage]
/// straight from a widget) is what lets the splash flow stay decoupled
/// from how "logged in" is actually determined.
class AuthStatusService {
  AuthStatusService(this._tokenStorage);

  final TokenStorage _tokenStorage;

  /// Resolves to `true` when a persisted auth token exists.
  Future<bool> isLoggedIn() => _tokenStorage.hasToken;
}

// ── Provider ──────────────────────────────────────────────────

final authStatusServiceProvider = Provider<AuthStatusService>((ref) {
  return AuthStatusService(ref.watch(tokenStorageProvider));
});
