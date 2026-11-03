// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';
import 'package:whoxa/main.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/avatar_initials.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/featuers/chat/widgets/chat_files_views_handle/image_view.dart';
import 'package:whoxa/widgets/clip_path.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';

String contrycode =
    '+1'; // Default fallback (US) - will be updated by device detection
String? phone;
String authToken = "";
String userID = "";
String userName = "";
String firstName = "";
String lastName = "";
String gender = "";
String mobileNum = "";
String country = "";
String countryShortName = "";
String email = "";
String bio = "";
String loginType = "";
bool permission = false;
bool isDemo = false;
String appVersion = "";
String userProfile = "";
bool isPhoneAuthEnabled = false;
bool isEmailAuthEnabled = false;
String appLogo = '';
String appLogoDarkMode = '';
String appName = '';
String appPrimeColor = '';
String appSecColor = '';
bool demoCredential = false;
String termsConditionText = "";
String privacyPoicyText = "";
String stroyCaption = "";
String stroyCaptionRecent = "";
String stroyCaptionView = "";
String googleMapKey = "YOUR_GOOGLE_MAPS_API_KEY";

/// A story caption is only worth rendering when it's real text — not empty
/// and not the literal string "null" (which used to leak in from
/// `caption.toString()` when the backend sent `caption: null`).
bool hasStoryCaption(String? caption) {
  final c = caption?.trim() ?? '';
  return c.isNotEmpty && c.toLowerCase() != 'null';
}

String langID = '';
String storyTime = '';
String? storyID;
bool isLightModeGlobal = true;
String chatMediaText = "";
String userTextDirection = "";
String toUserProfileCall = "";

String formatStoryTime(String isoTime) {
  final now = DateTime.now();
  final date = DateTime.parse(isoTime).toLocal();

  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final storyDate = DateTime(date.year, date.month, date.day);

  if (storyDate == today) {
    return AppString.todayAtTime(DateFormat.jm().format(date)); // 7:30 PM
  } else if (storyDate == yesterday) {
    return AppString.yesterdayAtTime(DateFormat.jm().format(date)); // 9:15 AM
  } else {
    return AppString.dateAtTime(DateFormat('MMM d').format(date), DateFormat.jm().format(date));
  }
}

Widget appLogoAppName({required double logheight, required double fontSize}) {
  return Row(
    children: [
      appDynamicLogo(height: logheight),
      SizedBox(width: SizeConfig.width(2)),
      Text(
        appName,
        style: TextStyle(
          color: AppThemeManage.appTheme.textColor,
          fontWeight: FontWeight.w600,
          fontSize: SizeConfig.getFontSize(fontSize),
          fontFamily: AppTypography.fontFamily.jostSemiBold,
        ),
      ),
    ],
  );
}

Widget appDynamicLogo({double? height}) {
  logger.i("appLogoLightMode:$appLogo");
  final double imageHeight = SizeConfig.sizedBoxHeight(height ?? 80);

  // ✅ No logo URL known yet (e.g. genuinely first launch, before any
  // project-config fetch has ever succeeded) — show the bundled fallback
  // instead of an indefinitely-spinning placeholder on an empty URL.
  if (appLogo.isEmpty) {
    return SvgPicture.asset(AppAssets.chatAppLogo, height: imageHeight);
  }

  if (appLogo.toLowerCase().endsWith(".svg")) {
    return SvgPicture.network(
      appLogo,
      height: imageHeight,
      placeholderBuilder:
          (context) => SizedBox(
            height: imageHeight,
            width: imageHeight,
            child: Center(child: commonLoading()),
          ),
    );
  } else {
    return Image.network(
      appLogo,
      height: imageHeight,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          height: imageHeight,
          width: imageHeight,
          child: Center(child: commonLoading()),
        );
      },
    );
  }
}

Widget appDynamicLogoDark({double? height}) {
  logger.i("appLogoDarkMode:$appLogoDarkMode");
  final double imageHeight = SizeConfig.sizedBoxHeight(height ?? 80);
  debugPrint('appLogoDark:$appLogoDarkMode');

  // ✅ No logo URL known yet — show the bundled fallback instead of an
  // indefinitely-spinning placeholder on an empty URL.
  if (appLogoDarkMode.isEmpty) {
    return SvgPicture.asset(AppAssets.chatWhiteAppLogo, height: imageHeight);
  }

  if (appLogoDarkMode.toLowerCase().endsWith(".svg")) {
    return SvgPicture.network(
      appLogoDarkMode,
      height: imageHeight,
      placeholderBuilder:
          (context) => SizedBox(
            height: imageHeight,
            width: imageHeight,
            child: Center(child: commonLoading()),
          ),
    );
  } else {
    return Image.network(
      appLogoDarkMode,
      height: imageHeight,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          height: imageHeight,
          width: imageHeight,
          child: Center(child: commonLoading()),
        );
      },
    );
  }
}

bool isURL(String? text) {
  // Regular expression to match common link patterns
  final RegExp linkRegex = RegExp(
    r'^(http[s]?:\/\/|www\.)\S+',
    caseSensitive: false,
  );

  // Check if the text matches the link pattern
  return linkRegex.hasMatch(text!);
}

