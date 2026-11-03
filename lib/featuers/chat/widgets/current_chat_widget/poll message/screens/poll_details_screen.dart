import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/poll%20message/data/poll_model.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';

class PollVoteDetailsSheet extends StatefulWidget {
  final PollData poll;
  final String currentUserId;

  const PollVoteDetailsSheet({
    super.key,
    required this.poll,
    required this.currentUserId,
  });

  @override
  State<PollVoteDetailsSheet> createState() => _PollVoteDetailsSheetState();
}

class _PollVoteDetailsSheetState extends State<PollVoteDetailsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.poll.options.length + 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ Deduplicate all voters across all options by userId
  List<chats.Votes> get allVoters {
    final seen = <int>{};
    final result = <chats.Votes>[];
    for (final option in widget.poll.options) {
      for (final voter in option.voters) {
        if (voter.userId != null && seen.add(voter.userId!)) {
          result.add(voter);
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.poll.totalVotes;
    final options = widget.poll.options;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.scaffoldBackColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle bar ──
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: AppThemeManage.appTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──
          Padding(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.poll.question,
                        style: AppTypography.h220(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                      iconSize: 20,
                      color: AppColors.textColor.textGreyColor,
                    ),
                  ],
                ),
                Text(
                  '$total ${total == 1 ? 'vote' : 'total votes'}',
                  style: AppTypography.captionText(
                    context,
                  ).copyWith(color: AppColors.textColor.textGreyColor),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppThemeManage.appTheme.borderColor),

          // ── Tabs: All + per option ──
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.appPriSecColor.primaryColor,
            unselectedLabelColor: AppColors.textColor.textGreyColor,
            indicatorColor: AppColors.appPriSecColor.primaryColor,
            labelStyle: AppTypography.innerText12Mediu(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'All ($total)'),
              ...options.map((o) => Tab(text: '${o.text} (${o.voteCount})')),
            ],
          ),

          // ── Tab content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All voters tab
                _buildVoterList(voters: allVoters, context: context),
                // Per option tabs
                ...options.map(
                  (o) => _buildVoterList(
                    voters: o.voters,
                    context: context,
                    optionText: o.text,
                    percent: total == 0 ? 0 : o.voteCount / total,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoterList({
    required List<chats.Votes> voters,
    required BuildContext context,
    String? optionText,
    double? percent,
  }) {
    if (voters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.how_to_vote_outlined,
              size: 48,
              color: AppColors.textColor.textGreyColor,
            ),
            SizedBox(height: 12),
            Text(
              'No votes yet',
              style: AppTypography.innerText12Mediu(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Per-option progress bar ──
        if (optionText != null && percent != null) ...[
          Padding(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        optionText,
                        style: AppTypography.innerText12Mediu(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${(percent * 100).toStringAsFixed(0)}%',
                      style: AppTypography.innerText12Mediu(context).copyWith(
                        color: AppColors.appPriSecColor.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    backgroundColor: AppThemeManage.appTheme.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.appPriSecColor.primaryColor,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppThemeManage.appTheme.borderColor),
        ],

        // ── Voter list ──
        Expanded(
          child: ListView.separated(
            padding: SizeConfig.getPaddingSymmetric(vertical: 8),
            itemCount: voters.length,
            separatorBuilder:
                (_, _) => Divider(
                  height: 1,
                  indent: 70,
                  color: AppThemeManage.appTheme.borderColor,
                ),
            itemBuilder: (context, index) {
              final voter = voters[index];
              final isMe = voter.userId.toString() == widget.currentUserId;
              // NEW's poll payload only ever gives back bare voter user-ids
              // (no name/avatar) — resolve the display name from the
              // already-synced contacts cache instead of showing "Unknown"
              // for every voter but yourself.
              final displayName =
                  isMe
                      ? 'You'
                      : ContactNameService.instance.getDisplayNameStable(
                        userId: voter.userId,
                        configProvider: Provider.of<ProjectConfigProvider>(
                          context,
                          listen: false,
                        ),
                        contextFullName:
                            voter.fullName?.isNotEmpty == true
                                ? voter.fullName
                                : voter.userName,
                      );

              return ListTile(
                leading: _buildAvatar(voter, displayName),
                title: Text(
                  displayName,
                  style: AppTypography.innerText12Mediu(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle:
                    voter.userName != null &&
                            voter.userName!.isNotEmpty &&
                            !isMe
                        ? Text(
                          '@${voter.userName}',
                          style: AppTypography.captionText(
                            context,
                          ).copyWith(color: AppColors.textColor.textGreyColor),
                        )
                        : null,
                trailing:
                    isMe
                        ? Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.appPriSecColor.primaryColor
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'You',
                            style: AppTypography.captionText(context).copyWith(
                              color: AppColors.appPriSecColor.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                        : null,
              );
            },
          ),
        ),
      ],
    );
  }

  // Same letter-avatar component used everywhere else in chat, so a voter
  // with no profile pic gets the app's usual initials avatar instead of a
  // bare "?".
  Widget _buildAvatar(chats.Votes voter, String resolvedName) {
    return CommonProfileAvatar(
      imageUrl: voter.profilePic,
      name: resolvedName,
      radius: 22,
    );
  }
}
