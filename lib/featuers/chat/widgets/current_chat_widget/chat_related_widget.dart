// ✅ NEW: Build metadata row with star, timestamp, and status
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/group/provider/group_provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class ChatRelatedWidget {
  static Widget buildMetadataRow({
    required BuildContext context,
    required chats.Records chat,
    required bool isStarred,
    required bool isSentByMe,
    VoidCallback? onRetry, // ✅ NEW: Retry callback for failed messages
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Pinned indicator (only show if pinned and not starred)
        if (chat.pinned == true) ...[
          SvgPicture.asset(
            AppAssets.pinMessageIcon,
            height: 13,
            color: isSentByMe
                ? AppColors.appPriSecColor.primaryColor
                : AppColors.textColor.textGreyColor,
          ),
          SizedBox(width: SizeConfig.width(1)),
        ],

        // Star indicator (only show if starred)
        if (isStarred) ...[
          Padding(
            padding: SizeConfig.getPaddingOnly(bottom: 2),
            child: Icon(
              Icons.star,
              size: 12,
              color: AppColors.appPriSecColor.primaryColor,
            ),
          ),
          SizedBox(width: SizeConfig.width(1)),
        ],

        if (isSentByMe) ...[
          buildMessageStatus(
            context: context,
            chat: chat,
            isStarred: isStarred,
            isSentByMe: isSentByMe,
            onRetry: onRetry, // ✅ NEW: Pass retry callback
          ),
          SizedBox(width: SizeConfig.width(1)),
        ],

        // Timestamp — prefixed "Edited · " once the sender edited the body.
        // Still the original `createdAt`; deleted-for-everyone hides it.
        Text(
          chat.isEdited == true && chat.deletedForEveryone != true
              ? '${AppString.edited} · ${_formatTime(chat.createdAt)}'
              : _formatTime(chat.createdAt),
          style: TextStyle(
            fontSize: 11,
            height: 1.1,
            color: Fp.textFaint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ✅ Message status indicators
  // ✅ UPDATED: Now supports optimistic UI states (sending, sent, failed)
  static Widget buildMessageStatus({
    required BuildContext context,
    required chats.Records chat,
    required bool isStarred,
    required bool isSentByMe,
    VoidCallback? onRetry, // ✅ NEW: Retry callback for failed messages
  }) {
    // ✅ NEW: Check for optimistic UI sendingStatus first
    final sendingStatus = chat.sendingStatus;

    if (sendingStatus != null) {
      switch (sendingStatus) {
        case chats.MessageSendingStatus.sending:
          // Show small loading indicator
          return SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.textColor.textDarkGray,
              ),
            ),
          );

        case chats.MessageSendingStatus.failed:
          // Show red error icon with retry
          return GestureDetector(
            onTap: onRetry,
            child: Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: 14,
            ),
          );

        case chats.MessageSendingStatus.sent:
          // Fall through to regular status handling
          break;
      }
    }

    IconData statusIcon = Icons.schedule;
    Color iconColor = AppColors.textColor.textDarkGray;

    switch (chat.messageSeenStatus?.toLowerCase()) {
      case 'read':
      case 'seen':
        statusIcon = Icons.done_all; // Double tick
        iconColor = Fp.tickRead; // Blue when read
        break;
      case 'sent':
        statusIcon = Icons.done; // Single tick: server accepted only
        iconColor = AppColors.textColor.textDarkGray; // Grey when sent
        break;
      case 'pending':
      default:
        statusIcon = Icons.schedule;
        iconColor = AppColors.textColor.textDarkGray;
        break;
    }

    return Icon(statusIcon, color: iconColor, size: 12);
  }

  // ✅ Helper: Format timestamp
  static String _formatTime(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final localDateTime = dateTime.toLocal(); // Convert to local time
      return DateFormat.jm().format(localDateTime); // e.g., 12:30 PM
    } catch (e) {
      return '';
    }
  }

  // String _formatTime(String? timestamp) {
  //   if (timestamp == null) return '';

  //   try {
  //     final dateTime = DateTime.parse(timestamp);
  //     final now = DateTime.now();

  //     if (dateTime.day == now.day &&
  //         dateTime.month == now.month &&
  //         dateTime.year == now.year) {
  //       return DateFormat.jm().format(
  //         dateTime,
  //       ); //'${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  //     } else {
  //       return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  //     }
  //   } catch (e) {
  //     return '';
  //   }
  // }

  // ✅ Build text preview
  static Widget buildTextPreview({
    required BuildContext context,
    required String content,
    required bool isSentByMe,
  }) {
    return Text(
      content,
      style: AppTypography.captionText(context)
          .copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ✅ Build text preview
  static Widget buildLinkPreview({
    required BuildContext context,
    required String content,
    required bool isSentByMe,
  }) {
    return Text(
      content,
      style: AppTypography.captionText(context)
          .copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  static Widget buildPollPreview({
    required BuildContext context,
    required String content,
    required bool isSentByMe,
  }) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.pollIcon,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: content,
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build image preview
  static Widget buildImagePreview({
    required BuildContext context,
    required String imageUrl,
    required bool isSentByMe,
  }) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.galleryMsg,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: AppString.photo,
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build voice preview
  static Widget buildVoicePreview({
    required BuildContext context,
    required bool isSentByMe,
  }) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.voiceMic,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: AppString.voiceMessage,
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build gif preview
  static Widget buildGifPreview({
    required BuildContext context,
    required String imageUrl,
    required bool isSentByMe,
  }) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.galleryMsg,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: AppString.gifTitleCase,
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build video preview
  static Widget buildVideoPreview({
    required BuildContext context,
    required String videoUrl,
    String? thumbnailUrl,
    required bool isSentByMe,
  }) {
    // final displayThumbnail = thumbnailUrl ?? videoUrl;

    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.videoMsg,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: "Video",
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build document preview
  static Widget buildDocumentPreview(BuildContext context, bool isSentByMe) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.documentMsg,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: AppString.document,
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build location preview
  static Widget buildLocationPreview(BuildContext context, bool isSentByMe) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.locationMsg,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: AppString.location,
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build contact preview
  static Widget buildContactPreview(BuildContext context, bool isSentByMe) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.contactMsg,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: AppString.contact,
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // NEW's reply payload only carries the parent's `sender_id` — the
  // synthesized `parentMessage` (MessageAdapter.attachParentMessages) has no
  // `User` object — so every other member's reply preview used to read
  // "User". Resolve the name from what the chat screen already has loaded:
  // the open group's member list, or the 1:1 peer on the chat-list row.
  static String getSenderName(
    BuildContext context,
    Map<String, dynamic> parentMessage,
    String currentUserId,
  ) {
    final rawSenderId = parentMessage['sender_id'];
    if (rawSenderId != null && rawSenderId.toString() == currentUserId) {
      return 'You';
    }
    final senderId = int.tryParse('${rawSenderId ?? ''}');

    String? fullName;
    String? userName;
    final userData = parentMessage['User'];
    if (userData is Map) {
      fullName = userData['full_name'] as String?;
      userName = userData['user_name'] as String?;
    }

    if (senderId != null && fullName == null && userName == null) {
      try {
        final member = Provider.of<GroupProvider>(
          context,
          listen: false,
        ).getMemberByUserId(senderId);
        fullName = member?.user?.fullName;
        userName = member?.user?.userName;
      } catch (_) {
        // GroupProvider not in scope for this chat — ignore.
      }
    }

    if (senderId != null && fullName == null && userName == null) {
      try {
        final chatList = Provider.of<ChatProvider>(
          context,
          listen: false,
        ).chatListData;
        for (final chat in chatList.chats) {
          final peer = chat.peerUserData;
          if (peer?.userId == senderId) {
            fullName = peer!.fullName;
            userName = peer.userName;
            break;
          }
        }
      } catch (_) {
        // ChatProvider not in scope — ignore.
      }
    }

    // Saved contact name still wins, same as the group sender header.
    return ContactNameService.instance.resolveName(
      userId: senderId,
      fullName: fullName,
      userName: userName,
      fallback: 'User',
    );
  }
}
