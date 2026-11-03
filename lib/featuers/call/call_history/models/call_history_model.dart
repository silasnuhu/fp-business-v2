// ignore_for_file: unused_local_variable

import 'package:flutter/foundation.dart';
import 'package:whoxa/main.dart';
import 'package:whoxa/widgets/global.dart';

class CallHistoryResponse {
  final bool status;
  final CallHistoryData data;
  final String message;
  final int toast;

  CallHistoryResponse({
    required this.status,
    required this.data,
    required this.message,
    required this.toast,
  });

  factory CallHistoryResponse.fromJson(Map<String, dynamic> json) {
    return CallHistoryResponse(
      status: json['status'] ?? false,
      data: CallHistoryData.fromJson(json['data'] ?? {}),
      message: json['message'] ?? '',
      toast: json['toast'] ?? 0,
    );
  }
}

class CallHistoryData {
  final List<CallRecord> records;
  final PaginationInfo pagination;

  CallHistoryData({required this.records, required this.pagination});

  factory CallHistoryData.fromJson(Map<String, dynamic> json) {
    return CallHistoryData(
      records:
          (json['Records'] as List<dynamic>?)
              ?.map((item) => CallRecord.fromJson(item))
              .toList() ??
          [],
      pagination: PaginationInfo.fromJson(json['Pagination'] ?? {}),
    );
  }
}

class CallRecord {
  final String messageContent;
  final String messageThumbnail;
  final int replyTo;
  final int socialId;
  final int messageId;
  final String messageType;
  final String messageLength;
  final String messageSeenStatus;
  final String messageSize;
  final List<String> deletedFor;
  final List<String> starredFor;
  final bool deletedForEveryone;
  final bool pinned;
  final String? pinLifetime;
  final List<PeerUser>? peerUser;
  final String? pinnedTill;
  final int forwardedFrom;
  final String createdAt;
  final String updatedAt;
  final int chatId;
  final int? senderId;
  final List<CallInfo> calls;
  final ChatInfo? chat;

  CallRecord({
    required this.messageContent,
    required this.messageThumbnail,
    required this.replyTo,
    required this.socialId,
    required this.messageId,
    required this.messageType,
    required this.messageLength,
    required this.messageSeenStatus,
    required this.messageSize,
    required this.deletedFor,
    required this.starredFor,
    required this.deletedForEveryone,
    required this.pinned,
    this.pinLifetime,
    this.peerUser,
    this.pinnedTill,
    required this.forwardedFrom,
    required this.createdAt,
    required this.updatedAt,
    required this.chatId,
    this.senderId,
    required this.calls,
    this.chat,
  });

  factory CallRecord.fromJson(Map<String, dynamic> json) {
    List<PeerUser> parsePeerUser(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        // API sends [] array
        return value.map((item) => PeerUser.fromJson(item)).toList();
      }
      if (value is Map<String, dynamic>) {
        // API sends {} object
        return [PeerUser.fromJson(value)];
      }
      return [];
    }

    return CallRecord(
      messageContent: json['message_content'] ?? '',
      messageThumbnail: json['message_thumbnail'] ?? '',
      replyTo: json['reply_to'] ?? 0,
      socialId: json['social_id'] ?? 0,
      messageId: json['message_id'] ?? 0,
      messageType: json['message_type'] ?? '',
      messageLength: json['message_length'] ?? '',
      messageSeenStatus: json['message_seen_status'] ?? '',
      messageSize: json['message_size'] ?? '',
      deletedFor: List<String>.from(json['deleted_for'] ?? []),
      starredFor: List<String>.from(json['starred_for'] ?? []),
      deletedForEveryone: json['deleted_for_everyone'] ?? false,
      pinned: json['pinned'] ?? false,
      pinLifetime: json['pin_lifetime'],
      // peerUser:
      //     (json['peer_user'] as List<dynamic>?)
      //         ?.map((item) => PeerUser.fromJson(item))
      //         .toList() ??
      //     [],
      peerUser: parsePeerUser(json['peer_user']),
      pinnedTill: json['pinned_till'],
      forwardedFrom: json['forwarded_from'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      chatId: json['chat_id'] ?? 0,
      senderId: json['sender_id'],
      calls:
          (json['Calls'] as List<dynamic>?)
              ?.map((item) => CallInfo.fromJson(item))
              .toList() ??
          [],
      chat: json['Chat'] != null ? ChatInfo.fromJson(json['Chat']) : null,
    );
  }

  // Helper method to get the primary call info (first call in the array)
  CallInfo? get primaryCall => calls.isNotEmpty ? calls.first : null;
  PeerUser? get peerUserInfo => peerUser!.isNotEmpty ? peerUser!.first : null;

  // Helper method to determine call direction based on current user
  String getCallDirection(String currentUserId) {
    final call = primaryCall;
    if (call == null) return 'unknown';

    final String? peerUserId = peerUserInfo?.userId?.toString();
    final bool isSelfUser = peerUserId != call.caller!.userId.toString();

    if (messageContent == "call missed" || call.callStatus == "missed") {
      logger.v("MISSED_CALL_called: $peerUserId");
      logger.v("MISSED_CALL_called:${userID.toString()}");
      if (call.callType == 'audio') {
        return
        // isSelfUser ? "outgoing audio" :
        "missed audio";
      } else if (call.callType == 'video') {
        return
        // isSelfUser ? "outgoing video" :
        "missed video";
      }
    } else if (messageContent == "call ended" ||
        call.callStatus == "ended" ||
        call.callStatus == "rejected") {
      // Determine if it was incoming or outgoing based on sender
      if (call.callType == 'audio') {
        if (senderId?.toString() == currentUserId) {
          return "outgoing audio";
        } else {
          return "incoming audio";
        }
      } else if (call.callType == 'video') {
        debugPrint("senderID:${senderId?.toString()}");
        debugPrint("currentUserId:${currentUserId.toString()}");
        if (senderId?.toString() == currentUserId) {
          return "outgoing video";
        } else {
          return "incoming video";
        }
      }
    } else if (messageContent == "calling" || call.callStatus == "ringing") {
      // For ringing calls, check sender to determine direction
      if (senderId?.toString() == currentUserId) {
        return "outgoing";
      } else {
        return "incoming";
      }
    }

    return "unknown";
  }

