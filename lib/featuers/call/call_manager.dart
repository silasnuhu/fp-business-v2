// =============================================================================
// Enhanced Call Manager with improved flow from ultimate_call
// Based on webrtc_call_flow_flutter_updated.md documentation
//
// Socket Events:
// EMIT: call, accept_call, reject_call, leave_call
// LISTEN: call, user_joined, user_left, call_ended, call_declined, call_missed
// OPTIONAL: call_accepted, call_failed, peer_disconnected
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/call/call_model.dart';
import 'package:whoxa/featuers/call/call_repository.dart';
import 'package:whoxa/featuers/chat/repository/conversation_repository.dart';
import 'package:whoxa/featuers/call/peerjs_call_controller.dart';
import 'package:whoxa/core/services/socket/socket_service.dart';
import 'package:whoxa/core/services/call_audio_manager.dart';
import 'package:whoxa/core/services/call_notification_manager.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/featuers/profile/data/repository/profile_status_repo.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/id_codec.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/core/navigation_helper.dart';

class CallManager with WidgetsBindingObserver {
  // Singleton
  static final CallManager _instance = CallManager._internal();
  static CallManager get instance => _instance;
  CallManager._internal();

  bool _lifecycleObserverAdded = false;

  final _logger = ConsoleAppLogger.forModule('CallManager');

  // Dependencies
  //
  // PeerJS mesh media plane. Recreated per call — it holds per-call state
  // (the Peer, one MediaConnection per remote participant, the roster and the
  // `/calls` namespace socket) and tears all of it down on dispose(). Null
  // when no call is active.
  PeerJsCallController? _media;
  final _audioManager = CallAudioManager.instance;
  SocketService? _socket;
  ApiClient? _apiClient;

  // Platform channel for native audio restoration
  static const platform = MethodChannel('primocys.call.audio');

  SocketService get socket {
    _socket ??= GetIt.instance<SocketService>();
    return _socket!;
  }

  // callIds we've already begun ringing for — the backend may emit
  // `incoming_call` more than once (its own initiate() fan-out plus the
  // `call_start` re-broadcast), and the OLD `receiving_call`/`incoming_call`
  // listeners historically doubled up too.
  final Set<String> _handledIncomingCallIds = {};

  ApiClient get apiClient {
    _apiClient ??= GetIt.instance<ApiClient>();
    return _apiClient!;
  }

  CallRepository? _callRepositoryInstance;
  CallRepository get _callRepository =>
      _callRepositoryInstance ??= CallRepository(apiClient);

  ConversationRepository? _conversationRepositoryInstance;
  ConversationRepository get _conversationRepository =>
      _conversationRepositoryInstance ??= ConversationRepository(apiClient);

  // Enhanced call state with session management
  CallState _state = CallState.idle;
  CallInfo? _currentCall;
  final Map<String, CallParticipant> _participants = {};
  final Map<String, Map<String, dynamic>> _peerMetadata =
      {}; // Store metadata by peer ID
  String? _sessionId;
  String? _roomId;
  bool _isInitialized = false;
  Timer? _callTimeoutTimer;
  Timer? _connectionTimeoutTimer;
  DateTime? _lastEmergencyStop; // For debouncing emergency stops

  // Callbacks
  VoidCallback? onStateChanged;
  Function(CallParticipant participant)? onParticipantJoined;
  Function(String peerId)? onParticipantLeft;
  Function(String peerId, MediaStream stream)? onStreamAdded;
  Function(String peerId)? onStreamRemoved;
  Function(String error)? onError;
  Function(Map<String, dynamic> missedCallData)? onMissedCall;

  /// Fired when the local capture stream becomes available (`getUserMedia`
  /// completed). The media plane starts asynchronously, so the UI wires this
  /// to (re)attach `localStream` to its renderer instead of polling for it.
  VoidCallback? onLocalStreamReady;

  // Getters
  CallState get state => _state;
  CallInfo? get currentCall => _currentCall;
  List<CallParticipant> get participants => _participants.values.toList();
  bool get isInCall => _state != CallState.idle && _state != CallState.ended;
  bool get isInitialized => _isInitialized;

  /// Local capture stream owned by the PeerJS controller (null outside a
  /// call). The UI renders this but must never stop/dispose its tracks — every
  /// MediaConnection in the mesh is still sending them; see
  /// `mediaBackendManagesStreams`.
  MediaStream? get localStream => _media?.localStream;

  /// The PeerJS mesh owns every media track (local + remote). UI teardown must
  /// only detach renderers (`srcObject = null` + dispose the renderer), never
  /// stop or dispose the underlying tracks.
  bool get mediaBackendManagesStreams => _media?.ownsStreams ?? true;
  String? get sessionId => _sessionId;
  String? get roomId => _roomId;
  int get participantCount => _participants.length + (isInCall ? 1 : 0);

  /// Initialize the call manager with enhanced setup
  Future<void> initialize() async {
    try {
      _logger.i('🚀 CallManager: Initializing...');

      // Initialize audio manager
      await _audioManager.initialize();

      // Setup audio manager timeout callback
      _audioManager.onCallTimeout = () {
        if (_state == CallState.ringing || _state == CallState.calling) {
          _logger.w('⏰ CallManager: Auto call timeout');

          // Trigger missed call callback
          final missedCallData = {
            'missed_call_type':
                _currentCall?.isIncoming == true
                    ? 'incoming_timeout'
                    : 'outgoing_timeout',
            'reason':
                _currentCall?.isIncoming == true
                    ? 'Incoming call timeout - no user action'
                    : 'Outgoing call timeout - caller auto-end',
            'call_id': _currentCall?.callId,
            'chat_id': _currentCall?.chatId,
            'call_type': _currentCall?.callType.name,
            'caller_name': _currentCall?.callerName,
            'duration': callDuration?.inSeconds ?? 0,
            'timestamp': DateTime.now().toIso8601String(),
          };
          onMissedCall?.call(missedCallData);

          // Use appropriate method based on call direction
          if (_currentCall?.isIncoming == false) {
            // For outgoing calls, use leaveCall to emit leave_call event
            leaveCall();
          } else {
            // For incoming calls, just cleanup without emitting events
            _cleanup();
          }
        }
      };

      // Media-plane callbacks are wired per call in `_startMedia()` — the
      // PeerJsCallController is created there, not here.

      // Setup socket listeners
      _setupSocketListeners();

      // Observe app lifecycle so an in-flight call is torn down deterministically
      // before the FlutterEngine goes away (see _teardownForEngineDetach).
      if (!_lifecycleObserverAdded) {
        WidgetsBinding.instance.addObserver(this);
        _lifecycleObserverAdded = true;
      }

      _isInitialized = true;
      _logger.i('✅ CallManager: Initialized successfully');
    } catch (e) {
      _logger.e('❌ CallManager: Failed to initialize: $e');
      onError?.call('Failed to initialize call manager: $e');
      rethrow;
    }
  }

  /// Setup socket event listeners with enhanced error handling.
  /// NEW's default-namespace socket events for call SESSION state
  /// (§7.5/§17): `incoming_call` (was `receiving_call`),
  /// `call_session_answered` (new — was inferred from `accept_call`'s
  /// round-trip in OLD), `call_session_declined` (was `call_declined`),
  /// `call_session_left`/`call_session_ended` (was `call_ended`/
  /// `missed_call` — the guide's checklist confirms a 45s auto-miss now
  /// arrives as `call_session_ended {reason:'missed'}`, not a separate
  /// event, so `_handleCallEnded` below branches on `reason` instead of a
  /// dedicated `missed_call` listener). Event payload shapes are NOT given
  /// verbatim by the guide — handlers below parse defensively.
  ///
  /// `user_joined`/`user_left`/`peer_disconnected`/`call_changes`/
  /// `call_failed` are the OLD default-namespace participant/mute-state
  /// events — left registered but effectively dormant: their NEW equivalents
  /// (`call:participantJoined`/`call:participantLeft`/`call:mediaState`) live
  /// on the separate `/calls` namespace and are handled by
  /// [PeerJsCallController].
  void _setupSocketListeners() {
    try {
      // CRITICAL: Remove existing listeners first to prevent duplicates
      socket.off('call');
      socket.off('receiving_call');
      socket.off('incoming_call');
      socket.off('user_joined');
      socket.off('user_left');
      socket.off('call_session_left');
      socket.off('call_ended');
      socket.off('call_session_ended');
      socket.off('call_declined');
      socket.off('call_session_declined');
      socket.off('call_missed');
      socket.off('call_accepted');
      socket.off('call_session_answered');
      socket.off('call_failed');
      socket.off('peer_disconnected');
      socket.off('call_changes');

      socket.on('incoming_call', _handleIncomingCall);
      socket.on('call_session_answered', _handleCallAccepted);
      socket.on('call_session_declined', _handleCallDeclined);
      // `call_session_left` is emitted by the backend ONLY for a single
      // participant leaving a still-live (group) call — it collapses to
      // `call_session_ended` when ≤1 participant remains. Its own handler
      // just drops that participant; it must never tear down the local call.
      socket.on('call_session_left', _handleCallSessionLeft);
      socket.on('call_session_ended', _handleCallEnded);

      // Legacy default-namespace media events — superseded by the `/calls`
      // namespace equivalents, kept registered for backward compatibility.
      socket.on('user_joined', _handleUserJoined);
      socket.on('user_left', _handleUserLeft);
      socket.on('call_changes', _handleCallChanges);
      socket.on('call_failed', _handleCallFailed);
      socket.on('peer_disconnected', _handlePeerDisconnected);

      _logger.i('✅ Socket listeners setup successfully (duplicates removed)');
    } catch (e) {
      _logger.e('❌ Error setting up socket listeners: $e');
      onError?.call('Socket setup failed: $e');
    }
  }

  /// Make a call with enhanced flow and error handling
  Future<void> makeCall({
    required int chatId,
    required CallType callType,
    required String chatName,
    int? peerId, // Peer user ID for calls without existing chat (chatId = 0)
  }) async {
    try {
      _logger.i(
        '📞 CallManager: Making ${callType.name} call to chat $chatId${peerId != null ? ', peerId: $peerId' : ''}',
      );

      // CRITICAL: Prevent multiple simultaneous calls
      if (isInCall) {
        _logger.w('⚠️ CallManager: Already in a call, cannot make new call');
        throw Exception('Already in a call');
      }

      // Generate session and room IDs
      _sessionId = _generateSessionId();
      _roomId = _generateRoomId(chatId);

      // Update state
      _setState(CallState.calling);
      _currentCall = CallInfo(
        chatId: chatId,
        callType: callType,
        callerName: chatName,
        isIncoming: false,
        sessionId: _sessionId,
        roomId: _roomId,
      );

      // Get user ID first for API call and WebRTC initialization
      final userId = userID.toString();

      // NEW: call session lifecycle is REST (§7.4/§7.6), and `POST /calls`
      // needs an existing conversationId — the old `peer_id` auto-create
      // is gone. Placing a call IS a real user action, so creating the
      // conversation here is legitimate (same rule as sending a message);
      // merely opening a chat or a profile never does. Still, look the
      // conversation up first so an existing chat is reused rather than
      // re-POSTed on every call.
      _logger.i('🚀 CallManager: Calling POST /calls (NEW session lifecycle)...');

      try {
        var conversationId = chatId;
        if (conversationId <= 0 && peerId != null) {
          final existingId = await _conversationRepository
              .findDirectConversationId(peerId.toString());
          conversationId = int.tryParse(existingId ?? '') ?? 0;

          if (conversationId <= 0) {
            // First ever contact with this user is this call — create it now.
            final conversation = await _conversationRepository
                .createConversation(
                  type: 'direct',
                  participantIds: [peerId.toString()],
                );
            conversationId = int.tryParse(conversation.id) ?? 0;
          }
          _logger.i(
            '📞 CallManager: Resolved conversation $conversationId for peer $peerId',
          );
        }

        if (conversationId <= 0) {
          throw Exception('No conversation to call into');
        }

        final apiResponse = await _callRepository.initiateCall(
          conversationId: conversationId.toString(),
          callType: callType.name,
        );

        _logger.i('✅ CallManager: API call successful: $apiResponse');

        // Response shape isn't given verbatim by the guide — best-effort
        // extraction, see call_repository.dart's file-level comment.
        final callId = extractCallId(apiResponse);
        _currentCall = _currentCall!.copyWith(
          callId: callId,
          chatId: conversationId,
          peerId: userId, // Set peerId to current user ID for outgoing call
        );

        _logger.i('✅ CallManager: Call data updated from API');
        _logger.i('   - Call ID: ${_currentCall!.callId}');
        _logger.i('   - Conversation ID: $conversationId');

        // Ring the callee. `POST /calls` only creates the call row — the
        // realtime `incoming_call` fan-out is driven by this `call_start`
        // socket signal (SocketGateway.onCallStart re-broadcasts it to the
        // conversation room). Without it the callee never rings. Safe even
        // if the backend also emits incoming_call itself — the callee
        // de-dupes on callId.
        try {
          socket.emit(
            'call_start',
            data: {
              'conversationId': conversationId.toString(),
              if (_currentCall!.callId != null) 'callId': _currentCall!.callId,
              'callType': callType.name,
            },
          );
          _logger.i('📡 CallManager: emitted call_start for call ${_currentCall!.callId}');
        } catch (e) {
          _logger.w('⚠️ CallManager: failed to emit call_start: $e');
        }
      } catch (apiError) {
        _logger.e('❌ CallManager: API call failed: $apiError');
        _setState(CallState.failed);
        await _cleanup();
        onError?.call('Failed to initiate call: $apiError');
        rethrow;
      }

      // Start the PeerJS media plane. The initiator's participant row is
      // already `joined` from `POST /calls`, so `call:join` succeeds now —
      // joining early means the callee's join snapshot already carries the
      // initiator's peer id, so the callee can dial us the moment it joins.
      if (_currentCall?.callId != null) {
        // Fire-and-forget: media connects in the background while the callee
        // is still ringing; awaiting it here would stall the ring UI.
        unawaited(
          _startMedia(
            callId: _currentCall!.callId!,
            userId: userId,
            callType: callType,
          ),
        );
      } else {
        _logger.w('⚠️ CallManager: no callId after POST /calls — media plane not started');
      }

      // 🚀 FINAL: WebRTC-native outgoing video call speaker setup
      if (callType == CallType.video) {
        _logger.i(
          '🚀 FINAL: WebRTC-native outgoing video call speaker setup...',
        );

        // Configure audio for video call with speaker
        await _audioManager.configureAudioForCall(useSpeaker: true);

        _logger.i(
          '✅ FINAL: WebRTC-native outgoing video call speaker setup completed',
        );
      }

      // NEW: OLD's "both users emit accept_call regardless of initiator"
      // hack doesn't apply here — call-session lifecycle is REST now
      // (§7.4/§7.5), and the OLD `accept_call` socket event has no NEW
      // counterpart for the caller side (the callee side is handled by
      // `acceptCall()` calling `POST /calls/:id/answer` instead). Removed.

      // Start caller tone with proper audio routing based on call type
      await _audioManager.startCallerTone(
        isVideoCall: callType == CallType.video,
      );

      // CRITICAL: Set timeout for call response (frontend-side handling)
      _callTimeoutTimer = Timer(Duration(seconds: 30), () {
        if (_state == CallState.calling) {
          _logger.w('⚠️ CallManager: Call timeout - no response');

          // Trigger missed call callback for outgoing call timeout
          if (_currentCall?.isIncoming == false) {
            final missedCallData = {
              'missed_call_type': 'outgoing_timeout',
              'reason': 'Outgoing call timeout - no receiver response',
              'call_id': _currentCall?.callId,
              'chat_id': _currentCall?.chatId,
              'call_type': _currentCall?.callType.name,
              'caller_name': _currentCall?.callerName,
              'duration': callDuration?.inSeconds ?? 0,
              'timestamp': DateTime.now().toIso8601String(),
            };
            onMissedCall?.call(missedCallData);
          }

          _setState(CallState.failed);
          onError?.call('Call timeout - no response');
          _cleanup();
        }
      });

      _logger.i(
        '✅ CallManager: Call initiated successfully with API-first flow',
      );
    } catch (e) {
      _logger.e('❌ CallManager: Failed to make call: $e');
      _setState(CallState.failed);
      await _cleanup();
      onError?.call('Failed to make call: $e');
      rethrow;
    }
  }

