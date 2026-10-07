import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../models/auth_response_model.dart';
import '../../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login(String email, String password);
  Future<AuthResponseModel> register(String email, String password, String displayName);
  Future<UserModel> getMe();
  Future<void> changePassword(String oldPassword, String newPassword);
  Future<UserModel> updateAvatar(String avatarUrl);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    final response = await apiClient.post(
      ApiConstants.login,
      data: {
        'email': email,
        'password': password,
      },
    );
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AuthResponseModel> register(String email, String password, String displayName) async {
    final response = await apiClient.post(
      ApiConstants.register,
      data: {
        'email': email,
        'password': password,
        'display_name': displayName,
      },
    );
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<UserModel> getMe() async {
    final response = await apiClient.get(ApiConstants.me);
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {
    await apiClient.post(
      '/auth/change-password',
      data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );
  }

  @override
  Future<UserModel> updateAvatar(String avatarUrl) async {
    final response = await apiClient.put(
      '/auth/avatar',
      data: {
        'avatar_url': avatarUrl,
      },
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }
}
