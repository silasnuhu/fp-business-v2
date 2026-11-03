import 'package:flutter/material.dart';
import 'dart:math' as math;

class CustomCircleDashedBorder extends StatelessWidget {
  final double size;
  final double dashWidth;
  final double dashSpace;
  final Color color;

  const CustomCircleDashedBorder({
    super.key,
    required this.size,
    this.dashWidth = 8,
    this.dashSpace = 4,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: DashedCirclePainter(
        dashWidth: dashWidth,
        dashSpace: dashSpace,
        color: color,
      ),
    );
  }
}

class DashedCirclePainter extends CustomPainter {
  final double dashWidth;
  final double dashSpace;
  final Color color;

  DashedCirclePainter({
    required this.dashWidth,
    required this.dashSpace,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    double circumference = 2 * math.pi * radius;
    double dashCount = circumference / (dashWidth + dashSpace);
    double dashAngle = 2 * math.pi / dashCount;

    for (int i = 0; i < dashCount; i++) {
      double startAngle = i * dashAngle;
      double endAngle =
          startAngle + (dashAngle * (dashWidth / (dashWidth + dashSpace)));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
