import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  // Determine base URL dynamically based on platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    // For Android emulator: 10.0.2.2 points to host machine
    // For real devices or desktop: use LAN IP or localhost
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static const String apiV1 = '/api/v1';

  // Auth endpoints
  static const String login = '$apiV1/auth/login';
  static const String register = '$apiV1/auth/register';
  static const String refresh = '$apiV1/auth/refresh';
  static const String me = '$apiV1/auth/me';
  static const String changePassword = '$apiV1/auth/change-password';
  static const String avatar = '$apiV1/auth/avatar';
  static const String oauthProviders = '$apiV1/auth/oauth/providers';
  static const String googleLogin = '$apiV1/auth/google';
  static const String githubLogin = '$apiV1/auth/github';

  // GitHub OAuth redirect (must match GITHUB_REDIRECT_URI on the backend
  // and the scheme registered in AndroidManifest.xml).
  static const String oauthCallbackScheme = 'devradar';

  // Repos endpoints
  static const String repos = '$apiV1/repos';
  static const String repoSearch = '$apiV1/repos';
  static const String repoStats = '$apiV1/stats';

  // Collections endpoints
  static const String collections = '$apiV1/collections';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Storage keys
  static const String accessTokenKey = 'devradar_access_token';
  static const String refreshTokenKey = 'devradar_refresh_token';
  static const String userKey = 'devradar_current_user';
  static const String themeModeKey = 'devradar_theme_mode';
}
