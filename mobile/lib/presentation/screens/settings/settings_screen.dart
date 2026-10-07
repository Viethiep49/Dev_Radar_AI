import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/local_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/storage_service.dart';
import '../../../data/datasources/local/cache_local_datasource.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/stats_repository.dart';
import '../../state/auth/auth_bloc.dart';
import '../../state/auth/auth_event.dart';
import '../../state/auth/auth_state.dart';
import '../../state/settings/profile_cubit.dart';
import '../../state/settings/settings_cubit.dart';
import '../../state/stats/stats_cubit.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/glass/glass_container.dart';
import '../../widgets/glass/glass_text_field.dart';
import '../../widgets/icons/github_logo.dart';
import 'change_password_screen.dart';

/// Settings tab: profile, preferences, notifications, theme, cache, security, logout.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (ctx) => SettingsCubit(
            storage: ctx.read<StorageService>(),
            notifications: ctx.read<LocalNotificationService>(),
            cache: ctx.read<CacheLocalDataSource>(),
          )..load(),
        ),
        BlocProvider(create: (ctx) => ProfileCubit(ctx.read<AuthRepository>())),
        BlocProvider(create: (ctx) => StatsCubit(ctx.read<StatsRepository>())..load()),
      ],
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  Future<void> _refresh(BuildContext context) async {
    await Future.wait([
      context.read<SettingsCubit>().load(),
      context.read<StatsCubit>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MultiBlocListener(
      listeners: [
        BlocListener<SettingsCubit, SettingsState>(
          listenWhen: (prev, curr) => curr.message != null || curr.errorMessage != null,
          listener: (context, state) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? state.message!),
                backgroundColor: state.errorMessage != null ? AppColors.error : null,
              ),
            );
          },
        ),
        BlocListener<ProfileCubit, ProfileState>(
          listenWhen: (prev, curr) => curr.savedUser != null || curr.errorMessage != null,
          listener: (context, state) {
            if (state.savedUser != null) {
              context.read<AuthBloc>().add(AuthUserUpdated(state.savedUser));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã cập nhật ảnh đại diện!')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi cập nhật ảnh đại diện: ${state.errorMessage}')),
              );
            }
          },
        ),
      ],
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              _ScreenHeader(isDark: isDark),
              const SizedBox(height: 18),
              const _ProfileCard(),
              const SizedBox(height: 16),
              const _StatsSummary(),
              const SizedBox(height: 22),
              _SectionLabel('CÁ NHÂN HOÁ', isDark: isDark),
              _NavTile(
                icon: Icons.tune_rounded,
                color: AppColors.secondary,
                title: 'Sở thích (ngôn ngữ & lĩnh vực)',
                subtitle: 'Dùng để gợi ý repo trên bảng tin',
                onTap: () => context.push('/onboarding', extra: true),
              ),
              const SizedBox(height: 10),
              _NavTile(
                icon: Icons.visibility_rounded,
                color: AppColors.success,
                title: 'Repo đang theo dõi',
                subtitle: 'Nhận thông báo khi có release mới',
                onTap: () => context.push('/watchlist'),
              ),
              const SizedBox(height: 22),
              _SectionLabel('THÔNG BÁO', isDark: isDark),
              const _NotificationSettings(),
              const SizedBox(height: 22),
              _SectionLabel('TÙY CHỈNH GIAO DIỆN', isDark: isDark),
              const _ThemePicker(),
              const SizedBox(height: 22),
              _SectionLabel('CHỌN ẢNH ĐẠI DIỆN', isDark: isDark),
              const _AvatarPicker(),
              const SizedBox(height: 22),
              _SectionLabel('DỮ LIỆU OFFLINE', isDark: isDark),
              const _CacheTile(),
              const SizedBox(height: 22),
              _SectionLabel('BẢO MẬT', isDark: isDark),
              _NavTile(
                icon: Icons.lock_reset_rounded,
                color: AppColors.primary,
                title: 'Đổi mật khẩu tài khoản',
                subtitle: 'Cập nhật mật khẩu để bảo vệ tài khoản',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                ),
              ),
              const SizedBox(height: 24),
              GlassButton(
                text: 'Đăng xuất khỏi thiết bị',
                icon: Icons.logout_rounded,
                style: GlassButtonStyle.danger,
                height: 48,
                onPressed: () => _confirmLogout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Dữ liệu cache trên máy sẽ được xoá.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<AuthBloc>().add(AuthLogoutRequested());
      context.go('/login');
    }
  }
}

class _ScreenHeader extends StatelessWidget {
  final bool isDark;

  const _ScreenHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(30),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withAlpha(80), width: 1.2),
          ),
          child: const Icon(Icons.settings_rounded, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cài đặt & Tài khoản',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Quản lý hồ sơ, thông báo, giao diện & bảo mật',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const _SectionLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final pending = context.select<ProfileCubit, String?>((c) => c.state.pendingAvatarUrl);
    final avatar = pending ?? user?.effectiveAvatarUrl;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withAlpha(90), blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: ClipOval(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: avatar == null
                    ? const Center(child: GithubLogo(size: 34, color: Colors.white))
                    : Image.network(
                        avatar,
                        key: ValueKey(avatar),
                        fit: BoxFit.cover,
                        width: 67,
                        height: 67,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: GithubLogo(size: 34, color: Colors.white)),
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
                  user?.displayName ?? 'Khách',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                ),
                const SizedBox(height: 3),
                Text(
                  user?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Real numbers from GET /stats/overview (no hard-coded values).
class _StatsSummary extends StatelessWidget {
  const _StatsSummary();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<StatsCubit, StatsState>(
      builder: (context, state) {
        final o = state.overview;
        String v(int? n) => o == null ? '–' : '$n';
        final tiles = [
          _MetricTile(Icons.bookmark_added_rounded, AppColors.primary, v(o?.totalRepos), 'Repo trong lộ trình'),
          _MetricTile(Icons.verified_rounded, AppColors.success, v(o?.used), 'Đã sử dụng'),
          _MetricTile(Icons.bookmarks_rounded, AppColors.secondary, v(o?.collectionsCount), 'Bộ sưu tập'),
          _MetricTile(Icons.sticky_note_2_rounded, AppColors.warning, v(o?.notesCount), 'Ghi chú'),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in tiles) SizedBox(width: width, child: t.build(isDark)),
              ],
            );
          },
        );
      },
    );
  }
}

