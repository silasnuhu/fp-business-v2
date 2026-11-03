// =============================================================================
// Enhanced Call Provider with improved state management
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:whoxa/featuers/call/call_manager.dart';
import 'package:whoxa/featuers/call/call_model.dart';
import 'package:whoxa/utils/logger.dart';
import 'dart:async';
import 'dart:io';

class CallProvider extends ChangeNotifier {
  final _callManager = CallManager.instance;
  final _logger = ConsoleAppLogger.forModule('CallProvider');

  // Local renderer for UI
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> remoteRenderers = {};

  // Enhanced media state
  bool _isAudioEnabled = true;
  bool _isVideoEnabled = true;
  bool _isSpeakerOn = true;
  bool _isInitialized = false;
  String? _lastError;

  // State tracking for UI consistency
  CallState _lastKnownState = CallState.idle;
  Timer? _stateCheckTimer;
  bool _disposed = false;

  // Getters
  CallState get callState => _callManager.state;
  CallInfo? get currentCall => _callManager.currentCall;
  List<CallParticipant> get participants => _callManager.participants;
  bool get isInCall => _callManager.isInCall;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  bool get isAudioEnabled => _isAudioEnabled;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isSpeakerOn => _isSpeakerOn;

  // Convenience getters
  bool get isIdle => callState == CallState.idle;
  bool get isCalling => callState == CallState.calling;
  bool get isRinging => callState == CallState.ringing;
  bool get isConnecting => callState == CallState.connecting;
  bool get isConnected => callState == CallState.connected;
  bool get isFailed => callState == CallState.failed;
  bool get isEnded => callState == CallState.ended;
  bool get canMakeCall => isIdle && !isInCall;
  bool get canAcceptCall => isRinging;
  bool get canDeclineCall => isRinging;
  int get participantCount => _callManager.participantCount;

  CallProvider() {
    _initialize();
  }

  /// Initialize provider with enhanced setup
  Future<void> _initialize() async {
    try {
      _logger.i('🚀 CallProvider: Initializing...');

      // Initialize local renderer
      await localRenderer.initialize();

      // Setup call manager callbacks
      _setupCallManagerCallbacks();

      // Initialize call manager
      await _callManager.initialize();

      // Start periodic state monitoring
      _startStateMonitoring();

      _isInitialized = true;
      _logger.i('✅ CallProvider: Initialized successfully');
    } catch (e) {
      _logger.e('❌ CallProvider: Failed to initialize: $e');
      _lastError = 'Failed to initialize: $e';
      rethrow;
    }
  }

  /// Setup call manager callbacks
  void _setupCallManagerCallbacks() {
    _callManager.onStateChanged = _onStateChanged;
    _callManager.onParticipantJoined = _onParticipantJoined;
    _callManager.onParticipantLeft = _onParticipantLeft;
    _callManager.onStreamAdded = _onStreamAdded;
    _callManager.onStreamRemoved = _onStreamRemoved;
    _callManager.onLocalStreamReady = _onLocalStreamReady;
    _callManager.onError = _onError;
  }

