// *****************************************************************************************
// * Filename: socket_service.dart (FIXED VERSION)
// * Developer: Deval Joshi
// * Date: May, 2025                                                                     *
// * Description: Fixed socket service with proper connection management                 *
// *****************************************************************************************

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:get_it/get_it.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/utils/logger.dart' show ConsoleAppLogger;
import 'package:whoxa/utils/network_info.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

// Enum to represent the connection state of the socket
enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class SocketService {
  // Singleton pattern implementation
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  // Initialize with non-late field and direct initialization in constructor
  final _logger = ConsoleAppLogger.forModule('SocketService');
  final NetworkInfo _networkInfo;

  // Socket.io instance - ONLY ONE INSTANCE
  io.Socket? _socket;

  // Connection state stream controller
  final _connectionStateController =
      StreamController<SocketConnectionState>.broadcast();
  Stream<SocketConnectionState> get connectionState =>
      _connectionStateController.stream;

  // Event types that need to be handled
  final Map<String, List<Function(dynamic)>> _eventHandlers = {};

  // Configuration
  static const String socketBaseUrl = ApiEndpoints.socketUrl;
  String _socketUrl = socketBaseUrl;
  // NEW's default-namespace gateway uses the socket.io library's default
  // path (`/socket.io/`), not OLD's custom `/socket` (§7.2/§7.8 breaking
  // change #6) — null here means "don't override", so OptionBuilder never
  // calls .setPath() and the library default applies.
  String? _socketPath;
  bool _initialized = false;
  bool _connecting = false;

  // Constructor now takes networkInfo directly
  SocketService._internal() : _networkInfo = GetIt.instance<NetworkInfo>();

  // Initialize the socket service
  void initialize({
    String? socketUrl,
    String? socketPath,
    Map<String, dynamic>? authData,
    int maxRetryAttempts = 5,
    int retryDelayMs = 3000,
  }) {
    if (_initialized) {
      _logger.i('SocketService already initialized');
      return;
    }

    _socketUrl = socketUrl ?? socketBaseUrl;
    _socketPath = socketPath; // null = library default, see field comment
    _initialized = true;

    _logger.i('SocketService initialized with URL: $_socketUrl');
  }

  Future<bool> connect() async {
    // Prevent multiple connection attempts
    if (_connecting) {
      _logger.i('Connection already in progress');
      return false;
    }

    // Check if already connected
    if (_socket != null && _socket!.connected) {
      _logger.i('Socket is already connected');
      _connectionStateController.add(SocketConnectionState.connected);
      return true;
    }

    _connecting = true;

    try {
      // Check network connection first
      bool hasConnection = false;
      try {
        hasConnection = await _networkInfo.isConnected;
      } catch (e) {
        _logger.e('Error checking network connection', e);
        hasConnection = true; // Continue even if network check fails
      }

      if (!hasConnection) {
        _logger.e('No internet connection. Cannot connect to socket');
        _connectionStateController.add(SocketConnectionState.error);
        _connecting = false;
        throw AppError('No internet connection', isNetworkError: true);
      }

      _connectionStateController.add(SocketConnectionState.connecting);
      _logger.i('Connecting to socket server: $_socketUrl');

      // Get the authentication token
      final token = await SecurePrefs.getString(SecureStorageKeys.TOKEN);
      if (token == null || token.isEmpty) {
        _logger.e('No authentication token available');
        _connectionStateController.add(SocketConnectionState.error);
        _connecting = false;
        throw AppError('No authentication token', isNetworkError: false);
      }

      _logger.i('User token available');
      _logger.i('User token: $token');

      // IMPORTANT: Disconnect existing socket if any
      if (_socket != null) {
        _logger.i('Cleaning up existing socket connection');
        _socket!.clearListeners();
        _socket!.disconnect();
        _socket!.close();
        _socket = null;
      }

      // Create NEW socket instance with proper configuration.
      // NEW's default-namespace gateway checks handshake.auth.token first,
      // then a standard Authorization: Bearer header — the custom "token"
      // header OLD used is no longer read at all. No custom path override
      // either — NEW uses the socket.io library default (§7.2/§7.8).
      final optionBuilder = io.OptionBuilder()
          .setTransports(['websocket', 'polling']) // Include both transports
          .setAuth({'token': token})
          .enableAutoConnect() // Let socket.io handle auto-connection
          .setReconnectionAttempts(5)
          .setReconnectionDelay(3000)
          .setReconnectionDelayMax(30000)
          .enableForceNew(); // Force new connection
      if (_socketPath != null) {
        optionBuilder.setPath(_socketPath!);
      }

      _socket = io.io(_socketUrl, optionBuilder.build());

      // Set up event listeners BEFORE connecting
      _setupSocketListeners();

      // Connect to the socket server
      _socket!.connect();

      // Wait for connection with timeout
      final completer = Completer<bool>();
      Timer? timeoutTimer;

      // Setup temporary listeners for connection response.
      // NEW sends NO error payload on auth failure — it just silently
      // disconnects (§7.2/§7.8 breaking change #7), unlike OLD's
      // `connect_error` message. Also resolving on `disconnected` (not
      // just `connected`/`error`) means a silent-disconnect auth failure
      // fails this connect() call immediately instead of idling out the
      // full 15s timeout below — this subscription is torn down the
      // moment any of these three fire, so a disconnect seen here can only
      // be the initial-handshake kind, never one from an
      // already-established, later session.
      late StreamSubscription subscription;
      subscription = _connectionStateController.stream.listen((state) {
        if (state == SocketConnectionState.connected) {
          if (!completer.isCompleted) {
            completer.complete(true);
            timeoutTimer?.cancel();
            subscription.cancel();
          }
        } else if (state == SocketConnectionState.error ||
            state == SocketConnectionState.disconnected) {
          if (!completer.isCompleted) {
            _logger.w(
              'Socket $state before ever connecting — likely a silent auth failure',
            );
            completer.complete(false);
            timeoutTimer?.cancel();
            subscription.cancel();
          }
        }
      });

      // Add timeout
      timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          _logger.w('Socket connection timeout');
          completer.complete(false);
          subscription.cancel();
        }
      });

      final result = await completer.future;
      _connecting = false;
      return result;
    } catch (e) {
      _logger.e('Error connecting to socket server', e);
      _connectionStateController.add(SocketConnectionState.error);
      _connecting = false;
      return false;
    }
  }

  // Set up socket event listeners - ONLY CALL ONCE PER SOCKET
  void _setupSocketListeners() {
    if (_socket == null) return;

    // Catch-all inbound-event logger: fires for EVERY event the server
    // emits, including ones nothing has registered a handler for, so
    // renamed/unexpected events are visible in the debug console instead of
    // silently disappearing. Purely observational — it neither consumes the
    // event nor stops the per-event `on()` handlers below from running.
    _socket!.onAny((event, data) {
      _logEventPayload(event, data);
    });

    _socket!.onConnect((_) {
      _logger.i('Socket connected successfully');
      log('CONNECTED', name: 'SOCKET');
      _connectionStateController.add(SocketConnectionState.connected);
      // Reset on successful connection
    });

    _socket!.onConnectError((error) {
      _logger.e('Socket connection error', error);
      log('CONNECTION ERROR: $error', name: 'SOCKET');
      _connectionStateController.add(SocketConnectionState.error);
    });

    _socket!.onDisconnect((reason) {
      _logger.w('Socket disconnected: $reason');
      log('DISCONNECTED: $reason', name: 'SOCKET');
      _connectionStateController.add(SocketConnectionState.disconnected);
    });

    _socket!.onError((error) {
      _logger.e('Socket error occurred', error);
      log('ERROR: $error', name: 'SOCKET');
      _connectionStateController.add(SocketConnectionState.error);
    });

    // Register all existing event handlers
    for (final entry in _eventHandlers.entries) {
      final event = entry.key;
      for (final handler in entry.value) {
        _socket!.on(event, (data) {
          try {
            handler(data);
          } catch (e) {
            _logger.e('Error in event handler for $event', e);
          }
        });
      }
    }
  }

  // Pretty-prints one inbound socket event. The console truncates long
  // lines, so a big payload is emitted in ~800-char chunks.
  void _logEventPayload(String event, dynamic data) {
    String payload;
    try {
      payload = const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      // Not JSON-encodable (binary ack, custom object, …) — fall back.
      payload = data.toString();
    }

    _logger.d('📩 SOCKET EVENT [$event]');
    for (var i = 0; i < payload.length; i += 800) {
      final end = i + 800 < payload.length ? i + 800 : payload.length;
      log(payload.substring(i, end), name: 'SOCKET[$event]');
    }
  }

  // Manually disconnect from the socket server
  void disconnect() {
    if (_socket != null) {
      _logger.i('Manually disconnecting socket');
      _socket!.disconnect();
      _connectionStateController.add(SocketConnectionState.disconnected);
    }
  }

  // Close and clean up all socket resources
  void closeSocket() {
    if (_socket != null) {
      _socket!.clearListeners();
      _socket!.disconnect();
      _socket!.close();
      _socket = null;
      _logger.i('Socket closed and listeners removed');
      log('Socket closed and listeners removed', name: "SOCKET");
    }
  }

  // Register a custom event handler
  void on(String event, Function(dynamic) handler) {
    if (!_eventHandlers.containsKey(event)) {
      _eventHandlers[event] = [];
    }

    _eventHandlers[event]!.add(handler);

    // Register the event with socket.io if we have an active socket
    if (_socket != null) {
      _socket!.on(event, (data) {
        _logger.d('Received event $event: $data');
        _notifyEventHandlers(event, data);
      });
    }

    _logger.d('Registered handler for event: $event');
  }

  // Notify all registered handlers for a specific event
  void _notifyEventHandlers(String event, dynamic data) {
    if (_eventHandlers.containsKey(event)) {
      for (var handler in _eventHandlers[event]!) {
        try {
          handler(data);
        } catch (e) {
          _logger.e('Error in event handler for $event', e);
        }
      }
    }
  }

  // Remove a specific event handler
  void off(String event, [Function(dynamic)? handler]) {
    if (handler == null) {
      // Remove all handlers for this event
      _eventHandlers.remove(event);
      if (_socket != null) {
        _socket!.off(event);
      }
      _logger.d('Removed all handlers for event: $event');
    } else if (_eventHandlers.containsKey(event)) {
      // Remove specific handler
      _eventHandlers[event]!.remove(handler);

      // If no handlers left, remove the event listener from socket
      if (_eventHandlers[event]!.isEmpty) {
        _eventHandlers.remove(event);
        if (_socket != null) {
          _socket!.off(event);
        }
      }
      _logger.d('Removed specific handler for event: $event');
    }
  }

  // Emit an event to the server
  void emit(
    String event, {
    dynamic data,
    Function(dynamic)? callback,
    bool withAck = false,
  }) {
    if (_socket != null && _socket!.connected) {
      _logger.d('Emitting event $event: $data');

      if (withAck && callback != null) {
        if (data != null) {
          _socket!.emitWithAck(event, data, ack: callback);
        } else {
          _socket!.emitWithAck(event, data, ack: callback);
        }
      } else {
        if (data != null) {
          _socket!.emit(event, data);
        } else {
          _socket!.emit(event);
        }
      }
    } else {
      _logger.w('Cannot emit event $event: Socket not connected');
      throw AppError(
        'Socket not connected. Cannot emit event: $event',
        isNetworkError: false,
      );
    }
  }

  // Check if socket is connected
  bool get isConnected => _socket?.connected ?? false;

  // Get current socket ID
  String? get socketId => _socket?.id;

  // Update authentication data
  Future<void> updateAuthData(Map<String, dynamic> newAuthData) async {
    _logger.i('Updating auth data');

    if (_socket != null && _socket!.connected) {
      // Disconnect and reconnect with new auth data
      disconnect();

      // Wait a bit before reconnecting
      await Future.delayed(Duration(milliseconds: 500));

      // Reconnect
      await connect();
    }
  }

  // Listen for connection status
  void onConnect(Function() callback) {
    if (_socket != null) {
      _socket!.onConnect((_) => callback());
    }
  }

  // Listen for disconnection status
  void onDisconnect(Function() callback) {
    if (_socket != null) {
      _socket!.onDisconnect((_) => callback());
    }
  }

  // Handle errors
  void onError(Function(dynamic error) callback) {
    if (_socket != null) {
      _socket!.onError((error) => callback(error));
    }
  }

  // ✅ NEW: Complete reset method for logout scenarios
  void reset() {
    _logger.i('Resetting SocketService to clean state');

    try {
      // Cancel any existing connection attempts
      _connecting = false;

      // Close and dispose current socket
      if (_socket != null) {
        _socket!.clearListeners();
        _socket!.disconnect();
        _socket!.close();
        _socket = null;
        _logger.i('Socket instance completely destroyed');
      }

      // Clear all event handlers
      _eventHandlers.clear();
      _logger.i('All event handlers cleared');

      // Reset all state flags

      _initialized = false;
      _connecting = false;

      // Reset connection state without closing the stream controller
      // (we need to keep it alive for future connections)
      _connectionStateController.add(SocketConnectionState.disconnected);

      _logger.i(
        'SocketService reset completed - ready for fresh initialization',
      );
    } catch (e) {
      _logger.e('Error during SocketService reset', e);
    }
  }

  // Dispose the socket service (for complete app shutdown)
  void dispose() {
    _logger.i('Disposing SocketService');

    closeSocket();

    // Close stream controllers
    _connectionStateController.close();

    _initialized = false;
  }
}

