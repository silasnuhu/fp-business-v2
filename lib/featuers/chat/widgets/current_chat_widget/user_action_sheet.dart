import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';

import '../../data/chats_model.dart';

class UserActionSheet extends StatelessWidget {
  final User user;
  final VoidCallback onViewProfile;
  final VoidCallback onStartChat;

  const UserActionSheet({
    super.key,
    required this.user,
    required this.onViewProfile,
    required this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedName = ContactNameService.instance.resolveName(
      userId: user.userId,
      fullName: user.fullName,
      userName: user.userName,
      fallback: 'Unknown User',
    );
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // User info header
          Row(
            children: [
              CommonProfileAvatar(
                imageUrl: user.profilePic,
                name: resolvedName,
                radius: 25,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolvedName,
                      style: AppTypography.h4(context),
                    ),
                    if (user.userName?.isNotEmpty == true)
                      Text(
                        '@${user.userName}',
                        style: AppTypography.captionText(
                          context,
                        ).copyWith(color: AppColors.textColor.textGreyColor),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Action buttons
          ListTile(
            leading: Icon(Icons.person),
            title: Text(AppString.viewProfile),
            onTap: onViewProfile,
          ),
          ListTile(
            leading: Icon(Icons.chat),
            title: Text(AppString.sendMessage),
            onTap: onStartChat,
          ),

          SizedBox(height: 20),
        ],
      ),
    );
  }
}
