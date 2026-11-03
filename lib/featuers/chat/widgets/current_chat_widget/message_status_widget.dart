import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';

/// Reusable message status widget for all message types
/// Shows timestamp and status ticks for sent messages
/// ✅ UPDATED: Now supports optimistic UI states (sending, sent, failed)
class MessageStatusWidget extends StatelessWidget {
  final chats.Records chat;
  final String currentUserId;
  final bool isDarkMode;
  final bool isStarred;
  final VoidCallback? onRetry; // ✅ NEW: Retry callback for failed messages

  const MessageStatusWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
    this.isDarkMode = false,
    this.isStarred = false,
    this.onRetry, // ✅ NEW
  });

  @override
  Widget build(BuildContext context) {
    final isSentByMe = chat.senderId.toString() == currentUserId;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Timestamp
          Text(
            _formatTime(),
            style: AppTypography.captionText(context).copyWith(
              color: isDarkMode 
                  ? Colors.white70 
                  : AppColors.textColor.textGreyColor,
              fontSize: 10,
            ),
          ),

          // Message status (for sent messages)
          if (isSentByMe) ...[
            SizedBox(width: SizeConfig.width(1)),
            _buildMessageStatusIcon(context),
          ],
        ],
      ),
    );
  }

  /// Build message status icon based on message seen status
  /// ✅ UPDATED: Now handles optimistic UI states (sending, sent, failed)
  Widget _buildMessageStatusIcon(BuildContext context) {
    // ✅ NEW: Check for optimistic UI sendingStatus first
    final sendingStatus = chat.sendingStatus;

    // Handle optimistic message states
    if (sendingStatus != null) {
      switch (sendingStatus) {
        case chats.MessageSendingStatus.sending:
          // Show small loading indicator or single grey tick
          return SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkMode ? Colors.white70 : AppColors.textColor.textGreyColor,
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
    Color iconColor = isDarkMode ? Colors.white70 : AppColors.textColor.textGreyColor;

    final messageStatus = chat.messageSeenStatus?.toLowerCase();

    // WhatsApp semantics: one tick = accepted by the server, two = delivered
    // to the device, two blue = read. The old mapping drew a double tick for
    // `sent`, which claimed delivery that had not happened.
    switch (messageStatus) {
      case 'read':
      case 'seen': // legacy value still emitted by older socket events
        statusIcon = Icons.done_all;
        iconColor = Fp.tickRead;
        break;
      case 'delivered':
        statusIcon = Icons.done_all;
        iconColor = isDarkMode ? Colors.white70 : AppColors.textColor.textGreyColor;
        break;
      case 'sent':
        statusIcon = Icons.done;
        iconColor = isDarkMode ? Colors.white70 : AppColors.textColor.textGreyColor;
        break;
      case 'failed':
        statusIcon = Icons.error_outline;
        iconColor = Fp.danger;
        break;
      case 'pending':
      case 'sending':
      case null:
      default:
        statusIcon = Icons.schedule;
        iconColor = isDarkMode ? Colors.white70 : AppColors.textColor.textGreyColor;
        break;
    }

    return Icon(
      statusIcon,
      color: iconColor,
      // Matches the 15px body text; WhatsApp ticks read at roughly this size.
      size: 14,
    );
  }

  /// Format timestamp for display prioritizing updatedAt over createdAt
  String _formatTime() {
    // Get the actual timestamp to use (updatedAt or createdAt)
    final timestamp = _getMessageTimestamp();
    if (timestamp == null || timestamp.isEmpty) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();

      // Convert to 12-hour format with AM/PM
      final hour12 = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
      final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
      final timeString = '${hour12.toString()}:${dateTime.minute.toString().padLeft(2, '0')} $amPm';

      if (dateTime.day == now.day &&
          dateTime.month == now.month &&
          dateTime.year == now.year) {
        return timeString;
      } else {
        return '${dateTime.day}/${dateTime.month} $timeString';
      }
    } catch (e) {
      return '';
    }
  }

  /// Get message timestamp prioritizing updatedAt over createdAt
  String? _getMessageTimestamp() {
    // Priority: updatedAt -> createdAt -> null
    if (chat.updatedAt != null && chat.updatedAt!.trim().isNotEmpty) {
      return chat.updatedAt;
    }
    
    if (chat.createdAt != null && chat.createdAt!.trim().isNotEmpty) {
      return chat.createdAt;
    }
    
    return null;
  }
}