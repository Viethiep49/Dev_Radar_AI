import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/repo_model.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/chat/repo_chat_screen.dart';
import '../../presentation/screens/collections/collection_detail_screen.dart';
import '../../presentation/screens/detail/repo_detail_screen.dart';
import '../../presentation/screens/main/main_navigation_screen.dart';
import '../../presentation/screens/notes/note_editor_screen.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/watchlist/watchlist_screen.dart';

class AppRouter {
  AppRouter._();

  /// Fade + slight slide used for every pushed screen.
  static CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static int? _intParam(GoRouterState state, String name) => int.tryParse(state.pathParameters[name] ?? '');

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', pageBuilder: (context, state) => _page(state, const LoginScreen())),
      GoRoute(path: '/register', pageBuilder: (context, state) => _page(state, const RegisterScreen())),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _page(state, OnboardingScreen(isEditing: state.extra is bool && state.extra as bool)),
      ),
      GoRoute(path: '/home', pageBuilder: (context, state) => _page(state, const MainNavigationScreen())),
      GoRoute(
        path: '/repo/:id',
        pageBuilder: (context, state) => _page(
          state,
          RepoDetailScreen(
            repoId: _intParam(state, 'id') ?? 0,
            initialRepo: state.extra is RepoModel ? state.extra as RepoModel : null,
          ),
        ),
        routes: [
          GoRoute(
            path: 'chat',
            // The chat needs the repo passed as extra; a deep link / web reload has none,
            // so open the detail screen instead (it has the "Hỏi đáp AI" button).
            redirect: (context, state) =>
                state.extra is RepoModel ? null : '/repo/${state.pathParameters['id']}',
            pageBuilder: (context, state) => _page(state, RepoChatScreen(repo: state.extra as RepoModel)),
          ),
        ],
      ),
      GoRoute(
        path: '/collections/:id',
        pageBuilder: (context, state) =>
            _page(state, CollectionDetailScreen(collectionId: _intParam(state, 'id') ?? 0)),
      ),
      GoRoute(
        path: '/notes/edit',
        pageBuilder: (context, state) =>
            _page(state, NoteEditorScreen(args: state.extra as NoteEditorArgs? ?? const NoteEditorArgs())),
      ),
      GoRoute(path: '/notifications', pageBuilder: (context, state) => _page(state, const NotificationsScreen())),
      GoRoute(path: '/watchlist', pageBuilder: (context, state) => _page(state, const WatchlistScreen())),
    ],
  );
}
