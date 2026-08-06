// ============================================================================
// lib/features/route_details/data/route_detail_repository.dart
//
// Thin pass-through layer between the notifier and the datasource.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../model/order_detail_model.dart';
import 'route_detail_remote_datasource.dart';

class RouteDetailRepository {
  RouteDetailRepository(this._datasource);
  final RouteDetailRemoteDatasource _datasource;

  Future<ApiResult<OrderDetail>> getOrderDetail(String orderId) =>
      _datasource.getOrderDetail(orderId);
}

final routeDetailRepositoryProvider = Provider<RouteDetailRepository>(
  (ref) => RouteDetailRepository(ref.watch(routeDetailRemoteDatasourceProvider)),
);
