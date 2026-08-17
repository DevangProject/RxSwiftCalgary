// ============================================================================
// lib/service/notification_service.dart
//
// Firebase Cloud Messaging integration.
//
//  • Foreground: FCM does not surface a tray notification by itself, so we
//    render one manually via flutter_local_notifications.
//  • Background/terminated: the OS renders the tray notification straight
//    from the payload's `notification` block (see the
//    com.google.firebase.messaging.default_notification_* meta-data in
//    AndroidManifest.xml) — firebaseMessagingBackgroundHandler only needs to
//    run for silent/data-only messages, so it's a no-op today.
//  • Tapping a notification just brings the app to the foreground (default
//    OS/FCM behavior) — no deep-link navigation is wired up.
// ============================================================================

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/data/fcm_token_remote_datasource.dart';
import '../features/today_route/provider/today_route_provider.dart';

/// Must be a top-level function — it runs in its own isolate when a message
/// arrives while the app is backgrounded/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

const _androidChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Order Notifications',
  description: 'Notifications about new and updated delivery orders.',
  importance: Importance.high,
);

class NotificationService {
  NotificationService(this._tokenDataSource, this._ref);
  final FcmTokenRemoteDataSource _tokenDataSource;
  final Ref _ref;

  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// One-time setup: permissions, local-notification channel, and the
  /// foreground/token-refresh listeners. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
    FirebaseMessaging.instance.onTokenRefresh.listen(_sendTokenSilently);

    // Cold start: app was terminated and opened by tapping a notification.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _refreshTodayRoute();
    });
  }

  void _onForegroundMessage(RemoteMessage message) {
    _showForegroundNotification(message);
    // Any push while the app is in the foreground can mean a new pickup/drop
    // was added to (or removed from) today's route, so pull the latest.
    _refreshTodayRoute();
  }

  void _onMessageOpenedApp(RemoteMessage message) => _refreshTodayRoute();

  /// Re-fetches today's route so a new pickup/drop from a push notification
  /// shows up immediately. No-op while the driver is offline — nothing is
  /// loaded on screen for them to refresh yet.
  void _refreshTodayRoute() {
    final state = _ref.read(todayRouteProvider);
    if (!state.isAvailable || state.isLoading) return;
    _ref.read(todayRouteProvider.notifier).refresh();
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Fetches the current FCM token and registers it with the backend.
  /// Call once after a successful login.
  ///
  /// On iOS, FCM cannot mint a token until Apple has handed us an APNs token.
  /// On a simulator that token can arrive a beat late, so we poll for it
  /// before asking for the FCM token — otherwise getToken() throws
  /// `apns-token-not-set` or returns null.
  Future<void> registerDeviceToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      for (var i = 0; i < 10 && apnsToken == null; i++) {
        await Future.delayed(const Duration(seconds: 1));
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      }
      debugPrint('APNs Token: $apnsToken');
      if (apnsToken == null) {
        debugPrint('No APNs token — cannot fetch FCM token (Intel simulator '
            'or iOS < 16 cannot receive push tokens).');
        return;
      }
    }

    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('FCM Token: $token');
    if (token != null) await _sendTokenSilently(token);
  }

  /// Silent failure mirrors the rest of the app's fire-and-forget sync calls
  /// (e.g. LocationSyncRepository) — a dropped registration just means the
  /// driver misses pushes until the next successful call.
  Future<void> _sendTokenSilently(String token) async {
    try {
      final device = await _readDeviceInfo();
      await _tokenDataSource.registerToken(
        token: token,
        platform: device.platform,
        deviceId: device.id,
        deviceName: device.name,
      );
    } catch (_) {}
  }

  /// Resolves this device's platform, stable id and human-readable name for
  /// the device-token registration payload. Falls back to empty id/name if
  /// the platform plugin can't supply them so registration still proceeds.
  Future<_DeviceInfo> _readDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = await plugin.iosInfo;
      return _DeviceInfo(
        platform: 'ios',
        id: ios.identifierForVendor ?? '',
        name: ios.name,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = await plugin.androidInfo;
      return _DeviceInfo(
        platform: 'android',
        id: android.id,
        name: '${android.manufacturer} ${android.model}'.trim(),
      );
    }
    return _DeviceInfo(
      platform: defaultTargetPlatform.name,
      id: '',
      name: '',
    );
  }
}

class _DeviceInfo {
  const _DeviceInfo({
    required this.platform,
    required this.id,
    required this.name,
  });
  final String platform;
  final String id;
  final String name;
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(fcmTokenRemoteDataSourceProvider), ref),
);
