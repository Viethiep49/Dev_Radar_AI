import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Ambient canvas with subtle luminous depth orbs.
/// Essential for providing high-contrast refraction background for Liquid Glass materials.
class AmbientBackground extends StatelessWidget {
  final Widget child;
  final bool showOrbs;

  const AmbientBackground({
    super.key,
    required this.child,
    this.showOrbs = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // Solid base canvas
        Positioned.fill(
          child: Container(
            color: isDark ? AppColors.darkBg : AppColors.lightBg,
          ),
        ),

        // Glowing ambient light blobs
        if (showOrbs && isDark) ...[
          // Top cyan glowing radial orb
          Positioned(
            top: -120,
            right: -60,
            width: 340,
            height: 340,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00E5FF).withAlpha(45),
                      const Color(0xFF6366F1).withAlpha(15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Middle left violet glowing orb
          Positioned(
            top: 280,
            left: -140,
            width: 360,
            height: 360,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFA855F7).withAlpha(35),
                      const Color(0xFF0090B3).withAlpha(10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Bottom right subtle indigo orb
          Positioned(
            bottom: -100,
            right: -80,
            width: 320,
            height: 320,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withAlpha(30),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
        ] else if (showOrbs && !isDark) ...[
          // Soft bright orbs for light mode
          Positioned(
            top: -80,
            right: -40,
            width: 300,
            height: 300,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00D2FF).withAlpha(30),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
        ],

        // Main content
        Positioned.fill(child: child),
      ],
    );
  }
}
