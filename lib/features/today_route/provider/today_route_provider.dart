import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/network_exception.dart';
import '../../../uttils/app_constants.dart';
import '../data/route_remote_datasource.dart';
import '../data/route_repository.dart';
import '../model/route_model.dart';
import 'route_location_service.dart';

// ─────────────────────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────────────────────

enum RouteLoadStatus { idle, loading, loaded, error }

enum RouteStartStatus { idle, starting, active, completed }

enum DriverOrdersLoadStatus { idle, loading, loaded, error }

/// State of the "usable current location" gate that sits in front of the
/// today-routeV2 call. `none` means the gate isn't currently blocking —
/// either it hasn't run yet or it already resolved (successfully or into a
/// plain API [RouteLoadStatus.error]). While any other value is set,
/// [RouteLoadStatus] is held at `loading` and the screen shows the matching
/// recovery UI instead of route content.
enum LocationGateStatus {
  none,
  checking,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  obtaining,
  failed,
}

class TodayRouteState {
  const TodayRouteState({
    // ── availability ──
    this.isAvailable = false,
    this.isAvailabilityUpdating = false,
    this.availabilityErrorMessage,
    this.isSessionExpired = false,
    // ── route load ──
    this.loadStatus = RouteLoadStatus.idle,
    this.locationGateStatus = LocationGateStatus.none,
    this.startStatus = RouteStartStatus.idle,
    this.route,
    this.errorMessage,
    // ── pickup ──
    this.isPickupLoading = false,
    this.activePickupOrderId,
    this.pickupErrorMessage,
    // ── unaccepted orders ──
    this.unacceptedOrders = const [],
    this.isAccepting = false,
    this.acceptErrorMessage,
    // ── driver orders (Upcoming / Completed tabs) ──
    this.driverOrders = const [],
    this.driverOrdersLoadStatus = DriverOrdersLoadStatus.idle,
    this.driverOrdersErrorMessage,
  });

  // ── Availability ─────────────────────────────────────────
  /// Whether the driver has toggled themselves as available.
  final bool isAvailable;

  /// True while the availability PATCH call is in flight.
  final bool isAvailabilityUpdating;

  /// Set when the availability API call fails; cleared on next attempt.
  final String? availabilityErrorMessage;

  /// Set when any call in this flow comes back 401 / "session expired".
  /// The screen watches this and force-logs the driver out.
  final bool isSessionExpired;

  // ── Route load ───────────────────────────────────────────
  final RouteLoadStatus loadStatus;

  /// Status of the current-location gate that runs before today-routeV2.
  /// See [LocationGateStatus] for what each value means for the UI.
  final LocationGateStatus locationGateStatus;
  final RouteStartStatus startStatus;
  final TodayRoute? route;
  final String? errorMessage;

  // ── Pickup ───────────────────────────────────────────────
  /// True while a pickup API call is in flight.
  final bool isPickupLoading;

  /// The orderId currently being picked up. Lets the UI disable only the
  /// matching stop's button rather than every Pickup button.
  final String? activePickupOrderId;

  /// Last pickup error message, surfaced to the screen as a SnackBar.
  final String? pickupErrorMessage;

  // ── Unaccepted orders ─────────────────────────────────────
  /// Orders assigned to the driver that are still awaiting acceptance.
  /// When non-empty, the screen shows these instead of today's route.
  final List<UnacceptedOrder> unacceptedOrders;

  /// True while the bulk accept-orders API call is in flight.
  final bool isAccepting;

  /// Last accept-order error message, surfaced to the screen as a SnackBar.
  final String? acceptErrorMessage;

  // ── Driver orders (Upcoming / Completed tabs) ─────────────
  /// Every order accepted by the driver (any stage), from GET /driver/orders.
  /// Fetched lazily the first time the Upcoming/Completed tabs are opened.
  final List<DriverOrder> driverOrders;
  final DriverOrdersLoadStatus driverOrdersLoadStatus;
  final String? driverOrdersErrorMessage;

  // ── Convenience getters ──────────────────────────────────
  bool get isLoading => loadStatus == RouteLoadStatus.loading;
  bool get isLoaded => loadStatus == RouteLoadStatus.loaded;
  bool get isError => loadStatus == RouteLoadStatus.error;

