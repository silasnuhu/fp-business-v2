// simple_forward_fix.dart - A simple, reliable replacement for your _handleForwardMessages method

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';

/// SIMPLE REPLACEMENT FOR YOUR _handleForwardMessages METHOD
/// 
/// Copy this method and replace your existing _handleForwardMessages method in contact_list.dart
/// This version processes ALL contacts reliably without complex batching.

Future<void> handleForwardMessagesReliable(
  BuildContext context,
  List<int> chatIds,
  List<int> userIds, {
  required List<int>? selectedMessageIds,
  required int? fromChatId,
  Function()? onForwardCompleted,
}) async {
  
  if ((chatIds.isEmpty && userIds.isEmpty) || selectedMessageIds?.isEmpty == true) {
    Navigator.of(context).pop();
    return;
  }

  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Forwarding ${selectedMessageIds?.length ?? 0} message${(selectedMessageIds?.length ?? 0) != 1 ? 's' : ''} to ${chatIds.length + userIds.length} recipient${(chatIds.length + userIds.length) != 1 ? 's' : ''}...',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  try {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    int successCount = 0;
    int totalAttempts = 0;
    List<String> errors = [];

    debugPrint('🚀 Starting reliable forward process');
    debugPrint('📋 Selected: ${chatIds.length} existing chats, ${userIds.length} new contacts');
    debugPrint('📨 Messages to forward: ${selectedMessageIds?.length ?? 0}');

    // Forward to existing chats - ONE BY ONE
    for (int chatIndex = 0; chatIndex < chatIds.length; chatIndex++) {
      final chatId = chatIds[chatIndex];
      debugPrint('📤 Processing existing chat ${chatIndex + 1}/${chatIds.length} (ID: $chatId)');
      
      for (int msgIndex = 0; msgIndex < (selectedMessageIds?.length ?? 0); msgIndex++) {
        final messageId = selectedMessageIds![msgIndex];
        totalAttempts++;

        try {
          debugPrint('  📩 Forwarding message $messageId to chat $chatId (${msgIndex + 1}/${selectedMessageIds.length})');
          
          final success = await chatProvider.forwardMessage(
            fromChatId: fromChatId ?? 0,
            toChatId: chatId,
            messageId: messageId,
          );

          if (success) {
            successCount++;
            debugPrint('  ✅ Success: Message $messageId → Chat $chatId');
          } else {
            errors.add('Failed to forward message to existing chat $chatId');
            debugPrint('  ❌ Failed: Message $messageId → Chat $chatId');
          }
        } catch (e) {
          errors.add('Error forwarding to chat $chatId: ${e.toString()}');
          debugPrint('  ❌ Exception: Message $messageId → Chat $chatId: $e');
        }
        
        // Small delay between messages
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      // Delay between different chats
      if (chatIndex < chatIds.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Forward to new chats (contacts) - ONE BY ONE  
    for (int userIndex = 0; userIndex < userIds.length; userIndex++) {
      final userId = userIds[userIndex];
      debugPrint('📤 Processing new contact ${userIndex + 1}/${userIds.length} (ID: $userId)');
      
      for (int msgIndex = 0; msgIndex < (selectedMessageIds?.length ?? 0); msgIndex++) {
        final messageId = selectedMessageIds![msgIndex];
        totalAttempts++;

        try {
          debugPrint('  📩 Forwarding message $messageId to user $userId (${msgIndex + 1}/${selectedMessageIds.length})');
          
          final success = await chatProvider.forwardMessageToUser(
            fromChatId: fromChatId ?? 0,
            toUserId: userId,
            messageId: messageId,
          );

          if (success) {
            successCount++;
            debugPrint('  ✅ Success: Message $messageId → User $userId');
          } else {
            errors.add('Failed to forward message to user $userId');
            debugPrint('  ❌ Failed: Message $messageId → User $userId');
          }
        } catch (e) {
          errors.add('Error forwarding to user $userId: ${e.toString()}');
          debugPrint('  ❌ Exception: Message $messageId → User $userId: $e');
        }
        
        // Small delay between messages  
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      // Delay between different users
      if (userIndex < userIds.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Close loading dialog
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    debugPrint('📊 Forward process complete: $successCount/$totalAttempts successful');

    // Refresh chat list if any forwards succeeded
    if (successCount > 0) {
      debugPrint('🔄 Refreshing chat list...');
      await chatProvider.refreshChatList();
      debugPrint('✅ Chat list refreshed');
    }

    // Show result and navigate
    if (successCount == totalAttempts) {
      // All successful
      if (onForwardCompleted != null) onForwardCompleted();
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close forward screen
      if (!context.mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst); // Go to chat list
      
      // Show success message
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully forwarded to all ${chatIds.length + userIds.length} recipients!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (successCount > 0) {
      // Partial success
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Partial Success'),
            ],
          ),
          content: Text('Successfully forwarded $successCount out of $totalAttempts messages.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close forward screen  
                Navigator.of(context).popUntil((route) => route.isFirst); // Go to chat list
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      // All failed
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Forward Failed'),
            ],
          ),
          content: const Text('Failed to forward any messages. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

  } catch (e) {
    // Close loading dialog on critical error
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    debugPrint('❌ Critical error in forward process: $e');
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text('An unexpected error occurred: ${e.toString()}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// INTEGRATION INSTRUCTIONS:
/// 
/// 1. In your contact_list.dart, replace your entire _handleForwardMessages method with:
/// 
///    Future<void> _handleForwardMessages(
///      List<int> chatIds,
///      List<int> userIds,
///    ) async {
///      await handleForwardMessagesReliable(
///        context,
///        chatIds,
///        userIds,
///        selectedMessageIds: widget.selectedMessageIds,
///        fromChatId: widget.fromChatId,
///        onForwardCompleted: widget.onForwardCompleted,
///      );
///    }
/// 
/// 2. Add this import at the top of your contact_list.dart:
///    import 'package:whoxa/featuers/contacts/screen/simple_forward_fix.dart';
///
/// 3. You can remove:
///    - The old _forwardToNewChat method
///    - Dialog helper methods (_showLoadingDialog, _closeLoadingDialog, etc.)
///
/// This version will:
/// ✅ Process ALL 12 contacts (no stopping at 7)
/// ✅ Use simple, reliable sequential processing
/// ✅ Provide detailed logging to track progress
/// ✅ Handle errors gracefully without breaking the chain
/// ✅ Refresh chat list automatically after successful forwards
/// ✅ Show appropriate success/error messages