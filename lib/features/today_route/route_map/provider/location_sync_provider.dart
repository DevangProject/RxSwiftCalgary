// ============================================================================
// lib/features/today_route/route_map/provider/location_sync_provider.dart
//
// Sends driver location to server API every 1 minute.
//
// KEY FIX: Provider is NOT autoDispose — the timer must survive for the full
// lifetime of the screen. autoDispose would kill the provider (and its timer)
// the moment nothing is actively watching it, which is immediately after
// ref.read() in _startTracking().
//
// Lifecycle is manually controlled:
//   • screen calls .start()  in _startTracking()
//   • screen calls .stop()   in dispose()
// ============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location_sync_remote_datasource.dart';
import '../repository/location_sync_repository.dart';
import 'driver_location_provider.dart';

const _kSyncInterval = Duration(minutes: 1);

// ── Repository provider ───────────────────────────────────────────────────

final locationSyncRepositoryProvider = Provider<LocationSyncRepository>(
      (ref) => LocationSyncRepository(
    ref.watch(locationSyncRemoteDataSourceProvider),
  ),
);

// ── Notifier ──────────────────────────────────────────────────────────────

class LocationSyncNotifier extends StateNotifier<void> {
  LocationSyncNotifier(this._repo) : super(null);

  final LocationSyncRepository _repo;
  Timer? _timer;
  DriverPosition? _latestPosition;

  /// Feed the latest GPS fix in from route_map_screen via listenManual.
  void updateLatestPosition(DriverPosition pos) {
    _latestPosition = pos;
  }

  /// Start 1-min periodic sync. Safe to call multiple times.
  void start() {
    stop(); // cancel any existing timer first
    _syncNow(); // fire immediately on start so first sync doesn't wait 1 min
    _timer = Timer.periodic(_kSyncInterval, (_) => _syncNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _syncNow() {
    final pos = _latestPosition;
    if (pos != null) {
      _repo.syncWithPosition(pos); // fire-and-forget, errors swallowed
    } else {
      _repo.syncOnce(); // fallback: reads GPS directly if no fix yet
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────
// NOT autoDispose — must stay alive for the full screen lifetime.
// The screen calls .stop() in its dispose() to clean up the timer.

final locationSyncProvider =
StateNotifierProvider<LocationSyncNotifier, void>(
      (ref) => LocationSyncNotifier(ref.watch(locationSyncRepositoryProvider)),
);