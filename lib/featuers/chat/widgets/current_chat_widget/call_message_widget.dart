import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/services/call_display_service.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';

class CallMessageWidget extends StatefulWidget {
  final chats.Records chat;
  final String currentUserId;
  final bool isStarred;
  final Function(int)? onReplyTap;
  final int? peerUserId;

  const CallMessageWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
    this.isStarred = false,
    this.onReplyTap,
    this.peerUserId,
  });

  @override
  State<CallMessageWidget> createState() => _CallMessageWidgetState();
}

class _CallMessageWidgetState extends State<CallMessageWidget> {
  final _logger = ConsoleAppLogger.forModule('CallMessageWidget');

  @override
  Widget build(BuildContext context) {
    final callDisplayService = CallDisplayService();
    final currentUserIdInt = int.tryParse(widget.currentUserId);
    final isSentByMe = widget.chat.senderId == currentUserIdInt;

    // Log widget.chat to check before passing to call info
    _logger.d('widget.chat before call info pass: ${widget.chat.toJson()}');
    _logger.v('=== CALL DEBUG ===');
    _logger.v('CALL DEBUG_currentUserId string: "${widget.currentUserId}"');
    _logger.v('CALL DEBUG_currentUserIdInt: $currentUserIdInt');
    _logger.v('CALL DEBUG_senderId: ${widget.chat.senderId}');
    _logger.v('CALL DEBUG_messageContent: ${widget.chat.messageContent}');
    _logger.v('CALL DEBUG_messageType: ${widget.chat.messageType}');
    _logger.v('CALL DEBUG_calls length: ${widget.chat.calls?.length}');
    _logger.v(
      'CALL DEBUG_isSentByMe: ${widget.chat.senderId == currentUserIdInt}',
    );

    // Get call info synchronously now that we have currentUserId
    final callInfo = callDisplayService.getCallDisplayInfoSync(
      calls: widget.chat.calls,
      messageContent: widget.chat.messageContent,
      messageType: widget.chat.messageType,
      currentUserId: currentUserIdInt,
      messageSenderId:
          widget.chat.senderId, // Pass message sender ID for correct direction
    );

    // If we have call info, display it immediately
    if (callInfo != null) {
      return _buildCallWidgetWithTimestamp(
        callDisplayService,
        callInfo,
        isSentByMe,
        context,
      );
    }

    // Fallback if no call info available
    return _buildCallLoadingWidget();
  }

  /// Build call widget with timestamp like other messages
  Widget _buildCallWidgetWithTimestamp(
    CallDisplayService service,
    CallDisplayInfo callInfo,
    bool isSendByMe,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          isSendByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Call widget centered (calls are shared events)
        service.buildUniversalChatCallWidget(callInfo, isSendByMe, context),

        // Timestamp row centered
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            _formatTime(_getMessageTimestamp()),
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textGreyColor, fontSize: 10),
          ),
        ),
      ],
    );
  }

  /// Format timestamp for display using same format as text messages
  String _formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final localDateTime = dateTime.toLocal(); // Convert to local time
      return DateFormat.jm().format(localDateTime); // e.g., 12:30 PM
    } catch (e) {
      return '';
    }
  }

  /// Get message timestamp prioritizing updatedAt over createdAt
  String? _getMessageTimestamp() {
    // Priority: updatedAt -> createdAt -> null
    if (widget.chat.updatedAt != null &&
        widget.chat.updatedAt!.trim().isNotEmpty) {
      return widget.chat.updatedAt;
    }

    if (widget.chat.createdAt != null &&
        widget.chat.createdAt!.trim().isNotEmpty) {
      return widget.chat.createdAt;
    }

    return null;
  }

  /// Improved loading widget that better matches final call appearance
  Widget _buildCallLoadingWidget() {
    // Try to determine call type from message content if available
    final messageContent = widget.chat.messageContent?.toLowerCase();
    IconData icon = Icons.phone;
    Color color = Colors.grey[600]!;
    String text = 'Loading call...';

    // Provide better loading state based on available info
    if (messageContent == 'callmissed') {
      icon = Icons.phone_missed_outlined;
      color = Colors.red[700]!;
      text = 'Missed call';
    } else if (widget.chat.calls != null && widget.chat.calls!.isNotEmpty) {
      // Show generic call icon with less jarring transition
      icon = Icons.phone;
      color = Colors.green[600]!;
      text = 'Call';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Call widget centered (calls are shared events)
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  messageContent == 'callmissed'
                      ? Colors.red[50]
                      : Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    messageContent == 'callmissed'
                        ? Colors.red[200]!
                        : Colors.green[200]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                SizedBox(width: 6),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Timestamp row centered
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            _formatTime(_getMessageTimestamp()),
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textGreyColor, fontSize: 10),
          ),
        ),
      ],
    );
  }
}
