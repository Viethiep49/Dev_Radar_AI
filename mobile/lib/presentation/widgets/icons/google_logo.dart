import 'package:flutter/material.dart';

/// Clean Google "G" 4-color vector icon
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({
    super.key,
    this.size = 22.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;

    // Scale from 48x48
    final double scale = w / 48.0;
    canvas.save();
    canvas.scale(scale, scale);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Blue
    paint.color = const Color(0xFF4285F4);
    final Path bluePath = Path()
      ..moveTo(46.14, 24.5)
      ..cubicTo(46.14, 22.8, 46.0, 21.15, 45.7, 19.56)
      ..lineTo(24, 19.56)
      ..lineTo(24, 28.98)
      ..lineTo(36.46, 28.98)
      ..cubicTo(35.91, 31.84, 34.25, 34.27, 31.75, 35.88)
      ..lineTo(31.75, 41.74)
      ..lineTo(39.33, 41.74)
      ..cubicTo(43.76, 37.66, 46.14, 31.65, 46.14, 24.5);
    canvas.drawPath(bluePath, paint);

    // Green
    paint.color = const Color(0xFF34A853);
    final Path greenPath = Path()
      ..moveTo(24, 47)
      ..cubicTo(30.21, 47, 35.43, 44.94, 39.33, 41.74)
      ..lineTo(31.75, 35.88)
      ..cubicTo(29.64, 37.3, 26.98, 38.16, 24, 38.16)
      ..cubicTo(17.99, 38.16, 12.9, 34.1, 11.08, 28.64)
      ..lineTo(3.26, 28.64)
      ..lineTo(3.26, 34.69)
      ..cubicTo(7.13, 42.38, 14.99, 47, 24, 47);
    canvas.drawPath(greenPath, paint);

    // Yellow
    paint.color = const Color(0xFFFBBC05);
    final Path yellowPath = Path()
      ..moveTo(11.08, 28.64)
      ..cubicTo(10.62, 27.27, 10.36, 25.8, 10.36, 24.28)
      ..cubicTo(10.36, 22.76, 10.62, 21.29, 11.08, 19.92)
      ..lineTo(11.08, 13.87)
      ..lineTo(3.26, 13.87)
      ..cubicTo(1.64, 17.09, 0.72, 20.58, 0.72, 24.28)
      ..cubicTo(0.72, 27.98, 1.64, 31.47, 3.26, 34.69)
      ..lineTo(11.08, 28.64);
    canvas.drawPath(yellowPath, paint);

    // Red
    paint.color = const Color(0xFFEA4335);
    final Path redPath = Path()
      ..moveTo(24, 10.4)
      ..cubicTo(27.38, 10.4, 30.41, 11.56, 32.79, 13.84)
      ..lineTo(39.5, 7.13)
      ..cubicTo(35.41, 3.32, 30.2, 1, 24, 1)
      ..cubicTo(14.99, 1, 7.13, 5.62, 3.26, 13.31)
      ..lineTo(11.08, 19.36)
      ..cubicTo(12.9, 13.9, 17.99, 10.4, 24, 10.4);
    canvas.drawPath(redPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
