// *****************************************************************************
// * calls_socket_service.dart
// *
// * Dedicated socket.io connection to the backend's `/calls` namespace — the
// * PeerJS mesh signaling plane (see whoxa-nest-api/src/calls/calls.gateway.ts,
// * `@WebSocketGateway({ namespace: 'calls' })`). It no longer carries media
// * itself: since the mediasoup→PeerJS migration the namespace only
// * authenticates the participant, hands out one peer id per call, shares the
// * roster of peer ids + the PeerServer/ICE config, and relays mic/cam on-off
// * state. Media is peer-to-peer (see PEERJS_MIGRATION.md §1–2).
// *
// * This is intentionally a SEPARATE io.Socket from the default-namespace
// * `SocketService` (chat/presence/ringing). The backend runs the media-plane
// * signaling on its own namespace with its own connection lifecycle: it only
// * matters while a call is live. Multiplexing it onto the chat socket would
// * tie media-plane teardown to chat-socket churn. It reuses the same base URL
// * and the same JWT (handshake `auth.token`) as the chat socket — no new
// * credentials, no new backend contract.
// *
// * Reconnect (PEERJS_MIGRATION.md §5): the PeerServer Peer and every
// * MediaConnection die with this socket, so auto-reconnect is ENABLED and a
// * successful reconnect is surfaced as [onReconnected] — the caller must then
// * do a full rejoin (new `call:join`, new `selfPeerId`, re-dial everyone). A
// * drop is only fatal ([onDropped]) once socket.io gives up retrying.
// *
// * Ack contract (calls.gateway.ts `safe()` wrapper): on success the handler's
// * value is returned directly as the ack payload; on failure the ack is
// * `{ error: string }`. There is no `{ success: true }` envelope.
// *****************************************************************************

import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/utils/logger.dart' show ConsoleAppLogger;
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

/// Thrown when a `/calls` signaling request is rejected by the server
/// (`{ error }` ack) or never acknowledged.
class CallsSignalingException implements Exception {
  CallsSignalingException(this.event, this.message);
  final String event;
  final String message;
  @override
  String toString() => 'CallsSignalingException($event): $message';
}

class CallsSocketService {
  CallsSocketService({String? baseUrl})
    : _url =
          '${(baseUrl ?? ApiEndpoints.socketUrl).replaceAll(RegExp(r'/+$'), '')}/calls';

  final String _url;
  final _logger = ConsoleAppLogger.forModule('CallsSocket');

  /// How many times socket.io retries the `/calls` namespace before the drop
  /// is declared fatal. With ~1–5s backoff this is roughly 40s of retrying,
  /// which comfortably covers a cell↔wifi handover without leaving a dead call
  /// on screen indefinitely.
  static const int _reconnectionAttempts = 10;

  io.Socket? _socket;
  bool _connecting = false;
  bool _hasConnected = false;

  /// Fired every time the namespace connection drops after having connected.
  /// With auto-reconnect on this is usually recoverable — [onReconnected]
  /// follows — so it is informational. [onDropped] is the fatal one.
  void Function(String reason)? onDisconnected;

  /// Fired when the namespace reconnects after a drop. Everything the media
  /// plane built on the previous connection is gone (PEERJS_MIGRATION.md §5),
  /// so the caller must tear the media plane down and run the whole join flow
  /// again — it gets a NEW `selfPeerId` and other participants see it leave
  /// and rejoin.
  void Function()? onReconnected;

  /// Fired when socket.io gives up reconnecting ([_reconnectionAttempts]
  /// exhausted), or the connection is closed by the server. Only now is a
  /// mid-call drop unrecoverable and the call must be torn down.
  void Function(String reason)? onDropped;

  bool get isConnected => _socket?.connected ?? false;
  String? get socketId => _socket?.id;

