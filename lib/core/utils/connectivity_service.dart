import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class ConnectivityService {
  const ConnectivityService(this._connectivity);
  final Connectivity _connectivity;

  /// Returns `true` if the device has an active network connection.
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Stream of connectivity changes — useful for reactive UI.
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}

// ── Providers ────────────────────────────────────────────────

final connectivityProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(Connectivity());
});

/// Reactive online/offline status. Emits the current state as soon as it's
/// known, then again every time the device's connectivity changes — the
/// single source of truth for any "no internet" UI in the app.
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityProvider);

  Stream<bool> statusStream() async* {
    yield await service.isConnected;
    yield* service.onConnectivityChanged
        .map((results) => results.any((r) => r != ConnectivityResult.none));
  }

  return statusStream().distinct();
});