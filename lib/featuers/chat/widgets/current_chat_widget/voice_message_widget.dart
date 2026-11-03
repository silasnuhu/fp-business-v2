import 'package:whoxa/main.dart';
import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/base_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/delete_message_widget.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/voice_wave.dart/voice_wave_design.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class VoiceMessageWidget extends BaseMessageWidget {
  final VoidCallback? onTap;
  final bool isStarred; // ✅ NEW: Star status parameter
  final Function(int)? onReplyTap; // ✅ NEW: Callback for reply tap
  final bool isForPinned;
  final bool openedFromStarred; // If Opened from the Starred Messages Screen

  const VoiceMessageWidget({
    super.key,
    required super.chat,
    required super.currentUserId,
    this.onTap,
    this.isStarred = false, // ✅ NEW: Default to false
    this.onReplyTap, // ✅ NEW: Optional callback for reply
    required this.isForPinned,
    this.openedFromStarred =
        false, // If Opened from the Starred Messages Screen
  });

  @override
  Widget build(BuildContext context) {
    final isSender = chat.senderId.toString() == currentUserId;
    final voiceUrl = chat.messageContent ?? '';
    final voiceDurationStr = chat.voiceDuration ?? "00:00";
    logger.v("voiceDurationStr:$voiceDurationStr");
    final hasParentMessage = chat.parentMessage != null;
    final messageId = chat.messageId;
    logger.v("🎶🎶voiceUrl🎶🎶 ::$voiceUrl");

    // ✅ Additional safety check: if message is deleted, don't render image
    if (chat.messageContent == 'This message was deleted.' ||
        chat.messageContent == 'This message was deleted' ||
        chat.deletedForEveryone == true) {
      return DeletedMessageWidget(chat: chat, currentUserId: currentUserId);
    }

    return Align(
      alignment:
          isForPinned
              ? Alignment.centerLeft
              : isSender
              ? openedFromStarred
                  ? Alignment.centerLeft
                  : AppDirectionality.appDirectionAlign.alignmentEnd
              : AppDirectionality.appDirectionAlign.alignmentLeftRight,
      child: Column(
        crossAxisAlignment:
            openedFromStarred
                ? CrossAxisAlignment.start
                : isSender
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: SizeConfig.screenWidth * 0.70,
            ),
            padding: SizeConfig.getPaddingSymmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              borderRadius:
                  (openedFromStarred && isSentByMe)
                      ? BorderRadius.circular(7)
                      : messageBorderRadius,
              color: messageBackgroundColor,

              // ✅ NEW: Add subtle border for starred messages
              border:
                  isSender
                      ? Border.all(
                        color: (Fp.dark ? Fp.violet.withValues(alpha: 0.32) : const Color(0xFFEDE6FF)),
                        width: 2,
                      )
                      : Border.all(
                        color: AppThemeManage.appTheme.chatOppoColor,
                        width: 2,
                      ),
            ),
            child: Column(
              children: [
                // ✅ NEW: Show parent message if this is a reply
                if (hasParentMessage) ...[
                  isForPinned
                      ? SizedBox.shrink()
                      : _buildParentMessagePreview(context, isSender),
                  isForPinned ? SizedBox.shrink() : SizedBox(height: 3),
                ],
                Container(
                  padding: SizeConfig.getPaddingSymmetric(
                    horizontal: 5,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: AppThemeManage.appTheme.darkGreyColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: WavedAudioPlayer2(
                    audioUrl: voiceUrl,
                    voiceDuration: parseDuration(voiceDurationStr),
                    messageId: messageId.toString(),
                    playColor:
                        isSentByMe
                            ? AppColors.appPriSecColor.primaryColor
                            : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          isForPinned
              ? SizedBox.shrink()
              : SizedBox(height: SizeConfig.height(1)),
          (isForPinned || openedFromStarred)
              ? SizedBox.shrink()
              : ChatRelatedWidget.buildMetadataRow(
                context: context,
                chat: chat,
                isStarred: isStarred,
                isSentByMe: isSender,
              ),
          (isForPinned || openedFromStarred)
              ? SizedBox.shrink()
              : SizedBox(height: SizeConfig.height(0)),
        ],
      ),
    );
  }

  Duration parseDuration(String value) {
    final parts = value.split(':').map(int.parse).toList();

    if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    } else if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    }
    return Duration.zero;
  }

  /// Build parent message preview with tap functionality
  Widget _buildParentMessagePreview(BuildContext context, bool isSentByMe) {
    final parentMessage = chat.parentMessage!;
    final parentContent = parentMessage['message_content'] ?? 'Message';
    final parentType = parentMessage['message_type'] ?? 'text';
    final parentThumbnail = parentMessage['message_thumbnail'];
    final parentMessageId = parentMessage['message_id'];

    return GestureDetector(
      onTap: () {
        // Handle tap to navigate to original message
        if (onReplyTap != null && parentMessageId != null) {
          onReplyTap!(parentMessageId as int);
        }
      },
      child: Container(
        constraints: BoxConstraints(maxWidth: SizeConfig.width(70)),
        padding: SizeConfig.getPaddingSymmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: AppThemeManage.appTheme.bg488DarkGrey,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with reply icon and sender name
            Row(
              children: [
                Text(
                  ChatRelatedWidget.getSenderName(
                    context,
                    parentMessage,
                    currentUserId,
                  ),
                  style: AppTypography.captionText(context).copyWith(
                    color: AppColors.appPriSecColor.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),

            // Content preview
            _buildParentMessageContent(
              context,
              parentType,
              parentContent,
              parentThumbnail,
              isSentByMe,
            ),
          ],
        ),
      ),
    );
  }

  /// Build parent message content based on type
  Widget _buildParentMessageContent(
    BuildContext context,
    String messageType,
    String content,
    String? thumbnail,
    bool isSentByMe,
  ) {
    // ✅ Check if the message is deleted and show only text
    if (content == 'This message was deleted.' ||
        content == 'This message was deleted' ||
        content.isEmpty) {
      return ChatRelatedWidget.buildTextPreview(
        context: context,
        content: AppString.thisMessageWasDeleted,
        isSentByMe: isSentByMe,
      );
    }

    switch (messageType.toLowerCase()) {
      case 'voice':
        return ChatRelatedWidget.buildVoicePreview(
          context: context,
          isSentByMe: isSentByMe,
        );
      case 'image':
        return ChatRelatedWidget.buildImagePreview(
          context: context,
          imageUrl: content,
          isSentByMe: isSentByMe,
        );
      case 'video':
        return ChatRelatedWidget.buildVideoPreview(
          context: context,
          videoUrl: content,
          thumbnailUrl: thumbnail,
          isSentByMe: isSentByMe,
        );
      case 'document':
      case 'doc':
      case 'pdf':
        return ChatRelatedWidget.buildDocumentPreview(context, isSentByMe);
      case 'location':
        return ChatRelatedWidget.buildLocationPreview(context, isSentByMe);
      case 'contact':
        return ChatRelatedWidget.buildContactPreview(context, isSentByMe);
      case 'link':
        return ChatRelatedWidget.buildLinkPreview(
          context: context,
          content: content,
          isSentByMe: isSentByMe,
        );
      case 'poll':
        return ChatRelatedWidget.buildPollPreview(
          context: context,
          content: content,
          isSentByMe: isSentByMe,
        );
      case 'text':
      default:
        return ChatRelatedWidget.buildTextPreview(
          context: context,
          content: content,
          isSentByMe: isSentByMe,
        );
    }
  }
}
