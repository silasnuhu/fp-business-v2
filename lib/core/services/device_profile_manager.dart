// =============================================================================
// Device Profile Manager
// Detects device sound profile (Silent, Vibrate, General) using native platform channels
// =============================================================================

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:whoxa/utils/logger.dart';

enum DeviceRingerMode {
  silent,    // No sound, no vibration
  vibrate,   // Vibration only
  general,   // Sound with vibration
}

class DeviceProfileManager {
  static final DeviceProfileManager _instance = DeviceProfileManager._internal();
  static DeviceProfileManager get instance => _instance;
  DeviceProfileManager._internal();

  final _logger = ConsoleAppLogger.forModule('DeviceProfileManager');
  
  // State management
  bool _isInitialized = false;
  DeviceRingerMode _currentRingerMode = DeviceRingerMode.general;
  
  // Platform channel for native ringer mode detection
  static const platform = MethodChannel('primocys.device.profile');

  /// Initialize the device profile manager
  Future<void> initialize() async {
    try {
      _logger.i('📱 DeviceProfileManager: Initializing...');
      
      // Try to get initial ringer mode from native
      await _updateRingerModeFromNative();
      
      _isInitialized = true;
      _logger.i('✅ DeviceProfileManager: Initialized successfully');
    } catch (e) {
      _logger.e('❌ DeviceProfileManager: Failed to initialize: $e');
      // Set default mode
      _currentRingerMode = DeviceRingerMode.general;
      _isInitialized = true;
    }
  }

  /// Update ringer mode from native platform (preferred method)
  Future<void> _updateRingerModeFromNative() async {
    try {
      final String mode = await platform.invokeMethod('getRingerMode');
      _handleNativeRingerModeChange(mode);
      _logger.d('📱 Native ringer mode: $mode');
    } catch (e) {
      _logger.d('📱 Native ringer mode detection not available: $e');
      // Use safe default
      _currentRingerMode = DeviceRingerMode.general;
    }
  }

  /// Handle ringer mode changes from native
  void _handleNativeRingerModeChange(String mode) {
    switch (mode.toLowerCase()) {
      case 'silent':
        _currentRingerMode = DeviceRingerMode.silent;
        break;
      case 'vibrate':
        _currentRingerMode = DeviceRingerMode.vibrate;
        break;
      case 'normal':
      case 'general':
      default:
        _currentRingerMode = DeviceRingerMode.general;
        break;
    }
  }

  /// Get current ringer mode with fallback detection
  Future<DeviceRingerMode> getCurrentRingerMode() async {
    if (!_isInitialized) await initialize();
    
    try {
      // Try to get fresh mode from native first
      await _updateRingerModeFromNative();
    } catch (e) {
      // Use cached mode
      _logger.d('📱 Using cached ringer mode');
    }
    
    return _currentRingerMode;
  }

  /// Force refresh ringer mode
  Future<void> refreshRingerMode() async {
    try {
      await _updateRingerModeFromNative();
    } catch (e) {
      _logger.w('⚠️ Could not refresh ringer mode: $e');
    }
  }

  /// Check if device is in silent mode
  Future<bool> isSilentMode() async {
    final mode = await getCurrentRingerMode();
    return mode == DeviceRingerMode.silent;
  }

  /// Check if device is in vibrate mode
  Future<bool> isVibrateMode() async {
    final mode = await getCurrentRingerMode();
    return mode == DeviceRingerMode.vibrate;
  }

  /// Check if device is in general/sound mode
  Future<bool> isGeneralMode() async {
    final mode = await getCurrentRingerMode();
    return mode == DeviceRingerMode.general;
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      _isInitialized = false;
      _logger.i('✅ DeviceProfileManager: Disposed');
    } catch (e) {
      _logger.e('❌ DeviceProfileManager: Dispose failed: $e');
    }
  }

  // Getters
  DeviceRingerMode get currentRingerMode => _currentRingerMode;
  bool get isInitialized => _isInitialized;
}