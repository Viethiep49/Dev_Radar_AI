import 'package:dev_radar_ai/data/datasources/remote/video_remote_datasource.dart';
import 'package:dev_radar_ai/data/repositories/video_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoRemoteDataSource extends Mock implements VideoRemoteDataSource {}

void main() {
  late MockVideoRemoteDataSource remote;
  late VideoRepository repository;

  setUp(() {
    remote = MockVideoRemoteDataSource();
    repository = VideoRepositoryImpl(remoteDataSource: remote);
  });

  test('parses the render result', () async {
    when(() => remote.createRoadmapVideo()).thenAnswer((_) async => {
          'job_id': 'abc123',
          'url': '/api/v1/videos/abc123',
          'duration_seconds': 19.05,
          'size_bytes': 691932,
        });

    final video = await repository.createRoadmapVideo();

    expect(video.jobId, 'abc123');
    expect(video.url, '/api/v1/videos/abc123');
    expect(video.durationSeconds, closeTo(19.05, 0.001));
    expect(video.sizeBytes, 691932);
  });

  test('propagates a failure (e.g. 400 on an empty roadmap)', () async {
    when(() => remote.createRoadmapVideo()).thenThrow(Exception('Lộ trình còn trống'));

    expect(repository.createRoadmapVideo(), throwsA(isA<Exception>()));
  });
}