  /// Accept incoming call with enhanced flow
  Future<void> acceptCall() async {
    try {
      _logger.i('✅ CallManager: Accepting call');

      if (_currentCall == null || _state != CallState.ringing) {
        throw Exception('No incoming call to accept');
      }

      // CRITICAL: Single emergency stop with debouncing
      final now = DateTime.now();

      if (_lastEmergencyStop == null ||
          now.difference(_lastEmergencyStop!).inMilliseconds > 1000) {
        _lastEmergencyStop = now;
        await _emergencyStopAllAudio();
      }

      // Configure audio with proper speaker state
      final useSpeaker = _currentCall!.callType == CallType.video;
      await _audioManager.configureAudioForCall(useSpeaker: useSpeaker);

      // Update state to connecting
      _setState(CallState.connecting);

      final userId = userID.toString();

      // NEW: REST call-session lifecycle (§7.4/§7.6) — replaces the old
      // socket `accept_call` emit. This advances the call's session state
      // server-side AND flips the callee's participant row to `joined`, which
      // is the precondition for `call:join` on the `/calls` namespace.
      if (_currentCall!.callId != null) {
        await _callRepository.answerCall(_currentCall!.callId!);
      } else {
        _logger.w(
          '⚠️ CallManager: Accepting call with no callId — cannot call POST /calls/:id/answer',
        );
      }

      // Now that the row is `joined`, start the PeerJS media plane. Run it in
      // the background so the accept flow can transition the UI to `connected`
      // without waiting on the full join + PeerServer handshake.
      if (_currentCall!.callId != null) {
        unawaited(
          _startMedia(
            callId: _currentCall!.callId!,
            userId: userId,
            callType: _currentCall!.callType,
          ),
        );
      }
      // Set connection timeout
      _connectionTimeoutTimer = Timer(Duration(seconds: 30), () {
        if (_state == CallState.connecting) {
          _logger.w('⚠️ CallManager: Connection timeout');
          _setState(CallState.failed);
          onError?.call('Connection timeout');
          _cleanup();
        }
      });

      // Configure speaker for video calls
      if (_currentCall!.callType == CallType.video) {
        await _audioManager.configureAudioForCall(useSpeaker: true);
      }

      // Transition to connected state
      _setState(CallState.connected);
      _callTimeoutTimer?.cancel();
      _connectionTimeoutTimer?.cancel();

      _logger.i('✅ CallManager: Call accepted successfully');
    } catch (e) {
      _logger.e('❌ CallManager: Failed to accept call: $e');
      _setState(CallState.failed);
      onError?.call('Failed to accept call: $e');
      rethrow;
    }
  }

  /// Decline incoming call with proper cleanup
  Future<void> declineCall({bool isAutoTimeout = false}) async {
    _logger.i('❌ CallManager: Declining call (isAutoTimeout: $isAutoTimeout)');

    if (_currentCall == null) return;

    try {
      // CRITICAL: Emergency stop all audio immediately (decline call - restore session)
      await _emergencyStopAllAudioAndRestore();

      // NEW: REST call-session lifecycle (§7.4/§7.6) — replaces the old
      // socket `decline_call` emit.
      if (_currentCall!.callId != null) {
        _logger.i('❌ CallManager: POST /calls/${_currentCall!.callId}/decline');
        await _callRepository.declineCall(_currentCall!.callId!);
      } else {
        _logger.w(
          '⚠️ CallManager: Declining call with no callId — cannot call POST /calls/:id/decline',
        );
      }

      _logger.i('✅ CallManager: Call declined successfully');
    } catch (e) {
      _logger.e('❌ Error declining call: $e');
    }

    await _cleanup();
  }

  /// Leave current call (emits leave_call event)
  Future<void> leaveCall() async {
    _logger.i('🔍 DEBUG: CallManager.leaveCall() called');
    _logger.i('🔍 DEBUG: Current state: ${_state.name}');
    _logger.i('🔍 DEBUG: Current call: ${_currentCall?.toString()}');
    _logger.i('🚪 CallManager: Leaving call (current state: ${_state.name})');

    if (_currentCall == null) {
      _logger.w('⚠️ CallManager: No current call to leave');
      return;
    }

    try {
      // CRITICAL: Emergency stop all audio immediately (leave call - restore session)
      await _emergencyStopAllAudioAndRestore();

      // NEW: REST call-session lifecycle (§7.4/§7.6) — replaces the old
      // socket `leave_call` emit.
      if (_currentCall!.callId != null) {
        _logger.i('🚪 CallManager: POST /calls/${_currentCall!.callId}/leave');
        await _callRepository.leaveCall(_currentCall!.callId!);
      } else {
        _logger.w(
          '⚠️ CallManager: call_id is null, cannot call POST /calls/:id/leave',
        );
      }

      // Update state and cleanup
      _setState(CallState.ended);
      await _cleanup();

      _logger.i('✅ CallManager: Left call successfully');
    } catch (e) {
      _logger.e('❌ Error leaving call: $e');
      // Force cleanup even on error
      await _forceCleanup();
    }
  }

  /// End current call with proper cleanup
  Future<void> endCall() async {
    _logger.i('🔚 CallManager: Ending call (current state: ${_state.name})');

    // CRITICAL: Prevent multiple end call attempts
    if (_state == CallState.idle || _state == CallState.ended) {
      _logger.d('⚠️ CallManager: Call already ended');
      return;
    }

    try {
      // CRITICAL: Emergency stop all audio immediately (end call - restore session)
      await _emergencyStopAllAudioAndRestore();

      if (_currentCall != null) {
        // If caller is ending call during ringing/calling state, this should trigger missed_call on receiver
        if (_state == CallState.calling || _state == CallState.ringing) {
          _logger.i(
            '🔚 CallManager: Ending call during ringing/calling state - this may trigger missed_call for receiver',
          );

          // Trigger local missed call callback for manual end during ringing/calling
          if (_currentCall != null) {
            final missedCallData = {
              'missed_call_type':
                  _currentCall!.isIncoming
                      ? 'incoming_manual_decline'
                      : 'outgoing_manual_cancel',
              'reason':
                  _currentCall!.isIncoming
                      ? 'Incoming call manually declined'
                      : 'Outgoing call manually cancelled',
              'call_id': _currentCall!.callId,
              'chat_id': _currentCall!.chatId,
              'call_type': _currentCall!.callType.name,
              'caller_name': _currentCall!.callerName,
              'duration': callDuration?.inSeconds ?? 0,
              'timestamp': DateTime.now().toIso8601String(),
            };
            onMissedCall?.call(missedCallData);
          }
        }

        // NEW: REST call-session lifecycle (§7.4/§7.6) — `POST
        // /calls/:id/end` is a genuinely new capability (not modeled in
        // OLD at all), replacing the old socket `leave_call`/`end_call`
        // emit here.
        if (_currentCall!.callId != null) {
          _logger.i('🔚 CallManager: POST /calls/${_currentCall!.callId}/end');
          await _callRepository.endCall(_currentCall!.callId!);
        } else {
          _logger.w(
            '⚠️ CallManager: call_id is null, cannot call POST /calls/:id/end',
          );
        }
      }

      // Update state and cleanup
      _setState(CallState.ended);
      await _cleanup();

      _logger.i('✅ CallManager: Call ended successfully');
    } catch (e) {
      _logger.e('❌ Error ending call: $e');
      // Force cleanup even on error
      await _forceCleanup();
    }
  }

