import 'package:flutter/foundation.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart';

class ChatListModel {
  Pagination? pagination;
  List<Chats> chats;

  ChatListModel({this.pagination, List<Chats>? chats}) : chats = chats ?? [];

  factory ChatListModel.fromJson(Map<String, dynamic> json) {
    return ChatListModel(
      pagination:
          json['pagination'] != null
              ? Pagination.fromJson(json['pagination'])
              : null,
      chats:
          json['Chats'] != null
              ? List<Chats>.from(json['Chats'].map((x) => Chats.fromJson(x)))
              : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pagination': pagination?.toJson(),
      'Chats': chats.map((x) => x.toJson()).toList(),
    };
  }
}

class Pagination {
  int? totalPages;
  int? totalRecords;
  int? currentPage;
  int? recordsPerPage;

  Pagination({
    this.totalPages,
    this.totalRecords,
    this.currentPage,
    this.recordsPerPage,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      totalPages: json['total_pages'],
      totalRecords: json['total_records'],
      currentPage: json['current_page'],
      recordsPerPage: json['records_per_page'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_pages': totalPages,
      'total_records': totalRecords,
      'current_page': currentPage,
      'records_per_page': recordsPerPage,
    };
  }
}

class Chats {
  List<Records>? records;
  PeerUserData? peerUserData;

  Chats({this.records, this.peerUserData});

  factory Chats.fromJson(Map<String, dynamic> json) {
    try {
      return Chats(
        records:
            json['Records'] != null
                ? List<Records>.from(
                  json['Records'].map((x) => Records.fromJson(x)),
                )
                : null,
        peerUserData:
            json['PeerUserData'] != null
                ? PeerUserData.fromJson(json['PeerUserData'])
                : null,
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing Chats: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('JSON: $json');
      // Return a mostly empty object that won't crash the UI
      return Chats(records: [], peerUserData: null);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'Records': records?.map((x) => x.toJson()).toList(),
      'PeerUserData': peerUserData?.toJson(),
    };
  }
}

class Records {
  int? chatId;
  String? groupIcon;
  String? chatType;
  String? groupName;
  String? groupDescription;
  String? deletedAt;
  String? createdAt;
  String? updatedAt;
  List<Messages>? messages;
  int? unseenCount;
  List<String>? blockedBy;
  List<dynamic>? archivedFor;
  List<Participants>? participants;
  bool? isPinned;
  bool? isFavorite;
  bool? isMuted;
  bool? isArchived;
  List<String>? labelIds;

  Records({
    this.chatId,
    this.groupIcon,
    this.chatType,
    this.groupName,
    this.groupDescription,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
    this.messages,
    this.unseenCount,
    this.blockedBy,
    this.archivedFor,
    this.participants,
    this.isPinned,
    this.isFavorite,
    this.isMuted,
    this.isArchived,
    this.labelIds,
  });

