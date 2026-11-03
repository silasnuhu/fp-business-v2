import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/base_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/video_thumbnail_view.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/delete_message_widget.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class VideoMessageWidget extends BaseMessageWidget {
  final VoidCallback? onTap;
  final String? thumbnailUrl;
  final bool isStarred; // ✅ NEW: Star status parameter
  final Function(int)? onReplyTap; // ✅ NEW: Callback for reply tap
  final bool isForPinned;
  final bool openedFromStarred; // If Opened from the Starred Messages Screen

  const VideoMessageWidget({
    super.key,
    required super.chat,
    required super.currentUserId,
    this.onTap,
    this.thumbnailUrl,
    this.isStarred = false, // ✅ NEW: Default to false
    this.onReplyTap, // ✅ NEW: Optional callback for reply tap
    required this.isForPinned,
    this.openedFromStarred =
        false, // If Opened from the Starred Messages Screen
  });

  @override
  Widget build(BuildContext context) {
    final isSentByMe = chat.senderId.toString() == currentUserId;
    final hasParentMessage = chat.parentMessage != null;
    debugPrint('video message:$thumbnailUrl');

    // Compact preview inside the pinned bar; WhatsApp-like large preview in chat.
    final bool compactPreview = isForPinned;
    final double bubbleWidth =
        compactPreview
            ? SizeConfig.screenWidth * 0.5
            : SizeConfig.screenWidth * 0.66;
    final double bubbleHeight =
        compactPreview
            ? SizeConfig.sizedBoxHeight(160)
            : SizeConfig.sizedBoxHeight(260);

    // ✅ Additional safety check: if message is deleted, don't render video
    if (chat.messageContent == 'This message was deleted.' ||
        chat.messageContent == 'This message was deleted' ||
        chat.deletedForEveryone == true) {
      return DeletedMessageWidget(chat: chat, currentUserId: currentUserId);
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment:
            openedFromStarred
                ? CrossAxisAlignment.start
                : isSentByMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: [
          Container(
            width: bubbleWidth,
            decoration: BoxDecoration(
              borderRadius:
                  (openedFromStarred && isSentByMe)
                      ? BorderRadius.circular(7)
                      : messageBorderRadius,
              color: messageBackgroundColor,
              // ✅ NEW: Add subtle border for starred messages
              border:
                  isSentByMe
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
                      : _buildParentMessagePreview(context, isSentByMe),
                  isForPinned ? SizedBox.shrink() : SizedBox(height: 3),
                ],
                ClipRRect(
                  borderRadius: messageBorderRadius,
                  child: Stack(
                    children: [
                      // Main video poster frame — backend thumbnail when it
                      // exists, otherwise a client-generated frame.
                      VideoThumbnailView(
                        width: bubbleWidth,
                        height: bubbleHeight,
                        backendThumbnailUrl: thumbnailUrl,
                        videoUrl: chat.messageContent ?? '',
                      ),

                      // Play button overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.black.withValues(alpha: 0.3),
                          ),
                          child: Center(
                            child: Container(
                              width: compactPreview ? 40 : 52,
                              height: compactPreview ? 40 : 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.white.withValues(alpha: 0.9),
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                size: compactPreview ? 25 : 32,
                                color: AppColors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                isSentByMe: isSentByMe,
              ),
          (isForPinned || openedFromStarred)
              ? SizedBox.shrink()
              : SizedBox(height: SizeConfig.height(0)),
        ],
      ),
    );
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
