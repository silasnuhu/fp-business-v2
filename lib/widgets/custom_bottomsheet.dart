import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

Future<T?> bottomSheetGobal<T>(
  BuildContext context, {
  EdgeInsets? insetPadding,
  BorderRadiusGeometry? borderRadius,
  bool isCloseIcon = false,
  required double bottomsheetHeight,
  required String title,
  required Widget child,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color.fromRGBO(0, 0, 0, 0.57),
    builder:
        (_) => Dialog(
          alignment: Alignment.bottomCenter,
          elevation: 0,
          insetPadding:
              insetPadding ??
              SizeConfig.getPaddingOnly(left: 15, right: 15, bottom: 15),
          backgroundColor: AppColors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius:
                borderRadius ??
                BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3.8, sigmaY: 3.8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                isCloseIcon
                    ? SizedBox.shrink()
                    : GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: SizeConfig.sizedBoxHeight(35),
                        width: SizeConfig.sizedBoxWidth(35),
                        decoration: BoxDecoration(
                          color: AppThemeManage.appTheme.darkGreyColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: AppThemeManage.appTheme.textColor,
                          ),
                        ),
                      ),
                    ),
                SizedBox(height: SizeConfig.height(1.5)),
                Container(
                  decoration: BoxDecoration(
                    color: AppThemeManage.appTheme.scaffoldBackColor,
                    borderRadius: borderRadius ?? BorderRadius.circular(20),
                  ),
                  height: bottomsheetHeight,
                  width: SizeConfig.screenWidth,
                  child: ClipRRect(
                    borderRadius: borderRadius ?? BorderRadius.circular(20),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              AppAssets.dotted1,
                              color: AppColors.appPriSecColor.primaryColor,
                            ),
                            Text(title, style: AppTypography.h4(context)),
                          ],
                        ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
}

Future<T?> bottomSheetGobalWithoutTitle<T>(
  BuildContext context, {
  EdgeInsets? insetPadding,
  BorderRadiusGeometry? borderRadius,
  AlignmentGeometry? alignment,
  bool isCenter = false,
  bool isCrossIconHide = false,
  bool barrierDismissible = true,
  // When true, `bottomsheetHeight` is treated as a max height cap and the
  // sheet shrinks to fit `child`'s actual content instead of always being
  // forced to that exact height. Without this, a fixed `height` gives the
  // panel's Column tight constraints, so on devices where the height (scaled
  // via SizeConfig) ends up taller than the content, the leftover space
  // renders as blank space inside the sheet.
  bool shrinkWrap = false,
  required double bottomsheetHeight,
  required Widget child,
}) {
  return showDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color.fromRGBO(0, 0, 0, 0.57),
    builder:
        // ignore: deprecated_member_use
        (_) => Dialog(
          alignment: alignment ?? Alignment.bottomCenter,
          elevation: 0,
          insetPadding:
              insetPadding ??
              SizeConfig.getPaddingOnly(left: 15, right: 15, bottom: 15),
          backgroundColor: AppColors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3.8, sigmaY: 3.8),
            child: Column(
              mainAxisAlignment:
                  isCenter ? MainAxisAlignment.center : MainAxisAlignment.end,
              children: [
                isCrossIconHide
                    ? SizedBox.shrink()
                    : GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: SizeConfig.sizedBoxHeight(35),
                        width: SizeConfig.sizedBoxWidth(35),
                        decoration: BoxDecoration(
                          color: AppThemeManage.appTheme.darkGreyColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: AppThemeManage.appTheme.textColor,
                          ),
                        ),
                      ),
                    ),
                isCrossIconHide
                    ? SizedBox.shrink()
                    : SizedBox(height: SizeConfig.height(2)),
                Container(
                  decoration: BoxDecoration(
                    color: AppThemeManage.appTheme.scaffoldBackColor,
                    borderRadius: borderRadius ?? BorderRadius.circular(20),
                  ),
                  height: shrinkWrap ? null : bottomsheetHeight,
                  constraints:
                      shrinkWrap
                          ? BoxConstraints(maxHeight: bottomsheetHeight)
                          : null,
                  width: SizeConfig.screenWidth,
                  child: child,
                ),
              ],
            ),
          ),
        ),
  );
}

Future<T?> showBottomSheetGobal<T>(
  BuildContext context, {
  EdgeInsets? insetPadding,
  BorderRadiusGeometry? borderRadius,
  bool isCloseIcon = false,
  required double bottomsheetHeight,
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true, // Allow the bottom sheet to adjust to keyboard
    backgroundColor: AppColors.transparent,
    barrierColor: const Color.fromRGBO(0, 0, 0, 0.57),

    shape: RoundedRectangleBorder(
      borderRadius:
          borderRadius ??
          const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
    ),
    builder:
        (context) => Padding(
          padding: MediaQuery.of(context).viewInsets, // Adjust for keyboard
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3.8, sigmaY: 3.8),
            child: SafeArea(
              child: Padding(
                padding:
                    insetPadding ??
                    SizeConfig.getPaddingOnly(left: 15, right: 15, bottom: 15),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isCloseIcon)
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Container(
                            height: SizeConfig.sizedBoxHeight(35),
                            width: SizeConfig.sizedBoxWidth(35),
                            decoration: BoxDecoration(
                              color: AppThemeManage.appTheme.darkGreyColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: AppThemeManage.appTheme.textColor,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: SizeConfig.height(1.5)),
                      Container(
                        decoration: BoxDecoration(
                          color: AppThemeManage.appTheme.scaffoldBackColor,
                          borderRadius:
                              borderRadius ?? BorderRadius.circular(20),
                        ),
                        constraints: BoxConstraints(
                          maxHeight: bottomsheetHeight,
                          minHeight: 100, // Minimum height to avoid collapsing
                        ),
                        width: SizeConfig.screenWidth,
                        child: ClipRRect(
                          borderRadius:
                              borderRadius ?? BorderRadius.circular(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.asset(
                                    AppAssets.dotted1,
                                    color:
                                        AppColors.appPriSecColor.primaryColor,
                                  ),
                                  Text(title, style: AppTypography.h4(context)),
                                ],
                              ),
                              Flexible(child: child),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
  );
}

Future<T?> bottomSheetGobalVoice<T>(
  BuildContext context, {
  EdgeInsets? insetPadding,
  BorderRadiusGeometry? borderRadius,
  required double bottomsheetHeight,
  required Widget child,
  bool barrierDismissible = false,
}) {
  return showGeneralDialog(
    context: context,
    useRootNavigator: true, // 🔥 IMPORTANT
    barrierDismissible: barrierDismissible,
    barrierLabel: "Voice",
    barrierColor: const Color.fromRGBO(0, 0, 0, 0.57),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin:
                insetPadding ??
                const EdgeInsets.only(left: 15, right: 15, bottom: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: borderRadius ?? BorderRadius.circular(20),
            ),
            height: bottomsheetHeight,
            width: MediaQuery.of(context).size.width,
            child: child,
          ),
        ),
      );
    },
  );
}
