import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';

/// Tokens: flutter_secure_storage (Android Keystore / iOS Keychain) on phones.
/// On web there is no secure storage, so SharedPreferences (localStorage) is used.
/// Non-secret things (cached user profile, flags) always go to SharedPreferences.
class StorageService {
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;

  StorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!kIsWeb) {
      await _migratePlainTokens();
    }
  }

  Future<SharedPreferences> get _p async => _prefs ??= await SharedPreferences.getInstance();

  /// Older builds also kept the tokens in SharedPreferences (plain text). Move them.
  Future<void> _migratePlainTokens() async {
    final prefs = await _p;
    for (final key in [ApiConstants.accessTokenKey, ApiConstants.refreshTokenKey]) {
      final value = prefs.getString(key);
      if (value == null) continue;
      try {
        if (await _secureStorage.read(key: key) == null) {
          await _secureStorage.write(key: key, value: value);
        }
        await prefs.remove(key);
      } catch (_) {}
    }
  }

  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      await (await _p).setString(key, value);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    if (kIsWeb) {
      return (await _p).getString(key);
    }
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _delete(String key) async {
    if (kIsWeb) {
      await (await _p).remove(key);
    } else {
      try {
        await _secureStorage.delete(key: key);
      } catch (_) {}
    }
  }

  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    await _write(ApiConstants.accessTokenKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _write(ApiConstants.refreshTokenKey, refreshToken);
    }
  }

  Future<String?> getAccessToken() => _read(ApiConstants.accessTokenKey);

  Future<String?> getRefreshToken() => _read(ApiConstants.refreshTokenKey);

  Future<void> clearTokens() async {
    await _delete(ApiConstants.accessTokenKey);
    await _delete(ApiConstants.refreshTokenKey);
  }

  Future<void> saveUserJson(String userJson) async {
    await (await _p).setString(ApiConstants.userKey, userJson);
  }

  Future<String?> getUserJson() async => (await _p).getString(ApiConstants.userKey);

  Future<void> clearUser() async {
    await (await _p).remove(ApiConstants.userKey);
  }

  /// Onboarding (choose languages/topics) is shown once per user id.
  Future<bool> isOnboardingDone(int userId) async =>
      (await _p).getBool('${ApiConstants.onboardingDoneKey}_$userId') ?? false;

  Future<void> setOnboardingDone(int userId) async {
    await (await _p).setBool('${ApiConstants.onboardingDoneKey}_$userId', true);
  }

  /// Generic helpers for small settings (notification toggles, reminder time...).
  Future<bool?> getBool(String key) async => (await _p).getBool(key);
  Future<void> setBool(String key, bool value) async => (await _p).setBool(key, value);
  Future<int?> getInt(String key) async => (await _p).getInt(key);
  Future<void> setInt(String key, int value) async => (await _p).setInt(key, value);
}
