// Enhanced PinnedMessagesWidget with search integration and visual feedback

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/contact_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/delete_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/document_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/gif_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/image_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/link_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/location_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/video_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/voice_message_widget.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/avatar_initials.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/chat/group/provider/group_provider.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';

class PinnedMessagesWidget extends StatelessWidget {
  final ChatProvider chatProvider;
  final ScrollController scrollController;
  final Function(int messageId) onMessageTap;
  final Function(chats.Records message) onUnpinMessage;
  final String currentUserId;
  final List<chats.Records> pinnedMessages;
  final bool isExpanded;
  final VoidCallback onToggleExpansion;

  const PinnedMessagesWidget({
    super.key,
    required this.chatProvider,
    required this.scrollController,
    required this.onMessageTap,
    required this.onUnpinMessage,
    required this.currentUserId,
    required this.pinnedMessages,
    required this.isExpanded,
    required this.onToggleExpansion,
  });

  @override
  Widget build(BuildContext context) {
    if (pinnedMessages.isEmpty) {
      return SizedBox.shrink();
    }

    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppThemeManage.appTheme.appSndColor3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.appPriSecColor.primaryColor,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ ENHANCED: Header with search indicator
              _buildHeader(context, chatProvider),

              // Pinned messages list
              if (isExpanded) ...[
                Divider(
                  height: 1,
                  color: AppColors.appPriSecColor.primaryColor,
                ),
                _buildPinnedMessagesList(context, chatProvider),
              ],
            ],
          ),
        );
      },
    );
  }

  // ✅ ENHANCED: Header with search status
  Widget _buildHeader(BuildContext context, ChatProvider chatProvider) {
    final isSearching = chatProvider.isSearchingForMessage;

    return InkWell(
      onTap: onToggleExpansion,
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ✅ ANIMATED: Pin icon with search indicator
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child:
                  isSearching
                      ? SizedBox(width: 18, height: 18, child: commonLoading())
                      : Transform.rotate(
                        angle: math.pi / 4,
                        child: SvgPicture.asset(
                          AppAssets.pinMessageIcon,
                          height: 23,
                          colorFilter: ColorFilter.mode(
                            AppThemeManage.appTheme.darkWhiteColor,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
            ),
            SizedBox(width: 12),

            // ✅ ENHANCED: Title with search status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pinnedMessages.length} ${AppString.homeScreenString.pinnedMessage}${pinnedMessages.length > 1 ? 's' : ''}',
                    style: AppTypography.innerText12Mediu(context)
                        .copyWith(fontWeight: FontWeight.w600)
                        .copyWith(
                          color: AppThemeManage.appTheme.darkWhiteColor,
                        ),
                  ),

                  // ✅ NEW: Search status indicator
                  if (isSearching) ...[
                    SizedBox(height: 2),
                    Text(
                      AppString.searchingForMessageDots,
                      style: AppTypography.captionText(context).copyWith(
                        color: AppColors.appPriSecColor.primaryColor.withValues(
                          alpha: 0.8,
                        ),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ✅ ENHANCED: Expand/collapse icon
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: Duration(milliseconds: 300),
              child: Icon(
                Icons.expand_more,
                color: AppThemeManage.appTheme.darkWhiteColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ ENHANCED: Pinned messages list with search highlighting
  Widget _buildPinnedMessagesList(
    BuildContext context,
    ChatProvider chatProvider,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: SizeConfig.height(40)),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(vertical: 8),
        itemCount: pinnedMessages.length,
        separatorBuilder:
            (context, index) =>
                Divider(color: AppColors.appPriSecColor.primaryColor),
        itemBuilder: (context, index) {
          final message = pinnedMessages[index];
          return _buildPinnedMessageItem(context, message, chatProvider);
        },
      ),
    );
  }

  // Resolves the sender's display name for a pinned message.
  //
  // The NEW backend's `/pins` payload doesn't embed a `User` object (and,
  // on older builds, not even a sender id), so relying on `message.user`
  // alone rendered every pinned row as "Unknown User". Walk the identity
  // sources the rest of the chat screen uses, in order of reliability, and
  // only fall back to a generic label when the sender genuinely can't be
  // resolved.
  String _resolveSenderName(BuildContext context, chats.Records message) {
    final user = message.user;
    if (user != null) {
      final fromRecord = _firstNonEmpty([user.fullName, user.userName]);
      if (fromRecord != null) return fromRecord;
    }

    final senderId = message.senderId;
    if (senderId == null) return 'User';

    if (senderId.toString() == currentUserId) return 'You';

    // Direct chats: the peer's identity lives on the chat-list entry.
    for (final chat in chatProvider.chatListData.chats) {
      final peer = chat.peerUserData;
      if (peer?.userId == senderId) {
        final name = _firstNonEmpty([peer!.fullName, peer.userName]);
        if (name != null) return name;
      }
    }

    // Group chats: resolve against the loaded member list.
    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      for (final member in groupProvider.members) {
        if (member.userId == senderId) {
          final name = _firstNonEmpty([
            member.user?.fullName,
            member.user?.userName,
          ]);
          if (name != null) return name;
        }
      }
    } catch (_) {
      // GroupProvider not in scope for this chat — ignore.
    }

    // Backend-managed contact name / cached server name.
    final configProvider = Provider.of<ProjectConfigProvider>(
      context,
      listen: false,
    );
    final resolved = ContactNameService.instance.getDisplayNameStable(
      userId: senderId,
      configProvider: configProvider,
      contextFullName: message.peerUserData?.fullName,
      firstName: message.peerUserData?.firstName,
      lastName: message.peerUserData?.lastName,
    );
    if (resolved.isNotEmpty && resolved != 'Unknown User') return resolved;

    return 'User';
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  // ✅ ENHANCED: Pinned message item with search indicators
  Widget _buildPinnedMessageItem(
    BuildContext context,
    chats.Records message,
    ChatProvider chatProvider,
  ) {
    final isSentByMe =
        message.senderId != null &&
        message.senderId.toString() == currentUserId;
    final senderName = _resolveSenderName(context, message);

    // ✅ NEW: Check if this message is being searched or highlighted
    final isSearchTarget = chatProvider.targetMessageId == message.messageId;
    final isHighlighted =
        chatProvider.highlightedMessageId == message.messageId;
    final isSearching = chatProvider.isSearchingForMessage && isSearchTarget;

    // ✅ NEW: Dynamic styling based on search state
    Color backgroundColor = Colors.transparent;
    Border? border;

    if (isHighlighted) {
      backgroundColor = AppColors.appPriSecColor.primaryColor.withValues(
        alpha: 0.2,
      );
      border = Border.all(
        color: AppColors.appPriSecColor.primaryColor,
        width: 2,
      );
    } else if (isSearching) {
      backgroundColor = AppColors.appPriSecColor.secondaryColor.withValues(
        alpha: 0.1,
      );
      border = Border.all(
        color: AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.5),
        width: 1,
      );
    }

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
      child: InkWell(
        onTap: () {
          if (message.messageId != null && !isSearching) {
            onMessageTap(message.messageId!);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ ENHANCED: Sender avatar with search indicator
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: AppColors.appPriSecColor.primaryColor
                            .withValues(alpha: 0.2),
                        backgroundImage:
                            message.user?.profilePic != null
                                ? NetworkImage(message.user!.profilePic!)
                                : null,
                        child:
                            message.user?.profilePic == null
                                ? Text(
                                  avatarInitials(senderName),
                                  style: TextStyle(
                                    color:
                                        AppColors.appPriSecColor.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                                : null,
                      ),

                      // ✅ NEW: Search indicator overlay
                      // if (!isSearching)
                      //   Positioned(
                      //     right: 0,
                      //     top: 0,
                      //     child: Container(
                      //       width: 12,
                      //       height: 12,
                      //       decoration: BoxDecoration(
                      //         color: AppColors.appPriSecColor.secondaryColor,
                      //         shape: BoxShape.circle,
                      //         border: Border.all(color: Colors.white, width: 1),
                      //       ),
                      //       child: SizedBox(
                      //         width: 8,
                      //         height: 8,
                      //         child: CircularProgressIndicator(
                      //           strokeWidth: 1,
                      //           valueColor: AlwaysStoppedAnimation<Color>(
                      //             Colors.white,
                      //           ),
                      //         ),
                      //       ),
                      //     ),
                      //   ),
                    ],
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      isSentByMe ? 'You' : senderName,
                      style: AppTypography.textBoxUpperText12(context).copyWith(
                        color: AppColors.textColor.textBlackColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // ✅ ENHANCED: Unpin button (disabled during search)
                  Tooltip(
                    message: isSearching ? 'Please wait...' : 'Unpin message',
                    child: InkWell(
                      onTap:
                          isSearching
                              ? null
                              : () {
                                _showUnpinConfirmation(context, message);
                              },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15, bottom: 3),
                        child: SvgPicture.asset(
                          AppAssets.chatImage.unpinnedIcon,
                          height: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 5),
                  Text(
                    _formatPinnedMessageTime(message.createdAt),
                    style: AppTypography.captionText(context).copyWith(
                      color: AppColors.textColor.textGreyColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // ✅ ENHANCED: Message content with search highlighting
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message content
                    _buildMessageContent(context, message),

                    // Message type indicator
                    if (_getMessageTypeIndicator(message).isNotEmpty) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          // ✅ NEW: Highlight indicator for found messages
                          if (isHighlighted) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.appPriSecColor.primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                AppString.found,
                                style: AppTypography.captionText(
                                  context,
                                ).copyWith(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ ENHANCED: Build message content with better error handling
  Widget _buildMessageContent(BuildContext context, chats.Records message) {
    final messageType = message.messageType?.toLowerCase() ?? 'text';
    final content = message.messageContent ?? '';

    // Check if message is deleted for everyone
    if (message.deletedForEveryone == true) {
      return DeletedMessageWidget(chat: message, currentUserId: currentUserId);
    }

    switch (messageType) {
      case 'text':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.isNotEmpty) ...[
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: AppColors.bgColor.bgWhite,
                  ),
                  padding: SizeConfig.getPadding(10),
                  width: double.infinity,
                  child: SelectableText(
                    content.isNotEmpty ? content : AppString.textMessage,
                    style: AppTypography.innerText10(context).copyWith(
                      color: AppColors.textColor.textBlackColor,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
              ),
            ],
          ],
        );

      case 'poll':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.isNotEmpty) ...[
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: AppColors.bgColor.bgWhite,
                  ),
                  padding: SizeConfig.getPadding(10),
                  width: double.infinity,
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        AppAssets.chatMsgTypeIcon.pollIcon,
                        height: 14,
                        colorFilter: ColorFilter.mode(
                          AppColors.textColor.textDarkGray,
                          BlendMode.srcIn,
                        ),
                      ),
                      SizedBox(width: 5),
                      SelectableText(
                        content.isNotEmpty ? content : AppString.pollMessage,
                        style: AppTypography.innerText10(context).copyWith(
                          color: AppColors.textColor.textBlackColor,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );

      case 'link':
        return Padding(
          padding: SizeConfig.getPaddingOnly(left: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.isNotEmpty) ...[
                IgnorePointer(
                  child: LinkMessageWidget(
                    chat: message,
                    currentUserId: currentUserId,
                    isForPinned: true,
                  ),
                ),
              ],
            ],
          ),
        );

      case 'voice':
        return Padding(
          padding: SizeConfig.getPaddingOnly(left: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.isNotEmpty) ...[
                IgnorePointer(
                  child: VoiceMessageWidget(
                    chat: message,
                    currentUserId: currentUserId,
                    isForPinned: true,
                  ),
                ),
              ],
            ],
          ),
        );

      case 'image':
        return Padding(
          padding: SizeConfig.getPaddingOnly(left: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.isNotEmpty) ...[
                IgnorePointer(
                  child: ImageMessageWidget(
                    chat: message,
                    currentUserId: currentUserId,
                    isForPinned: true,
                  ),
                ),
              ],
            ],
          ),
        );

      case 'video':
        return Padding(
          padding: SizeConfig.getPaddingOnly(left: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.isNotEmpty) ...[
                IgnorePointer(
                  child: VideoMessageWidget(
                    chat: message,
                    currentUserId: currentUserId,
                    thumbnailUrl: message.messageThumbnail,
                    isForPinned: true,
                  ),
                ),
              ],
            ],
          ),
        );

      case 'file':
      case 'document':
      case 'doc':
      case 'pdf':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.isNotEmpty) ...[
              IgnorePointer(
                child: DocumentMessageWidget(
                  chat: message,
                  currentUserId: currentUserId,
                  chatProvider: chatProvider,
                  isForPinned: true,
                ),
              ),
            ],
          ],
        );

      case 'location':
        return Padding(
          padding: SizeConfig.getPaddingOnly(left: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.isNotEmpty) ...[
                IgnorePointer(
                  child: LocationMessageWidget(
                    chat: message,
                    currentUserId: currentUserId,
                    latitude: _getLatitude(message),
                    longitude: _getLongitude(message),
                    isForPinned: true,
                  ),
                ),
              ],
            ],
          ),
        );

      case 'audio':
        return Row(
          children: [
            Icon(
              Icons.audio_file,
              color: AppColors.appPriSecColor.primaryColor,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              AppString.audioEmoji,
              style: AppTypography.mediumText(context).copyWith(
                color: AppColors.textColor.textBlackColor,
                fontSize: 13,
              ),
            ),
          ],
        );

      case 'gif':
        return Padding(
          padding: SizeConfig.getPaddingOnly(left: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.isNotEmpty) ...[
                IgnorePointer(
                  child: GifMessageWidget(
                    chat: message,
                    currentUserId: currentUserId,
                    isForPinned: true,
                  ),
                ),
              ],
            ],
          ),
        );

      case 'contact':
        return Padding(
          padding: SizeConfig.getPaddingOnly(left: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.isNotEmpty) ...[
                IgnorePointer(
                  child: ContactMessageWidget(
                    chat: message,
                    currentUserId: currentUserId,
                    isForPinned: true,
                  ),
                ),
              ],
            ],
          ),
        );

      default:
        return SelectableText(
          content.isNotEmpty ? content : AppString.message,
          style: AppTypography.mediumText(context).copyWith(
            color: AppColors.textColor.textBlackColor,
            fontSize: 13,
            height: 1.4,
          ),
          maxLines: 3,
        );
    }
  }

  // Get message type indicator
  String _getMessageTypeIndicator(chats.Records message) {
    final messageType = message.messageType?.toLowerCase() ?? 'text';
    switch (messageType) {
      case 'image':
        return 'Image';
      case 'video':
        return 'Video';
      case 'file':
      case 'document':
        return 'Document';
      case 'location':
        return 'Location';
      case 'audio':
        return 'Audio';
      case 'gif':
        return 'GIF';
      case 'contact':
        return 'Contact';
      case 'poll':
        return 'Poll';
      default:
        return '';
    }
  }

  // ✅ ENHANCED: Show unpin confirmation with better UX
  void _showUnpinConfirmation(BuildContext context, chats.Records message) {
    bottomSheetGobal(
      context,
      bottomsheetHeight: SizeConfig.sizedBoxHeight(240),
      borderRadius: BorderRadius.circular(20),
      title: AppString.homeScreenString.unpinMessage,
      // `bottomSheetGobal` puts this child inside an Expanded of a fixed-height
      // container. Let the text take the remaining space (scrolling if the
      // device/font makes it tight) and keep the button pinned to the bottom,
      // so it sits in the same place on every device and never overflows.
      child: Padding(
        padding: SizeConfig.getPaddingOnly(
          left: 20,
          right: 20,
          top: 16,
          bottom: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppString.homeScreenString.areYouSureYouWantToUnpin,
                      textAlign: TextAlign.start,
                      style: AppTypography.innerText16(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                      AppString
                          .homeScreenString
                          .itWillBeRemovedFromThePinnedMessages,
                      textAlign: TextAlign.start,
                      style: AppTypography.smallText(
                        context,
                      ).copyWith(color: AppColors.textColor.textGreyColor),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: SizeConfig.getPaddingSymmetric(horizontal: 35),
              child: SizedBox(
                height: 44,
                width: double.infinity,
                child: customBtn2(
                  context,
                  onTap: () {
                    Navigator.of(context).pop();
                    onUnpinMessage(message);
                  },
                  child: Text(
                    AppString.homeScreenString.unpin,
                    style: AppTypography.h5(context).copyWith(
                      fontWeight: FontWeight.w600,
                      // customBtn2 fills with the primary color; pick a text
                      // color that contrasts with it instead of a fixed black.
                      color: ThemeColorPalette.getTextColor(
                        AppColors.appPriSecColor.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Format timestamp for pinned messages
  String _formatPinnedMessageTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } else if (difference.inDays > 0) {
        return AppString.nDaysAgoShort('${difference.inDays}');
      } else if (difference.inHours > 0) {
        return AppString.nHoursAgoShort('${difference.inHours}');
      } else if (difference.inMinutes > 0) {
        return AppString.nMinutesAgoShort('${difference.inMinutes}');
      } else {
        return AppString.justNow;
      }
    } catch (e) {
      return '';
    }
  }

  double? _getLatitude(chats.Records message) {
    if (message.messageContent == null) return null;
    final coordinates = message.messageContent!.split(',');
    if (coordinates.isNotEmpty) {
      return double.tryParse(coordinates[0].trim());
    }
    return null;
  }

  double? _getLongitude(chats.Records message) {
    if (message.messageContent == null) return null;
    final coordinates = message.messageContent!.split(',');
    if (coordinates.length >= 2) {
      return double.tryParse(coordinates[1].trim());
    }
    return null;
  }
}
