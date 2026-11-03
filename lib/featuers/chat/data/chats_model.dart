// ignore_for_file: non_constant_identifier_names

class ChatInfo {
  String? groupIcon;
  int? chatId;
  String? chatType;
  String? groupName;
  String? groupDescription;
  String? deletedAt;
  bool? isGroupBlocked;
  List<dynamic>? archivedFor;
  List<dynamic>? blockedBy;
  List<dynamic>? clearedFor;
  List<dynamic>? deletedFor;
  String? createdAt;
  String? updatedAt;

  ChatInfo({
    this.groupIcon,
    this.chatId,
    this.chatType,
    this.groupName,
    this.groupDescription,
    this.deletedAt,
    this.isGroupBlocked,
    this.archivedFor,
    this.blockedBy,
    this.clearedFor,
    this.deletedFor,
    this.createdAt,
    this.updatedAt,
  });

  ChatInfo.fromJson(Map<String, dynamic> json) {
    groupIcon = json["group_icon"];
    chatId = json["chat_id"];
    chatType = json["chat_type"];
    groupName = json["group_name"];
    groupDescription = json["group_description"];
    deletedAt = json["deleted_at"];
    isGroupBlocked = json["is_group_blocked"];
    archivedFor = json["archived_for"] ?? [];
    blockedBy = json["blocked_by"] ?? [];
    clearedFor = json["cleared_for"] ?? [];
    deletedFor = json["deleted_for"] ?? [];
    createdAt = json["createdAt"];
    updatedAt = json["updatedAt"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["group_icon"] = groupIcon;
    data["chat_id"] = chatId;
    data["chat_type"] = chatType;
    data["group_name"] = groupName;
    data["group_description"] = groupDescription;
    data["deleted_at"] = deletedAt;
    data["is_group_blocked"] = isGroupBlocked;
    data["archived_for"] = archivedFor;
    data["blocked_by"] = blockedBy;
    data["cleared_for"] = clearedFor;
    data["deleted_for"] = deletedFor;
    data["createdAt"] = createdAt;
    data["updatedAt"] = updatedAt;
    return data;
  }
}

class ChatWrapperModel {
  ChatsModel? messageList;
  ChatsModel? pinnedMessages;
  ChatsModel? starredMessages;

  ChatWrapperModel({
    this.messageList,
    this.pinnedMessages,
    this.starredMessages,
  });

  ChatWrapperModel.fromJson(Map<String, dynamic> json) {
    messageList =
        json['message_list'] != null
            ? ChatsModel.fromJson(json['message_list'])
            : null;
    pinnedMessages =
        json['pinned_messages'] != null
            ? ChatsModel.fromJson(json['pinned_messages'])
            : null;
    starredMessages =
        json['starred_messages'] != null
            ? ChatsModel.fromJson(json['starred_messages'])
            : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (messageList != null) data['message_list'] = messageList!.toJson();
    if (pinnedMessages != null) {
      data['pinned_messages'] = pinnedMessages!.toJson();
    }
    if (starredMessages != null) {
      data['starred_messages'] = starredMessages!.toJson();
    }
    return data;
  }
}

class ChatsModel {
  List<Records>? records;
  Pagination? pagination;

  ChatsModel({this.records, this.pagination});

  ChatsModel.fromJson(Map<String, dynamic> json) {
    records =
        json["Records"] == null
            ? null
            : (json["Records"] as List)
                .map((e) => Records.fromJson(e))
                .toList();
    pagination =
        json["Pagination"] == null
            ? null
            : Pagination.fromJson(json["Pagination"]);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (records != null) {
      data["Records"] = records!.map((e) => e.toJson()).toList();
    }
    if (pagination != null) {
      data["Pagination"] = pagination!.toJson();
    }
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
    totalPages = json["total_pages"];
    totalRecords = json["total_records"];
    currentPage = json["current_page"];
    recordsPerPage = json["records_per_page"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["total_pages"] = totalPages;
    data["total_records"] = totalRecords;
    data["current_page"] = currentPage;
    data["records_per_page"] = recordsPerPage;
    return data;
  }
}

/// Enum for local message sending status (optimistic UI)
enum MessageSendingStatus {
  /// Message is being sent (queued or in-flight)
  sending,

  /// Message was sent successfully
  sent,

  /// Message failed to send
  failed,
}

class Records {
  String? messageContent;
  int? replyTo;
  int? socialId;
  int? messageId;
  String? messageType;
  String? messageThumbnail;
  String? messageLength;
  String? messageSize;
  String? createdAt;
  String? updatedAt;
  int? pinLifetime;
  String? pinnedTill;
  int? chatId;
  int? senderId;
  int? storyId;
  String? messageSeenStatus;
  int? unseenCount;
  bool? pinned;
  bool? stared;
  bool? deletedForEveryone;

