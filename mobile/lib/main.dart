import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/storage_service.dart';
import 'data/datasources/local/cache_local_datasource.dart';
import 'data/datasources/remote/auth_remote_datasource.dart';
import 'data/datasources/remote/chat_remote_datasource.dart';
import 'data/datasources/remote/collection_remote_datasource.dart';
import 'data/datasources/remote/learning_remote_datasource.dart';
import 'data/datasources/remote/note_remote_datasource.dart';
import 'data/datasources/remote/notification_remote_datasource.dart';
import 'data/datasources/remote/preferences_remote_datasource.dart';
import 'data/datasources/remote/repo_remote_datasource.dart';
import 'data/datasources/remote/stats_remote_datasource.dart';
import 'data/datasources/remote/watchlist_remote_datasource.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/collection_repository.dart';
import 'data/repositories/learning_repository.dart';
import 'data/repositories/note_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/preferences_repository.dart';
import 'data/repositories/repo_repository.dart';
import 'data/repositories/stats_repository.dart';
import 'data/repositories/watchlist_repository.dart';
import 'data/services/release_alert_service.dart';
import 'presentation/state/auth/auth_bloc.dart';
import 'presentation/state/auth/auth_event.dart';
import 'presentation/state/auth/auth_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();
  await ThemeController.init();

  // SQLite cache on phones; sqflite has no web implementation, so web keeps it in memory.
  final CacheLocalDataSource cache = kIsWeb
      ? MemoryCacheLocalDataSource()
      : SqliteCacheLocalDataSource(await AppDatabase.open());

  final localNotifications = LocalNotificationService();
  await localNotifications.init();

  final apiClient = ApiClient(storageService: storageService);

  final notificationRepository = NotificationRepositoryImpl(
    remoteDataSource: NotificationRemoteDataSourceImpl(apiClient: apiClient),
    cache: cache,
  );

  runApp(
    DevRadarApp(
      apiClient: apiClient,
      storageService: storageService,
      cache: cache,
      localNotifications: localNotifications,
      authRepository: AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSourceImpl(apiClient: apiClient),
        storageService: storageService,
        cache: cache,
      ),
      repoRepository: RepoRepositoryImpl(
        remoteDataSource: RepoRemoteDataSourceImpl(apiClient: apiClient),
        cache: cache,
      ),
      chatRepository: ChatRepositoryImpl(
        remoteDataSource: ChatRemoteDataSourceImpl(apiClient: apiClient),
        cache: cache,
      ),
      collectionRepository: CollectionRepositoryImpl(
        remoteDataSource: CollectionRemoteDataSourceImpl(apiClient: apiClient),
        cache: cache,
      ),
      noteRepository: NoteRepositoryImpl(
        remoteDataSource: NoteRemoteDataSourceImpl(apiClient: apiClient),
        cache: cache,
      ),
      learningRepository: LearningRepositoryImpl(
        remoteDataSource: LearningRemoteDataSourceImpl(apiClient: apiClient),
        cache: cache,
      ),
      watchlistRepository: WatchlistRepositoryImpl(
        remoteDataSource: WatchlistRemoteDataSourceImpl(apiClient: apiClient),
        cache: cache,
      ),
      statsRepository: StatsRepositoryImpl(
        remoteDataSource: StatsRemoteDataSourceImpl(apiClient: apiClient),
        cache: cache,
      ),
      preferencesRepository: PreferencesRepositoryImpl(
        remoteDataSource: PreferencesRemoteDataSourceImpl(apiClient: apiClient),
        cache: cache,
      ),
      notificationRepository: notificationRepository,
      releaseAlertService: ReleaseAlertService(
        notificationRepository: notificationRepository,
        localNotifications: localNotifications,
        storage: storageService,
      ),
    ),
  );
}

