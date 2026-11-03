import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';

/// Bridges the app's existing [ThemeProvider] into the redesign's token system.
///
/// The redesign reads colours from static `Fp` getters, which is fast and keeps
/// every screen free of theme plumbing — but static values do not rebuild on
/// their own. This widget is the missing link: it watches ThemeProvider, writes
/// the resolved mode + accent into `Fp`, and only then builds its child, so the
/// theme picker and the light/dark switch actually take effect.
class FpThemeSync extends StatelessWidget {
  const FpThemeSync({super.key, required this.child});

  final Widget child;

  /// Applies the provider's mode + accent into `Fp`. Call from a builder that
  /// rebuilds on theme changes (e.g. MaterialApp.builder).
  static void apply(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    // Light is the product default; the provider's flag flips us into dark.
    Fp.dark = !theme.isLightMode;

    final hex = theme.customThemeColor;
    if (hex != null && hex.trim().isNotEmpty) {
      final parsed = _parseHex(hex);
      if (parsed != null) Fp.accentColor = parsed;
    } else {
      Fp.accentColor = Fp.brandViolet;
    }

  }

  @override
  Widget build(BuildContext context) {
    // theme dependency: rebuild this screen when the theme changes
    // so the static Fp tokens are re-read (they are not InheritedWidgets).
    context.watch<ThemeProvider>();
    apply(context);
    return child;
  }

  /// Accepts #RRGGBB, RRGGBB, #AARRGGBB, 0xFFRRGGBB.
  static Color? _parseHex(String raw) {
    var v = raw.trim().replaceAll('#', '').replaceAll('0x', '');
    if (v.length == 6) v = 'FF$v';
    if (v.length != 8) return null;
    final n = int.tryParse(v, radix: 16);
    return n == null ? null : Color(n);
  }
}
