import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/roadmap_video_model.dart';
import '../../../data/repositories/video_repository.dart';
import '../load_status.dart';

class RepoVideoState extends Equatable {
  final LoadStatus status;
  final RoadmapVideoModel? video;
  final String? errorMessage;

  const RepoVideoState({
    this.status = LoadStatus.initial,
    this.video,
    this.errorMessage,
  });

  RepoVideoState copyWith({
    LoadStatus? status,
    RoadmapVideoModel? video,
    String? Function()? errorMessage,
  }) =>
      RepoVideoState(
        status: status ?? this.status,
        video: video ?? this.video,
        errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      );

  @override
  List<Object?> get props => [status, video, errorMessage];
}

/// Renders a detailed analysis video for a specific repo. Blocks server-side for 30-60s.
class RepoVideoCubit extends Cubit<RepoVideoState> {
  final VideoRepository videoRepository;
  final int repoId;

  RepoVideoCubit({
    required this.videoRepository,
    required this.repoId,
  }) : super(const RepoVideoState());

  Future<void> generate() async {
    if (state.status == LoadStatus.loading) return;
    emit(state.copyWith(status: LoadStatus.loading, errorMessage: () => null));
    try {
      final video = await videoRepository.createRepoVideo(repoId);
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.success, video: video));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: () => e.toString()));
    }
  }
}
