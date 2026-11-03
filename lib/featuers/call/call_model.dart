// =============================================================================
// File: lib/features/call/models/call_models.dart
// Step 1: Define all the models and enums we'll need
// =============================================================================

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Call types
enum CallType { audio, video }

/// Call states
enum CallState {
  idle, // No call
  calling, // Outgoing call in progress
  ringing, // Incoming call
  connecting, // Connecting to call
  connected, // Call connected
  failed, // Call failed
  ended, // Call ended
  disconnected, // Disconnected
}

/// Participant in a call
class CallParticipant {
  final String peerId;
  final String userId;
  final String userName;
  final DateTime joinedAt;
  bool isConnected;
  bool hasVideo;
  bool hasAudio;
  MediaStream? stream;

  CallParticipant({
    required this.peerId,
    required this.userId,
    required this.userName,
    DateTime? joinedAt,
    this.isConnected = false,
    this.hasVideo = false,
    this.hasAudio = false,
    this.stream,
  }) : joinedAt = joinedAt ?? DateTime.now();

  CallParticipant copyWith({
    String? userId,
    String? userName,
    bool? isConnected,
    bool? hasVideo,
    bool? hasAudio,
    MediaStream? stream,
  }) {
    return CallParticipant(
      peerId: peerId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      joinedAt: joinedAt,
      isConnected: isConnected ?? this.isConnected,
      hasVideo: hasVideo ?? this.hasVideo,
      hasAudio: hasAudio ?? this.hasAudio,
      stream: stream ?? this.stream,
    );
  }
}

/// Enhanced call information
class CallInfo {
  final int chatId;
  // NEW's call ids are BigInt-as-string, not numeric (§7.4/§11 "Universal
  // ID change") — was `int?` pre-migration.
  final String? callId;
  final String? roomId;
  final String? sessionId;
  final CallType callType;
  final String callerName;
  final bool isIncoming;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? peerId;
  final String? callerProfilePic;
  // The calling user's id (incoming calls), used for the blue tick.
  final String? callerUserId;

  CallInfo({
    required this.chatId,
    this.callId,
    this.roomId,
    this.sessionId,
    required this.callType,
    required this.callerName,
    required this.isIncoming,
    this.startTime,
    this.endTime,
    this.peerId,
    this.callerProfilePic,
    this.callerUserId,
  });

  CallInfo copyWith({
    int? chatId,
    String? callId,
    String? roomId,
    String? sessionId,
    CallType? callType,
    String? callerName,
    bool? isIncoming,
    DateTime? startTime,
    DateTime? endTime,
    String? peerId,
    String? callerProfilePic,
    String? callerUserId,
  }) {
    return CallInfo(
      chatId: chatId ?? this.chatId,
      callId: callId ?? this.callId,
      roomId: roomId ?? this.roomId,
      sessionId: sessionId ?? this.sessionId,
      callType: callType ?? this.callType,
      callerName: callerName ?? this.callerName,
      isIncoming: isIncoming ?? this.isIncoming,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      peerId: peerId ?? this.peerId,
      callerProfilePic: callerProfilePic ?? this.callerProfilePic,
      callerUserId: callerUserId ?? this.callerUserId,
    );
  }

  /// Get call duration
  Duration? get duration {
    if (startTime == null) return null;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!);
  }

  /// Get formatted call duration
  String get formattedDuration {
    final dur = duration;
    if (dur == null) return '00:00';
    
    final minutes = dur.inMinutes;
    final seconds = dur.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