  /// Set once the sender edits the body (`PATCH /messages/:id`). Drives the
  /// "Edited" label next to the timestamp — `createdAt` stays the sort key.
  bool? isEdited;
  String? editedAt;

  // Updated to handle ParentMessage as a Map instead of List
  Map<String, dynamic>? parentMessage;
  List<dynamic>? replies;
  List<dynamic>? deletedFor;
  List<dynamic>? starredFor;

  User? user;
  Story? story;
  User? actionedUser;
  Social? social;
  PeerUserData? peerUserData;
  bool? isFollowing;
  List<CallData>? calls;
  ChatInfo? chat; // Chat object for group creation responses
  String? voiceDuration;

  // ✅ NEW: Local-only fields for optimistic UI (not from API)
  /// Temporary ID for optimistic UI (UUID generated locally)
  String? tempId;

  /// Local sending status for optimistic UI
  MessageSendingStatus? sendingStatus;

  /// Number of retry attempts
  int retryCount = 0;
  PollData? pollData;

  /// For `messageType == 'poll'`: the poll's own id, taken from the
  /// message's embedded `poll` relation (or `metadata.pollId` on older
  /// payloads) — kept here so [pollData] can be refreshed or resolved
  /// via `GET /polls/:pollId` regardless of which path (REST page,
  /// socket, cache) produced this record.
  String? pollId;

  Records({
    this.messageContent,
    this.replyTo,
    this.socialId,
    this.messageId,
    this.messageType,
    this.messageThumbnail,
    this.messageLength,
    this.messageSize,
    this.createdAt,
    this.updatedAt,
    this.chatId,
    this.senderId,
    this.storyId,
    this.messageSeenStatus,
    this.unseenCount,
    this.pinned,
    this.stared,
    this.pinLifetime,
    this.pinnedTill,
    this.deletedForEveryone,
    this.isEdited,
    this.editedAt,
    this.parentMessage,
    this.replies,
    this.deletedFor,
    this.starredFor,
    this.user,
    this.story,
    this.actionedUser,
    this.social,
    this.peerUserData,
    this.isFollowing = true,
    this.calls,
    this.chat,
    this.voiceDuration,
    // ✅ NEW: Optimistic UI fields
    this.tempId,
    this.sendingStatus,
    this.retryCount = 0,
    this.pollData,
    this.pollId,
  });

