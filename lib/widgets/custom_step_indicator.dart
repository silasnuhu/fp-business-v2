import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/widgets/global.dart';

class CustomStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepTitles;
  final VoidCallback? onBackPressed;

  const CustomStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitles,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          // Top progress indicator - full width divided equally
          SizedBox(
            height: 4,
            width: double.infinity,
            child: Row(
              children: List.generate(totalSteps, (index) {
                return Expanded(
                  child: Container(
                    height: 4,
                    color:
                        index <= currentStep
                            ? AppColors.appPriSecColor.primaryColor
                            : AppColors.strokeColor.cECECEC,
                  ),
                );
              }),
            ),
          ),

          // Step title with back button
          Container(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: 20,
              vertical: 16,
            ),
            child: Row(
              children: [
                // Back button - only show from step 1 onwards
                if (currentStep > 0 && onBackPressed != null)
                  IconButton(
                    onPressed: onBackPressed,
                    icon: customeBackArrowBalck(
                      context,
                      color: AppThemeManage.appTheme.textColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                  )
                else
                  SizedBox(width: 40),

                // Step title
                Expanded(
                  child: Text(
                    currentStep < stepTitles.length
                        ? stepTitles[currentStep]
                        : '',
                    style: AppTypography.innerText14(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppThemeManage.appTheme.textColor,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),

                // Spacer for balance
                SizedBox(width: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
