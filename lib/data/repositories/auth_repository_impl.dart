import 'package:access_app/core/errors/error.dart';
import 'package:access_app/core/errors/server_exception.dart';
import 'package:access_app/data/data_source/remote_data_source.dart';
import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/domain/repository/auth_repository.dart';
import 'package:fpdart/fpdart.dart';

class AuthRepositoryImpl implements AuthRepository {
  final RemoteDataSource remoteDataSource;

  const AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, AuthSession>> refreshSession({
    required String refreshToken,
  }) async {
    try {
      final session = await remoteDataSource.refreshSession(
        refreshToken: refreshToken,
      );
      return right(session);
    } on ServerException catch (e) {
      return left(Failure(e.message));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> revokeRefreshToken({
    required String refreshToken,
  }) async {
    try {
      final result = await remoteDataSource.revokeRefreshToken(
        refreshToken: refreshToken,
      );
      return right(result);
    } on ServerException catch (e) {
      return left(Failure(e.message));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthSession>> signinWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final session = await remoteDataSource.loginWithEmail(
        email: email,
        password: password,
      );
      return right(session);
    } on ServerException catch (e) {
      return left(Failure(e.message));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthSession>> signupWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final session = await remoteDataSource.signUpWithEmail(
        name: name,
        email: email,
        password: password,
      );
      return right(session);
    } on ServerException catch (e) {
      return left(Failure(e.message));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }
}
