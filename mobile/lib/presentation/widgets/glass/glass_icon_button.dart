import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_theme.dart';
import 'glass_container.dart';

class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final String? tooltip;
  final bool enableGlow;
  final Color? glowColor;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44.0,
    this.iconSize = 20.0,
    this.iconColor,
    this.tooltip,
    this.enableGlow = false,
    this.glowColor,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> with SingleTickerProviderStateMixin {
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
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

    Widget button = GlassContainer(
      width: widget.size,
      height: widget.size,
      borderRadius: widget.size / 2,
      surfaceGradient: GlassTheme.glassSurfaceGradient(isDark),
      borderGradient: GlassTheme.glassBorderGradient(isDark),
      enableGlow: widget.enableGlow,
      glowColor: widget.glowColor,
      child: Center(
        child: Icon(
          widget.icon,
          size: widget.iconSize,
          color: widget.iconColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return Semantics(
      button: true,
      label: widget.tooltip ?? 'Nút chức năng',
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
