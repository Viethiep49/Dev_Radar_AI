import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/video_repository.dart';
import '../../state/load_status.dart';
import '../../state/video/roadmap_video_cubit.dart';
import '../../widgets/common/glass_page_scaffold.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/glass/glass_card.dart';

/// Renders the user's learning roadmap as a 9:16 video and offers it to the
/// system share sheet. Launching this screen starts the render: the button that
/// opens it already said "create".
class RoadmapVideoScreen extends StatelessWidget {
  const RoadmapVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => RoadmapVideoCubit(videoRepository: ctx.read<VideoRepository>())..generate(),
      child: const _RoadmapVideoView(),
    );
  }
}

class _RoadmapVideoView extends StatelessWidget {
  const _RoadmapVideoView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoadmapVideoCubit, RoadmapVideoState>(
      builder: (context, state) {
        final cubit = context.read<RoadmapVideoCubit>();
        return GlassPageScaffold(
          title: 'Video lộ trình',
          subtitle: 'Tổng kết hành trình học tập của bạn',
          body: switch (state.status) {
            LoadStatus.initial || LoadStatus.loading => const _Rendering(),
            LoadStatus.failure => ErrorRetryView(
                message: state.errorMessage ?? 'Không tạo được video',
                onRetry: cubit.generate,
              ),
            LoadStatus.success => _Result(url: ApiConstants.absoluteUrl(state.video!.url)),
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
          const Text('Đang dựng video...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Mất khoảng 30-60 giây. Bạn đừng rời màn hình nhé.',
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

  const _Result({required this.url});

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
    // iPad anchors the sheet to the button that opened it.
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        title: 'Lộ trình học tập của tôi',
        text: 'Xem tổng kết Lộ trình học tập Dev Radar của tôi!',
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
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      // Browsers block autoplay with sound, so start muted; a tap unmutes.
      ..setVolume(0)
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
            right: 8,
            bottom: 8,
            child: IconButton(
              tooltip: 'Bật/tắt tiếng',
              onPressed: () => setState(
                () => _controller.setVolume(_controller.value.volume == 0 ? 1 : 0),
              ),
              icon: Icon(
                _controller.value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
