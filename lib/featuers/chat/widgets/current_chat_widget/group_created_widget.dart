import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class GroupCreatedMessageWidget extends StatelessWidget {
  final String creatorName;
  final String? createdAt;

  const GroupCreatedMessageWidget({
    super.key,
    required this.creatorName,
    this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final timeText =
        createdAt != null
            ? DateFormat('hh:mm a').format(DateTime.parse(createdAt!))
            : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.group_add,
                    size: 16,
                    color: AppColors.appPriSecColor.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppString.nameCreatedTheGroup(creatorName),
                    style: AppTypography.smallText(context).copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.appPriSecColor.primaryColor,
                    ),
                  ),
                ],
              ),
              if (timeText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  timeText,
                  style: AppTypography.captionText(
                    context,
                  ).copyWith(color: AppColors.textColor.textGreyColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
