// =============================================================================
// Cold Start Notification Handler
// Handles navigation to call screen when app is launched from notification
// =============================================================================

import 'dart:async';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/featuers/call/call_manager.dart';
import 'package:whoxa/utils/logger.dart';

class ColdStartHandler {
  static final ColdStartHandler _instance = ColdStartHandler._internal();
  factory ColdStartHandler() => _instance;
  ColdStartHandler._internal();

  final _logger = ConsoleAppLogger.forModule('ColdStartHandler');

  // Storage for pending notification data
  Map<String, dynamic>? _pendingCallData;
  bool _isHandlingNotification = false;

  /// Store call data for handling after app initialization
  void storePendingCallData(Map<String, dynamic> callData) {
    _pendingCallData = callData;
    _logger.i('📱 Stored pending call data for cold start: $callData');
  }

  /// ✅ IMPROVED: Handle pending notification with splash coordination
  Future<void> handlePendingNotification() async {
    if (_pendingCallData == null || _isHandlingNotification) {
      return;
    }

    _isHandlingNotification = true;
    _logger.i('🚀 Handling pending call notification from splash screen');

    try {
      // Wait for navigation to be ready
      await _waitForNavigationReady();

      // ✅ IMPROVED: Shorter wait since splash screen now coordinates with us
      await Future.delayed(Duration(milliseconds: 500));

      // Check if navigation context is still valid
      if (NavigationHelper.context == null) {
        throw Exception('Navigation context lost during cold start');
      }

      // Initialize call manager
      final callManager = CallManager.instance;
      if (!callManager.isInitialized) {
        await callManager.initialize();
      }

      // Set up call state in CallManager first
      final socketEventData = {
        'call': {
          'chat_id': _pendingCallData!['chatId'],
          'call_id': _pendingCallData!['callId'],
          'room_id': _pendingCallData!['roomId'] ?? _pendingCallData!['peerId'],
          'call_type': _pendingCallData!['callType'],
          'peer_id': _pendingCallData!['peerId'],
          'call_status': 'ringing',
        },
        'user': {
          'full_name': _pendingCallData!['callerName'],
          'user_id': _pendingCallData!['chatId'],
        },
      };

      // Initialize incoming call state in CallManager — this alone already
      // triggers NavigationHelper.handleIncomingCall() once ringing state is
      // set (see CallManager._handleIncomingCall). Calling
      // NavigationHelper.handleIncomingCall() again here used to push the
      // call screen a second time, and forceResetNavigationState() right
      // before it defeated the dedup guard that would otherwise have caught
      // the duplicate.
      await callManager.handleIncomingCallFromNotification(socketEventData);

      _logger.i('✅ Successfully handled call notification from splash');
    } catch (e) {
      _logger.e('❌ Error handling call notification: $e');
      // Fallback: Try direct navigation
      try {
        NavigationHelper.forceResetNavigationState();
        await Future.delayed(Duration(milliseconds: 200));
        NavigationHelper.handleIncomingCall(_pendingCallData!);
      } catch (fallbackError) {
        _logger.e('❌ Fallback navigation failed: $fallbackError');
      }
    } finally {
      // ✅ IMPROVED: Clear data immediately since splash coordinated with us
      _pendingCallData = null;
      _isHandlingNotification = false;
    }
  }

  /// Wait for navigation context to be ready
  Future<void> _waitForNavigationReady() async {
    int attempts = 0;
    const maxAttempts =
        50; // ✅ IMPROVED: 5 seconds max wait (faster since splash coordinates)

    while (attempts < maxAttempts) {
      if (NavigationHelper.context != null) {
        _logger.i('✅ Navigation context ready after ${attempts * 100}ms');
        return;
      }
      await Future.delayed(Duration(milliseconds: 100));
      attempts++;
    }

    throw Exception(
      'Navigation context not ready after ${maxAttempts * 100}ms',
    );
  }

  /// Check if there's pending call data
  bool get hasPendingCallData => _pendingCallData != null;

  /// Check if currently handling a notification
  bool get isHandlingNotification => _isHandlingNotification;

  /// Clear any pending call data
  void clearPendingCallData() {
    _pendingCallData = null;
    _isHandlingNotification = false;
  }
}
