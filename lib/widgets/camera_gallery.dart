import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';

Future bottomSheetCameraGallrey(
  BuildContext context, {
  required Function() onTapCamera,
  required Function() onTapGallery,
}) {
  return bottomSheetGobal(
    context,
    bottomsheetHeight: SizeConfig.safeHeight(25),
    title: AppString.settingStrigs.profilePhoto,
    child: Column(
      children: [
        SizedBox(height: SizeConfig.height(3)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            bottomContainer(
              context,
              title: AppString.settingStrigs.camera,
              img: AppAssets.svgIcons.camera,
              onTap: onTapCamera,
            ),
            SizedBox(width: SizeConfig.width(10)),
            bottomContainer(
              context,
              title: AppString.settingStrigs.gellery,
              img: AppAssets.svgIcons.gellery,
              onTap: onTapGallery,
            ),
          ],
        ),
      ],
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
            color: AppColors.opacityColor.opacitySecColor,
          ),
          child: Padding(
            padding: SizeConfig.getPadding(12),
            child: Center(
              child: SvgPicture.asset(
                img,
                height: SizeConfig.sizedBoxHeight(22),
              ),
            ),
          ),
        ),
        SizedBox(height: SizeConfig.height(1)),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.smallText(context).copyWith(
            fontFamily: AppTypography.fontFamily.poppins,
            color: AppColors.textColor.textGreyColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
