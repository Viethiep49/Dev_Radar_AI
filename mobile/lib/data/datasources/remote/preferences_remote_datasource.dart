import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Raw JSON from /preferences and /repos/filters (choices for the onboarding chips).
abstract class PreferencesRemoteDataSource {
  Future<Map<String, dynamic>> getPreferences();
  Future<Map<String, dynamic>> savePreferences({required List<String> languages, required List<String> topics});
  Future<Map<String, dynamic>> getFilterOptions();
}

class PreferencesRemoteDataSourceImpl implements PreferencesRemoteDataSource {
  final ApiClient apiClient;

  PreferencesRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> getPreferences() async {
    final response = await apiClient.get(ApiConstants.preferences);
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> savePreferences({
    required List<String> languages,
    required List<String> topics,
  }) async {
    final response = await apiClient.put(
      ApiConstants.preferences,
      data: {'languages': languages, 'topics': topics},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getFilterOptions() async {
    final response = await apiClient.get(ApiConstants.repoFilters);
    return response.data as Map<String, dynamic>;
  }
}
