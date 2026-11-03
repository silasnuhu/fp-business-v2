import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/widgets/global.dart';

class AppDirectionality {
  static AppDirectionHelper appDirectionHelper = AppDirectionHelper();
  static AppDirectionIcon appDirectionIcon = AppDirectionIcon();
  static AppDirectionBool appDirectionBool = AppDirectionBool();
  static AppDirectionAlign appDirectionAlign = AppDirectionAlign();
  static AppDirectionPadding appDirectionPadding = AppDirectionPadding();
  static AppDirectionBorderRadius appDirectionBorderRadius =
      AppDirectionBorderRadius();
  static AppDirectionPositioned appDirectionPositioned =
      AppDirectionPositioned();
}

class AppDirectionHelper {
  MainAxisAlignment get mainAxis {
    return userTextDirection == 'RTL'
        ? MainAxisAlignment.end
        : MainAxisAlignment.start;
  }

  CrossAxisAlignment get crossAxis {
    return userTextDirection == 'RTL'
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
  }
}

class AppDirectionIcon {
  String get arrow {
    return userTextDirection == 'RTL'
        ? AppAssets
            .arrowLeft1 // back arrow for RTL
        : AppAssets.settingsIcosn.arrowforward; // forward arrow for LTR
  }

  String get arrowForBack {
    return userTextDirection == 'RTL'
        ? AppAssets.settingsIcosn.arrowforward
        : AppAssets.arrowLeft1;
  }
}

class AppDirectionBool {
  bool get isRtl {
    return userTextDirection == 'RTL';
  }

  /// Returns left value if RTL, right value if LTR
  double? positionedLeft(double value) {
    return isRtl ? value : 0;
  }

  double? positionedRight(double value) {
    return isRtl ? 0 : value;
  }
}

class AppDirectionAlign {
  /// Alignment helpers
  Alignment get alignmentLeftRight {
    return userTextDirection == 'RTL'
        ? Alignment.centerRight
        : Alignment.centerLeft;
  }

  Alignment get alignmentEnd {
    return userTextDirection == 'RTL'
        ? Alignment.centerLeft
        : Alignment.centerRight;
  }

  Alignment get alignmentTop {
    return userTextDirection == 'RTL' ? Alignment.topRight : Alignment.topLeft;
  }

  Alignment get alignmentBottom {
    return userTextDirection == 'RTL'
        ? Alignment.bottomRight
        : Alignment.bottomLeft;
  }
}

class AppDirectionPadding {
  /// Padding only on start side (left in LTR, right in RTL)
  EdgeInsets paddingStart(double value) {
    return userTextDirection == 'RTL'
        ? SizeConfig.getPaddingOnly(right: value)
        : SizeConfig.getPaddingOnly(left: value);
  }

  /// Padding only on end side (right in LTR, left in RTL)
  EdgeInsets paddingEnd(double value) {
    return userTextDirection == 'RTL'
        ? SizeConfig.getPaddingOnly(left: value)
        : SizeConfig.getPaddingOnly(right: value);
  }

  /// Padding for both start & end
  EdgeInsets paddingHorizontal(double value) {
    return SizeConfig.getPaddingSymmetric(horizontal: value);
  }

  /// Padding for all sides
  EdgeInsets paddingAll(double value) {
    return SizeConfig.getPadding(value);
  }

  /// Padding with top/bottom + start/end
  EdgeInsets paddingCustom({
    double start = 0,
    double end = 0,
    double top = 0,
    double bottom = 0,
  }) {
    return userTextDirection == 'RTL'
        ? SizeConfig.getPaddingOnly(
          right: start,
          left: end,
          top: top,
          bottom: bottom,
        )
        : SizeConfig.getPaddingOnly(
          left: start,
          right: end,
          top: top,
          bottom: bottom,
        );
  }
}

class AppDirectionBorderRadius {
  /// Returns a border radius with rounded corners on the start side
  BorderRadius radiusStart(double radius) {
    return userTextDirection == 'RTL'
        ? BorderRadius.only(
          topRight: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        )
        : BorderRadius.only(
          topLeft: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
        );
  }

  /// Returns a border radius with rounded corners on the end side
  BorderRadius radiusEnd(double radius) {
    return userTextDirection == 'RTL'
        ? BorderRadius.only(
          topLeft: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
        )
        : BorderRadius.only(
          topRight: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        );
  }

  /// Returns custom start and end radius values
  BorderRadius radiusCustom({
    double start = 0,
    double end = 0,
    double top = 0,
    double bottom = 0,
  }) {
    return userTextDirection == 'RTL'
        ? BorderRadius.only(
          topRight: Radius.circular(start),
          bottomRight: Radius.circular(bottom),
          topLeft: Radius.circular(end),
          bottomLeft: Radius.circular(bottom),
        )
        : BorderRadius.only(
          topLeft: Radius.circular(start),
          bottomLeft: Radius.circular(bottom),
          topRight: Radius.circular(end),
          bottomRight: Radius.circular(bottom),
        );
  }

  /// Uniform radius for all corners
  BorderRadius radiusAll(double radius) {
    return BorderRadius.circular(radius);
  }

  BorderRadius chatBubbleRadius({
    required bool isSentByMe,
    required bool hasParentMessage,
  }) {
    final radiusValue = Radius.circular(hasParentMessage ? 9 : 12);

    // For RTL direction
    if (userTextDirection == 'RTL') {
      if (isSentByMe) {
        return BorderRadius.only(
          topLeft: radiusValue,
          topRight: radiusValue,
          bottomRight: radiusValue,
        );
      } else {
        return BorderRadius.only(
          topLeft: radiusValue,
          topRight: radiusValue,
          bottomLeft: radiusValue,
        );
      }
    }
    // For LTR direction
    else {
      if (isSentByMe) {
        return BorderRadius.only(
          topLeft: radiusValue,
          topRight: radiusValue,
          bottomLeft: radiusValue,
        );
      } else {
        return BorderRadius.only(
          topLeft: radiusValue,
          topRight: radiusValue,
          bottomRight: radiusValue,
        );
      }
    }
  }
}

class AppDirectionPositioned {
  /// Start side (left in LTR, right in RTL)
  double? start(double value) {
    return userTextDirection == 'RTL' ? null : value;
  }

  /// End side (right in LTR, left in RTL)
  double? end(double value) {
    return userTextDirection == 'RTL' ? value : null;
  }

  /// Top
  double? top(double value) => value;

  /// Bottom
  double? bottom(double value) => value;
}
