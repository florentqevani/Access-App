import 'package:access_app/core/errors/error.dart';
import 'package:access_app/core/errors/server_exception.dart';
import 'package:access_app/data/data_source/user_access_remote_data_source.dart';
import 'package:access_app/domain/repository/user_access_models.dart';
import 'package:access_app/domain/repository/user_access_repository.dart';
import 'package:fpdart/fpdart.dart';

class UserAccessRepositoryImpl implements UserAccessRepository {
  final UserAccessRemoteDataSource remoteDataSource;

  const UserAccessRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, AccessActionResult>> executeAction({
    required String accessToken,
    required String resource,
    required String action,
  }) async {
    try {
      final result = await remoteDataSource.executeAction(
        accessToken: accessToken,
        resource: resource,
        action: action,
      );
      return right(result);
    } on ServerException catch (error) {
      return left(Failure(error.message));
    } catch (error) {
      return left(Failure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AuditLogEntry>>> getAuditLogs({
    required String accessToken,
    int limit = 20,
  }) async {
    try {
      final logs = await remoteDataSource.getAuditLogs(
        accessToken: accessToken,
        limit: limit,
      );
      return right(logs);
    } on ServerException catch (error) {
      return left(Failure(error.message));
    } catch (error) {
      return left(Failure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, List<UserSummary>>> getUsers({
    required String accessToken,
    int limit = 200,
  }) async {
    try {
      final users = await remoteDataSource.getUsers(
        accessToken: accessToken,
        limit: limit,
      );
      return right(users);
    } on ServerException catch (error) {
      return left(Failure(error.message));
    } catch (error) {
      return left(Failure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, List<RoleSummary>>> getRoles({
    required String accessToken,
  }) async {
    try {
      final roles = await remoteDataSource.getRoles(accessToken: accessToken);
      return right(roles);
    } on ServerException catch (error) {
      return left(Failure(error.message));
    } catch (error) {
      return left(Failure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, UserCreationResult>> createUser({
    required String accessToken,
    required String email,
    required String displayName,
    String? role,
  }) async {
    try {
      final result = await remoteDataSource.createUser(
        accessToken: accessToken,
        email: email,
        displayName: displayName,
        role: role,
      );
      return right(result);
    } on ServerException catch (error) {
      return left(Failure(error.message));
    } catch (error) {
      return left(Failure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> updateUser({
    required String accessToken,
    required String userId,
    String? email,
    String? displayName,
  }) async {
    try {
      final result = await remoteDataSource.updateUser(
        accessToken: accessToken,
        userId: userId,
        email: email,
        displayName: displayName,
      );
      return right(result);
    } on ServerException catch (error) {
      return left(Failure(error.message));
    } catch (error) {
      return left(Failure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteUser({
    required String accessToken,
    required String userId,
  }) async {
    try {
      final result = await remoteDataSource.deleteUser(
        accessToken: accessToken,
        userId: userId,
      );
      return right(result);
    } on ServerException catch (error) {
      return left(Failure(error.message));
    } catch (error) {
      return left(Failure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> updateUserRole({
    required String accessToken,
    required String userId,
    required String role,
  }) async {
    try {
      final result = await remoteDataSource.updateUserRole(
        accessToken: accessToken,
        userId: userId,
        role: role,
      );
      return right(result);
    } on ServerException catch (error) {
      return left(Failure(error.message));
    } catch (error) {
      return left(Failure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, String?>> resetUserPassword({
    required String accessToken,
    required String userId,
  }) async {
    try {
      final defaultPassword = await remoteDataSource.resetUserPassword(
        accessToken: accessToken,
        userId: userId,
      );
      return right(defaultPassword);
    } on ServerException catch (error) {
      return left(Failure(error.message));
    } catch (error) {
      return left(Failure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> exchangeIdToken({
    required String idToken,
  }) async {
    try {
      final result = await remoteDataSource.exchangeIdToken(idToken: idToken);
      return right(result);
    } on ServerException catch (error) {
      return left(Failure(error.message));
    } catch (error) {
      return left(Failure(error.toString()));
    }
  }
}