  // ── Location gate convenience getters ─────────────────────
  bool get isCheckingLocation => locationGateStatus == LocationGateStatus.checking;
  bool get isObtainingLocation => locationGateStatus == LocationGateStatus.obtaining;
  bool get needsLocationServiceEnable =>
      locationGateStatus == LocationGateStatus.serviceDisabled;
  bool get needsLocationPermission =>
      locationGateStatus == LocationGateStatus.permissionDenied;
  bool get needsLocationPermissionForever =>
      locationGateStatus == LocationGateStatus.permissionDeniedForever;
  bool get isLocationFetchFailed => locationGateStatus == LocationGateStatus.failed;
  bool get isLocationGateBlocking => locationGateStatus != LocationGateStatus.none;
  bool get isRouteActive => startStatus == RouteStartStatus.active;
  bool get isRouteCompleted => startStatus == RouteStartStatus.completed;
  bool get hasUnacceptedOrders => unacceptedOrders.isNotEmpty;

  int get completedStops =>
      route?.stops.where((s) => s.status == StopStatus.completed).length ?? 0;

  bool get isDriverOrdersLoading =>
      driverOrdersLoadStatus == DriverOrdersLoadStatus.loading;
  bool get isDriverOrdersError =>
      driverOrdersLoadStatus == DriverOrdersLoadStatus.error;

  /// Orders not yet delivered/failed — still active work for the driver.
  List<DriverOrder> get upcomingDriverOrders =>
      driverOrders.where((o) => !o.isCompleted).toList();

  /// Orders that reached a terminal state (delivered/failed).
  List<DriverOrder> get completedDriverOrders =>
      driverOrders.where((o) => o.isCompleted).toList();

