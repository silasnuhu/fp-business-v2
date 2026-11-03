// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/onboarding/Provider/onboarding_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final List<Widget Function(BuildContext)> permissionWidgets = const [
    _NotificationPermission.build,
    _LocationPermission.build,
    _ContactPermission.build,
    _PhotoGalleryPermission.build,
  ];

  late OnboardingProvider _provider;

  @override
  void initState() {
    super.initState();
    // Initialize the provider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<OnboardingProvider>(context, listen: false);
      _provider.initPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: AppColors.bgColor.bgWhite,
          // appBar: AppBar(
          //   toolbarHeight: 12,
          //   elevation: 0,
          //   scrolledUnderElevation: 0,
          //   systemOverlayStyle: systemUI(),
          //   automaticallyImplyLeading: false,
          //   backgroundColor: AppColors.bgColor.bg4Color,
          // ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: permissionWidgets[provider.currentStep](context),
                    ),
                  ),
                  // Bottom navigation bar with dots and next button
                  _buildBottomNavigation(context, provider),
                  SizedBox(height: SizeConfig.height(4) + MediaQuery.of(context).padding.bottom),
                ],
              ),
              // Show loading indicator if permissions are being requested
              if (provider.requestingPermission)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(child: commonLoading()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation(
    BuildContext context,
    OnboardingProvider provider,
  ) {
    return Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dots indicator
          Row(
            children: List.generate(
              permissionWidgets.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: SizeConfig.sizedBoxHeight(12),
                width: SizeConfig.sizedBoxWidth(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      provider.currentStep == index
                          ? AppColors.appPriSecColor.primaryColor
                          : AppColors.opacityColor.cFEF6D7B8,
                ),
              ),
            ),
          ),
          // Skip and Next buttons
          Row(
            children: [
              // Skip button - allows users to skip permission (Apple compliance)
              _buildSkipButton(context, provider),
              SizedBox(width: SizeConfig.width(2)),
              // Next button
              _buildNextButton(context, provider),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ APPLE COMPLIANCE: "Not Now" still routes through the system permission
  // dialog (see OnboardingProvider.skipCurrentPermission) - it just lets the
  // user proceed without an extra confirmation tap on grant.
  Widget _buildSkipButton(BuildContext context, OnboardingProvider provider) {
    return TextButton(
      onPressed: provider.requestingPermission
          ? null
          : () => provider.skipCurrentPermission(context),
      child: Text(
        "Not Now",
        style: AppTypography.buttonText(context).copyWith(
          color: AppColors.textColor.textGreyColor,
          fontSize: SizeConfig.getFontSize(14),
        ),
      ),
    );
  }

  // Next button that properly handles iOS permission requests
  //   Widget _buildNextButton(BuildContext context, OnboardingProvider provider) {
  //     // Get button text based on current step
  //     String buttonText =
  //         provider.currentStep < permissionWidgets.length - 1
  //             ? AppString.next
  //             : "Finish";

  //     return SizedBox(
  //       height: SizeConfig.sizedBoxHeight(32),
  //       width: SizeConfig.sizedBoxWidth(100),
  //       child: customBtn(
  //         context,
  //         onTap: () => provider.onNext(context),
  //         title: buttonText,
  //       ),
  //     );
  //   }
  // }
  Widget _buildNextButton(BuildContext context, OnboardingProvider provider) {
    // Get current permission based on step
    Permission currentPermission;
    switch (provider.currentStep) {
      case 0:
        currentPermission = Permission.notification;
        break;
      case 1:
        currentPermission = Permission.location;
        break;
      case 2:
        currentPermission = Permission.contacts;
        break;
      case 3:
        if (Platform.isIOS) {
          currentPermission = Permission.photos;
        } else {
          // For Android, check if any of the media permissions are granted
          currentPermission =
              provider.isPermissionGranted(Permission.photos) ||
                      provider.isPermissionGranted(Permission.videos) ||
                      provider.isPermissionGranted(Permission.storage)
                  ? Permission.photos
                  : Permission.storage;
        }
        break;
      default:
        currentPermission = Permission.notification;
    }

    // Check if permission is granted
    bool isPermissionGranted = provider.isPermissionGranted(currentPermission);

    // Set button text based on permission status and current step
    String buttonText =
        isPermissionGranted
            ? (provider.currentStep < provider.totalSteps - 1
                ? AppString.next
                : "Finish")
            : "Next";

    return SizedBox(
      height: SizeConfig.sizedBoxHeight(32),
      width: SizeConfig.sizedBoxWidth(100),
      child: customBtn(
        context,
        onTap: () => provider.onNext(context),
        title: buttonText,
      ),
    );
  }
}

// ============================
// NOTIFICATION PERMISSION VIEW
// ============================
class _NotificationPermission {
  static Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, child) {
        final isGranted = provider.isPermissionGranted(Permission.notification);

        return Column(
          children: [
            // Title
            headerYellowContainer(
              context,
              height: SizeConfig.sizedBoxHeight(115),
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: SizeConfig.getPaddingOnly(top: 20),
                  child: Text(
                    AppString.onboardingStrings.configureNotifications,
                    style: AppTypography.h220(context).copyWith(),
                  ),
                ),
              ),
            ),

            SizedBox(height: SizeConfig.height(4)),

            // Description
            Padding(
              padding: SizeConfig.getPaddingSymmetric(horizontal: 70),
              child: _buildChooseWhatMatter(
                context,
                title: AppString.onboardingStrings.chooseWhat,
              ),
            ),
            SizedBox(height: SizeConfig.height(2)),

            // Preference title
            _buildPreferenceTitle(
              context,
              title: AppString.onboardingStrings.notificationPreferences,
            ),
            SizedBox(height: SizeConfig.height(4)),

            // Permission preferences
            _buildPermissionPreference(
              context,
              isPermission: isGranted,
              permisName: AppString.onboardingStrings.allNewMessages,
              greyText: AppString.onboardingStrings.userWillReceive,
            ),
            SizedBox(height: SizeConfig.height(2)),

            _buildPermissionPreference(
              context,
              isPermission: isGranted,
              permisName: AppString.onboardingStrings.messagesInGroup,
              greyText: AppString.onboardingStrings.userWillReceive,
            ),
            SizedBox(height: SizeConfig.height(2)),

            _buildPermissionPreference(
              context,
              isPermission: isGranted,
              permisName: AppString.onboardingStrings.audioCall,
              greyText: AppString.onboardingStrings.userWillAudioCall,
            ),
            SizedBox(height: SizeConfig.height(2)),

            _buildPermissionPreference(
              context,
              isPermission: isGranted,
              permisName: AppString.onboardingStrings.videoCall,
              greyText: AppString.onboardingStrings.userWillVideCall,
            ),
            SizedBox(height: SizeConfig.height(4)),

            // Note box
            _buildNoteBox(
              context,
              title1: AppString.onboardingStrings.toReceiveNotification,
              title2: AppString.onboardingStrings.ifYouWantToDisable,
            ),
          ],
        );
      },
    );
  }
}

