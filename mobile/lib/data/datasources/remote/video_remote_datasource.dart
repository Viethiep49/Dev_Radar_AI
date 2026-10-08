import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Raw JSON calls for /videos. The repository parses the result.
abstract class VideoRemoteDataSource {
  /// POST /videos/roadmap -> RoadmapVideoOut {job_id, url, duration_seconds, size_bytes}.
  /// Blocks server-side for 30-60 seconds while the engine renders.
  Future<Map<String, dynamic>> createRoadmapVideo();
}

class VideoRemoteDataSourceImpl implements VideoRemoteDataSource {
  final ApiClient apiClient;

  VideoRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> createRoadmapVideo() async {
    final response = await apiClient.post(
      '${ApiConstants.videos}/roadmap',
      // A render takes 30-60s, far past the client's 30s default.
      options: Options(receiveTimeout: ApiConstants.slowRequestTimeout),
    );
    return response.data as Map<String, dynamic>;
  }
}
