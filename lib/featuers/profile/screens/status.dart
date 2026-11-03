import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/profile/provider/profile_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      Provider.of<ProfileProvider>(
        context,
        listen: false,
      ).statusGetApi(isGetData: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          shape: Border(
            bottom: BorderSide(color: AppThemeManage.appTheme.borderColor),
          ),
          backgroundColor: AppColors.transparent,
          systemOverlayStyle: systemUI(),
          flexibleSpace: flexibleSpace(),
          leading: Padding(
            padding: SizeConfig.getPadding(12),
            child: customeBackArrowBalck(context),
          ),
          titleSpacing: 1,
          title: Text(
            AppString.settingStrigs.about,
            style: AppTypography.h220(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          if (profileProvider.isGetLoad && !profileProvider.hasLoadedOnce) {
            return Center(child: commonLoading());
          }

          if (profileProvider.errorMessage != null &&
              !profileProvider.hasLoadedOnce) {
            return Center(
              child:
                  profileProvider.isInternetIssue
                      ? SvgPicture.asset(
                        AppAssets.svgIcons.internet,
                        colorFilter: ColorFilter.mode(
                          AppColors.appPriSecColor.primaryColor,
                          BlendMode.srcIn,
                        ),
                      )
                      : Text(
                        profileProvider.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: SizeConfig.getFontSize(13),
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: SizeConfig.height(4)),
              Padding(
                padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                child: Text(
                  AppString.settingStrigs.currentlySetTo,
                  style: AppTypography.textBoxUpperText12(context),
                ),
              ),
              SizedBox(height: SizeConfig.height(1)),
              Padding(
                padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.statuswrite);
                  },
                  child: Container(
                    height: SizeConfig.sizedBoxHeight(46),
                    decoration: BoxDecoration(
                      color: AppThemeManage.appTheme.scaffoldBackColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppThemeManage.appTheme.borderColor,
                      ),
                    ),
                    child: Padding(
                      padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            profileProvider.selectedabouttext.isNotEmpty
                                ? profileProvider.selectedabouttext
                                : AppString.noStatusSelected,
                            style: AppTypography.innerText11(context).copyWith(
                              color:
                                  profileProvider.selectedabouttext.isNotEmpty
                                      ? AppThemeManage.appTheme.textColor
                                      : AppColors.textColor.textGreyColor,
                            ),
                          ),

                          Icon(
                            Icons.arrow_forward_ios,
                            color: AppThemeManage.appTheme.textColor,
                            size: SizeConfig.safeHeight(2.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: SizeConfig.height(2.5)),
              Padding(
                padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                child: Text(
                  AppString.settingStrigs.selectYourAbout,
                  style: AppTypography.textBoxUpperText12(context),
                ),
              ),
              SizedBox(height: SizeConfig.height(0.5)),
              Padding(
                padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppThemeManage.appTheme.scaffoldBackColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppThemeManage.appTheme.borderColor,
                    ),
                  ),
                  child: Padding(
                    padding: SizeConfig.getPaddingSymmetric(vertical: 5),
                    child: ListView.separated(
                      itemCount: profileProvider.bioList.length,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      separatorBuilder: (context, index) {
                        return Divider(
                          color: AppThemeManage.appTheme.borderColor,
                        );
                      },
                      itemBuilder: (context, index) {
                        final isLoading = profileProvider.loadingIndex == index;
                        final isSelected =
                            profileProvider.selectedabouttext ==
                            profileProvider.bioList[index].name;
                        return InkWell(
                          splashColor: AppColors.transparent,
                          focusColor: AppColors.transparent,
                          highlightColor: AppColors.transparent,
                          hoverColor: AppColors.transparent,
                          onTap: () async {
                            profileProvider.setLoadingIndex(index);

                            profileProvider.statusText =
                                profileProvider.bioList[index].name;

                            final success = await profileProvider.statusGetApi(
                              isGetData: false,
                            );

                            if (!context.mounted) return;

                            profileProvider.setLoadingIndex(null);

                            if (success) {
                              profileProvider.selectStatus(
                                profileProvider.bioList[index],
                              );
                            } else {
                              final msg = profileProvider.errorMessage!;
                              snackbarNew(context, msg: msg);
                            }
                          },
                          child: Padding(
                            padding: SizeConfig.getPaddingSymmetric(
                              horizontal: 20,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  profileProvider.bioList[index].name,
                                  style: AppTypography.innerText11(context),
                                ),
                                if (isLoading)
                                  SizedBox(
                                    height: 15,
                                    width: 15,
                                    child: commonLoading2(),
                                  )
                                else if (isSelected)
                                  Icon(
                                    Icons.check,
                                    color: AppThemeManage.appTheme.textColor,
                                    size: 20,
                                  )
                                else
                                  SizedBox(
                                    height: SizeConfig.height(3),
                                    width: 15,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
