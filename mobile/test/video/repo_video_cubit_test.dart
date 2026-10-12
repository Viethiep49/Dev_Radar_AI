import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/models/roadmap_video_model.dart';
import 'package:dev_radar_ai/data/repositories/video_repository.dart';
import 'package:dev_radar_ai/presentation/state/load_status.dart';
import 'package:dev_radar_ai/presentation/state/video/repo_video_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoRepository extends Mock implements VideoRepository {}

const repoVideo = RoadmapVideoModel(
  jobId: 'repo_abc',
  url: '/api/v1/videos/repo_abc',
  durationSeconds: 22.0,
  sizeBytes: 750000,
);

void main() {
  late MockVideoRepository videos;

  setUp(() => videos = MockVideoRepository());

  RepoVideoCubit build() => RepoVideoCubit(videoRepository: videos, repoId: 99);

  blocTest<RepoVideoCubit, RepoVideoState>(
    'generate renders and exposes the repo video',
    build: () {
      when(() => videos.createRepoVideo(99)).thenAnswer((_) async => repoVideo);
      return build();
    },
    act: (cubit) => cubit.generate(),
    verify: (cubit) {
      expect(cubit.state.status, LoadStatus.success);
      expect(cubit.state.video, repoVideo);
      expect(cubit.state.errorMessage, isNull);
    },
  );

  blocTest<RepoVideoCubit, RepoVideoState>(
    'generate reports a failure',
    build: () {
      when(() => videos.createRepoVideo(99))
          .thenThrow(ApiException('Không tìm thấy repository', statusCode: 404));
      return build();
    },
    act: (cubit) => cubit.generate(),
    verify: (cubit) {
      expect(cubit.state.status, LoadStatus.failure);
      expect(cubit.state.errorMessage, 'Không tìm thấy repository');
    },
  );
}