// ============================
// LOCATION PERMISSION VIEW
// ============================
class _LocationPermission {
  static Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, child) {
        final isGranted = provider.isPermissionGranted(Permission.location);

        return Column(
          children: [
            // Title
            headerYellowContainer(
              context,
              height: SizeConfig.sizedBoxHeight(115),
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: SizeConfig.getPaddingOnly(top: 20),
                  child: Text(
                    AppString.onboardingStrings.configurePermission,
                    style: AppTypography.h220(context).copyWith(),
                  ),
                ),
              ),
            ),
            SizedBox(height: SizeConfig.height(4)),

            // Description
            Padding(
              padding: SizeConfig.getPaddingSymmetric(horizontal: 70),
              child: _buildChooseWhatMatter(
                context,
                title: AppString.onboardingStrings.chooseWhat,
              ),
            ),
            SizedBox(height: SizeConfig.height(2)),

            // Preference title
            _buildPreferenceTitle(
              context,
              title: AppString.onboardingStrings.locationPrefe,
            ),
            SizedBox(height: SizeConfig.height(4)),

            // Permission preferences
            _buildPermissionPreference(
              context,
              isPermission: isGranted,
              permisName: AppString.onboardingStrings.shareLocation,
              greyText: AppString.onboardingStrings.userWillReceive,
            ),
            SizedBox(height: SizeConfig.height(2)),

            _buildPermissionPreference(
              context,
              isPermission: isGranted,
              permisName: AppString.onboardingStrings.viewTheSharedLocation,
              greyText: AppString.onboardingStrings.userWillGroup,
            ),
            SizedBox(height: SizeConfig.height(4)),

            // Note box
            _buildNoteBox(
              context,
              title1: AppString.onboardingStrings.toAccessLocation,
              title2: AppString.onboardingStrings.ifYouWantToDisable,
            ),
          ],
        );
      },
    );
  }
}

