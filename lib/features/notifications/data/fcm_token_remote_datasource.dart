// ============================================================================
// lib/features/notifications/data/fcm_token_remote_datasource.dart
//
// Network layer for registering the driver's push device token.
// Mirrors location_sync_remote_datasource.dart:
//   • Uses shared DioClient — Bearer token via auth interceptor, envelope
//     unwrapping, ApiResult<T> return type.
//
// Endpoint:
//   POST /api/device-tokens/register
//   Content-Type: application/json
//   Body: { token, platform, deviceId, deviceName }
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../uttils/RouteApiConstants.dart';

class FcmTokenRemoteDataSource {
  FcmTokenRemoteDataSource(this._dioClient);
  final DioClient _dioClient;

  /// Registers the FCM [token] for this device with the backend so the
  /// driver can receive pushes. [platform]/[deviceId]/[deviceName] let the
  /// server target and de-duplicate a driver's individual devices.
  Future<ApiResult<bool>> registerToken({
    required String token,
    required String platform,
    required String deviceId,
    required String deviceName,
  }) {
    return _dioClient.post<bool>(
      RouteApiConstants.deviceTokenRegister,
      data: {
        'token': token,
        'platform': platform,
        'deviceId': deviceId,
        'deviceName': deviceName,
      },
      fromJson: (_) => true,
    );
  }
}

final fcmTokenRemoteDataSourceProvider = Provider<FcmTokenRemoteDataSource>(
  (ref) => FcmTokenRemoteDataSource(ref.watch(dioClientProvider)),
);
