import 'package:flutter/material.dart';

/// Flickpitch brand tokens — single source of truth for the mobile UI.
///
/// Values mirror the web design system so the two surfaces read as one
/// product: royal purple #8A5CFF, deep purple #6B3FE0, cyan #00D8FF, ink #0B1022.
class FpBrand {
  // colours
  static const Color purple = Color(0xFF8A5CFF);
  static const Color purpleDeep = Color(0xFF6B3FE0);
  static const Color purpleSoft = Color(0xFFA98BFF);
  static const Color cyan = Color(0xFF00D8FF);
  static const Color ink = Color(0xFF0B1022);

  /// Sent-message bubble: deep purple reads better behind white text than the
  /// flat brand purple, and keeps the brand hue intact.
  static const LinearGradient bubbleGradient = LinearGradient(
    colors: [purpleDeep, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Hero / empty-state wash.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [purpleDeep, purple, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // shape
  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const double bubbleRadius = 18;

  // elevation — soft, brand-tinted rather than grey
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: ink.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get bubbleShadow => [
        BoxShadow(
          color: purpleDeep.withValues(alpha: 0.22),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  /// Gradient text used for headings ("closer" on web).
  static ShaderMask gradientTextMask({required Widget child}) => ShaderMask(
        shaderCallback: (bounds) => heroGradient.createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: child,
      );
}
