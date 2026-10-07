import 'dart:convert';
import '../../core/utils/storage_service.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> login(String email, String password);
  Future<UserModel> register(String email, String password, String displayName);
  Future<UserModel?> getStoredUser();
  Future<bool> isAuthenticated();
  Future<void> logout();
  Future<void> changePassword(String oldPassword, String newPassword);
  Future<UserModel> updateAvatar(String avatarUrl);
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final StorageService storageService;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.storageService,
  });

  @override
  Future<UserModel> login(String email, String password) async {
    final authResponse = await remoteDataSource.login(email, password);
    await storageService.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    );
    await storageService.saveUserJson(jsonEncode(authResponse.user.toJson()));
    return authResponse.user;
  }

  @override
  Future<UserModel> register(String email, String password, String displayName) async {
    final authResponse = await remoteDataSource.register(email, password, displayName);
    await storageService.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    );
    await storageService.saveUserJson(jsonEncode(authResponse.user.toJson()));
    return authResponse.user;
  }

  @override
  Future<UserModel?> getStoredUser() async {
    final jsonStr = await storageService.getUserJson();
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return UserModel.fromJson(map);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await storageService.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> logout() async {
    await storageService.clearTokens();
    await storageService.clearUser();
  }

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {
    await remoteDataSource.changePassword(oldPassword, newPassword);
  }

  @override
  Future<UserModel> updateAvatar(String avatarUrl) async {
    final updatedUser = await remoteDataSource.updateAvatar(avatarUrl);
    await storageService.saveUserJson(jsonEncode(updatedUser.toJson()));
    return updatedUser;
  }
}