  /// Open the `/calls` namespace connection. Resolves `true` once connected,
  /// `false` on timeout or auth failure. Safe to call again while already
  /// connected (returns `true` immediately).
  Future<bool> connect({Duration timeout = const Duration(seconds: 15)}) async {
    if (_socket?.connected == true) return true;
    if (_connecting) {
      _logger.i('connect() already in progress');
      return false;
    }
    _connecting = true;

    try {
      final token = await SecurePrefs.getString(SecureStorageKeys.TOKEN);
      if (token == null || token.isEmpty) {
        _logger.e('No auth token — cannot open /calls namespace');
        return false;
      }

      // Tear down any stale instance first.
      _teardownSocket();

      final options =
          io.OptionBuilder()
              .setTransports(['websocket', 'polling'])
              .setAuth({'token': token})
              .disableAutoConnect()
              .enableForceNew()
              // PEERJS_MIGRATION.md §5: a drop is recoverable by rejoining, so
              // retry rather than treating the first blip as the end of the call.
              .enableReconnection()
              .setReconnectionAttempts(_reconnectionAttempts)
              .setReconnectionDelay(1000)
              .setReconnectionDelayMax(5000)
              .build();

      final socket = io.io(_url, options);
      _socket = socket;
      _hasConnected = false;

      final completer = Completer<bool>();
      Timer? timer;

      void finish(bool ok) {
        if (completer.isCompleted) return;
        timer?.cancel();
        completer.complete(ok);
      }

      socket.onConnect((_) {
        // socket.io fires `connect` again on every successful reconnect, so
        // this doubles as the reconnect signal — the manager's own `reconnect`
        // event is not forwarded to the namespace socket.
        if (_hasConnected) {
          _logger.i('/calls RECONNECTED: ${socket.id} — caller must rejoin');
          onReconnected?.call();
          return;
        }
        _hasConnected = true;
        _logger.i('/calls connected: ${socket.id}');
        finish(true);
      });
      socket.onConnectError((e) {
        _logger.e('/calls connect_error: $e');
        // After the first successful connect this is a failed retry, not a
        // failed open — socket.io keeps retrying, so don't resolve anything.
        if (!_hasConnected) finish(false);
      });
      socket.onDisconnect((reason) {
        _logger.w('/calls disconnected: $reason');
        // Only a post-connection drop is interesting; a pre-connect
        // disconnect is already handled by the connect() failure path.
        if (completer.isCompleted) {
          final why = reason?.toString() ?? 'disconnected';
          onDisconnected?.call(why);
          // A server-side disconnect is never retried by socket.io, so it is
          // immediately fatal; anything else gets the retry budget first.
          if (why == 'io server disconnect') onDropped?.call(why);
        } else {
          finish(false);
        }
      });
      // Manager-level: the retry budget is exhausted, so the call is over.
      socket.io.on('reconnect_failed', (_) {
        _logger.e(
          '/calls reconnect_failed — giving up after '
          '$_reconnectionAttempts attempts',
        );
        onDropped?.call('reconnect_failed');
      });

      timer = Timer(timeout, () {
        _logger.w('/calls connect timed out');
        finish(false);
      });

      socket.connect();
      return await completer.future;
    } catch (e) {
      _logger.e('/calls connect failed: $e');
      return false;
    } finally {
      _connecting = false;
    }
  }

  /// Emit [event] with [data] and await the server ack, enforcing the
  /// `/calls` gateway contract: an ack carrying an `error` key (or no ack
  /// within [timeout]) throws [CallsSignalingException]; otherwise the ack
  /// map is returned as-is.
  Future<Map<String, dynamic>> request(
    String event,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return Future.error(
        CallsSignalingException(event, '/calls socket not connected'),
      );
    }

    final completer = Completer<Map<String, dynamic>>();
    try {
      socket.emitWithAck(
        event,
        data,
        ack: (dynamic resp) {
          if (completer.isCompleted) return;
          final map = _asMap(
            resp is List && resp.isNotEmpty ? resp.first : resp,
          );
          if (map == null) {
            completer.completeError(
              CallsSignalingException(event, 'malformed ack: $resp'),
            );
            return;
          }
          final error = map['error'];
          if (error != null) {
            completer.completeError(
              CallsSignalingException(event, error.toString()),
            );
            return;
          }
          completer.complete(map);
        },
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(
          CallsSignalingException(event, 'emit failed: $e'),
        );
      }
    }

    return completer.future.timeout(
      timeout,
      onTimeout:
          () =>
              throw CallsSignalingException(
                event,
                'ack timed out after $timeout',
              ),
    );
  }

  /// Fire-and-forget emit (no ack expected).
  void emit(String event, [Map<String, dynamic>? data]) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      _logger.w('cannot emit $event — /calls not connected');
      return;
    }
    data == null ? socket.emit(event) : socket.emit(event, data);
  }

  void on(String event, void Function(dynamic data) handler) =>
      _socket?.on(event, handler);

  void off(String event, [void Function(dynamic data)? handler]) =>
      handler == null ? _socket?.off(event) : _socket?.off(event, handler);

  void disconnect() {
    _logger.i('closing /calls namespace connection');
    _teardownSocket();
  }

  void _teardownSocket() {
    final socket = _socket;
    _hasConnected = false;
    if (socket == null) return;
    try {
      socket.clearListeners();
      socket.disconnect();
      socket.close();
      socket.dispose();
    } catch (_) {}
    _socket = null;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
