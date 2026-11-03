import 'dart:math';
import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
import 'package:whoxa/featuers/chat/widgets/video_thumbnail_view.dart';
import 'package:whoxa/featuers/story/data/model/get_all_story_model.dart';
import 'package:whoxa/featuers/story/provider/story_provider.dart';
import 'package:whoxa/featuers/story/screens/my_story_view.dart';
import 'package:whoxa/featuers/story/screens/story_view.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/main.dart';
import 'package:whoxa/widgets/global.dart';

class StoryReplyMessageWidget extends StatelessWidget {
  /// Key of the bubble whose tap is currently fetching the story lists —
  /// drives the spinner on that bubble's thumbnail and blocks repeated taps
  /// from firing parallel fetches. Null when idle.
  static final ValueNotifier<String?> _resolvingStoryKey =
      ValueNotifier<String?>(null);

  String get _storyResolveKey =>
      chat.messageId?.toString() ?? 'story_${chat.story?.storyId}';

  final chats.Records chat;
  final String currentUserId;
  final bool isStarred; // ✅ NEW: Star status parameter
  final Function(int)? onReplyTap; // ✅ NEW: Callback for reply tap
  final bool openedFromStarred; // If Opened from the Starred Messages Screen
  final bool isForPinned;

  const StoryReplyMessageWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
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

