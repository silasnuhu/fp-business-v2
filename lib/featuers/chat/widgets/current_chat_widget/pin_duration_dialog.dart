// Pin Duration Selection Dialog
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class PinDurationDialog extends StatelessWidget {
  final Function(int) onDurationSelected;

  const PinDurationDialog({super.key, required this.onDurationSelected});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      elevation: 0,
      alignment: Alignment.bottomCenter,
      insetPadding: SizeConfig.getPaddingOnly(left: 15, right: 15, bottom: 10),
      backgroundColor: AppColors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3.8, sigmaY: 3.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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
                    color: AppThemeManage.appTheme.darkWhiteColor,
                  ),
                ),
              ),
            ),
            SizedBox(height: SizeConfig.height(2)),
            Container(
              decoration: BoxDecoration(
                color: AppThemeManage.appTheme.darkGreyColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          AppAssets.dotted1,
                          color: AppColors.appPriSecColor.primaryColor,
                        ),
                        Text(
                          AppString.homeScreenString.pinMessage,
                          style: AppTypography.h4(context),
                        ),
                      ],
                    ),
                    SizedBox(height: SizeConfig.height(1)),
                    Padding(
                      padding: SizeConfig.getPaddingSymmetric(horizontal: 60),
                      child: Container(
                        height: SizeConfig.sizedBoxHeight(30),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          color: AppColors.appPriSecColor.secondaryColor
                              .withValues(alpha: 0.4),
                        ),
                        child: Center(
                          child: Text(
                            AppString
                                .homeScreenString
                                .youCanUnpinAtAnyTime, //"You can unpin at any time",
                            style: AppTypography.innerText12Ragu(context),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: SizeConfig.height(1)),
                    // Dialog title

                    // Duration options
                    Divider(color: AppThemeManage.appTheme.borderColor),
                    _buildDurationOption(
                      context,
                      title: '24 ${AppString.homeScreenString.hours}',
                      value: 1,
                      assetName: AppAssets.chatImage.clock,
                    ),
                    Divider(color: AppThemeManage.appTheme.borderColor),
                    _buildDurationOption(
                      context,
                      title: '7 ${AppString.homeScreenString.days}',
                      value: 7,
                      assetName: AppAssets.chatImage.calendar,
                    ),
                    Divider(color: AppThemeManage.appTheme.borderColor),
                    _buildDurationOption(
                      context,
                      title: '30 ${AppString.homeScreenString.days}',
                      value: 30,
                      assetName: AppAssets.chatImage.calendar1,
                    ),
                    SizedBox(height: SizeConfig.height(1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationOption(
    BuildContext context, {
    required String title,
    required String assetName,
    required int value,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onDurationSelected(value);
      },
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 25, vertical: 12),
        child: Row(
          children: [
            SvgPicture.asset(
              assetName,
              height: 20,
              colorFilter: ColorFilter.mode(AppThemeManage.appTheme.darkWhiteColor, BlendMode.srcIn),
            ),
            SizedBox(width: 12),
            Text(
              title,
              style: AppTypography.innerText14(context).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: SizeConfig.getFontSize(13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
