import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_theme.dart';
import '../../state/auth/auth_bloc.dart';
import '../../state/auth/auth_event.dart';
import '../../state/auth/auth_state.dart';
import '../../widgets/common/ambient_background.dart';
import '../../widgets/glass/glass_container.dart';
import '../../widgets/radar_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        context.read<AuthBloc>().add(AuthCheckRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is AuthUnauthenticated || state is AuthFailure) {
          context.go('/login');
        }
      },
      child: Scaffold(
        body: AmbientBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GlassContainer(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 40,
                  enableGlow: true,
                  glowColor: AppColors.primary,
                  child: const RadarLogo(size: 100),
                ),
                const SizedBox(height: 28),
                ShaderMask(
                  shaderCallback: (bounds) => GlassTheme.primaryGradient.createShader(bounds),
                  child: const Text(
                    'DevRadar AI',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Theo dõi xu hướng & Trợ lý mã nguồn mở',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