  /// Handle incoming call from socket - NEW's 'incoming_call' event (was 'receiving_call')
  // NEW's `incoming_call` payload shape is not given verbatim by the
  // migration guide (only the event name/purpose is confirmed) — parsing
  // below tries NEW's documented camelCase conventions first
  // (conversationId, callType, caller{id,fullName,avatarUrl}), falling back
  // to the OLD snake_case shape in case some fields carry over. Verify
  // against a live NEW backend and tighten once the real payload is known.
  Future<void> _handleIncomingCall(dynamic data) async {
    _logger.i('🔍 CallManager: Raw incoming_call data: $data');

    // Only reject if already in call
    if (isInCall) {
      _logger.w('⚠️ CallManager: Already in call, rejecting incoming call');
      return;
    }

    try {
      final callData = data['call'] ?? data ?? {};
      final userData = data['caller'] ?? data['user'] ?? {};
      final chatData = data['conversation'] ?? data['chat'] ?? {};

      // De-dupe: the same call can arrive as `incoming_call` more than once
      // (backend initiate() fan-out + call_start re-broadcast). Ring once.
      final dedupeCallId =
          (callData['id'] ?? callData['callId'] ?? callData['call_id'])
              ?.toString();
      if (dedupeCallId != null && dedupeCallId.isNotEmpty) {
        if (!_handledIncomingCallIds.add(dedupeCallId)) {
          _logger.i(
            '⏭️ CallManager: incoming_call $dedupeCallId already handled, ignoring duplicate',
          );
          return;
        }
        // keep the set from growing unbounded across a long session
        if (_handledIncomingCallIds.length > 50) {
          _handledIncomingCallIds
            ..clear()
            ..add(dedupeCallId);
        }
      }

      _logger.i('🔍 CallManager: Parsed call data: $callData');
      _logger.i('🔍 CallManager: Parsed user data: $userData');
      _logger.i('🔍 CallManager: Parsed chat data: $chatData');

      if (callData.isEmpty) {
        _logger.e('❌ CallManager: No call data in incoming_call event');
        return;
      }

      // Extract caller information from user data
      String callerName = 'Unknown Caller';
      String callerId = '';

      if (userData.isNotEmpty) {
        // Extract caller details from user object
        final userDetails = userData['User'] ?? userData;
        callerId =
            userDetails['id']?.toString() ??
            userDetails['user_id']?.toString() ??
            userData['id']?.toString() ??
            userData['user_id']?.toString() ??
            '';

        callerName =
            userDetails['fullName']?.toString() ??
            userDetails['full_name']?.toString() ??
            userData['fullName']?.toString() ??
            userData['full_name']?.toString() ??
            'Caller $callerId';

        _logger.i(
          '✅ CallManager: Caller info - ID: $callerId, Name: $callerName',
        );
      }

      // The backend's socket-relayed `incoming_call` (SocketGateway.onCallStart)
      // carries only {conversationId, callId, callType, fromUserId} - no caller
      // object - so `callerName` is still the "Unknown Caller" placeholder here.
      // Resolve it from `fromUserId` using locally cached data (contacts cache +
      // chat list peer data) so the ringing screen shows the real name.
      final fromUserId = int.tryParse(
        (data['fromUserId'] ?? data['from_user_id'] ?? callData['fromUserId'])
                ?.toString() ??
            '',
      );
      if (fromUserId != null && _isUnresolvedCallerName(callerName)) {
        if (callerId.isEmpty) callerId = fromUserId.toString();
        final resolved = _resolveCallerNameFromUserId(fromUserId);
        if (resolved != null && resolved.trim().isNotEmpty) {
          callerName = resolved.trim();
          _logger.i(
            '✅ CallManager: Resolved caller name from fromUserId $fromUserId: $callerName',
          );
        }
      }

      // Extract chat information
      String chatName = '';
      final isPrivate =
          (chatData['type']?.toString() ?? chatData['chat_type']?.toString()) !=
              'group' &&
          (chatData['is_private'] != false);
      if (chatData.isNotEmpty) {
        chatName =
            chatData['title']?.toString() ??
            chatData['group_name']?.toString() ??
            chatData['chat_name']?.toString() ??
            'Chat ${callData['conversationId'] ?? callData['chat_id']}';

        _logger.i(
          '✅ CallManager: Chat info - Name: $chatName, IsPrivate: $isPrivate',
        );
      }

      // Use chat name for group calls, caller name for individual calls
      final displayName = isPrivate ? callerName : chatName;

      // Parse start time from call data
      DateTime? incomingStartTime;
      final serverStartTimeData =
          callData['startedAt'] ?? callData['start_time'];
      if (serverStartTimeData != null) {
        try {
          incomingStartTime = DateTime.tryParse(serverStartTimeData.toString());
          if (incomingStartTime != null) {
            _logger.i('⏱️ CallManager: Server start time: $incomingStartTime');
          }
        } catch (e) {
          _logger.w('⚠️ CallManager: Failed to parse start time: $e');
        }
      }

      final rawCallId = callData['id'] ?? callData['callId'] ?? callData['call_id'];
      final rawChatId =
          callData['conversationId'] ?? callData['chat_id'] ?? chatData['id'];

      // Create CallInfo with complete data from incoming_call event
      _currentCall = CallInfo(
        chatId: int.tryParse(rawChatId?.toString() ?? '') ?? 0,
        callId: rawCallId != null ? IdCodec.toId(rawCallId) : null,
        roomId: callData['roomId'] ?? callData['room_id'],
        sessionId: callData['sessionId'] ?? callData['session_id'],
        callType:
            (callData['callType'] ?? callData['call_type']) == 'video'
                ? CallType.video
                : CallType.audio,
        callerName: displayName,
        isIncoming: true,
        startTime: incomingStartTime,
        peerId: callData['peerId'] ?? callData['peer_id'],
        callerProfilePic:
            userData['avatarUrl'] ??
            userData['profile_pic'], // Add profile picture from incoming call data
        callerUserId: callerId.isNotEmpty ? callerId : null,
      );

      // Update manager state variables
      _sessionId = _currentCall!.sessionId;
      _roomId = _currentCall!.roomId;

      _logger.i('✅ CallManager: Created incoming call info');
      _logger.i('   - Call ID: ${_currentCall!.callId}');
      _logger.i('   - Room ID: $_roomId');
      _logger.i('   - Session ID: $_sessionId');
      _logger.i('   - Call Type: ${_currentCall!.callType.name}');
      _logger.i('   - Caller: ${_currentCall!.callerName}');
      _logger.i('   - Chat ID: ${_currentCall!.chatId}');
      _logger.i('   - Current Users: ${callData['current_users']}');

      _setState(CallState.ringing);

      // Start ringtone with loudspeaker for incoming call
      await _audioManager.startIncomingCallRingtone();

      // CRITICAL FIX: Trigger navigation to incoming call screen for both iOS and Android
      try {
        final callData = {
          'chatId': _currentCall!.chatId,
          'callId': _currentCall!.callId,
          'peerId': _currentCall!.peerId,
          'roomId': _currentCall!.roomId,
          'callType': _currentCall!.callType.name,
          'callerName': _currentCall!.callerName,
          'callerAvatar': _currentCall!.callerProfilePic ?? '',
        };

        _logger.i(
          '🚀 Triggering NavigationHelper for incoming call: $callData',
        );
        NavigationHelper.handleIncomingCall(callData);
      } catch (e) {
        _logger.e('❌ Error triggering navigation for incoming call: $e');
      }

      _logger.i('✅ CallManager: Incoming call processed successfully');
    } catch (e) {
      _logger.e('❌ Error processing receiving_call: $e');
      onError?.call('Failed to process incoming call: $e');
    }
  }

  /// ✅ PUBLIC: Handle incoming call from notification
  Future<void> handleIncomingCallFromNotification(dynamic data) async {
    _logger.i('📞 CallManager: Incoming call from notification: $data');
    await _handleIncomingCall(data);
  }

  /// Re-push the incoming-call screen for a call that is already ringing.
  ///
  /// On iOS the `incoming_call` socket event is usually delivered while the
  /// app is backgrounded (the socket stays alive for a short window), so the
  /// call goes to `ringing` and the ringtone plays, but
  /// `NavigationHelper.handleIncomingCall()` refuses to navigate because the
  /// lifecycle state is `paused` — it falls back to a notification instead.
  /// When the user then brings the app to the foreground (taps the push, or
  /// just opens the app) the ringing call has no screen. Called from
  /// AppLifecycleManager on resume to reconcile the UI with call state.
  void resurfaceIncomingCallScreenIfRinging() {
    if (_state != CallState.ringing || _currentCall == null) return;
    if (_currentCall!.isIncoming != true) return;

    _logger.i(
      '📲 CallManager: App resumed with a ringing call — resurfacing screen',
    );
    final callData = {
      'chatId': _currentCall!.chatId,
      'callId': _currentCall!.callId,
      'peerId': _currentCall!.peerId,
      'roomId': _currentCall!.roomId,
      'callType': _currentCall!.callType.name,
      'callerName': _currentCall!.callerName,
      'callerAvatar': _currentCall!.callerProfilePic ?? '',
    };
    // navigateToIncomingCallFromData (not handleIncomingCall) — it has no
    // lifecycle gate, only the context + duplicate-navigation guard, so it
    // is a no-op if the screen is already up.
    NavigationHelper.navigateToIncomingCallFromData(callData);
  }

