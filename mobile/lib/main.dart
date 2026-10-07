import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/network/api_client.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/storage_service.dart';
import 'data/datasources/remote/auth_remote_datasource.dart';
import 'data/datasources/remote/repo_remote_datasource.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/repo_repository.dart';
import 'presentation/state/auth/auth_bloc.dart';
import 'presentation/state/repo/repo_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();
  await ThemeController.init();

  final apiClient = ApiClient(storageService: storageService);

  final authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient: apiClient);
  final repoRemoteDataSource = RepoRemoteDataSourceImpl(apiClient: apiClient);

  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    storageService: storageService,
  );

  final repoRepository = RepoRepositoryImpl(
    remoteDataSource: repoRemoteDataSource,
  );

  runApp(
    DevRadarApp(
      authRepository: authRepository,
      repoRepository: repoRepository,
    ),
  );
}

class DevRadarApp extends StatelessWidget {
  final AuthRepository authRepository;
  final RepoRepository repoRepository;

  const DevRadarApp({
    super.key,
    required this.authRepository,
    required this.repoRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<RepoRepository>.value(value: repoRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(authRepository: authRepository),
          ),
          BlocProvider<RepoBloc>(
            create: (context) => RepoBloc(repoRepository: repoRepository),
          ),
        ],
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.themeModeNotifier,
          builder: (context, themeMode, _) {
            return MaterialApp.router(
              title: 'DevRadar AI',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              routerConfig: AppRouter.router,
            );
          },
        ),
      ),
    );
  }
}
