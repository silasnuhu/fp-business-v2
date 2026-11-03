import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';

/// System-generated non-interactive widget for block/unblock messages
/// This widget displays block/unblock events and cannot be starred, pinned, or replied to
class BlockUnblockMessageWidget extends StatelessWidget {
  final chats.Records chat;
  final String currentUserId;
  final bool isStarred;
  final Function(int)? onReplyTap;

  const BlockUnblockMessageWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
    this.isStarred = false,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBlockMessage = chat.messageType?.toLowerCase() == 'block';
    final messageContent = chat.messageContent ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isBlockMessage ? Colors.red[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isBlockMessage ? Colors.red[200]! : Colors.green[200]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBlockMessage ? Icons.block : Icons.check_circle_outline,
                  size: 16,
                  color: isBlockMessage ? Colors.red[700] : Colors.green[700],
                ),
                SizedBox(width: 6),
                Text(
                  isBlockMessage 
                      ? messageContent
                      : 'message_content: unblocked',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isBlockMessage ? Colors.red[700] : Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            _formatTime(_getMessageTimestamp()),
            style: AppTypography.captionText(context).copyWith(
              color: AppColors.textColor.textGreyColor,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final localDateTime = dateTime.toLocal();
      final now = DateTime.now();

      if (localDateTime.day == now.day &&
          localDateTime.month == now.month &&
          localDateTime.year == now.year) {
        return '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${localDateTime.day}/${localDateTime.month} ${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  String? _getMessageTimestamp() {
    if (chat.updatedAt != null && chat.updatedAt!.trim().isNotEmpty) {
      return chat.updatedAt;
    }
    
    if (chat.createdAt != null && chat.createdAt!.trim().isNotEmpty) {
      return chat.createdAt;
    }
    
    return null;
  }
}