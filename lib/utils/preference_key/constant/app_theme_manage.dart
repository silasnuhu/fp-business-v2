// ****** isLightModeGlobal ? LIGHT MODE : DARK MODE; ******//
import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

class AppThemeManage {
  static final AppTheme appTheme = AppTheme();
}

class AppTheme {
  Color get scaffoldBackColor => isLightModeGlobal
      ? AppColors.bgColor.bg4Color
      : AppColors.darkModeColor.blackColor;

  Color get borderColor => isLightModeGlobal
      ? AppColors.strokeColor.cECECEC
      : AppColors.darkModeColor.blackGrayBorder;

  Color get textColor => isLightModeGlobal
      ? AppColors.textColor.textBlackColor
      : AppColors.textColor.textWhiteColor;

  Color get darkGreyColor => isLightModeGlobal
      ? AppColors.bgColor.bg4Color
      : AppColors.darkModeColor.blackGray;

  Color get darkWhiteColor => isLightModeGlobal
      ? AppColors.darkModeColor.blackColor
      : AppColors.bgColor.bg4Color;

  Color get chatOppoColor => isLightModeGlobal
      ? AppColors.bgColor.bg2Color
      : AppColors.darkModeColor.chatDarkColor1;

  Color get chatOppText => isLightModeGlobal
      ? AppColors.bgColor.bg2Color
      : AppColors.darkModeColor.chatDarkColor1;

