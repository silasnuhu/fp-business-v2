class PinnedMessagesModel {
  List<PinnedMessage>? pinnedMessages;
  Pagination? pagination;

  PinnedMessagesModel({this.pinnedMessages, this.pagination});

  PinnedMessagesModel.fromJson(Map<String, dynamic> json) {
    if (json['Records'] != null) {
      pinnedMessages = <PinnedMessage>[];
      json['Records'].forEach((v) {
        pinnedMessages!.add(PinnedMessage.fromJson(v));
      });
    }
    pagination =
        json['Pagination'] != null
            ? Pagination.fromJson(json['Pagination'])
            : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (pinnedMessages != null) {
      data['Records'] = pinnedMessages!.map((v) => v.toJson()).toList();
    }
    if (pagination != null) {
      data['Pagination'] = pagination!.toJson();
    }
    return data;
  }
}

class PinnedMessage {
  int? messageId;
  int? chatId;
  int? senderId;
  String? messageContent;
  String? messageType;
  String? messageSeenStatus;
  String? createdAt;
  String? updatedAt;
  PeerUserData? peerUserData;
  bool? isPinned;

  PinnedMessage({
    this.messageId,
    this.chatId,
    this.senderId,
    this.messageContent,
    this.messageType,
    this.messageSeenStatus,
    this.createdAt,
    this.updatedAt,
    this.peerUserData,
    this.isPinned,
  });

  PinnedMessage.fromJson(Map<String, dynamic> json) {
    messageId = json['message_id'];
    chatId = json['chat_id'];
    senderId = json['sender_id'];
    messageContent = json['message_content'];
    messageType = json['message_type'];
    messageSeenStatus = json['message_seen_status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    peerUserData =
        json['peer_user_data'] != null
            ? PeerUserData.fromJson(json['peer_user_data'])
            : null;
    isPinned = json['is_pinned'] ?? true; // Default to true for pinned messages
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['message_id'] = messageId;
    data['chat_id'] = chatId;
    data['sender_id'] = senderId;
    data['message_content'] = messageContent;
    data['message_type'] = messageType;
    data['message_seen_status'] = messageSeenStatus;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    if (peerUserData != null) {
      data['peer_user_data'] = peerUserData!.toJson();
    }
    data['is_pinned'] = isPinned;
    return data;
  }
}

class PeerUserData {
  int? userId;
  String? firstName;
  String? lastName;
  String? profilePicture;
  String? username;
  String? createdAt;
  String? updatedAt;

  PeerUserData({
    this.userId,
    this.firstName,
    this.lastName,
    this.profilePicture,
    this.username,
    this.createdAt,
    this.updatedAt,
  });

  PeerUserData.fromJson(Map<String, dynamic> json) {
    userId = json['user_id'];
    firstName = json['first_name'];
    lastName = json['last_name'];
    profilePicture = json['profile_picture'];
    username = json['username'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_id'] = userId;
    data['first_name'] = firstName;
    data['last_name'] = lastName;
    data['profile_picture'] = profilePicture;
    data['username'] = username;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    return data;
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

  Pagination.fromJson(Map<String, dynamic> json) {
    totalPages = json['total_pages'];
    totalRecords = json['total_records'];
    currentPage = json['current_page'];
    recordsPerPage = json['records_per_page'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_pages'] = totalPages;
    data['total_records'] = totalRecords;
    data['current_page'] = currentPage;
    data['records_per_page'] = recordsPerPage;
    return data;
  }
}
