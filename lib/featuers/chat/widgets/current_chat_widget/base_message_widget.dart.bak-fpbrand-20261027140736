import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

abstract class BaseMessageWidget extends StatelessWidget {
  final chats.Records chat;
  final String currentUserId;

  const BaseMessageWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
  });

  /// Check if message is sent by current user
  bool get isSentByMe => chat.senderId.toString() == currentUserId;

  /// Get border radius based on sender
  BorderRadius get messageBorderRadius => AppDirectionality
      .appDirectionBorderRadius
      .chatBubbleRadius(isSentByMe: isSentByMe, hasParentMessage: false);

  /// Get message background color
  Color get messageBackgroundColor =>
      isSentByMe
          ? AppColors.appPriSecColor.primaryColor
          : AppThemeManage.appTheme.chatOppoColor;

  /// Get text color based on sender
  Color get messageTextColor =>
      isSentByMe
          ? AppColors.textColor.textBlackColor
          : AppColors.textColor.textBlackColor;
}
