import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

Widget flexibleSpace() {
  return ClipRRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15.6, sigmaY: 15.6),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppColors.appPriSecColor.secondaryColor,
              AppColors.appPriSecColor.primaryColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).withOpacity(0.04),
        ),
      ),
    ),
  );
}

Widget scaffoldPageDesign({required Widget child}) {
  return Container(
    color: AppColors.white,
    child: Stack(
      children: [
        child,
        Positioned(
          top: -156,
          left: 187,
          child: Container(
            height: SizeConfig.sizedBoxHeight(254),
            width: SizeConfig.sizedBoxWidth(254),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.appPriSecColor.secondaryColor,
                  AppColors.appPriSecColor.primaryColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          top: -92,
          left: 268,
          child: Container(
            height: SizeConfig.sizedBoxHeight(254),
            width: SizeConfig.sizedBoxWidth(254),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.appPriSecColor.secondaryColor,
                  AppColors.appPriSecColor.primaryColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          bottom: -95,
          left: -158,
          child: Container(
            height: SizeConfig.sizedBoxHeight(254),
            width: SizeConfig.sizedBoxWidth(254),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.appPriSecColor.secondaryColor,
                  AppColors.appPriSecColor.primaryColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).withOpacity(0.08),
            ),
          ),
        ),
      ],
    ),
  );
}

SystemUiOverlayStyle systemUI() {
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness:
        AppThemeManage.appTheme.brightnessDarkLight, // For Android
    statusBarBrightness:
        AppThemeManage.appTheme.brightnessLightDark, // For iOS (inverted logic)
  );
}

Widget innerContainer(BuildContext context, {required Widget child}) {
  return Container(
    width: MediaQuery.sizeOf(context).width,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: <Color>[
          AppColors.appPriSecColor.primaryColor,
          AppColors.appPriSecColor.secondaryColor,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: Container(
      width: MediaQuery.sizeOf(context).width,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: child,
    ),
  );
}

Widget innerContainerGrad(BuildContext context, {required Widget child}) {
  return Container(
    width: MediaQuery.sizeOf(context).width,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: <Color>[
          AppColors.appPriSecColor.primaryColor,
          AppColors.appPriSecColor.secondaryColor,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: Container(
      width: MediaQuery.sizeOf(context).width,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: child,
    ),
  );
}
