import 'package:flutter/material.dart';

class FlagLabelIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double flagRatio; // Ratio of flag width to total width

  const FlagLabelIcon({
    super.key,
    required this.size,
    required this.color,
    this.flagRatio = 0.85, // 85% of width is flag, 15% is pole
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.6), // Flag aspect ratio
      painter: FlagPainter(color: color, flagRatio: flagRatio),
    );
  }
}

class FlagPainter extends CustomPainter {
  final Color color;
  final double flagRatio;

  FlagPainter({required this.color, required this.flagRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    final double poleWidth = size.width * (1 - flagRatio) * 0.6; // Pole width
    final double cornerRadius = poleWidth * 0.5; // Rounded corners
    final double arrowDepth = size.height * 0.2; // Arrow tip depth

    // Start from top-left of pole
    path.moveTo(cornerRadius, 0);

    // Top of pole (rounded)
    path.lineTo(poleWidth - cornerRadius, 0);
    path.arcToPoint(
      Offset(poleWidth, cornerRadius),
      radius: Radius.circular(cornerRadius),
    );

    // Right side of pole to flag connection
    path.lineTo(poleWidth, size.height * 0.15);

    // Top edge of flag
    path.lineTo(size.width - arrowDepth, size.height * 0.15);

    // Arrow tip (right edge of flag)
    path.lineTo(size.width, size.height * 0.5);
    path.lineTo(size.width - arrowDepth, size.height * 0.85);

    // Bottom edge of flag
    path.lineTo(poleWidth, size.height * 0.85);

    // Left side of pole (bottom part)
    path.lineTo(poleWidth, size.height - cornerRadius);

    // Bottom of pole (rounded)
    path.arcToPoint(
      Offset(poleWidth - cornerRadius, size.height),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(cornerRadius, size.height);
    path.arcToPoint(
      Offset(0, size.height - cornerRadius),
      radius: Radius.circular(cornerRadius),
    );

    // Left side of pole
    path.lineTo(0, cornerRadius);

    // Top-left corner (rounded)
    path.arcToPoint(
      Offset(cornerRadius, 0),
      radius: Radius.circular(cornerRadius),
    );

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is FlagPainter &&
        (oldDelegate.color != color || oldDelegate.flagRatio != flagRatio);
  }
}