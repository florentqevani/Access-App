import 'dart:convert';

import 'package:access_app/core/errors/server_exception.dart';
import 'package:access_app/core/network/auth_server_config.dart';
import 'package:access_app/data/data_source/remote_data_source.dart';
import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/domain/repository/auth_user.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RemoteDataSourceImpl implements RemoteDataSource {
  final FirebaseAuth firebaseAuth;
  final String authServerBaseUrl;
  final Dio dio;

  RemoteDataSourceImpl({
    required this.firebaseAuth,
    required String authServerBaseUrl,
    required this.dio,
  }) : authServerBaseUrl = normalizeAuthServerBaseUrl(authServerBaseUrl);
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

    final user = _parseUser(payload['user'], accessToken: accessToken);

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken as String?,
      accessTokenExpiresAt: accessTokenExpiresAt,
      refreshTokenExpiresAt: refreshTokenExpiresAt,
      user: user,
    );
  }

  AuthUser _parseUser(dynamic rawUser, {required String accessToken}) {
    if (rawUser is Map) {
      final userMap = Map<String, dynamic>.from(rawUser);
      final id = userMap['id'];
      final role = userMap['role'];

      if (id is String && id.isNotEmpty && role is String && role.isNotEmpty) {
        return AuthUser(
          id: id,
          email: userMap['email'] as String?,
          displayName: userMap['displayName'] as String?,
          role: role,
          permissions: _parsePermissions(userMap['permissions']),
        );
      }
    }

    final claims = _decodeJwtClaims(accessToken);
    final id = claims['sub'];
    final role = claims['role'];
    if (id is String && id.isNotEmpty && role is String && role.isNotEmpty) {
      final decodedPermissions = claims['permissions'];
      return AuthUser(
        id: id,
        email: claims['email'] as String?,
        displayName: null,
        role: role,
        permissions: _parsePermissions(decodedPermissions),
      );
    }

    throw const ServerException(
      'Server did not return a valid authenticated user payload.',
    );
  }

  List<AuthPermission> _parsePermissions(dynamic rawPermissions) {
    if (rawPermissions is List) {
      final permissions = <AuthPermission>[];
      for (final item in rawPermissions) {
        if (item is Map) {
          final permission = Map<String, dynamic>.from(item);
          final resource = permission['resource'];
          final action = permission['action'];
          final scope = permission['scope'];
          if (resource is String && action is String && scope is String) {
            permissions.add(
              AuthPermission(resource: resource, action: action, scope: scope),
            );
          }
        } else if (item is String && item.contains(':')) {
          final parts = item.split(':');
          if (parts.length >= 2) {
            permissions.add(
              AuthPermission(
                resource: parts[0],
                action: parts[1],
                scope: parts.length > 2 ? parts[2] : 'full',
              ),
            );
          }
        }
      }
      return permissions;
    }
    return const <AuthPermission>[];
  }

  Map<String, dynamic> _decodeJwtClaims(String token) {
    final tokenParts = token.split('.');
    if (tokenParts.length < 2) {
      return const {};
    }

    try {
      final normalized = base64Url.normalize(tokenParts[1]);
      final payloadBytes = base64Url.decode(normalized);
      final payloadString = utf8.decode(payloadBytes);
      final dynamic decoded = jsonDecode(payloadString);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return const {};
    }

    return const {};
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

}