bool isURL2(String? text) {
  if (text == null || text.isEmpty) return false;
  final RegExp linkRegex = RegExp(
    r'(https?:\/\/|www\.)\S+',
    caseSensitive: false,
  );
  return linkRegex.hasMatch(text); // hasMatch = found anywhere in string
}

Future<void> launchURL(String url) async {
  try {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  } on PlatformException catch (e) {
    debugPrint("Error launching URL: $e");
  } catch (e) {
    debugPrint("Unexpected error: $e");
  }
}

Widget commonLoading() {
  return Padding(
    padding: EdgeInsets.all(3.0),
    child: CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: AlwaysStoppedAnimation<Color>(
        AppColors.appPriSecColor.primaryColor,
      ),
    ),
  );
}

Widget commonLoading2() {
  return CircularProgressIndicator(
    strokeWidth: 2,
    valueColor: AlwaysStoppedAnimation<Color>(
      AppThemeManage.appTheme.blackBg4Color,
    ), // Acts as a mask
  );
}

Widget container(
  BuildContext context, {
  required Widget child,
  double? radius,
  List<BoxShadow>? boxShadow,
  BoxBorder? border,
}) {
  return Container(
    // height: height,
    decoration: BoxDecoration(
      border: border ?? Border.all(color: AppColors.transparent),
      borderRadius: BorderRadius.circular(radius ?? 32),
      color: AppThemeManage.appTheme.darkGreyColor,
      boxShadow:
          boxShadow ??
          [
            BoxShadow(
              offset: Offset(0, -3),
              spreadRadius: 0,
              blurRadius: 37.8,
              color: AppColors.black.withValues(alpha: 0.20),
            ),
          ],
    ),
    child: child,
  );
}

Widget customBtn(
  BuildContext context, {
  required Function()? onTap,
  required String title,
  BorderRadiusGeometry? borderRadius,
}) {
  return Container(
    decoration: BoxDecoration(
      // gradient: AppColors.gradientColor.gradientColor,
      color: AppColors.appPriSecColor.primaryColor,
      borderRadius: borderRadius ?? BorderRadius.circular(10),
    ),
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.transparent,
        shadowColor: AppColors.transparent,
        fixedSize: Size(SizeConfig.screenWidth, SizeConfig.safeHeight(5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Center(
        child: Text(
          title,
          style: AppTypography.buttonText(context).copyWith(
            color: ThemeColorPalette.getTextColor(
              AppColors.appPriSecColor.primaryColor,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget customBtn2(
  BuildContext context, {
  required Function()? onTap,
  double? width,
  double? height,
  BorderRadiusGeometry? borderRadius,
  required Widget child,
  Color? color,
  List<BoxShadow>? boxShadow,
}) {
  return Container(
    decoration: BoxDecoration(
      boxShadow:
          boxShadow ??
          [
            BoxShadow(
              blurRadius: 7.5,
              offset: Offset(3, 3),
              spreadRadius: 0,
              color: AppColors.bgColor.bgBlack.withValues(alpha: 0.16),
            ),
          ],
      color: color ?? AppColors.appPriSecColor.primaryColor,
      borderRadius: borderRadius ?? BorderRadius.circular(10),
    ),
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.transparent,
        shadowColor: AppColors.transparent,
        fixedSize: Size(
          width ?? SizeConfig.safeWidth(MediaQuery.sizeOf(context).width),
          height ?? SizeConfig.sizedBoxHeight(45),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: child,
    ),
  );
}

Widget customBorderBtn(
  BuildContext context, {
  required Function()? onTap,
  required String title,
  TextStyle? style,
}) {
  return Container(
    decoration: BoxDecoration(
      color: AppThemeManage.appTheme.scaffoldBackColor,
      border: Border.all(color: AppColors.appPriSecColor.primaryColor),
      borderRadius: BorderRadius.circular(10),
    ),
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shadowColor: AppColors.transparent,
        backgroundColor: AppColors.transparent,
        fixedSize: Size(SizeConfig.screenWidth, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Center(
        child: Text(title, style: style ?? AppTypography.buttonText(context)),
      ),
    ),
  );
}

class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
  });

  final String text;
  final TextStyle? style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback:
          (bounds) => gradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
      child: Text(text, style: style, maxLines: 1),
    );
  }
}

// snackbar({required String title, required String msg}) {
//   return Get.snackbar(title, msg, snackPosition: SnackPosition.BOTTOM);
// }

// snackbarNew(BuildContext context, {required String title, required String msg}) {
//   final snackBar = SnackBar(
//     backgroundColor: AppColors.shadowColor.c000000.withValues(alpha: 0.2),
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//     content: Column(
//       mainAxisSize: MainAxisSize.min,
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           title,
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             color: AppColors.textColor.textBlackColor,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           msg,
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             color: AppColors.textColor.textBlackColor,
//           ),
//         ),
//       ],
//     ),
//     behavior: SnackBarBehavior.floating,
//   );

//   ScaffoldMessenger.of(context).showSnackBar(snackBar);
// }

void snackbarNew(
  BuildContext context, {
  required String msg,
  Color? backgroundColor,
}) {
  // ✅ Always resolve a safe context from the root navigator
  final safeContext = Navigator.of(context, rootNavigator: true).context;

  final messenger = ScaffoldMessenger.of(safeContext);

  final snackBar = SnackBar(
    backgroundColor: backgroundColor ?? AppColors.appPriSecColor.secondaryColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    content: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            msg,
            style: Theme.of(safeContext).textTheme.bodySmall?.copyWith(
              color: ThemeColorPalette.getTextColor(
                AppColors.appPriSecColor.primaryColor,
              ),
            ),
            maxLines: 3,
            overflow: TextOverflow.fade,
          ),
        ),
        SizedBox(width: 8),
        InkWell(
          onTap: () => messenger.hideCurrentSnackBar(),
          child: Icon(
            Icons.close,
            size: SizeConfig.sizedBoxHeight(18),
            color: ThemeColorPalette.getTextColor(
              AppColors.appPriSecColor.primaryColor,
            ),
          ),
        ),
      ],
    ),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
  );

  messenger.showSnackBar(snackBar);
}

