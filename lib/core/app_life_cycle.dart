import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:whoxa/core/network/network_listner.dart';
import 'package:whoxa/core/services/socket/socket_manager.dart';
import 'package:whoxa/featuers/call/call_manager.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

/// AppLifecycleManager - FIXED VERSION
/// Manages app lifecycle events and maintains socket connections appropriately
/// Connects sockets when app is in foreground and manages background state
class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({super.key, required this.child});

  @override
  AppLifecycleManagerState createState() => AppLifecycleManagerState();
}

class AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  final _logger = ConsoleAppLogger.forModule('AppLifecycleManager');

  // Use GetIt to get the same instances
  late final SocketManager _socketManager;
  late final NetworkListener _networkListener;

  bool _wasConnectedBeforePause = false;
  bool _appResumedFirstTime = true;
  DateTime? _lastPausedTime;
  bool _isUserLoggedIn = false;

  // Constants - Increased background duration to reduce unnecessary reconnections
  static const Duration kReconnectAfterBackground = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Get instances from GetIt instead of creating new ones
    _socketManager = GetIt.instance<SocketManager>();
    _networkListener = GetIt.instance<NetworkListener>();

    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _logger.i('Initializing AppLifecycleManager services');

      // Check if user is logged in
      await _checkUserLoginStatus();

      // Listen for network state changes
      _networkListener.onConnectivityChanged.listen(_handleNetworkStateChange);

      // Don't initialize socket here - let the login flow handle it
      _logger.i('AppLifecycleManager services initialized');
    } catch (e) {
      _logger.e('Error initializing AppLifecycleManager services', e);
    }
  }

  Future<void> _checkUserLoginStatus() async {
    try {
      final token = await SecurePrefs.getString(SecureStorageKeys.TOKEN);
      _isUserLoggedIn = token != null && token.isNotEmpty;
      _logger.i('User login status: $_isUserLoggedIn');
    } catch (e) {
      _logger.e('Error checking user login status', e);
      _isUserLoggedIn = false;
    }
  }

  @override
  void dispose() {
    _logger.i('Disposing AppLifecycleManager');
    WidgetsBinding.instance.removeObserver(this);
    // Don't dispose services that are managed by GetIt
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logger.i('App lifecycle state changed: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;

      case AppLifecycleState.inactive:
        // App is inactive but still visible (e.g., during phone calls)
        _logger.d('App is inactive');
        break;

      case AppLifecycleState.paused:
        _handleAppPaused();
        break;

      case AppLifecycleState.detached:
        _handleAppDetached();
        break;

      case AppLifecycleState.hidden:
        // App is hidden by the system
        _logger.d('App is hidden');
        break;
    }
  }

  void _handleAppResumed() async {
    _logger.i('App resumed');

    // A call that started ringing while we were backgrounded (delivered over
    // the still-alive socket) has no screen yet on iOS — surface it now that
    // the app is visible. Guarded + dedupe-safe, so a no-op in every other
    // case. Runs ahead of the login/socket bookkeeping below.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      try {
        CallManager.instance.resurfaceIncomingCallScreenIfRinging();
      } catch (e) {
        _logger.e('Error resurfacing ringing call on resume: $e');
      }
    });

    // Update socket manager about foreground state
    _socketManager.setAppForegroundState(true);

    // Check current login status
    await _checkUserLoginStatus();

    // Only handle socket logic if user is logged in
    if (!_isUserLoggedIn) {
      _logger.i('User not logged in, skipping socket operations');
      return;
    }

    // Sync block status when app comes to foreground to catch changes that happened while inactive
    try {
      final chatProvider = GetIt.instance.get<ChatProvider>();
      await chatProvider.syncBlockStatusOnForeground();
    } catch (e) {
      _logger.e('Error syncing block status on app resume: $e');
    }

    // If this is not the first resume (app has been to background before)
    if (!_appResumedFirstTime) {
      _logger.i(
        'App resumed after background - checking conditions for reconnection',
      );

      // Check if we need to reconnect after long background time
      final shouldReconnectAfterLongBackground =
          _shouldReconnectAfterBackground();
      final currentlyConnected = _socketManager.isConnected;

      _logger.i(
        'Reconnection check - Was connected before pause: $_wasConnectedBeforePause, '
        'Currently connected: $currentlyConnected, '
        'Should reconnect after long background: $shouldReconnectAfterLongBackground',
      );

      // Only attempt reconnection if:
      // 1. We were connected before pause AND currently not connected, OR
      // 2. We've been in background for a long time and should refresh connection
      if ((_wasConnectedBeforePause && !currentlyConnected) ||
          shouldReconnectAfterLongBackground) {
        _logger.i('Attempting reconnection due to app resume conditions');

        // Check network first
        final isNetworkConnected =
            await _networkListener.checkCurrentConnectivity();
        if (isNetworkConnected) {
          // Use a delay to avoid immediate reconnection attempts
          Future.delayed(Duration(seconds: 2), () async {
            if (_isUserLoggedIn && mounted) {
              await _socketManager.reconnectIfNeeded();
            }
          });
        } else {
          _logger.w('Network not available, skipping reconnection attempt');
        }
      } else {
        _logger.i(
          'No reconnection needed - socket is already connected or wasn\'t connected before',
        );
      }
    } else {
      _logger.i(
        'First app resume - socket should already be initialized by login flow',
      );
    }

    _appResumedFirstTime = false;
  }

  bool _shouldReconnectAfterBackground() {
    if (_lastPausedTime == null) return false;

    final timeInBackground = DateTime.now().difference(_lastPausedTime!);
    final shouldReconnect = timeInBackground >= kReconnectAfterBackground;

    _logger.i(
      'Background duration check - Time in background: ${timeInBackground.inMinutes} minutes, '
      'Should reconnect: $shouldReconnect',
    );

    return shouldReconnect;
  }

  void _handleAppPaused() {
    _logger.i('App paused');

    // Remember if we were connected before pausing (only if user is logged in)
    if (_isUserLoggedIn) {
      _wasConnectedBeforePause = _socketManager.isConnected;
      _logger.i(
        'Socket connection status before pause: $_wasConnectedBeforePause',
      );
    } else {
      _wasConnectedBeforePause = false;
    }

    // Remember when we paused
    _lastPausedTime = DateTime.now();

    // Update socket manager about background state
    _socketManager.setAppForegroundState(false);

    // Keep socket connected in background for notifications
    // Note: You could disconnect here to save battery if background messaging isn't needed
    _logger.i(
      'App moved to background - keeping socket connected for notifications',
    );
  }

  void _handleAppDetached() {
    _logger.i('App detached - cleaning up resources');

    // Only disconnect if user is logged in (otherwise nothing to disconnect)
    if (_isUserLoggedIn) {
      // Don't fully disconnect - just update the state
      // Full disconnection should only happen on logout
      _socketManager.setAppForegroundState(false);
    }
  }

  void _handleNetworkStateChange(bool isConnected) {
    _logger.i(
      'Network state changed: ${isConnected ? 'Connected' : 'Disconnected'}',
    );

    if (isConnected && _isUserLoggedIn) {
      // When network becomes available, try to reconnect socket if needed
      // Add a small delay to ensure network is stable
      Future.delayed(Duration(seconds: 3), () async {
        if (_isUserLoggedIn && mounted && !_socketManager.isConnected) {
          _logger.i('Network restored - attempting socket reconnection');
          await _socketManager.reconnectIfNeeded();
        }
      });
    } else if (isConnected && !_isUserLoggedIn) {
      _logger.i(
        'Network connected but user not logged in - no socket action needed',
      );
    } else {
      _logger.i(
        'Network disconnected - socket will handle reconnection when network returns',
      );
    }
  }

  // Method to be called when user logs in
  void onUserLoggedIn() {
    _logger.i('User logged in - updating lifecycle manager state');
    _isUserLoggedIn = true;
    _appResumedFirstTime = true; // Reset for proper handling
  }

  // Method to be called when user logs out
  void onUserLoggedOut() {
    _logger.i('User logged out - updating lifecycle manager state');
    _isUserLoggedIn = false;
    _wasConnectedBeforePause = false;
    _lastPausedTime = null;
    _appResumedFirstTime = true;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// Extension to access lifecycle manager from anywhere in the app
extension AppLifecycleManagerExtension on BuildContext {
  AppLifecycleManagerState? get lifecycleManager {
    return findAncestorStateOfType<AppLifecycleManagerState>();
  }
}