// Socket events class
class SocketEvents {
  // NEW: presence is global (not shared-chat-scoped) and slimmed to
  // {userId, isOnline} — a single `presence_update` event replaces both
  // OLD's `online_user` and `offline_user` (the `isOnline` field carries
  // the direction), and `presence_snapshot` (`{onlineUserIds:string[]}`,
  // connect-time-only, NOT re-requestable) replaces `initial_online_user`
  // (§5.4/§7.5/§13.14).
  final String presenceSnapshot = "presence_snapshot";
  final String presenceUpdate = "presence_update";

  // Typing — NEW splits OLD's single toggle event into explicit
  // client->server start/stop events, and a single server->client broadcast
  // that carries the direction as a bool (confirmed against ClientEvents/
  // ServerEvents in socket.types.ts).
  final String typingStart = "typing_start"; // emit
  final String typingStop = "typing_stop"; // emit
  final String userTyping = "user_typing"; // listen

  // NEW's real server->client push for a sent message (confirmed against
  // ServerEvents.NEW_MESSAGE in socket.types.ts).
  final String newMessage = "new_message";

  // Read receipts — NEW uses a per-conversation watermark (`upToSeq`), not
  // a per-message "seen" event. Client emits `message_read`; server
  // broadcasts `message_read_update` to the whole room (incl. the sender).
  // There is no NEW equivalent of a per-message seen/delivered push.
  final String messageRead = "message_read"; // emit
  final String messageReadUpdate = "message_read_update"; // listen

