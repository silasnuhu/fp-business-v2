import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:whoxa/utils/logger.dart';

/// NetworkListener
/// A class that monitors network connectivity changes
/// Provides streams and callbacks for network state changes
class NetworkListener {
  final ConsoleAppLogger _logger = ConsoleAppLogger();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;

  // Controller for network state changes
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  // Observable stream for network state changes
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  // Current connectivity status
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Initialize the network listener
  Future<void> initialize() async {
    try {
      _logger.i('Initializing NetworkListener');

      // Initial connectivity check
      final results = await _connectivity.checkConnectivity();
      _isConnected =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      _connectivityController.add(_isConnected);
      _logger.i(
        'Initial connection state: ${_isConnected ? 'Connected' : 'Disconnected'}',
      );

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        List<ConnectivityResult> results,
      ) async {
        await _handleConnectivityChange(results);
      });
    } catch (e) {
      _logger.e('Error initializing NetworkListener', e);
      // Set a default status if initialization fails
      _isConnected = false;
    }
  }

  /// Handle connectivity status changes
  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    final bool wasConnected = _isConnected;
    _isConnected =
        results.isNotEmpty && results.first != ConnectivityResult.none;

    // Only notify if the state actually changed
    if (wasConnected != _isConnected) {
      _logger.i(
        'Connectivity changed: ${_isConnected ? 'Connected' : 'Disconnected'}',
      );
      _connectivityController.add(_isConnected);
    }
  }

  /// Check current connectivity status
  Future<bool> checkCurrentConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isConnected =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      return _isConnected;
    } catch (e) {
      _logger.e('Error checking current connectivity', e);
      return false;
    }
  }

  /// Manually trigger a connectivity check
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final result =
          results.isNotEmpty && results.first != ConnectivityResult.none;

      // If state changed, notify listeners
      if (_isConnected != result) {
        _isConnected = result;
        _connectivityController.add(_isConnected);
      }
      return _isConnected;
    } catch (e) {
      _logger.e('Error checking connectivity', e);
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();

    // Close stream controller if it's open
    if (!_connectivityController.isClosed) {
      _connectivityController.close();
    }
    _logger.i('NetworkListener disposed');
  }
}