  /// Handle user joined event
  void _handleUserJoined(dynamic data) async {
    try {
      _logger.i('🔍 CallManager: Raw user_joined data: $data');

      final peerId = data['peer_id'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;

      if (peerId == null) {
        _logger.w('⚠️ Invalid user joined data - missing peer_id: $data');
        return;
      }

      _logger.i('🔍 CallManager: Extracted userData: $userData');
      _logger.i('🔍 CallManager: PeerId: $peerId');

      // Extract user information with better fallbacks
      final userId =
          userData?['user_id']?.toString() ??
          userData?['id']?.toString() ??
          userData?['userId']?.toString() ??
          data['user_id']?.toString() ??
          data['id']?.toString() ??
          '';

      _logger.i(
        '👤 CallManager: User joined - UserID: $userId, PeerID: $peerId',
      );
      _logger.i(
        '🔍 CallManager: Socket user data keys: ${userData?.keys.toList()}',
      );

      // CRITICAL: Set call ID from user_joined event if not already set
      if (_currentCall != null && _currentCall!.callId == null) {
        final callId = data['call_id'];
        if (callId != null) {
          _currentCall = _currentCall!.copyWith(callId: callId);
          _logger.i(
            '✅ CallManager: Call ID set from user_joined event: $callId',
          );
        }
      }

      // Try to extract server start_time for synchronized timing from call object
      DateTime? serverStartTime;
      final callData = data['call'];
      final serverTimestamp =
          callData?['start_time'] ??
          data['call_start_time'] ??
          data['start_time'] ??
          data['timestamp'];

      if (serverTimestamp != null) {
        try {
          if (serverTimestamp is int) {
            serverStartTime = DateTime.fromMillisecondsSinceEpoch(
              serverTimestamp,
            );
          } else if (serverTimestamp is String) {
            // Handle timestamp format with spaces: "2025-09-03T06: 49: 20.253Z"
            String cleanedTimestamp = serverTimestamp.replaceAll(' ', '');
            serverStartTime = DateTime.tryParse(cleanedTimestamp);
          }
          if (serverStartTime != null) {
            _logger.i(
              '⏱️ CallManager: Server provided synchronized start_time from call data: $serverStartTime',
            );
          } else {
            _logger.w(
              '⚠️ CallManager: Failed to parse server start_time: "$serverTimestamp"',
            );
          }
        } catch (e) {
          _logger.w('⚠️ CallManager: Failed to parse server start_time: $e');
        }
      }

      // Log the full call data for debugging
      if (callData != null) {
        _logger.i('📞 CallManager: Call data from server: $callData');
        _logger.i(
          '📞 CallManager: Call status: ${callData['call_status']}, Start time: ${callData['start_time']}',
        );
      }

      // ALWAYS set startTime from server data for ALL users (including call maker) for synchronized display
      if (_currentCall != null && serverStartTime != null) {
        if (_currentCall!.startTime == null) {
          // First time setting startTime - use server start_time directly
          _currentCall = _currentCall!.copyWith(startTime: serverStartTime);
          final durationFromStart =
              DateTime.now().difference(serverStartTime).inSeconds;
          _logger.i(
            '⏱️ CallManager: Setting startTime from server for ALL users - startTime: $serverStartTime, current duration: ${durationFromStart}s',
          );
        } else {
          // Force sync if server time is significantly different
          final currentStartTime = _currentCall!.startTime!;
          final serverTimeDiff =
              currentStartTime.difference(serverStartTime).abs().inSeconds;

          if (serverTimeDiff > 2) {
            _currentCall = _currentCall!.copyWith(startTime: serverStartTime);
            final newDuration =
                DateTime.now().difference(serverStartTime).inSeconds;
            _logger.i(
              '🔄 CallManager: Force synchronized to server start_time - new duration: ${newDuration}s',
            );
          }
        }
      }

      // Check if this is the call maker's own join event
      bool skipOwnJoinEvent = false;
      final isOwnPeerId = peerId == userID.toString();
      final isOwnUserId = userId == userID.toString();

      if (isOwnPeerId || isOwnUserId) {
        skipOwnJoinEvent = true;
        _logger.d(
          '📍 CallManager: Own join event detected - PeerID match: $isOwnPeerId, UserID match: $isOwnUserId ($userId == $userID)',
        );
      }

      // Count total participants (excluding self if this is own join event)
      final totalParticipants =
          skipOwnJoinEvent
              ? _participants.length +
                  1 // +1 for self
              : _participants.length +
                  2; // +1 for self, +1 for the joining participant

      _logger.i(
        '🔍 CallManager: Participant count check - current: ${_participants.length}, total after join: $totalParticipants, isOwnJoin: $skipOwnJoinEvent',
      );
      _logger.i(
        '🔍 CallManager: Logic branches - will go to connected: ${totalParticipants >= 2 && !skipOwnJoinEvent}, will go to ringing: ${totalParticipants == 1 || skipOwnJoinEvent}',
      );

      // CRITICAL: Only transition to connected state when we have 2+ users AND it's not our own join event
      // This prevents the call maker's own join from starting the call
      if ((_state == CallState.connecting || _state == CallState.calling) &&
          totalParticipants >= 2 &&
          !skipOwnJoinEvent) {
        _logger.i(
          '✅ CallManager: Transitioning to connected state - 2+ users present ($totalParticipants total)',
        );

        // CRITICAL: Emergency stop caller tone and configure audio for call
        await _emergencyStopAllAudio();

        // CRITICAL: Also explicitly stop caller tone to fix phone ringtone continuing issue
        await _audioManager.stopCallerTone();

        // Configure audio with proper speaker state based on call type
        final useSpeaker = _currentCall?.callType == CallType.video;
        await _audioManager.configureAudioForCall(useSpeaker: useSpeaker);

        // 🚀 FINAL: WebRTC-native speaker enforcement for video calls in user_joined
        if (useSpeaker) {
          _logger.i(
            '🚀 FINAL: WebRTC-native speaker enforcement in user_joined...',
          );

          // Set speaker via WebRTC-native control
          await setSpeakerphone(true);

          _logger.i(
            '✅ FINAL: WebRTC-native speaker enforcement in user_joined completed',
          );
        }

        _setState(CallState.connected);

        // Clear timeout timers on successful connection
        _callTimeoutTimer?.cancel();
        _connectionTimeoutTimer?.cancel();
      } else if (totalParticipants == 1 || skipOwnJoinEvent) {
        _logger.i(
          '🔔 CallManager: Ringing condition met - totalParticipants: $totalParticipants, skipOwnJoin: $skipOwnJoinEvent',
        );

        if (skipOwnJoinEvent) {
          _logger.i(
            '🔔 CallManager: Call maker\'s own join event - maintaining ringing state, will configure audio',
          );
        } else {
          _logger.i(
            '🔔 CallManager: Maintaining ringing state - only 1 user present, waiting for 2nd participant',
          );
        }

        // Ensure we're in the correct ringing state based on call direction
        if (_state == CallState.connecting || _state == CallState.calling) {
          if (_currentCall?.isIncoming == true) {
            _setState(CallState.ringing);
          } else {
            _setState(CallState.calling);
          }
        }

        // Configure ringing audio based on call type
        final isVideoCall = _currentCall?.callType == CallType.video;
        _logger.i(
          '🔔 CallManager: Configuring ringing audio - isVideoCall: $isVideoCall, isIncoming: ${_currentCall?.isIncoming}',
        );

        if (_currentCall?.isIncoming == false) {
          // For outgoing calls, caller tone should already be playing from makeCall()
          // Don't restart it here to avoid "Loading interrupted" errors
          _logger.i(
            '📞 CallManager: Caller tone should already be playing from makeCall() - ${isVideoCall ? "video (speaker)" : "audio (earpiece)"}',
          );

          // Only ensure proper audio routing is configured without restarting ringtone
          // Use the public configureAudioForCall method but don't use emergency stop (which would kill the caller tone)
          _logger.d(
            '🎵 CallManager: Ensuring audio routing is configured for ongoing caller tone',
          );
          // Note: We don't call configureAudioForCall here as it would stop the caller tone
          // The caller tone from makeCall() should continue playing until 2nd user joins
        } else {
          // For incoming calls, ringtone is already handled elsewhere
          // Just ensure proper audio routing for the call type
          _logger.i(
            '📞 CallManager: Configuring audio for incoming call - ${isVideoCall ? "video (speaker)" : "audio (earpiece)"}',
          );
          final useSpeaker = isVideoCall;
          await _audioManager.configureAudioForCall(useSpeaker: useSpeaker);
        }
      }

      // Skip participant handling if it's us (but state/startTime logic already executed above)
      if (skipOwnJoinEvent) {
        _logger.d(
          '📍 CallManager: Skipping own join event participant handling (but state/timer logic already executed)',
        );
        return;
      }

      // CRITICAL: Check if participant already exists
      final existingParticipant = _participants[peerId];
      if (existingParticipant != null) {
        // Only update connection status, NOT the name (name comes from metadata only)
        final updatedParticipant = existingParticipant.copyWith(
          userId: userId,
          isConnected: true,
        );
        _participants[peerId] = updatedParticipant;
        _logger.i(
          '✅ Updated participant connection status (peerId: $peerId, name unchanged: ${existingParticipant.userName})',
        );
        // Notify UI about the connection update
        onParticipantJoined?.call(updatedParticipant);
      } else {
        // Create new participant - IMMEDIATELY use socket userData instead of temporary name
        String participantName;
        final existingMetadata = _peerMetadata[peerId];

        if (existingMetadata != null) {
          // Use existing metadata if available
          participantName = _extractNameFromMetadata(existingMetadata, userId);
          _logger.i(
            '✅ Using existing metadata for new participant: $participantName',
          );
        } else if (userData != null) {
          // CRITICAL: Use socket userData IMMEDIATELY - no temporary names!
          participantName = _extractUserName(userData, 'User $userId');
          _logger.i(
            '✅ Using socket userData for new participant: $participantName',
          );
        } else {
          // Last resort fallback (should rarely happen)
          participantName = 'User $userId';
          _logger.i('⚠️ Using fallback name for participant: $participantName');
        }

        final newParticipant = CallParticipant(
          peerId: peerId,
          userId: userId,
          userName: participantName,
          isConnected: true,
        );
        _participants[peerId] = newParticipant;
        _logger.i('✅ Created participant: $participantName (peerId: $peerId)');

        // Notify UI about new participant
        onParticipantJoined?.call(newParticipant);

        // No per-peer dial here: the PeerJS controller owns the mesh. On
        // `call:participantJoined` the newcomer dials US and we answer, which
        // keeps it to exactly one MediaConnection per pair
        // (PEERJS_MIGRATION.md §3). Nothing to initiate.
      }

      _logger.i('✅ CallManager: User joined processed successfully');
    } catch (e) {
      _logger.e('❌ Error handling user joined: $e');
      onError?.call('Error processing user joined: $e');
    }
  }

  /// NEW backend `call_session_left` — ONE participant left a group call that
  /// is still live for everyone else. Payload: `{ callId, userId }` (no
  /// `peer_id` / rich `user` object like the legacy mesh `user_left`, and no
  /// participant-count decision tree: the backend already decided the call
  /// continues — when it doesn't, it sends `call_session_ended` instead).
  ///
  /// This only reconciles session/UI bookkeeping (drop the leaver's tile). The
  /// PeerJS controller tears down that peer's MediaConnection independently
  /// on the `/calls` `call:participantLeft` broadcast. It must NEVER end the
  /// local call.
  void _handleCallSessionLeft(dynamic data) {
    try {
      final map = data is Map ? data : const {};
      final leftUserId =
          (map['userId'] ?? map['user_id'] ?? map['peerId'] ?? map['peer_id'])
              ?.toString();

      _logger.i('👋 CallManager: call_session_left — userId=$leftUserId');

      if (leftUserId == null || leftUserId.isEmpty) {
        _logger.w('⚠️ CallManager: call_session_left with no userId: $data');
        return;
      }

      // Our own leave is driven by leaveCall()/_cleanup(); ignore the echo.
      if (leftUserId == userID.toString()) {
        _logger.i('↩️ CallManager: call_session_left is our own — ignoring');
        return;
      }

      // On the PeerJS mesh path `_participants` is keyed by the remote
      // participant's backend user id (see _handleRemoteStreamAdded); fall
      // back to a scan by userId for any other keying.
      String? key;
      if (_participants.containsKey(leftUserId)) {
        key = leftUserId;
      } else {
        for (final entry in _participants.entries) {
          if (entry.value.userId == leftUserId) {
            key = entry.key;
            break;
          }
        }
      }

      if (key != null) {
        final gone = _participants.remove(key);
        _peerMetadata.remove(key);
        _logger.i(
          '✅ CallManager: removed participant ${gone?.userName ?? key} '
          'after call_session_left',
        );
        onStreamRemoved?.call(key);
        onParticipantLeft?.call(key);
      } else {
        _logger.i(
          'ℹ️ CallManager: call_session_left for $leftUserId — no local '
          'participant tile (already removed by the media layer)',
        );
      }

      // Do NOT end the local call here — a real collapse arrives as
      // `call_session_ended` and is handled by _handleCallEnded.
      onStateChanged?.call();
    } catch (e) {
      _logger.e('❌ CallManager: Error handling call_session_left: $e');
    }
  }

  /// Handle user left event
  void _handleUserLeft(dynamic data) {
    try {
      final peerId = data['peer_id'] as String?;

      if (peerId == null) {
        _logger.w('⚠️ Invalid user left data: $data');
        return;
      }

      // CRITICAL: Check if participant exists to prevent duplicate processing
      final participant = _participants[peerId];
      if (participant == null) {
        _logger.w(
          '⚠️ CallManager: Participant $peerId already removed or never existed',
        );
        // CRITICAL: Still notify UI even if participant not found to ensure cleanup
        onParticipantLeft?.call(peerId);
        onStreamRemoved?.call(peerId);
        return;
      }

      _logger.i('👤 CallManager: User left: ${participant.userName} ($peerId)');

      // CRITICAL: Remove participant from list first to prevent race conditions
      _participants.remove(peerId);
      _peerMetadata.remove(peerId); // Clean up metadata
      _logger.i('✅ Removed participant: ${participant.userName}');

      // The PeerJS controller closes this peer's MediaConnection itself on
      // the `call:participantLeft` broadcast — nothing to close here.

      // CRITICAL: Notify UI components IMMEDIATELY for cleanup
      onStreamRemoved?.call(peerId);
      onParticipantLeft?.call(peerId);

      // ENHANCED: Check if call should end based on remaining participants and call state
      // Only end the call if there's only 1 user left (just the local user) AND it's not a group call scenario
      final remainingUsers = _participants.length + 1; // +1 for local user
      final leftReason = data['reason']?.toString() ?? 'unknown';

      _logger.i(
        '👥 CallManager: Remaining users after user left: $remainingUsers (reason: $leftReason)',
      );

      // STATE-AWARE: Handle call ending based on current state
      final callData = data['call'];
      final currentUsers = callData?['current_users'] as List?;

      _logger.i(
        '🔍 CallManager: _handleUserLeft - State: ${_state.name}, remainingUsers: $remainingUsers, leftReason: $leftReason',
      );

      // ENHANCED: Handle different scenarios based on call state
      if (_state == CallState.connected) {
        // FIXED: CONNECTED STATE - Check if this is a group call before ending
        final callData = data['call'] ?? {};
        final chatData = data['chat'] ?? {};
        final callUsers = callData['users'] as List?;

        // FIXED: Use is_private flag with fallback logic for when chat data is missing
        final hasValidChatData = chatData.isNotEmpty;
        final isPrivateFromChatData = chatData['is_private'] == true;
        bool chatTypeIsGroup;

        if (hasValidChatData && chatData.containsKey('is_private')) {
          chatTypeIsGroup = !isPrivateFromChatData;
          _logger.i(
            '🔍 CallManager: CONNECTED - Using chat is_private flag: $isPrivateFromChatData -> isGroup: $chatTypeIsGroup',
          );
        } else {
          final uniqueUsers = callUsers?.toSet().toList() ?? [];
          final uniqueUserCount = uniqueUsers.length;
          chatTypeIsGroup = uniqueUserCount >= 3;
          _logger.i(
            '🔍 CallManager: CONNECTED - No chat data, using participant count: $uniqueUserCount -> isGroup: $chatTypeIsGroup',
          );
        }

        final originalCallUserCount = callUsers?.length ?? 1;

        // FIXED: Use consistent group detection logic with server data (same as _handleCallDeclined)
        final currentUsers = callData['current_users'] as List?;
        final remainingUserCount = currentUsers?.length ?? 0;
        final serverIndicatesMultipleUsers = remainingUserCount >= 2;
        final isActualGroupCall =
            chatTypeIsGroup ||
            originalCallUserCount >= 3 ||
            serverIndicatesMultipleUsers;

        _logger.i(
          '🔍 CallManager: CONNECTED Group Detection - chatTypeIsGroup: $chatTypeIsGroup, originalUsers: $originalCallUserCount, serverUsers: $remainingUserCount, serverIndicatesMultiple: $serverIndicatesMultipleUsers -> isActualGroupCall: $isActualGroupCall',
        );

        // End call based on call type and remaining users
        if (isActualGroupCall) {
          // For group calls: only end when 1 user remains (just local user)
          if (remainingUsers <= 1) {
            _logger.i(
              '🔚 CallManager: GROUP CONNECTED call - Only local user remains, ending call',
            );
            Future.delayed(Duration(milliseconds: 500), () {
              if (_state == CallState.connected) {
                endCall();
              }
            });
          } else {
            _logger.i(
              '✅ CallManager: GROUP CONNECTED call - $remainingUsers users still connected, call continues',
            );
          }
        } else {
          // For individual calls: end when 2 or fewer users remain
          if (remainingUsers <= 2) {
            _logger.i(
              '🔚 CallManager: INDIVIDUAL CONNECTED call - Only $remainingUsers user(s) remain, ending call',
            );
            Future.delayed(Duration(milliseconds: 500), () {
              if (_state == CallState.connected) {
                endCall();
              }
            });
          } else {
            _logger.i(
              '✅ CallManager: INDIVIDUAL CONNECTED call - $remainingUsers users still connected, call continues',
            );
          }
        }
      } else if (_state == CallState.calling || _state == CallState.ringing) {
        // FIXED: RINGING/CALLING STATE logic
        final callData = data['call'] ?? {};
        final chatData = data['chat'] ?? {};
        final callUsers = callData['users'] as List?;

        // FIXED: Use is_private flag with fallback logic for when chat data is missing
        final hasValidChatData = chatData.isNotEmpty;
        final isPrivateFromChatData = chatData['is_private'] == true;
        bool chatTypeIsGroup;

        if (hasValidChatData && chatData.containsKey('is_private')) {
          chatTypeIsGroup = !isPrivateFromChatData;
          _logger.i(
            '🔍 CallManager: RINGING - Using chat is_private flag: $isPrivateFromChatData -> isGroup: $chatTypeIsGroup',
          );
        } else {
          final uniqueUsers = callUsers?.toSet().toList() ?? [];
          final uniqueUserCount = uniqueUsers.length;
          chatTypeIsGroup = uniqueUserCount >= 3;
          _logger.i(
            '🔍 CallManager: RINGING - No chat data, using participant count: $uniqueUserCount -> isGroup: $chatTypeIsGroup',
          );
        }

        final originalCallUserCount = callUsers?.length ?? 1;

        // FIXED: Use consistent group detection logic with server data (same as _handleCallDeclined)
        final currentUsers = callData['current_users'] as List?;
        final remainingUserCount = currentUsers?.length ?? 0;
        final serverIndicatesMultipleUsers = remainingUserCount >= 2;
        final isActualGroupCall =
            chatTypeIsGroup ||
            originalCallUserCount >= 3 ||
            serverIndicatesMultipleUsers;

        _logger.i(
          '🔍 CallManager: RINGING Group Detection - chatTypeIsGroup: $chatTypeIsGroup, originalUsers: $originalCallUserCount, serverUsers: $remainingUserCount, serverIndicatesMultiple: $serverIndicatesMultipleUsers -> isActualGroupCall: $isActualGroupCall',
        );

        if (leftReason == 'declined_call') {
          if (isActualGroupCall) {
            // FIXED: For group calls during ringing, NEVER end the call due to individual declines
            // The call should continue for other potential participants
            _logger.i(
              '🔄 CallManager: Group RINGING/CALLING call - User declined, preserving call for other participants (original users: $originalCallUserCount)',
            );
            // Don't end the call - let other users potentially join
            return;
          } else {
            // For 1-on-1 calls, if the other user declines, end the call immediately
            _logger.i(
              '🔚 CallManager: 1-on-1 RINGING/CALLING call - Other user declined, ending call',
            );
            Future.delayed(Duration(milliseconds: 500), () {
              if (_state == CallState.calling || _state == CallState.ringing) {
                endCall();
              }
            });
          }
        } else if (remainingUsers <= 1 && leftReason != 'declined_call') {
          // Only end if it's not a decline and we're in a non-group scenario
          if (!isActualGroupCall) {
            _logger.i(
              '🔚 CallManager: RINGING/CALLING call - Only local user remains and not due to decline, ending call',
            );
            Future.delayed(Duration(milliseconds: 500), () {
              if (_state == CallState.calling || _state == CallState.ringing) {
                endCall();
              }
            });
          } else {
            _logger.i(
              '✅ CallManager: Group RINGING/CALLING call - Preserving call despite low participant count (original users: $originalCallUserCount)',
            );
          }
        } else {
          _logger.i(
            '✅ CallManager: RINGING/CALLING call - $remainingUsers users still available, call continues',
          );
        }
      } else {
        // OTHER STATES: Use original logic
        if (remainingUsers <= 1) {
          _logger.i(
            '🔚 CallManager: OTHER state (${_state.name}) - Only local user remains, ending call',
          );
          Future.delayed(Duration(milliseconds: 500), () {
            if (_state != CallState.idle && _state != CallState.ended) {
              endCall();
            }
          });
        }
      }

      // Server validation: Only end if server explicitly says no users are left
      if (currentUsers != null) {
        _logger.i(
          '📊 CallManager: Server reports ${currentUsers.length} active users',
        );

        // Only end if server explicitly says no users are left AND we're not in a critical call state
        if (currentUsers.isEmpty && _state == CallState.connected) {
          _logger.w(
            '⚠️ CallManager: Server reports no active users in connected call, ending call',
          );

          Future.delayed(Duration(milliseconds: 500), () {
            if (_state == CallState.connected) {
              endCall();
            }
          });
        }
      }

      _logger.i('✅ CallManager: User left processed successfully');
    } catch (e) {
      _logger.e('❌ Error handling user left: $e');
    }
  }

  /// Handle call ended from socket
  // NEW's `call_session_ended` also carries the server-driven 45s
  // auto-missed-call timeout (§19 checklist: "automatic 45s ringing-timeout
  // -> call_session_ended {reason:'missed'}") instead of a distinct
  // `missed_call` event — the exact `reason` field name/values aren't given
  // verbatim, so this checks a few reasonable candidates and routes to the
  // existing missed-call UX (`_handleCallMissed`) when they suggest a
  // timeout; otherwise it's a normal end.
  void _handleCallEnded(dynamic data) {
    try {
      _logger.i('🔚 CallManager: Call ended by server');
      _logger.i('🔍 CallManager: Call ended data: $data');

      final reason =
          (data is Map
                  ? (data['reason'] ?? data['endReason'] ?? data['end_reason'])
                  : null)
              ?.toString()
              .toLowerCase();
      if (reason != null &&
          (reason.contains('missed') || reason.contains('timeout') ||
              reason.contains('no_answer'))) {
        _logger.i('📞 CallManager: call_session_ended reason=$reason -> treating as missed call');
        _handleCallMissed(data is Map ? data : {});
        return;
      }

      // CRITICAL: Emergency stop all audio immediately (call end - restore session)
      _emergencyStopAllAudioAndRestore();

      // Update state to ended if not already
      if (_state != CallState.ended) {
        _setState(CallState.ended);
      }

      // Force cleanup to ensure proper state reset
      _cleanup();

      _logger.i('✅ CallManager: Call ended handled successfully');
    } catch (e) {
      _logger.e('❌ CallManager: Error handling call ended: $e');
      // Force cleanup even on error
      _forceCleanup();
    }
  }

  /// Handle call accepted confirmation (if backend sends this)
  void _handleCallAccepted(dynamic data) {
    _logger.i('✅ CallManager: Call accepted confirmation received');

    // NEW backend emits `call_session_answered` { callId, userId } to the
    // WHOLE conversation, so both the initiator and the answering callee
    // receive it (callee sees its own userId). `userId` is the participant
    // that just answered.
    final answeredUserId =
        (data is Map ? (data['userId'] ?? data['user_id']) : null)?.toString();
    _logger.d('CallManager: call_session_answered by user $answeredUserId');

    // --- Authoritative call start time -----------------------------------
    // `call_session_answered` carries `startedAt` (ISO-8601, e.g.
    // "2026-09-01T12:41:07.812Z") — the moment the server marked the call
    // ACTIVE. Use it as the single source of truth for the in-call duration
    // on every device:
    //   - initiator: `startTime` was never set (makeCall/POST /calls only
    //     creates the row), so the UI was stuck on "Calling..." — set it now.
    //   - callee: `incoming_call` set `startTime` to the call's CREATION
    //     time, which includes the ring interval, so the timer was ahead —
    //     re-sync it to the real answer time.
    // The UI's 1s duration ticker reads `currentCall.startTime` directly, so
    // updating it here is enough; `onStateChanged` below covers the notify.
    final startedAtRaw = data is Map
        ? (data['startedAt'] ??
            data['started_at'] ??
            data['startTime'] ??
            data['start_time'] ??
            (data['call'] is Map
                ? (data['call']['startedAt'] ?? data['call']['start_time'])
                : null))
        : null;
    if (startedAtRaw != null && _currentCall != null) {
      final serverStartedAt = DateTime.tryParse(
        startedAtRaw.toString().replaceAll(' ', ''),
      );
      if (serverStartedAt != null) {
        final current = _currentCall!.startTime;
        final driftSeconds =
            current?.difference(serverStartedAt).abs().inSeconds ?? 999;
        if (driftSeconds > 1) {
          _currentCall = _currentCall!.copyWith(startTime: serverStartedAt);
          _logger.i(
            '⏱️ CallManager: call_session_answered startedAt=$serverStartedAt '
            '-> synced call startTime (was $current, drift ${driftSeconds}s)',
          );
          onStateChanged?.call();
        }
      } else {
        _logger.w(
          '⚠️ CallManager: could not parse call_session_answered startedAt "$startedAtRaw"',
        );
      }
    }

    final isInitiator = _currentCall?.isIncoming == false;

    // --- Call state ---------------------------------------------------------
    // The old flow waited for a mesh `user_joined` to reach `connected`, but
    // that layer is deferred and never fires here, so the initiator would
    // hang on `connecting` until timeout. Mirror the receiver's
    // `acceptCall()`, which hard-transitions to `connected`.
    if (isInitiator &&
        (_state == CallState.calling || _state == CallState.connecting)) {
      _setState(CallState.connecting);
      _callTimeoutTimer?.cancel();
      _connectionTimeoutTimer?.cancel();
      _setState(CallState.connected);
    } else if (_state == CallState.calling) {
      _setState(CallState.connecting);
    }

    // --- Media (PeerJS mesh) --------------------------------------------
    // `call_session_answered` is broadcast to the WHOLE conversation, so in a
    // group call this handler runs on every participant's device whenever ANY
    // one of them answers. `call:join` requires this device's OWN participant
    // row to be `status:'joined'`, which only happens after
    // THIS device's REST step:
    //   - initiator  -> `POST /calls`        (done in makeCall, which already
    //                                          started media)
    //   - callee     -> `POST /calls/:id/answer` (done in acceptCall, which
    //                                          already started media)
    // A callee that hasn't answered yet is still `invited`/`ringing` here, so
    // `call:join` would be rejected with "Not an active participant". Only the
    // initiator uses this as a recovery path (if makeCall's start attempt
    // raced/failed); `_startMedia` is a no-op if media is already running.
    if (isInitiator && _currentCall?.callId != null) {
      _startMedia(
        callId: _currentCall!.callId!,
        userId: userID.toString(),
        callType: _currentCall!.callType,
      );
    }
  }

  /// Create (once) and start the PeerJS mesh media plane for the active call.
  /// Safe to call from multiple lifecycle points — the second call is a no-op
  /// while the first is still running or has completed.
  ///
  /// [callId] must already be `joined` server-side: the initiator's row is
  /// `joined` from `POST /calls`, the callee's from `POST /calls/:id/answer`,
  /// so both sides may `call:join` right after their REST step.
  Future<void> _startMedia({
    required String callId,
    required String userId,
    required CallType callType,
  }) async {
    if (_media != null) {
      _logger.i(
        '↩️ CallManager: _startMedia($callId) skipped — media plane already exists',
      );
      return; // already starting / started for this call
    }

    _logger.i('🚀 CallManager: starting PeerJS media plane (call=$callId)');
    final media = PeerJsCallController();
    _media = media;

    media.onRemoteStreamAdded = _handleRemoteStreamAdded;
    media.onRemoteStreamRemoved = _handleRemoteStreamRemoved;
    media.onLocalStream = (_) {
      _logger.i('📹 CallManager: local capture stream ready');
      onLocalStreamReady?.call();
    };
    media.onError = (e) => onError?.call(e);
    media.onCallEnded = (reason) {
      _logger.i('🔚 CallManager: media plane ended ($reason)');
      _handleCallEnded({'reason': reason});
    };
    media.onRemoteAudioStarted = () {
      // Re-assert the audio route the moment remote audio actually plays out.
      _audioManager
          .configureAudioForCall(useSpeaker: callType == CallType.video)
          .catchError((_) {});
    };
    media.onRemoteMediaState = _handleRemoteMediaState;

    try {
      await media.start(callId: callId, userId: userId, callType: callType);
    } catch (e) {
      _logger.e('❌ CallManager: media plane start failed: $e');
      onError?.call('Failed to connect call media: $e');
    }
  }

  /// Handle call declined from socket.
  /// NEW's `call_session_declined` payload shape isn't given verbatim —
  /// field lookups below try camelCase candidates first, falling back to
  /// OLD's snake_case. The join-count decision tree below relies on
  /// `_participants`, which is populated by the mesh-only `user_joined`
  /// event (deferred media layer) — under this lifecycle-only phase
  /// `_participants` will typically stay empty, so this handler mostly
  /// takes the "nobody joined yet" branch (end private calls, silently
  /// preserve group calls) until media is wired up.
  void _handleCallDeclined(dynamic data) {
    try {
      _logger.i('❌ CallManager: Call declined by remote user');
      _logger.i('🔍 CallManager: Decline data: $data');

      // Extract declining user information
      final decliningUserId =
          data['decliningUserId'] ??
          data['declining_user_id'] ??
          data['userId'] ??
          data['user_id'] ??
          data['peerId'] ??
          data['peer_id'];
      final decliningPeerId =
          data['decliningPeerId'] ??
          data['declining_peer_id'] ??
          data['peerId'] ??
          data['peer_id'] ??
          decliningUserId;
      final chatData = data['conversation'] ?? data['chat'] ?? {};
      final callData = data['call'] ?? {};

      // REQUIRED BEHAVIOR: Use real-time joinedUsers set (maintained from user_joined events)
      // The joinedUsers count is represented by _participants.length
      final joinedUsersCount = _participants.length;

      // Telemetry/logging for debugging as required
      _logger.i(
        '🔍 CallManager: Telemetry - joinedUsers.size: $joinedUsersCount',
      );
      _logger.i(
        '🔍 CallManager: Telemetry - decliningUserId: $decliningUserId',
      );
      _logger.i('🔍 CallManager: Telemetry - call state: ${_state.name}');
      _logger.i('🔍 CallManager: Chat data: $chatData');
      _logger.i('🔍 CallManager: Call data: $callData');

      // Check if the declining user was ever in joinedUsers
      final wasInJoinedUsers =
          decliningPeerId != null && _participants.containsKey(decliningPeerId);
      _logger.i(
        '🔍 CallManager: Telemetry - was declining user in joinedUsers: $wasInJoinedUsers',
      );

      // Extract chat_type to determine if this is a group call
      final chatType =
          chatData['type']?.toString() ?? chatData['chat_type']?.toString() ?? '';
      final isPrivate = chatType == 'private' || chatType == 'direct';
      final isGroupCall =
          chatType == 'group' || (!isPrivate && chatType.isNotEmpty);

      _logger.i(
        '🔍 CallManager: Telemetry - chatType: $chatType, isPrivate: $isPrivate, isGroupCall: $isGroupCall',
      );

      if (joinedUsersCount == 0) {
        if (isGroupCall) {
          // For group calls: don't end the call even if no users joined yet
          // The call should continue for other potential participants
          _logger.i(
            '🔄 CallManager: Decision path: joinedUsers.size == 0 BUT isGroupCall -> preserving call for other participants',
          );

          if (wasInJoinedUsers) {
            // User was actually joined, treat as user_left
            final userLeftData = {
              'peer_id': decliningPeerId,
              'user_id': decliningUserId,
              'reason': 'declined_call',
              'call': callData,
              'chat': chatData,
            };
            _logger.i(
              '🔄 CallManager: Converting decline to user_left for joined user in group call',
            );
            _handleUserLeft(userLeftData);
          } else {
            // User declined before joining - just update invite state
            _logger.i(
              '📝 CallManager: User declined before joining group call - updating invite state only',
            );
          }

          _logger.i(
            '✅ CallManager: Group call preserved - user declined but call continues for other participants',
          );
          return;
        } else {
          // Case 1: Private call with no users actually joined - end the call for the call maker
          _logger.i(
            '🔚 CallManager: Decision path: joinedUsers.size == 0 AND private call -> ending call (nobody actually joined)',
          );

          // CRITICAL: Emergency stop all audio immediately (call end - restore session)
          _emergencyStopAllAudioAndRestore();

          // Update state to ended and cleanup
          _setState(CallState.ended);
          _cleanup();

          _logger.i(
            '✅ CallManager: Call ended - no users had joined private call',
          );
          return;
        }
      } else if (joinedUsersCount >= 2) {
        // Case 2: Multiple users joined - do not end the call, just handle the decline
        _logger.i(
          '🔄 CallManager: Decision path: joinedUsers.size >= 2 -> preserving call, removing declining participant',
        );

        if (wasInJoinedUsers) {
          // User was actually joined, treat as user_left
          final userLeftData = {
            'peer_id': decliningPeerId,
            'user_id': decliningUserId,
            'reason': 'declined_call',
            'call': callData,
            'chat': chatData,
          };
          _logger.i(
            '🔄 CallManager: Converting decline to user_left for joined user',
          );
          _handleUserLeft(userLeftData);
        } else {
          // User declined before joining - just update invite state
          _logger.i(
            '📝 CallManager: User declined before joining - updating invite state only',
          );
          // Note: No specific invite tracking in current implementation,
          // but call continues for other participants
        }

        // Notify remaining participants about the decline
        _logger.i('✅ CallManager: Call continues with remaining participants');
        return;
      } else {
        // Case 3: joinedUsersCount >= 1 (but < 2)
        if (!wasInJoinedUsers) {
          // Declining user was never in joinedUsers (declined before joining)
          // Don't touch the ongoing call if we have at least 1 joined user
          _logger.i(
            '📝 CallManager: Decision path: decline from non-joined user, preserving call (joinedUsers.size >= 1)',
          );
          _logger.i(
            '✅ CallManager: Call preserved - user declined before joining',
          );
          return;
        } else {
          // The declining user was actually joined - this is more complex
          // Since they're leaving and we have < 2 total, this might end the call
          // But according to requirements, we should still check the final count after they leave
          _logger.i(
            '🔄 CallManager: Joined user is declining, handling as user_left',
          );

          final userLeftData = {
            'peer_id': decliningPeerId,
            'user_id': decliningUserId,
            'reason': 'declined_call',
            'call': callData,
            'chat': chatData,
          };
          _handleUserLeft(userLeftData);
          return;
        }
      }
    } catch (e) {
      _logger.e('❌ CallManager: Error handling call decline: $e');
      // Force cleanup even on error
      _forceCleanup();
    }
  }

  /// Handle call missed from socket
  void _handleCallMissed(dynamic data) {
    try {
      _logger.i('📞 CallManager: Call missed event received');
      _logger.i('🔍 CallManager: Missed call data: $data');

      // Parse missed call data
      final Map<String, dynamic> missedCallInfo = {};

      if (data is Map<String, dynamic>) {
        missedCallInfo.addAll(data);
      }

      // Add current call information if available
      if (_currentCall != null) {
        missedCallInfo['local_call_info'] = {
          'chat_id': _currentCall!.chatId,
          'call_id': _currentCall!.callId,
          'call_type': _currentCall!.callType.name,
          'is_incoming': _currentCall!.isIncoming,
          'caller_name': _currentCall!.callerName,
          'duration': callDuration?.inSeconds ?? 0,
        };
      }

      // Add current state information
      missedCallInfo['call_state'] = _state.name;
      missedCallInfo['timestamp'] = DateTime.now().toIso8601String();

      // Determine missed call type based on current state and call direction
      if (_currentCall?.isIncoming == true && _state == CallState.ringing) {
        // Receiver didn't answer incoming call
        missedCallInfo['missed_call_type'] = 'incoming_not_answered';
        _logger.i(
          '📞 CallManager: Missed call type: Incoming call not answered by receiver',
        );
      } else if (_currentCall?.isIncoming == false &&
          (_state == CallState.calling || _state == CallState.ringing)) {
        // Caller cancelled outgoing call before receiver answered
        missedCallInfo['missed_call_type'] = 'outgoing_cancelled';
        _logger.i(
          '📞 CallManager: Missed call type: Outgoing call cancelled by caller',
        );
      } else {
        // Generic missed call
        missedCallInfo['missed_call_type'] = 'generic';
        _logger.i('📞 CallManager: Missed call type: Generic missed call');
      }

      // CRITICAL: Emergency stop all audio immediately (missed call - restore session)
      _emergencyStopAllAudioAndRestore();

      // Update state to ended first
      _setState(CallState.ended);

      // Notify UI about missed call with detailed information
      onMissedCall?.call(missedCallInfo);

      // CRITICAL: For missed calls, transition to idle after cleanup to trigger proper navigation
      Future.delayed(Duration(milliseconds: 500), () async {
        if (_state == CallState.ended) {
          await _cleanup();
          _logger.i(
            '📞 CallManager: Missed call cleanup completed, transitioning to idle',
          );
        }
      });

      _logger.i('✅ CallManager: Missed call handled successfully');
    } catch (e) {
      _logger.e('❌ CallManager: Error handling missed call: $e');
      // Force cleanup even on error
      _forceCleanup();
    }
  }

  /// Handle call failed from backend (if supported)
  void _handleCallFailed(dynamic data) {
    _logger.e(
      '❌ CallManager: Call failed from backend - ${data['reason'] ?? 'Unknown reason'}',
    );
    _setState(CallState.failed);
    onError?.call('Call failed: ${data['reason'] ?? 'Unknown reason'}');
    _cleanup();
  }

  /// Handle peer disconnected (if backend supports this)
  void _handlePeerDisconnected(dynamic data) {
    final peerId = data['peer_id'] as String?;
    if (peerId != null) {
      _logger.w('⚠️ CallManager: Peer disconnected from backend: $peerId');
      _handleUserLeft(data);
    }
  }

  /// NEW: Handle real-time call changes for audio/video state updates
  void _handleCallChanges(dynamic data) {
    try {
      _logger.i('🔄 CallManager: Call changes received: $data');

      final roomId = data['room_id'] as String?;
      final peerId = data['peer_id'] as String?;
      final isAudioEnabled = data['isAudioEnabled'] as bool?;
      final isVideoEnabled = data['isVideoEnabled'] as bool?;

      if (roomId == null || peerId == null) {
        _logger.w('⚠️ Invalid call changes data: $data');
        return;
      }

      // Only process if this is for our current call
      if (_currentCall?.roomId != roomId) {
        _logger.w(
          '⚠️ Call changes for different room: $roomId (current: ${_currentCall?.roomId})',
        );
        return;
      }

      // Update participant state
      final participant = _participants[peerId];
      if (participant != null) {
        final updatedParticipant = participant.copyWith(
          hasAudio: isAudioEnabled ?? participant.hasAudio,
          hasVideo: isVideoEnabled ?? participant.hasVideo,
        );
        _participants[peerId] = updatedParticipant;

        _logger.i(
          '✅ Updated participant $peerId - Audio: ${updatedParticipant.hasAudio}, Video: ${updatedParticipant.hasVideo}',
        );

        // Notify UI about the changes
        onParticipantJoined?.call(updatedParticipant);
      } else {
        _logger.w('⚠️ Participant $peerId not found for call changes update');
      }

      _logger.i('✅ CallManager: Call changes processed successfully');
    } catch (e) {
      _logger.e('❌ Error handling call changes: $e');
    }
  }

  /// Handle remote stream added
  void _handleRemoteStreamAdded(String peerId, MediaStream stream) {
    try {
      _logger.i('📹 CallManager: Remote stream added for: $peerId');

      // Validate stream
      if (stream.getTracks().isEmpty) {
        _logger.w('⚠️ Empty stream received from $peerId');
        return;
      }

      // Update or create participant
      final participant = _participants[peerId];
      if (participant != null) {
        // Update existing participant
        _participants[peerId] = participant.copyWith(
          isConnected: true,
          hasVideo: stream.getVideoTracks().isNotEmpty,
          hasAudio: stream.getAudioTracks().isNotEmpty,
          stream: stream,
        );

        _logger.i(
          '✅ Updated participant $peerId - Video: ${stream.getVideoTracks().length}, Audio: ${stream.getAudioTracks().length}',
        );

        // The participant may have been created earlier with a generic
        // "User <id>" placeholder (no metadata / no user_joined event on the
        // mesh path). Now that a stream is flowing, take another shot at a
        // real name — locally first, then an async server back-fill.
        final refreshed = _participants[peerId]!;
        if (_isUnresolvedCallerName(refreshed.userName)) {
          final betterId = int.tryParse(refreshed.userId) != null &&
                  refreshed.userId != '0'
              ? refreshed.userId
              : (int.tryParse(peerId) != null ? peerId : refreshed.userId);
          final betterName = _bestEffortParticipantName(betterId);
          if (!_isUnresolvedCallerName(betterName)) {
            _participants[peerId] =
                refreshed.copyWith(userName: betterName, userId: betterId);
            onParticipantJoined?.call(_participants[peerId]!);
          } else {
            _backfillParticipantName(peerId: peerId, userId: betterId);
          }
        }
      } else {
        // CRITICAL: Create participant if not exists (for cases where stream arrives before user_joined event)
        _logger.i('🆕 Creating temporary participant for stream: $peerId');

        // Try to use metadata if available, otherwise use temporary name
        final metadata = _peerMetadata[peerId];
        String participantName;
        // On the PeerJS mesh path there is no `user_joined` event carrying a
        // rich user object — the only identifier we get is the remote
        // participant's backend user id, which IS this stream key (`peerId`).
        // Use it so the name can actually be resolved instead of "User 0".
        String userId = metadata?['user_id']?.toString() ??
            (int.tryParse(peerId) != null ? peerId : '0');

        if (metadata != null) {
          // Use consistent metadata extraction
          participantName = _extractNameFromMetadata(metadata, userId);

          _logger.i(
            '✅ Using metadata for participant: $participantName (UserID: $userId, PeerID: $peerId)',
          );
        } else {
          // No metadata: resolve the name from locally available data (chat
          // list peer + saved contacts), and kick off an async peer-profile
          // back-fill if that still isn't enough.
          participantName = _bestEffortParticipantName(userId);
          _logger.i(
            '🔎 No metadata for $peerId — resolved participant name locally: $participantName (UserID: $userId)',
          );
          if (_isUnresolvedCallerName(participantName)) {
            _backfillParticipantName(peerId: peerId, userId: userId);
          }
        }

        final newParticipant = CallParticipant(
          peerId: peerId,
          userId: userId,
          userName: participantName,
          isConnected: true,
          hasVideo: stream.getVideoTracks().isNotEmpty,
          hasAudio: stream.getAudioTracks().isNotEmpty,
          stream: stream,
        );

        _participants[peerId] = newParticipant;

        _logger.i(
          '✅ Created temporary participant $participantName (UserID: $userId, PeerID: $peerId) - Video: ${stream.getVideoTracks().length}, Audio: ${stream.getAudioTracks().length}',
        );

        // Notify UI about new participant (will be updated with real name later)
        onParticipantJoined?.call(newParticipant);
      }

      // Notify UI about stream
      onStreamAdded?.call(peerId, stream);

      // CRITICAL: Immediately log debug info after stream update to verify state changes
      _logger.i('🔍 ===== CALL DEBUGGING INFO =====');
      _logger.i('🔍 Call State: ${_state.name}');
      _logger.i('🔍 Participant Count: ${_participants.length}');
      _logger.i('🔍 Remote Renderers: ${_participants.keys.toList()}');
      _logger.i('🔍 Detailed Participant Info:');

      int participantIndex = 1;
      for (final participant in _participants.values) {
        _logger.i('🔍   Participant $participantIndex:');
        _logger.i('🔍     UserID: ${participant.userId}');
        _logger.i('🔍     UserName: ${participant.userName}');
        _logger.i('🔍     PeerID: ${participant.peerId}');
        _logger.i('🔍     Connected: ${participant.isConnected}');
        _logger.i('🔍     HasVideo: ${participant.hasVideo}');
        _logger.i('🔍     HasAudio: ${participant.hasAudio}');
        // Also show metadata status
        final hasMetadata = _peerMetadata.containsKey(participant.peerId);
        _logger.i('🔍     HasMetadata: $hasMetadata');
        if (hasMetadata) {
          final metadata = _peerMetadata[participant.peerId];
          _logger.i(
            '🔍     Metadata: ${metadata?['user_name']} / ${metadata?['full_name']} / ${metadata?['first_name']}',
          );
        }
        participantIndex++;
      }
      _logger.i('🔍 ================================');
    } catch (e) {
      _logger.e('❌ Error handling remote stream added: $e');
    }
  }

  /// A remote peer's mic/camera state changed (`call:mediaState`). Reflect it
  /// on the participant so the call UI swaps the frozen last video frame for
  /// the avatar placeholder (and updates the mic-muted indicator) rather than
  /// leaving a stale image on screen — a disabled remote track stops RTP but
  /// the MediaConnection stays open, so the renderer keeps the last decoded
  /// frame until we tell the UI the video is off.
  void _handleRemoteMediaState(String peerId, bool audio, bool video) {
    final participant = _participants[peerId];
    if (participant == null) {
      // Normal on the mesh path: `call:participantJoined` and the join
      // snapshot both carry mediaState, and they can arrive before the peer's
      // stream has created the tile. The controller re-applies the last known
      // state on the first `stream` event, so nothing is lost.
      _logger.d(
        '📍 CallManager: media state (audio=$audio, video=$video) for '
        'participant $peerId that has no tile yet',
      );
      return;
    }

    final updated = participant.copyWith(hasAudio: audio, hasVideo: video);
    _participants[peerId] = updated;
    _logger.i(
      '⏯️ CallManager: participant $peerId mic ${audio ? 'ON' : 'OFF'}, '
      'camera ${video ? 'ON' : 'OFF'}',
    );

    // Same channel the UI already listens on for participant state changes.
    onParticipantJoined?.call(updated);
  }

  /// Handle remote stream removed
  void _handleRemoteStreamRemoved(String peerId) {
    try {
      _logger.i('📹 CallManager: Remote stream removed for: $peerId');

      // Update participant
      final participant = _participants[peerId];
      if (participant != null) {
        _participants[peerId] = participant.copyWith(
          isConnected: false,
          hasVideo: false,
          hasAudio: false,
          stream: null,
        );
        _logger.i('✅ Updated participant $peerId - stream removed');
      }

      // Notify UI
      onStreamRemoved?.call(peerId);
    } catch (e) {
      _logger.e('❌ Error handling remote stream removed: $e');
    }
  }

  /// Toggle audio
  void toggleAudio(bool enabled) {
    _media?.toggleAudio(enabled);
    _emitCallChanges(isAudioEnabled: enabled);
  }

  /// Toggle video.
  ///
  /// Turning the camera ON in a call captured without one rebuilds every
  /// MediaConnection (PEERJS_MIGRATION.md §3), so the controller's side is
  /// async — but this stays fire-and-forget so the UI flips instantly, exactly
  /// as it did before.
  void toggleVideo(bool enabled) {
    final media = _media;
    if (media != null) unawaited(media.toggleVideo(enabled));
    _emitCallChanges(isVideoEnabled: enabled);
  }

  /// NEW: Emit call_changes event for real-time audio/video state updates
  void _emitCallChanges({bool? isAudioEnabled, bool? isVideoEnabled}) {
    if (_currentCall?.roomId == null || !isInCall) {
      _logger.w('⚠️ Cannot emit call changes - no active call');
      return;
    }

    try {
      final data = <String, dynamic>{
        'room_id': _currentCall!.roomId!,
        'peer_id': userID.toString(),
      };

      if (isAudioEnabled != null) {
        data['isAudioEnabled'] = isAudioEnabled;
      }
      if (isVideoEnabled != null) {
        data['isVideoEnabled'] = isVideoEnabled;
      }

      socket.emit('call_changes', data: data);
      _logger.i('📤 CallManager: Emitted call_changes: $data');
    } catch (e) {
      _logger.e('❌ Error emitting call changes: $e');
    }
  }

  /// Switch camera
  Future<void> switchCamera() async {
    await _media?.switchCamera();
  }

  /// Speaker (earpiece <-> loudspeaker) routing. Handled entirely by
  /// CallAudioManager now — it wraps `Helper.setSpeakerphoneOn` plus the
  /// native platform channel and the Android earpiece-enumeration fallback
  /// that the old WebRTCService duplicated.
  Future<void> setSpeakerphone(bool enabled) async {
    _logger.i('🔊 CallManager: speaker route -> ${enabled ? "SPEAKER" : "EARPIECE"}');

    try {
      await _audioManager.toggleSpeaker(enabled);
      _logger.i(
        '✅ CallManager: speaker route applied - ${enabled ? "SPEAKER" : "EARPIECE"}',
      );
    } catch (e) {
      _logger.e('❌ CallManager: speaker route failed: $e');

      // Emergency fallback
      try {
        await _audioManager.toggleSpeaker(enabled);
        _logger.w('🚨 Emergency speaker fallback successful');
      } catch (fallbackError) {
        _logger.e('❌ Emergency speaker fallback failed: $fallbackError');
      }
    }
  }

  /// Configure audio for call with speaker state
  Future<void> configureAudioForCallWithSpeaker(bool useSpeaker) async {
    await _audioManager.configureAudioForCall(useSpeaker: useSpeaker);
    _logger.i('🎵 CallManager: Audio configured with speaker: $useSpeaker');
  }

  /// CRITICAL FIX: Force reset audio session for subsequent calls
  Future<void> forceResetAudioSessionForNextCall() async {
    try {
      _logger.i('🔄 CallManager: Force resetting audio session for next call');
      await _audioManager.forceResetAudioSessionForNextCall();
      _logger.i('✅ CallManager: Audio session force reset completed');
    } catch (e) {
      _logger.e('❌ CallManager: Audio session force reset failed: $e');
      rethrow;
    }
  }

  /// Generate unique session ID
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'session-$timestamp-$random';
  }

