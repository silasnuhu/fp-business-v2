// =============================================================================
// Enhanced Call Notification Manager
// Handles incoming call notifications based on device sound profile
// - Silent mode: No sound or vibration
// - Vibrate mode: Vibration only
// - General/Sound mode: Custom ringtone with loop
// =============================================================================

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/core/services/call_audio_manager.dart';
import 'package:whoxa/core/services/device_profile_manager.dart';
import 'package:whoxa/core/services/local_notification_service.dart';

class CallNotificationManager {
  static final CallNotificationManager _instance = CallNotificationManager._internal();
  static CallNotificationManager get instance => _instance;
  CallNotificationManager._internal();

  final _logger = ConsoleAppLogger.forModule('CallNotificationManager');
  
  // State management
  bool _isInitialized = false;
  Timer? _vibrationTimer;
  Timer? _ringtoneTimer;
  bool _isNotificationActive = false;
  
  // Platform channel for native ringer mode detection
  static const platform = MethodChannel('primocys.call.notification');

  /// Initialize the notification manager
  Future<void> initialize() async {
    try {
      _logger.i('🔔 CallNotificationManager: Initializing...');
      
      // Initialize device profile manager
      await DeviceProfileManager.instance.initialize();
      
      _isInitialized = true;
      _logger.i('✅ CallNotificationManager: Initialized successfully');
    } catch (e) {
      _logger.e('❌ CallNotificationManager: Failed to initialize: $e');
      rethrow;
    }
  }


  /// Start incoming call notification based on device sound profile
  Future<void> startIncomingCallNotification() async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.i('🔔 Starting incoming call notification...');
      
      // Get current ringer mode from device profile manager
      final currentRingerMode = await DeviceProfileManager.instance.getCurrentRingerMode();
      
      // Stop any existing notification
      await stopIncomingCallNotification();
      
      _isNotificationActive = true;

      switch (currentRingerMode) {
        case DeviceRingerMode.silent:
          _logger.i('🔇 Device in silent mode - no notification');
          break;

        case DeviceRingerMode.vibrate:
          _logger.i('📳 Device in vibrate mode - starting vibration');
          await _startVibrationPattern();
          break;

        case DeviceRingerMode.general:
          _logger.i('🔔 Device in general mode - starting ringtone and vibration');
          await _startRingtoneAndVibration();
          break;
      }

