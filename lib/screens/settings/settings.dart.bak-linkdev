import 'dart:developer';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/featuers/language_method/screen/lang_popup.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/featuers/subscription/provider/subscription_provider.dart';
import 'package:whoxa/featuers/subscription/widgets/subscription_settings_tile.dart';
import 'package:whoxa/screens/settings/terms_policy.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/theme_switch.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

// ✅ COMMENTED OUT: Unused imports for test widgets
// import 'package:whoxa/core/services/call_notification_manager.dart';
// import 'package:whoxa/featuers/opus_call/test_layout_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    log("userProfile:$userProfile");
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUI(),
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, langProvider, _) {
          return Scaffold(
            extendBody: true,
            backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
            body: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  //✅ Top profile layout
                  profileWidget(
                    context,
                    isBackArrow: false,
                    image: userProfile,
                    showVerifiedBadge: context
                        .select<SubscriptionProvider, bool>(
                          (p) => p.premiumUser,
                        ),
                    title: AppString.settingStrigs.settings,
                  ),
                  SizedBox(height: SizeConfig.height(5)),
                  //✅ Navigate to profile screen
                  Padding(
                    padding: SizeConfig.getPaddingSymmetric(horizontal: 22),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppThemeManage.appTheme.darkGreyColor,
                        border: Border.all(
                          color: AppThemeManage.appTheme.borderColor,
                        ),
                      ),
                      child: Column(
                        children: [
                          containerDesgin(
                            context,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.profile,
                              ).then((_) {
                                setState(() {
                                  userProfile;
                                });
                              });
                              debugPrint(userProfile);
                              debugPrint(
                                "${ApiEndpoints.socketUrl}/uploads/not-found-images/profile-image.png",
                              );
                            },
                            img: AppAssets.settingsIcosn.profile,
                            title: AppString.settingStrigs.profile,
                            sutTitle: AppString
                                .settingStrigs
                                .editAndManageYourProfile,
                            count: "",
                            isCount: false,
                            isLast: false,
                          ),
                          //✅ Navigate to Bio screen
                          containerDesgin(
                            context,
                            onTap: () {
                              Navigator.pushNamed(context, AppRoutes.bio).then((
                                _,
                              ) {
                                bio;
                              });
                            },
                            img: AppAssets.settingsIcosn.about,
                            title: AppString.settingStrigs.about,
                            sutTitle: AppString.settingStrigs.updateYourAbout,
                            count: "",
                            isCount: false,
                            isLast: false,
                          ),
                          //✅ Navigate to starred message screen
                          Consumer<ChatProvider>(
                            builder: (context, chatProvider, _) {
                              return containerDesgin(
                                context,
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.starredMessages,
                                  );
                                },
                                img: AppAssets.settingsIcosn.star,
                                title: AppString.settingStrigs.starredMessages,
                                sutTitle:
                                    AppString.settingStrigs.keepsSavedMessage,
                                count: chatProvider.starredCount.toString(),
                                isCount: true,
                                isLast: false,
                              );
                            },
                          ),
                          //✅ Naivgate to block list screen
                          Consumer<ChatProvider>(
                            builder: (context, chatProvider, _) {
                              return containerDesgin(
                                context,
                                onTap: () {
                                  Navigator.pushNamed(context, AppRoutes.block);
                                },
                                img: AppAssets.settingsIcosn.profiledelete,
                                title: AppString.settingStrigs.blockContacts,
                                sutTitle: AppString.settingStrigs.yourBlocked,
                                count: chatProvider.blocklistCount.toString(),
                                isCount: true,
                                isLast: false,
                              );
                            },
                          ),
                          //✅ bottom sheet open for language select
                          containerDesgin(
                            context,
                            onTap: () {
                              appLanguagePopup(context);
                            },
                            img: AppAssets.settingsIcosn.appLangIcon,
                            title: AppString.settingStrigs.appLanguage,
                            sutTitle:
                                AppString.settingStrigs.selectYourlanguage,
                            count: "0",
                            isCount: false,
                            isLast: false,
                          ),
                          // Google Play / App Store subscription
                          if (defaultTargetPlatform == TargetPlatform.android ||
                              defaultTargetPlatform == TargetPlatform.iOS)
                            SubscriptionSettingsTile(),
                          // Theme Color Selection
                          themeColorSelectionWidget(context),
                          //✅ Dark mode toggle
                          darkLightModeWidget(),

                          //✅ Navigate to Terms & conditions screen
                          containerDesgin(
                            context,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PrivacyWebView(
                                    title:
                                        AppString.settingStrigs.termsConditions,
                                    htmlContent: termsConditionText,
                                  ),
                                ),
                              );
                            },
                            img: AppAssets.settingsIcosn.terms,
                            title: AppString.settingStrigs.termsConditions,
                            sutTitle: AppString.settingStrigs.readOurTerms,
                            count: "",
                            isCount: false,
                            isLast: false,
                          ),
                          //✅ Navigate to Privacy policy scrren
                          containerDesgin(
                            context,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PrivacyWebView(
                                    title:
                                        AppString.settingStrigs.privacyPolicy,
                                    htmlContent: privacyPoicyText,
                                  ),
                                ),
                              );
                            },
                            img: AppAssets.settingsIcosn.policy,
                            title: AppString.settingStrigs.privacyPolicy,
                            sutTitle: AppString.settingStrigs.readOurPolicy,
                            count: "",
                            isCount: false,
                            isLast: false,
                          ),
                          // ✅ App Version show
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppThemeManage.appTheme.borderColor,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: SizeConfig.getPaddingSymmetric(
                                horizontal: 15,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors
                                          .appPriSecColor
                                          .primaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: SvgPicture.asset(
                                        AppAssets.settingsIcosn.policy,
                                        height: 20,
                                        width: 20,
                                        colorFilter: ColorFilter.mode(
                                          AppThemeManage
                                              .appTheme
                                              .darkWhiteColor,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppString.appVersion,
                                          style: AppTypography.innerText12Mediu(
                                            context,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        appVersion,
                                        style:
                                            AppTypography.inputPlaceholderSmall(
                                              context,
                                            ).copyWith(
                                              fontFamily: AppTypography
                                                  .fontFamily
                                                  .poppins,
                                              color: AppColors
                                                  .textColor
                                                  .textGreyColor,
                                            ),
                                      ),
                                      SvgPicture.asset(
                                        AppDirectionality
                                            .appDirectionIcon
                                            .arrow,
                                        height: SizeConfig.safeHeight(3),
                                        colorFilter: ColorFilter.mode(
                                          AppThemeManage
                                              .appTheme
                                              .darkWhiteColor,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Logout method
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              return InkWell(
                                onTap: authProvider.isLogout
                                    ? null
                                    : () {
                                        logoutDeleteDialog(
                                          context,
                                          title: AppString.settingStrigs.logout,
                                        );
                                      },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color:
                                        AppThemeManage.appTheme.darkGreyColor,
                                  ),
                                  child: Padding(
                                    padding: SizeConfig.getPaddingSymmetric(
                                      horizontal: 15,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Center(
                                            child: authProvider.isLogout
                                                ? SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.red),
                                                    ),
                                                  )
                                                : SvgPicture.asset(
                                                    AppAssets
                                                        .settingsIcosn
                                                        .logout,
                                                    height: 20,
                                                    width: 20,
                                                    colorFilter:
                                                        ColorFilter.mode(
                                                          Colors.red,
                                                          BlendMode.srcIn,
                                                        ),
                                                  ),
                                          ),
                                        ),
                                        SizedBox(width: SizeConfig.width(2)),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                authProvider.isLogout
                                                    ? AppString
                                                          .settingStrigs
                                                          .loggingOut
                                                    : AppString
                                                          .settingStrigs
                                                          .logout,
                                                style:
                                                    AppTypography.innerText12Mediu(
                                                      context,
                                                    ).copyWith(
                                                      color: Colors.red,
                                                      fontSize:
                                                          SizeConfig.getFontSize(
                                                            14,
                                                          ),
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (!authProvider.isLogout) ...[
                                                SizedBox(height: 2),
                                                Text(
                                                  AppString
                                                      .settingStrigs
                                                      .securlyLogOut, //"Securely log out from this device",
                                                  style:
                                                      AppTypography.inputPlaceholderSmall(
                                                        context,
                                                      ).copyWith(
                                                        fontFamily:
                                                            AppTypography
                                                                .fontFamily
                                                                .poppins,
                                                        color: AppColors
                                                            .textColor
                                                            .textGreyColor,
                                                        fontSize:
                                                            SizeConfig.getFontSize(
                                                              10,
                                                            ),
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        // Right arrow
                                        if (!authProvider.isLogout)
                                          SvgPicture.asset(
                                            AppDirectionality
                                                .appDirectionIcon
                                                .arrow,
                                            height: SizeConfig.safeHeight(3),
                                            colorFilter: ColorFilter.mode(
                                              AppThemeManage
                                                  .appTheme
                                                  .darkWhiteColor,
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: SizeConfig.height(4)),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      return Center(
                        child: InkWell(
                          onTap: authProvider.isDeleteAcc
                              ? null
                              : () {
                                  // ✅ Check if user is demo account
                                  if (isDemo) {
                                    snackbarNew(
                                      context,
                                      msg: AppString
                                          .demoAccountsCannotDeleteTheirAccount,
                                    );
                                    return;
                                  }

                                  logoutDeleteDialog(
                                    context,
                                    title:
                                        AppString.settingStrigs.deleteAccount,
                                  );
                                },
                          child: Padding(
                            padding: SizeConfig.getPaddingSymmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: authProvider.isDeleteAcc
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: 14,
                                        width: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors
                                                    .textColor
                                                    .textGreyColor,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "${AppString.deleting}...",
                                        style:
                                            AppTypography.buttonText12(
                                              context,
                                            ).copyWith(
                                              fontSize: SizeConfig.getFontSize(
                                                12,
                                              ),
                                              color: AppColors
                                                  .textColor
                                                  .textGreyColor,
                                            ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    AppString.settingStrigs.deleteAccount,
                                    style: AppTypography.buttonText12(context)
                                        .copyWith(
                                          fontSize: SizeConfig.getFontSize(12),
                                          color:
                                              AppColors.textColor.textGreyColor,
                                          decoration: TextDecoration.underline,
                                        ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget containerDesgin(
  BuildContext context, {
  required Function() onTap,
  required String img,
  required String title,
  required String sutTitle,
  required String count,
  required bool isCount,
  required bool isLast,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppThemeManage.appTheme.borderColor,
                  width: 0.5,
                ),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.appPriSecColor.primaryColor.withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: SvgPicture.asset(
                img,
                height: 20,
                width: 20,
                colorFilter: ColorFilter.mode(
                  AppThemeManage.appTheme.darkWhiteColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),

          SizedBox(width: SizeConfig.width(4)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.innerText12Mediu(context)),
                Text(
                  sutTitle,
                  maxLines: 2,
                  style: AppTypography.inputPlaceholderSmall(context).copyWith(
                    fontFamily: AppTypography.fontFamily.poppins,
                    color: AppColors.textColor.textGreyColor,
                    fontSize: SizeConfig.getFontSize(10),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              isCount
                  ? Text(
                      count,
                      style: AppTypography.inputPlaceholderSmall(context)
                          .copyWith(
                            fontFamily: AppTypography.fontFamily.poppins,
                            color: AppColors.textColor.textGreyColor,
                          ),
                    )
                  : SizedBox.shrink(),
              isCount
                  ? SizedBox(height: SizeConfig.height(1))
                  : SizedBox.shrink(),
              SvgPicture.asset(
                AppDirectionality.appDirectionIcon.arrow,
                height: SizeConfig.safeHeight(3),
                colorFilter: ColorFilter.mode(
                  AppThemeManage.appTheme.darkWhiteColor,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget darkLightModeWidget() {
  return Consumer<ThemeProvider>(
    builder: (context, themeProvider, _) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppThemeManage.appTheme.borderColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Left side with styled icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.appPriSecColor.primaryColor.withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return RotationTransition(
                      turns: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: SvgPicture.asset(
                    AppThemeManage.appTheme.appDarkLightIcon,
                    key: ValueKey<bool>(themeProvider.isLightMode),
                    height: 20,
                    width: 20,
                    colorFilter: ColorFilter.mode(
                      AppThemeManage.appTheme.darkWhiteColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: SizeConfig.width(4)),
            // Expanded column for title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      AppThemeManage.appTheme.lightDarkText,
                      key: ValueKey<bool>(themeProvider.isLightMode),
                      style: AppTypography.innerText12Mediu(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    AppString
                        .settingStrigs
                        .switchBetween, //"Switch between light and dark theme",
                    style: AppTypography.inputPlaceholderSmall(context)
                        .copyWith(
                          fontFamily: AppTypography.fontFamily.poppins,
                          color: AppColors.textColor.textGreyColor,
                          fontSize: SizeConfig.getFontSize(10),
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            CustomSwitch(
              value: isLightModeGlobal,
              onChanged: (bool value) {
                themeProvider.toggleThemeMode(value);
              },
            ),
          ],
        ),
      );
    },
  );
}

Widget themeColorSelectionWidget(BuildContext context) {
  return Consumer<ThemeProvider>(
    builder: (context, themeProvider, _) {
      return InkWell(
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.themeColorPicker);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppThemeManage.appTheme.borderColor,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left side with color circle icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.appPriSecColor.primaryColor.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Container(
                    height: 20,
                    width: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.appPriSecColor.primaryColor,
                      border: Border.all(
                        color: AppThemeManage.appTheme.darkWhiteColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Expanded column for title and subtitle
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppString.settingStrigs.chatcolor,
                            style: AppTypography.innerText12Mediu(context),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            AppString.settingStrigs.customizeColor, //"Customize your chat theme color",
                            style: AppTypography.inputPlaceholderSmall(context)
                                .copyWith(
                                  fontFamily: AppTypography.fontFamily.poppins,
                                  color: AppColors.textColor.textGreyColor,
                                  fontSize: SizeConfig.getFontSize(9.5),
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (themeProvider.hasCustomTheme)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.appPriSecColor.primaryColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          AppString.settingStrigs.custom, //"Custom",
                          style: AppTypography.inputPlaceholderSmall(context)
                              .copyWith(
                                fontFamily: AppTypography.fontFamily.poppins,
                                color: AppColors.appPriSecColor.primaryColor,
                                fontSize: SizeConfig.getFontSize(8),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              // Right arrow
              SvgPicture.asset(
                AppDirectionality.appDirectionIcon.arrow,
                height: SizeConfig.safeHeight(3),
                colorFilter: ColorFilter.mode(
                  AppThemeManage.appTheme.darkWhiteColor,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Updated logoutDeleteDialog function in your settings_screen.dart

Future logoutDeleteDialog(BuildContext context, {required String title}) {
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
            title == AppString.settingStrigs.logout
                ? AppString.settingStrigs.logoutAsk1
                : AppString.settingStrigs.deleteAsk1,
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
            title == AppString.settingStrigs.logout
                ? AppString.settingStrigs.logoutAsk
                : AppString.settingStrigs.deleteAsk,
            textAlign: TextAlign.start,
            style: AppTypography.captionText(context).copyWith(
              color: AppColors.textColor.textGreyColor,
              fontSize: SizeConfig.getFontSize(13),
            ),
          ),
        ),
        title == AppString.settingStrigs.logout
            ? SizedBox(height: SizeConfig.height(4))
            : SizedBox(height: SizeConfig.height(3)),
        Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return Row(
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
                    title: AppString.cancel,
                  ),
                ),
                authProvider.isDeleteAcc || authProvider.isLogout
                    ? Container(
                        height: SizeConfig.sizedBoxHeight(35),
                        width: SizeConfig.sizedBoxWidth(35),
                        decoration: BoxDecoration(),
                        child: commonLoading(),
                      )
                    : SizedBox(
                        height: SizeConfig.height(5),
                        width: SizeConfig.width(35),
                        child: customBtn2(
                          context,
                          onTap: () async {
                            if (title == AppString.settingStrigs.logout) {
                              // LOGOUT FLOW - Updated with socket cleanup
                              try {
                                // Handle logout with proper socket cleanup
                                final subscription = context
                                    .read<SubscriptionProvider>();
                                await authProvider.handleLogout(context);
                                subscription.reset();

                                // Small delay for cleanup to complete
                                await Future.delayed(
                                  const Duration(milliseconds: 500),
                                );

                                if (!context.mounted) return;

                                // Navigate to login screen
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppRoutes.login,
                                  (Route<dynamic> route) => false,
                                );
                              } catch (e) {
                                // If logout fails, still navigate but show error
                                if (!context.mounted) return;
                                snackbarNew(
                                  context,
                                  msg: AppString.logoutCompletedWithWarnings,
                                );
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppRoutes.login,
                                  (Route<dynamic> route) => false,
                                );
                              }
                            } else {
                              // ACCOUNT DELETION FLOW - Updated with socket cleanup
                              try {
                                final success = await authProvider
                                    .handleAccountDeletion(context);

                                if (!context.mounted) return;

                                if (success) {
                                  context.read<SubscriptionProvider>().reset();
                                  final msg =
                                      authProvider.errorMessage?.toString() ??
                                      'Account deleted successfully';
                                  snackbarNew(context, msg: msg);

                                  // Small delay to show the message
                                  await Future.delayed(
                                    const Duration(seconds: 1),
                                  );

                                  if (!context.mounted) return;

                                  // Navigate to login screen
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    AppRoutes.login,
                                    (Route<dynamic> route) => false,
                                  );
                                } else {
                                  final msg =
                                      authProvider.errorMessage?.toString() ??
                                      'Failed to delete account';
                                  Navigator.pop(context);
                                  snackbarNew(context, msg: msg);
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                snackbarNew(
                                  context,
                                  msg: AppString
                                      .errorOccurredDuringAccountDeletion,
                                );
                              }
                            }
                          },
                          child: Text(
                            title == AppString.settingStrigs.logout
                                ? AppString.settingStrigs.logout
                                : AppString.settingStrigs.delete,
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
            );
          },
        ),
      ],
    ),
  );
}

Future appLanguagePopup(BuildContext context) {
  return bottomSheetGobal(
    context,
    bottomsheetHeight: SizeConfig.sizedBoxHeight(360),
    insetPadding: SizeConfig.getPaddingOnly(left: 30, right: 30, bottom: 20),
    title: AppString.settingStrigs.appLanguage,
    child: LanguagePopUp(),
  );
}

/// 🧪 DEBUG TEST: Returns debug buttons only in debug mode
List<Widget> debugCallNotificationButton(BuildContext context) {
  List<Widget> widgets = [];

  // Only add the test buttons in debug mode
  // ✅ COMMENTED OUT: Test widgets hidden from settings screen
  /*
  assert(() {
    widgets.addAll([
      SizedBox(height: SizeConfig.height(2)),
      containerDesgin(
        context,
        onTap: () async {
          try {
            // Show confirmation dialog first
            final shouldTest = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('🧪 Test Call Notification'),
                  content: Text(
                    'This will test the call ringtone based on your device sound profile:\n\n'
                    '• Silent mode: No sound/vibration\n'
                    '• Vibrate mode: Vibration only\n'
                    '• Normal mode: Custom ringtone + vibration\n\n'
                    'Test will auto-stop after 10 seconds.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(AppString.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('Test Now'),
                    ),
                  ],
                );
              },
            );

            if (shouldTest == true) {
              // Trigger the test
              await CallNotificationManager.instance.testCallNotification();

              // Show success message
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🧪 Call notification test started! Check logs for details.',
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          } catch (e) {
            // Show error message
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🧪 Test failed: $e'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        },
        img: AppAssets.settingsIcosn.feedback, // Using feedback icon for test
        title: "🧪 Test Call Notification (Debug)",
        count: "",
        isCount: false,
      ),
      SizedBox(height: SizeConfig.height(2)),
      containerDesgin(
        context,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TestLayoutScreen()),
          );
        },
        img:
            AppAssets
                .settingsIcosn
                .profile, // Using profile icon for layout test
        title: "🧪 Test Video Call Layout (Debug)",
        count: "",
        isCount: false,
      ),
    ]);
    return true;
  }());
  */

  return widgets;
}
