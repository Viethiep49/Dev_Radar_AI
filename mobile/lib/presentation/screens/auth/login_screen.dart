import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/social_auth_service.dart';
import '../../state/auth/auth_bloc.dart';
import '../../state/auth/auth_event.dart';
import '../../state/auth/auth_state.dart';
import '../../widgets/common/ambient_background.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/glass/glass_container.dart';
import '../../widgets/icons/github_logo.dart';
import '../../widgets/icons/google_logo.dart';
import '../../widgets/radar_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSocialLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthLoginRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }


  /// Real Google/GitHub login: the provider token goes to the backend, which
  /// verifies it and returns our own JWTs (see backend/docs/OAUTH_LOGIN.md).
  Future<void> _loginWithSocial(String provider) async {
    setState(() {
      _isSocialLoading = true;
    });

    final authBloc = context.read<AuthBloc>();
    final authRepo = context.read<AuthRepository>();
    final isGoogle = provider == 'google';
    final providerName = isGoogle ? 'Google' : 'GitHub';

    try {
      final user = isGoogle ? await authRepo.loginWithGoogle() : await authRepo.loginWithGithub();

      authBloc.add(AuthCheckRequested());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng nhập $providerName thành công: ${user.displayName}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on SocialAuthException catch (e) {
      if (mounted && !e.cancelled) {
        _showSocialError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showSocialError('Không thể đăng nhập bằng $providerName: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
        });
      }
    }
  }

  void _showSocialError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: AmbientBackground(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              context.go('/home');
            } else if (state is AuthFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading || _isSocialLoading;

            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: GlassContainer(
                    borderRadius: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    enableGlow: true,
                    glowColor: AppColors.primary.withAlpha(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: RadarLogo(size: 76)),
                          const SizedBox(height: 18),
                          Text(
                            'DevRadar AI',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Trợ lý theo dõi công nghệ & mã nguồn mở',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 26),
                          CustomTextField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'nhap@email.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Vui lòng nhập email';
                              }
                              if (!val.contains('@')) {
                                return 'Email không hợp lệ';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _passwordController,
                            label: 'Mật khẩu',
                            hint: '••••••••',
                            prefixIcon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Vui lòng nhập mật khẩu';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 22),
                          GlassButton(
                            text: 'Đăng nhập',
                            isLoading: isLoading,
                            icon: Icons.login_rounded,
                            onPressed: _onLogin,
                          ),
                          const SizedBox(height: 20),

                          // Social Login Divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: (isDark ? Colors.white : Colors.black).withAlpha(30),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'Hoặc tiếp tục với',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: (isDark ? Colors.white : Colors.black).withAlpha(30),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Google & GitHub Login Buttons
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: isLoading ? null : () => _loginWithSocial('google'),
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: (isDark ? Colors.white : Colors.black).withAlpha(35),
                                        width: 1.1,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        GoogleLogo(size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Google',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: isLoading ? null : () => _loginWithSocial('github'),
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: (isDark ? Colors.white : Colors.black).withAlpha(35),
                                        width: 1.1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        GithubLogo(
                                          size: 20,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'GitHub',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Chưa có tài khoản? ',
                                style: TextStyle(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.push('/register'),
                                child: const Text(
                                  'Đăng ký ngay',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
