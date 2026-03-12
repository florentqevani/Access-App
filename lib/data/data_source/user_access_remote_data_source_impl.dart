import 'package:access_app/core/errors/server_exception.dart';
import 'package:access_app/core/network/auth_server_config.dart';
import 'package:access_app/data/data_source/user_access_remote_data_source.dart';
import 'package:access_app/domain/repository/user_access_models.dart';
import 'package:dio/dio.dart';

class UserAccessRemoteDataSourceImpl implements UserAccessRemoteDataSource {
  final Dio dio;
  final String authServerBaseUrl;

  UserAccessRemoteDataSourceImpl({
    required this.dio,
    required String authServerBaseUrl,
  }) : authServerBaseUrl = normalizeAuthServerBaseUrl(authServerBaseUrl);

  @override
  Future<AccessActionResult> executeAction({
    required String accessToken,
    required String resource,
    required String action,
  }) async {
    try {
      final response = await dio.post(
        _usersEndpoint('actions/execute'),
        data: {'resource': resource, 'action': action},
        options: _authorizedOptions(accessToken),
      );
      _validateStatusCode(response.statusCode, 'Failed to execute action.');

      final payload = _readPayload(response.data);
      final rawEvent = payload['event'];
      AuditLogEntry? event;
      if (rawEvent is Map) {
        event = AuditLogEntry.fromMap(Map<String, dynamic>.from(rawEvent));
      }

      final message = payload['message']?.toString() ?? 'Action executed.';
      return AccessActionResult(message: message, event: event);
    } on DioException catch (error) {
      throw ServerException(
        _dioErrorMessage(error, fallback: 'Failed to execute action.'),
      );
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<List<AuditLogEntry>> getAuditLogs({
    required String accessToken,
    int limit = 20,
  }) async {
    try {
      Response<dynamic> response;
      try {
        response = await dio.get(
          _usersEndpoint('logs/role-scoped'),
          queryParameters: {'limit': limit},
          options: _authorizedOptions(accessToken),
        );
        _validateStatusCode(response.statusCode, 'Failed to load audit logs.');
      } on DioException catch (error) {
        // Backward compatibility for older backend versions that only expose /users/logs.
        if (error.response?.statusCode == 404) {
          response = await dio.get(
            _usersEndpoint('logs'),
            queryParameters: {'limit': limit},
            options: _authorizedOptions(accessToken),
          );
          _validateStatusCode(
            response.statusCode,
            'Failed to load audit logs.',
          );
        } else {
          rethrow;
        }
      }

      final payload = _readPayload(response.data);
      final logsValue = payload['logs'];
      if (logsValue is! List) {
        throw const ServerException('Invalid logs payload.');
      }

      return logsValue
          .whereType<Map>()
          .map((item) => AuditLogEntry.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerException(
        _dioErrorMessage(error, fallback: 'Failed to load audit logs.'),
      );
    } on ServerException {
      rethrow;
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<List<UserSummary>> getUsers({
    required String accessToken,
    int limit = 200,
  }) async {
    try {
      final response = await dio.get(
        _usersEndpoint(''),
        queryParameters: {'limit': limit},
        options: _authorizedOptions(accessToken),
      );
      _validateStatusCode(response.statusCode, 'Failed to load users.');

      final payload = _readPayload(response.data);
      final rawUsers = payload['users'];
      if (rawUsers is! List) {
        throw const ServerException('Invalid users payload.');
      }

      return rawUsers
          .whereType<Map>()
          .map((item) => UserSummary.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerException(
        _dioErrorMessage(error, fallback: 'Failed to load users.'),
      );
    } on ServerException {
      rethrow;
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<List<RoleSummary>> getRoles({required String accessToken}) async {
    try {
      final response = await dio.get(
        _usersEndpoint('roles'),
        options: _authorizedOptions(accessToken),
      );
      _validateStatusCode(response.statusCode, 'Failed to load roles.');

      final payload = _readPayload(response.data);
      final rawRoles = payload['roles'];
      if (rawRoles is! List) {
        throw const ServerException('Invalid roles payload.');
      }

      return rawRoles
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(
            (item) => RoleSummary(
              name: item['name']?.toString() ?? '',
              description: item['description']?.toString(),
            ),
          )
          .where((role) => role.name.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerException(
        _dioErrorMessage(error, fallback: 'Failed to load roles.'),
      );
    } on ServerException {
      rethrow;
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<UserCreationResult> createUser({
    required String accessToken,
    required String email,
    required String displayName,
    String? role,
  }) async {
    try {
      final body = <String, dynamic>{
        'email': email,
        'displayName': displayName,
      };
      if (role != null && role.trim().isNotEmpty) {
        body['role'] = role.trim();
      }

      final response = await dio.post(
        _usersEndpoint(''),
        data: body,
        options: _authorizedOptions(accessToken),
      );
      _validateStatusCode(response.statusCode, 'Failed to create user.');

      final payload = _readPayload(response.data);
      final rawUser = payload['user'];
      String userId = '';
      if (rawUser is Map) {
        userId = rawUser['id']?.toString() ?? '';
      }

      return UserCreationResult(
        userId: userId,
        defaultPassword: payload['defaultPassword']?.toString(),
      );
    } on DioException catch (error) {
      throw ServerException(
        _dioErrorMessage(error, fallback: 'Failed to create user.'),
      );
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<bool> updateUser({
    required String accessToken,
    required String userId,
    String? email,
    String? displayName,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (email != null && email.trim().isNotEmpty) {
        body['email'] = email.trim();
      }
      if (displayName != null && displayName.trim().isNotEmpty) {
        body['displayName'] = displayName.trim();
      }

      final response = await dio.patch(
        _usersEndpoint(userId),
        data: body,
        options: _authorizedOptions(accessToken),
      );
      _validateStatusCode(response.statusCode, 'Failed to update user.');
      return true;
    } on DioException catch (error) {
      throw ServerException(
        _dioErrorMessage(error, fallback: 'Failed to update user.'),
      );
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<bool> deleteUser({
    required String accessToken,
    required String userId,
  }) async {
    try {
      final response = await dio.delete(
        _usersEndpoint(userId),
        options: _authorizedOptions(accessToken),
      );
      _validateStatusCode(response.statusCode, 'Failed to delete user.');
      return true;
    } on DioException catch (error) {
      throw ServerException(
        _dioErrorMessage(error, fallback: 'Failed to delete user.'),
      );
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<bool> updateUserRole({
    required String accessToken,
    required String userId,
    required String role,
  }) async {
    try {
      final response = await dio.patch(
        _usersEndpoint('$userId/role'),
        data: {'role': role},
        options: _authorizedOptions(accessToken),
      );
      _validateStatusCode(response.statusCode, 'Failed to update role.');
      return true;
    } on DioException catch (error) {
      throw ServerException(
        _dioErrorMessage(error, fallback: 'Failed to update role.'),
      );
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<String?> resetUserPassword({
    required String accessToken,
    required String userId,
  }) async {
    try {
      final response = await dio.post(
        _usersEndpoint('$userId/password/reset'),
        options: _authorizedOptions(accessToken),
      );
      _validateStatusCode(response.statusCode, 'Failed to reset password.');
      final payload = _readPayload(response.data);
      return payload['defaultPassword']?.toString();
    } on DioException catch (error) {
      throw ServerException(
        _dioErrorMessage(error, fallback: 'Failed to reset password.'),
      );
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<bool> exchangeIdToken({required String idToken}) async {
    try {
      final response = await dio.post(
        _authEndpoint('exchange'),
        data: {'idToken': idToken},
      );
      _validateStatusCode(response.statusCode, 'Failed to sync session.');
      return true;
    } on DioException catch (error) {
      throw ServerException(
        _dioErrorMessage(error, fallback: 'Failed to sync session.'),
      );
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  Options _authorizedOptions(String accessToken) {
    return Options(headers: {'Authorization': 'Bearer $accessToken'});
  }

  String _usersEndpoint(String path) {
    final base = _serviceBaseUrl();
    final trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedPath = path.trim();
    if (trimmed.endsWith('/users')) {
      if (normalizedPath.isEmpty) return trimmed;
      return '$trimmed/$normalizedPath';
    }
    if (normalizedPath.isEmpty) return '$trimmed/users';
    return '$trimmed/users/$normalizedPath';
  }

  String _authEndpoint(String path) {
    final base = _serviceBaseUrl();
    final trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    if (trimmed.endsWith('/auth')) {
      return '$trimmed/$path';
    }
    return '$trimmed/auth/$path';
  }

  String _serviceBaseUrl() {
    var base = authServerBaseUrl.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    if (base.endsWith('/auth')) {
      return base.substring(0, base.length - '/auth'.length);
    }
    if (base.endsWith('/users')) {
      return base.substring(0, base.length - '/users'.length);
    }
    return base;
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

  String _dioErrorMessage(DioException error, {required String fallback}) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['error'] ?? data['message'];
      if (message != null) {
        return message.toString();
      }
    }
    return error.message ?? fallback;
  }

  void _validateStatusCode(int? statusCode, String message) {
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw ServerException(message);
    }
  }
}
