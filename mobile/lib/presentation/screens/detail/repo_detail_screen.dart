import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../data/models/repo_model.dart';
import '../../../data/repositories/repo_repository.dart';
import '../../widgets/common/ambient_background.dart';
import '../../widgets/glass/glass_badge.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/glass/glass_card.dart';
import '../../widgets/glass/glass_container.dart';
import '../../widgets/glass/glass_icon_button.dart';
import '../../widgets/icons/github_logo.dart';

class RepoDetailScreen extends StatefulWidget {
  final RepoModel repo;

  const RepoDetailScreen({super.key, required this.repo});

  @override
  State<RepoDetailScreen> createState() => _RepoDetailScreenState();
}

class _RepoDetailScreenState extends State<RepoDetailScreen> {
  bool _isLoading = true;
  bool _isLoadingReadme = true;
  String? _summary;
  String? _quickstart;
  String? _learningStatus;
  String? _readmeContent;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _loadRepoDetails();
  }

  Future<String?> _fetchRawGithubReadme(String owner, String repoName) async {
    final branches = ['HEAD', 'main', 'master'];
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 6),
      ),
    );

    for (final branch in branches) {
      try {
        final res = await dio.get<String>(
          'https://raw.githubusercontent.com/$owner/$repoName/$branch/README.md',
          options: Options(responseType: ResponseType.plain),
        );
        if (res.statusCode == 200 && res.data != null && res.data!.trim().isNotEmpty) {
          return res.data;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _loadRepoDetails() async {
    try {
      final repoRepo = context.read<RepoRepository>();
      final data = await repoRepo.getRepoDetail(widget.repo.id);

      String? readme = data['readme'] as String?;
      if (readme == null || readme.trim().length < 1000) {
        final raw = await _fetchRawGithubReadme(widget.repo.owner, widget.repo.name);
        if (raw != null && raw.trim().isNotEmpty) {
          readme = raw;
        }
      }

      if (mounted) {
        setState(() {
          _learningStatus = data['learning_status'] as String?;
          final summaryData = data['summary'];
          if (summaryData is Map<String, dynamic>) {
            _summary = summaryData['summary'] as String?;
            _quickstart = summaryData['quickstart'] as String?;
          }
          _readmeContent = readme;
          _isLoading = false;
          _isLoadingReadme = false;
        });
      }
    } catch (_) {
      // Fallback: Fetch direct from GitHub Raw if backend call had issue
      final fallbackReadme = await _fetchRawGithubReadme(widget.repo.owner, widget.repo.name);
      if (mounted) {
        setState(() {
          _readmeContent = fallbackReadme;
          _isLoading = false;
          _isLoadingReadme = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String? newStatus) async {
    final prevStatus = _learningStatus;
    setState(() {
      _learningStatus = newStatus;
    });

    try {
      await context.read<RepoRepository>().updateLearningStatus(widget.repo.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus != null
                  ? 'Đã cập nhật trạng thái học tập'
                  : 'Đã xóa trạng thái học tập',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _learningStatus = prevStatus;
        });
      }
    }
  }

  void _copyQuickstart() {
    if (_quickstart == null || _quickstart!.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _quickstart!));
    setState(() {
      _isCopied = true;
    });
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép lệnh Quickstart vào clipboard!'),
        backgroundColor: AppColors.primaryDark,
        duration: Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  String _getFallbackMarkdown() {
    final topicsStr = widget.repo.topics.isNotEmpty
        ? widget.repo.topics.map((t) => '`$t`').join(', ')
        : 'Chưa phân loại';
    final homepageLine = widget.repo.homepage != null && widget.repo.homepage!.isNotEmpty
        ? '- 🌐 [Trang chủ dự án](${widget.repo.homepage})\n'
        : '';

    return '''# ${widget.repo.name}

> ${widget.repo.description ?? 'Dự án mã nguồn mở đáng chú ý trên GitHub.'}

## 📖 Giới thiệu dự án
Dự án **${widget.repo.name}** được sáng lập và duy trì bởi tổ chức/lập trình viên **${widget.repo.owner}**. Đây là một trong những dự án nhận được sự quan tâm lớn trong cộng đồng mã nguồn mở với **${widget.repo.stars} sao**.

## 📊 Thông tin tổng quan
- **Chủ sở hữu**: `${widget.repo.owner}`
- **Ngôn ngữ phát triển**: `${widget.repo.language ?? 'Đa ngôn ngữ'}`
- **Số sao GitHub**: ⭐ **${widget.repo.stars}**
- **Lượt Fork**: 🍴 **${widget.repo.forks}**
- **Vấn đề mở (Issues)**: 🐞 **${widget.repo.openIssues}**
- **Chủ đề liên quan**: $topicsStr

## 🚀 Hướng dẫn cài đặt & Khởi động nhanh
Bạn có thể clone mã nguồn dự án về máy tính cá nhân bằng lệnh Git:

```bash
git clone ${widget.repo.htmlUrl}.git
cd ${widget.repo.name}
```

## 🔗 Liên kết chính thức
- 🌐 [Kho lưu trữ chính thức trên GitHub](${widget.repo.htmlUrl})
$homepageLine''';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GlassIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Quay lại',
                      onPressed: () => context.pop(),
                    ),
                    Row(
                      children: [
                        if (widget.repo.isHot) GlassBadge.hot(),
                        const SizedBox(width: 8),
                        GlassIconButton(
                          icon: Icons.open_in_new_rounded,
                          tooltip: 'Xem trên GitHub',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Mở liên kết: ${widget.repo.htmlUrl}'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Repo Header Card (Hiển thị Avatar chủ sở hữu chuẩn CORS và sắc nét)
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        borderRadius: 24,
                        enableGlow: true,
                        glowColor: AppColors.primary.withAlpha(25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Owner Avatar (CORS-safe proxy wsrv.nl)
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? Colors.white.withAlpha(40) : const Color(0xFFD0D7DE),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      widget.repo.effectiveOwnerAvatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: const Color(0xFF21262D),
                                        child: const Center(
                                          child: GithubLogo(size: 26, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.repo.owner,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.repo.name,
                                        style: const TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (widget.repo.description != null && widget.repo.description!.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                widget.repo.description!,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            // Metrics Grid
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMetric('Stars', '${widget.repo.stars}', Icons.star_rounded, const Color(0xFFFFB800)),
                                _buildMetric('Forks', '${widget.repo.forks}', Icons.fork_right_rounded, AppColors.info),
                                _buildMetric('Issues', '${widget.repo.openIssues}', Icons.bug_report_outlined, AppColors.warning),
                                _buildMetric('Ngôn ngữ', widget.repo.language ?? 'Khác', Icons.code_rounded, AppColors.primary),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 2. Learning Status Selector
                      Text(
                        'Trạng thái học tập cá nhân',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildStatusSelector(isDark),

                      const SizedBox(height: 18),

                      // 3. AI Summary Card
                      GlassCard(
                        borderRadius: 24,
                        enableGlow: true,
                        glowColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                GlassBadge.ai(),
                                const Spacer(),
                                if (_isLoading)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Tóm tắt AI (Đọc trong 1 phút)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _summary ??
                                  (_isLoading
                                      ? 'AI đang phân tích tài liệu và cấu trúc repo...'
                                      : (widget.repo.description ?? 'Dự án mã nguồn mở đáng chú ý trên GitHub.')),
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.5,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 4. Quickstart Code Card
                      if (_quickstart != null && _quickstart!.isNotEmpty && _quickstart != 'Chưa có hướng dẫn nhanh') ...[
                        const SizedBox(height: 18),
                        GlassContainer(
                          padding: const EdgeInsets.all(18),
                          borderRadius: 22,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.terminal_rounded, size: 18, color: AppColors.primary),
                                      SizedBox(width: 8),
                                      Text(
                                        'Cài đặt nhanh (Quickstart)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: _copyQuickstart,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _isCopied
                                            ? AppColors.success.withAlpha(35)
                                            : AppColors.primary.withAlpha(35),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _isCopied ? AppColors.success : AppColors.primary.withAlpha(100),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                                            size: 13,
                                            color: _isCopied ? AppColors.success : AppColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _isCopied ? 'Đã chép' : 'Sao chép',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _isCopied ? AppColors.success : AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(160),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withAlpha(20)),
                                ),
                                child: Text(
                                  _quickstart!,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12.5,
                                    color: Color(0xFF70F3FF),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // 5. FILE GIỚI THIỆU README.MD (MARKDOWN RENDERER)
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        borderRadius: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(30),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.article_outlined, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'README.md',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF21262D) : const Color(0xFFEAEEF2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const GithubLogo(size: 12, color: Colors.grey),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Tài liệu chính thức',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            if (_isLoadingReadme)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                              )
                            else
                              MarkdownBody(
                                data: (_readmeContent != null && _readmeContent!.trim().isNotEmpty)
                                    ? _readmeContent!
                                    : _getFallbackMarkdown(),
                                selectable: true,
                                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                  p: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.55,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                  h1: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                  h2: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                  h3: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                  code: TextStyle(
                                    backgroundColor: isDark ? const Color(0xFF161B22) : const Color(0xFFEAEEF2),
                                    fontFamily: 'monospace',
                                    fontSize: 12.0,
                                    color: const Color(0xFF70F3FF),
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                                    ),
                                  ),
                                  codeblockPadding: const EdgeInsets.all(12),
                                  blockquoteDecoration: BoxDecoration(
                                    border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
                                    color: AppColors.primary.withAlpha(20),
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 90), // Bottom padding for floating button
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GlassButton(
          text: 'Hỏi đáp AI về Repo này',
          icon: Icons.chat_bubble_outline_rounded,
          style: GlassButtonStyle.primary,
          height: 56,
          borderRadius: 28,
          onPressed: () {
            context.push('/repo-chat', extra: widget.repo);
          },
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildStatusSelector(bool isDark) {
    final statuses = [
      {'key': 'want_to_try', 'label': 'Muốn thử', 'icon': Icons.bookmark_outline_rounded},
      {'key': 'learning', 'label': 'Đang học', 'icon': Icons.auto_stories_rounded},
      {'key': 'used', 'label': 'Đã dùng', 'icon': Icons.check_circle_outline_rounded},
    ];

    return GlassContainer(
      padding: const EdgeInsets.all(6),
      borderRadius: 18,
      child: Row(
        children: statuses.map((item) {
          final key = item['key'] as String;
          final isSelected = _learningStatus == key;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                _updateStatus(isSelected ? null : key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected ? GlassTheme.primaryGradient : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 15,
                      color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
