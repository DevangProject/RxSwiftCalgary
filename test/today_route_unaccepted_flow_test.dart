// Verification test for the unaccepted-orders flow. Drives the real
// TodayRouteScreen + TodayRouteNotifier with a fake repository (no live
// backend/login needed) to confirm: unaccepted-first load order, the
// bulk accept-order swipe flow, and the availability-OFF reset.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxswift/core/network/api_result.dart';
import 'package:rxswift/core/network/dio_client.dart';
import 'package:rxswift/core/network/network_exception.dart';
import 'package:rxswift/core/utils/connectivity_service.dart';
import 'package:rxswift/core/utils/token_storage.dart';
import 'package:rxswift/features/today_route/data/route_remote_datasource.dart';
import 'package:rxswift/features/today_route/data/route_repository.dart';
import 'package:rxswift/features/today_route/model/route_model.dart';
import 'package:rxswift/features/today_route/today_route_screen.dart';

class FakeRouteRepository extends RouteRepository {
  FakeRouteRepository(super.datasource);

  List<UnacceptedOrder> unaccepted = [];
  bool acceptShouldSucceed = true;
  int acceptCalls = 0;
  List<String>? lastAcceptedOrderIds;
  int todayRouteCalls = 0;

  @override
  Future<ApiResult<void>> updateDriverAvailability({
    required bool isAvailable,
  }) async =>
      const ApiSuccess(null);

  @override
  Future<ApiResult<List<UnacceptedOrder>>> getUnacceptedOrders() async =>
      ApiSuccess(unaccepted);

  @override
  Future<ApiResult<bool>> acceptUnacceptedOrders(
      List<String> orderIds) async {
    acceptCalls++;
    lastAcceptedOrderIds = orderIds;
    if (!acceptShouldSucceed) {
      return const ApiFailure(UnknownException('accept failed'));
    }
    unaccepted =
        unaccepted.where((o) => !orderIds.contains(o.id)).toList();
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<TodayRoute>> getTodayRoute() async {
    todayRouteCalls++;
    return ApiSuccess(TodayRoute(
      driverId: 'd1',
      driverName: 'Driver',
      startLatitude: 0,
      startLongitude: 0,
      routeDate: DateTime(2026, 6, 18),
      totalStops: 0,
      totalOrders: 0,
      estimatedDistanceKm: 0,
      stops: const [],
    ));
  }
}

UnacceptedOrder _order(String id) => UnacceptedOrder(
      id: id,
      orderNumber: 'RX$id',
      patientName: 'Dev $id',
      patientPhone: '1234567890',
      deliveryAddress: '123 Test Street',
      deliveryLatitude: 23.01,
      deliveryLongitude: 72.51,
      deliveryNotes: '',
      pharmacyName: 'JIO Pharma',
      pharmacyAddress: 'Pharmacy address',
      pharmacyPhone: '0987654321',
      pharmacyLatitude: 23.01,
      pharmacyLongitude: 72.51,
      status: 'PENDING',
      statusLabel: 'Pending',
      pickupWindowLabel: '4:00 PM Pickup',
      handlingType: 'Express',
      copayAmount: 0,
      priority: false,
      rxNumber: null,
      sortOrder: 0,
    );

void main() {
  late FakeRouteRepository repo;

  setUp(() {
    // Repository methods are all overridden below, so this datasource is
    // never actually hit — it just satisfies RouteRepository's constructor.
    final dioClient = DioClient(
      dio: Dio(),
      tokenStorage: TokenStorage(const FlutterSecureStorage()),
      connectivity: ConnectivityService(Connectivity()),
    );
    repo = FakeRouteRepository(RouteRemoteDatasource(dioClient));
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [routeRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TodayRouteScreen()),
      ),
    );
  }

  testWidgets('shows unaccepted orders before today route when present',
      (tester) async {
    repo.unaccepted = [_order('1'), _order('2')];

    await pumpScreen(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Dev 1'), findsOneWidget);
    expect(find.text('Dev 2'), findsOneWidget);
    expect(find.text('Swipe to Accept Order'), findsOneWidget);
    expect(repo.todayRouteCalls, 0);
  });

  testWidgets('falls back to today route when unaccepted list is empty',
      (tester) async {
    repo.unaccepted = [];

    await pumpScreen(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(repo.todayRouteCalls, 1);
    expect(find.text('Swipe to Accept Order'), findsNothing);
    expect(find.text('Start Route'), findsOneWidget);
  });

  testWidgets(
      'swiping accept bulk-accepts every unaccepted order then loads today route',
      (tester) async {
    repo.unaccepted = [_order('1'), _order('2')];

    await pumpScreen(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Dev 1'), findsOneWidget);
    expect(find.text('Dev 2'), findsOneWidget);

    final handle = find.byIcon(Icons.chevron_right_rounded);
    await tester.drag(handle, const Offset(2000, 0));
    await tester.pumpAndSettle();

    expect(repo.acceptCalls, 1);
    expect(repo.lastAcceptedOrderIds, ['1', '2']);
    expect(repo.todayRouteCalls, 1);
    expect(find.text('Start Route'), findsOneWidget);
  });

  testWidgets('turning availability OFF clears route and unaccepted state',
      (tester) async {
    repo.unaccepted = [_order('1')];

    await pumpScreen(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Dev 1'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Dev 1'), findsNothing);
    expect(find.text('You are currently offline'), findsOneWidget);
  });
}
