// ignore_for_file: unused_local_variable

import 'package:intl/intl.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

/// Utility functions for formatting timestamps in chat UI
class TimestampFormatter {
  // Format timestamp for chat messages
  // static String formatChatTimestamp(String timestamp) {
  //   try {
  //     final dateTime = DateTime.parse(timestamp);
  //     final now = DateTime.now();

  //     // If the message is from today, show only the time
  //     if (dateTime.year == now.year &&
  //         dateTime.month == now.month &&
  //         dateTime.day == now.day) {
  //       return DateFormat('h:mm a').format(dateTime);
  //     }

  //     // If the message is from yesterday, show "Yesterday" and time
  //     final yesterday = now.subtract(Duration(days: 1));
  //     if (dateTime.year == yesterday.year &&
  //         dateTime.month == yesterday.month &&
  //         dateTime.day == yesterday.day) {
  //       return 'Yesterday, ${DateFormat('h:mm a').format(dateTime)}';
  //     }

  //     // If the message is from this week, show day name and time
  //     if (now.difference(dateTime).inDays < 7) {
  //       return '${DateFormat('EEEE').format(dateTime)}, ${DateFormat('h:mm a').format(dateTime)}';
  //     }

  //     // Otherwise, show date and time
  //     return DateFormat('MMM d, h:mm a').format(dateTime);
  //   } catch (e) {
  //     return '';
  //   }
  // }

  // static String formatChatTimestamp(String timestamp) {
  //   DateTime utcDateTime = DateTime.parse(timestamp).toLocal();
  //   DateTime now = DateTime.now();
  //   DateTime today = DateTime(now.year, now.month, now.day);
  //   DateTime yesterday = today.subtract(const Duration(days: 1));

  //   if (utcDateTime.isAfter(today)) {
  //     return DateFormat('hh:mma').format(utcDateTime); // Today
  //   } else if (utcDateTime.isAfter(yesterday)) {
  //     return "Yesterday"; // Yesterday
  //   } else {
  //     return DateFormat('dd/MM/yyyy').format(utcDateTime); // Older dates
  //   }
  // }
  static String formatChatTimestamp(String timestamp) {
    try {
      DateTime utcDateTime = DateTime.parse(timestamp).toLocal();
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime yesterday = today.subtract(const Duration(days: 1));
      DateTime messageDate = DateTime(
        utcDateTime.year,
        utcDateTime.month,
        utcDateTime.day,
      );

      if (messageDate.isAtSameMomentAs(today)) {
        // Today - show time only (e.g., "2:30 PM")
        return DateFormat('h:mm a').format(utcDateTime);
      } else if (messageDate.isAtSameMomentAs(yesterday)) {
        // Yesterday - show "Yesterday" with time (e.g., "Yesterday 2:30 PM")
        return AppString.yesterdayTime(DateFormat('h:mm a').format(utcDateTime));
      } else {
        // Older dates - show date with time
        if (utcDateTime.year == now.year) {
          // Same year - show date without year (e.g., "Dec 25, 2:30 PM")
          return DateFormat('MMM d, h:mm a').format(utcDateTime);
        } else {
          // Different year - show full date with year (e.g., "Dec 25, 2023, 2:30 PM")
          return DateFormat('MMM d, yyyy, h:mm a').format(utcDateTime);
        }
      }
    } catch (e) {
      return AppString.invalidTimestamp;
    }
  }

  // Format last seen timestamp
  // static String formatLastSeen(String timestamp) {
  //   try {
  //     final dateTime = DateTime.parse(timestamp);
  //     final now = DateTime.now();
  //     final difference = now.difference(dateTime);

  //     if (difference.inSeconds < 60) {
  //       return 'Just now';
  //     } else if (difference.inMinutes < 60) {
  //       return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
  //     } else if (difference.inHours < 24) {
  //       return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
  //     } else if (difference.inDays < 7) {
  //       return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
  //     } else if (difference.inDays < 30) {
  //       return '${(difference.inDays / 7).floor()} ${(difference.inDays / 7).floor() == 1 ? 'week' : 'weeks'} ago';
  //     } else if (difference.inDays < 365) {
  //       return '${(difference.inDays / 30).floor()} ${(difference.inDays / 30).floor() == 1 ? 'month' : 'months'} ago';
  //     } else {
  //       return '${(difference.inDays / 365).floor()} ${(difference.inDays / 365).floor() == 1 ? 'year' : 'years'} ago';
  //     }
  //   } catch (e) {
  //     return 'Last seen recently';
  //   }
  // }
  static String formatLastSeen(String timestamp) {
    try {
      // Parse and convert to local time
      final dateTime = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // Under a minute → “Just Now”
      // if (difference.inMinutes < 1) {
      //   return 'Just Now';
      // }

      // Prepare date-only values for “today” comparison
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      // If it's today → show "last seen today at time"
      if (today == messageDate) {
        return AppString.lastSeenTodayAtTime(DateFormat('h:mm a').format(dateTime).toLowerCase());
      }

      // Else → "last seen dd/MM/yyyy at h:mma"
      final datePart = DateFormat('dd/MM/yyyy').format(dateTime);
      final timePart = DateFormat('h:mm a').format(dateTime).toLowerCase();
      return AppString.lastSeenDateAtTime(datePart, timePart);
    } catch (e) {
      return AppString.lastSeenRecently;
    }
  }

  // Format chat list timestamp (for the chat list screen)
  static String formatChatListTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();

      // If the message is from today, show only the time
      if (dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day) {
        return DateFormat('h:mm a').format(dateTime);
      }

      // If the message is from yesterday, show "Yesterday"
      final yesterday = now.subtract(Duration(days: 1));
      if (dateTime.year == yesterday.year &&
          dateTime.month == yesterday.month &&
          dateTime.day == yesterday.day) {
        return AppString.yesterday;
      }

      // If the message is from this year, show month and day
      if (dateTime.year == now.year) {
        return DateFormat('MMM d').format(dateTime);
      }

      // Otherwise, show date with year
      return DateFormat('MMM d, yyyy').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  // Format voice message duration
  /// The later of two ISO-8601 timestamps, ignoring blanks and
  /// unparseable values. Used to merge the two presence sources: the peer's
  /// `lastSeenAt` from `users/batch` (correct at chat-open time) and the
  /// local stamp from a `presence_update` seen since (correct afterwards) —
  /// neither can simply win outright.
  static String? latestTimestamp(String? a, String? b) {
    final aTime = DateTime.tryParse(a?.trim() ?? '');
    final bTime = DateTime.tryParse(b?.trim() ?? '');
    if (aTime == null) return bTime == null ? null : b;
    if (bTime == null) return a;
    return aTime.isAfter(bTime) ? a : b;
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    return duration.inHours > 0
        ? "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds"
        : "$twoDigitMinutes:$twoDigitSeconds";
  }
}
