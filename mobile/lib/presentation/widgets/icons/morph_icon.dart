import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Animated Morphing Icon inspired by Morphicons principles.
/// Executes smooth rotational and scaling vector transitions between active & inactive icon states.
class MorphIcon extends StatelessWidget {
  final bool isToggled;
  final IconData initialIcon;
  final IconData toggledIcon;
  final Color? initialColor;
  final Color? toggledColor;
  final double size;
  final Duration duration;

  const MorphIcon({
    super.key,
    required this.isToggled,
    required this.initialIcon,
    required this.toggledIcon,
    this.initialColor,
    this.toggledColor,
    this.size = 24.0,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultInitialColor = initialColor ??
        (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
    final defaultToggledColor = toggledColor ?? AppColors.primary;

    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        return RotationTransition(
          turns: Tween<double>(begin: 0.15, end: 0.0).animate(animation),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
      child: isToggled
          ? Icon(
              toggledIcon,
              key: ValueKey(toggledIcon),
              size: size,
              color: defaultToggledColor,
            )
          : Icon(
              initialIcon,
              key: ValueKey(initialIcon),
              size: size,
              color: defaultInitialColor,
            ),
    );
  }
}