      _logger.i('✅ Incoming call notification started');
    } catch (e) {
      _logger.e('❌ Failed to start incoming call notification: $e');
      _isNotificationActive = false;
    }
  }

  /// Start vibration pattern for vibrate mode
  Future<void> _startVibrationPattern() async {
    try {
      // Stop any existing vibration timer first
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      
      // Start continuous vibration pattern using native
      _vibrationTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
        if (!_isNotificationActive) {
          timer.cancel();
          return;
        }
        
        try {
          await platform.invokeMethod('startVibration');
        } catch (e) {
          _logger.w('⚠️ Vibration error: $e');
        }
      });

      // Start first vibration immediately
      await platform.invokeMethod('startVibration');
      
      _logger.d('📳 Vibration pattern started');
    } catch (e) {
      _logger.e('❌ Failed to start vibration: $e');
    }
  }

  /// Start ringtone and vibration for general mode
  Future<void> _startRingtoneAndVibration() async {
    try {
      // Start custom ringtone using CallAudioManager
      await CallAudioManager.instance.startIncomingCallRingtone();
      
      // Also start vibration pattern alongside ringtone
      await _startVibrationPattern();
      
      _logger.d('🔔 Ringtone and vibration started');
    } catch (e) {
      _logger.e('❌ Failed to start ringtone and vibration: $e');
      
      // Fallback to system ringtone
      try {
        await _startSystemRingtone();
        await _startVibrationPattern();
      } catch (fallbackError) {
        _logger.e('❌ Fallback ringtone also failed: $fallbackError');
      }
    }
  }

  /// Start system ringtone as fallback
  Future<void> _startSystemRingtone() async {
    try {
      // Use platform channel to play system ringtone
      await platform.invokeMethod('playSystemRingtone');
      _logger.d('🔔 System ringtone started');
    } catch (e) {
      _logger.e('❌ Failed to start system ringtone: $e');
    }
  }

  /// Stop all incoming call notifications
  Future<void> stopIncomingCallNotification() async {
    try {
      _logger.i('🔔 Stopping incoming call notification...');
      
      _isNotificationActive = false;

      // Stop vibration
      await _stopVibration();
      
      // Stop ringtone
      await _stopRingtone();
      
      // Stop system ringtone
      await _stopSystemRingtone();

      // Silencing the ringtone is not enough — the "<name> is calling..."
      // entry stays in the notification shade until it is cancelled, so a
      // missed/declined/answered call would leave a dead call notification
      // behind that still offers to answer it.
      await CallNotificationService().dismissIncomingCallNotifications(
        reason: 'call no longer ringing',
      );

      _logger.i('✅ Incoming call notification stopped');
    } catch (e) {
      _logger.e('❌ Failed to stop incoming call notification: $e');
    }
  }

  /// Handle call acceptance - stops notification and ringtone
  Future<void> onCallAccepted({bool useSpeaker = false}) async {
    try {
      _logger.i('📞 Call accepted - stopping all notifications...');
      
      // Stop all incoming call notifications
      await stopIncomingCallNotification();
      
      // Configure audio for call using CallAudioManager
      await CallAudioManager.instance.configureAudioForCall(useSpeaker: useSpeaker);
      
      _logger.i('✅ Call acceptance handled successfully');
    } catch (e) {
      _logger.e('❌ Failed to handle call acceptance: $e');
    }
  }

  /// Handle call rejection - stops notification and ringtone
  Future<void> onCallRejected() async {
    try {
      _logger.i('📞 Call rejected - stopping all notifications...');
      
      // Stop all incoming call notifications
      await stopIncomingCallNotification();
      
      // Clean up audio using CallAudioManager
      await CallAudioManager.instance.cleanup();
      
      _logger.i('✅ Call rejection handled successfully');
    } catch (e) {
      _logger.e('❌ Failed to handle call rejection: $e');
    }
  }

  /// Stop vibration
  Future<void> _stopVibration() async {
    try {
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      
      await platform.invokeMethod('stopVibration');
      _logger.d('📳 Vibration stopped');
    } catch (e) {
      _logger.w('⚠️ Error stopping vibration: $e');
    }
  }

  /// Stop custom ringtone
  Future<void> _stopRingtone() async {
    try {
      await CallAudioManager.instance.stopRingtone();
      _logger.d('🔔 Custom ringtone stopped');
    } catch (e) {
      _logger.w('⚠️ Error stopping custom ringtone: $e');
    }
  }

  /// Stop system ringtone
  Future<void> _stopSystemRingtone() async {
    try {
      await platform.invokeMethod('stopSystemRingtone');
      _logger.d('🔔 System ringtone stopped');
    } catch (e) {
      _logger.w('⚠️ Error stopping system ringtone: $e');
    }
  }

  /// Emergency stop - immediately halt all notifications
  Future<void> emergencyStopNotification() async {
    try {
      _logger.w('🚨 Emergency notification stop initiated...');
      
      _isNotificationActive = false;
      
      // Cancel timers immediately
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      _ringtoneTimer?.cancel();
      _ringtoneTimer = null;
      
      // Stop all without waiting for completion
      platform.invokeMethod('stopVibration').catchError((e) => _logger.w('Emergency vibration stop error: $e'));
      platform.invokeMethod('stopSystemRingtone').catchError((e) => _logger.w('Emergency ringtone stop error: $e'));
      
      _logger.w('🚨 Emergency notification stop completed');
    } catch (e) {
      _logger.e('❌ Emergency stop failed: $e');
    }
  }

  /// Get current ringer mode
  Future<DeviceRingerMode> getCurrentRingerMode() async => 
      await DeviceProfileManager.instance.getCurrentRingerMode();
  
  /// Check if notification is active
  bool get isNotificationActive => _isNotificationActive;
  
  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// 🚧 DEVELOPER TEST: Test call notification in debug mode only
  Future<void> testCallNotification() async {
    // Only work in debug mode
    assert(() {
      _testCallNotificationInternal();
      return true;
    }());
  }

  /// Internal test method - only executed in debug mode
  Future<void> _testCallNotificationInternal() async {
    try {
      _logger.i('🧪 DEVELOPER TEST: Starting call notification test...');
      
      if (!_isInitialized) await initialize();
      
      // Show test notification info
      _logger.i('🧪 TEST: Device will play call ringtone based on current sound profile');
      _logger.i('🧪 TEST: - Silent mode: No sound/vibration');
      _logger.i('🧪 TEST: - Vibrate mode: Vibration only');  
      _logger.i('🧪 TEST: - Normal mode: Custom ringtone + vibration');
      
      // Get and display current ringer mode
      final currentMode = await getCurrentRingerMode();
      _logger.i('🧪 TEST: Current device mode: $currentMode');
      
      // Start test notification
      await startIncomingCallNotification();
      
      // Auto-stop after 10 seconds for testing
      Timer(Duration(seconds: 10), () async {
        _logger.i('🧪 TEST: Auto-stopping test notification after 10 seconds');
        await stopIncomingCallNotification();
        _logger.i('🧪 TEST: Call notification test completed ✅');
      });
      
    } catch (e) {
      _logger.e('🧪 TEST ERROR: Failed to run test notification: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await stopIncomingCallNotification();
      _isInitialized = false;
      _logger.i('✅ CallNotificationManager: Disposed');
    } catch (e) {
      _logger.e('❌ CallNotificationManager: Dispose failed: $e');
    }
  }
}