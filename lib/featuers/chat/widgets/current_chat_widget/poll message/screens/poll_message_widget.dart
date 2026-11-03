import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/poll%20message/data/poll_model.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/poll%20message/screens/poll_details_screen.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/main.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class PollMessageWidget extends StatefulWidget {
  final chats.Records chat;
  final String currentUserId;
  final bool isStarred;
  final Function(int)? onReplyTap;
  final bool isForPinned;
  final Function(PollData updatedPoll)? onVote;
  final bool openedFromStarred;

  const PollMessageWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
    this.isStarred = false,
    this.onReplyTap,
    required this.isForPinned,
    this.onVote,
    this.openedFromStarred = false,
  });

  @override
  State<PollMessageWidget> createState() => _PollMessageWidgetState();
}

class _PollMessageWidgetState extends State<PollMessageWidget> {
  bool _isVoting = false;
  String? _votingOptionText;

  bool get isSentByMe =>
      widget.chat.senderId.toString() == widget.currentUserId;

  // ✅ Always get fresh poll data from widget
  PollData _buildPollData() {
    final apiPoll = widget.chat.pollData;

    // ✅ ADD THIS TEMPORARILY
    logger.v('=== POLL DEBUG ===');
    logger.v('isForPinned: ${widget.isForPinned}');
    logger.v('isStarred: ${widget.isStarred}');
    logger.v('apiPoll null: ${apiPoll == null}');
    logger.v('apiPoll.options: ${apiPoll?.options}');
    logger.v('apiPoll.options length: ${apiPoll?.options?.length}');
    logger.v('raw pollData type: ${widget.chat.pollData.runtimeType}');
    // ==================

    if (apiPoll == null) {
      return PollData(
        question: widget.chat.messageContent ?? '',
        options: [],
        allowMultipleVotes: false,
        createdBy: widget.chat.senderId.toString(),
        createdAt: DateTime.parse(
          widget.chat.createdAt ?? DateTime.now().toString(),
        ),
      );
    }

    // ✅ Guard: if options list is empty but question exists,
    // the fromJson likely failed silently — log it
    if (apiPoll.options == null || apiPoll.options!.isEmpty) {
      logger.w(
        'PollData has no options for pollId=${apiPoll.pollId}, '
        'raw options=${apiPoll.options}',
      );
    }

    return PollData.fromApiPollData(
      apiPoll: apiPoll,
      currentUserId: widget.currentUserId,
    );
  }

