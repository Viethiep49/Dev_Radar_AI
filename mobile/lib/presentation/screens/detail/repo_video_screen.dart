import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/video_repository.dart';
import '../../state/load_status.dart';
import '../../state/video/repo_video_cubit.dart';
import '../../widgets/common/glass_page_scaffold.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/glass/glass_card.dart';

/// Renders a detailed analysis video for a specific repository (9:16)
/// and allows viewing and sharing it via the system share sheet.
class RepoVideoScreen extends StatelessWidget {
  final int repoId;
  final String repoName;
  final String repoFullName;

  const RepoVideoScreen({
    super.key,
    required this.repoId,
    required this.repoName,
    required this.repoFullName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => RepoVideoCubit(
        videoRepository: ctx.read<VideoRepository>(),
        repoId: repoId,
      )..generate(),
      child: _RepoVideoView(
        repoName: repoName,
        repoFullName: repoFullName,
      ),
    );
  }
}

class _RepoVideoView extends StatelessWidget {
  final String repoName;
  final String repoFullName;

  const _RepoVideoView({
    required this.repoName,
    required this.repoFullName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RepoVideoCubit, RepoVideoState>(
      builder: (context, state) {
        final cubit = context.read<RepoVideoCubit>();
        return GlassPageScaffold(
          title: 'Phân tích $repoName',
          subtitle: 'Video tổng quan chuyên sâu: $repoFullName',
          body: switch (state.status) {
            LoadStatus.initial || LoadStatus.loading => const _Rendering(),
            LoadStatus.failure => ErrorRetryView(
                message: state.errorMessage ?? 'Không tạo được video phân tích',
                onRetry: cubit.generate,
              ),
            LoadStatus.success => _Result(
                url: ApiConstants.absoluteUrl(state.video!.url),
                repoName: repoName,
                repoFullName: repoFullName,
              ),
          },
        );
      },
    );
  }
}

class _Rendering extends StatelessWidget {
  const _Rendering();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text('Đang dựng video phân tích...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Đang tổng hợp thông tin, giọng đọc tiếng Việt và hiệu ứng.\nMất khoảng 30-60 giây, bạn đừng rời màn hình nhé.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final String url;
  final String repoName;
  final String repoFullName;

  const _Result({
    required this.url,
    required this.repoName,
    required this.repoFullName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassCard(
          padding: const EdgeInsets.all(10),
          borderRadius: 24,
          child: AspectRatio(aspectRatio: 9 / 16, child: _VideoPreview(url: url)),
        ),
        const SizedBox(height: 18),
        GlassButton(
          text: 'Chia sẻ video',
          icon: Icons.ios_share_rounded,
          height: 56,
          onPressed: () => _share(context),
        ),
      ],
    );
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        title: 'Video phân tích $repoName',
        text: 'Xem video phân tích chi tiết repository $repoFullName trên Dev Radar AI!',
        uri: Uri.parse(url),
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final String url;

  const _VideoPreview({required this.url});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final initialVolume = kIsWeb ? 0.0 : 1.0;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setVolume(initialVolume)
      ..setLooping(true);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.play();
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _ready = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_ready) return;
    setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play());
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    final isMuted = _controller.value.volume == 0;
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!_controller.value.isPlaying)
            const Center(
              child: Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white70),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.black.withAlpha(160),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(
                  () => _controller.setVolume(isMuted ? 1.0 : 0.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isMuted ? 'Bật tiếng' : 'Tắt tiếng',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
