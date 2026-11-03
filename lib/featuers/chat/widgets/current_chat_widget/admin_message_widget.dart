import 'dart:math';
import 'package:whoxa/main.dart';
import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

class AdminTextMessageWidget extends StatelessWidget {
  final chats.Records chat;
  final String currentUserId;

  const AdminTextMessageWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isSentByMe = chat.senderId.toString() == currentUserId;
    final hasParentMessage = chat.parentMessage != null;

    final messageText = chat.messageContent ?? '';
    final parentText = chat.parentMessage?['message_content'] ?? '';
    final senderName = ChatRelatedWidget.getSenderName(
      context,
      chat.parentMessage ?? {},
      currentUserId,
    );
    final messageType = chat.messageType ?? 'admin_broadcast';
    final parentType = chat.parentMessage?['message_type'] ?? 'admin_broadcast';
    logger.v("messageType:$messageType");
    final messageWidth = _calculateTextWidth1(
      context,
      messageText,
      messageType,
    );
    final parentWidth =
        hasParentMessage
            ? _calculateTextWidth1(context, parentText, parentType)
            : 0.0;
    final senderNameWidth = _calculateTextWidth1(
      context,
      senderName,
      'admin_broadcast',
    );

    final totalBubbleWidth = min(
      SizeConfig.width(70),
      max(max(messageWidth, parentWidth), senderNameWidth) + 30,
    ); // 30 for padding

    return Column(
      crossAxisAlignment:
          isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: totalBubbleWidth),
          decoration: BoxDecoration(
            color:
                isSentByMe
                    ? (Fp.dark ? Fp.violet.withValues(alpha: 0.32) : const Color(0xFFEDE6FF))
                    : Fp.inkRaised,
            borderRadius: AppDirectionality.appDirectionBorderRadius
                .chatBubbleRadius(
                  isSentByMe: isSentByMe,
                  hasParentMessage: hasParentMessage,
                ),
          ),
          child: Padding(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: hasParentMessage ? 3 : 15,
              vertical: hasParentMessage ? 3 : 8,
            ),
            child: Column(
              crossAxisAlignment:
                  isSentByMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main message content
                Padding(
                  padding: SizeConfig.getPaddingOnly(
                    left: hasParentMessage ? 10 : 0,
                    right: hasParentMessage ? 8 : 0,
                  ),
                  child: Text(
                    chat.messageContent ?? '',
                    style: AppTypography.innerText12Ragu(context).copyWith(
                      color:
                          isSentByMe
                              ? ThemeColorPalette.getTextColor(
                                AppColors.appPriSecColor.primaryColor,
                              )
                              : AppThemeManage.appTheme.textColor,
                    ),
                  ),
                ),
                isSentByMe
                    ? hasParentMessage
                        ? SizedBox(height: SizeConfig.height(2))
                        : SizedBox.shrink()
                    : SizedBox.shrink(),
              ],
            ),
          ),
        ),
        // ✅ NEW: Add metadata row with star
        SizedBox(height: SizeConfig.height(1)),
      ],
    );
  }

  // double _calculateTextWidth(BuildContext context, String text) {
  //   final TextPainter textPainter = TextPainter(
  //     text: TextSpan(text: text, style: AppTypography.mediumText(context)),
  //     maxLines: 1,
  //     textDirection: TextDirection.ltr,
  //   )..layout();

  //   // Add some padding so text doesn't hit the edge
  //   return textPainter.size.width + 24;
  // }

  double _calculateTextWidth1(
    BuildContext context,
    String messageContent,
    String messageType,
  ) {
    String displayText;

    switch (messageType.toLowerCase()) {
      case 'admin_broadcast':
      case 'poll':
      case 'link':
      case 'text':
        displayText = messageContent;
        break;
      case 'image':
        displayText = 'Image';
        break;
      case 'video':
        displayText = 'Video';
        break;
      case 'document':
      case 'doc':
      case 'pdf':
        displayText = 'Document';
        break;
      case 'location':
        displayText = 'Location';
        break;
      case 'gif':
        displayText = 'gif';
        break;
      default:
        displayText = '';
    }

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: AppTypography.mediumText(context),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    return textPainter.size.width + 24; // 24 = padding
  }
}