    final messageText = chat.messageContent ?? '';
    final parentText = chat.parentMessage?['message_content'] ?? '';
    final senderName = ChatRelatedWidget.getSenderName(
      context,
      chat.parentMessage ?? {},
      currentUserId,
    );
    final messageType = chat.messageType ?? 'story_reply';
    final parentType = chat.parentMessage?['message_type'] ?? 'story_reply';

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
      'story_reply',
    );

    final totalBubbleWidth = min(
      SizeConfig.width(70),
      max(max(messageWidth, parentWidth), senderNameWidth) + 30,
    ); // 30 for padding
    final bool hasStory = chat.story != null && chat.story!.storyId != null;

    if (hasStory) {
      logger.v("Story ID: ${chat.story!.storyId}");
      logger.v("Story Media: ${chat.story!.media}");
      logger.v("Story Thumbnail: ${chat.story!.thumbnail}");
      logger.v("Story Type: ${chat.story!.storyType}");
      logger.v("Story Caption: ${chat.story!.caption}");
      logger.v("Story expiresAt: ${chat.story!.expiresAt}");
      logger.v("Story isExpired: ${chat.story!.isExpired}");
      logger.v("Story userName: ${chat.story!.user?.userName}");
      logger.v("Story userName: ${chat.story!.user?.fullName}");
      logger.v("Story userId: ${chat.story!.user?.userId}");
    }

    Map<String, int>? findStoryInRecent({
      required String storyId,
      required List<RecentStories> recentStories,
    }) {
      for (int userIndex = 0; userIndex < recentStories.length; userIndex++) {
        final stories = recentStories[userIndex].stories ?? [];
        for (int storyIndex = 0; storyIndex < stories.length; storyIndex++) {
          if (stories[storyIndex].storyId.toString() == storyId) {
            return {'userIndex': userIndex, 'storyIndex': storyIndex};
          }
        }
      }
      return null;
    }

    Map<String, int>? findStoryInViewed({
      required String storyId,
      required List<ViewedStories> viewedStories,
    }) {
      for (int userIndex = 0; userIndex < viewedStories.length; userIndex++) {
        final stories = viewedStories[userIndex].stories ?? [];
        for (int storyIndex = 0; storyIndex < stories.length; storyIndex++) {
          if (stories[storyIndex].storyId.toString() == storyId) {
            return {'userIndex': userIndex, 'storyIndex': storyIndex};
          }
        }
      }
      return null;
    }

    Map<String, int>? findStoryOwn({
      required String storyId,
      required List<MyStories> myStories,
    }) {
      for (int userIndex = 0; userIndex < myStories.length; userIndex++) {
        for (int storyIndex = 0; storyIndex < myStories.length; storyIndex++) {
          if (myStories[storyIndex].storyId.toString() == storyId) {
            return {'userIndex': userIndex, 'storyIndex': storyIndex};
          }
        }
      }
      return null;
    }

    return Column(
      crossAxisAlignment:
          openedFromStarred
              ? CrossAxisAlignment.start
              : isSentByMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth:
                hasParentMessage
                    ? totalBubbleWidth
                    : SizeConfig.screenWidth * 0.7,
          ),
          decoration: BoxDecoration(
            color:
                isSentByMe
                    ? (Fp.dark ? Fp.violet.withValues(alpha: 0.32) : const Color(0xFFEDE6FF))
                    : AppThemeManage.appTheme.chatOppoColor,
            borderRadius:
                openedFromStarred
                    ? BorderRadius.circular(hasParentMessage ? 9 : 12)
                    : AppDirectionality.appDirectionBorderRadius
                        .chatBubbleRadius(
                          isSentByMe: isSentByMe,
                          hasParentMessage: hasParentMessage,
                        ),
          ),
          child: Padding(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: hasParentMessage ? 3 : 5,
              vertical: hasParentMessage ? 3 : 5,
            ),
            child: Column(
              crossAxisAlignment:
                  isSentByMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ ENHANCED: Show parent message if this is a reply
                if (hasParentMessage) ...[
                  _buildParentMessagePreview(
                    context,
                    isSentByMe,
                    totalBubbleWidth,
                  ),
                  SizedBox(height: 8),
                ],
                hasParentMessage
                    ? SizedBox.shrink()
                    : InkWell(
                      onTap: () async {
                        // 1️⃣ If story itself is null
                        if (chat.story == null || chat.story!.storyId == null) {
                          snackbarNew(
                            context,
                            msg: "This story is no longer available",
                          );
                          return;
                        }
                        if (_resolvingStoryKey.value != null) return;
                        final storyProvider = Provider.of<StoryProvider>(
                          context,
                          listen: false,
                        );

                        final String storyId = chat.story!.storyId.toString();
                        final String storyUserId =
                            chat.story!.user!.userId.toString();
                        final bool isMyStory = storyUserId == currentUserId;

                        bool isCached() =>
                            isMyStory
                                ? findStoryOwn(
                                      storyId: storyId,
                                      myStories: storyProvider.getMyStories,
                                    ) !=
                                    null
                                : findStoryInRecent(
                                          storyId: storyId,
                                          recentStories:
                                              storyProvider.getRecentStoryList,
                                        ) !=
                                        null ||
                                    findStoryInViewed(
                                          storyId: storyId,
                                          viewedStories:
                                              storyProvider.getViewedStoryList,
                                        ) !=
                                        null;

                        // The story lists are only filled once the Status tab
                        // (or a story screen) has loaded them — opening a chat
                        // straight after app launch leaves them empty. Fetch
                        // once before concluding the story is gone.
                        if (!isCached()) {
                          _resolvingStoryKey.value = _storyResolveKey;
                          try {
                            await storyProvider.getAllStories();
                          } finally {
                            _resolvingStoryKey.value = null;
                          }
                          if (!context.mounted) return;
                        }

                        Map<String, int>? storyLocation;
                        if (isMyStory) {
                          // My own story
                          storyLocation = findStoryOwn(
                            storyId: storyId,
                            myStories: storyProvider.getMyStories,
                          );

                          if (storyLocation == null) {
                            snackbarNew(
                              context,
                              msg: "This story is no longer available",
                            );
                            return;
                          }

                          logger.v("Story Navigate to MY story");

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => MyStoriesView(
                                    isMyStory: true,
                                    initialIndex: storyLocation!['userIndex']!,
                                    initialStoryIndex:
                                        storyLocation['storyIndex']!,
                                  ),
                            ),
                          );
                        } else {
                          // Someone else's story
                          bool foundInRecent = false;

                          // First: Check Recent Stories
                          storyLocation = findStoryInRecent(
                            storyId: storyId,
                            recentStories: storyProvider.getRecentStoryList,
                          );

                          if (storyLocation != null) {
                            foundInRecent = true;
                          } else {
                            // Second: Check Viewed Stories
                            storyLocation = findStoryInViewed(
                              storyId: storyId,
                              viewedStories: storyProvider.getViewedStoryList,
                            );
                          }

                          if (storyLocation == null) {
                            snackbarNew(
                              context,
                              msg: "This story is no longer available",
                            );
                            return;
                          }

                          // Log only the correct one
                          logger.v(
                            foundInRecent
                                ? "Story Navigate to RECENT story"
                                : "Story Navigate to VIEWED story",
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => StoriesView(
                                    isMyStory: false,
                                    recentStories:
                                        foundInRecent
                                            ? storyProvider.getRecentStoryList
                                            : [],
                                    viewedStories:
                                        foundInRecent
                                            ? []
                                            : storyProvider.getViewedStoryList,
                                    initialIndex: storyLocation!['userIndex']!,
                                    initialStoryIndex:
                                        storyLocation['storyIndex']!,
                                    isRecentStoryView: foundInRecent,
                                  ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppThemeManage.appTheme.darkGreyColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${chat.user!.fullName} • Status",
                                      style: AppTypography.innerText14(
                                        context,
                                      ).copyWith(
                                        fontFamily:
                                            AppTypography
                                                .fontFamily
                                                .poppinsMedium,
                                      ),
                                    ),
                                    SizedBox(height: SizeConfig.height(0.5)),
                                    chat.story != null
                                        ? rowMessageType(
                                          context,
                                          chat.story!.storyType!,
                                        )
                                        : Row(
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              color:
                                                  AppColors
                                                      .textColor
                                                      .textDarkGray,
                                              size: 17,
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              AppString.storyUnavailable,
                                              style: AppTypography.innerText11(
                                                context,
                                              ).copyWith(
                                                color:
                                                    AppColors
                                                        .textColor
                                                        .textDarkGray,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                  ],
                                ),
                              ),
                              Container(
                                height: SizeConfig.sizedBoxHeight(55),
                                width: SizeConfig.sizedBoxWidth(55),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: AppThemeManage.appTheme.borderColor,
                                  ),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child:
                                          chat.story != null
                                              ? chat.story!.storyType == "video"
                                                  // Backend poster when the reply
                                                  // carried one, else a frame
                                                  // pulled from the video itself.
                                                  ? VideoThumbnailView(
                                                    videoUrl:
                                                        chat.story!.media ?? '',
                                                    backendThumbnailUrl:
                                                        chat.story!.thumbnail,
                                                    fit: BoxFit.cover,
                                                    placeholderBuilder:
                                                        (
                                                          context,
                                                          loading,
                                                        ) => Center(
                                                          child:
                                                              loading
                                                                  ? const SizedBox(
                                                                    width: 18,
                                                                    height: 18,
                                                                    child: CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                    ),
                                                                  )
                                                                  : Icon(
                                                                    Icons
                                                                        .videocam,
                                                                    color:
                                                                        AppColors
                                                                            .textColor
                                                                            .textGreyColor,
                                                                  ),
                                                        ),
                                                  )
                                                  : Image.network(
                                                    chat.story!.media!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Center(
                                                        child: Icon(
                                                          Icons.error_outline,
                                                          color:
                                                              AppColors
                                                                  .textColor
                                                                  .textGreyColor,
                                                        ),
                                                      );
                                                    },
                                                  )
                                              : Center(
                                                child: Icon(
                                                  Icons.error_outline,
                                                  color:
                                                      AppColors
                                                          .textColor
                                                          .textGreyColor,
                                                ),
                                              ),
                                    ),
                                    // Spinner while this bubble's tap fetches
                                    // the story lists (cold start → chat).
                                    ValueListenableBuilder<String?>(
                                      valueListenable: _resolvingStoryKey,
                                      builder:
                                          (context, resolvingKey, _) =>
                                              resolvingKey == _storyResolveKey
                                                  ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          7,
                                                        ),
                                                    child: ColoredBox(
                                                      color: Colors.black38,
                                                      child: Center(
                                                        child: SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                hasParentMessage
                    ? SizedBox.shrink()
                    : SizedBox(height: SizeConfig.height(0.5)),
                // Main message content
                Padding(
                  padding: SizeConfig.getPaddingOnly(
                    left: 10,
                    right: 8,
                    bottom: 5,
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
        if (!openedFromStarred)
          ChatRelatedWidget.buildMetadataRow(
            context: context,
            chat: chat,
            isStarred: isStarred,
            isSentByMe: isSentByMe,
          ),
        if (!openedFromStarred) SizedBox(height: SizeConfig.height(0)),
      ],
    );
  }

  // ✅ ENHANCED: Build parent message preview with media support and tap functionality
  Widget _buildParentMessagePreview(
    BuildContext context,
    bool isSentByMe,
    double width,
  ) {
    final parentMessage = chat.parentMessage!;
    final parentContent = parentMessage['message_content'] ?? 'Message';
    final parentType = parentMessage['message_type'] ?? 'story_reply';
    final parentThumbnail = parentMessage['message_thumbnail'];
    final parentMessageId = parentMessage['message_id'];

    return GestureDetector(
      onTap: () {
        // ✅ NEW: Handle tap to navigate to original message
        if (onReplyTap != null && parentMessageId != null) {
          onReplyTap!(parentMessageId as int);
        }
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Container(
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
              SizedBox(height: 1),

              // ✅ Media preview or text content
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
      ),
    );
  }

  // ✅ Build parent message content based on type
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
      case 'story_reply':
      default:
        return ChatRelatedWidget.buildTextPreview(
          context: context,
          content: content,
          isSentByMe: isSentByMe,
        );
    }
  }

  Widget rowMessageType(BuildContext context, String messageType) {
    return Row(
      children: [
        messageContentIcon(context, messageType: messageType),
        SizedBox(width: 5),
        Text(
          textMessageContent(context, messageType: messageType.toLowerCase()),
          style: AppTypography.innerText11(
            context,
          ).copyWith(color: AppColors.textColor.textDarkGray),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget messageContentIcon(
    BuildContext context, {
    required String messageType,
  }) {
    switch (messageType.toLowerCase()) {
      case 'image':
        return SvgPicture.asset(
          AppAssets.chatMsgTypeIcon.galleryMsg,
          colorFilter: ColorFilter.mode(
            AppColors.textColor.textDarkGray,
            BlendMode.srcIn,
          ),
          height: SizeConfig.sizedBoxHeight(14),
        );
      case 'video':
        return SvgPicture.asset(
          AppAssets.chatMsgTypeIcon.videoMsg,
          colorFilter: ColorFilter.mode(
            AppColors.textColor.textDarkGray,
            BlendMode.srcIn,
          ),
          height: SizeConfig.sizedBoxHeight(14),
        );
      default:
        return SizedBox.shrink();
    }
  }

  String textMessageContent(
    BuildContext context, {
    required String messageType,
  }) {
    switch (messageType.toLowerCase()) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      default:
        return 'Story Reply';
    }
  }

  double _calculateTextWidth1(
    BuildContext context,
    String messageContent,
    String messageType,
  ) {
    String displayText;

    switch (messageType.toLowerCase()) {
      case 'poll':
      case 'link':
      case 'text':
        displayText = messageContent;
        break;
      case 'story_reply':
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
