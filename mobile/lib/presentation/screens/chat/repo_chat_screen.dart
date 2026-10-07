import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../data/models/repo_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../state/chat/chat_bloc.dart';
import '../../state/chat/chat_event.dart';
import '../../state/chat/chat_state.dart';
import '../../widgets/common/ambient_background.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/glass/glass_badge.dart';
import '../../widgets/glass/glass_container.dart';
import '../../widgets/glass/glass_icon_button.dart';

/// Chat with AI about one repo; answers cite the README/docs excerpts they use.
class RepoChatScreen extends StatelessWidget {
  final RepoModel repo;

  const RepoChatScreen({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ChatBloc(repoId: repo.id, chatRepository: context.read<ChatRepository>())..add(const ChatStarted()),
      child: _RepoChatView(repo: repo),
    );
  }
}

class _RepoChatView extends StatefulWidget {
  final RepoModel repo;

  const _RepoChatView({required this.repo});

  @override
  State<_RepoChatView> createState() => _RepoChatViewState();
}

class _RepoChatViewState extends State<_RepoChatView> {
  static const _suggestedPrompts = [
    'Dự án này giải quyết vấn đề gì?',
    'Cách cài đặt và chạy thử nhanh?',
    'Có dùng được với Flutter không?',
    'Yêu cầu môi trường như thế nào?',
  ];

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    context.read<ChatBloc>().add(ChatQuestionSent(text));
    _messageController.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _confirmClear() async {
    final bloc = context.read<ChatBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá lịch sử hội thoại?'),
        content: const Text('Toàn bộ câu hỏi và câu trả lời về repo này sẽ bị xoá.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok == true) bloc.add(const ChatCleared());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: BlocConsumer<ChatBloc, ChatState>(
            listenWhen: (a, b) =>
                a.messages.length != b.messages.length ||
                a.isSending != b.isSending ||
                (b.errorMessage != null && a.errorMessage != b.errorMessage),
            listener: (context, state) {
              _scrollToBottom();
              // Errors not tied to a failed question (e.g. clearing failed) go to a SnackBar.
              if (state.errorMessage != null &&
                  state.failedQuestion == null &&
                  state.historyStatus == ChatHistoryStatus.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.error),
                );
              }
            },
            builder: (context, state) {
              return Column(
                children: [
                  _ChatTopBar(
                    repo: widget.repo,
                    canClear: state.messages.isNotEmpty && !state.isSending,
                    onClear: _confirmClear,
                  ),
                  const Divider(height: 1),
                  if (state.fromCache)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: OfflineBanner(
                        cachedAt: state.cachedAt,
                        onRetry: () => context.read<ChatBloc>().add(const ChatStarted()),
                      ),
                    ),
                  Expanded(child: _buildMessages(state, isDark)),
                  if (state.messages.isEmpty && state.historyStatus == ChatHistoryStatus.success)
                    _SuggestedPrompts(prompts: _suggestedPrompts, onTap: _send, isDark: isDark),
                  _InputBar(
                    controller: _messageController,
                    enabled: !state.isSending,
                    isDark: isDark,
                    onSend: _send,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessages(ChatState state, bool isDark) {
    switch (state.historyStatus) {
      case ChatHistoryStatus.loading:
        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
      case ChatHistoryStatus.failure:
        return ErrorRetryView(
          message: state.errorMessage ?? 'Không tải được lịch sử hội thoại',
          onRetry: () => context.read<ChatBloc>().add(const ChatStarted()),
        );
      case ChatHistoryStatus.success:
        if (state.messages.isEmpty && !state.isSending) {
          return _WelcomeState(repoName: widget.repo.name, isDark: isDark);
        }
        final trailing = (state.isSending ? 1 : 0) + (state.failedQuestion != null ? 1 : 0);
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: state.messages.length + trailing,
          itemBuilder: (context, index) {
            if (index >= state.messages.length) {
              if (state.isSending) return _TypingBubble(isDark: isDark);
              return _FailedNotice(
                message: state.errorMessage ?? 'Gửi câu hỏi thất bại',
                onRetry: () => context.read<ChatBloc>().add(const ChatRetryRequested()),
              );
            }
            final message = state.messages[index];
            return TweenAnimationBuilder<double>(
              key: ValueKey('msg-${message.id ?? 'pending'}-$index'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child),
              ),
              child: message.isUser
                  ? _UserBubble(message: message)
                  : _AssistantBubble(message: message, isDark: isDark),
            );
          },
        );
    }
  }
}

class _ChatTopBar extends StatelessWidget {
  final RepoModel repo;
  final bool canClear;
  final VoidCallback onClear;

  const _ChatTopBar({required this.repo, required this.canClear, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Quay lại',
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        repo.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlassBadge.ai(),
                  ],
                ),
                Text(
                  'Hỏi đáp dựa trên README & tài liệu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ],
            ),
          ),
          if (canClear)
            GlassIconButton(
              icon: Icons.delete_sweep_outlined,
              tooltip: 'Xoá lịch sử',
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

class _WelcomeState extends StatelessWidget {
  final String repoName;
  final bool isDark;

  const _WelcomeState({required this.repoName, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: GlassTheme.primaryGradient,
                boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(70), blurRadius: 20)],
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 32, color: Colors.black),
            ),
            const SizedBox(height: 16),
            Text(
              'Trò chuyện cùng AI về $repoName',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'AI chỉ trả lời dựa trên README và tài liệu của repo, kèm trích dẫn đoạn nguồn để bạn đối chiếu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final ChatMessageModel message;

  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: GlassTheme.primaryGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withAlpha(50), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Opacity(
          opacity: message.id == null ? 0.75 : 1, // not saved yet
          child: Text(
            message.content,
            style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600, height: 1.35),
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isDark;

  const _AssistantBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 36),
        child: GlassContainer(
          borderRadius: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'DevRadar AI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.primary : AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                message.content,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.48,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              if (message.sources.isNotEmpty) ...[
                const SizedBox(height: 10),
                _Sources(sources: message.sources),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable list of the excerpts the answer is based on.
class _Sources extends StatelessWidget {
  final List<ChatSourceModel> sources;

  const _Sources({required this.sources});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          leading: const Icon(Icons.format_quote_rounded, size: 18, color: AppColors.primary),
          title: Text(
            'Nguồn trích dẫn (${sources.length})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          children: sources
              .map((source) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.path,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 2),
                        Text(source.excerpt, style: const TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.35)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  final bool isDark;

  const _TypingBubble({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GlassContainer(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'AI đang đọc tài liệu và suy nghĩ...',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedNotice extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FailedNotice({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Gửi lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedPrompts extends StatelessWidget {
  final List<String> prompts;
  final ValueChanged<String> onTap;
  final bool isDark;

  const _SuggestedPrompts({required this.prompts, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => onTap(prompts[index]),
          child: GlassContainer(
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              prompts[index],
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isDark;
  final ValueChanged<String> onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.isDark,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: GlassContainer(
        borderRadius: 26,
        borderWidth: 1.2,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        enableGlow: true,
        glowColor: AppColors.primary.withAlpha(20),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                maxLength: 1000,
                minLines: 1,
                maxLines: 4,
                onSubmitted: enabled ? onSend : null,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Hỏi AI về cách cài đặt, cách dùng...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: enabled ? () => onSend(controller.text) : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: enabled ? 1 : 0.4,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: GlassTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withAlpha(100), blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Center(child: Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.black)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