  TodayRouteState copyWith({
    // availability
    bool? isAvailable,
    bool? isAvailabilityUpdating,
    String? availabilityErrorMessage,
    bool clearAvailabilityError = false,
    bool? isSessionExpired,
    // route load
    RouteLoadStatus? loadStatus,
    LocationGateStatus? locationGateStatus,
    RouteStartStatus? startStatus,
    TodayRoute? route,
    bool clearRoute = false,
    String? errorMessage,
    bool clearError = false,
    // pickup
    bool? isPickupLoading,
    String? activePickupOrderId,
    bool clearActivePickup = false,
    String? pickupErrorMessage,
    bool clearPickupError = false,
    // unaccepted orders
    List<UnacceptedOrder>? unacceptedOrders,
    bool? isAccepting,
    String? acceptErrorMessage,
    bool clearAcceptError = false,
    // driver orders
    List<DriverOrder>? driverOrders,
    DriverOrdersLoadStatus? driverOrdersLoadStatus,
    String? driverOrdersErrorMessage,
    bool clearDriverOrdersError = false,
  }) {
    return TodayRouteState(
      isAvailable: isAvailable ?? this.isAvailable,
      isAvailabilityUpdating:
      isAvailabilityUpdating ?? this.isAvailabilityUpdating,
      availabilityErrorMessage: clearAvailabilityError
          ? null
          : (availabilityErrorMessage ?? this.availabilityErrorMessage),
      isSessionExpired: isSessionExpired ?? this.isSessionExpired,
      loadStatus: loadStatus ?? this.loadStatus,
      locationGateStatus: locationGateStatus ?? this.locationGateStatus,
      startStatus: startStatus ?? this.startStatus,
      route: clearRoute ? null : (route ?? this.route),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isPickupLoading: isPickupLoading ?? this.isPickupLoading,
      activePickupOrderId: clearActivePickup
          ? null
          : (activePickupOrderId ?? this.activePickupOrderId),
      pickupErrorMessage: clearPickupError
          ? null
          : (pickupErrorMessage ?? this.pickupErrorMessage),
      unacceptedOrders: unacceptedOrders ?? this.unacceptedOrders,
      isAccepting: isAccepting ?? this.isAccepting,
      acceptErrorMessage: clearAcceptError
          ? null
          : (acceptErrorMessage ?? this.acceptErrorMessage),
      driverOrders: driverOrders ?? this.driverOrders,
      driverOrdersLoadStatus:
          driverOrdersLoadStatus ?? this.driverOrdersLoadStatus,
      driverOrdersErrorMessage: clearDriverOrdersError
          ? null
          : (driverOrdersErrorMessage ?? this.driverOrdersErrorMessage),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────────────────────

class TodayRouteNotifier extends StateNotifier<TodayRouteState> {
  TodayRouteNotifier(this._repository, this._locationService)
      : super(const TodayRouteState()) {
    // Route itself is never eagerly loaded here — only once the driver is
    // (or, via _restoreAvailability, was already) available.
    _restoreAvailability();
  }

  final RouteRepository _repository;
  final RouteLocationService _locationService;

  /// Guards the location-gate + today-routeV2 sequence against duplicate
  /// concurrent runs — e.g. a manual "Try Again" tap racing with an
  /// app-resume recheck after the driver returns from Settings.
  bool _isFetchingRoute = false;

  static const _isAvailableKey = 'driver_is_available';

  // ── Availability ──────────────────────────────────────────────────────────

  /// Restores the driver's online/offline toggle from the last session so
  /// they aren't forced to flip it on every time they reopen the app —
  /// mirrors the usual gig-driver-app pattern where "online" persists until
  /// the driver explicitly goes offline or logs out.
  Future<void> _restoreAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    final wasAvailable = prefs.getBool(_isAvailableKey) ?? false;
    if (!wasAvailable) return;

    state = state.copyWith(isAvailable: true);
    await loadRoute();
  }

  Future<void> _persistAvailability(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isAvailableKey, value);
  }

  /// Called when the driver flips the availability switch.
  ///
  /// - Guards against duplicate taps while an update is already in flight.
  /// - On success, loads the route (if turning ON) or clears state (if OFF).
  /// - On failure, reverts the switch and surfaces an error via
  ///   [availabilityErrorMessage].
  Future<void> toggleAvailability(bool newValue) async {
    // Guard: ignore if already updating or if value hasn't changed.
    if (state.isAvailabilityUpdating) return;
    if (state.isAvailable == newValue) return;

    state = state.copyWith(
      isAvailabilityUpdating: true,
      clearAvailabilityError: true,
    );

    final result = await _repository.updateDriverAvailability(
      isAvailable: newValue,
    );

    switch (result) {
      case ApiSuccess():
        await _persistAvailability(newValue);
        if (newValue) {
          // Driver turned ON — persist the new value then fetch route.
          state = state.copyWith(
            isAvailable: true,
            isAvailabilityUpdating: false,
          );
          await loadRoute();
        } else {
          // Driver turned OFF — clear all route + unaccepted-order data.
          state = state.copyWith(
            isAvailable: false,
            isAvailabilityUpdating: false,
            loadStatus: RouteLoadStatus.idle,
            startStatus: RouteStartStatus.idle,
            clearRoute: true,
            clearError: true,
            unacceptedOrders: const [],
            isAccepting: false,
            clearAcceptError: true,
          );
        }

      case ApiFailure(:final exception):
      // Revert — state.isAvailable stays at its previous value.
        state = state.copyWith(
          isAvailabilityUpdating: false,
          availabilityErrorMessage: exception.message,
          isSessionExpired: _isSessionExpired(exception),
        );
    }
  }

  /// A 401 from the API means the access token is dead — the driver has to
  /// sign in again. The server also returns some auth failures as HTTP 200
  /// with `success: false`, which lands here as a [ServerException], so the
  /// message is checked as well.
  bool _isSessionExpired(NetworkException exception) {
    if (exception is UnauthorisedException) return true;
    final msg = exception.message.toLowerCase();
    return msg.contains('session expired') ||
        msg.contains('unauthorized') ||
        msg.contains('unauthorised') ||
        msg.contains('token expired') ||
        msg.contains('invalid token');
  }

  // ── Route loading ─────────────────────────────────────────────────────────

  /// Entry point called whenever the driver becomes available (or retries).
  ///
  /// Checks for unaccepted orders first:
  /// - If any exist, they're shown instead of today's route and the route
  ///   API is skipped until all of them are accepted.
  /// - If none exist, today's route is loaded as before.
  Future<void> loadRoute() async {
    // Safety: never load when the driver is unavailable.
    if (!state.isAvailable) return;

    state = state.copyWith(
      loadStatus: RouteLoadStatus.loading,
      clearError: true,
    );

    final unacceptedResult = await _repository.getUnacceptedOrders();

    switch (unacceptedResult) {
      case ApiSuccess(:final data):
        if (data.isNotEmpty) {
          state = state.copyWith(
            loadStatus: RouteLoadStatus.loaded,
            unacceptedOrders: data,
          );
          return;
        }
        // No unaccepted orders — get a usable location, then fetch the
        // actual route (today-routeV2).
        await _fetchTodayRouteWithLocation();
      case ApiFailure(:final exception):
        state = state.copyWith(
          loadStatus: RouteLoadStatus.error,
          errorMessage: exception.message,
          isSessionExpired: _isSessionExpired(exception),
        );
    }
  }

  // ── Location gate + today-routeV2 ───────────────────────────────────────

  /// Obtains a usable current location (checking service + permission first)
  /// and, on success, calls today-routeV2 with it. Safe to call repeatedly —
  /// re-entrant calls while one is already in flight are ignored, so a
  /// "Try Again" tap or an app-resume recheck can never fire a duplicate
  /// request.
  Future<void> _fetchTodayRouteWithLocation() async {
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;
    try {
      final position = await _ensureLocation();
      if (position == null) return; // state already reflects why we stopped

      state = state.copyWith(
        loadStatus: RouteLoadStatus.loading,
        clearError: true,
      );

      final result = await _repository.getTodayRouteV2(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      switch (result) {
        case ApiSuccess(:final data):
          state = state.copyWith(
            loadStatus: RouteLoadStatus.loaded,
            route: data,
          );
        case ApiFailure(:final exception):
          state = state.copyWith(
            loadStatus: RouteLoadStatus.error,
            errorMessage: exception.message,
            isSessionExpired: _isSessionExpired(exception),
          );
      }
    } finally {
      _isFetchingRoute = false;
    }
  }

  /// Checks device location services + app permission and, once both are
  /// satisfied, returns a fresh GPS fix. Returns null and leaves
  /// [TodayRouteState.locationGateStatus] set to the blocking reason
  /// whenever the driver can't proceed yet — the screen reads that to show
  /// the matching recovery UI (turn on location / try again / open settings)
  /// instead of an infinite spinner.
  Future<Position?> _ensureLocation() async {
    state = state.copyWith(
      locationGateStatus: LocationGateStatus.checking,
      loadStatus: RouteLoadStatus.loading,
      clearError: true,
    );

    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        locationGateStatus: LocationGateStatus.serviceDisabled,
      );
      return null;
    }

    var permission = await _locationService.checkPermission();
    if (permission == LocationPermission.denied) {
      // Not yet granted — ask through the platform's normal permission
      // flow. (The screen shows a brief "why we need this" explanation
      // alongside the checking/obtaining state.)
      permission = await _locationService.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        locationGateStatus: LocationGateStatus.permissionDeniedForever,
      );
      return null;
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      state = state.copyWith(
        locationGateStatus: LocationGateStatus.permissionDenied,
      );
      return null;
    }

