// *****************************************************************************************
// * Filename: call_display_service.dart                                                 *
// * Date: 04 August 2025                                                               *
// * Developer: Deval Joshi                                                            *
// * Description: Service to handle call status display logic for chat list and        *
// * universal chat screen. Determines missed call, incoming call, and outgoing call    *
// * status based on call data structure and current user context.                      *
// *****************************************************************************************

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/preference_key/constant/app_constant.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

enum CallDisplayType {
  missedCall,
  incomingCall,
  outgoingCall,
  ongoingCall,
  endedCall,
}

class CallDisplayInfo {
  final CallDisplayType type;
  // final IconData icon;
  final SvgPicture svgIcon;
  final Color color;
  final String text;
  final String callStatus;
  final String chatListCallStatus;
  final String? duration;

  CallDisplayInfo({
    required this.type,
    // required this.icon,
    required this.svgIcon,
    required this.color,
    required this.text,
    required this.callStatus,
    required this.chatListCallStatus,
    this.duration,
  });
}

class CallDisplayService {
  static final CallDisplayService _instance = CallDisplayService._internal();
  factory CallDisplayService() => _instance;
  CallDisplayService._internal();

  int? _cachedUserId;

  /// Initialize the service with user ID to avoid async calls later
  Future<void> initializeWithUserId() async {
    _cachedUserId ??= await Constants.getUserId();
  }

  /// Main method to get call display information
  /// Used in both chat list and universal chat
  Future<CallDisplayInfo?> getCallDisplayInfo({
    required List<CallData>? calls,
    String? messageContent,
    String? messageType,
    int? currentUserId,
    int? messageSenderId,
  }) async {
    // If currentUserId is provided, use sync method immediately
    if (currentUserId != null) {
      return getCallDisplayInfoSync(
        calls: calls,
        messageContent: messageContent,
        messageType: messageType,
        currentUserId: currentUserId,
        messageSenderId: messageSenderId,
      );
    }

    // Return null if no call data and not a call message
    if ((calls == null || calls.isEmpty) &&
        messageType?.toLowerCase() != 'call' &&
        !_isCallMessageContent(messageContent)) {
      return null;
    }

    try {
      // Use cached user ID or fetch it
      final userId = _cachedUserId ?? await Constants.getUserId();

      // Handle legacy message content based calls
      if ((calls == null || calls.isEmpty) &&
          _isCallMessageContent(messageContent)) {
        return _getCallInfoFromMessageContent(
          messageContent,
          userId,
          messageSenderId,
        );
      }

      // Handle new call array structure
      if (calls != null && calls.isNotEmpty) {
        final call = calls.first;
        // Override call.userId with messageSenderId for more accurate direction detection
        if (messageSenderId != null) {
          final updatedCall = CallData(
            callId: call.callId,
            callType: call.callType,
            callStatus: call.callStatus,
            callDuration: call.callDuration,
            startTime: call.startTime,
            endTime: call.endTime,
            users: call.users,
            messageId: call.messageId,
            chatId: call.chatId,
            userId: messageSenderId, // Use message sender ID for direction
            roomId: call.roomId,
            currentUsers: call.currentUsers,
            updatedAt: call.updatedAt,
            createdAt: call.createdAt,
            caller: call.caller,
          );
          return _getCallInfoFromCallData(updatedCall, userId);
        }
        return _getCallInfoFromCallData(call, userId);
      }

      return null;
    } catch (e) {
      debugPrint('Error in CallDisplayService.getCallDisplayInfo: $e');
      return null;
    }
  }

  /// Synchronous method to get call display information when user ID is provided
  CallDisplayInfo? getCallDisplayInfoSync({
    required List<CallData>? calls,
    String? messageContent,
    String? messageType,
    int? currentUserId,
    int? messageSenderId, // NEW: sender_id from the message record
  }) {
    // Return null if no call data and not a call message
    if ((calls == null || calls.isEmpty) &&
        messageType?.toLowerCase() != 'call' &&
        !_isCallMessageContent(messageContent)) {
      return null;
    }

    // Use provided user ID, cached user ID, or return null
    final userId = currentUserId ?? _cachedUserId;
    if (userId == null) return null;

    try {
      // Handle legacy message content based calls with caller info from calls array
      if ((calls == null || calls.isEmpty) &&
          _isCallMessageContent(messageContent)) {
        // Use messageSenderId as caller info
        return _getCallInfoFromMessageContent(
          messageContent,
          userId,
          messageSenderId,
        );
      }

      // Handle new call array structure
      if (calls != null && calls.isNotEmpty) {
        final call = calls.first;
        // Override call.userId with messageSenderId for more accurate direction detection
        if (messageSenderId != null) {
          final updatedCall = CallData(
            callId: call.callId,
            callType: call.callType,
            callStatus: call.callStatus,
            callDuration: call.callDuration,
            startTime: call.startTime,
            endTime: call.endTime,
            users: call.users,
            messageId: call.messageId,
            chatId: call.chatId,
            userId: messageSenderId, // Use message sender ID for direction
            roomId: call.roomId,
            currentUsers: call.currentUsers,
            updatedAt: call.updatedAt,
            createdAt: call.createdAt,
            caller: call.caller,
          );
          return _getCallInfoFromCallData(updatedCall, userId);
        }
        return _getCallInfoFromCallData(call, userId);
      }

      // Fallback for message content with call data context
      if (_isCallMessageContent(messageContent)) {
        // Use messageSenderId as primary source, fallback to calls array
        int? callerId = messageSenderId;
        if (callerId == null && calls != null && calls.isNotEmpty) {
          callerId = calls.first.caller?.userId;
        }
        return _getCallInfoFromMessageContent(messageContent, userId, callerId);
      }

      return null;
    } catch (e) {
      debugPrint('Error in CallDisplayService.getCallDisplayInfoSync: $e');
      return null;
    }
  }

