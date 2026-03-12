import 'package:access_app/core/errors/error.dart';
import 'package:access_app/domain/repository/user_access_models.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class UserAccessRepository {
  Future<Either<Failure, AccessActionResult>> executeAction({
    required String accessToken,
    required String resource,
    required String action,
  });

  Future<Either<Failure, List<AuditLogEntry>>> getAuditLogs({
    required String accessToken,
    int limit = 20,
  });

  Future<Either<Failure, List<UserSummary>>> getUsers({
    required String accessToken,
    int limit = 200,
  });

  Future<Either<Failure, List<RoleSummary>>> getRoles({
    required String accessToken,
  });

  Future<Either<Failure, UserCreationResult>> createUser({
    required String accessToken,
    required String email,
    required String displayName,
    String? role,
  });

  Future<Either<Failure, bool>> updateUser({
    required String accessToken,
    required String userId,
    String? email,
    String? displayName,
  });

  Future<Either<Failure, bool>> deleteUser({
    required String accessToken,
    required String userId,
  });

  Future<Either<Failure, bool>> updateUserRole({
    required String accessToken,
    required String userId,
    required String role,
  });

  Future<Either<Failure, String?>> resetUserPassword({
    required String accessToken,
    required String userId,
  });
}
