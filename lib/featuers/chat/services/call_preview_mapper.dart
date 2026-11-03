// *****************************************************************************************
// * Filename: call_preview_mapper.dart                                                   *
// * Date: 03 September 2025                                                            *
// * Developer: Deval Joshi                                              *
// * Description: Unified call preview mapping service for chat list previews.          *
// * Maps call messages to appropriate display text and icons for different call        *
// * states (incoming, outgoing, missed, ended) for both audio and video calls.         *
// *****************************************************************************************

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

enum CallPreviewType { missed, incoming, outgoing, ongoing, ended }

class CallPreviewInfo {
  final CallPreviewType type;
  final String displayText;
  final SvgPicture icon;
  final Color color;
  final String? duration;

  CallPreviewInfo({
    required this.type,
    required this.displayText,
    required this.icon,
    required this.color,
    this.duration,
  });
}

class CallPreviewMapper {
  static final CallPreviewMapper _instance = CallPreviewMapper._internal();
  factory CallPreviewMapper() => _instance;
  CallPreviewMapper._internal();

  CallPreviewInfo? mapCallMessageToPreview({
    required List<CallData>? calls,
    required String? messageContent,
    required String? messageType,
    required int? currentUserId,
    required int? messageSenderId,
  }) {
    // Return null if not a call message
    if (!_isCallMessage(calls, messageContent, messageType)) {
      return null;
    }

    // Handle calls array first (most reliable)
    if (calls != null && calls.isNotEmpty) {
      return _mapFromCallData(calls.first, currentUserId, messageSenderId);
    }

    // Fallback to message content
    if (_isCallMessageContent(messageContent)) {
      return _mapFromMessageContent(
        messageContent,
        currentUserId,
        messageSenderId,
      );
    }

    return null;
  }

