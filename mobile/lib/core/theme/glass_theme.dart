import 'package:flutter/material.dart';

enum GlassPerformanceLevel {
  high,   // Full blur, dual-layer specular highlight, inner glow, shadow
  medium, // Standard blur, single specular border
  low,    // No blur, solid alpha fallback
}

/// Design system tokens for Liquid Glass materials (Apple iOS & VisionOS Frosted Glass)
class GlassTheme {
  GlassTheme._();

  static GlassPerformanceLevel currentLevel = GlassPerformanceLevel.high;

  // Blur Sigma
  static double get blurSigma {
    switch (currentLevel) {
      case GlassPerformanceLevel.high:
        return 28.0;
      case GlassPerformanceLevel.medium:
        return 16.0;
      case GlassPerformanceLevel.low:
        return 0.0;
    }
  }

  // Dark mode frosted glass colors (Mờ đục, sâu, không bị trong suốt quá mức)
  static Color darkTint = const Color(0xE8161B22); // 91% opacity GitHub dark slate
  static Color darkSurface = const Color(0xF2161B22);
  static Color darkBorderHighlight = Colors.white.withAlpha(50);
  static Color darkBorderShadow = Colors.white.withAlpha(15);

  // Light mode glass colors
  static Color lightTint = Colors.white.withAlpha(225);
  static Color lightSurface = Colors.white.withAlpha(240);
  static Color lightBorderHighlight = Colors.white.withAlpha(240);
  static Color lightBorderShadow = const Color(0xFFD0D7DE);

  // Glass specular gradient border
  static LinearGradient glassBorderGradient(bool isDark) {
    if (isDark) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withAlpha(65),
          const Color(0xFF30363D),
          const Color(0xFF58A6FF).withAlpha(50),
          const Color(0xFF30363D).withAlpha(80),
        ],
        stops: const [0.0, 0.45, 0.75, 1.0],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withAlpha(255),
          const Color(0xFFD0D7DE),
          const Color(0xFF0969DA).withAlpha(40),
          const Color(0xFFD0D7DE),
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
      );
    }
  }

  // Deep Apple Frosted surface gradient
  static LinearGradient glassSurfaceGradient(bool isDark) {
    if (isDark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xF01C2128), // 94% opacity
          Color(0xEA161B22), // 92% opacity
          Color(0xF50D1117), // 96% opacity
        ],
        stops: [0.0, 0.5, 1.0],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withAlpha(245),
          Colors.white.withAlpha(225),
          const Color(0xFFF6F8FA).withAlpha(235),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    }
  }

  // Primary Action Button Gradient (GitHub Electric Blue)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF58A6FF),
      Color(0xFF1F6FEB),
    ],
  );

  // Hot Tag Badge Gradient
  static const LinearGradient hotGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF78166),
      Color(0xFFDA3633),
    ],
  );
}
