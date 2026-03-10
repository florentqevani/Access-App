import 'package:access_app/domain/repository/auth_session.dart';

class LocalDataSource {
  static const Duration tokenValidityDuration = Duration(minutes: 15);

  static String? _accessToken;
  static DateTime? _accessTokenExpiresAt;
  static String? _refreshToken;
  static DateTime? _refreshTokenExpiresAt;

  Future<void> saveSession(AuthSession session) async {
    _accessToken = session.accessToken;
    _accessTokenExpiresAt = session.accessTokenExpiresAt;
    _refreshToken = session.refreshToken;
    _refreshTokenExpiresAt = session.refreshTokenExpiresAt;

    if (session.refreshToken != null) {
      _refreshToken = session.refreshToken;
      _refreshTokenExpiresAt = session.refreshTokenExpiresAt;
    }
  }

  Future<void> saveAccessToken(
    String accessToken, {
    Duration duration = tokenValidityDuration,
    DateTime? expiresAt,
  }) async {
    _accessToken = accessToken;
    _accessTokenExpiresAt = expiresAt ?? DateTime.now().add(duration);
  }

  Future<String?> getAccessToken() async {
    if (_accessToken == null || _accessTokenExpiresAt == null) {
      return null;
    }

    if (DateTime.now().isAfter(_accessTokenExpiresAt!)) {
      _accessToken = null;
      _accessTokenExpiresAt = null;
      return null;
    }

    return _accessToken;
  }

  Future<String?> getRefreshToken() async {
    if (_refreshToken == null || _refreshTokenExpiresAt == null) {
      return null;
    }

    if (DateTime.now().isAfter(_refreshTokenExpiresAt!)) {
      await clearTokens();
      return null;
    }

    return _refreshToken;
  }

  Future<Duration?> getRemainingAccessTokenDuration() async {
    final accessToken = await getAccessToken();
    if (accessToken == null || _accessTokenExpiresAt == null) {
      return null;
    }

    final remaining = _accessTokenExpiresAt!.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      _accessToken = null;
      _accessTokenExpiresAt = null;
      return null;
    }

    return remaining;
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _accessTokenExpiresAt = null;
    _refreshToken = null;
    _refreshTokenExpiresAt = null;
  }
}