  factory Records.fromJson(Map<String, dynamic> json) {
    try {
      return Records(
        chatId: json['chat_id'],
        groupIcon: json['group_icon'],
        chatType: json['chat_type'],
        groupName: json['group_name'],
        groupDescription: json['group_description'],
        deletedAt: json['deleted_at'],
        createdAt: json['createdAt'],
        updatedAt: json['updatedAt'],
        messages:
            json['Messages'] != null
                ? List<Messages>.from(
                  json['Messages'].map((x) => Messages.fromJson(x)),
                )
                : [],
        unseenCount: json['unseen_count'] ?? 0,
        isPinned: json['is_pinned'] as bool? ?? false,
        isFavorite: json['is_favorite'] as bool? ?? false,
        isMuted: json['is_muted'] as bool? ?? false,
        isArchived: json['is_archived'] as bool? ?? false,
        labelIds: (json['label_ids'] as List?)?.map((e) => e.toString()).toList(),
        blockedBy:
            json['blocked_by'] != null
                ? List<String>.from(json['blocked_by'])
                : [],
        archivedFor: json['archived_for'] ?? [],
        participants:
            json['participants'] != null
                ? List<Participants>.from(
                  json['participants'].map((x) => Participants.fromJson(x)),
                )
                : [],
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing Records: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('JSON: $json');
      // Return default values
      return Records(
        chatId: 0,
        messages: [],
        unseenCount: 0,
        blockedBy: [],
        archivedFor: [],
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'group_icon': groupIcon,
      'chat_type': chatType,
      'group_name': groupName,
      'group_description': groupDescription,
      'deleted_at': deletedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'Messages': messages?.map((x) => x.toJson()).toList(),
      'unseen_count': unseenCount,
      'blocked_by': blockedBy,
      'archived_for': archivedFor,
      'participants': participants?.map((x) => x.toJson()).toList(),
    };
  }
}

class Participants {
  int? participantId;
  bool? isAdmin;
  bool? updateCounter;
  bool? isDeleted;
  int? lastMessageId;
  bool? isCreator;
  bool? isLocked;
  // String? lockPin;
  String? lockedAt;
  String? createdAt;
  String? updatedAt;
  int? chatId;
  int? userId;

  Participants({
    this.participantId,
    this.isAdmin,
    this.updateCounter,
    this.isDeleted,
    this.lastMessageId,
    this.isCreator,
    this.isLocked,
    // this.lockPin,
    this.lockedAt,
    this.createdAt,
    this.updatedAt,
    this.chatId,
    this.userId,
  });

  factory Participants.fromJson(Map<String, dynamic> json) {
    try {
      return Participants(
        participantId: json['participant_id'],
        isAdmin: json['is_admin'],
        updateCounter: json['update_counter'],
        isDeleted: json['is_deleted'],
        lastMessageId: json['last_message_id'],
        isCreator: json['is_creator'],
        isLocked: json['is_locked'],
        // lockPin: json['lock_pin'],
        lockedAt: json['locked_at'],
        createdAt: json['createdAt'],
        updatedAt: json['updatedAt'],
        chatId: json['chat_id'],
        userId: json['user_id'],
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing Participants: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('JSON: $json');
      return Participants(
        participantId: 0,
        isAdmin: false,
        updateCounter: false,
        isDeleted: false,
        lastMessageId: 0,
        isCreator: false,
        isLocked: false,
        // lockPin: '',
        lockedAt: '',
        createdAt: '',
        updatedAt: '',
        chatId: 0,
        userId: 0,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'participant_id': participantId,
      'is_admin': isAdmin,
      'update_counter': updateCounter,
      'is_deleted': isDeleted,
      'last_message_id': lastMessageId,
      'is_creator': isCreator,
      'is_locked': isLocked,
      // 'lock_pin': lockPin,
      'locked_at': lockedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'chat_id': chatId,
      'user_id': userId,
    };
  }
}

class Messages {
  String? messageContent;
  int? replyTo;
  int? socialId;
  int? messageId;
  String? messageType;
  String? messageLength;
  String? messageSeenStatus;
  String? messageSize;
  List<dynamic>? deletedFor;
  List<dynamic>? starredFor;
  bool? deletedForEveryone;
  bool? pinned;
  String? createdAt;
  String? updatedAt;
  int? chatId;
  dynamic senderId;
  dynamic user;
  User? actionedUser;
  Social? social;
  List<CallData>? calls;

  Messages({
    this.messageContent,
    this.replyTo,
    this.socialId,
    this.messageId,
    this.messageType,
    this.messageLength,
    this.messageSeenStatus,
    this.messageSize,
    this.deletedFor,
    this.starredFor,
    this.deletedForEveryone,
    this.pinned,
    this.createdAt,
    this.updatedAt,
    this.chatId,
    this.senderId,
    this.user,
    this.actionedUser,
    this.social,
    this.calls,
  });

  factory Messages.fromJson(Map<String, dynamic> json) {
    try {
      return Messages(
        messageContent: json['message_content'],
        replyTo: json['reply_to'],
        socialId: json['social_id'],
        messageId: json['message_id'],
        messageType: json['message_type'],
        messageLength: json['message_length'],
        messageSeenStatus: json['message_seen_status'],
        messageSize: json['message_size'],
        deletedFor: json['deleted_for'],
        starredFor: json['starred_for'],
        deletedForEveryone: json['deleted_for_everyone'],
        pinned: json['pinned'],
        createdAt: json['createdAt'],
        updatedAt: json['updatedAt'],
        chatId: json['chat_id'],
        senderId: json['sender_id'],
        user: json['User'],
        actionedUser:
            json['ActionedUser'] != null
                ? User.fromJson(json['ActionedUser'])
                : null,
        // Add social property if present in your model
        social: json['social'] != null ? Social.fromJson(json['social']) : null,
        // Parse Calls array
        calls:
            json['Calls'] != null
                ? (json['Calls'] as List)
                    .map((call) => CallData.fromJson(call))
                    .toList()
                : null,
      );
    } catch (e) {
      debugPrint('Error parsing Messages: $e');
      return Messages(
        messageContent: 'Error parsing message',
        messageType: 'text',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'message_content': messageContent,
      'reply_to': replyTo,
      'social_id': socialId,
      'message_id': messageId,
      'message_type': messageType,
      'message_length': messageLength,
      'message_seen_status': messageSeenStatus,
      'message_size': messageSize,
      'deleted_for': deletedFor,
      'starred_for': starredFor,
      'deleted_for_everyone': deletedForEveryone,
      'pinned': pinned,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'chat_id': chatId,
      'sender_id': senderId,
      'User': user,
      'ActionedUser': actionedUser?.toJson(),
      'social': social?.toJson(),
      'Calls': calls?.map((x) => x.toJson()).toList(),
    };
  }
}

class PeerUserData {
  String? userName;
  String? email;
  String? profilePic;
  int? userId;
  String? fullName;
  String? firstName;
  String? lastName;
  String? countryCode;
  String? phoneNumber;
  String? country;
  String? gender;
  String? bio;
  bool? profileVerificationStatus;
  bool? loginVerificationStatus;
  List<String>? socketIds;
  String? updatedAt;
  String? createdAt;
  String? userType;

  PeerUserData({
    this.userName,
    this.email,
    this.profilePic,
    this.userId,
    this.fullName,
    this.firstName,
    this.lastName,
    this.countryCode,
    this.phoneNumber,
    this.country,
    this.gender,
    this.bio,
    this.profileVerificationStatus,
    this.loginVerificationStatus,
    this.socketIds,
    this.updatedAt,
    this.createdAt,
    this.userType,
  });

  factory PeerUserData.fromJson(Map<String, dynamic> json) {
    try {
      return PeerUserData(
        userName: json['user_name'],
        email: json['email'],
        profilePic: json['profile_pic'],
        userId: json['user_id'],
        fullName: json['full_name'] ?? '', // Use empty string if null
        firstName: json['first_name'],
        lastName: json['last_name'],
        countryCode: json['country_code'],
        phoneNumber: json['mobile_num'],
        country: json['country'],
        gender: json['gender'],
        bio: json['bio'],
        profileVerificationStatus: json['profile_verification_status'],
        loginVerificationStatus: json['login_verification_status'],
        socketIds:
            json['socket_ids'] != null
                ? List<String>.from(json['socket_ids'])
                : [],
        updatedAt: json['updatedAt'],
        createdAt: json['createdAt'],
        userType: json['user_type'],
      );
    } catch (e) {
      debugPrint('Error parsing PeerUserData: $e');
      return PeerUserData(userId: 0, fullName: 'Unknown User');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'user_name': userName,
      'email': email,
      'profile_pic': profilePic,
      'user_id': userId,
      'full_name': fullName,
      'first_name': firstName,
      'last_name': lastName,
      'country_code': countryCode,
      'mobile_num': phoneNumber,
      'country': country,
      'gender': gender,
      'bio': bio,
      'profile_verification_status': profileVerificationStatus,
      'login_verification_status': loginVerificationStatus,
      'socket_ids': socketIds,
      'updatedAt': updatedAt,
      'createdAt': createdAt,
      'user_type': userType,
    };
  }
}

class Social {
  String? reelThumbnail;
  int? socialId;
  String? socialDesc;
  String? socialType;
  int? totalViews;
  int? totalSaves;
  int? totalShares;
  User? user;

  Social({
    this.reelThumbnail,
    this.socialId,
    this.socialDesc,
    this.socialType,
    this.totalViews,
    this.totalSaves,
    this.totalShares,
    this.user,
  });

  factory Social.fromJson(Map<String, dynamic> json) {
    return Social(
      reelThumbnail: json['reel_thumbnail'],
      socialId: json['social_id'],
      socialDesc: json['social_desc'],
      socialType: json['social_type'],
      totalViews: json['total_views'],
      totalSaves: json['total_saves'],
      totalShares: json['total_shares'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reel_thumbnail': reelThumbnail,
      'social_id': socialId,
      'social_desc': socialDesc,
      'social_type': socialType,
      'total_views': totalViews,
      'total_saves': totalSaves,
      'total_shares': totalShares,
      'user': user?.toJson(),
    };
  }
}

class User {
  int? userId;
  String? userName;
  String? fullName;
  String? profilePic;

  User({this.userId, this.userName, this.fullName, this.profilePic});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      userName: json['user_name'],
      fullName: json['full_name'],
      profilePic: json['profile_pic'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'full_name': fullName,
      'profile_pic': profilePic,
    };
  }
}
