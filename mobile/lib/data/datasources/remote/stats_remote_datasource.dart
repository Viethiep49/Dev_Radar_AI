import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Raw JSON from the /stats endpoints (parsed by StatsRepository).
abstract class StatsRemoteDataSource {
  Future<Map<String, dynamic>> getOverview();
  Future<List<dynamic>> getWeekly({int weeks = 8});
  Future<List<dynamic>> getLanguages();
}

class StatsRemoteDataSourceImpl implements StatsRemoteDataSource {
  final ApiClient apiClient;

  StatsRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> getOverview() async {
    final response = await apiClient.get(ApiConstants.statsOverview);
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<List<dynamic>> getWeekly({int weeks = 8}) async {
    final response = await apiClient.get(ApiConstants.statsWeekly, queryParameters: {'weeks': weeks});
    return response.data as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getLanguages() async {
    final response = await apiClient.get(ApiConstants.statsLanguages);
    return response.data as List<dynamic>;
  }
}
