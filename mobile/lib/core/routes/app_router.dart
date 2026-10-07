import 'package:go_router/go_router.dart';
import '../../data/models/repo_model.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/chat/repo_chat_screen.dart';
import '../../presentation/screens/detail/repo_detail_screen.dart';
import '../../presentation/screens/main/main_navigation_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: '/repo-detail',
        builder: (context, state) {
          final repo = state.extra as RepoModel;
          return RepoDetailScreen(repo: repo);
        },
      ),
      GoRoute(
        path: '/repo-chat',
        builder: (context, state) {
          final repo = state.extra as RepoModel;
          return RepoChatScreen(repo: repo);
        },
      ),
    ],
  );
}
