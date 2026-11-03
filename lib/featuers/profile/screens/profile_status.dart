import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/profile/provider/profile_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';

class ProfileStatus extends StatelessWidget {
  const ProfileStatus({super.key});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      backgroundColor: AppColors.bgColor.bgWhite,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          shape: Border(
            bottom: BorderSide(color: AppColors.shadowColor.cE9E9E9),
          ),
          backgroundColor: AppColors.transparent,
          systemOverlayStyle: systemUI(),
          flexibleSpace: flexibleSpace(),
          leading: Padding(
            padding: SizeConfig.getPadding(12),
            child: customeBackArrowBalck(context),
          ),
          title: Text(
            AppString.settingStrigs.profile,
            style: AppTypography.h2(context),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: SizeConfig.height(2.5)),
          Consumer<ProfileProvider>(
            builder: (context, profileProvider, child) {
              return containerDesgin(
                context,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.bio).then((_) {
                    bio;
                  });
                },
                img: AppAssets.settingsIcosn.about,
                title: AppString.settingStrigs.status,
                count: bio,
                isCount: true,
              );
            },
          ),
          SizedBox(height: SizeConfig.height(2)),
          containerDesgin(
            context,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.profile);
            },
            img: AppAssets.settingsIcosn.profile,
            title: AppString.settingStrigs.editProfile,
            count: "",
            isCount: false,
          ),
        ],
      ),
    );
  }
}

Widget containerDesgin(
  BuildContext context, {
  required Function() onTap,
  required String img,
  required String title,
  required String count,
  required bool isCount,
}) {
  return Padding(
    padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: SizeConfig.safeHeight(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.bgColor.bgWhite,
          border: Border.all(color: AppColors.bgColor.bgEFEFEF),
        ),
        child: Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SvgPicture.asset(img, height: SizeConfig.safeHeight(2.5)),
                  SizedBox(width: SizeConfig.width(2.5)),
                  Text(
                    title,
                    style: AppTypography.inputPlaceholderSmall(
                      context,
                    ).copyWith(fontFamily: AppTypography.fontFamily.poppins),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  isCount
                      ? Text(
                        count,
                        style: AppTypography.menuText(context).copyWith(
                          color: AppColors.textColor.textGreyColor,
                          fontSize: SizeConfig.getFontSize(10),
                        ),
                      )
                      : SizedBox.shrink(),
                  isCount
                      ? SizedBox(width: SizeConfig.width(2))
                      : SizedBox.shrink(),
                  SvgPicture.asset(
                    AppAssets.settingsIcosn.arrowforward,
                    height: SizeConfig.safeHeight(2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
