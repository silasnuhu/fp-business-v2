import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';

class ChatListForForward extends StatefulWidget {
  final Function(int chatId, String chatName) onChatSelected;
  final int currentChatId;

  const ChatListForForward({
    super.key,
    required this.onChatSelected,
    required this.currentChatId,
  });

  @override
  State<ChatListForForward> createState() => _ChatListForForwardState();
}

class _ChatListForForwardState extends State<ChatListForForward> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final chats = chatProvider.chatListData.chats;

        // Filter out current chat
        final availableChats =
            chats.where((chat) {
              final chatId = chat.records?.first.chatId;
              return chatId != null && chatId != widget.currentChatId;
            }).toList();

        if (availableChats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: AppColors.textColor.textGreyColor,
                ),
                SizedBox(height: 16),
                Text(
                  'No other chats available',
                  style: AppTypography.mediumText(
                    context,
                  ).copyWith(color: AppColors.textColor.textGreyColor),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: availableChats.length,
          itemBuilder: (context, index) {
            final chat = availableChats[index];
            final chatRecord = chat.records?.first;
            final peerUser = chat.peerUserData;

            if (chatRecord == null) return SizedBox.shrink();

            final chatId = chatRecord.chatId ?? 0;
            final chatName = ContactNameService.instance.resolveName(
              userId: peerUser?.userId,
              firstName: peerUser?.firstName,
              lastName: peerUser?.lastName,
              fullName: peerUser?.fullName,
              userName: peerUser?.userName,
              email: peerUser?.email,
              fallback: 'Unknown Chat',
            );
            final profilePic = peerUser?.profilePic ?? '';
            final lastMessage = chatRecord.messages?.first.messageContent ?? '';

            return ListTile(
              leading: CommonProfileAvatar(
                imageUrl: profilePic,
                name: chatName,
                radius: 24,
              ),
              title: Text(
                chatName,
                style: AppTypography.mediumText(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                lastMessage,
                style: AppTypography.smallText(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => widget.onChatSelected(chatId, chatName),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            );
          },
        );
      },
    );
  }
}
