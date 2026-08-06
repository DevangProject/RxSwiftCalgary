/// Request body sent to POST /Auth/login
class LoginRequestModel {
  const LoginRequestModel({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
    'login': email,
    'password': password,
  };
}