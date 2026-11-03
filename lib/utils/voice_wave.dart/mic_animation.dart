import 'package:flutter/material.dart';

class MicWaveAnimation extends StatefulWidget {
  final double size;
  final Color color;

  const MicWaveAnimation({super.key, this.size = 60, required this.color});

  @override
  State<MicWaveAnimation> createState() => _MicWaveAnimationState();
}

class _MicWaveAnimationState extends State<MicWaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
      height: widget.size * 2,
      width: widget.size * 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          return CustomPaint(
            painter: _WavePainter(
              progress: _controller.value,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _WavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final radius = maxRadius * (progress + i / 3);
      final opacity = (1 - (progress + i / 3)).clamp(0.0, 1.0);

      final paint =
          Paint()
            ..color = color.withValues(alpha: opacity * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
