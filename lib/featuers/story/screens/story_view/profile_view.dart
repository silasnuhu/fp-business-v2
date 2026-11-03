import 'package:flutter/material.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';
import 'package:whoxa/widgets/global.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.userName,
    required this.userProfile,
    required this.fName,
    required this.lName,
    required this.isMyStory,
    required this.storyTime,
    required this.onPauseRequested,
    this.userId,
  });
  final String userName;
  final String userProfile;
  final String fName;
  final String lName;
  final bool isMyStory;
  final String storyTime;
  final VoidCallback onPauseRequested;

  /// The story owner; a blue tick follows the name when they are premium.
  final int? userId;

  Widget _buildName(BuildContext context) {
    final style = AppTypography.innerText14(context).copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textColor.textWhiteColor,
    );
    if (!isMyStory) {
      return UserNameWithBadge(userId: userId, name: userName, style: style);
    }
    // The user's own story: the tick follows their own subscription.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            userName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const OwnVerifiedBadge(size: 15, leading: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30, left: 15, right: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommonProfileAvatar(
                  imageUrl: userProfile,
                  name: userName,
                  radius: 17.5,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildName(context),
                      Text(
                        formatStoryTime(storyTime),
                        style: AppTypography.innerText10(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textColor.textDarkGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          isMyStory
              ? InkWell(
                onTap: () {
                  onPauseRequested();
                },
                child: Icon(
                  Icons.more_horiz,
                  size: SizeConfig.sizedBoxHeight(25),
                  color: AppColors.white,
                ),
              )
              : SizedBox.shrink(),
        ],
      ),
    );
  }
}