  /// Get call display info from CallData structure
  CallDisplayInfo _getCallInfoFromCallData(CallData call, int currentUserId) {
    final senderId =
        call.userId; // sender_id from socket event - primary identifier
    final callStatus = call.callStatus?.toLowerCase();
    final callType =
        call.callType?.toLowerCase() ??
        'voice'; // Default to voice if not specified
    final durationText = _formatDuration(call.callDuration);
    final users = call.users ?? [];
    final callerId = call.caller?.userId ?? senderId;

    // Helper function to get appropriate icon based on call type
    // ignore: unused_element
    IconData getCallIcon(String baseIconType) {
      if (callType == 'video') {
        switch (baseIconType) {
          case 'outgoing':
            return Icons.videocam_outlined;
          case 'incoming':
            return Icons.videocam_outlined;
          case 'missed':
            return Icons.videocam_off;
          case 'ongoing':
            return Icons.videocam;
          default:
            return Icons.videocam_outlined;
        }
      } else {
        switch (baseIconType) {
          case 'outgoing':
            return Icons.call_made;
          case 'incoming':
            return Icons.call_received;
          case 'missed':
            return Icons.phone_missed_outlined;
          case 'ongoing':
            return Icons.phone;
          default:
            return Icons.call_made;
        }
      }
    }

    SvgPicture getCallIconSvg(String baseIconType) {
      if (callType == 'video') {
        switch (baseIconType) {
          case 'outgoing':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVideo);
          case 'incoming':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVideo);
          case 'missed':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.missedcallVideo);
          case 'ongoing':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVideo);
          default:
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVideo);
        }
      } else {
        switch (baseIconType) {
          case 'outgoing':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice);
          case 'incoming':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVoice);
          case 'missed':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.missedCallVoice);
          case 'ongoing':
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVoice);
          default:
            return SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice);
        }
      }
    }

    // Helper function to format call type text
    String getCallTypeText(String status) {
      final typeText =
          callType == 'video'
              ? 'Video'
              : (callType == 'audio' ? 'Voice' : 'Voice');
      return AppString.typeCall(AppString.tr(typeText));
    }

    String getCallForChatListText(String status) {
      final typeText =
          callType == 'video'
              ? 'Video'
              : (callType == 'audio' ? 'Voice' : 'Voice');
      return AppString.statusTypeCall(AppString.tr(status), AppString.tr(typeText));
    }

    String getCallStatusText(String status) {
      return AppString.statusCall(AppString.tr(status));
    }

    // 1. For Outgoing Calls: Current user ID matches sender_id (primary check)
    // 2. For Incoming Calls: Current user ID does NOT match sender_id
    final currentUserInUsers = users.contains(currentUserId);

    // 3. For Missed Calls: Use users array logic FIRST, then check caller
    if (callStatus == 'missed') {
      // Check if current user was the caller first
      final wasCallerUser =
          (senderId == currentUserId) || (callerId == currentUserId);

      if (wasCallerUser) {
        // Current user was the caller - call was cancelled
        return CallDisplayInfo(
          type: CallDisplayType.outgoingCall,
          // icon: getCallIcon('outgoing'),
          svgIcon: getCallIconSvg('outgoing'),
          color: AppColors.appPriSecColor.primaryColor, //Colors.orange[700]!,
          text: getCallTypeText('Cancelled'),
          callStatus: getCallStatusText('Outgoing'),
          chatListCallStatus: getCallForChatListText('Outgoing'),
          duration: durationText,
        );
      } else if (!currentUserInUsers) {
        // Current user was supposed to answer but is NOT in users array = MISSED CALL
        return CallDisplayInfo(
          type: CallDisplayType.missedCall,
          // icon: getCallIcon('missed'),
          svgIcon: getCallIconSvg('missed'),
          color: AppColors.appPriSecColor.secondaryRed,
          text: getCallTypeText('Missed'),
          callStatus: getCallStatusText('Missed'),
          chatListCallStatus: getCallForChatListText('Missed'),
          duration: durationText,
        );
      } else {
        // Current user was in the call (users array) - answered call
        return CallDisplayInfo(
          type: CallDisplayType.incomingCall,
          // icon: getCallIcon('incoming'),
          svgIcon: getCallIconSvg('incoming'),
          color: AppColors.verifiedColor.c00C32B,
          text: getCallTypeText('Incoming'),
          callStatus: getCallStatusText('Incoming'),
          chatListCallStatus: getCallForChatListText("Incoming"),
          duration: durationText,
        );
      }
    }

    // 3. Handle specific call statuses based on
    switch (callStatus) {
      case 'ringing':
        // Call is currently ringing - use only senderId for direction
        if (senderId == currentUserId) {
          return CallDisplayInfo(
            type: CallDisplayType.outgoingCall,
            // icon: getCallIcon('outgoing'),
            svgIcon: getCallIconSvg('outgoing'),
            color: AppColors.verifiedColor.c00C32B,
            text: getCallTypeText('Outgoing'),
            callStatus: getCallStatusText('Outgoing'),
            chatListCallStatus: getCallForChatListText('Outgoing'),
            duration: durationText,
          );
        } else {
          return CallDisplayInfo(
            type: CallDisplayType.incomingCall,
            // icon: getCallIcon('incoming'),
            svgIcon: getCallIconSvg('incoming'),
            color: AppColors.verifiedColor.c00C32B,
            text: getCallTypeText('Incoming'),
            callStatus: getCallStatusText('Incoming'),
            chatListCallStatus: getCallForChatListText('Incoming'),
            duration: durationText,
          );
        }

      case 'ongoing':
        // Call is active (user_joined event received)
        return CallDisplayInfo(
          type: CallDisplayType.ongoingCall,
          // icon: getCallIcon('ongoing'),
          svgIcon: getCallIconSvg('ongoing'),
          color: AppColors.verifiedColor.c00C32B,
          text: getCallTypeText('Ongoing'),
          callStatus: getCallStatusText('Ongoing'),
          chatListCallStatus: getCallForChatListText('Ongoing'),
          duration: durationText,
        );

      case 'ended':
        // Call ended successfully with duration - use only senderId for direction
        if (senderId == currentUserId) {
          return CallDisplayInfo(
            type: CallDisplayType.outgoingCall,
            // icon: getCallIcon('outgoing'),
            svgIcon: getCallIconSvg('outgoing'),
            color: AppColors.verifiedColor.c00C32B,
            text: getCallTypeText('Outgoing'),
            callStatus: getCallStatusText('Outgoing'),
            chatListCallStatus: getCallForChatListText('Outgoing'),
            duration: durationText,
          );
        } else {
          return CallDisplayInfo(
            type: CallDisplayType.incomingCall,
            // icon: getCallIcon('incoming'),
            svgIcon: getCallIconSvg('incoming'),
            color: AppColors.verifiedColor.c00C32B,
            text: getCallTypeText('Incoming'),
            callStatus: getCallStatusText('Incoming'),
            chatListCallStatus: getCallForChatListText('Incoming'),
            duration: durationText,
          );
        }

      case 'missed':
        // Explicit missed call status - same logic as above
        if (senderId == currentUserId || callerId == currentUserId) {
          // Caller's side - call was cancelled/not answered
          return CallDisplayInfo(
            type: CallDisplayType.outgoingCall,
            // icon: getCallIcon('outgoing'),
            svgIcon: getCallIconSvg('outgoing'),
            color: AppColors.appPriSecColor.primaryColor,
            text: getCallTypeText('Cancelled'),
            callStatus: getCallStatusText('Outgoing'),
            chatListCallStatus: getCallForChatListText('Outgoing'),
            duration: durationText,
          );
        } else if (!currentUserInUsers) {
          // Current user was supposed to answer but is NOT in users array = MISSED CALL
          return CallDisplayInfo(
            type: CallDisplayType.missedCall,
            // icon: getCallIcon('missed'),
            svgIcon: getCallIconSvg('missed'),
            color: AppColors.appPriSecColor.secondaryRed,
            text: getCallTypeText('Missed'),
            callStatus: getCallStatusText('Missed'),
            chatListCallStatus: getCallForChatListText('Missed'),
            duration: durationText,
          );
        } else {
          // Current user was in the call - answered call
          return CallDisplayInfo(
            type: CallDisplayType.incomingCall,
            // icon: getCallIcon('incoming'),
            svgIcon: getCallIconSvg('incoming'),
            color: AppColors.verifiedColor.c00C32B,
            text: getCallTypeText('Incoming'),
            callStatus: getCallStatusText('Incoming'),
            chatListCallStatus: getCallForChatListText('Incoming'),
            duration: durationText,
          );
        }

      default:
        // Fallback based on direction - use only senderId for consistency
        if (senderId == currentUserId) {
          return CallDisplayInfo(
            type: CallDisplayType.outgoingCall,
            // icon: getCallIcon('outgoing'),
            svgIcon: getCallIconSvg('outgoing'),
            color: AppColors.verifiedColor.c00C32B,
            text: getCallTypeText('Outgoing'),
            callStatus: getCallStatusText('Outgoing'),
            chatListCallStatus: getCallForChatListText('Outgoing'),
            duration: durationText,
          );
        } else {
          return CallDisplayInfo(
            type: CallDisplayType.incomingCall,
            // icon: getCallIcon('incoming'),
            svgIcon: getCallIconSvg('incoming'),
            color: AppColors.verifiedColor.c00C32B,
            text: getCallTypeText('Incoming'),
            callStatus: getCallStatusText('Incoming'),
            chatListCallStatus: getCallForChatListText('Incoming'),
            duration: durationText,
          );
        }
    }
  }

  /// Get call display info from legacy message content
  /// This method now tries to determine incoming vs outgoing from user context
  CallDisplayInfo _getCallInfoFromMessageContent(
    String? messageContent, [
    int? currentUserId,
    int? callerId,
    String? callType, // NEW: Optional call type parameter
  ]) {
    // Default to voice if call type not provided
    final type = callType?.toLowerCase() ?? 'voice';

    String getCallTypeText(String status) {
      final typeText =
          callType == 'video'
              ? 'Video'
              : (callType == 'audio' ? 'Voice' : 'Voice');
      return AppString.typeCall(AppString.tr(typeText));
    }

    // Helper function to get icon based on call type
    // ignore: unused_element
    IconData getLegacyCallIcon(String status) {
      if (type == 'video') {
        switch (status) {
          case 'outgoing':
            return Icons.videocam_outlined;
          case 'incoming':
            return Icons.videocam_outlined;
          case 'missed':
            return Icons.videocam_off;
          case 'cancelled':
            return Icons.videocam_off;
          default:
            return Icons.videocam_outlined;
        }
      } else {
        // Handles both 'audio' and 'voice' call types
        switch (status) {
          case 'outgoing':
            return Icons.call_made;
          case 'incoming':
            return Icons.call_received;
          case 'missed':
            return Icons.phone_missed_outlined;
          case 'cancelled':
            return Icons.call_made;
          default:
            return Icons.call_made;
        }
      }
    }

    switch (messageContent?.toLowerCase()) {
      case 'callmissed':
      case 'missed':
        // Use same logic as main missed call handler
        if (currentUserId != null && callerId != null) {
          final wasCallerUser = callerId == currentUserId;

          if (wasCallerUser) {
            // Current user was the caller - call was cancelled
            return CallDisplayInfo(
              type: CallDisplayType.outgoingCall,
              // icon: Icons.call_made,
              svgIcon: SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.outgoingVoice,
              ),
              color: AppColors.appPriSecColor.primaryColor,
              text: getCallTypeText('Cancelled'), //'Cancelled call',
              callStatus: AppString.outgoingCallLower,
              chatListCallStatus: AppString.outgoingCall,
            );
          } else {
            // Current user missed the call
            return CallDisplayInfo(
              type: CallDisplayType.missedCall,
              // icon: Icons.phone_missed_outlined,
              svgIcon: SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.missedCallVoice,
              ),
              color: AppColors.appPriSecColor.secondaryRed,
              text: getCallTypeText('Missed'), //'Missed call',
              callStatus: AppString.missedCallLower,
              chatListCallStatus: AppString.missedCall,
            );
          }
        } else {
          // Fallback: show as missed call if no caller info
          return CallDisplayInfo(
            type: CallDisplayType.missedCall,
            // icon: Icons.phone_missed_outlined,
            svgIcon: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.missedCallVoice,
            ),
            color: AppColors.appPriSecColor.secondaryRed,
            text: getCallTypeText('Missed'), //'Missed call',
            callStatus: AppString.missedCallLower,
            chatListCallStatus: AppString.missedCall,
          );
        }
      case 'calling':
        // For 'calling' status, we need to determine if it's incoming or outgoing based on caller
        if (currentUserId != null && callerId != null) {
          if (callerId == currentUserId) {
            return CallDisplayInfo(
              type: CallDisplayType.outgoingCall,
              // icon: Icons.call_made,
              svgIcon: SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.outgoingVoice,
              ),
              color: AppColors.verifiedColor.c00C32B,
              text: getCallTypeText('Outgoing'), //'Outgoing call',
              callStatus: AppString.outgoingCallLower,
              chatListCallStatus: AppString.outgoingCall,
            );
          } else {
            return CallDisplayInfo(
              type: CallDisplayType.incomingCall,
              // icon: Icons.call_received,
              svgIcon: SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.incomingVoice,
              ),
              color: AppColors.verifiedColor.c00C32B,
              text: getCallTypeText('Incoming'), //'Incoming call',
              callStatus: AppString.incomingCallLower,
              chatListCallStatus: AppString.incomingCall,
            );
          }
        }
        // Fallback to incoming if no caller info (safer assumption for 'calling' status)
        return CallDisplayInfo(
          type: CallDisplayType.incomingCall,
          // icon: Icons.call_received,
          svgIcon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVoice),
          color: AppColors.verifiedColor.c00C32B,
          text: getCallTypeText('Incoming'), //'Incoming call',
          callStatus: AppString.incomingCallLower,
          chatListCallStatus: AppString.incomingCall,
        );
      case 'ongoing':
        return CallDisplayInfo(
          type: CallDisplayType.ongoingCall,
          // icon: Icons.phone,
          svgIcon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice),
          color: AppColors.verifiedColor.c00C32B,
          text: getCallTypeText('Ongoing'), //'Ongoing call',
          callStatus: 'Ongoing call',
          chatListCallStatus: 'Ongoing Call',
        );
      case 'callended':
      case 'ended':
        // For ended calls, determine direction based on caller
        if (currentUserId != null && callerId != null) {
          if (callerId == currentUserId) {
            return CallDisplayInfo(
              type: CallDisplayType.outgoingCall,
              // icon: Icons.call_made,
              svgIcon: SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.outgoingVoice,
              ),
              color: AppColors.verifiedColor.c00C32B,
              text: getCallTypeText('Outgoing'), //'Outgoing call',
              callStatus: AppString.outgoingCallLower,
              chatListCallStatus: AppString.outgoingCall,
            );
          } else {
            return CallDisplayInfo(
              type: CallDisplayType.incomingCall,
              // icon: Icons.call_received,
              svgIcon: SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.incomingVoice,
              ),
              color: AppColors.verifiedColor.c00C32B,
              text: getCallTypeText('Incoming'), //'Incoming call',
              callStatus: AppString.incomingCallLower,
              chatListCallStatus: AppString.incomingCall,
            );
          }
        }
        return CallDisplayInfo(
          type: CallDisplayType.endedCall,
          // icon: Icons.phone,
          svgIcon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice),
          color: AppColors.verifiedColor.c00C32B,
          text: getCallTypeText('Call ended'), //'Call ended',
          callStatus: 'Call ended',
          chatListCallStatus: 'Call ended',
        );
      case 'declined':
        // For declined calls, determine direction based on caller
        if (currentUserId != null && callerId != null) {
          if (callerId == currentUserId) {
            return CallDisplayInfo(
              type: CallDisplayType.outgoingCall,
              // icon: Icons.call_made,
              svgIcon: SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.outgoingVoice,
              ),
              color: AppColors.verifiedColor.c00C32B,
              text: getCallTypeText('Outgoing'), //'Outgoing call',
              callStatus: AppString.outgoingCallLower,
              chatListCallStatus: AppString.outgoingCall,
            );
          } else {
            return CallDisplayInfo(
              type: CallDisplayType.incomingCall,
              // icon: Icons.call_received,
              svgIcon: SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.incomingVoice,
              ),
              color: AppColors.verifiedColor.c00C32B,
              text: getCallTypeText('Incoming'), //'Incoming call',
              callStatus: AppString.incomingCallLower,
              chatListCallStatus: AppString.incomingCall,
            );
          }
        }
        return CallDisplayInfo(
          type: CallDisplayType.incomingCall,
          // icon: Icons.call_received,
          svgIcon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVoice),
          color: AppColors.verifiedColor.c00C32B,
          text: getCallTypeText('Declined'), //'Declined call',
          callStatus: 'Declined call',
          chatListCallStatus: 'Declined call',
        );
      default:
        return CallDisplayInfo(
          type: CallDisplayType.incomingCall,
          // icon: Icons.phone,
          svgIcon: SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice),
          color: AppColors.verifiedColor.c00C32B,
          text: getCallTypeText('Call'), //'Call',
          callStatus: 'Call',
          chatListCallStatus: 'Call',
        );
    }
  }

  /// Specialized method for chatlist call display
  /// Takes into account caller information from the calls array for better direction detection
  CallDisplayInfo? getChatListCallDisplayInfo({
    required List<CallData>? calls,
    String? messageContent,
    String? messageType,
    int? currentUserId,
    int? messageSenderId, // NEW: sender_id from the message record
  }) {
    // Return null if no call data and not a call message
    if ((calls == null || calls.isEmpty) &&
        messageType?.toLowerCase() != 'call' &&
        !_isCallMessageContent(messageContent)) {
      return null;
    }

    // Use provided user ID, cached user ID, or return null
    final userId = currentUserId ?? _cachedUserId;
    if (userId == null) return null;

    try {
      // PRIORITY 1: Handle new call array structure first (most accurate)
      if (calls != null && calls.isNotEmpty) {
        final call = calls.first;
        // Override call.userId with messageSenderId for more accurate direction detection
        if (messageSenderId != null) {
          final updatedCall = CallData(
            callId: call.callId,
            callType: call.callType,
            callStatus: call.callStatus,
            callDuration: call.callDuration,
            startTime: call.startTime,
            endTime: call.endTime,
            users: call.users,
            messageId: call.messageId,
            chatId: call.chatId,
            userId: messageSenderId, // Use message sender ID for direction
            roomId: call.roomId,
            currentUsers: call.currentUsers,
            updatedAt: call.updatedAt,
            createdAt: call.createdAt,
            caller: call.caller,
          );
          return _getCallInfoFromCallData(updatedCall, userId);
        }
        return _getCallInfoFromCallData(call, userId);
      }

      // PRIORITY 2: Handle legacy message content based calls with enhanced logic
      if (_isCallMessageContent(messageContent)) {
        // Use messageSenderId as primary source, fallback to calls array
        int? callerId = messageSenderId;
        if (callerId == null && calls != null && calls.isNotEmpty) {
          callerId = calls.first.caller?.userId;
        }

        // Debug logging to understand the data structure
        debugPrint('ChatList Call Debug:');
        debugPrint('Message Content: $messageContent');
        debugPrint('Message Type: $messageType');
        debugPrint('Current User ID: $userId');
        debugPrint('Message Sender ID: $messageSenderId');
        debugPrint('Caller ID: $callerId');
        debugPrint('Calls Array Length: ${calls?.length ?? 0}');
        if (calls != null && calls.isNotEmpty) {
          final call = calls.first;
          debugPrint('Call Status: ${call.callStatus}');
          debugPrint('Users in call: ${call.users}');
          debugPrint(
            'FIXED Call Direction: ${callerId == userId ? "Outgoing" : "Incoming"}',
          );
        }

        return _getCallInfoFromMessageContent(messageContent, userId, callerId);
      }

      return null;
    } catch (e) {
      debugPrint('Error in CallDisplayService.getChatListCallDisplayInfo: $e');
      return null;
    }
  }

  /// Check if message content indicates a call message
  bool _isCallMessageContent(String? messageContent) {
    if (messageContent == null) return false;
    const callContents = [
      'callmissed',
      'calling',
      'ongoing',
      'callended',
      'ended',
      'declined',
      'missed call',
      'call',
      'missed',
      'ringing',
    ];
    return callContents.contains(messageContent.toLowerCase());
  }

  /// Format call duration in seconds to readable format
  String? _formatDuration(int? durationInSeconds) {
    if (durationInSeconds == null || durationInSeconds == 0) return null;

    final minutes = durationInSeconds ~/ 60;
    final seconds = durationInSeconds % 60;

    if (minutes > 0) {
      return AppString.minSecDuration('$minutes', '$seconds');
    } else {
      return '$seconds sec';
    }
  }

  /// Widget helper for chat list display
  Widget buildChatListCallWidget(
    CallDisplayInfo callInfo,
    BuildContext context,
  ) {
    return Row(
      children: [
        // Icon(callInfo.icon, size: 14, color: callInfo.color),
        callInfo.svgIcon,
        SizedBox(width: 4),
        Expanded(
          child: Text(
            callInfo.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ),
        if (callInfo.duration != null) ...[
          SizedBox(width: 4),
          Text(
            callInfo.duration!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }

  /// Widget helper for universal chat display
  Widget buildUniversalChatCallWidget(
    CallDisplayInfo callInfo,
    bool isSendByMe,
    BuildContext context,
  ) {
    return Container(
      constraints: BoxConstraints(maxWidth: SizeConfig.screenWidth * 0.60),
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.scaffoldBackColor,
        // callInfo.type == CallDisplayType.missedCall
        //     ? Colors.red[50]
        //     : Colors.green[50],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(isSendByMe ? 8 : 0),
          bottomRight: Radius.circular(isSendByMe ? 0 : 8),
        ),
        border: Border.all(
          color: AppThemeManage.appTheme.borderColor,
          // callInfo.type == CallDisplayType.missedCall
          //     ? Colors.red[200]!
          //     : Colors.green[200]!,
          width: 2.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon(callInfo.icon, size: 16, color: callInfo.color),
          Container(
            height: SizeConfig.sizedBoxHeight(45),
            width: SizeConfig.sizedBoxWidth(45),
            padding: SizeConfig.getPadding(
              callInfo.text == 'Video Call' ? 9 : 11,
            ),
            decoration: BoxDecoration(
              color: AppThemeManage.appTheme.darkGreyColor,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.grey.withValues(alpha: 0.10)),
            ),
            child: callInfo.svgIcon,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  callInfo.text,
                  style: AppTypography.innerText14(
                    context,
                  ).copyWith(fontSize: 13),
                  // Theme.of(context).textTheme.bodyMedium?.copyWith(
                  //   color: callInfo.color,
                  //   fontWeight: FontWeight.w500,
                  // ),
                ),
                Row(
                  children: [
                    Text(
                      callInfo.callStatus,
                      style: AppTypography.innerText10(
                        context,
                      ).copyWith(color: AppColors.textColor.textDarkGray),
                    ),
                    if (callInfo.duration != null) ...[
                      Text(
                        ' • ${callInfo.duration!}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: callInfo.color,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOCKET EVENT HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Handle receiving_call socket event (for receiver)
  CallDisplayInfo? handleReceivingCallEvent(
    Map<String, dynamic> eventData,
    int currentUserId,
  ) {
    try {
      final call = eventData['call'];
      final user = eventData['user'];

      if (call == null || user == null) return null;

      // final callerId = user['user_id'] ?? call['user_id']; // Not used in current implementation
      final callType = (call['call_type'] ?? 'voice').toString().toLowerCase();
      final callerName =
          call['caller_name'] ?? user['full_name'] ?? user['user_name'];
      final typeText =
          callType == 'video'
              ? 'video'
              : (callType == 'audio' ? 'audio' : 'voice');

      // For receiving_call event, current user is always the receiver
      return CallDisplayInfo(
        type: CallDisplayType.incomingCall,
        // icon: callType == 'video' ? Icons.videocam : Icons.call_received,
        svgIcon:
            callType == 'video'
                ? SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVideo)
                : SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVoice),
        color: AppColors.verifiedColor.c00C32B,
        text: AppString.incomingTypeCallFromCaller(AppString.tr(typeText), callerName),
        callStatus: AppString.incomingTypeCallFromCaller(AppString.tr(typeText), callerName),
        chatListCallStatus: AppString.incomingTypeCallFromCaller(AppString.tr(typeText), callerName),
      );
    } catch (e) {
      debugPrint('Error handling receiving_call event: $e');
      return null;
    }
  }

  /// Handle user_joined socket event
  CallDisplayInfo? handleUserJoinedEvent(
    Map<String, dynamic> eventData,
    int currentUserId,
  ) {
    try {
      final call = eventData['call'];
      final user = eventData['user'];

      if (call == null || user == null) return null;

      final callType = call['call_type'] ?? 'voice';
      final joinedUserId = user['user_id'];

      final userJoined = joinedUserId == currentUserId;
      final typeText =
          callType == 'video'
              ? 'video'
              : (callType == 'audio' ? 'audio' : 'voice');

      return CallDisplayInfo(
        type: CallDisplayType.ongoingCall,
        // icon: callType == 'video' ? Icons.videocam : Icons.phone,
        svgIcon:
            callType == 'video'
                ? SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVideo)
                : SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice),
        color: AppColors.verifiedColor.c00C32B,
        text: userJoined ? 'You joined the call' : 'Ongoing $typeText call',
        callStatus:
            userJoined ? 'You joined the call' : 'Ongoing $typeText call',
        chatListCallStatus:
            userJoined ? 'You joined the call' : 'Ongoing $typeText call',
      );
    } catch (e) {
      debugPrint('Error handling user_joined event: $e');
      return null;
    }
  }

  /// Handle call_ended socket event
  CallDisplayInfo? handleCallEndedEvent(
    Map<String, dynamic> eventData,
    int currentUserId,
  ) {
    try {
      final callerId = eventData['caller']?['user_id'] ?? eventData['user_id'];
      final callDuration = eventData['call_duration'] ?? 0;
      final callType = eventData['call_type'] ?? 'voice';
      // final users = eventData['users'] as List? ?? []; // Not used in current implementation

      final durationText = _formatDuration(callDuration);
      final isOutgoingCall = callerId == currentUserId;
      final typeText =
          callType == 'video'
              ? 'video'
              : (callType == 'audio' ? 'audio' : 'voice');
      // final userParticipated = users.contains(currentUserId); // Not used in current implementation

      if (isOutgoingCall) {
        return CallDisplayInfo(
          type: CallDisplayType.outgoingCall,
          // icon: callType == 'video' ? Icons.videocam_outlined : Icons.call_made,
          svgIcon:
              callType == 'video'
                  ? SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVideo)
                  : SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice),
          color: AppColors.verifiedColor.c00C32B,
          text: AppString.outgoingTypeCall(AppString.tr(typeText)),
          callStatus: AppString.outgoingTypeCall(AppString.tr(typeText)),
          chatListCallStatus: AppString.outgoingTypeCall(AppString.tr(typeText)),
          duration: durationText,
        );
      } else {
        return CallDisplayInfo(
          type: CallDisplayType.incomingCall,
          // icon:
          //     callType == 'video'
          //         ? Icons.videocam_outlined
          //         : Icons.call_received,
          svgIcon:
              callType == 'video'
                  ? SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVideo)
                  : SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVoice),
          color: AppColors.verifiedColor.c00C32B,
          text: AppString.incomingTypeCall(AppString.tr(typeText)),
          callStatus: AppString.incomingTypeCall(AppString.tr(typeText)),
          chatListCallStatus: AppString.incomingTypeCall(AppString.tr(typeText)),
          duration: durationText,
        );
      }
    } catch (e) {
      debugPrint('Error handling call_ended event: $e');
      return null;
    }
  }

  /// Handle missed_call socket event
  CallDisplayInfo? handleMissedCallEvent(
    Map<String, dynamic> eventData,
    int currentUserId,
  ) {
    try {
      final callerId = eventData['caller']?['user_id'] ?? eventData['user_id'];
      final callType =
          (eventData['call_type'] ?? 'voice').toString().toLowerCase();
      final callerName =
          eventData['caller']?['full_name'] ??
          eventData['caller']?['user_name'];
      final users = eventData['users'] as List? ?? [];

      // Check if current user was the caller (outgoing call)
      final isOutgoingCall = callerId == currentUserId;

      // Check if current user is in users array (was supposed to answer)
      final currentUserInUsers = users.contains(currentUserId);

      // Helper function to get appropriate icon
      SvgPicture getSocketCallIcon(String status, String type) {
        if (type == 'video') {
          switch (status) {
            case 'cancelled':
              return SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.missedcallVideo,
              ); //Icons.videocam_off;
            case 'missed':
              return SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.missedcallVideo,
              ); //Icons.videocam_off;
            case 'incoming':
              return SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.incomingVideo,
              ); //Icons.videocam_outlined;
            default:
              return SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.outgoingVideo,
              ); //Icons.videocam_outlined;
          }
        } else {
          // Handles both 'audio' and 'voice' call types
          switch (status) {
            case 'cancelled':
              return SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.missedCallVoice,
              ); //Icons.call_made;
            case 'missed':
              return SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.missedCallVoice,
              ); //Icons.phone_missed_outlined;
            case 'incoming':
              return SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.incomingVoice,
              ); //Icons.call_received;
            default:
              return SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.outgoingVoice,
              ); //Icons.call_made;
          }
        }
      }

      final typeText =
          callType == 'video'
              ? 'video'
              : (callType == 'audio' ? 'audio' : 'voice');

      if (isOutgoingCall) {
        // Current user was the caller - call was cancelled/not answered
        return CallDisplayInfo(
          type: CallDisplayType.outgoingCall,
          // icon: getSocketCallIcon('cancelled', callType),
          svgIcon: getSocketCallIcon('cancelled', callType),
          color: AppColors.appPriSecColor.primaryColor,
          text: AppString.cancelledTypeCall(AppString.tr(typeText)),
          callStatus: AppString.cancelledTypeCall(AppString.tr(typeText)),
          chatListCallStatus: AppString.cancelledTypeCall(AppString.tr(typeText)),
        );
      } else if (!currentUserInUsers) {
        // Current user was supposed to answer but is NOT in users array = MISSED CALL
        return CallDisplayInfo(
          type: CallDisplayType.missedCall,
          // icon: getSocketCallIcon('missed', callType),
          svgIcon: getSocketCallIcon('missed', callType),
          color: AppColors.appPriSecColor.secondaryRed,
          text:
              (callerName != null ? AppString.missedTypeCallFromCaller(AppString.tr(typeText), callerName) : AppString.missedTypeCall(AppString.tr(typeText))),
          callStatus:
              (callerName != null ? AppString.missedTypeCallFromCaller(AppString.tr(typeText), callerName) : AppString.missedTypeCall(AppString.tr(typeText))),
          chatListCallStatus:
              (callerName != null ? AppString.missedTypeCallFromCaller(AppString.tr(typeText), callerName) : AppString.missedTypeCall(AppString.tr(typeText))),
        );
      } else {
        // Current user was in the call (users array) but call ended - answered call
        return CallDisplayInfo(
          type: CallDisplayType.incomingCall,
          // icon: getSocketCallIcon('incoming', callType),
          svgIcon: getSocketCallIcon('incoming', callType),
          color: AppColors.verifiedColor.c00C32B,
          text: AppString.incomingTypeCall(AppString.tr(typeText)),
          callStatus: AppString.incomingTypeCall(AppString.tr(typeText)),
          chatListCallStatus: AppString.incomingTypeCall(AppString.tr(typeText)),
        );
      }
    } catch (e) {
      debugPrint('Error handling missed_call event: $e');
      return null;
    }
  }

  /// Handle recieve event (call initiated by current user)
  CallDisplayInfo? handleReceiveEvent(
    Map<String, dynamic> eventData,
    int currentUserId,
  ) {
    try {
      final records = eventData['Records'] as List? ?? [];
      if (records.isEmpty) return null;

      final record = records.first;
      final calls = record['Calls'] as List? ?? [];
      if (calls.isEmpty) return null;

      final call = calls.first;
      final senderId = record['sender_id'];
      final callType = call['call_type'] ?? 'voice';
      // final callStatus = call['call_status'] ?? 'ringing'; // Not used in current implementation

      final isOutgoingCall = senderId == currentUserId;
      final typeText =
          callType == 'video'
              ? 'video'
              : (callType == 'audio' ? 'audio' : 'voice');

      if (isOutgoingCall) {
        return CallDisplayInfo(
          type: CallDisplayType.outgoingCall,
          // icon: callType == 'video' ? Icons.videocam_outlined : Icons.call_made,
          svgIcon:
              callType == 'video'
                  ? SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVideo)
                  : SvgPicture.asset(AppAssets.chatMsgTypeIcon.outgoingVoice),
          color: AppColors.verifiedColor.c00C32B,
          text: AppString.outgoingTypeCall(AppString.tr(typeText)),
          callStatus: AppString.outgoingTypeCall(AppString.tr(typeText)),
          chatListCallStatus: AppString.outgoingTypeCall(AppString.tr(typeText)),
        );
      } else {
        return CallDisplayInfo(
          type: CallDisplayType.incomingCall,
          // icon:
          //     callType == 'video'
          //         ? Icons.videocam_outlined
          //         : Icons.call_received,
          svgIcon:
              callType == 'video'
                  ? SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVideo)
                  : SvgPicture.asset(AppAssets.chatMsgTypeIcon.incomingVoice),
          color: AppColors.verifiedColor.c00C32B,
          text: AppString.incomingTypeCall(AppString.tr(typeText)),
          callStatus: AppString.incomingTypeCall(AppString.tr(typeText)),
          chatListCallStatus: AppString.incomingTypeCall(AppString.tr(typeText)),
        );
      }
    } catch (e) {
      debugPrint('Error handling recieve event: $e');
      return null;
    }
  }
}
