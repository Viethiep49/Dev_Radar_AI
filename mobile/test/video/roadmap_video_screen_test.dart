import 'dart:async';

import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/models/roadmap_video_model.dart';
import 'package:dev_radar_ai/data/repositories/video_repository.dart';
import 'package:dev_radar_ai/presentation/screens/roadmap/roadmap_video_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoRepository extends Mock implements VideoRepository {}

void main() {
  late MockVideoRepository videos;

  setUp(() => videos = MockVideoRepository());

  Widget app() => RepositoryProvider<VideoRepository>.value(
        value: videos,
        child: const MaterialApp(home: Scaffold(body: RoadmapVideoScreen())),
      );

  testWidgets('shows the render in progress with an honest wait time', (tester) async {
    // Never completes: the screen stays in its loading state.
    when(() => videos.createRoadmapVideo()).thenAnswer((_) => Completer<RoadmapVideoModel>().future);

    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Đang dựng video...'), findsOneWidget);
    expect(find.textContaining('30-60 giây'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the backend message and a retry button on failure', (tester) async {
    when(() => videos.createRoadmapVideo())
        .thenThrow(ApiException('Lộ trình còn trống, chưa thể tạo video', statusCode: 400));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Lộ trình còn trống, chưa thể tạo video'), findsOneWidget);
    expect(find.text('Thử lại'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // The success state is deliberately not pumped here: video_player needs a
  // platform channel that a widget test does not have, so it would throw
  // MissingPluginException rather than exercise anything real. Playback is
  // verified by hand on a device.
}