/// Composition root: provides every repository/service to the widget tree.
/// Screens create their own blocs/cubits from these (UI -> Bloc -> Repository).
class DevRadarApp extends StatefulWidget {
  final ApiClient apiClient;
  final StorageService storageService;
  final CacheLocalDataSource cache;
  final LocalNotificationService localNotifications;
  final AuthRepository authRepository;
  final RepoRepository repoRepository;
  final ChatRepository chatRepository;
  final CollectionRepository collectionRepository;
  final NoteRepository noteRepository;
  final LearningRepository learningRepository;
  final WatchlistRepository watchlistRepository;
  final StatsRepository statsRepository;
  final PreferencesRepository preferencesRepository;
  final NotificationRepository notificationRepository;
  final ReleaseAlertService releaseAlertService;

  const DevRadarApp({
    super.key,
    required this.apiClient,
    required this.storageService,
    required this.cache,
    required this.localNotifications,
    required this.authRepository,
    required this.repoRepository,
    required this.chatRepository,
    required this.collectionRepository,
    required this.noteRepository,
    required this.learningRepository,
    required this.watchlistRepository,
    required this.statsRepository,
    required this.preferencesRepository,
    required this.notificationRepository,
    required this.releaseAlertService,
  });

  @override
  State<DevRadarApp> createState() => _DevRadarAppState();
}

class _DevRadarAppState extends State<DevRadarApp> with WidgetsBindingObserver {
  late final AuthBloc _authBloc = AuthBloc(
    authRepository: widget.authRepository,
    sessionExpired: widget.apiClient.sessionExpired,
  )..add(AuthCheckRequested()); // restore the session even when a deep link skips the splash screen
  StreamSubscription<int?>? _notificationTapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tapping a local notification about a repo opens its detail screen.
    _notificationTapSubscription = widget.localNotifications.onRepoTapped.listen(_openFromNotification);
    // The app may have been started by tapping a notification.
    final launchRepoId = widget.localNotifications.takeLaunchRepoId();
    if (launchRepoId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotification(launchRepoId));
    }
  }

  void _openFromNotification(int? repoId) {
    if (_authBloc.state is! AuthAuthenticated) return;
    AppRouter.router.push(repoId == null ? '/notifications' : '/repo/$repoId');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkReleases();
    }
  }

  /// Shows a local notification for new releases of watched repos (in place of FCM push).
  void _checkReleases() {
    if (_authBloc.state is AuthAuthenticated) {
      unawaited(widget.releaseAlertService.checkForNewReleases()); // never throws
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTapSubscription?.cancel();
    _authBloc.close();
    widget.apiClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>.value(value: widget.apiClient),
        RepositoryProvider<StorageService>.value(value: widget.storageService),
        RepositoryProvider<CacheLocalDataSource>.value(value: widget.cache),
        RepositoryProvider<LocalNotificationService>.value(value: widget.localNotifications),
        RepositoryProvider<AuthRepository>.value(value: widget.authRepository),
        RepositoryProvider<RepoRepository>.value(value: widget.repoRepository),
        RepositoryProvider<ChatRepository>.value(value: widget.chatRepository),
        RepositoryProvider<CollectionRepository>.value(value: widget.collectionRepository),
        RepositoryProvider<NoteRepository>.value(value: widget.noteRepository),
        RepositoryProvider<LearningRepository>.value(value: widget.learningRepository),
        RepositoryProvider<WatchlistRepository>.value(value: widget.watchlistRepository),
        RepositoryProvider<StatsRepository>.value(value: widget.statsRepository),
        RepositoryProvider<PreferencesRepository>.value(value: widget.preferencesRepository),
        RepositoryProvider<NotificationRepository>.value(value: widget.notificationRepository),
        RepositoryProvider<ReleaseAlertService>.value(value: widget.releaseAlertService),
      ],
      child: BlocProvider<AuthBloc>.value(
        value: _authBloc,
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              _checkReleases();
            } else if (state is AuthUnauthenticated && state.sessionExpired) {
              AppRouter.router.go('/login');
            }
          },
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
      ),
    );
  }
}
