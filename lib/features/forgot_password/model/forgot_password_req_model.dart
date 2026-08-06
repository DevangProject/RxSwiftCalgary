// lib/model/forgot_password/forgot_password_req_model.dart

class ForgotPasswordRequestModel {
  const ForgotPasswordRequestModel({required this.email});

  final String email;

  Map<String, dynamic> toJson() => {'email': email};
}
