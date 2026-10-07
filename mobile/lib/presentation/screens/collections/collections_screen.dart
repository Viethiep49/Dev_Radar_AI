import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/repo_model.dart';
import '../../../data/repositories/repo_repository.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/glass/glass_card.dart';
import '../../widgets/glass/glass_container.dart';
import '../../widgets/glass/glass_icon_button.dart';
import '../../widgets/glass/glass_modal_sheet.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List<RepoModel> _allRepos = [];
  bool _isLoadingRepos = false;

  // Set các bộ sưu tập đang mở (Mặc định mở bộ sưu tập 1 để giao diện không bị trống)
  final Set<int> _expandedCollectionIds = {1};

  final List<Map<String, dynamic>> _collections = [
    {
      'id': 1,
      'name': 'Đồ án Di động CMP177',
      'desc': 'Các repo tham khảo cho đồ án Flutter & AI',
      'count': 5,
      'repoIds': <int>[1, 2, 3, 4, 5],
      'icon': Icons.smartphone_rounded,
      'color': AppColors.primary,
    },
    {
      'id': 2,
      'name': 'Học Flutter & BLoC Pattern',
      'desc': 'Clean Architecture, State Management',
      'count': 8,
      'repoIds': <int>[1, 2, 3, 4, 5, 9, 10, 11],
      'icon': Icons.code_rounded,
      'color': AppColors.secondary,
    },
    {
      'id': 3,
      'name': 'AI & LLM Services',
      'desc': 'Ollama, LangChain, RAG embeddings',
      'count': 6,
      'repoIds': <int>[6, 7, 8, 13, 14, 15],
      'icon': Icons.psychology_rounded,
      'color': AppColors.accent,
    },
    {
      'id': 4,
      'name': 'Backend FastAPI & Microservices',
      'desc': 'SQLAlchemy, PostgreSQL, Docker Compose',
      'count': 4,
      'repoIds': <int>[6, 7, 8, 10],
      'icon': Icons.dns_rounded,
      'color': AppColors.success,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  Future<void> _loadRepos() async {
    setState(() {
      _isLoadingRepos = true;
    });
    try {
      final repos = await context.read<RepoRepository>().getTrendingRepos();
      if (mounted) {
        setState(() {
          _allRepos = repos;
          _isLoadingRepos = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingRepos = false;
        });
      }
    }
  }

  void _toggleExpand(int id) {
    setState(() {
      if (_expandedCollectionIds.contains(id)) {
        _expandedCollectionIds.remove(id);
      } else {
        _expandedCollectionIds.add(id);
      }
    });
  }

  void _showCreateCollectionDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    GlassModalSheet.show(
      context: context,
      title: 'Tạo bộ sưu tập mới',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Tên bộ sưu tập (vd: Công cụ AI)...',
              labelText: 'Tên bộ sưu tập',
              prefixIcon: Icon(Icons.folder_outlined, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: descController,
            decoration: const InputDecoration(
              hintText: 'Mô tả ngắn...',
              labelText: 'Mô tả',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 20),
          GlassButton(
            text: 'Tạo bộ sưu tập',
            icon: Icons.add_rounded,
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                final newId = DateTime.now().millisecondsSinceEpoch;
                setState(() {
                  _collections.insert(0, {
                    'id': newId,
                    'name': nameController.text.trim(),
                    'desc': descController.text.trim().isEmpty ? 'Chưa có mô tả' : descController.text.trim(),
                    'count': 0,
                    'repoIds': <int>[],
                    'icon': Icons.folder_special_rounded,
                    'color': AppColors.primary,
                  });
                  _expandedCollectionIds.add(newId);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã tạo bộ sưu tập mới thành công!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditCollectionDialog(BuildContext context, int index) {
    final item = _collections[index];
    final nameController = TextEditingController(text: item['name'] as String);
    final descController = TextEditingController(text: item['desc'] as String);

    GlassModalSheet.show(
      context: context,
      title: 'Chỉnh sửa bộ sưu tập',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Tên bộ sưu tập',
              prefixIcon: Icon(Icons.edit_outlined, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: descController,
            decoration: const InputDecoration(
              labelText: 'Mô tả',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 20),
          GlassButton(
            text: 'Lưu thay đổi',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  _collections[index]['name'] = nameController.text.trim();
                  _collections[index]['desc'] = descController.text.trim();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã cập nhật bộ sưu tập thành công!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteCollectionDialog(BuildContext context, int index) {
    final item = _collections[index];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E222B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withAlpha(30)),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
              SizedBox(width: 8),
              Text('Xác nhận xóa', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa bộ sưu tập "${item['name']}"? Hành động này không thể hoàn tác.',
            style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() {
                  _expandedCollectionIds.remove(item['id']);
                  _collections.removeAt(index);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa bộ sưu tập "${item['name']}" thành công!'),
                    backgroundColor: AppColors.error,
                  ),
                );
              },
              child: const Text('Xóa vĩnh viễn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAddRepoDialog(BuildContext context, Map<String, dynamic> item) {
    final repoIds = (item['repoIds'] as List<dynamic>?)?.cast<int>() ?? <int>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final availableRepos = _allRepos.where((r) => !repoIds.contains(r.id)).toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161A23) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Thêm repo vào "${item['name']}"',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: availableRepos.isEmpty
                    ? const Center(
                        child: Text(
                          'Tất cả repo hiện có đã nằm trong bộ sưu tập!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: availableRepos.length,
                        separatorBuilder: (context, _) => const Divider(height: 1),
                        itemBuilder: (context, rIndex) {
                          final repo = availableRepos[rIndex];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withAlpha(30),
                              backgroundImage: NetworkImage(repo.effectiveOwnerAvatarUrl),
                              onBackgroundImageError: (error, stackTrace) {},
                              child: Text(repo.name.isNotEmpty ? repo.name[0].toUpperCase() : '?'),
                            ),
                            title: Text(
                              repo.fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              repo.description ?? 'Không có mô tả',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Thêm', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                setState(() {
                                  repoIds.add(repo.id);
                                  item['repoIds'] = repoIds;
                                  item['count'] = repoIds.length;
                                });
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã thêm "${repo.name}" vào bộ sưu tập!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getLangColor(String? lang) {
    if (lang == null) return Colors.grey;
    switch (lang.toLowerCase()) {
      case 'dart':
        return AppColors.langDart;
      case 'python':
        return AppColors.langPython;
      case 'typescript':
        return AppColors.langTypeScript;
      case 'javascript':
        return AppColors.langJavaScript;
      case 'rust':
        return AppColors.langRust;
      case 'go':
        return AppColors.langGo;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bộ sưu tập học tập',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Phân loại và lưu trữ repo theo lộ trình (Bấm để xem danh sách)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
                GlassIconButton(
                  icon: Icons.create_new_folder_outlined,
                  tooltip: 'Tạo mới',
                  onPressed: () => _showCreateCollectionDialog(context),
                ),
              ],
            ),
          ),

          // Collections List with Accordion Expandable Repos
          Expanded(
            child: _collections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 56,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có bộ sưu tập nào',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () => _showCreateCollectionDialog(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Tạo bộ sưu tập đầu tiên'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: _collections.length,
                    itemBuilder: (context, index) {
                      final item = _collections[index];
                      final color = item['color'] as Color;
                      final id = item['id'] as int;
                      final isExpanded = _expandedCollectionIds.contains(id);
                      final repoIds = (item['repoIds'] as List<dynamic>?)?.cast<int>() ?? <int>[];
                      final matchedRepos = _allRepos.where((r) => repoIds.contains(r.id)).toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          borderRadius: 22,
                          enableGlow: isExpanded,
                          glowColor: color.withAlpha(40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Clickable Card Header
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _toggleExpand(id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: color.withAlpha(35),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: color.withAlpha(100), width: 1.2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: color.withAlpha(50),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Icon(item['icon'] as IconData, color: color, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'] as String,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              item['desc'] as String,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Repo count badge
                                      GlassContainer(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        borderRadius: 10,
                                        child: Text(
                                          '${repoIds.length} repo',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Animated Dropdown Chevron
                                      AnimatedRotation(
                                        turns: isExpanded ? 0.5 : 0.0,
                                        duration: const Duration(milliseconds: 200),
                                        child: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                          size: 24,
                                        ),
                                      ),
                                      // 3-dots Menu
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert_rounded,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                          size: 19,
                                        ),
                                        color: isDark ? const Color(0xFF1E222B) : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          side: BorderSide(color: Colors.white.withAlpha(30)),
                                        ),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showEditCollectionDialog(context, index);
                                          } else if (value == 'delete') {
                                            _showDeleteCollectionDialog(context, index);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                                SizedBox(width: 10),
                                                Text('Chỉnh sửa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                                SizedBox(width: 10),
                                                Text('Xóa bộ sưu tập', style: TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Expanded Section: Repositories List
                              if (isExpanded) ...[
                                const SizedBox(height: 12),
                                Divider(color: (isDark ? Colors.white : Colors.black).withAlpha(20), height: 1),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.auto_stories_rounded, size: 16, color: color),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Danh sách repository (${repoIds.length})',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ],
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showAddRepoDialog(context, item),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        child: Row(
                                          children: [
                                            Icon(Icons.add_circle_outline_rounded, size: 14, color: color),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Thêm repo',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                if (_isLoadingRepos && matchedRepos.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                      ),
                                    ),
                                  )
                                else if (matchedRepos.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.withAlpha(150)),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Chưa có repository nào trong bộ sưu tập này',
                                            style: TextStyle(fontSize: 12.5, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 10),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: color.withAlpha(30),
                                              foregroundColor: color,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            icon: const Icon(Icons.add_rounded, size: 16),
                                            label: const Text('Thêm repository ngay', style: TextStyle(fontSize: 12)),
                                            onPressed: () => _showAddRepoDialog(context, item),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: matchedRepos.length,
                                    separatorBuilder: (context, _) => const SizedBox(height: 8),
                                    itemBuilder: (context, rIndex) {
                                      final repo = matchedRepos[rIndex];
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () {
                                          context.push('/repo-detail', extra: repo);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: (isDark ? Colors.white : Colors.black).withAlpha(18),
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              // Repo Avatar
                                              CircleAvatar(
                                                radius: 17,
                                                backgroundColor: AppColors.primary.withAlpha(30),
                                                backgroundImage: NetworkImage(repo.effectiveOwnerAvatarUrl),
                                                onBackgroundImageError: (e, s) {},
                                                child: Text(
                                                  repo.name.isNotEmpty ? repo.name[0].toUpperCase() : '?',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              // Repo Info
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      repo.fullName,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13.5,
                                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (repo.description != null && repo.description!.isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        repo.description!,
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        if (repo.language != null) ...[
                                                          Container(
                                                            width: 7,
                                                            height: 7,
                                                            decoration: BoxDecoration(
                                                              color: _getLangColor(repo.language),
                                                              shape: BoxShape.circle,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            repo.language!,
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                                          ),
                                                          const SizedBox(width: 10),
                                                        ],
                                                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
                                                        const SizedBox(width: 2),
                                                        Text(
                                                          repo.stars >= 1000 ? '${(repo.stars / 1000).toStringAsFixed(1)}k' : '${repo.stars}',
                                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              // Delete from collection icon
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                  size: 17,
                                                  color: AppColors.error,
                                                ),
                                                tooltip: 'Xóa khỏi bộ sưu tập',
                                                onPressed: () {
                                                  setState(() {
                                                    repoIds.remove(repo.id);
                                                    item['repoIds'] = repoIds;
                                                    item['count'] = repoIds.length;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
