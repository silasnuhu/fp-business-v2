import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/chat/widgets/chat_files_views_handle/image_view.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/base_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/delete_message_widget.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class GifMessageWidget extends BaseMessageWidget {
  final VoidCallback? onTap;
  final bool isStarred;
  final Function(int)? onReplyTap;
  final bool isForPinned;
  final bool openedFromStarred; // If Opened from the Starred Messages Screen

  const GifMessageWidget({
    super.key,
    required super.chat,
    required super.currentUserId,
    this.onTap,
    this.isStarred = false,
    this.onReplyTap,
    required this.isForPinned,
    this.openedFromStarred = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSender = chat.senderId.toString() == currentUserId;
    final gifUrl = chat.messageContent ?? '';
    final heroTag = "${gifUrl}_gif";
    final hasParentMessage = chat.parentMessage != null;

    // Additional safety check: if message is deleted, don't render GIF
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
            width: SizeConfig.screenWidth * 0.5,
            decoration: BoxDecoration(
              borderRadius:
                  (openedFromStarred && isSentByMe)
                      ? BorderRadius.circular(7)
                      : messageBorderRadius,
              color: messageBackgroundColor,
              // Add subtle border for starred messages
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
                // Show parent message if this is a reply
                if (hasParentMessage) ...[
                  isForPinned
                      ? SizedBox.shrink()
                      : _buildParentMessagePreview(context, isSender),
                  isForPinned ? SizedBox.shrink() : SizedBox(height: 3),
                ],

                ClipRRect(
                  borderRadius:
                      (openedFromStarred && isSentByMe)
                          ? BorderRadius.circular(7)
                          : isSender
                          ? BorderRadius.only(
                            topLeft: Radius.circular(7),
                            bottomLeft: Radius.circular(7),
                            topRight: Radius.circular(7),
                          )
                          : BorderRadius.only(
                            topRight: Radius.circular(7),
                            bottomRight: Radius.circular(7),
                            topLeft: Radius.circular(7),
                          ),
                  child: Stack(
                    children: [
                      // GIF Image
                      GifThumbnail(
                        isSender: isSender,
                        gifUrl: gifUrl,
                        heroTag: heroTag,
                        onTap:
                            onTap ??
                            () {
                              context.viewImage(
                                imageSource: gifUrl,
                                imageTitle: 'GIF',
                                heroTag: heroTag,
                              );
                            },
                      ),
                      // GIF indicator overlay
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.gif, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'GIF',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                isSentByMe: isSender,
              ),
          (isForPinned || openedFromStarred)
              ? SizedBox.shrink()
              : SizedBox(height: SizeConfig.height(0)),
          // _buildMetadataRow(context, isSender),
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
    // Check if the message is deleted and show only text
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
      case 'gif':
        return ChatRelatedWidget.buildGifPreview(
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

// GIF Thumbnail widget similar to ImageThumbnail
class GifThumbnail extends StatelessWidget {
  final String gifUrl;
  final String heroTag;
  final VoidCallback? onTap;
  final bool? isSender;

  const GifThumbnail({
    super.key,
    required this.gifUrl,
    required this.heroTag,
    this.onTap,
    this.isSender,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: heroTag,
        child: Container(
          width: SizeConfig.screenWidth * 0.6,
          height: SizeConfig.height(20),
          decoration: BoxDecoration(
            color: AppColors.grey,
            borderRadius:
                isSender!
                    ? BorderRadius.only(
                      topLeft: Radius.circular(7),
                      bottomLeft: Radius.circular(7),
                      topRight: Radius.circular(7),
                    )
                    : BorderRadius.only(
                      topRight: Radius.circular(7),
                      bottomRight: Radius.circular(7),
                      topLeft: Radius.circular(7),
                    ),
          ),
          child:
              gifUrl.isNotEmpty
                  ? ClipRRect(
                    borderRadius:
                        isSender!
                            ? BorderRadius.only(
                              topLeft: Radius.circular(7),
                              bottomLeft: Radius.circular(7),
                              topRight: Radius.circular(7),
                            )
                            : BorderRadius.only(
                              topRight: Radius.circular(7),
                              bottomRight: Radius.circular(7),
                              topLeft: Radius.circular(7),
                            ),
                    child: Image.network(
                      gifUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.appPriSecColor.primaryColor,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.grey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.gif,
                                size: 40,
                                color: AppColors.textColor.textGreyColor,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'GIF failed to load',
                                style: TextStyle(
                                  color: AppColors.textColor.textGreyColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.gif,
                        size: 40,
                        color: AppColors.textColor.textGreyColor,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'GIF',
                        style: TextStyle(
                          color: AppColors.textColor.textGreyColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}