  /// Generate room ID based on chat ID
  String _generateRoomId(int chatId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'room-$chatId-$timestamp';
  }

  /// Update state with enhanced logging
  void _setState(CallState newState) {
    if (_state != newState) {
      final oldState = _state;
      _state = newState;
      _logger.i(
        '🔄 CallManager: State change: ${oldState.name} → ${newState.name}',
      );

      // Notify listeners
      onStateChanged?.call();

      // Handle state-specific actions
      _handleStateChange(oldState, newState);
    }
  }

  /// Handle state change actions
  void _handleStateChange(CallState oldState, CallState newState) {
    switch (newState) {
      case CallState.connected:
        _logger.i('📞 Call connected successfully');
        break;
      case CallState.ended:
        _logger.i('🔚 Call ended');
        break;
      case CallState.failed:
        _logger.e('❌ Call failed');
        onError?.call('Call failed');
        break;
      default:
        break;
    }
  }

  /// Enhanced cleanup with proper error handling
  Future<void> _cleanup() async {
    try {
      _logger.i('🧹 CallManager: Starting cleanup...');

      // CRITICAL: Prevent cleanup during ongoing operations
      if (_state == CallState.idle) {
        _logger.d('⚠️ CallManager: Already cleaned up');
        return;
      }

      _setState(CallState.ended);

      // CRITICAL: Emergency stop all audio first for immediate silence (cleanup - restore session)
      await _emergencyStopAllAudioAndRestore();

      // Then do regular cleanup
      await _audioManager.cleanup();

      // Cancel timeout timers
      _callTimeoutTimer?.cancel();
      _connectionTimeoutTimer?.cancel();

      // Clean up participants and metadata
      _participants.clear();
      _peerMetadata.clear();

      // CRITICAL: Small delay to allow any pending stream events to complete
      // before disposing WebRTC to prevent "Cannot add new events after calling close" error
      await Future.delayed(Duration(milliseconds: 100));

      // Dispose the PeerJS media plane — closes every MediaConnection and
      // the Peer, stops the local capture stream, emits `call:leave`, and
      // closes the `/calls` socket.
      try {
        await _media?.dispose();
        _media = null;
        _logger.i('✅ PeerJS media plane disposed - all audio stopped');
      } catch (e) {
        _media = null;
        _logger.w('⚠️ Error disposing PeerJS media plane: $e');
      }

      // Clear call info
      _currentCall = null;
      _sessionId = null;
      _roomId = null;

      // Small delay before setting to idle
      await Future.delayed(Duration(milliseconds: 200));

      _setState(CallState.idle);

      _logger.i('✅ CallManager: Cleanup completed');
    } catch (e) {
      _logger.e('❌ Error during cleanup: $e');
      await _forceCleanup();
    }
  }

