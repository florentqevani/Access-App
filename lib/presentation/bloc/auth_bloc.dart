import 'package:access_app/domain/use_cases/login_use_case.dart';
import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/domain/use_cases/refresh_session_use_case.dart';
import 'package:access_app/domain/use_cases/revoke_refresh_token_use_case.dart';
import 'package:access_app/domain/use_cases/signup_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class AuthEvent {}

class AuthSignIn extends AuthEvent {
  final String email;
  final String password;

  AuthSignIn({required this.email, required this.password});
}

class AuthSignUp extends AuthEvent {
  final String name;
  final String email;
  final String password;

  AuthSignUp({required this.name, required this.email, required this.password});
}

class AuthRefreshSession extends AuthEvent {
  final String refreshToken;

  AuthRefreshSession({required this.refreshToken});
}

class AuthRevokeSession extends AuthEvent {
  final String refreshToken;

  AuthRevokeSession({required this.refreshToken});
}

sealed class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final AuthSession session;

  AuthAuthenticated(this.session);
}

class AuthFailure extends AuthState {
  final String message;

  AuthFailure(this.message);
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _login;
  final SignUpUseCase _signup;
  final RefreshSessionUseCase _refreshSession;
  final RevokeRefreshTokenUseCase _revokeRefreshToken;

  AuthBloc({
    required LoginUseCase loginUseCase,
    required SignUpUseCase signUpUseCase,
    required RefreshSessionUseCase refreshSessionUseCase,
    required RevokeRefreshTokenUseCase revokeRefreshTokenUseCase,
  }) : _login = loginUseCase,
       _signup = signUpUseCase,
       _refreshSession = refreshSessionUseCase,
       _revokeRefreshToken = revokeRefreshTokenUseCase,
       super(AuthInitial()) {
    on<AuthSignIn>((event, emit) async {
      try {
        emit(AuthLoading());
        final response = await _login(
          LoginParams(email: event.email, password: event.password),
        );
        await response.fold(
          (failure) async => emit(AuthFailure(failure.message)),
          (session) async => emit(AuthAuthenticated(session)),
        );
      } catch (error) {
        emit(AuthFailure(error.toString()));
      }
    });

    on<AuthSignUp>((event, emit) async {
      try {
        emit(AuthLoading());
        final response = await _signup(
          SignUpParams(
            name: event.name,
            email: event.email,
            password: event.password,
          ),
        );
        await response.fold(
          (failure) async => emit(AuthFailure(failure.message)),
          (session) async => emit(AuthAuthenticated(session)),
        );
      } catch (error) {
        emit(AuthFailure(error.toString()));
      }
    });

    on<AuthRefreshSession>((event, emit) async {
      try {
        emit(AuthLoading());
        final response = await _refreshSession(
          RefreshSessionParams(refreshToken: event.refreshToken),
        );
        await response.fold(
          (failure) async => emit(AuthFailure(failure.message)),
          (session) async => emit(AuthAuthenticated(session)),
        );
      } catch (error) {
        emit(AuthFailure(error.toString()));
      }
    });

    on<AuthRevokeSession>((event, emit) async {
      try {
        emit(AuthLoading());
        final response = await _revokeRefreshToken(
          RevokeRefreshTokenParams(refreshToken: event.refreshToken),
        );
        await response.fold(
          (failure) async => emit(AuthFailure(failure.message)),
          (_) async => emit(AuthInitial()),
        );
      } catch (error) {
        emit(AuthFailure(error.toString()));
      }
    });
  }
}
