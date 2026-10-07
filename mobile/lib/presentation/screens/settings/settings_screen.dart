import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../state/auth/auth_bloc.dart';
import '../../state/auth/auth_event.dart';
import '../../state/auth/auth_state.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/glass/glass_container.dart';
import '../../widgets/glass/glass_text_field.dart';
import '../../widgets/icons/github_logo.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _githubUsernameController = TextEditingController();
  String? _selectedAvatar;
  bool _isSavingAvatar = false;

  final List<String> _avatarPresets = [
    'https://api.dicebear.com/7.x/identicon/png?seed=devradar',
    'https://api.dicebear.com/7.x/bottts/png?seed=developer',
    'https://api.dicebear.com/7.x/pixel-art/png?seed=coder',
    'https://api.dicebear.com/7.x/adventurer/png?seed=radar',
    'https://api.dicebear.com/7.x/lorelei/png?seed=engineer',
    'https://github.com/facebook.png',
  ];

  @override
  void dispose() {
    _githubUsernameController.dispose();
    super.dispose();
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final isSelected = mode == currentMode;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(40)
              : (isDark ? const Color(0xFF21262D) : const Color(0xFFEAEEF2)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(70),
                    blurRadius: 10,
                  ),
                ]
              : null,
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

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentTheme = ThemeController.themeModeNotifier.value;

    final authState = context.watch<AuthBloc>().state;
    String userEmail = 'demo@devradar.dev';
    String userName = 'Demo Developer';
    String? currentAvatar;

    if (authState is AuthAuthenticated) {
      userEmail = authState.user.email;
      userName = authState.user.displayName;
      currentAvatar = authState.user.effectiveAvatarUrl;
    }

    final activeAvatar = _selectedAvatar ?? currentAvatar ?? _avatarPresets.first;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header
            Row(
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
                Column(
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
                      'Quản lý hồ sơ, giao diện & bảo mật',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 1. Profile Card
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              child: Row(
                children: [
                  Stack(
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
                            BoxShadow(
                              color: AppColors.primary.withAlpha(90),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2.5),
                        child: ClipOval(
                          child: Image.network(
                            activeAvatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: GithubLogo(size: 34, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF161B22) : Colors.white,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primary.withAlpha(90),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const GithubLogo(size: 13, color: AppColors.success),
                            const SizedBox(width: 5),
                            Text(
                              'GitHub Verified Member',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success.withAlpha(220),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. DEVELOPER STATS GRID (CHO LÊN TRÊN CÙNG THEO YÊU CẦU - ẢNH 5)
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.star_rounded,
                    iconColor: AppColors.warning,
                    value: '18',
                    label: 'Đang theo dõi',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.bookmarks_rounded,
                    iconColor: AppColors.primary,
                    value: '4',
                    label: 'Bộ sưu tập',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: AppColors.accent,
                    value: '42',
                    label: 'AI Phân tích',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.code_rounded,
                    iconColor: AppColors.success,
                    value: '6',
                    label: 'Tech Stacks',
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // 3. TÙY CHỈNH GIAO DIỆN (Sáng / Tối / Hệ thống)
            Text(
              'TÙY CHỈNH GIAO DIỆN',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildThemeOption(
                    title: 'Sáng',
                    icon: Icons.light_mode_rounded,
                    mode: ThemeMode.light,
                    currentMode: currentTheme,
                    onTap: () {
                      setState(() {
                        ThemeController.setThemeMode(ThemeMode.light);
                      });
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildThemeOption(
                    title: 'Tối',
                    icon: Icons.dark_mode_rounded,
                    mode: ThemeMode.dark,
                    currentMode: currentTheme,
                    onTap: () {
                      setState(() {
                        ThemeController.setThemeMode(ThemeMode.dark);
                      });
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildThemeOption(
                    title: 'Hệ thống',
                    icon: Icons.brightness_auto_rounded,
                    mode: ThemeMode.system,
                    currentMode: currentTheme,
                    onTap: () {
                      setState(() {
                        ThemeController.setThemeMode(ThemeMode.system);
                      });
                    },
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 4. ĐỔI ẢNH ĐẠI DIỆN (AVATAR)
            Text(
              'CHỌN ẢNH ĐẠI DIỆN',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 10),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _avatarPresets.map((presetUrl) {
                        final isSel = activeAvatar == presetUrl;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAvatar = presetUrl;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? AppColors.primary : Colors.white.withAlpha(40),
                                width: isSel ? 2.5 : 1.0,
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withAlpha(120),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipOval(
                              child: Image.network(
                                presetUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(child: GithubLogo(size: 20, color: Colors.white)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GlassTextField(
                          controller: _githubUsernameController,
                          hintText: 'Nhập username GitHub (vd: torvalds)',
                          prefixIcon: Icons.alternate_email_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GlassButton(
                        text: 'Xem',
                        width: 64,
                        height: 44,
                        style: GlassButtonStyle.secondary,
                        onPressed: () {
                          final username = _githubUsernameController.text.trim();
                          if (username.isNotEmpty) {
                            setState(() {
                              _selectedAvatar = 'https://github.com/$username.png';
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GlassButton(
                    text: _isSavingAvatar ? 'Đang lưu Avatar...' : 'Lưu ảnh đại diện',
                    icon: Icons.check_circle_outline_rounded,
                    height: 42,
                    isLoading: _isSavingAvatar,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final authBloc = context.read<AuthBloc>();
                      final authRepo = context.read<AuthRepository>();

                      setState(() {
                        _isSavingAvatar = true;
                      });
                      try {
                        final updatedUser = await authRepo.updateAvatar(activeAvatar);
                        if (mounted) {
                          authBloc.add(AuthUserUpdated(updatedUser));
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Đã cập nhật Avatar thành công!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Lỗi cập nhật avatar: $e')),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isSavingAvatar = false;
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 5. BẢO MẬT & ĐỔI MẬT KHẨU (CHUYỂN SANG TRANG RIÊNG THEO YÊU CẦU - ẢNH 6)
            Text(
              'BẢO MẬT & ĐỔI MẬT KHẨU',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 10),
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              borderRadius: 18,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đổi mật khẩu tài khoản',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cập nhật mật khẩu để bảo vệ tài khoản',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 6. Developer Tools & Token
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.key_rounded, color: AppColors.primary, size: 20),
              ),
              title: const Text('Sao chép Auth Token', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Dành cho tích hợp API hoặc cURL', style: TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.copy_rounded, size: 18),
              onTap: () {
                Clipboard.setData(const ClipboardData(text: 'bearer_token_devradar_active'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép Bearer Token vào bộ nhớ tạm!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

            const SizedBox(height: 18),

            // 7. Logout Button
            GlassButton(
              text: 'Đăng xuất khỏi thiết bị',
              icon: Icons.logout_rounded,
              style: GlassButtonStyle.danger,
              height: 48,
              onPressed: () {
                context.read<AuthBloc>().add(AuthLogoutRequested());
                context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