// ============================
// CONTACTS PERMISSION VIEW
// ============================
class _ContactPermission {
  static Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, child) {
        final isGranted = provider.isPermissionGranted(Permission.contacts);

        return Column(
          children: [
            // Title
            headerYellowContainer(
              context,
              height: SizeConfig.sizedBoxHeight(115),
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: SizeConfig.getPaddingOnly(top: 20),
                  child: Text(
                    AppString.onboardingStrings.configurePermission,
                    style: AppTypography.h220(context).copyWith(),
                  ),
                ),
              ),
            ),
            SizedBox(height: SizeConfig.height(4)),

            // Description
            Padding(
              padding: SizeConfig.getPaddingSymmetric(horizontal: 70),
              child: _buildChooseWhatMatter(
                context,
                title: AppString.onboardingStrings.chooseWhat,
              ),
            ),
            SizedBox(height: SizeConfig.height(2)),

            // Preference title
            _buildPreferenceTitle(
              context,
              title: AppString.onboardingStrings.contactPermission,
            ),
            SizedBox(height: SizeConfig.height(4)),

            // Permission preferences
            _buildPermissionPreference(
              context,
              isPermission: isGranted,
              permisName: AppString.onboardingStrings.canViewAllContacts,
              greyText: AppString.onboardingStrings.oneNotification,
            ),
            SizedBox(height: SizeConfig.height(2)),

            _buildPermissionPreference(
              context,
              isPermission: isGranted,
              permisName: AppString.onboardingStrings.shareTheContact,
              greyText: AppString.onboardingStrings.whileAllowingThis,
            ),
            SizedBox(height: SizeConfig.height(4)),

            // Note box
            _buildNoteBox(
              context,
              title1: AppString.onboardingStrings.toAccessContact,
              title2: AppString.onboardingStrings.ifYouWantToDisable,
            ),
          ],
        );
      },
    );
  }
}

// ============================
// PHOTO GALLERY PERMISSION VIEW
// ============================
class _PhotoGalleryPermission {
  static Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, child) {
        // Check appropriate permissions based on platform
        bool isMediaGranted =
            Platform.isIOS
                ? provider.isPermissionGranted(Permission.photos)
                : (provider.isPermissionGranted(Permission.photos) ||
                    provider.isPermissionGranted(Permission.videos) ||
                    provider.isPermissionGranted(Permission.storage));

        return Column(
          children: [
            // Title
            headerYellowContainer(
              context,
              height: SizeConfig.sizedBoxHeight(115),
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: SizeConfig.getPaddingOnly(top: 20),
                  child: Text(
                    AppString.onboardingStrings.configurePermission,
                    style: AppTypography.h220(context).copyWith(),
                  ),
                ),
              ),
            ),
            SizedBox(height: SizeConfig.height(4)),

            // Description
            Padding(
              padding: SizeConfig.getPaddingSymmetric(horizontal: 70),
              child: _buildChooseWhatMatter(
                context,
                title: AppString.onboardingStrings.chooseWhat,
              ),
            ),
            SizedBox(height: SizeConfig.height(2)),

            // Preference title
            _buildPreferenceTitle(
              context,
              title: AppString.onboardingStrings.galleryNotifi,
            ),
            SizedBox(height: SizeConfig.height(4)),

            // Permission preferences
            _buildPermissionPreference(
              context,
              isPermission: isMediaGranted,
              permisName: AppString.onboardingStrings.photoAccess,
              greyText: AppString.onboardingStrings.userNeedToAllow,
            ),
            SizedBox(height: SizeConfig.height(2)),

            _buildPermissionPreference(
              context,
              isPermission: isMediaGranted,
              permisName: AppString.onboardingStrings.videoAccess,
              greyText: AppString.onboardingStrings.userNeedToVideo,
            ),
            SizedBox(height: SizeConfig.height(2)),

            _buildPermissionPreference(
              context,
              isPermission: isMediaGranted,
              permisName: AppString.onboardingStrings.viewAccessPermission,
              greyText: AppString.onboardingStrings.userAllowDownload,
            ),
            SizedBox(height: SizeConfig.height(4)),

            // Note box
            _buildNoteBox(
              context,
              title1: AppString.onboardingStrings.toReceiveNotification,
              title2: AppString.onboardingStrings.ifYouWantToDisable,
            ),
          ],
        );
      },
    );
  }
}

