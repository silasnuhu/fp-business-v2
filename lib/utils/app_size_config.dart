import 'package:flutter/material.dart';

class SizeConfig {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  static late bool isPortrait;
  static late bool isMobilePortrait;

  static double _scaleFactor = 1.0;

  static late double _safeAreaHorizontal;
  static late double _safeAreaVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;

    _safeAreaHorizontal =
        _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    _safeAreaVertical =
        _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
    safeBlockHorizontal = (screenWidth - _safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - _safeAreaVertical) / 100;

    isPortrait = _mediaQueryData.orientation == Orientation.portrait;
    isMobilePortrait = isPortrait && screenWidth < 450;

    // Calculate scale factor based on screen height
    _scaleFactor = _calculateScaleFactor();
  }

  static double _calculateScaleFactor() {
    // Base height of 800 is chosen as a reference
    double factor = screenHeight / 800;

    // Adjust scale factor based on device size
    if (screenHeight < 600) {
      // Smaller devices need less aggressive scaling
      factor = factor * 0.95;
    } else if (screenHeight > 1000) {
      // Larger devices need less aggressive scaling
      factor = factor * 0.9;
    }

    // Clamp the scale factor to prevent extreme scaling
    return factor.clamp(0.8, 1.2);
  }

  // Get exact font size with minimal scaling
  static double getFontSize(double size) {
    return size * _scaleFactor;
  }

  // Get size that scales more with screen size (for layouts)
  static double getScaledSize(double size) {
    return size * blockSizeVertical / 8;
  }

  // Get proportionate height
  static double height(double height) {
    return blockSizeVertical * height;
  }

  // Get proportionate width
  static double width(double width) {
    return blockSizeHorizontal * width;
  }

  // Get safe area height (considering notches and system UI)
  static double safeHeight(double height) {
    return safeBlockVertical * height;
  }

  // Get safe area width (considering notches and system UI)
  static double safeWidth(double width) {
    return safeBlockHorizontal * width;
  }

  // Get padding that scales with screen size
  static EdgeInsets getPadding(double all) {
    return EdgeInsets.all(getScaledSize(all));
  }

  // Get padding that scales with screen size (different values)
  static EdgeInsets getPaddingLTRB(
    double left,
    double top,
    double right,
    double bottom,
  ) {
    return EdgeInsets.fromLTRB(
      getScaledSize(left),
      getScaledSize(top),
      getScaledSize(right),
      getScaledSize(bottom),
    );
  }

  // Get symmetric padding that scales with screen size
  static EdgeInsets getPaddingSymmetric({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: getScaledSize(horizontal),
      vertical: getScaledSize(vertical),
    );
  }

  // Get specific edge padding that scales with screen size
  static EdgeInsets getPaddingOnly({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(
      left: getScaledSize(left),
      top: getScaledSize(top),
      right: getScaledSize(right),
      bottom: getScaledSize(bottom),
    );
  }

  static double sizedBoxWidth(double widthPixel) {
    return width((widthPixel / screenWidth) * 100);
  }

  static double sizedBoxHeight(double hieghtPixel) {
    return height((hieghtPixel / screenHeight) * 100);
  }
}
