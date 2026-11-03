import 'package:flutter/material.dart';
import 'dart:math';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

class CustomCircularProgressIndicator extends StatelessWidget {
  final double value;
  final double strokeWidth;
  final Color backgroundColor;
  final LinearGradient progressGradient;

  const CustomCircularProgressIndicator({
    super.key,
    required this.value,
    this.strokeWidth = 4.0,
    this.backgroundColor = AppColors.grey,
    required this.progressGradient,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 250,
      child: CustomPaint(
        painter: _CircularProgressPainter(
          value: value,
          strokeWidth: strokeWidth,
          backgroundColor: backgroundColor,
          progressGradient: progressGradient,
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double value;
  final double strokeWidth;
  final Color backgroundColor;
  // final Color progressColor;
  final LinearGradient progressGradient;

  _CircularProgressPainter({
    required this.value,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressGradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background Circle
    final backgroundPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress Arc
    final gradientShader = progressGradient.createShader(
      Rect.fromCircle(center: center, radius: radius),
    );

    // Progress Paint with Gradient
    final progressPaint =
        Paint()
          ..shader = gradientShader
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    final startAngle = -pi / 2;
    final sweepAngle = 2 * pi * value;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // Custom Marker at Endpoint
    final angle = startAngle + sweepAngle;
    final markerX = center.dx + radius * cos(angle);
    final markerY = center.dy + radius * sin(angle);
    final markerCenter = Offset(markerX, markerY);

    // Outer Circle
    final outerPaint =
        Paint()
          ..color = AppColors.appPriSecColor.primaryColor.withValues(
            alpha: 0.10,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    canvas.drawCircle(markerCenter, 18, outerPaint);

    // Gradient Circle
    final gradient = RadialGradient(
      colors: [
        AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.51),
        AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.19),
      ],
    ).createShader(Rect.fromCircle(center: markerCenter, radius: 13.5));

    final gradientPaint = Paint()..shader = gradient;
    canvas.drawCircle(markerCenter, 13.5, gradientPaint);

    // Inner Circle
    final innerPaint =
        Paint()
          ..color = AppColors.appPriSecColor.primaryColor
          ..style = PaintingStyle.fill;

    canvas.drawCircle(markerCenter, 7, innerPaint);

    // Inner White Border
    final whiteBorderPaint =
        Paint()
          ..color = AppColors.bgColor.bgWhite
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    canvas.drawCircle(markerCenter, 7, whiteBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