  // Pin/unpin are two separate server events, not one combined toggle.
  final String messagePinned = "message_pinned";
  final String messageUnpinned = "message_unpinned";

  // Delete-for-everyone is the only delete socket event NEW has — there is
  // no server broadcast for delete-for-me (it's private to the requester).
  final String messageDeletedEvent = "message_deleted";

  // Edit (and other in-place message changes). Payload is the full
  // `toPublicMessage` object, same shape as `PATCH /messages/:id` returns;
  // broadcast to the whole room, the editor's own devices included.
  final String messageUpdated = "message_updated";

  // Block/unblock. Payload is just `{userId: "<the other party>"}` — no
  // chat id, and nothing saying which side of the block this session is on
  // (it reaches the blocked user too). So it is not a block-state change to
  // apply locally, it's a "re-read that user" ping answered with a
  // `GET /users/batch?ids=` call: blocking flips what that peer's curated
  // user object exposes (`lastSeenVisible`, `lastSeenAt`, `isOnline`,
  // profile picture).
  final String userBlocked = "user_blocked"; // listen
  final String userUnblocked = "user_unblocked"; // listen

  // ❌ REMOVED: `messageList`/`chatList`/`chatlocked`/`chatUnlocked` (legacy
  // Socket.IO-driven pagination + a chat-lock feature that don't exist on
  // NEW at all — it's REST-paginated); `starUnstarMessage`/
  // `archiveChatEvent`/`archivedChatListEvent`/`blockUpdates`/`adminMessage`
  // (NEW never emits any of these — star/unstar and archive still require a
  // client-side re-fetch after the local REST action; OLD's combined
  // `block_updates` is gone, replaced by the `user_blocked`/`user_unblocked`
  // pair above, which only ever reaches the blocker's own sessions;
  // system/admin messages arrive as regular `new_message`
  // events with `type: 'system'` instead of a separate event). Confirmed
  // absent from `ServerEvents`/`ClientEvents` in the backend's
  // `socket.types.ts`.

