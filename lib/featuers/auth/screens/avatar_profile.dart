import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/provider/tabbar_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/clip_path.dart';
import 'package:whoxa/widgets/global.dart';

class AvatarProfile extends StatelessWidget {
  const AvatarProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor.bg4Color,
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return Column(
            children: [
              Stack(
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
                        color: AppColors.bgColor.bg4Color,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ClipOval(child: profileWidget(authProvider)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 16,
                    child: Row(
                      children: [
                        // GestureDetector(
                        //   onTap: () => Navigator.pop(context),
                        //   child: Icon(
                        //     Icons.arrow_back_ios_new,
                        //     color: Colors.black,
                        //     size: 20,
                        //   ),
                        // ),
                        // const SizedBox(width: 8),
                        const SizedBox(width: 2),
                        Text(
                          AppString.avatarScreenString.selectProfile,
                          style: AppTypography.h220(context).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: SizeConfig.getFontSize(18),
                            color: ThemeColorPalette.getTextColor(
                              AppColors.appPriSecColor.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: SizeConfig.height(6)),
                      //******************************** Horizontal Avatar List *********************************/
                      Padding(
                        padding: SizeConfig.getPaddingOnly(left: 20, right: 20),
                        child: container(
                          context,
                          radius: 15,
                          boxShadow: [
                            BoxShadow(
                              offset: Offset(0, 0),
                              spreadRadius: 0,
                              blurRadius: 8.4,
                              color: AppColors.bgColor.bgBlack.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ],
                          child: Padding(
                            padding: SizeConfig.getPaddingSymmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppString.avatarScreenString.chooseAvtar,
                                  style: AppTypography.text12(context).copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: SizeConfig.height(1.5)),
                                SizedBox(
                                  height: SizeConfig.sizedBoxHeight(80),
                                  child:
                                      authProvider.isLoadingAvatars
                                          ? Center(
                                            child: SizedBox(
                                              height: 40,
                                              width: 40,
                                              child: commonLoading(),
                                            ),
                                          )
                                          : authProvider.avatars.isNotEmpty
                                          ? ListView.builder(
                                            shrinkWrap: true,
                                            padding: EdgeInsets.zero,
                                            scrollDirection: Axis.horizontal,
                                            itemCount:
                                                authProvider.avatars.length,
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            itemBuilder: (context, index) {
                                              final avatar =
                                                  authProvider.avatars[index];
                                              final isSelected =
                                                  authProvider
                                                      .selectedAvatar
                                                      ?.avatarId ==
                                                  avatar.avatarId;

                                              return InkWell(
                                                onTap: () {
                                                  authProvider.selectAvatar(
                                                    avatar,
                                                  );
                                                },
                                                child: Padding(
                                                  padding:
                                                      SizeConfig.getPaddingOnly(
                                                        right: 10,
                                                      ),
                                                  child: Stack(
                                                    children: [
                                                      Container(
                                                        height:
                                                            SizeConfig.sizedBoxHeight(
                                                              80,
                                                            ),
                                                        width:
                                                            SizeConfig.sizedBoxWidth(
                                                              80,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color:
                                                                isSelected
                                                                    ? AppColors
                                                                        .appPriSecColor
                                                                        .primaryColor
                                                                    : Colors
                                                                        .transparent,
                                                            width: 2,
                                                          ),
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              SizeConfig.getPadding(
                                                                3,
                                                              ),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                              color:
                                                                  AppColors
                                                                      .appPriSecColor
                                                                      .secondaryColor,
                                                            ),
                                                            clipBehavior:
                                                                Clip.hardEdge,
                                                            child: CachedNetworkImage(
                                                              imageUrl:
                                                                  avatar
                                                                      .avatarMedia ??
                                                                  "",
                                                              fit: BoxFit.cover,
                                                              errorWidget: (
                                                                context,
                                                                url,
                                                                error,
                                                              ) {
                                                                return Center(
                                                                  child: Icon(
                                                                    Icons
                                                                        .person,
                                                                    color:
                                                                        AppColors
                                                                            .bgColor
                                                                            .bg4Color,
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      // Checkmark icon if selected
                                                      if (isSelected)
                                                        Positioned(
                                                          right: -1,
                                                          bottom: 8,
                                                          child: Container(
                                                            height:
                                                                SizeConfig.sizedBoxHeight(
                                                                  18,
                                                                ),
                                                            width:
                                                                SizeConfig.sizedBoxWidth(
                                                                  18,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                              gradient:
                                                                  AppColors
                                                                      .gradientColor
                                                                      .logoColor,
                                                              border: Border.all(
                                                                color:
                                                                    AppColors
                                                                        .bgColor
                                                                        .bgWhite,
                                                                width: 2,
                                                              ),
                                                            ),
                                                            child: Icon(
                                                              Icons.check,
                                                              color:
                                                                  Colors.black,
                                                              size: 10,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                          : Center(
                                            child: Text(
                                              AppString.avatarProfileNotFound,
                                            ),
                                          ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: SizeConfig.height(3)),
                      //************************  OR *******************************************************************************/
                      Padding(
                        padding: SizeConfig.getPaddingSymmetric(horizontal: 50),
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: AppColors.appPriSecColor.secondaryColor,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Text(
                                AppString.or,
                                style: AppTypography.text12(
                                  context,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: AppColors.appPriSecColor.secondaryColor,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: SizeConfig.height(3)),
                      // ****************************************** Galley Choose ***********************************************************
                      Padding(
                        padding: SizeConfig.getPaddingOnly(left: 20, right: 20),
                        child: container(
                          context,
                          radius: 15,
                          boxShadow: [
                            BoxShadow(
                              offset: Offset(0, 0),
                              spreadRadius: 0,
                              blurRadius: 8.4,
                              color: AppColors.bgColor.bgBlack.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ],
                          child: Padding(
                            padding: SizeConfig.getPaddingOnly(
                              left: 20,
                              right: 20,
                              top: 20,
                              bottom: 30,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppString.avatarScreenString.chooseFrom,
                                  style: AppTypography.text12(context).copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: SizeConfig.height(3)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    bottomContainer(
                                      context,
                                      title: AppString.settingStrigs.camera,
                                      img: AppAssets.svgIcons.camera,
                                      onTap: () {
                                        authProvider.getImageFromCamera();
                                      },
                                    ),
                                    SizedBox(width: SizeConfig.width(10)),
                                    bottomContainer(
                                      context,
                                      title: AppString.settingStrigs.gellery,
                                      img: AppAssets.svgIcons.gellery,
                                      onTap: () {
                                        authProvider.getImageFromGallery();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: SizeConfig.height(5)),
                      Padding(
                        padding: SizeConfig.getPaddingSymmetric(horizontal: 60),
                        child:
                            authProvider.isUserProfile
                                ? commonLoading()
                                : customBtn2(
                                  context,
                                  onTap: () async {
                                    final success = await authProvider
                                        .updateAvatarApi(context);

                                    if (!success) {
                                      if (!context.mounted) return;
                                      snackbarNew(
                                        context,
                                        msg:
                                            authProvider.errorMessage
                                                .toString(),
                                      );
                                    }
                                    if (success && context.mounted) {
                                      // Check if user needs to complete profile info
                                      String? freshFirstName =
                                          await SecurePrefs.getString(
                                            SecureStorageKeys.FIRST_NAME,
                                          ) ??
                                          "";

                                      if (freshFirstName.isEmpty) {
                                        // User needs to complete profile info
                                        if (context.mounted) {
                                          Navigator.pushNamedAndRemoveUntil(
                                            context,
                                            AppRoutes.addinfo,
                                            (Route<dynamic> route) => false,
                                          );
                                        }
                                      } else {
                                        // User profile is complete, go to main app
                                        if (context.mounted) {
                                          Provider.of<TabbarProvider>(
                                            context,
                                            listen: false,
                                          ).navigateToIndex(0);
                                          Navigator.pushNamedAndRemoveUntil(
                                            context,
                                            AppRoutes.tabbar,
                                            (Route<dynamic> route) => false,
                                          );
                                        }
                                      }
                                    }
                                  },
                                  child: Text(
                                    AppString.submit,
                                    style: AppTypography.h5(context).copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textColor.textBlackColor,
                                    ),
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget profileWidget(AuthProvider authProvider) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.50),
      child:
          authProvider.image != null
              ? Image.file(authProvider.image!, fit: BoxFit.cover)
              : authProvider.selectedAvatar != null
              ? CachedNetworkImage(
                imageUrl: authProvider.selectedAvatar!.avatarMedia ?? '',
                fit: BoxFit.cover,
                errorWidget: (context, url, error) {
                  return Center(
                    child: Icon(Icons.person, color: AppColors.bgColor.bgWhite),
                  );
                },
              )
              : Center(
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: AppColors.bgColor.bgWhite,
                ),
              ),
    );
  }

  Widget bottomContainer(
    BuildContext context, {
    required String title,
    required String img,
    required Function() onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.appPriSecColor.secondaryColor.withValues(
                alpha: 0.50,
              ),
            ),
            child: Padding(
              padding: SizeConfig.getPadding(15),
              child: Center(child: SvgPicture.asset(img, height: 22)),
            ),
          ),
          SizedBox(height: SizeConfig.height(1)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.captionText(context).copyWith(
              color: AppColors.textColor.textDarkGray,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