  // Helper method to format call duration
  String getFormattedDuration() {
    final call = primaryCall;
    if (call == null || call.callDuration <= 0) return "00:00";

    int duration = call.callDuration;
    int hours = duration ~/ 3600;
    int minutes = (duration % 3600) ~/ 60;
    int seconds = duration % 60;

    if (hours > 0) {
      return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } else {
      return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
  }

  // Helper method to get call type
  String getCallType() {
    final call = primaryCall;
    return call?.callType ?? 'unknown';
  }

  // Helper method to check if it's a video call
  bool get isVideoCall => getCallType() == 'video';

  // Helper method to get caller name
  String getCallerName() {
    // First, try to get the actual caller name from the call data
    final call = primaryCall;
    if (call?.caller != null) {
      // Use userName if available, otherwise fallback to fullName
      if (call!.caller!.userName.isNotEmpty) {
        return call.caller!.userName;
      } else if (call.caller!.fullName.isNotEmpty) {
        return call.caller!.fullName;
      }
    }

    // Fallback to chat info if available
    if (chat != null) {
      if (chat!.chatType == 'group') {
        return chat!.groupName ?? 'Group Call';
      } else {
        return 'Contact'; // Fallback for individual calls without caller info
      }
    }

    return 'Unknown';
  }

  // Helper method to get caller display info
  String getCallerDisplayInfo() {
    // Use the same logic as getCallerName for consistency
    return getCallerName();
  }

  // Helper method to get caller profile picture
  String? getCallerProfilePic() {
    final call = primaryCall;
    if (call?.caller != null && call!.caller!.profilePic.isNotEmpty) {
      return call.caller!.profilePic;
    }
    return null;
  }

  // Helper method to get caller user ID
  int? getCallerUserId() {
    final call = primaryCall;
    if (call?.caller != null) {
      return call!.caller!.userId;
    }
    return null;
  }
}

class PeerUser {
  String? userName;
  String? profilePic;
  String? bannerImage;
  int? userId;
  String? fullName;

  PeerUser({
    this.userName,
    this.profilePic,
    this.bannerImage,
    this.userId,
    this.fullName,
  });

  PeerUser.fromJson(Map<String, dynamic> json) {
    userName = json['user_name'];
    profilePic = json['profile_pic'];
    bannerImage = json['banner_image'];
    userId = json['user_id'];
    fullName = json['full_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_name'] = userName;
    data['profile_pic'] = profilePic;
    data['banner_image'] = bannerImage;
    data['user_id'] = userId;
    data['full_name'] = fullName;
    return data;
  }
}

class CallInfo {
  final int callId;
  final String callType;
  final int callDuration;
  final String callStatus;
  final CallerInfo? caller;

  CallInfo({
    required this.callId,
    required this.callType,
    required this.callDuration,
    required this.callStatus,
    this.caller,
  });

  factory CallInfo.fromJson(Map<String, dynamic> json) {
    return CallInfo(
      callId: json['call_id'] ?? 0,
      callType: json['call_type'] ?? '',
      callDuration: json['call_duration'] ?? 0,
      callStatus: json['call_status'] ?? '',
      caller:
          json['caller'] != null ? CallerInfo.fromJson(json['caller']) : null,
    );
  }
}

class PaginationInfo {
  final int totalPages;
  final int totalRecords;
  final int currentPage;
  final int recordsPerPage;

  PaginationInfo({
    required this.totalPages,
    required this.totalRecords,
    required this.currentPage,
    required this.recordsPerPage,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      totalPages: json['total_pages'] ?? 0,
      totalRecords: json['total_records'] ?? 0,
      currentPage: json['current_page'] ?? 1,
      recordsPerPage: json['records_per_page'] ?? 10,
    );
  }
}

class ChatInfo {
  final String groupIcon;
  final int chatId;
  final String chatType;
  final String? groupName;

  ChatInfo({
    required this.groupIcon,
    required this.chatId,
    required this.chatType,
    this.groupName,
  });

  factory ChatInfo.fromJson(Map<String, dynamic> json) {
    return ChatInfo(
      groupIcon: json['group_icon'] ?? '',
      chatId: json['chat_id'] ?? 0,
      chatType: json['chat_type'] ?? '',
      groupName: json['group_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_icon': groupIcon,
      'chat_id': chatId,
      'chat_type': chatType,
      'group_name': groupName,
    };
  }
}

class CallerInfo {
  final String userName;
  final String fullName;
  final String profilePic;
  final int userId;

  CallerInfo({
    required this.userName,
    required this.fullName,
    required this.profilePic,
    required this.userId,
  });

  factory CallerInfo.fromJson(Map<String, dynamic> json) {
    return CallerInfo(
      userName: json['user_name'] ?? '',
      fullName: json['full_name'] ?? '',
      profilePic: json['profile_pic'] ?? '',
      userId: json['user_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_name': userName,
      'full_name': fullName,
      'profile_pic': profilePic,
      'user_id': userId,
    };
  }
}