// ============================
// COMMON WIDGETS FOR ALL PERMISSION SCREENS
// ============================

// Description text widget
Widget _buildChooseWhatMatter(BuildContext context, {required String title}) {
  return Text(
    title,
    textAlign: TextAlign.center,
    style: AppTypography.inputPlaceholderSmall(context).copyWith(
      color: AppColors.textColor.textGreyColor,
      fontFamily: AppTypography.fontFamily.poppins,
    ),
  );
}

// Preference title widget
Widget _buildPreferenceTitle(BuildContext context, {required String title}) {
  return Text(
    title,
    style: AppTypography.h4(
      context,
    ).copyWith(color: AppColors.appPriSecColor.primaryColor),
  );
}

// Permission preference item widget
Widget _buildPermissionPreference(
  BuildContext context, {
  required bool isPermission,
  required String permisName,
  required String greyText,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(permisName, style: AppTypography.h5(context))),
            Container(
              height: SizeConfig.sizedBoxHeight(16),
              width: SizeConfig.sizedBoxWidth(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isPermission
                          ? AppColors.transparent
                          : AppColors.appPriSecColor.primaryColor,
                ),
                color:
                    isPermission
                        ? AppColors.appPriSecColor.primaryColor
                        : AppColors.transparent,
              ),
              child:
                  isPermission
                      ? Center(child: SvgPicture.asset(AppAssets.right))
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      SizedBox(height: SizeConfig.height(1)),
      Padding(
        padding: SizeConfig.getPaddingOnly(left: 25, right: 5),
        child: Text(
          greyText,
          textAlign: TextAlign.left,
          style: AppTypography.inputPlaceholderSmall(context).copyWith(
            color: AppColors.textColor.textGreyColor,
            fontFamily: AppTypography.fontFamily.poppins,
            fontSize: SizeConfig.getFontSize(11.5),
          ),
        ),
      ),
    ],
  );
}

// Note box widget
Widget _buildNoteBox(
  BuildContext context, {
  required String title1,
  required String title2,
}) {
  return Padding(
    padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Color(0xffF8E6A7).withValues(alpha: 0.80),
          ),
          padding: SizeConfig.getPadding(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                AppAssets.inforCircle,
                height: SizeConfig.sizedBoxHeight(18),
              ),
              SizedBox(width: SizeConfig.width(3)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBulletPoint(context, text: title1),
                    SizedBox(height: SizeConfig.height(1)),
                    _buildBulletPoint(context, text: title2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Bullet point text widget
Widget _buildBulletPoint(BuildContext context, {required String text}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: SizeConfig.getPaddingOnly(top: 5),
        child: Container(
          height: SizeConfig.sizedBoxHeight(3),
          width: SizeConfig.sizedBoxWidth(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.black,
          ),
        ),
      ),
      SizedBox(width: SizeConfig.width(1.5)),
      Expanded(
        child: Text(
          text,
          style: AppTypography.buttonText(context).copyWith(
            fontSize: SizeConfig.getFontSize(11),
            fontFamily: AppTypography.fontFamily.poppins,
          ),
        ),
      ),
    ],
  );
}
