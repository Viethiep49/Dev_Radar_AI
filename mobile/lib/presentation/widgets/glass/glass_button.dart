import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_theme.dart';
import 'glass_container.dart';

enum GlassButtonStyle {
  primary, // Luminous primary gradient with specular border
  secondary, // Translucent glass with border
  danger, // Soft red glass for delete / logout
}

class GlassButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final GlassButtonStyle style;
  final double height;
  final double? width;
  final double borderRadius;

  const GlassButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.style = GlassButtonStyle.primary,
    this.height = 52.0,
    this.width,
    this.borderRadius = 16.0,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Gradient? surfaceGrad;
    Gradient? borderGrad;
    Color? textColor;
    Color? iconColor;
    bool enableGlow = false;
    Color? glowColor;

    switch (widget.style) {
      case GlassButtonStyle.primary:
        surfaceGrad = GlassTheme.primaryGradient;
        borderGrad = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha(200),
            Colors.white.withAlpha(50),
            const Color(0xFF00E5FF).withAlpha(120),
          ],
        );
        textColor = Colors.black;
        iconColor = Colors.black;
        enableGlow = true;
        glowColor = const Color(0xFF00E5FF);
        break;

      case GlassButtonStyle.secondary:
        surfaceGrad = GlassTheme.glassSurfaceGradient(isDark);
        borderGrad = GlassTheme.glassBorderGradient(isDark);
        textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        iconColor = AppColors.primary;
        break;

      case GlassButtonStyle.danger:
        surfaceGrad = LinearGradient(
          colors: [
            const Color(0xFFEF4444).withAlpha(160),
            const Color(0xFF991B1B).withAlpha(200),
          ],
        );
        borderGrad = LinearGradient(
          colors: [
            Colors.white.withAlpha(140),
            const Color(0xFFEF4444).withAlpha(100),
          ],
        );
        textColor = Colors.white;
        iconColor = Colors.white;
        enableGlow = true;
        glowColor = const Color(0xFFEF4444);
        break;
    }

    Widget content;
    if (widget.isLoading) {
      content = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
          ],
          Text(
            widget.text,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
    }

    final button = GlassContainer(
      width: widget.width ?? double.infinity,
      height: widget.height,
      borderRadius: widget.borderRadius,
      surfaceGradient: surfaceGrad,
      borderGradient: borderGrad,
      enableGlow: enableGlow,
      glowColor: glowColor,
      child: Center(child: content),
    );

    if (widget.onPressed == null || widget.isLoading) {
      return Opacity(opacity: 0.6, child: button);
    }

    return Semantics(
      button: true,
      label: widget.text,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: button,
        ),
      ),
    );
  }
}
