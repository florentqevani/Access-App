import 'package:access_app/core/errors/error.dart';
import 'package:access_app/core/use_case.dart';
import 'package:access_app/domain/repository/user_access_models.dart';
import 'package:access_app/domain/repository/user_access_repository.dart';
import 'package:fpdart/fpdart.dart';

class ExecuteUserActionUseCase
    implements UseCase<AccessActionResult, ExecuteUserActionParams> {
  final UserAccessRepository repository;

  const ExecuteUserActionUseCase(this.repository);

  @override
  Future<Either<Failure, AccessActionResult>> call(
    ExecuteUserActionParams params,
  ) async {
    return repository.executeAction(
      accessToken: params.accessToken,
      resource: params.resource,
      action: params.action,
    );
  }
}

class GetAuditLogsUseCase
    implements UseCase<List<AuditLogEntry>, GetAuditLogsParams> {
  final UserAccessRepository repository;

  const GetAuditLogsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AuditLogEntry>>> call(
    GetAuditLogsParams params,
  ) async {
    return repository.getAuditLogs(
      accessToken: params.accessToken,
      limit: params.limit,
    );
  }
}

class GetUsersUseCase implements UseCase<List<UserSummary>, GetUsersParams> {
  final UserAccessRepository repository;

  const GetUsersUseCase(this.repository);

  @override
  Future<Either<Failure, List<UserSummary>>> call(GetUsersParams params) async {
    return repository.getUsers(
      accessToken: params.accessToken,
      limit: params.limit,
    );
  }
}

class GetRolesUseCase implements UseCase<List<RoleSummary>, GetRolesParams> {
  final UserAccessRepository repository;

  const GetRolesUseCase(this.repository);

  @override
  Future<Either<Failure, List<RoleSummary>>> call(GetRolesParams params) async {
    return repository.getRoles(accessToken: params.accessToken);
  }
}

class CreateUserUseCase
    implements UseCase<UserCreationResult, CreateUserParams> {
  final UserAccessRepository repository;

  const CreateUserUseCase(this.repository);

  @override
  Future<Either<Failure, UserCreationResult>> call(
    CreateUserParams params,
  ) async {
    return repository.createUser(
      accessToken: params.accessToken,
      email: params.email,
      displayName: params.displayName,
      role: params.role,
    );
  }
}

class UpdateUserUseCase implements UseCase<bool, UpdateUserParams> {
  final UserAccessRepository repository;

  const UpdateUserUseCase(this.repository);

  @override
  Future<Either<Failure, bool>> call(UpdateUserParams params) async {
    return repository.updateUser(
      accessToken: params.accessToken,
      userId: params.userId,
      email: params.email,
      displayName: params.displayName,
    );
  }
}

class DeleteUserUseCase implements UseCase<bool, DeleteUserParams> {
  final UserAccessRepository repository;

  const DeleteUserUseCase(this.repository);

  @override
  Future<Either<Failure, bool>> call(DeleteUserParams params) async {
    return repository.deleteUser(
      accessToken: params.accessToken,
      userId: params.userId,
    );
  }
}

class UpdateUserRoleUseCase implements UseCase<bool, UpdateUserRoleParams> {
  final UserAccessRepository repository;

  const UpdateUserRoleUseCase(this.repository);

  @override
  Future<Either<Failure, bool>> call(UpdateUserRoleParams params) async {
    return repository.updateUserRole(
      accessToken: params.accessToken,
      userId: params.userId,
      role: params.role,
    );
  }
}

class ResetUserPasswordUseCase
    implements UseCase<String?, ResetUserPasswordParams> {
  final UserAccessRepository repository;

  const ResetUserPasswordUseCase(this.repository);

  @override
  Future<Either<Failure, String?>> call(ResetUserPasswordParams params) async {
    return repository.resetUserPassword(
      accessToken: params.accessToken,
      userId: params.userId,
    );
  }
}

class ExecuteUserActionParams {
  final String accessToken;
  final String resource;
  final String action;

  const ExecuteUserActionParams({
    required this.accessToken,
    required this.resource,
    required this.action,
  });
}

class GetAuditLogsParams {
  final String accessToken;
  final int limit;

  const GetAuditLogsParams({required this.accessToken, this.limit = 20});
}

class GetUsersParams {
  final String accessToken;
  final int limit;

  const GetUsersParams({required this.accessToken, this.limit = 200});
}

class GetRolesParams {
  final String accessToken;

  const GetRolesParams({required this.accessToken});
}

class CreateUserParams {
  final String accessToken;
  final String email;
  final String displayName;
  final String? role;

  const CreateUserParams({
    required this.accessToken,
    required this.email,
    required this.displayName,
    this.role,
  });
}

class UpdateUserParams {
  final String accessToken;
  final String userId;
  final String? email;
  final String? displayName;

  const UpdateUserParams({
    required this.accessToken,
    required this.userId,
    this.email,
    this.displayName,
  });
}

class DeleteUserParams {
  final String accessToken;
  final String userId;

  const DeleteUserParams({required this.accessToken, required this.userId});
}

class UpdateUserRoleParams {
  final String accessToken;
  final String userId;
  final String role;

  const UpdateUserRoleParams({
    required this.accessToken,
    required this.userId,
    required this.role,
  });
}

class ResetUserPasswordParams {
  final String accessToken;
  final String userId;

  const ResetUserPasswordParams({
    required this.accessToken,
    required this.userId,
  });
}
