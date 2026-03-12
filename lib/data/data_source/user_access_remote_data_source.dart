import 'package:access_app/domain/repository/user_access_models.dart';

abstract interface class UserAccessRemoteDataSource {
  Future<AccessActionResult> executeAction({
    required String accessToken,
    required String resource,
    required String action,
  });

  Future<List<AuditLogEntry>> getAuditLogs({
    required String accessToken,
    int limit = 20,
  });

  Future<List<UserSummary>> getUsers({
    required String accessToken,
    int limit = 200,
  });

  Future<List<RoleSummary>> getRoles({required String accessToken});

  Future<UserCreationResult> createUser({
    required String accessToken,
    required String email,
    required String displayName,
    String? role,
  });

  Future<bool> updateUser({
    required String accessToken,
    required String userId,
    String? email,
    String? displayName,
  });

  Future<bool> deleteUser({
    required String accessToken,
    required String userId,
  });

  Future<bool> updateUserRole({
    required String accessToken,
    required String userId,
    required String role,
  });

  Future<String?> resetUserPassword({
    required String accessToken,
    required String userId,
  });

  Future<bool> exchangeIdToken({required String idToken});
}
