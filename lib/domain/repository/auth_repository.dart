import 'package:access_app/core/errors/error.dart';
import 'package:fpdart/fpdart.dart';
import 'package:access_app/domain/repository/auth_session.dart';

abstract interface class AuthRepository {
  Future<Either<Failure, AuthSession>> signupWithEmail({
    required String name,
    required String email,
    required String password,
  });

  Future<Either<Failure, AuthSession>> signinWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, AuthSession>> refreshSession({
    required String refreshToken,
  });

  Future<Either<Failure, bool>> revokeRefreshToken({
    required String refreshToken,
  });
}
