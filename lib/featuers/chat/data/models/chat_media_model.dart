class ChatMediaResponse {
  final bool status;
  final Data? data;
  final String message;
  final int toast;

  ChatMediaResponse({
    required this.status,
    this.data,
    required this.message,
    required this.toast,
  });

  factory ChatMediaResponse.fromJson(Map<String, dynamic> json) {
    return ChatMediaResponse(
      status: json['status'] ?? false,
      data: json['data'] != null ? Data.fromJson(json['data']) : null,
      message: json['message'] ?? '',
      toast: json['toast'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'data': data?.toJson(),
    'message': message,
    'toast': toast,
  };
}

class Data {
  final List<Records> records;
  final Pagenation? pagenation;

  Data({required this.records, this.pagenation});

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      records:
          (json['Records'] as List? ?? [])
              .map((e) => Records.fromJson(e))
              .toList(),
      pagenation:
          json['pagenation'] != null
              ? Pagenation.fromJson(json['pagenation'])
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'Records': records.map((e) => e.toJson()).toList(),
    'pagenation': pagenation?.toJson(),
  };
}

class Records {
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
  final int? pinLifetime;
  final dynamic peerUser;
  final String? pinnedTill;
  final int forwardedFrom;
  final String createdAt;
  final String updatedAt;
  final int chatId;
  final int senderId;
  final User? user;

  Records({
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
    required this.senderId,
    this.user,
  });

  factory Records.fromJson(Map<String, dynamic> json) {
    return Records(
      messageContent: json['message_content'] ?? '',
      messageThumbnail: json['message_thumbnail'] ?? '',
      replyTo: json['reply_to'] ?? 0,
      socialId: json['social_id'] ?? 0,
      messageId: json['message_id'] ?? 0,
      messageType: json['message_type'] ?? '',
      messageLength: json['message_length'] ?? '',
      messageSeenStatus: json['message_seen_status'] ?? '',
      messageSize: json['message_size'] ?? '',
      deletedFor:
          (json['deleted_for'] as List? ?? [])
              .map((e) => e.toString())
              .toList(),
      starredFor:
          (json['starred_for'] as List? ?? [])
              .map((e) => e.toString())
              .toList(),
      deletedForEveryone: json['deleted_for_everyone'] ?? false,
      pinned: json['pinned'] ?? false,
      pinLifetime: json['pin_lifetime'],
      peerUser: json['peer_user'],
      pinnedTill: json['pinned_till'],
      forwardedFrom: json['forwarded_from'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      chatId: json['chat_id'] ?? 0,
      senderId: json['sender_id'] ?? 0,
      user: json['User'] != null ? User.fromJson(json['User']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'message_content': messageContent,
    'message_thumbnail': messageThumbnail,
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
    'pin_lifetime': pinLifetime,
    'peer_user': peerUser,
    'pinned_till': pinnedTill,
    'forwarded_from': forwardedFrom,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'chat_id': chatId,
    'sender_id': senderId,
    'User': user?.toJson(),
  };

  bool get isImage => messageType == 'image';
  bool get isGif => messageType == 'gif';
  bool get isVideo => messageType == 'video';
  bool get isAudio => messageType == 'audio';
  bool get isDocument => messageType == 'document';
  bool get isLinks => messageType == 'link';
  bool get hasValidThumbnail => messageThumbnail.isNotEmpty;
}

class User {
  final String userName;
  final String profilePic;
  final int userId;
  final String fullName;

  User({
    required this.userName,
    required this.profilePic,
    required this.userId,
    required this.fullName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userName: json['user_name'] ?? '',
      profilePic: json['profile_pic'] ?? '',
      userId: json['user_id'] ?? 0,
      fullName: json['full_name'] ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
    'user_name': userName,
    'profile_pic': profilePic,
    'user_id': userId,
    'full_name': fullName,
  };
}

class Pagenation {
  int? totalRecords;
  int? currentPage;
  int? recordsPerPage;
  int? totalPages;

  Pagenation({
    this.totalRecords,
    this.currentPage,
    this.recordsPerPage,
    this.totalPages,
  });

  factory Pagenation.fromJson(Map<String, dynamic> json) => Pagenation(
    totalRecords: json['total_records'],
    currentPage: json['current_page'],
    recordsPerPage: json['records_per_page'],
    totalPages: json['total_pages'],
  );

  Map<String, dynamic> toJson() => {
    'total_records': totalRecords,
    'current_page': currentPage,
    'records_per_page': recordsPerPage,
    'total_pages': totalPages,
  };
}
