import 'package:flutter/foundation.dart';

// DEBUG: Forward Screen Missing Chats Analysis
// This file helps identify why some chats are missing in forward screen

/*
ISSUE: User has 12 total chats but forward screen shows only 9

POTENTIAL CAUSES:
1. Current chat exclusion (reduces count by 1)
2. Empty records filtering (chats with no messages)
3. Pagination not loading all chats
4. Data processing errors

DEBUGGING STEPS:
1. Check console logs when opening forward screen
2. Look for these debug messages:
   - "🔍 DEBUG - Total chats in chatProvider: X"
   - "🔍 DEBUG - Recent chats shown: X"
   - "🔍 DEBUG - Current chat skipped: X"
   - "🔍 DEBUG - Empty records skipped: X"

EXPECTED RESULTS:
- If you have 12 total chats
- Current chat (1) should be excluded
- You should see 11 chats in forward screen
- If you see 9, then 2 chats are being filtered out

MOST LIKELY CAUSES:
1. 2 chats have empty records (no messages)
2. Pagination is not loading all chats
3. Some chats have invalid data structure

SOLUTIONS:
1. Include chats with empty records
2. Load all paginated chats
3. Better error handling for malformed chat data
*/

class ForwardDebugHelper {
  // Method to analyze missing chats
  static void analyzeForwardChatIssue({
    required int totalChats,
    required int shownChats,
    required int currentChatSkipped,
    required int emptyRecordsSkipped,
  }) {
    debugPrint('📊 FORWARD CHAT ANALYSIS:');
    debugPrint('   Total chats available: $totalChats');
    debugPrint('   Chats shown in forward: $shownChats');
    debugPrint('   Current chat skipped: $currentChatSkipped');
    debugPrint('   Empty records skipped: $emptyRecordsSkipped');

    final expectedShown = totalChats - currentChatSkipped;
    final actualMissing = expectedShown - shownChats;

    debugPrint('   Expected to show: $expectedShown');
    debugPrint('   Actually missing: $actualMissing');

    if (actualMissing > 0) {
      debugPrint('⚠️  ISSUE: $actualMissing chats are missing');
      debugPrint('   Likely causes:');
      debugPrint('   - Empty records: $emptyRecordsSkipped');
      debugPrint('   - Pagination issue: ${actualMissing - emptyRecordsSkipped}');
    } else {
      debugPrint('✅ All chats are showing correctly');
    }
  }

  // Method to check if chat should be included
  static bool shouldIncludeChat(dynamic chat, int? fromChatId) {
    // Check if chat has records
    if (chat.records?.isEmpty ?? true) {
      debugPrint('❌ Chat excluded: No records');
      return false;
    }

    final record = chat.records!.first;

    // Check if it's current chat
    if (fromChatId != null && record.chatId == fromChatId) {
      debugPrint('❌ Chat excluded: Current chat (${record.chatId})');
      return false;
    }

    // Check if chat has valid structure
    if (record.chatId == null) {
      debugPrint('❌ Chat excluded: No chatId');
      return false;
    }

    debugPrint('✅ Chat included: ${record.chatId}');
    return true;
  }
}
