import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/api_constants.dart';
import '../models/oauth_providers_model.dart';

/// Thrown when a social login cannot start or did not finish.
/// [cancelled] is true when the user simply closed the Google/GitHub screen.
class SocialAuthException implements Exception {
  final String message;
  final bool cancelled;

  const SocialAuthException(this.message, {this.cancelled = false});

  @override
  String toString() => message;
}

/// Result of the GitHub web flow: what POST /auth/github needs.
class GitHubAuthCode {
  final String code;
  final String codeVerifier;

  const GitHubAuthCode({required this.code, required this.codeVerifier});
}

/// Talks to Google / GitHub only. The tokens it returns are sent to the backend,
/// which verifies them and issues the app's own JWTs (see backend/docs/OAUTH_LOGIN.md).
/// Client IDs come from the backend (/auth/oauth/providers), so nothing is hard-coded here.
class SocialAuthService {
  bool _googleInitialized = false;

  /// Google sign-in -> Google ID token (audience = the Web client ID from the backend).
  Future<String> googleIdToken(OAuthProvidersModel providers) async {
    final clientId = providers.googleClientId;
    if (!providers.googleEnabled || clientId == null) {
      throw const SocialAuthException('Đăng nhập Google chưa được cấu hình trên server');
    }
    final google = GoogleSignIn.instance;
    if (!_googleInitialized) {
      // Web: the Web client ID is the clientId. Android/iOS: it is the serverClientId,
      // so the ID token is issued for the backend.
      await google.initialize(
        clientId: kIsWeb ? clientId : null,
        serverClientId: kIsWeb ? null : clientId,
      );
      _googleInitialized = true;
    }
    if (!google.supportsAuthenticate()) {
      throw const SocialAuthException(
        'Đăng nhập Google chưa hỗ trợ trên nền tảng này, hãy dùng app Android/iOS',
      );
    }

    try {
      final account = await google.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const SocialAuthException('Google không trả về ID token');
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialAuthException('Đã huỷ đăng nhập Google', cancelled: true);
      }
      throw SocialAuthException('Đăng nhập Google thất bại: ${e.description ?? e.code.name}');
    }
  }

  /// GitHub OAuth web flow with PKCE + state -> authorization code.
  Future<GitHubAuthCode> githubCode(OAuthProvidersModel providers) async {
    final clientId = providers.githubClientId;
    final redirectUri = providers.githubRedirectUri;
    if (!providers.githubEnabled || clientId == null || redirectUri == null) {
      throw const SocialAuthException('Đăng nhập GitHub chưa được cấu hình trên server');
    }
    if (kIsWeb) {
      throw const SocialAuthException(
        'Đăng nhập GitHub chưa hỗ trợ trên web, hãy dùng app Android/iOS',
      );
    }
    final callbackScheme = Uri.parse(redirectUri).scheme;
    if (callbackScheme != ApiConstants.oauthCallbackScheme) {
      throw SocialAuthException(
        'GITHUB_REDIRECT_URI phải dùng scheme "${ApiConstants.oauthCallbackScheme}://", hiện là "$redirectUri"',
      );
    }

    final state = _randomString(32);
    final codeVerifier = _randomString(64);
    final codeChallenge =
        base64Url.encode(sha256.convert(ascii.encode(codeVerifier)).bytes).replaceAll('=', '');

    final authorizeUrl = Uri.parse(providers.githubAuthorizeUrl).replace(queryParameters: {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': providers.githubScope,
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });

    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authorizeUrl.toString(),
        callbackUrlScheme: callbackScheme,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') {
        throw const SocialAuthException('Đã huỷ đăng nhập GitHub', cancelled: true);
      }
      throw SocialAuthException('Không mở được trang đăng nhập GitHub: ${e.message ?? e.code}');
    }

    final params = Uri.parse(result).queryParameters;
    if (params['state'] != state) {
      throw const SocialAuthException('Phản hồi GitHub không hợp lệ (state không khớp)');
    }
    final error = params['error'];
    if (error != null) {
      final denied = error == 'access_denied';
      throw SocialAuthException(
        denied ? 'Bạn đã từ chối quyền truy cập GitHub' : 'GitHub báo lỗi: $error',
        cancelled: denied,
      );
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw const SocialAuthException('GitHub không trả về mã đăng nhập');
    }
    return GitHubAuthCode(code: code, codeVerifier: codeVerifier);
  }

  /// Sign out of Google too, so the next login can pick another account.
  Future<void> signOut() async {
    if (!_googleInitialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  static const _charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  static String _randomString(int length) {
    final random = Random.secure();
    return List.generate(length, (_) => _charset[random.nextInt(_charset.length)]).join();
  }
}