  Records.fromJson(Map<String, dynamic> json) {
    messageContent = json["message_content"];
    replyTo = json["reply_to"];
    socialId = json["social_id"];
    messageId = json["message_id"];
    messageType = json["message_type"];
    messageThumbnail = json["message_thumbnail"];
    messageLength = json["message_length"];
    messageSize = json["message_size"];
    createdAt = json["createdAt"];
    updatedAt = json["updatedAt"];
    chatId = json["chat_id"];
    senderId = json["sender_id"];
    storyId = json['story_id'];
    messageSeenStatus = json["message_seen_status"];
    unseenCount = json["unseen_count"];
    pinned = json["pinned"];
    stared = json["starred"];
    pinLifetime = json["pin_lifetime"];
    pinnedTill = json["pinned_till"];
    deletedForEveryone = json["deleted_for_everyone"];
    isEdited = json["is_edited"];
    editedAt = json["edited_at"];

    // Handle ParentMessage as Map or null
    parentMessage =
        json["ParentMessage"] is Map<String, dynamic>
            ? json["ParentMessage"]
            : null;

    replies = json["Replies"] ?? [];
    deletedFor = json["deleted_for"] ?? [];
    starredFor = json["starred_for"] ?? [];
    user = json["User"] == null ? null : User.fromJson(json["User"]);
    story = json['Story'] == null ? null : Story.fromJson(json['Story']);
    actionedUser =
        json["ActionedUser"] == null
            ? null
            : User.fromJson(json["ActionedUser"]);
    social = json["Social"] == null ? null : Social.fromJson(json["Social"]);
    peerUserData =
        json["peerUserData"] == null
            ? null
            : PeerUserData.fromJson(json["peerUserData"]);

    // Parse Calls array
    if (json["Calls"] != null) {
      calls = <CallData>[];
      json["Calls"].forEach((v) {
        calls!.add(CallData.fromJson(v));
      });
    }

    // Parse Chat object for group creation responses
    chat = json["Chat"] == null ? null : ChatInfo.fromJson(json["Chat"]);
    voiceDuration = json['voice_duration'];

    // ✅ NEW: Handle local optimistic UI fields (optional in JSON)
    tempId = json['temp_id'];
    retryCount = json['retry_count'] ?? 0;
    // Parse sendingStatus from string if present
    if (json['sending_status'] != null) {
      sendingStatus = MessageSendingStatus.values.firstWhere(
        (e) => e.name == json['sending_status'],
        orElse: () => MessageSendingStatus.sent,
      );
    }
    pollData =
        json['poll_data'] != null
            ? PollData.fromJson(json['poll_data'])
            : json['pollData'] != null
            ? PollData.fromJson(json['pollData'])
            : null;
    pollId = json['poll_id']?.toString() ?? json['pollId']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["message_content"] = messageContent;
    data["reply_to"] = replyTo;
    data["social_id"] = socialId;
    data["message_id"] = messageId;
    data["message_type"] = messageType;
    data["message_thumbnail"] = messageThumbnail;
    data["message_length"] = messageLength;
    data["message_size"] = messageSize;
    data["createdAt"] = createdAt;
    data["updatedAt"] = updatedAt;
    data["chat_id"] = chatId;
    data["sender_id"] = senderId;
    data['story_id'] = storyId;
    data["message_seen_status"] = messageSeenStatus;
    data["unseen_count"] = unseenCount;
    data["pinned"] = pinned;
    data["starred"] = stared;
    data["pin_lifetime"] = pinLifetime;
    data["pinned_till"] = pinnedTill;
    data["deleted_for_everyone"] = deletedForEveryone;
    if (isEdited != null) data["is_edited"] = isEdited;
    if (editedAt != null) data["edited_at"] = editedAt;
    data["ParentMessage"] = parentMessage;
    data["Replies"] = replies;
    data["deleted_for"] = deletedFor;
    data["starred_for"] = starredFor;
    data["voice_duration"] = voiceDuration;
    if (pollData != null) data['poll_data'] = pollData!.toJson();
    if (pollId != null) data['poll_id'] = pollId;
    if (user != null) data["User"] = user!.toJson();
    if (story != null) data["Story"] = story!.toJson();
    if (actionedUser != null) data["ActionedUser"] = actionedUser!.toJson();
    if (social != null) data["Social"] = social!.toJson();
    if (peerUserData != null) data["peerUserData"] = peerUserData!.toJson();
    if (calls != null) {
      data["Calls"] = calls!.map((v) => v.toJson()).toList();
    }
    if (chat != null) {
      data["Chat"] = chat!.toJson();
    }
    // ✅ NEW: Include optimistic UI fields for local cache
    if (tempId != null) data['temp_id'] = tempId;
    if (sendingStatus != null) data['sending_status'] = sendingStatus!.name;
    data['retry_count'] = retryCount;
    return data;
  }

  /// ✅ NEW: Check if this is an optimistic message (not yet confirmed by server)
  bool get isOptimistic => tempId != null && messageId == null;

  /// ✅ NEW: Check if this message failed to send
  bool get isFailed => sendingStatus == MessageSendingStatus.failed;

  /// ✅ NEW: Check if this message is currently being sent
  bool get isSending => sendingStatus == MessageSendingStatus.sending;
}

class PollData {
  int? pollId;
  String? question;
  List<Option>? options;
  bool? allowMultipleVotes;
  CreatedBy? createdBy;
  int? totalVotes;
  List<String>? userVotes;

  PollData({
    this.pollId,
    this.question,
    this.options,
    this.allowMultipleVotes,
    this.createdBy,
    this.totalVotes,
    this.userVotes,
  });

  String? get userVote =>
      userVotes?.isNotEmpty == true ? userVotes!.first : null;

  // ✅ Check if user voted for a specific option
  bool hasUserVotedFor(String optionText) =>
      userVote?.contains(optionText) ?? false;

  PollData.fromJson(Map<String, dynamic> json) {
    pollId = json["poll_id"];
    question = json["question"];
    options =
        json["options"] == null
            ? null
            : (json["options"] as List).map((e) => Option.fromJson(e)).toList();
    allowMultipleVotes = json["allow_multiple_votes"];
    createdBy =
        json["created_by"] == null
            ? null
            : CreatedBy.fromJson(json["created_by"]);
    totalVotes = json["total_votes"];
    // userVote = json["user_vote"];
    final rawUserVote = json["user_vote"];
    if (rawUserVote == null) {
      userVotes = [];
    } else if (rawUserVote is String) {
      // ✅ Single vote as string — wrap in list
      userVotes = rawUserVote.isNotEmpty ? [rawUserVote] : [];
    } else if (rawUserVote is List) {
      // ✅ Multiple votes as list
      userVotes =
          rawUserVote
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
    } else {
      userVotes = [];
    }
  }

