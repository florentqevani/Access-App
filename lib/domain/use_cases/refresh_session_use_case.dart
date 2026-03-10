import 'package:access_app/core/errors/error.dart';
import 'package:access_app/core/use_case.dart';
import 'package:access_app/domain/repository/auth_repository.dart';
import 'package:access_app/domain/repository/auth_session.dart';
import 'package:fpdart/fpdart.dart';

class RefreshSessionUseCase
    implements UseCase<AuthSession, RefreshSessionParams> {
  final AuthRepository authRepository;

  const RefreshSessionUseCase(this.authRepository);

  @override
  Future<Either<Failure, AuthSession>> call(
    RefreshSessionParams params,
  ) async {
    return authRepository.refreshSession(refreshToken: params.refreshToken);
  }
}

class RefreshSessionParams {
  final String refreshToken;

  const RefreshSessionParams({required this.refreshToken});
}
