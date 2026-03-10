class AuthSession {
  final String accessToken;
  final String? refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime? refreshTokenExpiresAt;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
  });
}