  /// Maps NEW's `/conversations/:id/polls` (create), `/polls/:id` (get) and
  /// the `poll_updated` socket broadcast — `{ pollId, question, pollType,
  /// isClosed, options: [{ optionId, optionText, voteCount, voters?:
  /// [userIdStr], viewerVoted? }] }` — onto this OLD-shaped model so the
  /// existing poll widget renders unchanged. `voters` is only present when
  /// results are visible and the poll isn't anonymous. The viewer-aware
  /// REST responses carry an explicit per-option `viewerVoted`; the
  /// viewer-neutral `poll_updated` broadcast (`toBroadcastPoll`) never does,
  /// so for that payload the voter's own "has voted" state is instead
  /// recovered from `currentUserId` appearing in `voters` — this keeps a
  /// live vote-count push from a *different* participant from clearing the
  /// current user's own vote highlighting.
  factory PollData.fromNewApi(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final rawOptions =
        (json['options'] as List?)?.whereType<Map>().toList() ?? const [];

    final mappedOptions =
        rawOptions.map((raw) {
          final m = raw.cast<String, dynamic>();
          final voters =
              (m['voters'] as List?)
                  ?.map((e) => Votes(userId: int.tryParse(e.toString())))
                  .toList() ??
              <Votes>[];
          final viewerVoted =
              m['viewerVoted'] == true ||
              (currentUserId != null &&
                  currentUserId.isNotEmpty &&
                  voters.any((v) => v.userId?.toString() == currentUserId));
          if (viewerVoted &&
              currentUserId != null &&
              currentUserId.isNotEmpty &&
              !voters.any((v) => v.userId?.toString() == currentUserId)) {
            voters.add(
              Votes(
                userId: int.tryParse(currentUserId),
                fullName: 'You',
                userName: '',
                profilePic: '',
              ),
            );
          }
          final vc = m['voteCount'];
          return Option(
            option: m['optionText']?.toString() ?? '',
            optionId: m['optionId']?.toString(),
            votes:
                voters.isNotEmpty
                    ? voters
                    // results hidden: keep count-only placeholders so the
                    // tally still shows even without per-voter identity
                    : (vc is int
                        ? List.generate(vc, (_) => Votes())
                        : <Votes>[]),
          );
        }).toList();

    final userVotes = <String>[];
    for (final raw in rawOptions) {
      final m = raw.cast<String, dynamic>();
      final voters = (m['voters'] as List?) ?? const [];
      final viewerVoted =
          m['viewerVoted'] == true ||
          (currentUserId != null &&
              currentUserId.isNotEmpty &&
              voters.any((e) => e.toString() == currentUserId));
      if (viewerVoted) {
        userVotes.add(m['optionText']?.toString() ?? '');
      }
    }

    final total = mappedOptions.fold<int>(
      0,
      (sum, o) => sum + (o.votes?.length ?? 0),
    );

    return PollData(
      pollId: int.tryParse(json['pollId']?.toString() ?? ''),
      question: json['question']?.toString(),
      options: mappedOptions,
      allowMultipleVotes: json['pollType']?.toString() == 'multiple_choice',
      totalVotes: total,
      userVotes: userVotes,
    );
  }

  static List<PollData> fromList(List<Map<String, dynamic>> list) {
    return list.map(PollData.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["poll_id"] = pollId;
    data["question"] = question;
    if (options != null) {
      data["options"] = options?.map((e) => e.toJson()).toList();
    }
    data["allow_multiple_votes"] = allowMultipleVotes;
    if (createdBy != null) {
      data["created_by"] = createdBy?.toJson();
    }
    data["total_votes"] = totalVotes;
    if (userVotes == null || userVotes!.isEmpty) {
      data["user_vote"] = null;
    } else if (userVotes!.length == 1) {
      data["user_vote"] = userVotes!.first;
    } else {
      data["user_vote"] = userVotes;
    }
    return data;
  }
}

class CreatedBy {
  int? userId;
  String? fullName;
  String? userName;
  String? profilePic;

  CreatedBy({this.userId, this.fullName, this.userName, this.profilePic});

  CreatedBy.fromJson(Map<String, dynamic> json) {
    userId = json["user_id"];
    fullName = json["full_name"];
    userName = json["user_name"];
    profilePic = json["profile_pic"];
  }

  static List<CreatedBy> fromList(List<Map<String, dynamic>> list) {
    return list.map(CreatedBy.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["user_id"] = userId;
    data["full_name"] = fullName;
    data["user_name"] = userName;
    data["profile_pic"] = profilePic;
    return data;
  }
}

class Option {
  String? option;

