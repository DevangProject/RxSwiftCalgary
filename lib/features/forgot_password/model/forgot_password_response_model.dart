// lib/model/forgot_password/forgot_password_response_model.dart

class ForgotPasswordResponseModel {
  const ForgotPasswordResponseModel({
    required this.success,
    required this.message,
    required this.data,
    required this.statusCode,
    required this.errors,
  });

  final bool success;
  final String message;
  final bool data;
  final int statusCode;
  final List<dynamic> errors;

  factory ForgotPasswordResponseModel.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResponseModel(
      success:    json['success']    as bool,
      message:    json['message']    as String,
      data:       json['data']       as bool,
      statusCode: json['statusCode'] as int,
      errors:     (json['errors']    as List<dynamic>?) ?? [],
    );
  }
}
