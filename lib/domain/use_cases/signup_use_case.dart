import 'package:access_app/core/errors/error.dart';
import 'package:access_app/core/use_case.dart';
import 'package:access_app/domain/repository/auth_repository.dart';
import 'package:access_app/domain/repository/auth_session.dart';
import 'package:fpdart/fpdart.dart';

class SignUpUseCase implements UseCase<AuthSession, SignUpParams> {
  final AuthRepository authRepository;

  const SignUpUseCase(this.authRepository);

  @override
  Future<Either<Failure, AuthSession>> call(SignUpParams params) async {
    return await authRepository.signupWithEmail(
      name: params.name,
      email: params.email,
      password: params.password,
    );
  }
}

class SignUpParams {
  final String name;
  final String email;
  final String password;

  const SignUpParams({
    required this.name,
    required this.email,
    required this.password,
  });
}
