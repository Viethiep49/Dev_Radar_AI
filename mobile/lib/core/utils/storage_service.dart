import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;

  StorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(ApiConstants.accessTokenKey, accessToken);
    if (refreshToken != null) {
      await _prefs!.setString(ApiConstants.refreshTokenKey, refreshToken);
    }

    if (!kIsWeb) {
      try {
        await _secureStorage.write(key: ApiConstants.accessTokenKey, value: accessToken);
        if (refreshToken != null) {
          await _secureStorage.write(key: ApiConstants.refreshTokenKey, value: refreshToken);
        }
      } catch (_) {}
    }
  }

  Future<String?> getAccessToken() async {
    _prefs ??= await SharedPreferences.getInstance();
    final token = _prefs!.getString(ApiConstants.accessTokenKey);
    if (token != null && token.isNotEmpty) {
      return token;
    }

    if (!kIsWeb) {
      try {
        return await _secureStorage.read(key: ApiConstants.accessTokenKey);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<String?> getRefreshToken() async {
    _prefs ??= await SharedPreferences.getInstance();
    final token = _prefs!.getString(ApiConstants.refreshTokenKey);
    if (token != null && token.isNotEmpty) {
      return token;
    }

    if (!kIsWeb) {
      try {
        return await _secureStorage.read(key: ApiConstants.refreshTokenKey);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearTokens() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(ApiConstants.accessTokenKey);
    await _prefs!.remove(ApiConstants.refreshTokenKey);

    if (!kIsWeb) {
      try {
        await _secureStorage.delete(key: ApiConstants.accessTokenKey);
        await _secureStorage.delete(key: ApiConstants.refreshTokenKey);
      } catch (_) {}
    }
  }

  Future<void> saveUserJson(String userJson) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(ApiConstants.userKey, userJson);
  }

  Future<String?> getUserJson() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getString(ApiConstants.userKey);
  }

  Future<void> clearUser() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(ApiConstants.userKey);
  }
}
