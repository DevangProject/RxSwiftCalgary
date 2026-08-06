// ============================================================================
// model/login/login_response_model.dart
//
// IMPORTANT: DioClient._extractData() unwraps the envelope and returns the
// inner `data` object. So this model parses the DATA block directly — NOT the
// outer { success, message, data, ... } envelope.
//
// Inner data shape:
// {
//   "accessToken": "...",
//   "refreshToken": "...",
//   "accessTokenExpiresAt": "...",
//   "refreshTokenExpiresAt": "...",
//   "user": { ... }
// }
// ============================================================================

class LoginResponseModel {
  const LoginResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;
  final UserModel user;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      accessTokenExpiresAt:
      DateTime.parse(json['accessTokenExpiresAt'] as String),
      refreshTokenExpiresAt:
      DateTime.parse(json['refreshTokenExpiresAt'] as String),
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
    'refreshTokenExpiresAt': refreshTokenExpiresAt.toIso8601String(),
    'user': user.toJson(),
  };

  @override
  String toString() =>
      'LoginResponseModel(user: $user, accessTokenExpiresAt: $accessTokenExpiresAt)';
}

/// Authenticated user. Several fields are nullable because the API returns
/// null depending on account type (a DRIVER has no pharmacyId/pharmacyName).
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    required this.phone,
    this.pharmacyId,
    this.driverId,
    this.avatarInitials,
    this.pharmacyName,
  });

  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;
  final String phone;
  final String? pharmacyId;
  final String? driverId;
  final String? avatarInitials;
  final String? pharmacyName;

  bool get isDriver => role.toUpperCase() == 'DRIVER';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String? ?? json['email'] as String,
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      pharmacyId: json['pharmacyId'] as String?,
      driverId: json['driverId'] as String?,
      avatarInitials: json['avatarInitials'] as String?,
      pharmacyName: json['pharmacyName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pharmacyId': pharmacyId,
    'driverId': driverId,
    'email': email,
    'username': username,
    'fullName': fullName,
    'role': role,
    'phone': phone,
    'avatarInitials': avatarInitials,
    'pharmacyName': pharmacyName,
  };

  @override
  String toString() =>
      'UserModel(id: $id, fullName: $fullName, email: $email, role: $role)';
}