    state = state.copyWith(locationGateStatus: LocationGateStatus.obtaining);
    try {
      final position = await _locationService.getCurrentPosition();
      state = state.copyWith(locationGateStatus: LocationGateStatus.none);
      return position;
    } catch (_) {
      state = state.copyWith(
        locationGateStatus: LocationGateStatus.failed,
        errorMessage: 'Could not get your current location. Please try again.',
      );
      return null;
    }
  }

  /// "Try Again" — re-runs the whole location gate from scratch. Also used
  /// to recover from a plain GPS-fetch failure ([LocationGateStatus.failed]).
  Future<void> retryLocationAccess() => _fetchTodayRouteWithLocation();

  /// "Turn on Location" — opens the device's location-services setting.
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  /// "Open App Settings" — for permanently-denied permission.
  Future<void> openAppSettingsForLocation() async {
    await _locationService.openAppSettings();
  }

  /// Called when the app resumes (e.g. the driver comes back from Settings).
  /// Only re-runs the gate when it's actually the thing blocking the
  /// screen — a no-op resume elsewhere in the app never triggers an
  /// unwanted request.
  void recheckLocationIfPending() {
    final blocked = state.needsLocationServiceEnable ||
        state.needsLocationPermission ||
        state.needsLocationPermissionForever;
    if (blocked) {
      unawaited(_fetchTodayRouteWithLocation());
    }
  }

  // ── Driver orders (Upcoming / Completed tabs) ───────────────────────────

  /// Fetches GET /driver/orders once and caches it — both the Upcoming and
  /// Completed tabs read from this single list, split client-side by
  /// [DriverOrder.isCompleted]. Called lazily the first time either tab is
  /// opened; pass [force] to bypass the "already loaded" guard (e.g. pull to
  /// refresh, or retrying after an error).
  Future<void> loadDriverOrders({bool force = false}) async {
    if (state.isDriverOrdersLoading) return;
    if (!force && state.driverOrdersLoadStatus == DriverOrdersLoadStatus.loaded) {
      return;
    }

    state = state.copyWith(
      driverOrdersLoadStatus: DriverOrdersLoadStatus.loading,
      clearDriverOrdersError: true,
    );

    final result = await _repository.getDriverOrders();

    switch (result) {
      case ApiSuccess(:final data):
        state = state.copyWith(
          driverOrdersLoadStatus: DriverOrdersLoadStatus.loaded,
          driverOrders: data,
        );
      case ApiFailure(:final exception):
        state = state.copyWith(
          driverOrdersLoadStatus: DriverOrdersLoadStatus.error,
          driverOrdersErrorMessage: exception.message,
          isSessionExpired: _isSessionExpired(exception),
        );
    }
  }

  // ── Accept order ──────────────────────────────────────────────────────────

  /// Called when the driver swipes "Accept Order". Bulk-accepts every order
  /// currently in [TodayRouteState.unacceptedOrders] in a single API call.
  ///
  /// On success, clears the unaccepted list and loads today's route.
  Future<void> acceptAllUnacceptedOrders() async {
    if (state.isAccepting) return;
    if (state.unacceptedOrders.isEmpty) return;

    final orderIds = state.unacceptedOrders.map((o) => o.id).toList();

    state = state.copyWith(
      isAccepting: true,
      clearAcceptError: true,
    );

    final result = await _repository.acceptUnacceptedOrders(orderIds);

    switch (result) {
      case ApiSuccess():
        state = state.copyWith(
          isAccepting: false,
          unacceptedOrders: const [],
        );
        await _fetchTodayRouteWithLocation();
      case ApiFailure(:final exception):
        state = state.copyWith(
          isAccepting: false,
          acceptErrorMessage: exception.message,
          isSessionExpired: _isSessionExpired(exception),
        );
    }
  }

  // ── Route start ───────────────────────────────────────────────────────────

  Future<void> startRoute() async {
    if (state.route == null || state.route!.stops.isEmpty) return;
    if (state.startStatus == RouteStartStatus.starting) return; // double-tap

    state = state.copyWith(
      startStatus: RouteStartStatus.starting,
      clearError: true,
    );

    final result = await _repository.updateDriverStatus(
      status: ApiConstants.driverOnRouteStatus,
    );

    switch (result) {
      case ApiSuccess():
        state = state.copyWith(startStatus: RouteStartStatus.active);
        // Mark the first stop in-progress.
        _setStopStatus(state.route!.stops.first.id, StopStatus.inProgress);
      case ApiFailure(:final exception):
      // Revert to idle so the driver can retry the Start button.
        state = state.copyWith(
          startStatus: RouteStartStatus.idle,
          errorMessage: exception.message,
        );
    }
  }

  // ── Pickup ────────────────────────────────────────────────────────────────

  Future<bool> pickupOrder({
    required String orderId,
    required String photoPath,
    required double latitude,
    required double longitude,
  }) async {
    if (orderId.isEmpty) {
      state = state.copyWith(
        pickupErrorMessage: 'Invalid order. Please refresh and try again.',
      );
      return false;
    }

    // Guard against duplicate taps on the same order.
    if (state.isPickupLoading && state.activePickupOrderId == orderId) {
      return false;
    }

    state = state.copyWith(
      isPickupLoading: true,
      activePickupOrderId: orderId,
      clearPickupError: true,
    );

    final result = await _repository.pickupOrder(
      orderId: orderId,
      photoPath: photoPath,
      latitude: latitude,
      longitude: longitude,
    );

    switch (result) {
      case ApiSuccess<PickupConfirmationResponse>():
        state = state.copyWith(
          isPickupLoading: false,
          clearActivePickup: true,
        );
        return true;
      case ApiFailure<PickupConfirmationResponse>(:final exception):
        state = state.copyWith(
          isPickupLoading: false,
          clearActivePickup: true,
          pickupErrorMessage: exception.message,
        );
        return false;
    }
  }

  // ── Stop lifecycle ────────────────────────────────────────────────────────

  void markStopCompleted(String stopId) {
    _setStopStatus(stopId, StopStatus.completed);

    final stops = state.route?.stops ?? [];
    final hasPending = stops.any((s) => s.status == StopStatus.pending);
    if (hasPending) {
      final next = stops.firstWhere((s) => s.status == StopStatus.pending);
      _setStopStatus(next.id, StopStatus.inProgress);
    }

    final allDone =
    state.route!.stops.every((s) => s.status == StopStatus.completed);
    if (allDone) {
      state = state.copyWith(startStatus: RouteStartStatus.completed);
    }

    // The Completed tab reads from `driverOrders` (GET /driver/orders), a
    // separate cache from `route.stops` — without this it stays stale until
    // a manual pull-to-refresh, even though the stop above just moved to
    // "Done". Force a background refetch so it reflects the new
    // delivered/failed order as soon as this stop completes, no user action
    // needed. Fire-and-forget: the Completed tab is a ConsumerWidget that
    // rebuilds on its own once the state lands.
    unawaited(loadDriverOrders(force: true));

    // The header's "Total routes" / "Done" counts come from today-route's
    // totalStops / totalDeliveredOrders, which only the server can update —
    // refetch quietly so they reflect this completion.
    unawaited(_refreshRouteSilently());
  }

  /// Re-fetches today-routeV2 in the background without touching
  /// [TodayRouteState.loadStatus] or the location gate, so the current
  /// list stays on screen (no spinner, no gate views). Failures are ignored
  /// — the existing route stays as-is until the next explicit refresh.
  Future<void> _refreshRouteSilently() async {
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;
    try {
      final position = await _locationService.getCurrentPosition();
      final result = await _repository.getTodayRouteV2(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (result case ApiSuccess(:final data)) {
        state = state.copyWith(route: data);
      }
    } catch (_) {
      // Location unavailable — keep the current route.
    } finally {
      _isFetchingRoute = false;
    }
  }

  void _setStopStatus(String stopId, StopStatus status) {
    if (state.route == null) return;
    final updated = state.route!.stops
        .map((s) => s.id == stopId ? s.copyWith(status: status) : s)
        .toList();
    state = state.copyWith(route: state.route!.copyWith(stops: updated));
  }

  // ── Maps ──────────────────────────────────────────────────────────────────

  /// Opens the stop in Google Maps. Uses coordinates when present, otherwise
  /// falls back to a text address search.
  Future<bool> openInGoogleMaps(RouteStop stop) async {
    final Uri uri;
    if (stop.hasCoordinates) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${stop.latitude},${stop.longitude}',
      );
    } else {
      final q = Uri.encodeComponent(stop.address);
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    }
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  // ── Public helpers ────────────────────────────────────────────────────────

  void refresh() => loadRoute();

  /// Wipes every trace of the current driver's session. Called on logout —
  /// this provider is not autoDispose, so without it the next driver to log
  /// in would inherit the previous one's route, availability and errors.
  void reset() {
    state = const TodayRouteState();
    // Clear the persisted toggle too — otherwise the next driver to log in
    // on this device would open the app already "online".
    unawaited(_clearPersistedAvailability());
  }

  Future<void> _clearPersistedAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isAvailableKey);
  }
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

final todayRouteProvider =
StateNotifierProvider<TodayRouteNotifier, TodayRouteState>(
      (ref) => TodayRouteNotifier(
    ref.watch(routeRepositoryProvider),
    ref.watch(routeLocationServiceProvider),
  ),
);