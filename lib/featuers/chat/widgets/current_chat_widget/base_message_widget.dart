import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import '../../../../utils/brand_theme.dart';

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
  /// Sent bubbles use the deeper brand purple: the flat brand hue washed out
  /// behind white text on bright screens.
  Color get messageBackgroundColor =>
      isSentByMe
          ? FpBrand.purpleDeep
          : AppThemeManage.appTheme.chatOppoColor;

  /// Get text color based on sender
  /// Outgoing bubbles carry a saturated purple, so text must be white -
  /// black-on-purple was unreadable in sunlight and on OLED dark mode.
  Color get messageTextColor =>
      isSentByMe ? Colors.white : AppColors.textColor.textBlackColor;
}
