import '../datasources/remote/video_remote_datasource.dart';
import '../models/roadmap_video_model.dart';

/// The roadmap video. Write-only, so nothing here goes through the cache:
/// the backend renders a fresh MP4 per request and the file is served by URL.
abstract class VideoRepository {
  /// Renders a summary video of the caller's learning roadmap. Blocks for
  /// 30-60 seconds. Throws a 400 when the roadmap is empty.
  Future<RoadmapVideoModel> createRoadmapVideo();
}

class VideoRepositoryImpl implements VideoRepository {
  final VideoRemoteDataSource remoteDataSource;

  VideoRepositoryImpl({required this.remoteDataSource});

  @override
  Future<RoadmapVideoModel> createRoadmapVideo() async =>
      RoadmapVideoModel.fromJson(await remoteDataSource.createRoadmapVideo());
}
