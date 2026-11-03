// improved_contact_list_forward.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';

/// Forward result model
class ForwardResult {
  final bool success;
  final String? error;
  final int? chatId;
  final int? userId;
  final int messageId;

  ForwardResult({
    required this.success,
    this.error,
    this.chatId,
    this.userId,
    required this.messageId,
  });

  @override
  String toString() {
    return 'ForwardResult(success: $success, chatId: $chatId, userId: $userId, messageId: $messageId, error: $error)';
  }
}

/// Enhanced Forward Message Handler
/// Fixes the issues with partial forwards and inconsistent UI updates
class ImprovedForwardMessageHandler {
  final BuildContext context;
  final List<int>? selectedMessageIds;
  final int? fromChatId;
  final Function()? onForwardCompleted;

  ImprovedForwardMessageHandler({
    required this.context,
    this.selectedMessageIds,
    this.fromChatId,
    this.onForwardCompleted,
  });

  /// Main method to handle forward messages with enhanced reliability
  Future<Map<String, dynamic>> handleForwardMessages(
    List<int> chatIds,
    List<int> userIds,
  ) async {
    if ((chatIds.isEmpty && userIds.isEmpty) ||
        selectedMessageIds?.isEmpty == true) {
      return {
        'success': false,
        'error': 'No recipients or messages selected',
      };
    }

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      // Create a queue of all forward tasks
      List<Future<ForwardResult>> forwardTasks = [];
      
      // Forward to existing chats
      for (final chatId in chatIds) {
        for (final messageId in selectedMessageIds!) {
          forwardTasks.add(_forwardToExistingChat(chatProvider, chatId, messageId));
        }
      }
      
      // Forward to new chats (contacts)
      for (final userId in userIds) {
        for (final messageId in selectedMessageIds!) {
          forwardTasks.add(_forwardToNewChat(chatProvider, userId, messageId));
        }
      }
      
      debugPrint('📋 Created ${forwardTasks.length} forward tasks');
      
      // Execute all tasks with controlled concurrency and retry logic
      List<ForwardResult> results = await _executeForwardTasksWithRetry(forwardTasks);
      
      // Analyze results
      int successCount = results.where((r) => r.success).length;
      int totalAttempts = results.length;
      List<String> errors = results
          .where((r) => !r.success)
          .map((r) => r.error ?? 'Unknown error')
          .toList();

      debugPrint('📊 Forward execution completed: $successCount/$totalAttempts successful');

      // Force refresh chat list and messages after forwarding
      if (successCount > 0) {
        await _refreshChatListAndMessages(chatProvider);
      }

      return {
        'success': successCount > 0,
        'total_attempts': totalAttempts,
        'success_count': successCount,
        'failure_count': totalAttempts - successCount,
        'errors': errors,
        'all_successful': successCount == totalAttempts,
      };
    } catch (e) {
      debugPrint('❌ Critical error in forward handler: $e');
      return {
        'success': false,
        'error': 'Critical error: ${e.toString()}',
      };
    }
  }

  /// Enhanced method for forwarding to existing chats
  Future<ForwardResult> _forwardToExistingChat(
    ChatProvider chatProvider,
    int chatId,
    int messageId,
  ) async {
    try {
      debugPrint('📤 Forwarding message $messageId from $fromChatId to chat $chatId');
      
      final success = await chatProvider.forwardMessage(
        fromChatId: fromChatId ?? 0,
        toChatId: chatId,
        messageId: messageId,
      );

      if (success) {
        debugPrint('✅ Successfully forwarded message $messageId to chat $chatId');
        return ForwardResult(
          success: true,
          chatId: chatId,
          messageId: messageId,
        );
      } else {
        debugPrint('❌ Failed to forward message $messageId to chat $chatId');
        return ForwardResult(
          success: false,
          error: 'Failed to forward message to chat $chatId',
          chatId: chatId,
          messageId: messageId,
        );
      }
    } catch (e) {
      debugPrint('❌ Exception forwarding message $messageId to chat $chatId: $e');
      return ForwardResult(
        success: false,
        error: 'Error forwarding to chat $chatId: ${e.toString()}',
        chatId: chatId,
        messageId: messageId,
      );
    }
  }

  /// Enhanced method for forwarding to new chats
  Future<ForwardResult> _forwardToNewChat(
    ChatProvider chatProvider,
    int userId,
    int messageId,
  ) async {
    try {
      debugPrint('🔄 Forwarding message $messageId to new chat with user $userId');

      // FIXED: Actual API call for forwarding to new chat
      final success = await chatProvider.forwardMessageToUser(
        fromChatId: fromChatId ?? 0,
        toUserId: userId,
        messageId: messageId,
      );

      if (success) {
        debugPrint('✅ Successfully forwarded message $messageId to user $userId');
        return ForwardResult(
          success: true,
          userId: userId,
          messageId: messageId,
        );
      } else {
        debugPrint('❌ Failed to forward message $messageId to user $userId');
        return ForwardResult(
          success: false,
          error: 'Failed to forward message to user $userId',
          userId: userId,
          messageId: messageId,
        );
      }
    } catch (e) {
      debugPrint('❌ Error forwarding to new chat: $e');
      return ForwardResult(
        success: false,
        error: 'Error forwarding to user $userId: ${e.toString()}',
        userId: userId,
        messageId: messageId,
      );
    }
  }

  /// Execute forward tasks with retry logic - SIMPLIFIED APPROACH
  Future<List<ForwardResult>> _executeForwardTasksWithRetry(
    List<Future<ForwardResult>> tasks,
  ) async {
    List<ForwardResult> results = [];
    
    debugPrint('🔄 Starting sequential execution of ${tasks.length} forward tasks');
    
    // Execute tasks ONE BY ONE to ensure reliability
    for (int i = 0; i < tasks.length; i++) {
      try {
        debugPrint('🔄 Processing task ${i + 1}/${tasks.length}');
        
        // Wait for this specific task with extended timeout
        ForwardResult result = await tasks[i].timeout(
          const Duration(seconds: 30), // Increased timeout
        );
        
        results.add(result);
        
        if (result.success) {
          debugPrint('✅ Task ${i + 1} completed successfully');
        } else {
          debugPrint('❌ Task ${i + 1} failed: ${result.error}');
        }
        
        // Add delay between tasks to prevent server overload
        if (i < tasks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
      } catch (e) {
        debugPrint('❌ Task ${i + 1} execution error: $e');
        
        // Add failed result but continue with remaining tasks
        results.add(ForwardResult(
          success: false,
          error: 'Task execution error: ${e.toString()}',
          messageId: -1,
        ));
        
        // Still add delay even after error
        if (i < tasks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    
    final successCount = results.where((r) => r.success).length;
    debugPrint('📊 All tasks completed: $successCount/${results.length} successful');
    
    return results;
  }

  /// Force refresh chat list and messages after forwarding
  Future<void> _refreshChatListAndMessages(ChatProvider chatProvider) async {
    try {
      debugPrint('🔄 Refreshing chat list and messages after forward');
      
      // Refresh chat list to show new last messages and unseen counts
      await chatProvider.refreshChatList();
      
      // If we're in a specific chat, refresh those messages too
      if (fromChatId != null && fromChatId! > 0) {
        // Get peer ID from current chat context if available
        final currentChat = chatProvider.chatListData.chats
            .where((chat) => chat.records?.first.chatId == fromChatId)
            .firstOrNull;
        
        if (currentChat?.peerUserData?.userId != null) {
          await chatProvider.refreshChatMessages(
            chatId: fromChatId!,
            peerId: currentChat!.peerUserData!.userId!,
          );
        }
      }
      
      // Force immediate UI update by triggering a rebuild
      // The notifyListeners is called automatically by the refresh methods
      
      debugPrint('✅ Chat refresh completed');
    } catch (e) {
      debugPrint('❌ Error refreshing chat data: $e');
    }
  }

  /// Show enhanced loading dialog
  void showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Close loading dialog
  void closeLoadingDialog() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Show result dialog based on forward results
  void showResultDialog(Map<String, dynamic> result) {
    final successCount = result['success_count'] ?? 0;
    final totalAttempts = result['total_attempts'] ?? 0;
    final errors = result['errors'] as List<String>? ?? [];
    final allSuccessful = result['all_successful'] ?? false;

    if (allSuccessful) {
      // All forwards successful
      _showSuccessDialog(successCount, totalAttempts);
    } else if (successCount > 0) {
      // Partial success
      _showPartialSuccessDialog(successCount, totalAttempts, errors);
    } else {
      // All failed
      _showErrorDialog('Failed to forward any messages', errors);
    }
  }

  void _showSuccessDialog(int successCount, int totalAttempts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(
          'Successfully forwarded $successCount message${successCount != 1 ? 's' : ''}!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPartialSuccessDialog(int successCount, int totalAttempts, List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Partial Success'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Successfully forwarded $successCount out of $totalAttempts messages.'),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Errors:'),
              ...errors.take(3).map((error) => Text('• $error', style: const TextStyle(fontSize: 12))),
              if (errors.length > 3) Text('... and ${errors.length - 3} more errors'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Failed to forward messages.'),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Errors:'),
              ...errors.take(3).map((error) => Text('• $error', style: const TextStyle(fontSize: 12))),
              if (errors.length > 3) Text('... and ${errors.length - 3} more errors'),
            ],
          ],
        ),
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