import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class RadarLogo extends StatefulWidget {
  final double size;

  const RadarLogo({super.key, this.size = 80});

  @override
  State<RadarLogo> createState() => _RadarLogoState();
}

class _RadarLogoState extends State<RadarLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarPainter(
              progress: _controller.value,
              color: AppColors.primary,
            ),
            child: Center(
              child: Icon(
                Icons.radar_rounded,
                size: widget.size * 0.45,
                color: AppColors.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw concentric radar rings
    final ringPaint = Paint()
      ..color = color.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius * 0.35, ringPaint);
    canvas.drawCircle(center, radius * 0.70, ringPaint);
    canvas.drawCircle(center, radius, ringPaint);

    // Draw pulsing ring
    final pulseRadius = radius * progress;
    final pulsePaint = Paint()
      ..color = color.withAlpha(((1 - progress) * 100).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Draw sweeping radar beam
    final sweepAngle = progress * 2 * math.pi;
    final beamPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: 0,
        endAngle: math.pi / 2,
        colors: [
          color.withAlpha(0),
          color.withAlpha(80),
        ],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, beamPaint);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => true;
}
