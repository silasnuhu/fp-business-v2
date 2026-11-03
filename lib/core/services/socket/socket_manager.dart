import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:whoxa/core/services/socket/socket_event_controller.dart';
import 'package:whoxa/core/services/socket/socket_service.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/network_info.dart';

/// SocketManager - FIXED VERSION
/// A singleton class that manages socket connections throughout the application
class SocketManager {
  // Singleton pattern
  static final SocketManager _instance = SocketManager._internal();
  factory SocketManager() => _instance;

  // Dependencies
  final ConsoleAppLogger _logger = ConsoleAppLogger();
  late final NetworkInfo _networkInfo;
  late final SocketService _socketService;
  late final SocketEventController _socketEventController;

  // State tracking
  bool _initialized = false;
  bool _connectingInProgress = false;
  Timer? _reconnectTimer;
  bool _appInForeground = true;
  int _reconnectAttempts = 0;
  static const int kMaxReconnectAttempts = 3; // Reduced attempts

  // Value notifier for connection status updates
  final ValueNotifier<bool> connectionStatus = ValueNotifier<bool>(false);

  // Stream subscription for connection state changes
  StreamSubscription? _connectionSubscription;

  // Private constructor with dependency injection
  SocketManager._internal() {
    _networkInfo = GetIt.instance<NetworkInfo>();
    _socketService = GetIt.instance<SocketService>();
    _socketEventController = GetIt.instance<SocketEventController>();
  }

  /// Initialize socket connections when user is logged in
  Future<void> initializeSocket() async {
    if (_initialized || _connectingInProgress) {
      _logger.i('Socket manager already initialized or initializing');
      return;
    }

    _connectingInProgress = true;

    try {
      _logger.i('Initializing socket manager');

      // Check if user is logged in
      final token = await SecurePrefs.getString(SecureStorageKeys.TOKEN);
      if (token == null || token.isEmpty) {
        _logger.i('User not logged in, skipping socket initialization');
        _connectingInProgress = false;
        return;
      }

      // Initialize socket service ONCE
      _socketService.initialize(
        authData: {'token': token},
        maxRetryAttempts: 3,
        retryDelayMs: 5000,
      );

      // Cancel existing subscription if any
      _connectionSubscription?.cancel();

      // Listen to connection state changes
      _connectionSubscription = _socketService.connectionState.listen(
        _handleSocketConnectionStateChange,
        onError: (error) {
          _logger.e('Error in connection state stream', error);
          connectionStatus.value = false;
        },
      );

      // Connect to socket
      final connected = await _socketService.connect();

      if (connected) {
        // Initialize event controller only after successful connection
        await _socketEventController.initialize();
        _logger.i('Socket and event controller initialized successfully');
      }

      _initialized = true;
    } catch (e) {
      _logger.e('Error initializing socket manager', e);
      _initialized = true; // Still mark as initialized to allow reconnection
    } finally {
      _connectingInProgress = false;
    }
  }

  // Handle socket connection state changes - SIMPLIFIED
  void _handleSocketConnectionStateChange(SocketConnectionState state) {
    switch (state) {
      case SocketConnectionState.connected:
        connectionStatus.value = true;
        _reconnectAttempts = 0; // Reset counter on successful connection
        _logger.i('Socket manager: Socket connected');
        break;

      case SocketConnectionState.disconnected:
        connectionStatus.value = false;
        _logger.i('Socket manager: Socket disconnected');

        // ONLY schedule reconnection if we haven't hit the limit
        if (_appInForeground &&
            _initialized &&
            _reconnectAttempts < kMaxReconnectAttempts) {
          _scheduleReconnection();
        }
        break;

      case SocketConnectionState.error:
        connectionStatus.value = false;
        _logger.e('Socket manager: Socket error');

        // Try to reconnect on error too, but with limits
        if (_appInForeground &&
            _initialized &&
            _reconnectAttempts < kMaxReconnectAttempts) {
          _scheduleReconnection();
        }
        break;

      case SocketConnectionState.connecting:
      case SocketConnectionState.reconnecting:
        // Just log, don't interfere
        _logger.i('Socket manager: Socket state - $state');
        break;
    }
  }

  // Schedule reconnection with longer delays - FIXED
  void _scheduleReconnection() {
    // Cancel any existing reconnect timer
    _reconnectTimer?.cancel();

    // Check if we've exceeded max attempts
    if (_reconnectAttempts >= kMaxReconnectAttempts) {
      _logger.w(
        'Socket manager: Max reconnection attempts reached: $kMaxReconnectAttempts',
      );
      return;
    }

    // Use longer delays: 5s, 10s, 20s
    final delays = [5000, 10000, 20000];
    final delay = delays[_reconnectAttempts.clamp(0, delays.length - 1)];
    _reconnectAttempts++;

    _logger.i(
      'Socket manager: Scheduling reconnection attempt $_reconnectAttempts in ${delay}ms',
    );

    // Schedule reconnection attempt
    _reconnectTimer = Timer(Duration(milliseconds: delay), () async {
      if (await _networkInfo.isConnected) {
        _logger.i(
          'Socket manager: Executing reconnection attempt $_reconnectAttempts',
        );
        await _socketService.connect();
      } else {
        _logger.w('Socket manager: Network unavailable, will retry later');
        // Retry network check after some time
        _scheduleReconnection();
      }
    });
  }

