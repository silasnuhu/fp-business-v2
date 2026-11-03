import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/widgets/contact_details_bottom_sheet.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/avatar_initials.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class ContactMessageWidget extends StatelessWidget {
  final chats.Records chat;
  final String currentUserId;
  final bool isStarred;
  final Function(int)? onReplyTap;
  final bool isForPinned;
  final bool openedFromStarred; // If Opened from the Starred Messages Screen
  final Function()? onTap;

  const ContactMessageWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
    this.isStarred = false,
    this.onReplyTap,
    required this.isForPinned,
    this.onTap,
    this.openedFromStarred =
        false, // If Opened from the Starred Messages Screen
  });

  Map<String, String> _parseContactData(String messageContent) {
    // Parse format: "Name,PhoneNumber"
    final parts = messageContent.split(',');
    return {
      'name': parts.isNotEmpty ? parts[0].trim() : 'Unknown Contact',
      'phone': parts.length > 1 ? parts[1].trim() : '',
    };
  }

  void _showContactDetails(
    BuildContext context,
    String contactName,
    String phoneNumber,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => ContactDetailsBottomSheet(
            contactName: contactName,
            phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
            userId: null,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMyMessage = chat.senderId.toString() == currentUserId;
    final contactData = _parseContactData(chat.messageContent?.trim() ?? '');
    final hasParentMessage = chat.parentMessage != null;
    final contactName = contactData['name']!;
    final phoneNumber = contactData['phone']!;

    return InkWell(
      onTap:
          openedFromStarred
              ? onTap
              : isForPinned
              ? () {}
              : () => _showContactDetails(context, contactName, phoneNumber),
      child: Column(
        crossAxisAlignment:
            openedFromStarred
                ? CrossAxisAlignment.start
                : isMyMessage
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: SizeConfig.width(55),
              minWidth: SizeConfig.width(30),
            ),
            padding: SizeConfig.getPaddingSymmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color:
                  isMyMessage
                      ? (Fp.dark ? Fp.violet.withValues(alpha: 0.32) : const Color(0xFFEDE6FF))
                      : AppThemeManage.appTheme.chatOppoColor,
              borderRadius:
                  (openedFromStarred && isMyMessage)
                      ? BorderRadius.circular(7)
                      : AppDirectionality.appDirectionBorderRadius
                          .chatBubbleRadius(
                            isSentByMe: isMyMessage,
                            hasParentMessage: false,
                          ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ NEW: Show parent message if this is a reply
                if (hasParentMessage) ...[
                  isForPinned
                      ? SizedBox.shrink()
                      : _buildParentMessagePreview(context, isMyMessage),
                  isForPinned ? SizedBox.shrink() : SizedBox(height: 3),
                ],
                // Single contact display
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(9),
                      topRight: Radius.circular(9),
                    ),
                    color:
                        hasParentMessage
                            ? isMyMessage
                                ? (Fp.dark ? Fp.violet.withValues(alpha: 0.32) : const Color(0xFFEDE6FF))
                                : AppColors.bgColor.bg2Color
                            : AppThemeManage.appTheme.darkGreyColor,
                  ),
                  child: Padding(
                    padding: SizeConfig.getPaddingSymmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        // Contact avatar with Hero animation
                        Hero(
                          tag: 'contact_avatar_$contactName',
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.bgColor.bgEFEFEF,
                            child: Text(
                              _getInitials(contactName),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textColor.textBlackColor,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: SizeConfig.width(2)),
                        // Contact name and phone
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contactName,
                                style: AppTypography.innerText12Mediu(
                                  context,
                                ).copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (phoneNumber.isNotEmpty) ...[
                                SizedBox(height: 2),
                                Text(
                                  phoneNumber,
                                  style: AppTypography.innerText10(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color:
                            hasParentMessage
                                ? AppColors.black.withValues(alpha: 0.04)
                                : AppColors.transparent,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: SizeConfig.getPaddingSymmetric(vertical: 5),
                    child: Center(
                      child: Text(
                        AppString.viewContact,
                        style: AppTypography.innerText12Mediu(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              isMyMessage
                                  ? ThemeColorPalette.getTextColor(
                                    AppColors.appPriSecColor.primaryColor,
                                  ) //AppColors.textColor.textBlackColor
                                  : AppThemeManage.appTheme.textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          isForPinned
              ? SizedBox.shrink()
              : SizedBox(height: SizeConfig.height(0.5)),
          (isForPinned || openedFromStarred)
              ? SizedBox.shrink()
              : ChatRelatedWidget.buildMetadataRow(
                context: context,
                chat: chat,
                isStarred: isStarred,
                isSentByMe: isMyMessage,
              ),
          (isForPinned || openedFromStarred)
              ? SizedBox.shrink()
              : SizedBox(height: SizeConfig.height(0)),
        ],
      ),
    );
  }

  String _getInitials(String name) => avatarInitials(name);

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
          color: AppThemeManage.appTheme.bg4DarkGrey,
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