  Color get chatAudiVideoContainerColor => isLightModeGlobal
      ? AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.3)
      : AppColors.darkModeColor.blackGray;

  Color get chatAudiVideoContBorColor => isLightModeGlobal
      ? AppColors.transparent
      : AppColors.bgColor.bg4Color.withValues(alpha: 0.16);

  Color get chatMediaText => isLightModeGlobal
      ? AppColors.textColor.textBlackColor
      : AppColors.darkModeColor.blackTextGrey;

  Color get strokBorder => isLightModeGlobal
      ? AppColors.strokeColor.cF9F9F9
      : AppColors.darkModeColor.blackGray;

  Color get strokBorder2 => isLightModeGlobal
      ? AppColors.strokeColor.greyColor
      : AppColors.darkModeColor.blackGray;

  Color get chatBuuble => isLightModeGlobal
      ? AppColors.chatBubbleColor.chatPriBubble
      : AppColors.appPriSecColor.primaryColor;

  Color get blackPrimary => isLightModeGlobal
      ? AppColors.bgColor.bgBlack
      : AppColors.appPriSecColor.primaryColor;

  Color get appSndColor => isLightModeGlobal
      ? AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.5)
      : AppColors.appPriSecColor.secondaryColor;

  Color get appSndColor2 => isLightModeGlobal
      ? AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.5)
      : AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.1);

  Color get shimmerBaseColor => isLightModeGlobal
      ? Colors.grey.shade300
      : AppColors.darkModeColor.blackGrayBorder;

  Color get shimmerHighColor => isLightModeGlobal
      ? Colors.grey.shade100
      : AppColors.darkModeColor.blackGray;

  LinearGradient get starredGradient => isLightModeGlobal
      ? AppColors.gradientColor.starredColor
      : AppColors.gradientColor.starredColorDark;

  Color get starredOppa => isLightModeGlobal
      ? AppColors.white.withValues(alpha: 0.8)
      : AppColors.black.withValues(alpha: 0.8);

  Color get greyBorder => isLightModeGlobal
      ? Colors.grey.shade100
      : AppColors.darkModeColor.blackGray;

  Color get pinColor => isLightModeGlobal
      ? AppColors.darkModeColor.blackColor
      : AppColors.textColor.textGreyColor;

  Color get blackBg4Color => isLightModeGlobal
      ? AppColors.darkModeColor.blackColor
      : AppColors.bgColor.bg4Color;

  Color get bg4BlackColor => isLightModeGlobal
      ? AppColors.bgColor.bg4Color
      : AppColors.darkModeColor.blackColor;

  Color get greyBlackGrey => isLightModeGlobal
      ? AppColors.strokeColor.greyColor
      : AppColors.darkModeColor.blackGrayBorder;

  Color get bg4BlackGrey => isLightModeGlobal
      ? AppColors.bgColor.bg4Color
      : AppColors.darkModeColor.blackGray;

  Color get bg4Darkgrey => isLightModeGlobal
      ? AppColors.bgColor.bg4Color
      : AppColors.darkModeColor.blackGray;

  Color get textGreyblackGrey => isLightModeGlobal
      ? AppColors.textColor.textGreyColor
      : AppColors.darkModeColor.blackGrayBorder;

  Color get appSndColor3 => isLightModeGlobal
      ? AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.3)
      : AppColors.appPriSecColor.secondaryColor;

  Color get bg4DarkGrey => isLightModeGlobal
      ? AppColors.bgColor.bg4Color.withValues(alpha: 0.88)
      : AppColors.darkModeColor.blackGray;

  Color get black10 =>
      isLightModeGlobal ? Colors.white10 : AppColors.darkModeColor.blackColor;

  Color get transprent => isLightModeGlobal
      ? AppColors.transparent
      : AppColors.darkModeColor.blackGrayBorder;

  Color get traprentBg4 =>
      isLightModeGlobal ? AppColors.bgColor.bg4Color : AppColors.transparent;

  LinearGradient get gradintLogoColor => isLightModeGlobal
      ? AppColors.gradientColor.logoColor.withOpacity(0.30)
      : AppColors.gradientColor.logoColor.withOpacity(0.06);

  LinearGradient get primSecoOppcaity => isLightModeGlobal
      ? LinearGradient(
          colors: <Color>[
            AppColors.appPriSecColor.secondaryColor,
            AppColors.appPriSecColor.primaryColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).withOpacity(0.30)
      : LinearGradient(
          colors: <Color>[
            AppColors.appPriSecColor.secondaryColor,
            AppColors.appPriSecColor.primaryColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).withOpacity(0.06);

  Color get textGreyWhite => isLightModeGlobal
      ? AppColors.textColor.textDarkGray
      : AppColors.textColor.textWhiteColor;

  Color get bg3DarkGrey => isLightModeGlobal
      ? AppColors.bgColor.bg3Color.withValues(alpha: 0.5)
      : AppColors.darkModeColor.blackGray;

  Color get greyOppBorder => isLightModeGlobal
      ? AppColors.strokeColor.greyColor.withValues(alpha: 0.3)
      : AppColors.darkModeColor.blackGrayBorder;

  Color get bg488DarkGrey => isLightModeGlobal
      ? AppColors.bgColor.bg4Color.withValues(alpha: 0.88)
      : AppColors.darkModeColor.blackGray;

  Color get whiteBorder => isLightModeGlobal
      ? AppColors.white.withValues(alpha: 0.9)
      : AppColors.darkModeColor.blackGrayBorder;

  Color get textWhiteBlack => isLightModeGlobal
      ? AppColors.textColor.textWhiteColor
      : AppColors.textColor.textBlackColor;

  Color get whiteBlck => isLightModeGlobal ? AppColors.white : AppColors.black;

  //***************************************************************************/

  Brightness get brightnessDarkLight =>
      isLightModeGlobal ? Brightness.dark : Brightness.light;

  // For iOS status bar (inverted logic)
  Brightness get brightnessLightDark =>
      isLightModeGlobal ? Brightness.light : Brightness.dark;

  //********************************Strings , Assets manage *******************************************/

  String get lightDarkText =>
      isLightModeGlobal ? AppString.lightMode : AppString.darkMode;

  String get appDarkLightIcon => isLightModeGlobal
      ? AppAssets.darkLightIcons.moon
      : AppAssets.darkLightIcons.sun;

  //****************************** Widget manage *********************************************/

  Widget get appDarkLightLogo => isLightModeGlobal
      ? appDynamicLogo(height: SizeConfig.sizedBoxHeight(75))
      : appDynamicLogoDark(height: SizeConfig.sizedBoxHeight(75));

  Widget get appHomelogo => isLightModeGlobal
      ? appDynamicLogo(height: SizeConfig.sizedBoxHeight(30))
      : appDynamicLogoDark(height: SizeConfig.sizedBoxHeight(30));

  //***************************************************************************/

  double get appInt => isLightModeGlobal ? 0.1 : 0.5;
}