  /// Map from CallData structure (most accurate)
  CallPreviewInfo _mapFromCallData(
    CallData call,
    int? currentUserId,
    int? messageSenderId,
  ) {
    final senderId =
        messageSenderId ?? call.userId; // Use message sender as primary
    final callStatus = call.callStatus?.toLowerCase() ?? 'ringing';
    final callType = call.callType?.toLowerCase() ?? 'voice';
    final duration = _formatDuration(call.callDuration);
    final users = call.users ?? [];
    final isCurrentUserCaller = senderId == currentUserId;
    final currentUserInUsers =
        currentUserId != null && users.contains(currentUserId);

    debugPrint('=== CALL PREVIEW MAPPING ===');
    debugPrint('Call Status: $callStatus');
    debugPrint('Call Type: $callType');
    debugPrint('Sender ID: $senderId');
    debugPrint('Current User ID: $currentUserId');
    debugPrint('Is Caller: $isCurrentUserCaller');
    debugPrint('Current User in Users: $currentUserInUsers');
    debugPrint('Users Array: $users');
    debugPrint('Duration: $duration');

    // Get appropriate icon based on type and direction
    SvgPicture getCallIcon(String direction) {
      if (callType == 'video') {
        switch (direction) {
          case 'outgoing':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVideo);
          case 'incoming':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVideo);
          case 'missed':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.missedcallVideo);
          default:
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVideo);
        }
      } else {
        switch (direction) {
          case 'outgoing':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice);
          case 'incoming':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVoice);
          case 'missed':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.missedCallVoice);
          default:
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice);
        }
      }
    }

    String getTypeText() {
      return callType == 'video' ? 'Video' : 'Voice';
    }

    // Handle missed calls first (special logic)
    if (callStatus == 'missed') {
      if (isCurrentUserCaller) {
        // Current user was caller - call was cancelled
        final displayText =
            duration != null
                ? 'Outgoing ${getTypeText().toLowerCase()} call ($duration)'
                : 'Outgoing ${getTypeText().toLowerCase()} call';

        debugPrint('Mapped to: Outgoing (cancelled) - $displayText');
        return CallPreviewInfo(
          type: CallPreviewType.outgoing,
          displayText: displayText,
          icon: getCallIcon('outgoing'),
          color: Color(0xffFCC604),
          duration: duration,
        );
      } else if (!currentUserInUsers) {
        // Current user missed the call
        final displayText = 'Missed ${getTypeText().toLowerCase()} call';

        debugPrint('Mapped to: Missed - $displayText');
        return CallPreviewInfo(
          type: CallPreviewType.missed,
          displayText: displayText,
          icon: getCallIcon('missed'),
          color: AppColors.appPriSecColor.secondaryRed,
          duration: duration,
        );
      } else {
        // Current user was in call but status is missed (edge case)
        final displayText =
            duration != null
                ? 'Incoming ${getTypeText().toLowerCase()} call ($duration)'
                : 'Incoming ${getTypeText().toLowerCase()} call';

        debugPrint('Mapped to: Incoming (was in users) - $displayText');
        return CallPreviewInfo(
          type: CallPreviewType.incoming,
          displayText: displayText,
          icon: getCallIcon('incoming'),
          color: AppColors.verifiedColor.c00C32B,
          duration: duration,
        );
      }
    }

    // Handle other call statuses
    switch (callStatus) {
      case 'ringing':
      case 'calling':
        if (isCurrentUserCaller) {
          debugPrint('Mapped to: Outgoing (ringing)');
          return CallPreviewInfo(
            type: CallPreviewType.outgoing,
            displayText: 'Outgoing ${getTypeText().toLowerCase()} call',
            icon: getCallIcon('outgoing'),
            color: Color(0xffFCC604),
            duration: duration,
          );
        } else {
          debugPrint('Mapped to: Incoming (ringing)');
          return CallPreviewInfo(
            type: CallPreviewType.incoming,
            displayText: 'Incoming ${getTypeText().toLowerCase()} call',
            icon: getCallIcon('incoming'),
            color: AppColors.verifiedColor.c00C32B,
            duration: duration,
          );
        }

      case 'ongoing':
        debugPrint('Mapped to: Ongoing');
        return CallPreviewInfo(
          type: CallPreviewType.ongoing,
          displayText: 'Ongoing ${getTypeText().toLowerCase()} call',
          icon: getCallIcon(isCurrentUserCaller ? 'outgoing' : 'incoming'),
          color: AppColors.verifiedColor.c00C32B,
          duration: duration,
        );

      case 'ended':
        if (isCurrentUserCaller) {
          final displayText =
              duration != null
                  ? 'Outgoing ${getTypeText().toLowerCase()} call ($duration)'
                  : 'Outgoing ${getTypeText().toLowerCase()} call';

          debugPrint('Mapped to: Outgoing (ended) - $displayText');
          return CallPreviewInfo(
            type: CallPreviewType.outgoing,
            displayText: displayText,
            icon: getCallIcon('outgoing'),
            color: Color(0xffFCC604),
            duration: duration,
          );
        } else {
          final displayText =
              duration != null
                  ? 'Incoming ${getTypeText().toLowerCase()} call ($duration)'
                  : 'Incoming ${getTypeText().toLowerCase()} call';

          debugPrint('Mapped to: Incoming (ended) - $displayText');
          return CallPreviewInfo(
            type: CallPreviewType.incoming,
            displayText: displayText,
            icon: getCallIcon('incoming'),
            color: AppColors.verifiedColor.c00C32B,
            duration: duration,
          );
        }

      default:
        // Fallback based on caller direction
        if (isCurrentUserCaller) {
          debugPrint('Mapped to: Outgoing (fallback)');
          return CallPreviewInfo(
            type: CallPreviewType.outgoing,
            displayText: 'Outgoing ${getTypeText().toLowerCase()} call',
            icon: getCallIcon('outgoing'),
            color: Color(0xffFCC604),
            duration: duration,
          );
        } else {
          debugPrint('Mapped to: Incoming (fallback)');
          return CallPreviewInfo(
            type: CallPreviewType.incoming,
            displayText: 'Incoming ${getTypeText().toLowerCase()} call',
            icon: getCallIcon('incoming'),
            color: AppColors.verifiedColor.c00C32B,
            duration: duration,
          );
        }
    }
  }

  /// Map from legacy message content
  CallPreviewInfo _mapFromMessageContent(
    String? messageContent,
    int? currentUserId,
    int? messageSenderId,
  ) {
    final isCurrentUserCaller = messageSenderId == currentUserId;

    debugPrint('=== LEGACY CONTENT MAPPING ===');
    debugPrint('Message Content: $messageContent');
    debugPrint('Message Sender: $messageSenderId');
    debugPrint('Current User: $currentUserId');
    debugPrint('Is Caller: $isCurrentUserCaller');

    switch (messageContent?.toLowerCase()) {
      case 'callmissed':
      case 'missed':
        if (isCurrentUserCaller) {
          debugPrint('Legacy Mapped to: Outgoing (cancelled)');
          return CallPreviewInfo(
            type: CallPreviewType.outgoing,
            displayText: 'Outgoing voice call',
            icon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice),
            color: Color(0xffFCC604),
          );
        } else {
          debugPrint('Legacy Mapped to: Missed');
          return CallPreviewInfo(
            type: CallPreviewType.missed,
            displayText: 'Missed voice call',
            icon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.missedCallVoice),
            color: AppColors.appPriSecColor.secondaryRed,
          );
        }

      case 'calling':
        if (isCurrentUserCaller) {
          debugPrint('Legacy Mapped to: Outgoing (calling)');
          return CallPreviewInfo(
            type: CallPreviewType.outgoing,
            displayText: 'Outgoing voice call',
            icon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice),
            color: AppColors.verifiedColor.c00C32B,
          );
        } else {
          debugPrint('Legacy Mapped to: Incoming (calling)');
          return CallPreviewInfo(
            type: CallPreviewType.incoming,
            displayText: 'Incoming voice call',
            icon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVoice),
            color: AppColors.verifiedColor.c00C32B,
          );
        }

      case 'ongoing':
        debugPrint('Legacy Mapped to: Ongoing');
        return CallPreviewInfo(
          type: CallPreviewType.ongoing,
          displayText: 'Ongoing voice call',
          icon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice),
          color: AppColors.verifiedColor.c00C32B,
        );

      case 'callended':
      case 'ended':
        if (isCurrentUserCaller) {
          debugPrint('Legacy Mapped to: Outgoing (ended)');
          return CallPreviewInfo(
            type: CallPreviewType.outgoing,
            displayText: 'Outgoing voice call',
            icon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice),
            color: AppColors.verifiedColor.c00C32B,
          );
        } else {
          debugPrint('Legacy Mapped to: Incoming (ended)');
          return CallPreviewInfo(
            type: CallPreviewType.incoming,
            displayText: 'Incoming voice call',
            icon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVoice),
            color: AppColors.verifiedColor.c00C32B,
          );
        }

      default:
        debugPrint('Legacy Mapped to: Default call');
        return CallPreviewInfo(
          type: CallPreviewType.incoming,
          displayText: 'Voice call',
          icon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice),
          color: AppColors.verifiedColor.c00C32B,
        );
    }
  }

  /// Check if this is a call message
  bool _isCallMessage(
    List<CallData>? calls,
    String? messageContent,
    String? messageType,
  ) {
    return (calls != null && calls.isNotEmpty) ||
        messageType?.toLowerCase() == 'call' ||
        _isCallMessageContent(messageContent);
  }

  /// Check if message content indicates a call
  bool _isCallMessageContent(String? messageContent) {
    if (messageContent == null) return false;
    const callContents = [
      'callmissed',
      'calling',
      'ongoing',
      'callended',
      'ended',
      'declined',
      'missed',
    ];
    return callContents.contains(messageContent.toLowerCase());
  }

  /// Format call duration
  String? _formatDuration(int? durationInSeconds) {
    if (durationInSeconds == null || durationInSeconds == 0) return null;

    if (durationInSeconds < 60) {
      return '${durationInSeconds}s';
    } else {
      final minutes = durationInSeconds ~/ 60;
      final seconds = durationInSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
  }
}
