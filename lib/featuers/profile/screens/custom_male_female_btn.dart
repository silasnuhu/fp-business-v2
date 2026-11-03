import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

class MaleFemaleRadioBtn extends StatelessWidget {
  final VoidCallback onTap;
  final String maleFemaleTitle;
  final String matchString;

  const MaleFemaleRadioBtn({
    super.key,
    required this.onTap,
    required this.maleFemaleTitle,
    required this.matchString,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = maleFemaleTitle == matchString;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  isSelected
                      ? LinearGradient(
                        colors: <Color>[
                          AppColors.appPriSecColor.secondaryColor,
                          AppColors.appPriSecColor.primaryColor,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                      : AppColors.borderGradiant,
            ),
            child: Padding(
              padding: SizeConfig.getPadding(2),
              child: Container(
                height: SizeConfig.safeHeight(3.2),
                width: SizeConfig.safeWidth(3.2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppThemeManage.appTheme.bg4BlackColor,
                ),
                child:
                    isSelected
                        ? Padding(
                          padding: SizeConfig.getPadding(2.2),
                          child: Container(
                            height: SizeConfig.safeHeight(0.8),
                            width: SizeConfig.safeWidth(0.8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: <Color>[
                                  AppColors.appPriSecColor.secondaryColor,
                                  AppColors.appPriSecColor.primaryColor,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        )
                        : null,
              ),
            ),
          ),
          SizedBox(width: SizeConfig.width(2)),
          Text(
            matchString,
            style: AppTypography.innerText12Mediu(context).copyWith(
              color:
                  isSelected
                      ? AppThemeManage.appTheme.textColor
                      : AppColors.textColor.textGreyColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