  /// Start periodic state monitoring
  void _startStateMonitoring() {
    _stateCheckTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      _checkStateConsistency();
    });
  }

  /// Check state consistency and update UI if needed
  void _checkStateConsistency() {
    final currentState = _callManager.state;
    if (currentState != _lastKnownState) {
      _lastKnownState = currentState;
      _logger.d('🔄 State change detected: ${currentState.name}');

      // Use post frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          notifyListeners();
        }
      });
    }
  }

  /// Handle state changes
  void _onStateChanged() {
    final previousState = _lastKnownState;
    final currentState = _callManager.state;
    _logger.i('🔍 STATE CHANGE: $previousState → $currentState');

    _checkStateConsistency();

    // CRITICAL FIX: Stop ALL audio tracks IMMEDIATELY when call ends (ANY state -> ended)
    // This prevents audio from continuing to transmit after call ends on iOS
    if (currentState == CallState.ended && previousState != CallState.ended) {
      _logger.i(
        '🚨 CallProvider: Call ended - IMMEDIATELY stopping all media tracks',
      );

      // CRITICAL: Stop tracks SYNCHRONOUSLY (not async) for immediate effect
      _stopAllTracksImmediately();

      // Then clear renderers asynchronously
      _clearRenderers().then((_) {
        _logger.i('✅ CallProvider: All renderers cleared after call end');

        // Ensure immediate UI update
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) {
            notifyListeners();
          }
        });
      });
    }

    // CRITICAL: Handle transition from ended to idle for proper navigation
    if (currentState == CallState.idle && previousState == CallState.ended) {
      _logger.i(
        '🔄 CallProvider: Detected transition from ended to idle - triggering UI update',
      );

      // Force immediate UI update to trigger navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          notifyListeners();
        }
      });
    }

    // CRITICAL: Set initial speaker state when call connects (ONE TIME ONLY)
    if (currentState == CallState.connected &&
        previousState != CallState.connected) {
      _logger.i('🔄 CallProvider: Call connected - setting INITIAL speaker state');
      _logger.i('🔍 DEBUG: Platform.isIOS = ${Platform.isIOS}');
      _logger.i('🔍 DEBUG: currentCall?.callType = ${currentCall?.callType}');

      // Set initial speaker state ONCE when call connects
      // After this, user's manual toggles will be respected (no auto-correction)
      Future.microtask(() async {
        if (!_disposed && _callManager.state == CallState.connected) {
          await _syncSpeakerWithWebRTC();
          _logger.i('✅ Initial speaker state set - user can now toggle freely');
        }
      });
    }
  }

  /// Handle errors
  void _onError(String error) {
    _logger.e('❌ CallProvider: Error received: $error');
    _lastError = error;
    notifyListeners();
  }

  /// Make a call with enhanced error handling
  Future<bool> makeCall({
    required int chatId,
    required CallType callType,
    required String chatName,
    int? peerId, // Peer user ID for calls without existing chat (chatId = 0)
  }) async {
    try {
      _logger.i(
        '📞 CallProvider: Making ${callType.name} call to $chatName ($chatId)${peerId != null ? ', peerId: $peerId' : ''}',
      );

      if (!canMakeCall) {
        _logger.w('⚠️ Cannot make call - conditions not met');
        return false;
      }

      _lastError = null; // Clear previous errors

      await _callManager.makeCall(
        chatId: chatId,
        callType: callType,
        chatName: chatName,
        peerId: peerId, // Pass peerId for calls without existing chat
      );

      // Set initial media state based on call type
      _isVideoEnabled = callType == CallType.video;
      _isSpeakerOn =
          callType == CallType.video; // Video calls default to speaker ON

      // CRITICAL: Set local stream to renderer with proper initialization
      await _setupLocalStream();
      _logger.i(
        '✅ CallProvider: Local stream setup initiated for outgoing call',
      );

      // CRITICAL: Set initial speaker state immediately for outgoing calls
      await _syncSpeakerWithWebRTC();

      notifyListeners();
      _logger.i('✅ CallProvider: Call initiated successfully');
      return true;
    } catch (e) {
      _logger.e('❌ CallProvider: Failed to make call: $e');
      _lastError = 'Failed to make call: $e';
      notifyListeners();
      return false;
    }
  }

  /// Accept incoming call with enhanced handling
  Future<bool> acceptCall() async {
    try {
      _logger.i('✅ CallProvider: Accepting incoming call');

      if (!canAcceptCall) {
        _logger.w('⚠️ Cannot accept call - no incoming call');
        return false;
      }

      _lastError = null; // Clear previous errors

      // CRITICAL FIX: Reset audio session state before accepting call
      try {
        await _callManager.forceResetAudioSessionForNextCall();
        _logger.i(
          '🔄 CallProvider: Audio session reset completed before accept',
        );
      } catch (e) {
        _logger.w(
          '⚠️ CallProvider: Audio session reset failed, continuing: $e',
        );
      }

      await _callManager.acceptCall();

      // Set initial media state based on call type
      _isVideoEnabled = currentCall?.callType == CallType.video;
      _isSpeakerOn =
          currentCall?.callType ==
          CallType.video; // Video calls default to speaker ON

      // CRITICAL: Set local stream to renderer with proper initialization
      await _setupLocalStream();
      _logger.i(
        '✅ CallProvider: Local stream setup initiated for incoming call',
      );

      // CRITICAL: Set initial speaker state immediately for incoming calls
      await _syncSpeakerWithWebRTC();

      notifyListeners();
      _logger.i('✅ CallProvider: Call accepted successfully');
      return true;
    } catch (e) {
      _logger.e('❌ CallProvider: Failed to accept call: $e');
      _lastError = 'Failed to accept call: $e';
      notifyListeners();
      return false;
    }
  }

  /// Decline incoming call with enhanced handling
  Future<bool> declineCall({bool isAutoTimeout = false}) async {
    try {
      _logger.i(
        '❌ CallProvider: Declining incoming call (isAutoTimeout: $isAutoTimeout)',
      );

      if (!canDeclineCall && !isAutoTimeout) {
        _logger.w('⚠️ Cannot decline call - no incoming call');
        return false;
      }

      await _callManager.declineCall(isAutoTimeout: isAutoTimeout);

      // CRITICAL: Clear renderers on decline
      await _clearRenderers();

      notifyListeners();
      _logger.i('✅ CallProvider: Call declined successfully');
      return true;
    } catch (e) {
      _logger.e('❌ CallProvider: Failed to decline call: $e');
      _lastError = 'Failed to decline call: $e';
      notifyListeners();
      return false;
    }
  }

  /// End current call with proper cleanup
  Future<void> endCall() async {
    try {
      _logger.i('🔚 CallProvider: Ending call');

      await _callManager.endCall();

      // Clear renderers
      await _clearRenderers();

      notifyListeners();
      _logger.i('✅ CallProvider: Call ended successfully');
    } catch (e) {
      _logger.e('❌ CallProvider: Failed to end call: $e');
      _lastError = 'Failed to end call: $e';
      // Force cleanup
      await _clearRenderers();
      notifyListeners();
    }
  }

  /// Leave current call (for outgoing call timeout)
  Future<void> leaveCall() async {
    try {
      _logger.i('🔍 DEBUG: CallProvider.leaveCall() called');
      _logger.i('🔍 DEBUG: Current call state: ${callState.name}');
      _logger.i('🔍 DEBUG: Current call info: ${currentCall?.toString()}');
      _logger.i('🚪 CallProvider: Leaving call');

      await _callManager.leaveCall();

      // Clear renderers
      await _clearRenderers();

      notifyListeners();
      _logger.i('✅ CallProvider: Call left successfully');
    } catch (e) {
      _logger.e('❌ CallProvider: Failed to leave call: $e');
      _lastError = 'Failed to leave call: $e';
      // Force cleanup
      await _clearRenderers();
      notifyListeners();
    }
  }

  /// Helper method to safely check if a stream is active
  bool _isStreamActive(MediaStream stream) {
    try {
      return stream.active ?? true;
    } catch (e) {
      _logger.w(
        '⚠️ Could not check local stream active state, assuming active: $e',
      );
      return true; // Assume active if we can't check
    }
  }

  /// Setup local stream with proper initialization
  /// Attach the local capture stream to the local renderer.
  ///
  /// The media plane starts asynchronously (`/calls` connect + join +
  /// PeerServer handshake), so `localStream` is usually still null when this
  /// first runs right after accept/make. That is fine — `CallManager.onLocalStreamReady` calls
  /// this again the moment `getUserMedia` completes (see `_onLocalStreamReady`).
  Future<void> _setupLocalStream() async {
    try {
      final localStream = _callManager.localStream;
      if (localStream == null) {
        _logger.i(
          '🔄 CallProvider: local stream not ready yet — waiting for onLocalStreamReady',
        );
        return;
      }
      if (localRenderer.srcObject == localStream) return;

      localRenderer.srcObject = localStream;
      _logger.i('✅ CallProvider: local stream attached to renderer');
      notifyListeners();
    } catch (e) {
      _logger.e('❌ CallProvider: Error in _setupLocalStream: $e');
    }
  }

  void _onLocalStreamReady() {
    _logger.i('📹 CallProvider: onLocalStreamReady — attaching local stream');
    _setupLocalStream();
  }

  /// CRITICAL: Stop all media tracks IMMEDIATELY (synchronous)
  /// This prevents audio from continuing to transmit on iOS after call ends
  /// Uses reelboostmobile pattern: DISABLE first, then STOP
  void _stopAllTracksImmediately() {
    try {
      _logger.i('🚨 EMERGENCY: Detaching renderers immediately');

      // Always safe and required: detach every renderer's srcObject so nothing
      // keeps rendering/playing out a stream that is about to go away.
      final localStream = localRenderer.srcObject;
      localRenderer.srcObject = null;
      for (final entry in remoteRenderers.entries) {
        entry.value.srcObject = null;
      }

      // On the PeerJS mesh path the controller OWNS every track (local and
      // remote) and stops/disposes them in its own dispose(). Stopping them
      // here would kill the tracks every MediaConnection is still sending
      // during a mid-join teardown. Detaching the renderers is all the UI does.
      if (_callManager.mediaBackendManagesStreams) {
        _logger.i('✅ EMERGENCY: renderers detached (SFU owns the tracks)');
        return;
      }

      // Step 2: DISABLE all local tracks FIRST (immediate audio silence - reelboostmobile pattern)
      if (localStream != null) {
        try {
          _logger.i('🔇 Step 2: Disabling local tracks...');
          for (var track in localStream.getTracks()) {
            try {
              track.enabled = false;
              _logger.d('🔇 Disabled local ${track.kind} track');
            } catch (e) {
              _logger.w('⚠️ Error disabling local track: $e');
            }
          }
        } catch (e) {
          _logger.e('❌ Error disabling local tracks: $e');
        }
      }

      // Step 3: Note - remote tracks are handled by WebRTCService._remoteStreams cleanup
      // srcObjects already cleared above, WebRTCService.dispose() will handle the rest

      // Step 4: STOP local tracks (release hardware)
      if (localStream != null) {
        try {
          _logger.i('⏹️ Step 4: Stopping local tracks...');
          for (var track in localStream.getTracks()) {
            try {
              track.stop();
              _logger.d('⏹️ Stopped local ${track.kind} track');
            } catch (e) {
              _logger.w('⚠️ Error stopping local track: $e');
            }
          }
        } catch (e) {
          _logger.e('❌ Error stopping local tracks: $e');
        }
      }

      _logger.i('✅ EMERGENCY STOP: All media tracks disabled and stopped immediately');

      // NOTE: Remote stream cleanup is handled by WebRTCService.dispose()
      // which now properly tracks and cleans up all remote streams
    } catch (e) {
      _logger.e('❌ CRITICAL ERROR in _stopAllTracksImmediately: $e');
    }
  }

  /// Clear renderers with proper disposal order (reelboostmobile pattern)
  /// Order: Clear srcObject → Disable tracks → Stop tracks → Dispose stream → Dispose renderer
  Future<void> _clearRenderers() async {
    try {
      _logger.i('🧹 Clearing renderers...');

      // Step 1: Clear srcObject FIRST (detaches from audio output)
      final localStream = localRenderer.srcObject;
      localRenderer.srcObject = null;
      _logger.d('📺 Local renderer srcObject cleared');

      // On the PeerJS mesh path the controller owns every track/stream and
      // frees them in its dispose(). The UI only detaches + disposes the
      // renderers — never the tracks or the MediaStream objects.
      if (_callManager.mediaBackendManagesStreams) {
        for (final entry in remoteRenderers.entries) {
          entry.value.srcObject = null;
          try {
            await entry.value.dispose();
          } catch (e) {
            _logger.w('⚠️ Error disposing renderer for ${entry.key}: $e');
          }
        }
        remoteRenderers.clear();
        _logger.i('✅ Renderers cleared (SFU owns the streams)');
        return;
      }

      // Step 2: Process local stream with disable → stop → dispose
      if (localStream != null) {
        // Disable all tracks FIRST (immediate silence)
        for (var track in localStream.getTracks()) {
          try {
            track.enabled = false;
          } catch (e) {
            _logger.w('⚠️ Error disabling local track: $e');
          }
        }

        // Stop all tracks (release hardware)
        for (var track in localStream.getTracks()) {
          try {
            track.stop();
          } catch (e) {
            _logger.w('⚠️ Error stopping local track: $e');
          }
        }

        // Clear track arrays
        localStream.getAudioTracks().clear();
        localStream.getVideoTracks().clear();

        // Dispose stream
        try {
          await localStream.dispose();
          _logger.i('✅ Local stream disposed');
        } catch (e) {
          _logger.w('⚠️ Error disposing local stream: $e');
        }
      }

      // Step 3: Process remote renderers with disable → stop → dispose
      for (final entry in remoteRenderers.entries) {
        final peerId = entry.key;
        final renderer = entry.value;
        final stream = renderer.srcObject;

        // Clear srcObject first
        renderer.srcObject = null;

        if (stream != null) {
          // Disable all tracks FIRST (immediate silence)
          for (var track in stream.getTracks()) {
            try {
              track.enabled = false;
            } catch (e) {
              _logger.w('⚠️ Error disabling remote track for $peerId: $e');
            }
          }

          // Stop all tracks (release hardware)
          for (var track in stream.getTracks()) {
            try {
              track.stop();
            } catch (e) {
              _logger.w('⚠️ Error stopping remote track for $peerId: $e');
            }
          }

          // Clear track arrays
          stream.getAudioTracks().clear();
          stream.getVideoTracks().clear();

          // Dispose stream
          try {
            await stream.dispose();
            _logger.d('✅ Remote stream disposed for: $peerId');
          } catch (e) {
            _logger.w('⚠️ Error disposing remote stream for $peerId: $e');
          }
        }

        // Dispose renderer
        try {
          await renderer.dispose();
        } catch (e) {
          _logger.w('⚠️ Error disposing renderer for $peerId: $e');
        }
      }
      remoteRenderers.clear();

      _logger.i('✅ All renderers cleared (reelboostmobile pattern)');
    } catch (e) {
      _logger.e('❌ Error clearing renderers: $e');
    }
  }

  /// Toggle audio
  void toggleAudio() {
    _isAudioEnabled = !_isAudioEnabled;
    _callManager.toggleAudio(_isAudioEnabled);
    notifyListeners();
  }

  /// Toggle video
  void toggleVideo() {
    _isVideoEnabled = !_isVideoEnabled;
    _callManager.toggleVideo(_isVideoEnabled);
    notifyListeners();
  }

  /// Toggle speaker - SIMPLE approach (no auto-correction)
  Future<void> toggleSpeaker() async {
    try {
      final newSpeakerState = !_isSpeakerOn;
      _logger.i(
        '🔄 CallProvider: Toggling speaker from ${_isSpeakerOn ? "ON" : "OFF"} to ${newSpeakerState ? "ON" : "OFF"}',
      );

      // Update UI state first
      _isSpeakerOn = newSpeakerState;

      // Configure audio with new state
      await _callManager.configureAudioForCallWithSpeaker(newSpeakerState);
      await _callManager.setSpeakerphone(newSpeakerState);

      // Update UI
      notifyListeners();

      _logger.i(
        '✅ Speaker toggled successfully: ${_isSpeakerOn ? "ON (Speaker)" : "OFF (Earpiece)"}',
      );
    } catch (e) {
      _logger.e('❌ Failed to toggle speaker: $e');
      // Revert UI state if failed
      _isSpeakerOn = !_isSpeakerOn;
      notifyListeners();
      rethrow;
    }
  }

  /// Switch camera
  Future<void> switchCamera() async {
    await _callManager.switchCamera();
  }

  /// Sync speaker state with WebRTC and audio manager - simplified approach
  Future<void> _syncSpeakerWithWebRTC() async {
    try {
      _logger.i(
        '🔊 CallProvider: Syncing speaker state - UI=${_isSpeakerOn ? "ON" : "OFF"}, CallType=${currentCall?.callType.name}',
      );

      // SIMPLIFIED: Single sync attempt - let native iOS handle the persistence
      if (currentCall?.callType == CallType.video && _isSpeakerOn) {
        _logger.i(
          '🎥 VIDEO CALL detected - single speaker sync with native enforcement',
        );

        // Configure audio manager once
        await _callManager.configureAudioForCallWithSpeaker(true);

        // Single WebRTC speaker call - native iOS will handle delayed enforcement
        await _callManager.setSpeakerphone(true);

        _logger.i(
          '✅ VIDEO CALL speaker sync completed - Native iOS will handle persistence',
        );
      } else {
        // Regular sync for audio calls or speaker OFF
        await _callManager.configureAudioForCallWithSpeaker(_isSpeakerOn);
        await _callManager.setSpeakerphone(_isSpeakerOn);
        _logger.i(
          '✅ Regular speaker sync completed: ${_isSpeakerOn ? "SPEAKER" : "EARPIECE"}',
        );
      }

      _logger.i(
        '✅ Speaker state synced: UI=${_isSpeakerOn ? "ON" : "OFF"}, Audio=${_isSpeakerOn ? "Speaker" : "Earpiece"}',
      );
    } catch (e) {
      _logger.e('❌ Failed to sync speaker state: $e');
    }
  }

  /// DISABLED: This was forcing speaker ON even when user manually turned it OFF
  void _checkAndEnforceSpeakerModeForVideoCall() {
    // DO NOTHING - respect user's manual speaker toggle
    // Previously this would force speaker ON for video calls when participants joined
    // This was the main bug causing auto-enable
    _logger.i('🔊 Speaker enforcement disabled - respecting user choice');
  }

  // REMOVED: Deprecated methods that were auto-correcting user's speaker settings
  // - _syncSpeakerWithActualAudioState()
  // - _forceSpeakerMode()
  // - _reinforceSpeakerMode()
  // These methods were causing unwanted auto-enable of speaker mode

  /// Handle participant joined
  void _onParticipantJoined(CallParticipant participant) {
    _logger.i(
      '👤 CallProvider: Participant joined/updated: ${participant.userName} (UserID: ${participant.userId}, PeerID: ${participant.peerId})',
    );

    // Print detailed debugging info
    printCallDebuggingInfo();

    // CRITICAL: Force speaker mode for video calls when 2 or more users are in call (including current user)
    _checkAndEnforceSpeakerModeForVideoCall();

    // Force UI update to reflect new participant or name changes
    notifyListeners();
  }

  /// Handle participant left
  void _onParticipantLeft(String peerId) {
    _logger.i('👤 CallProvider: Participant left: $peerId');

    // CRITICAL: Check if renderer exists to prevent duplicate processing
    final renderer = remoteRenderers[peerId];
    if (renderer == null) {
      _logger.w('⚠️ CallProvider: No renderer found for participant: $peerId');
      // CRITICAL: Still notify UI immediately to ensure participant is removed from lists
      notifyListeners();
      return;
    }

    try {
      // CRITICAL: Clear stream IMMEDIATELY to hide video preview
      renderer.srcObject = null;
      _logger.i(
        '✅ CallProvider: Stream cleared immediately for participant: $peerId',
      );

      // CRITICAL: Remove renderer from map BEFORE UI update to prevent race conditions
      remoteRenderers.remove(peerId);

      // Force immediate UI update after clearing stream and removing renderer
      notifyListeners();

      // Dispose renderer asynchronously to prevent blocking UI
      renderer.dispose().catchError((e) {
        _logger.w('⚠️ Error disposing renderer for $peerId: $e');
      });

      _logger.i('✅ CallProvider: Cleaned up renderer for participant: $peerId');
    } catch (e) {
      _logger.e('❌ CallProvider: Error cleaning up renderer for $peerId: $e');
      // Still remove from map even if cleanup failed
      remoteRenderers.remove(peerId);
      // Force UI update even on error
      notifyListeners();
    }

    // CRITICAL: Additional UI update with microtask to ensure state consistency
    Future.microtask(() {
      notifyListeners();
      _logger.d(
        '🔄 CallProvider: Final UI update completed for participant removal: $peerId',
      );
    });
  }

  /// Handle stream added
  Future<void> _onStreamAdded(String peerId, MediaStream stream) async {
    _logger.i('📹 CallProvider: Stream added for: $peerId');

    // CRITICAL: Verify stream is active (with fallback for compatibility)
    bool isStreamActive = _isStreamActive(stream);
    if (!isStreamActive) {
      _logger.w('⚠️ CallProvider: Stream is not active for: $peerId');
      return;
    }

    // Log stream details
    final videoTracks = stream.getVideoTracks();
    final audioTracks = stream.getAudioTracks();
    _logger.i(
      '📹 CallProvider: Stream details for $peerId - Video: ${videoTracks.length}, Audio: ${audioTracks.length}',
    );

    // Create renderer if needed
    if (!remoteRenderers.containsKey(peerId)) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      remoteRenderers[peerId] = renderer;
      _logger.i('✅ CallProvider: Created new renderer for: $peerId');
    }

    // Set stream
    remoteRenderers[peerId]!.srcObject = stream;
    _logger.i('✅ CallProvider: Remote stream set to renderer for: $peerId');
    notifyListeners();
  }

  /// Handle stream removed
  void _onStreamRemoved(String peerId) {
    _logger.i('📹 CallProvider: Stream removed for: $peerId');

    final renderer = remoteRenderers[peerId];
    if (renderer != null) {
      try {
        // On the PeerJS mesh path the controller owns and closes the remote
        // tracks itself (when the MediaConnection closes, or on
        // `call:participantLeft`). The UI only detaches the renderer —
        // stopping the tracks here would race the controller's own teardown.
        if (!_callManager.mediaBackendManagesStreams) {
          final stream = renderer.srcObject;
          if (stream != null) {
            for (var track in stream.getAudioTracks()) {
              track.stop();
            }
            for (var track in stream.getVideoTracks()) {
              track.stop();
            }
            _logger.i('✅ All media tracks stopped for: $peerId');
          }
        }

        // Clear stream from renderer
        renderer.srcObject = null;
        _logger.i('✅ CallProvider: Stream cleared for participant: $peerId');

        // Force immediate UI update after clearing stream
        notifyListeners();
      } catch (e) {
        _logger.e('❌ CallProvider: Error clearing stream for $peerId: $e');
      }
    } else {
      _logger.w(
        '⚠️ CallProvider: No renderer found for stream removal: $peerId',
      );
    }

    // Additional UI update with slight delay to ensure state synchronization
    Future.microtask(() => notifyListeners());
  }

  /// Force reset call state
  Future<void> forceResetCallState() async {
    try {
      _logger.i('🔄 CallProvider: Force resetting call state');

      await _callManager.endCall();
      await _clearRenderers();

      _lastError = null;
      _isAudioEnabled = true;
      _isVideoEnabled = true;
      _isSpeakerOn = false; // Reset to default (earpiece for audio calls)

      notifyListeners();
      _logger.i('✅ CallProvider: Call state reset successfully');
    } catch (e) {
      _logger.e('❌ CallProvider: Failed to reset call state: $e');
      _lastError = 'Failed to reset call state: $e';
      notifyListeners();
    }
  }

  /// Get call state display text
  String get callStateText {
    switch (callState) {
      case CallState.idle:
        return 'Ready';
      case CallState.calling:
        return 'Calling...';
      case CallState.ringing:
        return 'Incoming Call';
      case CallState.connecting:
        return 'Connecting...';
      case CallState.connected:
        return 'Connected';
      case CallState.failed:
        return 'Call Failed';
      case CallState.ended:
        return 'Call Ended';
      case CallState.disconnected:
        return 'Disconnected';
    }
  }

  /// Get participant by user ID
  CallParticipant? getParticipantByUserId(String userId) {
    return _callManager.getParticipantByUserId(userId);
  }

  /// Get all participants mapped by user ID
  Map<String, CallParticipant> getParticipantsByUserId() {
    return _callManager.getParticipantsByUserId();
  }

  /// Get user ID to peer ID mapping for backend integration
  Map<String, String> getUserIdToPeerIdMapping() {
    return _callManager.getUserIdToPeerIdMapping();
  }

  /// Get detailed participant information for debugging
  List<Map<String, dynamic>> getDetailedParticipantInfo() {
    return _callManager.getDetailedParticipantInfo();
  }

  /// Print detailed call information for debugging
  void printCallDebuggingInfo() {
    _logger.i('🔍 ===== CALL DEBUGGING INFO =====');
    _logger.i('🔍 Call State: $callState');
    _logger.i('🔍 Participant Count: $participantCount');
    _logger.i('🔍 Remote Renderers: ${remoteRenderers.keys.toList()}');

    final userIdMapping = getUserIdToPeerIdMapping();
    _logger.i('🔍 User ID to Peer ID Mapping: $userIdMapping');

    final detailedInfo = getDetailedParticipantInfo();
    _logger.i('🔍 Detailed Participant Info:');
    for (int i = 0; i < detailedInfo.length; i++) {
      final info = detailedInfo[i];
      _logger.i('🔍   Participant ${i + 1}:');
      _logger.i('🔍     UserID: ${info['userId']}');
      _logger.i('🔍     UserName: ${info['userName']}');
      _logger.i('🔍     PeerID: ${info['peerId']}');
      _logger.i('🔍     Connected: ${info['isConnected']}');
      _logger.i('🔍     HasVideo: ${info['hasVideo']}');
      _logger.i('🔍     HasAudio: ${info['hasAudio']}');
    }
    _logger.i('🔍 ================================');

    // Also validate metadata status
    _callManager.validateMetadataStatus();
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'callState': callState.name,
      'isInCall': isInCall,
      'canMakeCall': canMakeCall,
      'canAcceptCall': canAcceptCall,
      'participantCount': participantCount,
      'isAudioEnabled': isAudioEnabled,
      'isVideoEnabled': isVideoEnabled,
      'isSpeakerOn': isSpeakerOn,
      'lastError': lastError,
      'isInitialized': isInitialized,
      'remoteRenderersCount': remoteRenderers.length,
      'callManagerState': _callManager.state.name,
      'userIdToPeerIdMapping': getUserIdToPeerIdMapping(),
      'detailedParticipantInfo': getDetailedParticipantInfo(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  @override
  void dispose() {
    _logger.d('🧹 CallProvider: Disposing...');

    _disposed = true;

    // Stop state monitoring
    _stateCheckTimer?.cancel();

    // Order matters: detach the streams from the renderers first (cheap, sync),
    // then tear down the media plane / peer connections, and only then dispose
    // the renderer textures. Disposing renderers while peer connections are
    // still alive lets a late WebRTC callback fire against a half-torn-down
    // engine, which crashes natively in flutter_webrtc's postEvent().
    try {
      localRenderer.srcObject = null;
    } catch (_) {}
    for (final renderer in remoteRenderers.values) {
      try {
        renderer.srcObject = null;
      } catch (_) {}
    }

    // Dispose call manager (awaits the Peer + peer-connection close).
    final managerDown = _callManager.dispose();

    Future(() async {
      try {
        await managerDown;
      } catch (e) {
        _logger.w('⚠️ CallProvider: call manager dispose failed: $e');
      }
      try {
        await localRenderer.dispose();
      } catch (_) {}
      for (final renderer in remoteRenderers.values) {
        try {
          await renderer.dispose();
        } catch (_) {}
      }
      remoteRenderers.clear();
    });

    super.dispose();
  }
}