  /// Force cleanup in case of errors
  Future<void> _forceCleanup() async {
    try {
      _logger.w('🚨 CallManager: Force cleanup...');

      _state = CallState.idle;
      _currentCall = null;
      _sessionId = null;
      _roomId = null;
      _participants.clear();
      _peerMetadata.clear();

      // Cancel timeout timers
      _callTimeoutTimer?.cancel();
      _connectionTimeoutTimer?.cancel();

      // Force dispose the PeerJS media plane
      try {
        await _media?.dispose();
      } catch (e) {
        _logger.w('⚠️ Error disposing PeerJS media plane: $e');
      }
      _media = null;

      _logger.w('✅ CallManager: Force cleanup completed');
    } catch (e) {
      _logger.e('❌ Error in force cleanup: $e');
    }
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'state': _state.name,
      'isInitialized': _isInitialized,
      'isInCall': isInCall,
      'sessionId': _sessionId,
      'roomId': _roomId,
      'participantCount': participantCount,
      'participants': _participants.keys.toList(),
      'currentCall':
          _currentCall != null
              ? {
                'chatId': _currentCall!.chatId,
                'callId': _currentCall!.callId,
                'callType': _currentCall!.callType.name,
                'isIncoming': _currentCall!.isIncoming,
                'callerName': _currentCall!.callerName,
              }
              : null,
      'mediaStatus': _media?.getConnectionStatus() ?? {'active': false},
      'hasMissedCallCallback': onMissedCall != null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Test missed call handling (for debugging)
  void testMissedCallHandler(Map<String, dynamic> testData) {
    _logger.i(
      '🧪 CallManager: Testing missed call handler with data: $testData',
    );
    _handleCallMissed(testData);
  }

  /// Extract name from metadata with consistent key handling
  String _extractNameFromMetadata(
    Map<String, dynamic> metadata,
    String userId,
  ) {
    // Use same priority order as socket data
    final userName = metadata['user_name']?.toString();
    final fullName = metadata['full_name']?.toString();
    final firstName = metadata['first_name']?.toString();

    if (userName != null && userName.isNotEmpty) {
      return userName;
    } else if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    } else if (firstName != null && firstName.isNotEmpty) {
      return firstName;
    } else {
      return 'User $userId';
    }
  }

