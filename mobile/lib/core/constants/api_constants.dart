import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  /// Override with `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080`
  /// when running on a real phone in the same LAN as the backend.
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      return _baseUrlOverride;
    }
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    // Android emulator: 10.0.2.2 points to the host machine.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  /// Absolute URL for a path the backend returned relative (video URLs are).
  static String absoluteUrl(String path) => '$baseUrl$path';

  static const String apiV1 = '/api/v1';

  // Auth
  static const String login = '$apiV1/auth/login';
  static const String register = '$apiV1/auth/register';
  static const String refresh = '$apiV1/auth/refresh';
  static const String me = '$apiV1/auth/me';
  static const String changePassword = '$apiV1/auth/change-password';
  static const String avatar = '$apiV1/auth/avatar';
  static const String oauthProviders = '$apiV1/auth/oauth/providers';
  static const String googleLogin = '$apiV1/auth/google';
  static const String githubLogin = '$apiV1/auth/github';
  static const String deviceTokens = '$apiV1/auth/device-tokens';

  // GitHub OAuth redirect (must match GITHUB_REDIRECT_URI on the backend
  // and the scheme registered in AndroidManifest.xml).
  static const String oauthCallbackScheme = 'devradar';

  // Repos: GET repos (search + filter + sort), GET repos/feed (personalised),
  // GET repos/filters, GET repos/{id}, GET repos/{id}/summary, GET repos/{id}/stars
  static const String repos = '$apiV1/repos';
  static const String repoFeed = '$apiV1/repos/feed';
  static const String repoFilters = '$apiV1/repos/filters';

  // Chat with a repo: POST/GET/DELETE chat/{repoId}
  static const String chat = '$apiV1/chat';

  // Personal data
  static const String preferences = '$apiV1/preferences';
  static const String collections = '$apiV1/collections';
  static const String notes = '$apiV1/notes';
  static const String learning = '$apiV1/learning';
  static const String watchlist = '$apiV1/watchlist';
  static const String notifications = '$apiV1/notifications';
  static const String notificationsUnreadCount = '$apiV1/notifications/unread-count';
  static const String notificationsReadAll = '$apiV1/notifications/read-all';

  // Statistics
  static const String statsOverview = '$apiV1/stats/overview';
  static const String statsWeekly = '$apiV1/stats/weekly';
  static const String statsLanguages = '$apiV1/stats/languages';

  // Roadmap video: POST videos/roadmap (renders, blocks), GET videos/{jobId} (public MP4)
  static const String videos = '$apiV1/videos';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30); // AI chat answers can be slow

  /// For the two calls that block server-side for minutes: generating a summary
  /// (AI reads a whole README) and rendering a video. Set above the backend's own
  /// ceilings so the backend's error arrives instead of a client-side timeout.
  static const Duration slowRequestTimeout = Duration(seconds: 330);

  // Storage keys
  static const String accessTokenKey = 'devradar_access_token';
  static const String refreshTokenKey = 'devradar_refresh_token';
  static const String userKey = 'devradar_current_user';
  static const String themeModeKey = 'devradar_theme_mode';
  static const String onboardingDoneKey = 'devradar_onboarding_done';
}