  /// Disconnect socket when user logs out
  void disconnectSocket() {
    if (!_initialized) return;

    try {
      _logger.i('Socket manager: Disconnecting socket');

      // Cancel any pending reconnection attempts
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;

      // Disconnect the socket
      _socketService.disconnect();

      // Update connection status
      connectionStatus.value = false;
    } catch (e) {
      _logger.e('Error disconnecting socket', e);
    }
  }

  /// Reset initialized state (useful after logout)
  void reset() {
    try {
      _logger.i('Socket manager: Resetting all socket connections');
      
      // Cancel any pending reconnection attempts
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
      _connectingInProgress = false;
      
      // Cancel connection subscription to prevent further state changes
      _connectionSubscription?.cancel();
      _connectionSubscription = null;
      
      // ✅ FIXED: Use reset() instead of closeSocket() to fully reset the singleton
      _socketService.reset();
      
      // Update connection status
      connectionStatus.value = false;
      
      // Mark as uninitialized
      _initialized = false;
      
      _logger.i('Socket manager: Reset completed');
    } catch (e) {
      _logger.e('Error during socket manager reset', e);
    }
  }

  /// Check connection status
  bool get isConnected {
    try {
      if (!_initialized) return false;
      return _socketService.isConnected;
    } catch (e) {
      _logger.e('Error checking connection status', e);
      return false;
    }
  }

  /// Handle user authentication updates
  Future<void> handleAuthChange() async {
    final token = await SecurePrefs.getString(SecureStorageKeys.TOKEN);

    if (token == null || token.isEmpty) {
      // User logged out
      reset();
    } else if (_initialized) {
      // Token updated, update auth data
      try {
        await _socketService.updateAuthData({'token': token});
      } catch (e) {
        _logger.e('Error updating auth data', e);
      }
    } else {
      // Not initialized, but we have a token - initialize
      await initializeSocket();
    }
  }

  /// Reconnect socket if connection was dropped (gentle reconnection)
  Future<bool> reconnectIfNeeded() async {
    if (!_initialized || _connectingInProgress) {
      _logger.i('Cannot reconnect: not initialized or connection in progress');
      return false;
    }

    // If already connected, no need to reconnect
    if (_socketService.isConnected) {
      _logger.i('Socket already connected, no reconnection needed');
      return true;
    }

    _connectingInProgress = true;

    try {
      _logger.i('Socket disconnected, attempting to reconnect');

      // Check network first
      final hasConnection = await _networkInfo.isConnected;
      if (!hasConnection) {
        _logger.w('No network connection available for reconnection');
        _connectingInProgress = false;
        return false;
      }

      // Check if we have a valid token
      final token = await SecurePrefs.getString(SecureStorageKeys.TOKEN);
      if (token == null || token.isEmpty) {
        _logger.w('No authentication token available for reconnection');
        _connectingInProgress = false;
        return false;
      }

      // Attempt to connect
      final result = await _socketService.connect();
      _connectingInProgress = false;

      if (result) {
        _logger.i('Reconnection successful');
        // Make sure event controller is initialized
        if (_socketEventController.isConnected != result) {
          await _socketEventController.initialize();
        }
      } else {
        _logger.w('Reconnection failed');
      }

      return result;
    } catch (e) {
      _logger.e('Error during reconnection', e);
      _connectingInProgress = false;
      return false;
    }
  }

  /// Force a reconnection attempt (aggressive reconnection)
  Future<bool> forceReconnect() async {
    try {
      // Cancel any pending reconnection attempts
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;

      // Get fresh token
      final token = await SecurePrefs.getString(SecureStorageKeys.TOKEN);
      if (token == null || token.isEmpty) {
        _logger.i('No token available for forced reconnection');
        return false;
      }

      _logger.i('Force reconnecting socket');

      // Disconnect first if connected
      if (_socketService.isConnected) {
        _socketService.disconnect();
        // Wait a bit before reconnecting
        await Future.delayed(Duration(milliseconds: 1000));
      }

      // Update auth data with fresh token
      await _socketService.updateAuthData({'token': token});

      // Reconnect
      return await _socketService.connect();
    } catch (e) {
      _logger.e('Error during forced reconnection', e);
      return false;
    }
  }

  /// Update app foreground state
  void setAppForegroundState(bool inForeground) {
    _appInForeground = inForeground;

    // If coming back to foreground, check connection
    if (inForeground &&
        _initialized &&
        !isConnected &&
        _reconnectAttempts < kMaxReconnectAttempts) {
      _scheduleReconnection();
    }
  }

  /// Cleanup resources
  void dispose() {
    _reconnectTimer?.cancel();
    _connectionSubscription?.cancel();
  }
}