  // Polls: NEW broadcasts `poll_updated` (`{messageId, poll}`, viewer-neutral
  // `toBroadcastPoll()` shape — no `viewerVoted`, but `voters` id-list is
  // present whenever results are visible and the poll isn't anonymous) to
  // the whole conversation room on every vote AND on close
  // (`PollsService.emitPollUpdated`, `polls.service.ts`). This replaces the
  // old, now-incorrect assumption that poll votes never push live.
  final String pollUpdated = "poll_updated";

  /// Live Stream
  final String startLive = "start_live";
  final String stopLive = "stop_live";
  final String joinLive = "join_live";
  final String leaveLive = "leave_live";
  final String activityOnLive = "activity_on_live";

  // Call emit
  final String makeCall = "call";
  final String acceptCall = "accept_call";
  final String rejectCall = "decline_call";
  final String endCall = "leave_call";

  // Call listen
  final String call = "call";
  final String declineCall = "call_declined";
  final String userJoinedCall = "user_joined";
  final String callEnded = "call_ended";
  final String missCall = "missed_call";
  final String userLeft = "user_left";

  // AI Assistant (server -> client, sent to the human participant only).
  // `ai_message_chunk` is `{conversationId, delta}` — an ephemeral preview of
  // the reply while it generates, never persisted; the finished reply
  // arrives as a normal `new_message` from the bot user.
  // `ai_message_error` is `{conversationId}` — generation failed; a fallback
  // bot reply still arrives via `new_message`.
  final String aiMessageChunk = 'ai_message_chunk';
  final String aiMessageError = 'ai_message_error';

  // AI (old `/chatbot` flow)
  final String botMessageChunk = 'bot_message_chunk';
  final String botMessageComplete = 'bot_message_complete';
  final String sendBotMessage = 'send_bot_message';
}
