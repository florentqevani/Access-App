import 'package:access_app/core/errors/server_exception.dart';
import 'package:access_app/data/data_source/remote_data_source.dart';
import 'package:access_app/domain/repository/auth_session.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class RemoteDataSourceImpl implements RemoteDataSource {
  final FirebaseAuth firebaseAuth;
  final String authServerBaseUrl;
  final Dio dio;

  RemoteDataSourceImpl({
    required this.firebaseAuth,
    required String authServerBaseUrl,
    required this.dio,
  }) : authServerBaseUrl = _normalizeBaseUrl(authServerBaseUrl);
  @override
  Future<AuthSession> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = response.user;

      if (user == null) {
        throw const ServerException('User is null');
      }

      return _exchangeFirebaseSession(user);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<AuthSession> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const ServerException('User is null');
      }

      if (name.trim().isNotEmpty) {
        await user.updateDisplayName(name.trim());
        await user.reload();
      }

      return _exchangeFirebaseSession(user);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<AuthSession> refreshSession({required String refreshToken}) async {
    try {
      final response = await dio.post(
        _authEndpoint('refresh'),
        data: {'refreshToken': refreshToken},
      );

      _validateStatusCode(response.statusCode, 'Failed to refresh session.');
      return _toAuthSession(_readPayload(response.data));
    } on DioException catch (e) {
      if (_isConnectionError(e.type)) {
        throw _serverNotReachable();
      }
      throw ServerException(e.message ?? 'Failed to refresh session.');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<bool> revokeRefreshToken({required String refreshToken}) async {
    try {
      final response = await dio.post(
        _authEndpoint('revoke'),
        data: {'refreshToken': refreshToken},
      );

      _validateStatusCode(
        response.statusCode,
        'Failed to revoke refresh token.',
      );
      final payload = _readPayload(response.data);
      final revoked = payload['revoked'];

      if (revoked is bool) {
        return revoked;
      }

      return true;
    } on DioException catch (e) {
      if (_isConnectionError(e.type)) {
        throw _serverNotReachable();
      }
      throw ServerException(e.message ?? 'Failed to revoke refresh token.');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<AuthSession> _exchangeFirebaseSession(User user) async {
    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw const ServerException('Unable to read Firebase ID token.');
    }

    try {
      final response = await dio.post(
        _authEndpoint('exchange'),
        data: {'idToken': idToken},
      );

      _validateStatusCode(
        response.statusCode,
        'Failed to exchange Firebase token.',
      );
      return _toAuthSession(_readPayload(response.data));
    } on DioException catch (e) {
      if (_isConnectionError(e.type)) {
        throw _serverNotReachable();
      }
      throw ServerException(e.message ?? 'Failed to exchange Firebase token.');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  AuthSession _toAuthSession(Map<String, dynamic> payload) {
    final accessToken = payload['accessToken'];
    final refreshToken = payload['refreshToken'];
    final accessTokenExpiresAt =
        _parseExpiry(payload['accessTokenExpiresAt']) ??
        _parseExpiry(payload['accessTokenExpiresIn']) ??
        _secondsFromNow(payload['expiresIn']) ??
        _secondsFromNow(payload['accessTokenExpires']);

    if (accessToken is! String || accessToken.isEmpty) {
      throw const ServerException(
        'Server did not return a valid access token.',
      );
    }

    if (accessTokenExpiresAt == null) {
      throw const ServerException(
        'Server did not return a valid access token expiry.',
      );
    }

    DateTime? refreshTokenExpiresAt;
    if (payload.containsKey('refreshTokenExpiresAt') ||
        payload.containsKey('refreshTokenExpiresIn')) {
      refreshTokenExpiresAt =
          _parseExpiry(payload['refreshTokenExpiresAt']) ??
          _parseExpiry(payload['refreshTokenExpiresIn']);
    }

    if (refreshToken != null && refreshToken is! String) {
      throw const ServerException(
        'Server did not return a valid refresh token.',
      );
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken as String?,
      accessTokenExpiresAt: accessTokenExpiresAt,
      refreshTokenExpiresAt: refreshTokenExpiresAt,
    );
  }

  Map<String, dynamic> _readPayload(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const ServerException('Invalid server response payload.');
  }

  DateTime? _parseExpiry(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  DateTime? _secondsFromNow(dynamic value) {
    if (value is num) {
      return DateTime.now().add(Duration(seconds: value.toInt()));
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return DateTime.now().add(Duration(seconds: parsed));
      }
    }
    return null;
  }

  void _validateStatusCode(int? statusCode, String message) {
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw ServerException(message);
    }
  }

  ServerException _serverNotReachable() {
    return ServerException(
      'Cannot reach auth server at $authServerBaseUrl. '
      'Start backend server and set AUTH_SERVER_BASE_URL if needed.',
    );
  }

  String _authEndpoint(String path) {
    final trimmed = authServerBaseUrl.endsWith('/')
        ? authServerBaseUrl.substring(0, authServerBaseUrl.length - 1)
        : authServerBaseUrl;
    if (trimmed.endsWith('/auth')) {
      return '$trimmed/$path';
    }
    return '$trimmed/auth/$path';
  }

  bool _isConnectionError(DioExceptionType type) {
    switch (type) {
      case DioExceptionType.cancel:
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.unknown:
        return true;
      default:
        return false;
    }
  }

  static String _normalizeBaseUrl(String rawBaseUrl) {
    final trimmed = rawBaseUrl.trim();
    if (trimmed.isEmpty) {
      return rawBaseUrl;
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return trimmed;
    }

    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      return uri.replace(host: '10.0.2.2').toString();
    }

    return trimmed;
  }
}
