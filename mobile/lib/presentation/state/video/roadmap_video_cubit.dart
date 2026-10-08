import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/roadmap_video_model.dart';
import '../../../data/repositories/video_repository.dart';
import '../load_status.dart';

class RoadmapVideoState extends Equatable {
  final LoadStatus status;
  final RoadmapVideoModel? video;
  final String? errorMessage;

  const RoadmapVideoState({
    this.status = LoadStatus.initial,
    this.video,
    this.errorMessage,
  });

  RoadmapVideoState copyWith({
    LoadStatus? status,
    RoadmapVideoModel? video,
    String? Function()? errorMessage,
  }) =>
      RoadmapVideoState(
        status: status ?? this.status,
        video: video ?? this.video,
        errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      );

  @override
  List<Object?> get props => [status, video, errorMessage];
}

/// Renders the "Lộ trình của tôi" video. The call blocks server-side for 30-60s.
class RoadmapVideoCubit extends Cubit<RoadmapVideoState> {
  final VideoRepository videoRepository;

  RoadmapVideoCubit({required this.videoRepository}) : super(const RoadmapVideoState());

  Future<void> generate() async {
    if (state.status == LoadStatus.loading) return; // a second tap must not queue a render
    emit(state.copyWith(status: LoadStatus.loading, errorMessage: () => null));
    try {
      final video = await videoRepository.createRoadmapVideo();
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.success, video: video));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: () => e.toString()));
    }
  }
}
