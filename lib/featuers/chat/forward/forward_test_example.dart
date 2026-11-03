// Example of how to use the improved forward manager
// This file demonstrates the enhanced forward functionality

import 'package:flutter/material.dart';
import 'package:whoxa/featuers/contacts/screen/contact_list.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class ForwardTestExample {
  // Example 1: Navigate to forward mode with message IDs
  static void navigateToForwardMode(BuildContext context) {
    // Sample data - replace with actual selected message IDs
    final selectedMessageIds = [123, 456, 789];
    final currentChatId = 100;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ContactListScreen(
              isForwardMode: true,
              selectedMessageIds: selectedMessageIds,
              fromChatId: currentChatId,
              forwardTitle: 'Forward Messages',
            ),
      ),
    );
  }

  // Example 2: Navigate to forward mode from chat screen
  static void forwardFromChatScreen(
    BuildContext context,
    List<int> selectedMessages,
    int chatId,
    String chatName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ContactListScreen(
              isForwardMode: true,
              selectedMessageIds: selectedMessages,
              fromChatId: chatId,
              forwardTitle: 'Forward from $chatName',
            ),
      ),
    );
  }

  // Example 3: Handle forward result
  static void handleForwardResult(
    BuildContext context,
    List<int> selectedMessages,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ContactListScreen(
              isForwardMode: true,
              selectedMessageIds: selectedMessages,
              fromChatId: 100, // Current chat ID
              forwardTitle:
                  '${AppString.forward} ${selectedMessages.length} ${AppString.message}${selectedMessages.length != 1 ? 's' : ''}',
            ),
      ),
    ).then((result) {
      // Handle result when returning from forward screen
      if (result == true) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppString.messagesForwardedSuccessfully)),
        );
      }
    });
  }
}

/*
USAGE INSTRUCTIONS:

1. **Basic Forward Navigation:**
   ```dart
   // In your chat screen, when user selects messages to forward
   ForwardTestExample.navigateToForwardMode(context);
   ```

2. **Forward with Selected Messages:**
   ```dart
   // When you have specific message IDs to forward
   final selectedMessageIds = [123, 456, 789];
   final currentChatId = 100;
   
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => ContactListScreen(
         isForwardMode: true,
         selectedMessageIds: selectedMessageIds,
         fromChatId: currentChatId,
       ),
     ),
   );
   ```

3. **What's Improved in Forward Mode:**
   - ✅ Shows ALL recent chats (including those with unregistered users)
   - ✅ Shows both registered and unregistered contacts
   - ✅ Clear separation between "Recent Chats" and "All Contacts"
   - ✅ Search functionality across all chats and contacts
   - ✅ Multiple selection with visual feedback
   - ✅ Prevents forwarding to the same chat you're forwarding from
   - ✅ Shows proper chat names, group indicators, and unread counts
   - ✅ Handles both individual and group chats properly
   - ✅ Real-time updates when chat list changes

4. **Features Available:**
   - Recent Chats tab: Shows all your recent conversations
   - All Contacts tab: Shows all device contacts (registered + unregistered)
   - Search: Find specific chats or contacts quickly
   - Multi-select: Select multiple recipients at once
   - Forward button: Send messages to selected recipients
   - Visual feedback: Selected items are highlighted
   - Counter: Shows how many recipients are selected

5. **Contact List Screen (Normal Mode) Unchanged:**
   - Regular contact list functionality remains the same
   - Only forward mode has been enhanced
   - Normal mode still has "Contacts" and "Invites" tabs
   - No changes to regular contact management
*/