  /// Extract user name with priority order: contact_name > user_name > full_name > first_name + last_name > name > fallback
  String _extractUserName(
    Map<String, dynamic>? userData, [
    String fallback = 'Unknown',
  ]) {
    if (userData == null) {
      _logger.d(
        '🔍 _extractUserName: userData is null, using fallback: $fallback',
      );
      return fallback;
    }

    _logger.d('🔍 _extractUserName: Processing userData: $userData');

    // PRIORITY 0: Check if user is saved in contacts (HIGHEST PRIORITY)
    final userId = userData['user_id'];
    if (userId != null) {
      try {
        final userIdInt = int.tryParse(userId.toString());

        // Ensure contacts are loaded if not already cached
        if (!ContactNameService.instance.hasCachedContacts) {
          _logger.d(
            '🔍 _extractUserName: Contact cache empty, triggering load',
          );
          ContactNameService.instance.loadAndCacheContacts().catchError((e) {
            _logger.w('⚠️ _extractUserName: Failed to load contacts: $e');
          });
        }

        if (userIdInt != null &&
            ContactNameService.instance.isUserInContacts(userIdInt)) {
          // Get the saved contact name
          final configProvider = _getConfigProvider();
          if (configProvider != null) {
            final contactDisplayName = ContactNameService.instance
                .getDisplayName(
                  userId: userIdInt,
                  userFullName: userData['full_name'] as String?,
                  userName: userData['user_name'] as String?,
                  userEmail: userData['email'] as String?,
                  configProvider: configProvider,
                );

            // Only use contact name if it's different from server data (indicating it was found in contacts)
            final serverFullName = userData['full_name'] as String? ?? '';
            final serverUserName = userData['user_name'] as String? ?? '';

            if (contactDisplayName != serverFullName &&
                contactDisplayName != serverUserName &&
                contactDisplayName != 'Unknown User') {
              _logger.d(
                '🔍 _extractUserName: Using CONTACT name: $contactDisplayName',
              );
              return contactDisplayName;
            }
          }
        }
      } catch (e) {
        _logger.w('⚠️ _extractUserName: Error checking contacts: $e');
      }
    }

    // Priority 1: user_name (matches socket data - e.g., "Amit67")
    final userName = userData['user_name'] as String?;
    if (userName != null && userName.trim().isNotEmpty) {
      _logger.d('🔍 _extractUserName: Using user_name: $userName');
      return userName.trim();
    }

    // Priority 2: full_name (e.g., "Amit Primo")
    final fullName = userData['full_name'] as String?;
    if (fullName != null && fullName.trim().isNotEmpty) {
      _logger.d('🔍 _extractUserName: Using full_name: $fullName');
      return fullName.trim();
    }

    // Priority 3: first_name + last_name
    final firstName = userData['first_name'] as String?;
    final lastName = userData['last_name'] as String?;
    if (firstName != null && firstName.trim().isNotEmpty) {
      final name = firstName.trim();
      if (lastName != null && lastName.trim().isNotEmpty) {
        final fullNameFromParts = '$name ${lastName.trim()}';
        _logger.d(
          '🔍 _extractUserName: Using first_name + last_name: $fullNameFromParts',
        );
        return fullNameFromParts;
      }
      _logger.d('🔍 _extractUserName: Using first_name only: $name');
      return name;
    }

    // Priority 4: name (generic name field)
    final name = userData['name'] as String?;
    if (name != null && name.trim().isNotEmpty) {
      _logger.d('🔍 _extractUserName: Using name: $name');
      return name.trim();
    }

    // Priority 5: username (without underscore)
    final username = userData['username'] as String?;
    if (username != null && username.trim().isNotEmpty) {
      _logger.d('🔍 _extractUserName: Using username: $username');
      return username.trim();
    }

    // Fallback
    _logger.d('🔍 _extractUserName: No name found, using fallback: $fallback');
    return fallback;
  }

