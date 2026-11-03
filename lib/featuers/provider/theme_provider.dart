import 'package:flutter/material.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart';

class ThemeProvider extends ChangeNotifier {
  bool isLightTheme = true;
  bool _isLightMode = true;
  String? _customThemeColor;

  ThemeProvider() {
    _loadTheme(); // load when provider created
  }

  //getter for current theme mode
  bool get isLightMode => _isLightMode;

  //getter for custom theme color
  String? get customThemeColor => _customThemeColor;

  Future<void> _loadTheme() async {
    _isLightMode = await SecurePrefs.getBoolLighDark(
      SecureStorageKeys.isLightMode,
      defaultValue: true, // 👈 define here
    );

    // Load custom theme color
    _customThemeColor = await SecurePrefs.getString(
      SecureStorageKeys.customThemeColor,
    );

    notifyListeners();
  }

  // Function to toggle the theme mode
  Future<void> toggleThemeMode(bool value) async {
    _isLightMode = value; // ✅ Set value properly

    await SecurePrefs.setBool(SecureStorageKeys.isLightMode, _isLightMode);
    isLightModeGlobal = await SecurePrefs.getBoolLighDark(
      SecureStorageKeys.isLightMode,
      defaultValue: _isLightMode,
    );
    notifyListeners();
  }

  void updateLightModeValue(bool value) {
    _isLightMode = value;
    notifyListeners();
  }

  /// Set custom theme color
  Future<void> setCustomThemeColor(String colorHex) async {
    _customThemeColor = colorHex;
    await SecurePrefs.setString(
      SecureStorageKeys.customThemeColor,
      colorHex,
    );
    notifyListeners();
  }

  /// Reset to default theme (clear custom color)
  Future<void> resetToDefaultTheme() async {
    _customThemeColor = null;
    await SecurePrefs.remove(SecureStorageKeys.customThemeColor);
    notifyListeners();
  }

  /// Check if custom theme is set
  bool get hasCustomTheme => _customThemeColor != null;

  /// Manually trigger rebuild (for when colors are updated externally)
  void triggerRebuild() {
    notifyListeners();
  }
}
