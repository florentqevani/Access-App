import 'package:access_app/core/theme/theme.dart';
import 'package:access_app/core/network/auth_server_config.dart';
import 'package:access_app/data/data_source/remote_data_source_impl.dart';
import 'package:access_app/data/data_source/user_access_remote_data_source_impl.dart';
import 'package:access_app/data/repositories/auth_repository_impl.dart';
import 'package:access_app/data/repositories/user_access_repository_impl.dart';
import 'package:access_app/domain/use_cases/login_use_case.dart';
import 'package:access_app/domain/use_cases/refresh_session_use_case.dart';
import 'package:access_app/domain/use_cases/revoke_refresh_token_use_case.dart';
import 'package:access_app/domain/use_cases/signup_use_case.dart';
import 'package:access_app/domain/use_cases/user_access_use_cases.dart';
import 'package:access_app/presentation/bloc/auth_bloc.dart';
import 'package:access_app/presentation/pages/login_page.dart';
import 'package:access_app/firebase_options.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    runApp(FirebaseErrorApp(error: e.toString()));
    return;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseAuth = FirebaseAuth.instance;
    final dio = Dio();
    const configuredAuthServerBaseUrl = String.fromEnvironment(
      'AUTH_SERVER_BASE_URL',
    );
    final authServerBaseUrl = resolveAuthServerBaseUrl(
      configuredBaseUrl: configuredAuthServerBaseUrl,
    );
    final remoteDataSource = RemoteDataSourceImpl(
      firebaseAuth: firebaseAuth,
      authServerBaseUrl: authServerBaseUrl,
      dio: dio,
    );
    final repository = AuthRepositoryImpl(remoteDataSource);
    final loginUseCase = LoginUseCase(repository);
    final signupUseCase = SignUpUseCase(repository);
    final refreshSessionUseCase = RefreshSessionUseCase(repository);
    final revokeRefreshTokenUseCase = RevokeRefreshTokenUseCase(repository);
    final userAccessRemoteDataSource = UserAccessRemoteDataSourceImpl(
      dio: dio,
      authServerBaseUrl: authServerBaseUrl,
    );
    final userAccessRepository = UserAccessRepositoryImpl(
      userAccessRemoteDataSource,
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ExecuteUserActionUseCase>(
          create: (_) => ExecuteUserActionUseCase(userAccessRepository),
        ),
        RepositoryProvider<GetAuditLogsUseCase>(
          create: (_) => GetAuditLogsUseCase(userAccessRepository),
        ),
        RepositoryProvider<GetUsersUseCase>(
          create: (_) => GetUsersUseCase(userAccessRepository),
        ),
        RepositoryProvider<GetRolesUseCase>(
          create: (_) => GetRolesUseCase(userAccessRepository),
        ),
        RepositoryProvider<CreateUserUseCase>(
          create: (_) => CreateUserUseCase(userAccessRepository),
        ),
        RepositoryProvider<UpdateUserUseCase>(
          create: (_) => UpdateUserUseCase(userAccessRepository),
        ),
        RepositoryProvider<DeleteUserUseCase>(
          create: (_) => DeleteUserUseCase(userAccessRepository),
        ),
        RepositoryProvider<UpdateUserRoleUseCase>(
          create: (_) => UpdateUserRoleUseCase(userAccessRepository),
        ),
        RepositoryProvider<ResetUserPasswordUseCase>(
          create: (_) => ResetUserPasswordUseCase(userAccessRepository),
        ),
        RepositoryProvider<ExchangeIdTokenUseCase>(
          create: (_) => ExchangeIdTokenUseCase(userAccessRepository),
        ),
      ],
      child: BlocProvider(
        create: (context) => AuthBloc(
          loginUseCase: loginUseCase,
          signUpUseCase: signupUseCase,
          refreshSessionUseCase: refreshSessionUseCase,
          revokeRefreshTokenUseCase: revokeRefreshTokenUseCase,
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Access App',
          theme: AppTheme.darkMode,
          home: const LoginPage(),
        ),
      ),
    );
  }
}

class FirebaseErrorApp extends StatelessWidget {
  final String error;

  const FirebaseErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Setup Required',
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Firebase is not initialized',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add Firebase platform config files and run flutterfire configure.',
                ),
                const SizedBox(height: 24),
                Text(error, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
