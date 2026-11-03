import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class DeletedMessageWidget extends StatelessWidget {
  final chats.Records chat;
  final String currentUserId;

  const DeletedMessageWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    // final isSentByMe = chat.senderId.toString() == currentUserId;

    return Container(
      constraints: BoxConstraints(maxWidth: SizeConfig.width(70)),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.bg3DarkGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppThemeManage.appTheme.greyOppBorder,
          width: 1,
        ),
      ),
      padding: SizeConfig.getPaddingSymmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 16, color: AppColors.textColor.textGreyColor),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              AppString.thisMessageWasDeleted,
              style: AppTypography.mediumText(context).copyWith(
                color: AppColors.textColor.textGreyColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
