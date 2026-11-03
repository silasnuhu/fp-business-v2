import 'package:flutter/material.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

class GroupChatStatusWidget extends StatelessWidget {
  final int memberCount;
  final int onlineCount;
  final List<String> typingUsers;

  const GroupChatStatusWidget({
    super.key,
    required this.memberCount,
    required this.onlineCount,
    required this.typingUsers,
  });

  @override
  Widget build(BuildContext context) {
    if (typingUsers.isNotEmpty) {
      return _buildTypingIndicator(context);
    }

    return _buildMemberStatus(context);
  }

  Widget _buildTypingIndicator(BuildContext context) {
    String typingText;
    if (typingUsers.length == 1) {
      typingText = '${typingUsers.first} is typing...';
    } else if (typingUsers.length == 2) {
      typingText = '${typingUsers[0]} and ${typingUsers[1]} are typing...';
    } else {
      typingText = '${typingUsers.length} people are typing...';
    }

    return Row(
      children: [
        SizedBox(width: 12, height: 12, child: commonLoading()),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            typingText,
            style: AppTypography.captionText(context).copyWith(
              color: AppColors.appPriSecColor.primaryColor,
              fontStyle: FontStyle.italic,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberStatus(BuildContext context) {
    return Text(
      '${AppString.countMembers('$memberCount')}${onlineCount > 0 ? ', ${AppString.countOnline('$onlineCount')}' : ''}',
      style: AppTypography.captionText(
        context,
      ).copyWith(color: AppColors.textColor.textGreyColor),
    );
  }
}