Widget snackBarCustom({required String msg}) {
  return Align(
    alignment: Alignment.bottomCenter,
    child: Container(
      width: SizeConfig.screenWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: AppColors.appPriSecColor.secondaryColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            msg,
            style: TextStyle(fontSize: 10, color: AppColors.black),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

Widget customeBackArrow(BuildContext context) {
  return GestureDetector(
    onTap: () {
      Navigator.pop(context);
    },
    child: SvgPicture.asset(
      AppAssets.arrowleftwh,
      height: SizeConfig.safeHeight(3.5),
    ),
  );
}

// Widget customeBackArrowBalck(BuildContext context) {
//   return GestureDetector(
//     onTap: () {
//       Navigator.pop(context);
//     },
//     child: SvgPicture.asset(AppAssets.arrowLeft1, height: 20),
//   );
// }

Widget customeBackArrowBalck(
  BuildContext context, {
  dynamic result,
  bool isBackBlack = false,
  Color? color,
}) {
  return GestureDetector(
    onTap: () {
      Navigator.pop(context, result);
    },
    child: SvgPicture.asset(
      AppDirectionality.appDirectionIcon.arrowForBack,
      height: 30,
      color:
          color ??
          (isLightModeGlobal
              ? AppColors.darkModeColor.blackColor
              : isBackBlack
              ? AppColors.darkModeColor.blackColor
              : AppColors.bgColor.bg4Color),
    ),
  );
}

String getMobile(String number) {
  return number
      .toString()
      .trim()
      .replaceAll(' ', '')
      .replaceAll(' ', '')
      .replaceAll('  ', '')
      .replaceAll("(", "")
      .replaceAll(")", "")
      .replaceAll("+93", "")
      .replaceAll("+358", "")
      .replaceAll("+355", "")
      .replaceAll("+213", "")
      .replaceAll("+1", "")
      .replaceAll("+376", "")
      .replaceAll("+244", "")
      .replaceAll("+1", "")
      .replaceAll("+1", "")
      .replaceAll("+54", "")
      .replaceAll("+374", "")
      .replaceAll("+297", "")
      .replaceAll("+247", "")
      .replaceAll("+61", "")
      .replaceAll("+672", "")
      .replaceAll("+43", "")
      .replaceAll("+994", "")
      .replaceAll("+1", "")
      .replaceAll("+973", "")
      .replaceAll("+880", "")
      .replaceAll("+1", "")
      .replaceAll("+375", "")
      .replaceAll("+32", "")
      .replaceAll("+501", "")
      .replaceAll("+229", "")
      .replaceAll("+93", "")
      .replaceAll("+355", "")
      .replaceAll("+213", "")
      .replaceAll("+1-684", "")
      .replaceAll("+376", "")
      .replaceAll("+244", "")
      .replaceAll("+1-264", "")
      .replaceAll("+672", "")
      .replaceAll("+1-268", "")
      .replaceAll("+54", "")
      .replaceAll("+374", "")
      .replaceAll("+297", "")
      .replaceAll("+61", "")
      .replaceAll("+43", "")
      .replaceAll("+994", "")
      .replaceAll("+1-242", "")
      .replaceAll("+973", "")
      .replaceAll("+880", "")
      .replaceAll("+1-246", "")
      .replaceAll("+375", "")
      .replaceAll("+32", "")
      .replaceAll("+501", "")
      .replaceAll("+229", "")
      .replaceAll("+1-441", "")
      .replaceAll("+975", "")
      .replaceAll("+591", "")
      .replaceAll("+387", "")
      .replaceAll("+267", "")
      .replaceAll("+55", "")
      .replaceAll("+246", "")
      .replaceAll("+1-284", "")
      .replaceAll("+673", "")
      .replaceAll("+359", "")
      .replaceAll("+226", "")
      .replaceAll("+257", "")
      .replaceAll("+855", "")
      .replaceAll("+237", "")
      .replaceAll("+1", "")
      .replaceAll("+238", "")
      .replaceAll("+1-345", "")
      .replaceAll("+236", "")
      .replaceAll("+235", "")
      .replaceAll("+56", "")
      .replaceAll("+86", "")
      .replaceAll("+61", "")
      .replaceAll("+61", "")
      .replaceAll("+57", "")
      .replaceAll("+269", "")
      .replaceAll("+682", "")
      .replaceAll("+506", "")
      .replaceAll("+385", "")
      .replaceAll("+53", "")
      .replaceAll("+599", "")
      .replaceAll("+357", "")
      .replaceAll("+420", "")
      .replaceAll("+243", "")
      .replaceAll("+45", "")
      .replaceAll("+253", "")
      .replaceAll("+1-767", "")
      .replaceAll("+1-809", "")
      .replaceAll("+1-829", "")
      .replaceAll("+1-849", "")
      .replaceAll("+670", "")
      .replaceAll("+593", "")
      .replaceAll("+20", "")
      .replaceAll("+503", "")
      .replaceAll("+240", "")
      .replaceAll("+291", "")
      .replaceAll("+372", "")
      .replaceAll("+251", "")
      .replaceAll("+500", "")
      .replaceAll("+298", "")
      .replaceAll("+679", "")
      .replaceAll("+358", "")
      .replaceAll("+33", "")
      .replaceAll("+689", "")
      .replaceAll("+241", "")
      .replaceAll("+220", "")
      .replaceAll("+995", "")
      .replaceAll("+49", "")
      .replaceAll("+233", "")
      .replaceAll("+350", "")
      .replaceAll("+30", "")
      .replaceAll("+299", "")
      .replaceAll("+1-473", "")
      .replaceAll("+1-671", "")
      .replaceAll("+502", "")
      .replaceAll("+44-1481", "")
      .replaceAll("+224", "")
      .replaceAll("+245", "")
      .replaceAll("+592", "")
      .replaceAll("+509", "")
      .replaceAll("+504", "")
      .replaceAll("+852", "")
      .replaceAll("+36", "")
      .replaceAll("+354", "")
      .replaceAll("+91", "")
      .replaceAll("+62", "")
      .replaceAll("+98", "")
      .replaceAll("+964", "")
      .replaceAll("+353", "")
      .replaceAll("+44-1624", "")
      .replaceAll("+972", "")
      .replaceAll("+39", "")
      .replaceAll("+225", "")
      .replaceAll("+1-876", "")
      .replaceAll("+81", "")
      .replaceAll("+44-1534", "")
      .replaceAll("+962", "")
      .replaceAll("+7", "")
      .replaceAll("+254", "")
      .replaceAll("+686", "")
      .replaceAll("+383", "")
      .replaceAll("+965", "")
      .replaceAll("+996", "")
      .replaceAll("+856", "")
      .replaceAll("+371", "")
      .replaceAll("+961", "")
      .replaceAll("+266", "")
      .replaceAll("+231", "")
      .replaceAll("+218", "")
      .replaceAll("+423", "")
      .replaceAll("+370", "")
      .replaceAll("+352", "")
      .replaceAll("+853", "")
      .replaceAll("+389", "")
      .replaceAll("+261", "")
      .replaceAll("+265", "")
      .replaceAll("+60", "")
      .replaceAll("+960", "")
      .replaceAll("+223", "")
      .replaceAll("+356", "")
      .replaceAll("+692", "")
      .replaceAll("+222", "")
      .replaceAll("+230", "")
      .replaceAll("+262", "")
      .replaceAll("+52", "")
      .replaceAll("+691", "")
      .replaceAll("+373", "")
      .replaceAll("+377", "")
      .replaceAll("+976", "")
      .replaceAll("+382", "")
      .replaceAll("+1-664", "")
      .replaceAll("+212", "")
      .replaceAll("+258", "")
      .replaceAll("+95", "")
      .replaceAll("+264", "")
      .replaceAll("+674", "")
      .replaceAll("+977", "")
      .replaceAll("+31", "")
      .replaceAll("+599", "")
      .replaceAll("+687", "")
      .replaceAll("+64", "")
      .replaceAll("+505", "")
      .replaceAll("+227", "")
      .replaceAll("+234", "")
      .replaceAll("+683", "")
      .replaceAll("+850", "")
      .replaceAll("+1-670", "")
      .replaceAll("+47", "")
      .replaceAll("+968", "")
      .replaceAll("+92", "")
      .replaceAll("+680", "")
      .replaceAll("+970", "")
      .replaceAll("+507", "")
      .replaceAll("+675", "")
      .replaceAll("+595", "")
      .replaceAll("+51", "")
      .replaceAll("+63", "")
      .replaceAll("+64", "")
      .replaceAll("+48", "")
      .replaceAll("+351", "")
      .replaceAll("+1-787", "")
      .replaceAll("+1-939", "")
      .replaceAll("+974", "")
      .replaceAll("+242", "")
      .replaceAll("+262", "")
      .replaceAll("+40", "")
      .replaceAll("+7", "")
      .replaceAll("+250", "")
      .replaceAll("+590", "")
      .replaceAll("+290", "")
      .replaceAll("+1-869", "")
      .replaceAll("+1-758", "")
      .replaceAll("+590", "")
      .replaceAll("+508", "")
      .replaceAll("+1-784", "")
      .replaceAll("+685", "")
      .replaceAll("+378", "")
      .replaceAll("+239", "")
      .replaceAll("+966", "")
      .replaceAll("+221", "")
      .replaceAll("+381", "")
      .replaceAll("+248", "")
      .replaceAll("+232", "")
      .replaceAll("+65", "")
      .replaceAll("+1-721", "")
      .replaceAll("+421", "")
      .replaceAll("+386", "")
      .replaceAll("+677", "")
      .replaceAll("+252", "")
      .replaceAll("+27", "")
      .replaceAll("+82", "")
      .replaceAll("+211", "")
      .replaceAll("+34", "")
      .replaceAll("+94", "")
      .replaceAll("+249", "")
      .replaceAll("+597", "")
      .replaceAll("+47", "")
      .replaceAll("+268", "")
      .replaceAll("+46", "")
      .replaceAll("+41", "")
      .replaceAll("+963", "")
      .replaceAll("+886", "")
      .replaceAll("+992", "")
      .replaceAll("+255", "")
      .replaceAll("+66", "")
      .replaceAll("+228", "")
      .replaceAll("+690", "")
      .replaceAll("+676", "")
      .replaceAll("+1-868", "")
      .replaceAll("+216", "")
      .replaceAll("+90", "")
      .replaceAll("+993", "")
      .replaceAll("+1-649", "")
      .replaceAll("+688", "")
      .replaceAll("+1-340", "")
      .replaceAll("+256", "")
      .replaceAll("+380", "")
      .replaceAll("+971", "")
      .replaceAll("+44", "")
      .replaceAll("+1", "")
      .replaceAll("+598", "")
      .replaceAll("+998", "")
      .replaceAll("+678", "")
      .replaceAll("+379", "")
      .replaceAll("+58", "")
      .replaceAll("+84", "")
      .replaceAll("+681", "")
      .replaceAll("+212", "")
      .replaceAll("+967", "")
      .replaceAll("+260", "")
      .replaceAll("+263", "")
      .replaceAll("+92", "")
      .replaceAll(RegExp(r'^0+(?=.)'), '')
      .replaceFirst(RegExp(r'^0+'), '')
      .replaceAll("-", "")
      .replaceAll(" ", "")
      .replaceAll(".", "")
      .replaceAll('  ', "")
      .replaceAll("+91", "")
      .trim();
}

String formatStoryDate(String dateString) {
  logger.i("STORY_DATE:$dateString");
  DateTime inputDate = DateTime.parse(dateString).toLocal();
  DateTime now = DateTime.now();

  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(Duration(days: 1));
  final inputDay = DateTime(inputDate.year, inputDate.month, inputDate.day);

  String formattedTime = DateFormat.jm().format(inputDate); // e.g. 12:42 PM

  if (inputDay == today) {
    return AppString.todayAtTime(formattedTime);
  } else if (inputDay == yesterday) {
    return AppString.yesterdayAtTime(formattedTime);
  } else {
    String formattedDate = DateFormat.MMMd().format(inputDate); // e.g. May 12
    return AppString.dateAtTime(formattedDate, formattedTime);
  }
}

String formatTimeAgo(String updatedAt) {
  logger.i("STORY_SEEN_TIME:$updatedAt");
  // Parse the UTC time string
  DateTime updatedDate = DateTime.parse(updatedAt).toLocal();
  DateTime now = DateTime.now();

  // Calculate the difference between now and the updated time
  Duration diff = now.difference(updatedDate);

  // If less than 5 seconds, show 'Just now'
  if (diff.inSeconds < 5) {
    return AppString.justNow;
  } else if (diff.inSeconds < 60) {
    return AppString.nSecondsAgo('${diff.inSeconds}');
  } else if (diff.inMinutes < 60) {
    return AppString.trParams(
      diff.inMinutes > 1 ? '{n} minutes ago' : '{n} minute ago',
      {'n': '${diff.inMinutes}'},
    );
  } else if (diff.inHours < 24) {
    return AppString.trParams(
      diff.inHours > 1 ? '{n} hours ago' : '{n} hour ago',
      {'n': '${diff.inHours}'},
    );
  } else if (diff.inDays < 7) {
    return AppString.trParams(
      diff.inDays > 1 ? '{n} days ago' : '{n} day ago',
      {'n': '${diff.inDays}'},
    );
  } else if (diff.inDays < 30) {
    int weeks = (diff.inDays / 7).floor();
    return AppString.trParams(
      weeks > 1 ? '{n} weeks ago' : '{n} week ago',
      {'n': '$weeks'},
    );
  } else if (diff.inDays < 365) {
    int months = (diff.inDays / 30).floor();
    return AppString.trParams(
      months > 1 ? '{n} months ago' : '{n} month ago',
      {'n': '$months'},
    );
  } else {
    int years = (diff.inDays / 365).floor();
    return AppString.trParams(
      years > 1 ? '{n} years ago' : '{n} year ago',
      {'n': '$years'},
    );
  }
}

Widget headerYellowContainer(
  BuildContext context, {
  required Widget child,
  required double height,
}) {
  return Container(
    height: height,
    decoration: BoxDecoration(
      gradient: AppColors.gradientColor.headerColor.withOpacity(0.08),
    ),
    child: ClipRRect(
      borderRadius: BorderRadiusGeometry.circular(0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15.6, sigmaY: 15.6),
        child: child,
      ),
    ),
  );
}

class YellowProfileDesign extends StatelessWidget {
  final String image;
  const YellowProfileDesign({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.30,
          child: Image.asset(AppAssets.backImage),
        ),
        Positioned(
          bottom: -5,
          left: 0,
          right: 0,
          child: Container(
            height: SizeConfig.sizedBoxHeight(100),
            width: SizeConfig.sizedBoxWidth(100),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bgColor.bg4Color,
            ),
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadiusGeometry.circular(100),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget profileWidget(
  BuildContext context, {
  required bool isBackArrow,
  required String title,
  String? image,
  bool defaultGroupIcon = false,
  Widget? actionButton,
  // Shown (non-tappable) instead of falling back to the logged-in user's own
  // `userProfile` when [image] is null — e.g. a group without an icon.
  Widget? placeholder,
  bool showVerifiedBadge = false,
}) {
  final bool showPlaceholder = image == null && placeholder != null;
  return Stack(
    clipBehavior: Clip.none,
    children: [
      yellowImageWidget(context),
      Positioned(
        bottom: -15,
        left: (MediaQuery.sizeOf(context).width - 100) / 2,
        child: GestureDetector(
          onTap: () {
            if (showPlaceholder) return;
            final String resolvedImage = image ?? userProfile;
            if (resolvedImage.isEmpty) return;
            context.viewImage(
              imageSource: resolvedImage,
              heroTag: 'profile_widget_image',
            );
          },
          child: Container(
            height: 110,
            width: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppThemeManage.appTheme.bg4BlackColor,
              border: Border.all(
                color: AppThemeManage.appTheme.bg4BlackColor,
                width: 4,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgColor.bg4Color,
                  borderRadius: BorderRadius.circular(110),
                  border: Border.all(color: AppColors.strokeColor.cECECEC),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(110),
                  child:
                      showPlaceholder
                          ? placeholder
                          : Hero(
                            tag: 'profile_widget_image',
                            child: _buildProfileImage(image ?? userProfile),
                          ),
                ),
              ),
            ),
          ),
        ),
      ),
      // Blue tick on the avatar while the logged-in user is premium.
      if (showVerifiedBadge)
        Positioned(
          bottom: -9,
          left: (MediaQuery.sizeOf(context).width - 100) / 2 + 110 - 36,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppThemeManage.appTheme.bg4BlackColor,
            ),
            child: const OwnVerifiedBadge(size: 28),
          ),
        ),
      Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        // left: 16,
        child:
            actionButton == null
                ? SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        isBackArrow
                            ? GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: customeBackArrowBalck(
                                context,
                                isBackBlack: true,
                              ),
                            )
                            : SizedBox.shrink(),
                        isBackArrow
                            ? const SizedBox(width: 8)
                            : SizedBox.shrink(),
                        title.isNotEmpty
                            ? Text(
                              title,
                              style: AppTypography.h2(context).copyWith(
                                fontWeight: FontWeight.w600,
                                fontFamily:
                                    AppTypography.fontFamily.poppinsBold,
                                color: ThemeColorPalette.getTextColor(
                                  AppColors.appPriSecColor.primaryColor,
                                ), //AppColors.textColor.textBlackColor,
                              ),
                            )
                            : SizedBox.shrink(),
                      ],
                    ),
                  ),
                )
                : SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (isBackArrow)
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: customeBackArrowBalck(
                                    context,
                                    isBackBlack: true,
                                  ),
                                ),
                              if (isBackArrow) const SizedBox(width: 8),

                              if (title.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    title,
                                    style: AppTypography.h220(context).copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textColor.textBlackColor,
                                      fontSize: SizeConfig.getFontSize(18),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        actionButton,
                      ],
                    ),
                  ),
                ),
      ),
    ],
  );
}

