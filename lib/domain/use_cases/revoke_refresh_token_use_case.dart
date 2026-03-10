import 'package:access_app/core/errors/error.dart';
import 'package:access_app/core/use_case.dart';
import 'package:access_app/domain/repository/auth_repository.dart';
import 'package:fpdart/fpdart.dart';

class RevokeRefreshTokenUseCase
    implements UseCase<bool, RevokeRefreshTokenParams> {
  final AuthRepository authRepository;

  const RevokeRefreshTokenUseCase(this.authRepository);

  @override
  Future<Either<Failure, bool>> call(
    RevokeRefreshTokenParams params,
  ) async {
    return authRepository.revokeRefreshToken(refreshToken: params.refreshToken);
  }
}

class RevokeRefreshTokenParams {
  final String refreshToken;

  const RevokeRefreshTokenParams({required this.refreshToken});
}
