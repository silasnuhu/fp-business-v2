import 'package:flutter/material.dart';

/// Flickpitch mobile design tokens.
///
/// This is the single source of truth for the redesigned UI. It deliberately
/// does NOT extend the old `AppColors`/`AppThemeManage` colour-swap approach:
/// the redesign introduces its own canvas, elevation and type system so that
/// screens look structurally different from the stock template, not recoloured.
class Fp {
  Fp._();

  // ---------------------------------------------------------------- colour
  //
  // Light is the default surface. `Fp.dark` flips the whole system; every
  // widget reads these as getters, so screens never hardcode a mode.
  static bool dark = false;

  /// Brand default. `FpThemeSync` overwrites [accentColor] from ThemeProvider,
  /// so the theme picker actually repaints the redesign.
  static const Color brandViolet = Color(0xFF7C4DFF);
  static Color accentColor = brandViolet;

  static Color get violet => accentColor;
  static Color get violetDeep =>
      Color.lerp(accentColor, const Color(0xFF000000), 0.30)!;
  static Color get violetGlow =>
      Color.lerp(accentColor, const Color(0xFFFFFFFF), 0.38)!;
  static const Color cyan = Color(0xFF00A3C4);
  static const Color mint = Color(0xFF0FA47A);
  static const Color coral = Color(0xFFE0455A);
  /// Read-receipt blue. Deliberately its own colour, not the brand violet:
  /// a read tick must read as "read", never as branding.
  static const Color tickRead = Color(0xFF34B7F1);
  static const Color danger = coral;
  static const Color amber = Color(0xFFC77A00);
  static const Color onAccent = Color(0xFF10101A);

  // ---- light palette (default)
  static const Color _inkLight = Color(0xFFF6F5FB);
  static const Color _inkSoftLight = Color(0xFFFFFFFF);
  static const Color _inkRaisedLight = Color(0xFFFFFFFF);
  static const Color _hairlineLight = Color(0x14000000);
  static const Color _hairlineStrongLight = Color(0x29000000);
  static const Color _textLight = Color(0xFF14121F);
  static const Color _textMutedLight = Color(0xFF5B5773);
  static const Color _textFaintLight = Color(0xFF8B87A3);

  // ---- dark palette
  static const Color _inkDark = Color(0xFF07070E);
  static const Color _inkSoftDark = Color(0xFF0E0E1A);
  static const Color _inkRaisedDark = Color(0xFF16162A);
  static const Color _hairlineDark = Color(0x1FFFFFFF);
  static const Color _hairlineStrongDark = Color(0x33FFFFFF);
  static const Color _textDark = Color(0xFFF6F5FF);
  static const Color _textMutedDark = Color(0xFFA9A6C4);
  static const Color _textFaintDark = Color(0xFF6E6B8C);

  static Color get ink => dark ? _inkDark : _inkLight;
  static Color get inkSoft => dark ? _inkSoftDark : _inkSoftLight;
  static Color get inkRaised => dark ? _inkRaisedDark : _inkRaisedLight;
  static Color get hairline => dark ? _hairlineDark : _hairlineLight;
  static Color get hairlineStrong =>
      dark ? _hairlineStrongDark : _hairlineStrongLight;
  static Color get text => dark ? _textDark : _textLight;
  static Color get textMuted => dark ? _textMutedDark : _textMutedLight;
  static Color get textFaint => dark ? _textFaintDark : _textFaintLight;

  // ---------------------------------------------------------------- type
  // The bundled fonts are registered as separate families per weight, so a
  // plain fontWeight would silently fall back to the regular cut.
  static String _familyFor(FontWeight w) {
    if (w.value >= FontWeight.w700.value) return 'PoppinsBold';
    if (w.value >= FontWeight.w600.value) return 'PoppinsSemibold';
    if (w.value >= FontWeight.w500.value) return 'PoppinsMedium';
    return 'Poppins';
  }

  static TextStyle _t(double size, FontWeight w,
          {double? height, double? spacing, Color? color}) =>
      TextStyle(
        fontFamily: _familyFor(w),
        fontSize: size,
        fontWeight: w,
        height: height ?? 1.25,
        letterSpacing: spacing ?? 0,
        color: color ?? text,
      );

  static TextStyle get display =>
      _t(34, FontWeight.w700, height: 1.1, spacing: -0.8);
  static TextStyle get h1 => _t(26, FontWeight.w600, height: 1.15, spacing: -0.4);
  static TextStyle get h2 => _t(20, FontWeight.w600, height: 1.2, spacing: -0.2);
  static TextStyle get h3 => _t(17, FontWeight.w600);
  static TextStyle get body => _t(15, FontWeight.w400, height: 1.45);
  static TextStyle get bodyStrong => _t(15, FontWeight.w600, height: 1.45);
  static TextStyle get caption => _t(12.5, FontWeight.w400, height: 1.35);
  static TextStyle get label => _t(11, FontWeight.w600, spacing: 1.4);

  // ------------------------------------------------------------- geometry
  static const double s2 = 2, s4 = 4, s8 = 8, s12 = 12, s16 = 16;
  static const double s20 = 20, s24 = 24, s32 = 32, s40 = 40, s56 = 56;

  static const double rSm = 14;
  static const double rMd = 20;
  static const double rLg = 28;
  static const double rXl = 36;
  static const double rPill = 999;

  static const EdgeInsets pagePad = EdgeInsets.symmetric(horizontal: s24);

  // ---------------------------------------------------------------- depth
  static List<BoxShadow> get lift => [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.45 : 0.08),
          blurRadius: dark ? 28 : 20,
          offset: Offset(0, dark ? 14 : 8),
        ),
      ];

  static List<BoxShadow> glow(Color c) => [
        BoxShadow(
          color: c.withValues(alpha: dark ? 0.34 : 0.22),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ];

  // --------------------------------------------------------------- paints
  static LinearGradient get accent => LinearGradient(
        colors: [violetGlow, violet, violetDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get aurora => LinearGradient(
        colors: dark
            ? const [Color(0xFF2A1157), _inkDark, Color(0xFF0A1F2E)]
            : const [Color(0xFFF2ECFF), _inkLight, Color(0xFFE8F7FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient cyanTrail = LinearGradient(
    colors: [cyan, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ------------------------------------------------------------ animation
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 280);
  static const Curve ease = Curves.easeOutCubic;
}
