// ============================================================================
// lib/service/background_location_service.dart
//
// Keeps posting the driver's GPS location to the backend while the app is
// backgrounded on Android during an active navigation session.
//
// Android suspends/kills the main Flutter engine's Dart isolate once the
// Activity is backgrounded, regardless of any stream/timer running inside
// it — the only way to survive that is a genuine Android foreground Service
// running a SEPARATE Flutter engine, which is what flutter_foreground_task
// provides via its TaskHandler (this is also geolocator's own documented
// recommendation for background-after-kill tracking).
//
// iOS doesn't need this: given "Always" permission + UIBackgroundModes:
// location, LocationService.liveLocationStream()'s AppleSettings keeps the
// app's own isolate alive in the background, so iOS syncs location straight
// from NavigationNotifier instead of through a second engine. start()/stop()
// below are no-ops on iOS.
// ============================================================================

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../features/today_route/model/location_sync_model.dart';
import '../uttils/RouteApiConstants.dart';
import '../uttils/app_constants.dart';

const _kSyncInterval = Duration(minutes: 1);

// ── Task handler — runs in its own isolate/Flutter engine ──────────────────

/// Top-level entry point required by flutter_foreground_task; registers the
/// handler that actually does the periodic GPS read + POST.
@pragma('vm:entry-point')
void startLocationTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_LocationTaskHandler());
}

class _LocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _syncNow();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _syncNow();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  /// This isolate has no Riverpod ProviderContainer of its own, so it reads
  /// the auth token and posts the request directly, mirroring
  /// LocationSyncRepository.syncOnce() rather than reusing it.
  Future<void> _syncNow() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      print('[BackgroundLocation] ${DateTime.now()} lat: ${position.latitude}, lng: ${position.longitude}');

      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      final token = await storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) return;

      final request = LocationSyncRequest(
        latitude: position.latitude,
        longitude: position.longitude,
        speedKph: (position.speed < 0 ? 0.0 : position.speed) * 3.6,
        heading: position.heading < 0 ? 0.0 : position.heading,
      );

      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));
      await dio.patch(RouteApiConstants.driverLocation, data: request.toJson());
    } catch (_) {
      // Silent failure — next interval will retry.
    }
  }
}

// ── Main-isolate control surface ────────────────────────────────────────────

class BackgroundLocationService {
  bool _initialized = false;

  /// One-time setup. Safe to call multiple times. Must run before [start].
  void initialize() {
    if (_initialized || !Platform.isAndroid) return;
    _initialized = true;

    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'driver_location_tracking',
        channelName: 'Live Delivery Tracking',
        channelDescription:
            'Keeps sharing your location with dispatch while you are navigating.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction:
            ForegroundTaskEventAction.repeat(_kSyncInterval.inMilliseconds),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Starts the persistent foreground-service location sync (Android only —
  /// no-op elsewhere; see [LocationService.liveLocationStream] for iOS).
  /// Returns whether the service actually started.
  Future<bool> start() async {
    if (!Platform.isAndroid) return false;
    initialize();

    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.restartService();
      return result is ServiceRequestSuccess;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 5000,
      notificationTitle: 'Delivery in progress',
      notificationText: 'Sharing your location with dispatch',
      callback: startLocationTaskCallback,
    );
    return result is ServiceRequestSuccess;
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

final backgroundLocationServiceProvider =
    Provider<BackgroundLocationService>((ref) => BackgroundLocationService());
