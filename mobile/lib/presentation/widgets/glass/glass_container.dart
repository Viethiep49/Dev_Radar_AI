import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/glass_theme.dart';

/// Core Liquid Glass Container inspired by Apple VisionOS and Liquid Glass JS.
/// Uses 4 layered passes:
/// 1. BackdropFilter for frosted optical blur (refraction).
/// 2. Tinted gradient surface with subtle transparency.
/// 3. Specular highlight border with directional light angle.
/// 4. Soft ambient depth shadow.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double? blur;
  final Color? tint;
  final Gradient? surfaceGradient;
  final Gradient? borderGradient;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final bool enableGlow;
  final Color? glowColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20.0,
    this.blur,
    this.tint,
    this.surfaceGradient,
    this.borderGradient,
    this.borderWidth = 1.0,
    this.shadows,
    this.onTap,
    this.enableGlow = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sigma = blur ?? GlassTheme.blurSigma;

    final defaultSurfaceGradient = surfaceGradient ?? GlassTheme.glassSurfaceGradient(isDark);
    final defaultBorderGradient = borderGradient ?? GlassTheme.glassBorderGradient(isDark);

    final defaultShadows = shadows ??
        (isDark
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(90),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  spreadRadius: -4,
                ),
                if (enableGlow && glowColor != null)
                  BoxShadow(
                    color: glowColor!.withAlpha(45),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF64748B).withAlpha(35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
              ]);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: tint,
        gradient: tint == null ? defaultSurfaceGradient : null,
      ),
      child: child,
    );

    // Apply optical blur if performance tier allows
    if (sigma > 0) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: content,
      );
    }

    Widget glassBox = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: defaultShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CustomPaint(
          foregroundPainter: _GlassBorderPainter(
            borderRadius: borderRadius,
            borderWidth: borderWidth,
            gradient: defaultBorderGradient,
          ),
          child: content,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: glassBox,
      );
    }

    return glassBox;
  }
}

/// Custom painter for directional specular highlight border
class _GlassBorderPainter extends CustomPainter {
  final double borderRadius;
  final double borderWidth;
  final Gradient gradient;

  _GlassBorderPainter({
    required this.borderRadius,
    required this.borderWidth,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (borderWidth <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(borderWidth / 2),
      Radius.circular(borderRadius),
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GlassBorderPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.gradient != gradient;
}
