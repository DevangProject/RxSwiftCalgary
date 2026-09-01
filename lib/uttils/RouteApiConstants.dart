// ============================================================================
// lib/features/today_route/data/route_api_constants.dart
//
// All driver-route endpoints. baseUrl is configured in your DioClient as
// http://103.235.105.96:8086/api so every path here is relative to /api.
// ============================================================================

class RouteApiConstants {
  RouteApiConstants._();

  /// GET — today's route for the logged-in driver.
  /// Adjust to match the actual path your existing getTodayRoute() hits.
  static const String todayRoute = '/driver/today-route';

  /// PATCH — update the driver's current status (e.g. on-route).
  /// Adjust to match the actual path youFr existing updateDriverStatus() hits.
  static const String driverStatus = '/driver/status';

  /// PATCH — pickup a specific order.
  /// Full URL: http://103.235.105.96:8086/api/driver/orders/{orderId}/pickup
  static String pickupOrder(String orderId) => '/driver/orders/$orderId/pickup';

  // ── Delivery-Confirm endpoints ────────────────────────────────────────────

  /// POST  /api/driver/orders/{orderId}/delivery-photo
  /// Content-Type: multipart/form-data   Field: Photo
  static String deliveryPhoto(String orderId) => '/driver/orders/$orderId/delivery-photo';

  // ── Live Location Sync ────────────────────────────────────────────────────

  /// PATCH /api/driver/location
  /// Body: { latitude, longitude, speedKph, heading }
  static const String driverLocation = '/driver/location';


  /// POST /api/driver/orders/{orderId}/fail
  static String failOrder(String orderId) =>
      '/driver/orders/$orderId/fail';


  static const String driverAvailability = '/driver/status';

  // ── Unaccepted orders ──────────────────────────────────────────────────

  /// GET — orders assigned to the driver that are awaiting acceptance.
  /// Full URL: http://103.235.105.96:8086/api/driver/orders/unaccepted
  static const String unacceptedOrders = '/driver/orders/unaccepted';

  /// PATCH — bulk-accept one or more unaccepted orders.
  /// Full URL: http://103.235.105.96:8086/api/driver/orders/accept-bulk
  /// Body: { "orderIds": ["..."] }
  static const String acceptOrdersBulk = '/driver/orders/accept-bulk';

  // ── Driver orders (Upcoming / Completed tabs) ───────────────────────────

  /// GET — every order accepted by the driver, at any stage (pickup through
  /// delivery), not scoped to today's route.
  /// Full URL: http://103.235.105.96:8086/api/driver/orders
  static const String driverOrders = '/driver/orders';

  // ── Order detail ──────────────────────────────────────────────────────

  /// GET — full detail for a single order.
  /// Full URL: http://103.235.105.96:8086/api/driver/orders/{orderId}
  static String orderDetail(String orderId) => '/driver/orders/$orderId';

  // ── Push notifications ────────────────────────────────────────────────

  /// POST — register/update the driver's FCM device token.
  /// Full URL: http://103.235.105.96:8086/api/driver/fcm-token
  /// Body: { "fcmToken": "..." }
  static const String fcmToken = '/driver/fcm-token';

  /// POST — register the driver's push device token with the backend.
  /// Full URL: http://103.235.105.96:8086/api/device-tokens/register
  /// Body: { "token", "platform", "deviceId", "deviceName" }
  static const String deviceTokenRegister = '/device-tokens/register';

}