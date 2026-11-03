import 'package:flutter/material.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

class CustomCheckCircle extends StatelessWidget {
  final bool isSelected;

  const CustomCheckCircle({super.key, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            isSelected
                ? AppColors.appPriSecColor.primaryColor
                : AppThemeManage.appTheme.bg4DarkGrey,
        shape: BoxShape.circle,
        border:
            isSelected
                ? null
                : Border.all(
                  color: AppColors.appPriSecColor.secondaryColor,
                  width: 1.5,
                ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(
          Icons.check_rounded,
          color: isSelected ? AppColors.black : Colors.transparent,
          size: 16,
        ),
      ),
    );
  }
}