  Future<void> _onOptionTap(PollOption option, PollData currentPoll) async {
    if (_isVoting) return;

    final userId = widget.currentUserId;
    final alreadyVoted = option.hasVoted(userId);

    // ✅ Single vote: block re-tap on already voted option
    // ✅ Multiple votes: allow toggle (vote/unvote)
    if (alreadyVoted && !currentPoll.allowMultipleVotes) return;

    setState(() {
      _isVoting = true;
      _votingOptionText = option.text;
    });

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    // ✅ Print for debug
    logger.w(
      '🗳️ Option tapped: "${option.text}", '
      'alreadyVoted: $alreadyVoted, '
      'allowMultiple: ${currentPoll.allowMultipleVotes}, '
      'pollId: ${widget.chat.pollData?.pollId}',
    );

    // NEW wants opaque option ids, not text — see ChatProvider.votePoll's
    // doc comment for why this local `option.id` is only a best-effort
    // stand-in (it's a positional index, not a real server-assigned id).
    final success = await chatProvider.votePoll(widget.chat.pollData!.pollId!, [
      option.voteId,
    ]);

    logger.w('🗳️ Vote result: $success for option "${option.text}"');

    if (mounted) {
      setState(() {
        _isVoting = false;
        _votingOptionText = null;
      });
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chatProvider.errorMessage ?? 'Failed to vote. Try again.',
            ),
            backgroundColor: AppColors.appPriSecColor.secondaryRed,
          ),
        );
      }
    }
  }

  // NEW's poll payload only ever gives back bare voter user-ids (no name/
  // avatar) — resolve through the same contacts cache the rest of chat uses
  // instead of falling back to "?" for every voter but yourself.
  String _resolveVoterName(chats.Votes voter) {
    if (voter.userId.toString() == widget.currentUserId) return 'You';
    return ContactNameService.instance.getDisplayNameStable(
      userId: voter.userId,
      configProvider: Provider.of<ProjectConfigProvider>(
        context,
        listen: false,
      ),
      contextFullName:
          voter.fullName?.isNotEmpty == true ? voter.fullName : voter.userName,
    );
  }

  void _showVoteDetails(PollData poll) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => PollVoteDetailsSheet(
            poll: poll,
            currentUserId: widget.currentUserId,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final poll = _buildPollData();
    final hasParentMessage = widget.chat.parentMessage != null;
    final isSender = widget.chat.senderId.toString() == widget.currentUserId;
    final totalVotes = poll.totalVotes;

    return Column(
      crossAxisAlignment:
          widget.openedFromStarred
              ? CrossAxisAlignment.start
              : isSentByMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: SizeConfig.width(80)),
          decoration: BoxDecoration(
            color:
                isSentByMe
                    ? AppColors.appPriSecColor.secondaryColor
                    : AppThemeManage.appTheme.chatOppText,
            borderRadius:
                widget.openedFromStarred
                    ? BorderRadius.circular(12)
                    : AppDirectionality.appDirectionBorderRadius
                        .chatBubbleRadius(
                          isSentByMe: isSentByMe,
                          hasParentMessage: hasParentMessage,
                        ),
          ),
          child: Padding(
            padding: SizeConfig.getPaddingSymmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasParentMessage) ...[
                  widget.isForPinned
                      ? SizedBox.shrink()
                      : _buildParentMessagePreview(context, isSender),
                  widget.isForPinned ? SizedBox.shrink() : SizedBox(height: 3),
                ],
                // ── Question ──
                Padding(
                  padding: SizeConfig.getPaddingSymmetric(horizontal: 14),
                  child: Text(
                    poll.question,
                    style: AppTypography.innerText14(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color:
                          isSentByMe
                              ? ThemeColorPalette.getTextColor(
                                AppColors.appPriSecColor.primaryColor,
                              )
                              : AppThemeManage.appTheme.textColor,
                    ),
                  ),
                ),

                SizedBox(height: SizeConfig.height(1.5)),
                // ── Subtitle: Select one / Select one or more ──
                Padding(
                  padding: SizeConfig.getPaddingSymmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.loop_rounded,
                        size: 14,
                        color: (isSentByMe
                                ? ThemeColorPalette.getTextColor(
                                  AppColors.appPriSecColor.primaryColor,
                                )
                                : AppThemeManage.appTheme.textColor)
                            .withValues(alpha: 0.5),
                      ),
                      SizedBox(width: SizeConfig.width(1)),
                      Text(
                        poll.allowMultipleVotes
                            ? 'Select one or more'
                            : 'Select one',
                        style: AppTypography.captionText(context).copyWith(
                          color: (isSentByMe
                                  ? ThemeColorPalette.getTextColor(
                                    AppColors.appPriSecColor.primaryColor,
                                  )
                                  : AppThemeManage.appTheme.textColor)
                              .withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: SizeConfig.height(2)),
                // ── Options ──
                if (poll.options.isEmpty)
                  Padding(
                    padding: SizeConfig.getPaddingSymmetric(horizontal: 14),
                    child: Text(
                      poll.question.isNotEmpty
                          ? 'Loading options...' // question exists but options not mapped yet
                          : 'No options available',
                      style: AppTypography.captionText(
                        context,
                      ).copyWith(color: AppColors.textColor.textGreyColor),
                    ),
                  )
                else
                  ...poll.options.map(
                    (option) => _buildOptionTile(option, totalVotes, poll),
                  ),

                SizedBox(height: SizeConfig.height(1)),
                Divider(
                  height: 1,
                  color:
                      isSentByMe
                          ? AppThemeManage.appTheme.borderColor.withValues(
                            alpha: 0.5,
                          )
                          : AppThemeManage.appTheme.textWhiteBlack,
                ),
                SizedBox(height: SizeConfig.height(1)),

                // ── Footer: total votes + view votes ──
                Center(
                  child: GestureDetector(
                    onTap: totalVotes > 0 ? () => _showVoteDetails(poll) : null,
                    child: Text(
                      'View votes',
                      style: AppTypography.innerText14(context).copyWith(
                        color:
                            totalVotes > 0
                                ? isSentByMe
                                    ? ThemeColorPalette.getTextColor(
                                      AppColors.appPriSecColor.primaryColor,
                                    )
                                    : ThemeColorPalette.getTextColor(
                                      AppThemeManage.appTheme.chatOppText,
                                    )
                                : AppColors.textColor.textGreyColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: SizeConfig.height(1)),
        if (!widget.openedFromStarred)
          ChatRelatedWidget.buildMetadataRow(
            context: context,
            chat: widget.chat,
            isStarred: widget.isStarred,
            isSentByMe: isSentByMe,
          ),
      ],
    );
  }

  Widget _buildOptionTile(PollOption option, int totalVotes, PollData poll) {
    final hasVoted = option.hasVoted(widget.currentUserId);
    final userVotedAny = poll.options.any(
      (o) => o.hasVoted(widget.currentUserId),
    );
    final percent = totalVotes == 0 ? 0.0 : option.voteCount / totalVotes;

    final isThisOptionLoading = _isVoting && _votingOptionText == option.text;

    return Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 14),
      child: InkWell(
        onTap: _isVoting ? null : () => _onOptionTap(option, poll),
        child: Padding(
          padding: SizeConfig.getPaddingOnly(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Option row: circle/check + text + avatar + count ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ Circle or checkmark
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: 200),
                    child:
                        isThisOptionLoading
                            // ✅ Show small circular loader on tapped option
                            ? SizedBox(
                              key: ValueKey('loading_${option.id}'),
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isSentByMe
                                      ? ThemeColorPalette.getTextColor(
                                        AppColors.appPriSecColor.primaryColor,
                                      )
                                      : AppColors.appPriSecColor.primaryColor,
                                ),
                              ),
                            )
                            : hasVoted
                            ? Container(
                              key: ValueKey('checked_${option.id}'),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    isSentByMe
                                        ? ThemeColorPalette.getTextColor(
                                          AppColors.appPriSecColor.primaryColor,
                                        )
                                        : ThemeColorPalette.getTextColor(
                                          AppThemeManage.appTheme.chatOppText,
                                        ),
                              ),
                              child: Icon(
                                Icons.check,
                                color:
                                    isSentByMe
                                        ? AppColors.appPriSecColor.primaryColor
                                        : AppThemeManage.appTheme.chatOppText,
                                size: 12,
                              ),
                            )
                            : Container(
                              key: ValueKey('unchecked_${option.id}'),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      isSentByMe
                                          ? ThemeColorPalette.getTextColor(
                                            AppColors
                                                .appPriSecColor
                                                .primaryColor,
                                          ).withValues(alpha: 0.6)
                                          : AppColors.textColor.textGreyColor,
                                  width: 2,
                                ),
                              ),
                            ),
                  ),

                  SizedBox(width: SizeConfig.width(3)),

                  // ✅ Option text
                  Expanded(
                    child: Text(
                      option.text,
                      style: AppTypography.innerText14(context).copyWith(
                        color:
                            isThisOptionLoading
                                ? AppColors.textColor.textGreyColor
                                : isSentByMe
                                ? ThemeColorPalette.getTextColor(
                                  AppColors.appPriSecColor.primaryColor,
                                )
                                : AppThemeManage.appTheme.textColor,
                        fontWeight:
                            hasVoted ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  SizedBox(width: SizeConfig.width(2)),

                  // ✅ Voter avatar stack + vote count
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show first voter profile pic if available
                      if (option.voteCount > 0) ...[
                        // Show up to 2 stacked avatars
                        SizedBox(
                          width: option.voteCount > 1 ? 34 : 22,
                          height: 22,
                          child: Stack(
                            children: [
                              ...option.voters
                                  .take(2)
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((e) {
                                    final voter = e.value;
                                    final offsetX = e.key * 10.0;
                                    return Positioned(
                                      left: offsetX,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                isSentByMe
                                                    ? AppColors
                                                        .appPriSecColor
                                                        .secondaryColor
                                                    : AppThemeManage
                                                        .appTheme
                                                        .chatOppText,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: CommonProfileAvatar(
                                          imageUrl: voter.profilePic,
                                          name: _resolveVoterName(voter),
                                          radius: 9,
                                        ),
                                      ),
                                    );
                                  }),
                            ],
                          ),
                        ),
                        SizedBox(width: SizeConfig.width(1.5)),
                      ],
                      Text(
                        '${option.voteCount}',
                        style: AppTypography.innerText14(context).copyWith(
                          color:
                              isSentByMe
                                  ? ThemeColorPalette.getTextColor(
                                    AppColors.appPriSecColor.primaryColor,
                                  )
                                  : AppThemeManage.appTheme.textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: SizeConfig.height(1)),

              // ✅ Progress bar — always show, fills based on percent
              Padding(
                padding: SizeConfig.getPaddingOnly(left: 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 400),
                    height: 5,
                    child: Stack(
                      children: [
                        // Background track
                        Container(
                          width: double.infinity,
                          color:
                              isSentByMe
                                  ? ThemeColorPalette.getTextColor(
                                    AppColors.appPriSecColor.primaryColor,
                                  ).withValues(alpha: 0.15)
                                  : AppColors.textColor.textGreyColor
                                      .withValues(alpha: 0.2),
                        ),
                        // Filled portion
                        AnimatedFractionallySizedBox(
                          duration: Duration(milliseconds: 400),
                          widthFactor: userVotedAny ? percent : 0.0,
                          heightFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: ThemeColorPalette.getTextColor(
                                isSentByMe
                                    ? AppColors.appPriSecColor.primaryColor
                                    : AppThemeManage.appTheme.chatOppText,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build parent message preview with tap functionality
  Widget _buildParentMessagePreview(BuildContext context, bool isSentByMe) {
    final parentMessage = widget.chat.parentMessage!;
    final parentContent = parentMessage['message_content'] ?? 'Message';
    final parentType = parentMessage['message_type'] ?? 'text';
    final parentThumbnail = parentMessage['message_thumbnail'];
    final parentMessageId = parentMessage['message_id'];

    return GestureDetector(
      onTap: () {
        // Handle tap to navigate to original message
        if (widget.onReplyTap != null && parentMessageId != null) {
          widget.onReplyTap!(parentMessageId as int);
        }
      },
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 8),
        child: Container(
          // constraints: BoxConstraints(maxWidth: SizeConfig.width(70)),
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
                      widget.currentUserId,
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
