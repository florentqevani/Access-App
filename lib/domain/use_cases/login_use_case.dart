import 'package:access_app/core/use_case.dart';
import 'package:access_app/domain/repository/auth_repository.dart';
import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/core/errors/error.dart';
import 'package:fpdart/fpdart.dart';

class LoginUseCase implements UseCase<AuthSession, LoginParams> {
  final AuthRepository authRepository;

  const LoginUseCase(this.authRepository);

  @override
  Future<Either<Failure, AuthSession>> call(LoginParams params) async {
    return await authRepository.signinWithEmail(
      email: params.email,
      password: params.password,
    );
  }
}

class LoginParams {
  final String email;
  final String password;

  const LoginParams({required this.email, required this.password});
}