  /// NEW's server-assigned opaque option id (`optionId` from
  /// `/polls/:id`). Required as the vote payload — the positional index is
  /// only a fallback. Null for legacy/cached polls created before this.
  String? optionId;
  List<Votes>? votes;

  Option({this.option, this.optionId, this.votes});

  Option.fromJson(Map<String, dynamic> json) {
    option = json['option'];
    optionId = json['option_id']?.toString();
    if (json['votes'] != null) {
      votes = <Votes>[];
      json['votes'].forEach((v) {
        votes!.add(Votes.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['option'] = option;
    data['option_id'] = optionId;
    if (votes != null) {
      data['votes'] = votes!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Votes {
  int? userId;
  String? fullName;
  String? userName;
  String? profilePic;

  Votes({this.userId, this.fullName, this.userName, this.profilePic});

  Votes.fromJson(Map<String, dynamic> json) {
    userId = json['user_id'];
    fullName = json['full_name'];
    userName = json['user_name'];
    profilePic = json['profile_pic'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_id'] = userId;
    data['full_name'] = fullName;
    data['user_name'] = userName;
    data['profile_pic'] = profilePic;
    return data;
  }
}

class Social {
  String? reelThumbnail;
  int? socialId;
  String? socialDesc;
  String? socialType;
  String? aspectRatio;
  String? videoHight;
  String? location;
  int? totalViews;
  int? totalSaves;
  int? totalShares;
  int? totalLikes;
  int? totalComments;
  String? country;
  String? createdAt;
  String? updatedAt;
  int? userId;
  List<Media>? media;
  User? user;
  bool? isSaved;
  bool? isLiked;

  Social({
    this.reelThumbnail,
    this.socialId,
    this.socialDesc,
    this.socialType,
    this.aspectRatio,
    this.videoHight,
    this.location,
    this.totalViews,
    this.totalSaves,
    this.totalShares,
    this.totalLikes,
    this.totalComments,
    this.country,
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.media,
    this.user,
    this.isLiked,
    this.isSaved,
  });

  Social.fromJson(Map<String, dynamic> json) {
    reelThumbnail = json["reel_thumbnail"];
    socialId = json["social_id"];
    socialDesc = json["social_desc"];
    socialType = json["social_type"];
    aspectRatio = json["aspect_ratio"];
    videoHight = json["video_hight"];
    location = json["location"];
    totalViews = json["total_views"];
    totalSaves = json["total_saves"];
    totalShares = json["total_shares"];
    totalLikes = json["total_likes"];
    totalComments = json["total_comments"];
    country = json["country"];
    createdAt = json["createdAt"];
    updatedAt = json["updatedAt"];
    userId = json["user_id"];
    media =
        json["Media"] == null
            ? null
            : (json["Media"] as List).map((e) => Media.fromJson(e)).toList();
    user = json["User"] == null ? null : User.fromJson(json["User"]);
    isLiked = json["isLiked"];
    isSaved = json["isSaved"];
  }

  static List<Social> fromList(List<Map<String, dynamic>> list) {
    return list.map(Social.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["reel_thumbnail"] = reelThumbnail;
    data["social_id"] = socialId;
    data["social_desc"] = socialDesc;
    data["social_type"] = socialType;
    data["aspect_ratio"] = aspectRatio;
    data["video_hight"] = videoHight;
    data["location"] = location;
    data["total_views"] = totalViews;
    data["total_saves"] = totalSaves;
    data["total_shares"] = totalShares;
    data["total_likes"] = totalLikes;
    data["total_comments"] = totalComments;
    data["country"] = country;
    data["createdAt"] = createdAt;
    data["updatedAt"] = updatedAt;
    data["user_id"] = userId;
    if (media != null) {
      data["Media"] = media?.map((e) => e.toJson()).toList();
    }
    if (user != null) {
      data["User"] = user?.toJson();
    }
    data["isLiked"] = isLiked;
    data["isSaved"] = isSaved;
    return data;
  }
}

class Media {
  int? socialId;
  String? mediaLocation;
  int? mediaId;
  String? createdAt;
  String? updatedAt;

  Media({
    this.socialId,
    this.mediaLocation,
    this.mediaId,
    this.createdAt,
    this.updatedAt,
  });

  Media.fromJson(Map<String, dynamic> json) {
    socialId = json["social_id"];
    mediaLocation = json["media_location"];
    mediaId = json["media_id"];
    createdAt = json["createdAt"];
    updatedAt = json["updatedAt"];
  }

  static List<Media> fromList(List<Map<String, dynamic>> list) {
    return list.map(Media.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["social_id"] = socialId;
    data["media_location"] = mediaLocation;
    data["media_id"] = mediaId;
    data["createdAt"] = createdAt;
    data["updatedAt"] = updatedAt;
    return data;
  }
}

class PeerUserData {
  String? mobileNum;
  String? profilePic;
  String? dob;
  int? userId;
  String? fullName;
  String? firstName;
  String? lastName;
  String? userName;
  String? email;
  String? countryCode;
  String? socketId;
  String? loginType;
  int? socialId;
  String? gender;
  String? country;
  String? state;
  String? city;
  String? bio;
  bool? profileVerificationStatus;
  bool? loginVerificationStatus;
  bool? isPrivate;
  bool? isAdmin;
  String? createdAt;
  String? updatedAt;

  PeerUserData({
    this.mobileNum,
    this.profilePic,
    this.dob,
    this.userId,
    this.fullName,
    this.firstName,
    this.lastName,
    this.userName,
    this.email,
    this.countryCode,
    this.socketId,
    this.loginType,
    this.socialId,
    this.gender,
    this.country,
    this.state,
    this.city,
    this.bio,
    this.profileVerificationStatus,
    this.loginVerificationStatus,
    this.isPrivate,
    this.isAdmin,
    this.createdAt,
    this.updatedAt,
  });

  PeerUserData.fromJson(Map<String, dynamic> json) {
    mobileNum = json["mobile_num"];
    profilePic = json["profile_pic"];
    dob = json["dob"];
    userId = json["user_id"];
    fullName = json["full_name"];
    firstName = json["first_name"];
    lastName = json["last_name"];
    userName = json["user_name"];
    email = json["email"];
    countryCode = json["country_code"];
    socketId = json["socket_id"];
    loginType = json["login_type"];
    socialId = json["social_id"];
    gender = json["gender"];
    country = json["country"];
    state = json["state"];
    city = json["city"];
    bio = json["bio"];
    profileVerificationStatus = json["profile_verification_status"];
    loginVerificationStatus = json["login_verification_status"];
    isPrivate = json["is_private"];
    isAdmin = json["is_admin"];
    createdAt = json["createdAt"];
    updatedAt = json["updatedAt"];
  }

  static List<PeerUserData> fromList(List<Map<String, dynamic>> list) {
    return list.map(PeerUserData.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["mobile_num"] = mobileNum;
    data["profile_pic"] = profilePic;
    data["dob"] = dob;
    data["user_id"] = userId;
    data["full_name"] = fullName;
    data["first_name"] = firstName;
    data["last_name"] = lastName;
    data["user_name"] = userName;
    data["email"] = email;
    data["country_code"] = countryCode;
    data["socket_id"] = socketId;
    data["login_type"] = loginType;
    data["social_id"] = socialId;
    data["gender"] = gender;
    data["country"] = country;
    data["state"] = state;
    data["city"] = city;
    data["bio"] = bio;
    data["profile_verification_status"] = profileVerificationStatus;
    data["login_verification_status"] = loginVerificationStatus;
    data["is_private"] = isPrivate;
    data["is_admin"] = isAdmin;
    data["createdAt"] = createdAt;
    data["updatedAt"] = updatedAt;
    return data;
  }
}

class User {
  String? profilePic;
  int? userId;
  String? fullName;
  String? userName;
  String? email;
  String? countryCode;
  String? country;
  String? gender;
  String? bio;
  bool? profileVerificationStatus;
  bool? loginVerificationStatus;
  String? socketId;
  String? createdAt;
  String? updatedAt;
  // Added socket_ids as List to match JSON structure
  List<String>? socketIds;
  String? userType;

  User({
    this.profilePic,
    this.userId,
    this.fullName,
    this.userName,
    this.email,
    this.countryCode,
    this.country,
    this.gender,
    this.bio,
    this.profileVerificationStatus,
    this.loginVerificationStatus,
    this.socketId,
    this.createdAt,
    this.updatedAt,
    this.socketIds,
    this.userType,
  });

  User.fromJson(Map<String, dynamic> json) {
    profilePic = json["profile_pic"];
    userId = json["user_id"];
    fullName = json["full_name"];
    userName = json["user_name"];
    email = json["email"];
    countryCode = json["country_code"];
    country = json["country"];
    gender = json["gender"];
    bio = json["bio"];
    profileVerificationStatus = json["profile_verification_status"];
    loginVerificationStatus = json["login_verification_status"];
    socketId = json["socket_id"];
    createdAt = json["createdAt"];
    updatedAt = json["updatedAt"];
    socketIds =
        json["socket_ids"] != null
            ? List<String>.from(json["socket_ids"])
            : null;
    userType = json["user_type"];
  }

  static List<User> fromList(List<Map<String, dynamic>> list) {
    return list.map(User.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["profile_pic"] = profilePic;
    data["user_id"] = userId;
    data["full_name"] = fullName;
    data["user_name"] = userName;
    data["email"] = email;
    data["country_code"] = countryCode;
    data["country"] = country;
    data["gender"] = gender;
    data["bio"] = bio;
    data["profile_verification_status"] = profileVerificationStatus;
    data["login_verification_status"] = loginVerificationStatus;
    data["socket_id"] = socketId;
    data["createdAt"] = createdAt;
    data["updatedAt"] = updatedAt;
    data["socket_ids"] = socketIds;
    data["user_type"] = userType;
    return data;
  }
}

class Story {
  String? media;
  String? thumbnail;
  int? storyId;
  String? caption;
  String? storyType;
  String? expiresAt;
  List<String>? views;
  bool? isExpired;
  String? createdAt;
  String? updatedAt;
  int? userId;
  StoryUser? user;

  Story({
    this.media,
    this.thumbnail,
    this.storyId,
    this.caption,
    this.storyType,
    this.expiresAt,
    this.views,
    this.isExpired,
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.user,
  });

  Story.fromJson(Map<String, dynamic> json) {
    media = json['media'];
    thumbnail = json['thumbnail'];
    storyId = json['story_id'];
    caption = json['caption'];
    storyType = json['story_type'];
    expiresAt = json['expiresAt'];
    views = json['views'].cast<String>();
    isExpired = json['is_expired'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    userId = json['user_id'];
    user = json['user'] != null ? StoryUser.fromJson(json['user']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['media'] = media;
    data['thumbnail'] = thumbnail;
    data['story_id'] = storyId;
    data['caption'] = caption;
    data['story_type'] = storyType;
    data['expiresAt'] = expiresAt;
    data['views'] = views;
    data['is_expired'] = isExpired;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['user_id'] = userId;
    if (user != null) {
      data['user'] = user!.toJson();
    }
    return data;
  }
}

class StoryUser {
  String? userName;
  String? email;
  String? profilePic;
  int? userId;
  String? fullName;
  String? countryCode;
  String? country;
  String? gender;
  String? bio;
  bool? profileVerificationStatus;
  bool? loginVerificationStatus;
  List<String>? socketIds;

  StoryUser({
    this.userName,
    this.email,
    this.profilePic,
    this.userId,
    this.fullName,
    this.countryCode,
    this.country,
    this.gender,
    this.bio,
    this.profileVerificationStatus,
    this.loginVerificationStatus,
    this.socketIds,
  });

  StoryUser.fromJson(Map<String, dynamic> json) {
    userName = json['user_name'];
    email = json['email'];
    profilePic = json['profile_pic'];
    userId = json['user_id'];
    fullName = json['full_name'];
    countryCode = json['country_code'];
    country = json['country'];
    gender = json['gender'];
    bio = json['bio'];
    profileVerificationStatus = json['profile_verification_status'];
    loginVerificationStatus = json['login_verification_status'];
    socketIds = json['socket_ids'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_name'] = userName;
    data['email'] = email;
    data['profile_pic'] = profilePic;
    data['user_id'] = userId;
    data['full_name'] = fullName;
    data['country_code'] = countryCode;
    data['country'] = country;
    data['gender'] = gender;
    data['bio'] = bio;
    data['profile_verification_status'] = profileVerificationStatus;
    data['login_verification_status'] = loginVerificationStatus;
    data['socket_ids'] = socketIds;
    return data;
  }
}

class CallData {
  int? callId;
  String? callType;
  String? callStatus;
  int? callDuration;
  String? startTime;
  String? endTime;
  List<int>? users;
  List<int>? currentUsers;
  String? roomId;
  String? createdAt;
  String? updatedAt;
  int? messageId;
  int? chatId;
  int? userId;
  CallerData? caller;

  CallData({
    this.callId,
    this.callType,
    this.callStatus,
    this.callDuration,
    this.startTime,
    this.endTime,
    this.users,
    this.currentUsers,
    this.roomId,
    this.createdAt,
    this.updatedAt,
    this.messageId,
    this.chatId,
    this.userId,
    this.caller,
  });

  CallData.fromJson(Map<String, dynamic> json) {
    // Safely parse integer fields to handle both string and int types
    callId =
        json['call_id'] is int
            ? json['call_id']
            : (json['call_id'] != null
                ? int.tryParse(json['call_id'].toString())
                : null);
    callType = json['call_type'];
    callStatus = json['call_status'];
    callDuration =
        json['call_duration'] is int
            ? json['call_duration']
            : (json['call_duration'] != null
                ? int.tryParse(json['call_duration'].toString())
                : null);
    startTime = json['start_time'];
    endTime = json['end_time'];

    // Safely handle users array - it might contain strings instead of ints
    if (json['users'] != null) {
      users =
          (json['users'] as List).map((user) {
            if (user is int) {
              return user;
            } else {
              return int.tryParse(user.toString()) ?? 0;
            }
          }).toList();
    }

    // Safely handle current_users array
    if (json['current_users'] != null) {
      currentUsers =
          (json['current_users'] as List).map((user) {
            if (user is int) {
              return user;
            } else {
              return int.tryParse(user.toString()) ?? 0;
            }
          }).toList();
    }

    roomId = json['room_id'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    messageId =
        json['message_id'] is int
            ? json['message_id']
            : (json['message_id'] != null
                ? int.tryParse(json['message_id'].toString())
                : null);
    chatId =
        json['chat_id'] is int
            ? json['chat_id']
            : (json['chat_id'] != null
                ? int.tryParse(json['chat_id'].toString())
                : null);
    userId =
        json['user_id'] is int
            ? json['user_id']
            : (json['user_id'] != null
                ? int.tryParse(json['user_id'].toString())
                : null);
    caller =
        json['caller'] != null ? CallerData.fromJson(json['caller']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['call_id'] = callId;
    data['call_type'] = callType;
    data['call_status'] = callStatus;
    data['call_duration'] = callDuration;
    data['start_time'] = startTime;
    data['end_time'] = endTime;
    data['users'] = users;
    data['current_users'] = currentUsers;
    data['room_id'] = roomId;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['message_id'] = messageId;
    data['chat_id'] = chatId;
    data['user_id'] = userId;
    if (caller != null) data['caller'] = caller!.toJson();
    return data;
  }
}

class CallerData {
  String? userName;
  String? email;
  String? profilePic;
  int? userId;
  String? fullName;
  String? countryCode;
  String? country;
  String? gender;

  CallerData({
    this.userName,
    this.email,
    this.profilePic,
    this.userId,
    this.fullName,
    this.countryCode,
    this.country,
    this.gender,
  });

  CallerData.fromJson(Map<String, dynamic> json) {
    userName = json['user_name'];
    email = json['email'];
    profilePic = json['profile_pic'];
    // Safely parse user_id to handle both string and int types
    userId =
        json['user_id'] is int
            ? json['user_id']
            : (json['user_id'] != null
                ? int.tryParse(json['user_id'].toString())
                : null);
    fullName = json['full_name'];
    countryCode = json['country_code'];
    country = json['country'];
    gender = json['gender'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_name'] = userName;
    data['email'] = email;
    data['profile_pic'] = profilePic;
    data['user_id'] = userId;
    data['full_name'] = fullName;
    data['country_code'] = countryCode;
    data['country'] = country;
    data['gender'] = gender;
    return data;
  }
}

extension RecordsCopyWith on Records {
  Records copyWith({
    String? messageContent,
    int? replyTo,
    int? socialId,
    int? messageId,
    String? messageType,
    String? messageLength,
    String? messageSeenStatus,
    String? messageSize,
    List<dynamic>? deletedFor,
    List<dynamic>? starredFor,
    bool? deletedForEveryone,
    bool? pinned,
    String? createdAt,
    String? updatedAt,
    int? chatId,
    int? senderId,
    Map<String, dynamic>? parentMessage,
    List<dynamic>? replies,
    User? user,
    PeerUserData? peerUserData,
    List<CallData>? calls,
    // ✅ NEW: Optimistic UI fields
    String? tempId,
    MessageSendingStatus? sendingStatus,
    int? retryCount,
  }) {
    return Records(
      messageContent: messageContent ?? this.messageContent,
      replyTo: replyTo ?? this.replyTo,
      socialId: socialId ?? this.socialId,
      messageId: messageId ?? this.messageId,
      messageType: messageType ?? this.messageType,
      messageLength: messageLength ?? this.messageLength,
      messageSeenStatus: messageSeenStatus ?? this.messageSeenStatus,
      messageSize: messageSize ?? this.messageSize,
      deletedFor: deletedFor ?? this.deletedFor,
      starredFor: starredFor ?? this.starredFor,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      parentMessage: parentMessage ?? this.parentMessage,
      replies: replies ?? this.replies,
      user: user ?? this.user,
      peerUserData: peerUserData ?? this.peerUserData,
      calls: calls ?? this.calls,
      // ✅ NEW: Optimistic UI fields
      tempId: tempId ?? this.tempId,
      sendingStatus: sendingStatus ?? this.sendingStatus,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
