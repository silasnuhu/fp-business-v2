// contact_list_integration_example.dart
// This shows how to integrate the ImprovedForwardMessageHandler into your ContactListScreen

import 'package:flutter/material.dart';
import 'package:whoxa/featuers/contacts/screen/improved_contact_list_forward.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

/// Example of how to replace the existing _handleForwardMessages method
class ContactListScreenIntegration {
  
  /// REPLACE YOUR EXISTING _handleForwardMessages METHOD WITH THIS:
  Future<void> handleForwardMessages(
    BuildContext context,
    List<int> chatIds,
    List<int> userIds, {
    List<int>? selectedMessageIds,
    int? fromChatId,
    Function()? onForwardCompleted,
  }) async {
    
    // Create the improved handler
    final forwardHandler = ImprovedForwardMessageHandler(
      context: context,
      selectedMessageIds: selectedMessageIds,
      fromChatId: fromChatId,
      onForwardCompleted: onForwardCompleted,
    );

    // Show loading dialog
    forwardHandler.showLoadingDialog(
      '${AppString.forwarding} ${selectedMessageIds?.length ?? 0} ${AppString.homeScreenString.messages}...',
    );

    try {
      // Execute the forward operation with improved reliability
      final result = await forwardHandler.handleForwardMessages(chatIds, userIds);
      
      // Close loading dialog
      forwardHandler.closeLoadingDialog();

      // Handle the result
      if (result['all_successful'] == true) {
        // All forwards successful
        if (!context.mounted) return;
        Navigator.of(context).pop(); // Close forward screen
        
        // Trigger completion callback
        if (onForwardCompleted != null) {
          onForwardCompleted();
        }
        
        // Navigate back to chat list - the handler already refreshed the data
        if (!context.mounted) return;
        _navigateToChatListWithRefresh(context);
        
      } else if (result['success_count'] > 0) {
        // Show result dialog for partial success or complete failure
        forwardHandler.showResultDialog(result);
      } else {
        // Show error dialog for complete failure
        forwardHandler.showResultDialog(result);
      }
      
    } catch (e) {
      // Close loading dialog on error
      forwardHandler.closeLoadingDialog();
      
      // Show error dialog
      final errorResult = {
        'success': false,
        'total_attempts': chatIds.length + userIds.length,
        'success_count': 0,
        'failure_count': chatIds.length + userIds.length,
        'errors': ['Critical error: ${e.toString()}'],
        'all_successful': false,
      };
      
      forwardHandler.showResultDialog(errorResult);
    }
  }

  /// Enhanced navigation method
  static void _navigateToChatListWithRefresh(BuildContext context) {
    // Navigate back to the main chat list screen
    Navigator.of(context).popUntil((route) => route.isFirst);
    
    // The refresh is already handled by the ImprovedForwardMessageHandler
    // So no need for additional refresh calls here
  }
}

/// INTEGRATION STEPS:
/// 
/// 1. Add the import at the top of your contact_list.dart:
///    import 'package:whoxa/featuers/contacts/screen/improved_contact_list_forward.dart';
///
/// 2. Replace your existing _handleForwardMessages method with:
/// 
///    Future<void> _handleForwardMessages(
///      List<int> chatIds,
///      List<int> userIds,
///    ) async {
///      await ContactListScreenIntegration.handleForwardMessages(
///        context,
///        chatIds,
///        userIds,
///        selectedMessageIds: widget.selectedMessageIds,
///        fromChatId: widget.fromChatId,
///        onForwardCompleted: widget.onForwardCompleted,
///      );
///    }
///
/// 3. Remove these old methods (they're replaced by the new handler):
///    - _forwardToNewChat
///    - All the dialog methods (_showLoadingDialog, _closeLoadingDialog, etc.)
///    - The old _navigateToChatListWithRefresh (use the static one above)
///
/// 4. That's it! Your forward feature will now:
///    ✅ Handle all API calls reliably without stopping midway
///    ✅ Use controlled concurrency (3 requests at a time)
///    ✅ Include retry logic and proper error handling  
///    ✅ Refresh chat list and messages consistently
///    ✅ Show proper success/error dialogs
///    ✅ Update UI consistently without manual refresh needed