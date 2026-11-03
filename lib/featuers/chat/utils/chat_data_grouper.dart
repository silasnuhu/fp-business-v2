import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart';

class ChatDateGrouper {
  static Map<String, List<Records>> groupMessagesByDate(
    List<Records> messages,
  ) {
    final Map<String, List<Records>> groupedMessages = {};

    for (final message in messages) {
      if (message.createdAt != null) {
        final dateKey = _getDateKey(message.createdAt!);
        groupedMessages.putIfAbsent(dateKey, () => []).add(message);
      }
    }

    return groupedMessages;
  }

  static String _getDateKey(String createdAt) {
    try {
      final messageDate = DateTime.parse(createdAt);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final msgDate = DateTime(
        messageDate.year,
        messageDate.month,
        messageDate.day,
      );

      if (msgDate == today) {
        return 'Today';
      } else if (msgDate == yesterday) {
        return 'Yesterday';
      } else {
        return DateFormat('dd MMMM yyyy').format(messageDate);
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  static List<Widget> buildGroupedMessageList(
    Map<String, List<Records>> groupedMessages,
    Function(Records) messageBuilder,
  ) {
    final List<Widget> widgets = [];

    // Sort date groups (Today -> Yesterday -> Older dates)
    final sortedKeys =
        groupedMessages.keys.toList()..sort((a, b) => _sortDateKeys(a, b));

    for (final dateKey in sortedKeys) {
      // Add date header
      widgets.add(_buildDateHeader(dateKey));

      // Add messages for this date
      final messages = groupedMessages[dateKey]!;
      for (final message in messages) {
        widgets.add(messageBuilder(message));
      }
    }

    return widgets;
  }

  static Widget _buildDateHeader(String dateKey) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(
            dateKey,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  static int _sortDateKeys(String a, String b) {
    if (a == 'Today') return -1;
    if (b == 'Today') return 1;
    if (a == 'Yesterday') return -1;
    if (b == 'Yesterday') return 1;

    try {
      final dateA = DateFormat('dd MMMM yyyy').parse(a);
      final dateB = DateFormat('dd MMMM yyyy').parse(b);
      return dateB.compareTo(dateA); // Newer dates first
    } catch (e) {
      return 0;
    }
  }
}
