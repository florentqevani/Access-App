import 'package:access_app/domain/repository/auth_user.dart';

class AuthSession {
  final String accessToken;
  final String? refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime? refreshTokenExpiresAt;
  final AuthUser user;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.user,
  });
}
