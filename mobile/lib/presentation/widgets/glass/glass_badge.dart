import 'package:flutter/material.dart';
import '../../../core/theme/glass_theme.dart';
import 'glass_container.dart';

class GlassBadge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  final Gradient? gradient;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry padding;

  const GlassBadge({
    super.key,
    required this.text,
    this.icon,
    this.color,
    this.gradient,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
  });

  factory GlassBadge.hot() {
    return const GlassBadge(
      text: 'HOT',
      icon: Icons.local_fire_department_rounded,
      gradient: GlassTheme.hotGradient,
    );
  }

  factory GlassBadge.ai() {
    return const GlassBadge(
      text: 'AI Insight',
      icon: Icons.auto_awesome_rounded,
      gradient: GlassTheme.primaryGradient,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFF00E5FF);

    return GlassContainer(
      padding: padding,
      borderRadius: 12,
      surfaceGradient: gradient ??
          LinearGradient(
            colors: [
              effectiveColor.withAlpha(50),
              effectiveColor.withAlpha(20),
            ],
          ),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withAlpha(120),
          effectiveColor.withAlpha(100),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: textStyle ??
                const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ),
    );
  }
}