class _MetricTile {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _MetricTile(this.icon, this.color, this.value, this.label);

  Widget build(bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 18,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 15, color: isDark ? Colors.white54 : Colors.black45),
        ],
      ),
    );
  }
}

class _NotificationSettings extends StatelessWidget {
  const _NotificationSettings();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();
        final time = state.reminderTime.format(context);
        return GlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 6),
          borderRadius: 18,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.new_releases_rounded, color: AppColors.success),
                title: const Text('Thông báo release mới', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Khi repo bạn theo dõi có phiên bản mới'),
                value: state.releaseAlertsEnabled,
                onChanged: state.loaded ? cubit.setReleaseAlerts : null,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.alarm_rounded, color: AppColors.primary),
                title: const Text('Nhắc học hằng ngày', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(state.reminderEnabled ? 'Lúc $time mỗi ngày' : 'Đang tắt'),
                value: state.reminderEnabled,
                onChanged: state.loaded ? cubit.setReminderEnabled : null,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: state.reminderEnabled
                    ? ListTile(
                        leading: const Icon(Icons.schedule_rounded),
                        title: const Text('Giờ nhắc học'),
                        trailing: Text(
                          time,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: state.reminderTime);
                          if (picked != null) {
                            await cubit.setReminderTime(picked);
                          }
                        },
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeModeNotifier,
      builder: (context, current, _) {
        Widget option(String title, IconData icon, ThemeMode mode) => Expanded(
              child: _ThemeOption(
                title: title,
                icon: icon,
                isSelected: current == mode,
                onTap: () => ThemeController.setThemeMode(mode),
              ),
            );
        return Row(
          children: [
            option('Sáng', Icons.light_mode_rounded, ThemeMode.light),
            const SizedBox(width: 8),
            option('Tối', Icons.dark_mode_rounded, ThemeMode.dark),
            const SizedBox(width: 8),
            option('Hệ thống', Icons.brightness_auto_rounded, ThemeMode.system),
          ],
        );
      },
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({required this.title, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(40)
              : (isDark ? AppColors.darkElevated : AppColors.lightElevated),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withAlpha(70), blurRadius: 10)] : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatefulWidget {
  const _AvatarPicker();

  @override
  State<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<_AvatarPicker> {
  static const _presets = [
    'https://api.dicebear.com/7.x/identicon/png?seed=devradar',
    'https://api.dicebear.com/7.x/bottts/png?seed=developer',
    'https://api.dicebear.com/7.x/pixel-art/png?seed=coder',
    'https://api.dicebear.com/7.x/adventurer/png?seed=radar',
    'https://api.dicebear.com/7.x/lorelei/png?seed=engineer',
  ];

  final _githubUsernameController = TextEditingController();

  @override
  void dispose() {
    _githubUsernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final current = authState is AuthAuthenticated ? authState.user.effectiveAvatarUrl : _presets.first;
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final cubit = context.read<ProfileCubit>();
        final active = state.pendingAvatarUrl ?? current;
        return GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final url in _presets)
                      GestureDetector(
                        onTap: () => cubit.selectAvatar(url),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active == url ? AppColors.primary : Colors.white.withAlpha(40),
                              width: active == url ? 2.5 : 1.0,
                            ),
                            boxShadow: active == url
                                ? [BoxShadow(color: AppColors.primary.withAlpha(120), blurRadius: 10)]
                                : null,
                          ),
                          child: ClipOval(
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(child: GithubLogo(size: 20, color: Colors.white)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GlassTextField(
                      controller: _githubUsernameController,
                      hintText: 'Username GitHub (vd: torvalds)',
                      prefixIcon: Icons.alternate_email_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassButton(
                    text: 'Xem',
                    width: 64,
                    height: 44,
                    style: GlassButtonStyle.secondary,
                    onPressed: () => cubit.selectGithubAvatar(_githubUsernameController.text),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassButton(
                text: state.isSaving ? 'Đang lưu...' : 'Lưu ảnh đại diện',
                icon: Icons.check_circle_outline_rounded,
                height: 42,
                isLoading: state.isSaving,
                onPressed: state.isSaving ? null : () => cubit.saveAvatar(active),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CacheTile extends StatelessWidget {
  const _CacheTile();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (prev, curr) => prev.cacheCount != curr.cacheCount || prev.isClearingCache != curr.isClearingCache,
      builder: (context, state) {
        return GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          borderRadius: 18,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.warning.withAlpha(30), shape: BoxShape.circle),
                child: const Icon(Icons.storage_rounded, color: AppColors.warning, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bộ nhớ đệm (SQLite)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '${state.cacheCount} mục đã lưu để xem khi mất mạng',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: state.isClearingCache || state.cacheCount == 0 ? null : () => _confirm(context),
                child: state.isClearingCache
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Xoá'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá dữ liệu cache?'),
        content: const Text('Dữ liệu đã lưu để xem offline sẽ bị xoá. Lần mở sau app sẽ tải lại từ server.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok == true) {
      await cubit.clearCache();
    }
  }
}