Widget profileWidget2(
  BuildContext context, {
  required bool isBackArrow,
  required String title,
  required Widget profileChild,
  bool isEditShow = false,
}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      yellowImageWidget(context),
      Positioned(
        bottom: -15,
        left: (MediaQuery.sizeOf(context).width - 100) / 2,
        child: Container(
          height: 110,
          width: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppThemeManage.appTheme.bg4BlackColor,
            border: Border.all(
              color: AppThemeManage.appTheme.bg4BlackColor,
              width: 4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Stack(
              children: [
                ClipOval(child: profileChild),
                isEditShow
                    ? Positioned(
                      bottom: SizeConfig.sizedBoxHeight(1),
                      right: SizeConfig.sizedBoxWidth(0),
                      child: Container(
                        padding: SizeConfig.getPadding(3),
                        decoration: BoxDecoration(
                          color: AppThemeManage.appTheme.scaffoldBackColor,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          height: SizeConfig.sizedBoxHeight(21),
                          width: SizeConfig.sizedBoxWidth(21),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.appPriSecColor.primaryColor,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Image.asset(
                              AppAssets.edit2,
                              color: ThemeColorPalette.getTextColor(
                                AppColors.appPriSecColor.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    : SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: AppDirectionality.appDirectionBool.positionedLeft(16),
        right: AppDirectionality.appDirectionBool.positionedRight(16),
        child: Row(
          children: [
            isBackArrow ? const SizedBox(width: 8) : SizedBox.shrink(),
            isBackArrow
                ? customeBackArrowBalck(
                  context,
                  isBackBlack: true,
                  color: ThemeColorPalette.getTextColor(
                    AppColors.appPriSecColor.primaryColor,
                  ),
                )
                : SizedBox.shrink(),
            isBackArrow ? const SizedBox(width: 8) : SizedBox.shrink(),
            title.isNotEmpty
                ? Text(
                  title,
                  style: AppTypography.h220(context).copyWith(
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTypography.fontFamily.poppinsMedium,
                    color: ThemeColorPalette.getTextColor(
                      AppColors.appPriSecColor.primaryColor,
                    ), //AppColors.textColor.textBlackColor,
                  ),
                )
                : SizedBox.shrink(),
          ],
        ),
      ),
    ],
  );
}

Widget newTabbarFooterIcon({
  required String svgImageFill,
  required String image,
  required EdgeInsetsGeometry padding,
  required EdgeInsetsGeometry paddingColor,
  double? height,
}) {
  return Container(
    width: 27,
    height: 24,
    margin: const EdgeInsets.only(top: 2),
    child: Stack(
      children: [
        Padding(
          padding: paddingColor,
          child: SvgPicture.asset(
            svgImageFill,
            colorFilter: ColorFilter.mode(
              AppColors.appPriSecColor.primaryColor,
              BlendMode.srcIn,
            ),
            height: SizeConfig.safeHeight(3),
          ),
        ),
        Padding(
          padding: padding,
          child: SvgPicture.asset(
            image,
            height: height ?? SizeConfig.safeHeight(3.5),
            color: ThemeColorPalette.getTextColor(
              AppThemeManage.appTheme.scaffoldBackColor,
            ), //AppThemeManage.appTheme.blackBg4Color,
          ),
        ),
      ],
    ),
  );
}

Widget chatCountContainer(BuildContext context, {required int count}) {
  return Container(
    height: SizeConfig.sizedBoxHeight(20),
    width: SizeConfig.sizedBoxWidth(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      color: AppColors.appPriSecColor.primaryColor,
    ),
    child: Center(
      child: Text(
        '${count > 99 ? "+99" : count}',
        style: AppTypography.innerText10(context).copyWith(
          fontSize: count > 99 ? 9 : 10,
          color: ThemeColorPalette.getTextColor(
            AppColors.appPriSecColor.primaryColor,
          ), //AppThemeManage.appTheme.darkWhiteColor,
        ),
      ),
    ),
  );
}

void closeKeyboard() {
  return FocusManager.instance.primaryFocus
      ?.unfocus(); //SystemChannels.textInput.invokeMethod('TextInput.hide');
}

Widget messageContentIcon(BuildContext context, {required String messageType}) {
  switch (messageType.toLowerCase()) {
    case 'image':
      return SvgPicture.asset(
        AppAssets.chatMsgTypeIcon.galleryMsg,
        height: SizeConfig.sizedBoxHeight(14),
        color: AppColors.textColor.textDarkGray,
      );
    case 'video':
      return SvgPicture.asset(
        AppAssets.chatMsgTypeIcon.videoMsg,
        height: SizeConfig.sizedBoxHeight(14),
        color: AppColors.textColor.textDarkGray,
      );
    case 'document':
    case 'doc':
    case 'pdf':
    case 'file':
      return SvgPicture.asset(
        AppAssets.chatMsgTypeIcon.documentMsg,
        height: SizeConfig.sizedBoxHeight(14),
        color: AppColors.textColor.textDarkGray,
      );
    case 'location':
      return SvgPicture.asset(
        AppAssets.chatMsgTypeIcon.locationMsg,
        height: SizeConfig.sizedBoxHeight(14),
        color: AppColors.textColor.textDarkGray,
      );
    // case 'audio':
    //   return SvgPicture.asset(assetName);
    case 'gif':
      return SvgPicture.asset(
        AppAssets.chatMsgTypeIcon.gifMsg,
        height: SizeConfig.sizedBoxHeight(14),
        color: AppColors.textColor.textDarkGray,
      );
    case 'contact':
      return SvgPicture.asset(
        AppAssets.chatMsgTypeIcon.contactMsg,
        height: SizeConfig.sizedBoxHeight(14),
        color: AppColors.textColor.textDarkGray,
      );
    case 'link':
      return Transform.rotate(
        angle: math.pi / 1.5,
        child: Icon(
          Icons.link,
          size: SizeConfig.sizedBoxHeight(15),
          color: AppColors.textColor.textDarkGray,
        ),
      );
    case 'voice':
      return SvgPicture.asset(
        AppAssets.chatMsgTypeIcon.voiceMic,
        height: SizeConfig.sizedBoxHeight(14),
        color: AppColors.textColor.textDarkGray,
      );
    case 'poll':
      return SvgPicture.asset(
        AppAssets.chatMsgTypeIcon.pollIcon,
        height: SizeConfig.sizedBoxHeight(14),
        color: AppColors.textColor.textDarkGray,
      );
    default:
      return SizedBox.shrink();
  }
}

Widget rowAudioVideoSearchContainer({
  required BuildContext context,
  required Function() onTap,
  required String title,
  required String svgImage,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: AppThemeManage.appTheme.chatAudiVideoContBorColor,
        ),
        color: AppThemeManage.appTheme.chatAudiVideoContainerColor,
      ),
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 15, vertical: 10),
        child: Center(
          child: Column(
            children: [
              SvgPicture.asset(
                svgImage,
                height: SizeConfig.sizedBoxHeight(16),
                color: AppThemeManage.appTheme.darkWhiteColor,
              ),
              SizedBox(height: SizeConfig.height(1)),
              Text(title, style: AppTypography.innerText10(context)),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget rowIconWithRedText({
  required BuildContext context,
  required Function() onTap,
  required String svgImage,
  required String title,
  required Color color,
}) {
  return InkWell(
    onTap: onTap,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SvgPicture.asset(
          svgImage,
          height: SizeConfig.sizedBoxHeight(18),
          color: color, //AppColors.appPriSecColor.secondaryRed,
        ),
        SizedBox(width: SizeConfig.width(2)),
        Text(
          title,
          style: AppTypography.innerText12Ragu(context).copyWith(
            color: color, //AppColors.textColor.textErrorColor1,
          ),
        ),
      ],
    ),
  );
}

Future<void> showGlobalBottomSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  required String confirmButtonText,
  required VoidCallback onConfirm,
  String? cancelButtonText,
  bool isLoading = false,
}) {
  return bottomSheetGobalWithoutTitle(
    context,
    bottomsheetHeight: SizeConfig.height(25),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: SizeConfig.height(3)),
        Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
          child: Text(
            title,
            textAlign: TextAlign.start,
            style: AppTypography.captionText(context).copyWith(
              fontSize: SizeConfig.getFontSize(15),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: SizeConfig.height(2)),
        Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
          child: Text(
            subtitle,
            textAlign: TextAlign.start,
            style: AppTypography.captionText(context).copyWith(
              color: AppColors.textColor.textGreyColor,
              fontSize: SizeConfig.getFontSize(13),
            ),
          ),
        ),
        SizedBox(height: SizeConfig.height(4)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              height: SizeConfig.height(5),
              width: SizeConfig.width(35),
              child: customBorderBtn(
                context,
                onTap: () {
                  Navigator.pop(context);
                },
                title: cancelButtonText!,
              ),
            ),
            isLoading
                ? SizedBox(
                  height: SizeConfig.sizedBoxHeight(35),
                  width: SizeConfig.sizedBoxWidth(35),
                  child: commonLoading(),
                )
                : SizedBox(
                  height: SizeConfig.height(5),
                  width: SizeConfig.width(35),
                  child: customBtn2(
                    context,
                    onTap: onConfirm,
                    child: Text(
                      confirmButtonText,
                      style: AppTypography.h5(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: ThemeColorPalette.getTextColor(
                          AppColors.appPriSecColor.primaryColor,
                        ), //AppColors.textColor.textBlackColor,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildProfileImage(String imageUrl) {
  // Check if the imageUrl is a local file path
  if (imageUrl.startsWith('/') || imageUrl.startsWith('file://')) {
    // Handle local file
    final file = File(
      imageUrl.startsWith('file://') ? imageUrl.substring(7) : imageUrl,
    );
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Center(child: _buildProfileLetterAvatar());
        },
      );
    }
  }

  // Handle network image or fallback to default icon if local file doesn't exist
  if (imageUrl.isNotEmpty &&
      (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) {
        return Center(child: _buildProfileLetterAvatar());
      },
    );
  }

  // Default fallback icon
  return Center(child: _buildProfileLetterAvatar());
}

Widget _buildProfileLetterAvatar() {
  // "First Last" so our own avatar matches the initials other users see for us.
  final composed = [firstName.trim(), lastName.trim()]
      .where((p) => p.isNotEmpty)
      .join(' ');
  final String name = composed.isNotEmpty
      ? composed
      : (userName.isNotEmpty ? userName : '');

  final String initials = avatarInitials(name);

  return Container(
    width: 100,
    height: 100,
    decoration: BoxDecoration(
      color: AppColors.textColor.textDarkGray,
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.textColor.textWhiteColor,
          fontWeight: FontWeight.bold,
          fontSize: 40,
        ),
      ),
    ),
  );
}

String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);

  if (hours > 0) {
    // HH:MM:SS
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  } else {
    // MM:SS
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

bool checkDemoMode(BuildContext context, {String? customMessage}) {
  if (isDemo) {
    snackbarNew(
      context,
      msg: customMessage ?? "This action is disabled in Demo Mode.",
    );
    return true;
  }
  return false;
}

/// Mirrors the signed-in user's display name (business name for
/// business accounts); kept in sync by BusinessProfileProvider.
String fullName = '';
