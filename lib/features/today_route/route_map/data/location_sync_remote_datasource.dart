// ============================================================================
// lib/features/today_route/route_map/data/location_sync_remote_datasource.dart
//
// Network layer for the driver live-location update endpoint.
//
// Mirrors route_remote_datasource.dart exactly:
//   • Uses shared DioClient — Bearer token via auth interceptor, envelope
//     unwrapping, ApiResult<T> return type.
//   • A failed call returns ApiResult.failure — callers ignore it silently.
//
// Endpoint:
//   PATCH /api/driver/location
//   Content-Type: application/json
//   Body: { latitude, longitude, speedKph, heading }
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_result.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../uttils/RouteApiConstants.dart';
import '../../model/location_sync_model.dart';


class LocationSyncRemoteDataSource {
  LocationSyncRemoteDataSource(this._dioClient);
  final DioClient _dioClient;

  /// Send current driver location to the server.
  /// Returns ApiResult.failure silently on any network/server error.
  Future<ApiResult<bool>> updateLocation(LocationSyncRequest request) {
    return _dioClient.patch<bool>(
      RouteApiConstants.driverLocation,
      data: request.toJson(),
      fromJson: (_) => true,
    );
  }
}

final locationSyncRemoteDataSourceProvider =
Provider<LocationSyncRemoteDataSource>(
      (ref) => LocationSyncRemoteDataSource(ref.watch(dioClientProvider)),
);