import 'package:flutter/material.dart';

/// Official GitHub Octocat silhouette vector icon
class GithubLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const GithubLogo({
    super.key,
    this.size = 28.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.white;

    return CustomPaint(
      size: Size(size, size),
      painter: _GithubLogoPainter(color: effectiveColor),
    );
  }
}

class _GithubLogoPainter extends CustomPainter {
  final Color color;

  _GithubLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Scale from 1024x1024 standard SVG viewBox
    final scale = size.width / 1024.0;
    canvas.save();
    canvas.scale(scale, scale);

    final path = Path();
    // Precise GitHub Octocat SVG Path
    path.moveTo(512, 0);
    path.cubicTo(229.2, 0, 0, 229.2, 0, 512);
    path.cubicTo(0, 738.3, 146.5, 930.3, 349.7, 998);
    path.cubicTo(375.3, 1002.7, 384.7, 986.9, 384.7, 973.3);
    path.cubicTo(384.7, 961.1, 384.2, 921, 384, 878.1);
    path.cubicTo(241.6, 909, 211.5, 809.5, 201.3, 780.8);
    path.cubicTo(195.6, 766.1, 170.8, 720.8, 149.1, 708.7);
    path.cubicTo(131.2, 699, 105.6, 675.2, 148.5, 674.6);
    path.cubicTo(188.8, 674, 217.6, 711.6, 227.2, 727);
    path.cubicTo(273.2, 804.3, 346.9, 782.6, 376.3, 769.2);
    path.cubicTo(380.9, 735.9, 394.2, 713.5, 408.9, 700.7);
    path.cubicTo(295.2, 687.7, 176.3, 643.9, 176.3, 448.9);
    path.cubicTo(176.3, 393.3, 196.1, 347.5, 228.7, 311.8);
    path.cubicTo(223.6, 298.9, 205.8, 246.8, 233.7, 176.5);
    path.cubicTo(233.7, 176.5, 276.4, 163.1, 373.8, 228.9);
    path.cubicTo(414.5, 217.6, 457.7, 212, 500.8, 211.8);
    path.cubicTo(543.8, 212, 587.1, 217.6, 627.8, 228.9);
    path.cubicTo(725.2, 163.1, 767.9, 176.5, 767.9, 176.5);
    path.cubicTo(795.8, 246.8, 778, 298.9, 772.9, 311.8);
    path.cubicTo(805.5, 347.5, 825.3, 393.3, 825.3, 448.9);
    path.cubicTo(825.3, 644.5, 705.8, 687.5, 591.5, 700.7);
    path.cubicTo(610, 716.7, 626.6, 748, 626.6, 796);
    path.cubicTo(626.6, 865.1, 625.9, 920.9, 625.9, 938.2);
    path.cubicTo(625.9, 951.8, 635.3, 968, 661.1, 963.2);
    path.cubicTo(864.1, 895.5, 1010.5, 703.5, 1010.5, 477.2);
    path.cubicTo(1010.5, 213.6, 787.4, 0, 512, 0);
    path.close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GithubLogoPainter oldDelegate) => oldDelegate.color != color;
}
