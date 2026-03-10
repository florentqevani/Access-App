import 'package:access_app/domain/repository/auth_session.dart';

abstract interface class RemoteDataSource {
  Future<AuthSession> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  });
  Future<AuthSession> loginWithEmail({
    required String email,
    required String password,
  });
  Future<AuthSession> refreshSession({required String refreshToken});
  Future<bool> revokeRefreshToken({required String refreshToken});
}
