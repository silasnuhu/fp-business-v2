import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart';
import 'package:whoxa/utils/app_size_config.dart';

/// Retry button widget for failed messages
/// Shows a small, subtle retry icon that users can tap to resend
class MessageRetryWidget extends StatelessWidget {
  final Records message;
  final VoidCallback onRetry;
  final bool showLabel;

  const MessageRetryWidget({
    super.key,
    required this.message,
    required this.onRetry,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    // Only show for failed messages
    if (message.sendingStatus != MessageSendingStatus.failed) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onRetry,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.width(2),
          vertical: SizeConfig.height(0.5),
        ),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh,
              size: 16,
              color: Colors.red.shade600,
            ),
            if (showLabel) ...[
              SizedBox(width: SizeConfig.width(1)),
              Text(
                'Retry',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline retry icon (smaller, to be placed inside or beside message bubble)
class InlineRetryIcon extends StatelessWidget {
  final VoidCallback onRetry;
  final double size;

  const InlineRetryIcon({
    super.key,
    required this.onRetry,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRetry,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.error_outline,
          size: size,
          color: Colors.red.shade600,
        ),
      ),
    );
  }
}

/// Failed message indicator with retry action
class FailedMessageIndicator extends StatelessWidget {
  final VoidCallback onRetry;

  const FailedMessageIndicator({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size: 12,
          color: Colors.red.shade600,
        ),
        SizedBox(width: 4),
        GestureDetector(
          onTap: onRetry,
          child: Text(
            'Tap to retry',
            style: TextStyle(
              fontSize: 10,
              color: Colors.red.shade600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