  /// Get ConfigProvider instance for contact name resolution
  ProjectConfigProvider? _getConfigProvider() {
    try {
      // Try to get from current context if available
      final context = WidgetsBinding.instance.rootElement;
      if (context != null) {
        return Provider.of<ProjectConfigProvider>(context, listen: false);
      }
    } catch (e) {
      _logger.w('⚠️ Could not get ConfigProvider: $e');
    }
    return null; // Will cause ContactNameService to use fallback behavior
  }

  /// Get ChatProvider instance (for peer-name lookup) if a context is available.
  ChatProvider? _getChatProvider() {
    try {
      final context = WidgetsBinding.instance.rootElement;
      if (context != null) {
        return Provider.of<ChatProvider>(context, listen: false);
      }
    } catch (e) {
      _logger.w('⚠️ Could not get ChatProvider: $e');
    }
    return null;
  }

  /// True when [name] is empty or one of the generic placeholders that means
  /// "we don't actually know who is calling yet".
  bool _isUnresolvedCallerName(String? name) {
    if (name == null) return true;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return true;
    final lower = trimmed.toLowerCase();
    return lower == 'unknown' ||
        lower == 'unknown caller' ||
        lower == 'unknown user' ||
        trimmed.startsWith('Caller ') ||
        trimmed.startsWith('User ');
  }

  /// Resolve a display name for [userId] from locally available data:
  /// contacts / final-name cache first, then the chat list's peer data.
  /// Returns null when nothing better than a placeholder can be found.
  String? _resolveCallerNameFromUserId(int userId) {
    try {
      // Pull a full name from the chat list peer data if we have that chat.
      String? peerFullName;
      final chatProvider = _getChatProvider();
      if (chatProvider != null) {
        for (final chat in chatProvider.chatListData.chats) {
          final peer = chat.peerUserData;
          if (peer?.userId == userId &&
              (peer?.fullName?.trim().isNotEmpty ?? false)) {
            peerFullName = peer!.fullName!.trim();
            break;
          }
        }
      }

      if (!ContactNameService.instance.hasCachedContacts) {
        ContactNameService.instance.loadAndCacheContacts().catchError((e) {
          _logger.w('⚠️ _resolveCallerNameFromUserId: contact load failed: $e');
        });
      }

      final resolved = ContactNameService.instance.getDisplayNameStable(
        userId: userId,
        configProvider: _getConfigProvider(),
        contextFullName: peerFullName,
      );

      if (resolved.trim().isNotEmpty &&
          !resolved.toLowerCase().startsWith('unknown')) {
        return resolved.trim();
      }
      return peerFullName;
    } catch (e) {
      _logger.w('⚠️ _resolveCallerNameFromUserId error: $e');
      return null;
    }
  }

  // Peer ids we've already issued a profile back-fill for, so repeated stream
  // events (audio, then video) for the same peer don't spam the API.
  final Set<String> _nameBackfillInFlight = {};

  ProfileStatusRepository? _profileRepositoryInstance;
  ProfileStatusRepository get _profileRepository =>
      _profileRepositoryInstance ??= ProfileStatusRepository(apiClient);

  /// Best-effort display name for a call participant known only by [userId].
  /// The PeerJS media plane carries no names, so this tries locally
  /// available data — the chat list's peer entry and saved contacts — and
  /// otherwise returns a generic `User <id>` placeholder that
  /// [_backfillParticipantName] can replace from the server.
  String _bestEffortParticipantName(String userId) {
    final uid = int.tryParse(userId);
    if (uid != null && uid > 0) {
      final resolved = _resolveCallerNameFromUserId(uid);
      if (resolved != null && resolved.trim().isNotEmpty) {
        return resolved.trim();
      }
    }
    return 'User $userId';
  }

  /// Fetch [userId]'s public profile and, if the matching participant is still
  /// showing a generic `User <id>` placeholder, swap in the real name and push
  /// the update to the UI.
  Future<void> _backfillParticipantName({
    required String peerId,
    required String userId,
  }) async {
    final uid = int.tryParse(userId);
    if (uid == null || uid <= 0) return;
    if (!_nameBackfillInFlight.add(peerId)) return;

    try {
      final model = await _profileRepository.getPeerUserProfileRepo(uid);
      final record = (model.data?.records?.isNotEmpty ?? false)
          ? model.data!.records!.first
          : null;
      String? resolvedName;
      if ((record?.fullName?.trim().isNotEmpty ?? false)) {
        resolvedName = record!.fullName!.trim();
      } else if ((record?.userName?.trim().isNotEmpty ?? false)) {
        resolvedName = record!.userName!.trim();
      }
      if (resolvedName == null) return;

      final current = _participants[peerId];
      if (current == null) return;
      // Someone (metadata / a later event) may have set a real name already.
      if (!_isUnresolvedCallerName(current.userName)) return;

      final updated = current.copyWith(userName: resolvedName, userId: userId);
      _participants[peerId] = updated;
      _logger.i(
        '✅ CallManager: back-filled participant name for $peerId → $resolvedName',
      );
      onParticipantJoined?.call(updated);
    } catch (e) {
      _logger.w(
        '⚠️ CallManager: participant name back-fill failed for $peerId: $e',
      );
    } finally {
      _nameBackfillInFlight.remove(peerId);
    }
  }

  /// Check if peer exists
  bool hasPeer(String peerId) {
    return _participants.containsKey(peerId);
  }

  /// Get participant by peer ID
  CallParticipant? getParticipant(String peerId) {
    return _participants[peerId];
  }

  /// Get participant by user ID
  CallParticipant? getParticipantByUserId(String userId) {
    try {
      return _participants.values.firstWhere(
        (participant) => participant.userId == userId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get all participants with their user ID mapping
  Map<String, CallParticipant> getParticipantsByUserId() {
    final Map<String, CallParticipant> userIdMap = {};
    for (final participant in _participants.values) {
      if (participant.userId.isNotEmpty) {
        userIdMap[participant.userId] = participant;
      }
    }
    return userIdMap;
  }

  /// Get user ID to peer ID mapping
  Map<String, String> getUserIdToPeerIdMapping() {
    final Map<String, String> mapping = {};
    for (final participant in _participants.values) {
      if (participant.userId.isNotEmpty) {
        mapping[participant.userId] = participant.peerId;
      }
    }
    _logger.i('👥 CallManager: User ID to Peer ID mapping: $mapping');
    return mapping;
  }

  /// Get detailed participant information for debugging
  List<Map<String, dynamic>> getDetailedParticipantInfo() {
    return _participants.values
        .map(
          (participant) => {
            'userId': participant.userId,
            'userName': participant.userName,
            'peerId': participant.peerId,
            'isConnected': participant.isConnected,
            'hasVideo': participant.hasVideo,
            'hasAudio': participant.hasAudio,
            'joinedAt': participant.joinedAt.toIso8601String(),
          },
        )
        .toList();
  }

  /// Check metadata status for all participants
  void validateMetadataStatus() {
    _logger.i('🔍 METADATA STATUS CHECK:');
    for (final participant in _participants.values) {
      final hasMetadata = _peerMetadata.containsKey(participant.peerId);
      final metadata = _peerMetadata[participant.peerId];
      final status =
          participant.userName.contains('Connecting') ||
                  participant.userName.contains('Peer ')
              ? '❌ Missing'
              : '✅ Received';
      _logger.i('   ${participant.peerId}: $status (${participant.userName})');
      if (hasMetadata && metadata != null) {
        _logger.i(
          '     → Metadata: user_name=${metadata['user_name']}, full_name=${metadata['full_name']}, first_name=${metadata['first_name']}',
        );
      } else {
        _logger.i('     → No metadata stored');
      }
    }

    // Also log current metadata store
    _logger.i('🔍 STORED METADATA:');
    _peerMetadata.forEach((peerId, metadata) {
      _logger.i(
        '   $peerId: user_name=${metadata['user_name']}, full_name=${metadata['full_name']}, first_name=${metadata['first_name']}',
      );
    });
  }

  /// Force reset the call manager
  Future<void> forceReset() async {
    _logger.w('🚨 CallManager: Force reset...');
    try {
      // Force end any active call
      if (isInCall) {
        await endCall();
      }

      // Force cleanup
      await _forceCleanup();

      _logger.w('✅ CallManager: Force reset completed');
    } catch (e) {
      _logger.e('❌ Error in force reset: $e');
    }
  }

  /// Check if service is ready
  bool get isReady {
    return _isInitialized && (_media?.isInitialized ?? true);
  }

  /// Check if current call is a group call based on participant count
  /// A group call is defined as having more than 2 total participants (including local user)
  bool get isGroupCall {
    if (_currentCall == null) return false;
    final totalParticipants = _participants.length + 1; // +1 for local user
    return totalParticipants > 2;
  }

  /// Check if current call has the potential to be a group call
  /// This is useful during the ringing phase when we don't know who will join yet
  bool get isPotentialGroupCall {
    // This would ideally check chat member count from chat data
    // For now, we assume it's a potential group call if we have chat data indicating group type
    return _currentCall !=
        null; // Can be enhanced with actual group member count
  }

  /// Get current call duration
  Duration? get callDuration {
    if (_currentCall?.startTime == null) return null;
    return DateTime.now().difference(_currentCall!.startTime!);
  }

  /// Format call duration
  String get formattedCallDuration {
    final duration = callDuration;
    if (duration == null) return '00:00';

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Emergency stop all audio for CALL ACCEPT (WebRTC-safe)
  Future<void> _emergencyStopAllAudio() async {
    try {
      _logger.w('🚨 FIXED: Emergency stop for CALL ACCEPT (WebRTC-safe)');

      // Stop both services without them calling each other
      await Future.wait([
        _audioManager.emergencyStopAudio(), // FIXED: WebRTC-safe version
        CallNotificationManager.instance.emergencyStopNotification(),
      ]);

      _logger.w(
        '🚨 FIXED: Emergency stop completed (WebRTC session preserved)',
      );
    } catch (e) {
      _logger.e('❌ CallManager: Emergency stop failed: $e');
    }
  }

  /// Emergency stop all audio for CALL END (kills WebRTC session)
  Future<void> _emergencyStopAllAudioAndRestore() async {
    try {
      _logger.w('🚨 CallManager: Emergency stop for CALL END (full restore)');

      // Stop both services without them calling each other
      await Future.wait([
        _audioManager
            .emergencyStopAudioAndRestore(), // Full restoration for call end
        CallNotificationManager.instance.emergencyStopNotification(),
      ]);

      _logger.w('🚨 CallManager: Emergency stop and restore completed');
    } catch (e) {
      _logger.e('❌ CallManager: Emergency stop and restore failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // The engine (and every FlutterEventSink backing the WebRTC event
      // channels) is about to be destroyed. Close peer connections now so no
      // late native callback is posted to a dead messenger — the cause of the
      // EXC_BAD_ACCESS in flutter_webrtc's postEvent().
      _teardownForEngineDetach();
    }
  }

  void _teardownForEngineDetach() {
    final media = _media;
    _media = null;
    if (media == null) return;
    _logger.w('🛑 CallManager: app detached mid-call — force-closing media plane');
    // Fire-and-forget: the isolate is going down, we only need the native
    // close()/dispose() calls to be issued before it does.
    media.dispose().catchError((e) {
      _logger.w('⚠️ CallManager: detach teardown failed: $e');
    });
  }

  /// Dispose with proper cleanup
  Future<void> dispose() async {
    _logger.i('🧹 CallManager: Disposing...');

    if (_lifecycleObserverAdded) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserverAdded = false;
    }

    // Cancel all timers
    _callTimeoutTimer?.cancel();
    _connectionTimeoutTimer?.cancel();

    // CRITICAL: Remove socket listeners to prevent memory leaks and duplicate events
    try {
      socket.off('call');
      socket.off('receiving_call');
      socket.off('incoming_call');
      socket.off('user_joined');
      socket.off('user_left');
      socket.off('call_session_left');
      socket.off('call_ended');
      socket.off('call_session_ended');
      socket.off('call_declined');
      socket.off('call_session_declined');
      socket.off('call_missed');
      socket.off('call_accepted');
      socket.off('call_session_answered');
      socket.off('call_failed');
      socket.off('peer_disconnected');
      socket.off('call_changes');
      _logger.i('✅ Socket listeners removed');
    } catch (e) {
      _logger.w('⚠️ Error removing socket listeners: $e');
    }

    await _cleanup();
    _isInitialized = false;
  }
}
