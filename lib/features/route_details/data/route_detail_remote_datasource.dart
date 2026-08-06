// ============================================================================
// lib/features/route_details/data/route_detail_remote_datasource.dart
//
// Uses the central DioClient — NOT a raw Dio instance.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../uttils/RouteApiConstants.dart';
import '../model/order_detail_model.dart';

class RouteDetailRemoteDatasource {
  RouteDetailRemoteDatasource(this._dioClient);
  final DioClient _dioClient;

  // ── Order detail  GET /api/driver/orders/{orderId} ────────────────────

  Future<ApiResult<OrderDetail>> getOrderDetail(String orderId) {
    return _dioClient.get<OrderDetail>(
      RouteApiConstants.orderDetail(orderId),
      fromJson: (json) => OrderDetail.fromJson(json as Map<String, dynamic>),
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final routeDetailRemoteDatasourceProvider =
    Provider<RouteDetailRemoteDatasource>(
  (ref) => RouteDetailRemoteDatasource(ref.watch(dioClientProvider)),
);
