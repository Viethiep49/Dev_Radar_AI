import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../state/settings/change_password_cubit.dart';
import '../../widgets/common/glass_page_scaffold.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/glass/glass_container.dart';
import '../../widgets/glass/glass_text_field.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ChangePasswordCubit(ctx.read<AuthRepository>()),
      child: const _ChangePasswordView(),
    );
  }
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView();

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<ChangePasswordCubit>().submit(
          oldPassword: _oldPasswordController.text,
          newPassword: _newPasswordController.text,
          confirmPassword: _confirmPasswordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<ChangePasswordCubit, ChangePasswordState>(
      listener: (context, state) {
        if (state.status == ChangePasswordStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đổi mật khẩu thành công!'), backgroundColor: AppColors.success),
          );
          Navigator.of(context).maybePop();
        } else if (state.status == ChangePasswordStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage ?? 'Đổi mật khẩu thất bại'), backgroundColor: AppColors.error),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state.status == ChangePasswordStatus.submitting;
        return GlassPageScaffold(
          title: 'Đổi mật khẩu',
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), shape: BoxShape.circle),
                        child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bảo vệ tài khoản DevRadar AI',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nên dùng mật khẩu mạnh kết hợp chữ hoa, chữ thường, số và ký tự đặc biệt. '
                              'Tài khoản đăng nhập bằng Google/GitHub chưa có mật khẩu thì để trống ô "Mật khẩu hiện tại".',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'THÔNG TIN MẬT KHẨU',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 10),
                GlassContainer(
                  padding: const EdgeInsets.all(18),
                  borderRadius: 20,
                  child: Column(
                    children: [
                      GlassTextField(
                        controller: _oldPasswordController,
                        hintText: 'Mật khẩu hiện tại',
                        obscureText: true,
                        prefixIcon: Icons.lock_outline_rounded,
                      ),
                      const SizedBox(height: 14),
                      GlassTextField(
                        controller: _newPasswordController,
                        hintText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                        obscureText: true,
                        prefixIcon: Icons.lock_reset_rounded,
                      ),
                      const SizedBox(height: 14),
                      GlassTextField(
                        controller: _confirmPasswordController,
                        hintText: 'Xác nhận mật khẩu mới',
                        obscureText: true,
                        prefixIcon: Icons.check_rounded,
                      ),
                      const SizedBox(height: 22),
                      GlassButton(
                        text: isSubmitting ? 'Đang cập nhật...' : 'Xác nhận đổi mật khẩu',
                        icon: Icons.shield_rounded,
                        height: 48,
                        isLoading: isSubmitting,
                        onPressed: isSubmitting ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
