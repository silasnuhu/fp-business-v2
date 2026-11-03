// ignore_for_file: non_constant_identifier_names

import 'package:whoxa/featuers/chat/data/chats_model.dart';

class StarredMessagesResponse {
  bool? status;
  StarredMessagesData? data;
  String? message;
  int? toast;

  StarredMessagesResponse({this.status, this.data, this.message, this.toast});

  StarredMessagesResponse.fromJson(Map<String, dynamic> json) {
    status = json["status"];
    data =
        json["data"] != null
            ? StarredMessagesData.fromJson(json["data"])
            : null;
    message = json["message"];
    toast = json["toast"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["status"] = status;
    if (this.data != null) data["data"] = this.data!.toJson();
    data["message"] = message;
    data["toast"] = toast;
    return data;
  }
}

class StarredMessagesData {
  List<StarredMessageRecord>? records;
  Pagination? pagination;

  StarredMessagesData({this.records, this.pagination});

  StarredMessagesData.fromJson(Map<String, dynamic> json) {
    records =
        json["Records"] == null
            ? null
            : (json["Records"] as List)
                .map((e) => StarredMessageRecord.fromJson(e))
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

class StarredMessageRecord {
  String? messageContent;
  String? messageThumbnail;
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
  int? pinLifetime;
  PeerUser? peerUser;
  String? pinnedTill;
  int? forwardedFrom;
  String? createdAt;
  String? updatedAt;
  int? chatId;
  int? senderId;
  User? user;
  StarredMessageChat? chat;
  String? voiceDuration;
  PollData? pollData;

  StarredMessageRecord({
    this.messageContent,
    this.messageThumbnail,
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
    this.pinLifetime,
    this.peerUser,
    this.pinnedTill,
    this.forwardedFrom,
    this.createdAt,
    this.updatedAt,
    this.chatId,
    this.senderId,
    this.user,
    this.chat,
    this.voiceDuration,
    this.pollData,
  });

  StarredMessageRecord.fromJson(Map<String, dynamic> json) {
    messageContent = json["message_content"];
    messageThumbnail = json["message_thumbnail"];
    replyTo = json["reply_to"];
    socialId = json["social_id"];
    messageId = json["message_id"];
    messageType = json["message_type"];
    messageLength = json["message_length"];
    messageSeenStatus = json["message_seen_status"];
    messageSize = json["message_size"];
    deletedFor = json["deleted_for"] ?? [];
    starredFor = json["starred_for"] ?? [];
    deletedForEveryone = json["deleted_for_everyone"];
    pinned = json["pinned"];
    pinLifetime = json["pin_lifetime"];
    peerUser =
        json["peer_user"] != null ? PeerUser.fromJson(json["peer_user"]) : null;
    pinnedTill = json["pinned_till"];
    forwardedFrom = json["forwarded_from"];
    createdAt = json["createdAt"];
    updatedAt = json["updatedAt"];
    chatId = json["chat_id"];
    senderId = json["sender_id"];
    user = json["User"] != null ? User.fromJson(json["User"]) : null;
    chat =
        json["Chat"] != null ? StarredMessageChat.fromJson(json["Chat"]) : null;
    voiceDuration = json['voice_duration'];
    pollData =
        json['poll_data'] != null
            ? PollData.fromJson(json['poll_data'])
            : json['pollData'] != null
            ? PollData.fromJson(json['pollData'])
            : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["message_content"] = messageContent;
    data["message_thumbnail"] = messageThumbnail;
    data["reply_to"] = replyTo;
    data["social_id"] = socialId;
    data["message_id"] = messageId;
    data["message_type"] = messageType;
    data["message_length"] = messageLength;
    data["message_seen_status"] = messageSeenStatus;
    data["message_size"] = messageSize;
    data["deleted_for"] = deletedFor;
    data["starred_for"] = starredFor;
    data["deleted_for_everyone"] = deletedForEveryone;
    data["pinned"] = pinned;
    data["pin_lifetime"] = pinLifetime;
    if (peerUser != null) data["peer_user"] = peerUser!.toJson();
    data["pinned_till"] = pinnedTill;
    data["forwarded_from"] = forwardedFrom;
    data["createdAt"] = createdAt;
    data["updatedAt"] = updatedAt;
    data["chat_id"] = chatId;
    data["sender_id"] = senderId;
    if (user != null) data["User"] = user!.toJson();
    if (chat != null) data["Chat"] = chat!.toJson();
    data['voice_duration'] = voiceDuration;
    if (pollData != null) data['poll_data'] = pollData!.toJson();
    return data;
  }
}

class PollData {
  int? pollId;
  String? question;
  List<Option>? options;
  bool? allowMultipleVotes;
  CreatedBy? createdBy;
  int? totalVotes;
  String? userVote;

  PollData({
    this.pollId,
    this.question,
    this.options,
    this.allowMultipleVotes,
    this.createdBy,
    this.totalVotes,
    this.userVote,
  });

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
    userVote = json["user_vote"];
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
    data["user_vote"] = userVote;
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
  List<Votes>? votes;

  Option({this.option, this.votes});

  Option.fromJson(Map<String, dynamic> json) {
    option = json['option'];
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

class PeerUser {
  String? userName;
  String? email;
  String? mobileNum;
  String? profilePic;
  String? dob;
  int? userId;
  String? firstName;
  String? lastName;
  String? fullName;
  String? countryCode;
  List<dynamic>? socketIds;
  String? loginType;
  String? gender;
  String? country;
  String? countryShortName;
  String? state;
  String? city;
  String? bio;
  bool? profileVerificationStatus;
  bool? loginVerificationStatus;
  bool? isPrivate;
  bool? isAdmin;
  String? deletedAt;
  bool? blockedByAdmin;
  String? createdAt;
  String? updatedAt;
  String? userType;

  PeerUser({
    this.userName,
    this.email,
    this.mobileNum,
    this.profilePic,
    this.dob,
    this.userId,
    this.firstName,
    this.lastName,
    this.fullName,
    this.countryCode,
    this.socketIds,
    this.loginType,
    this.gender,
    this.country,
    this.countryShortName,
    this.state,
    this.city,
    this.bio,
    this.profileVerificationStatus,
    this.loginVerificationStatus,
    this.isPrivate,
    this.isAdmin,
    this.deletedAt,
    this.blockedByAdmin,
    this.createdAt,
    this.updatedAt,
    this.userType,
  });

  PeerUser.fromJson(Map<String, dynamic> json) {
    userName = json["user_name"];
    email = json["email"];
    mobileNum = json["mobile_num"];
    profilePic = json["profile_pic"];
    dob = json["dob"];
    userId = json["user_id"];
    firstName = json["first_name"];
    lastName = json["last_name"];
    fullName = json["full_name"];
    countryCode = json["country_code"];
    socketIds = json["socket_ids"];
    loginType = json["login_type"];
    gender = json["gender"];
    country = json["country"];
    countryShortName = json["country_short_name"];
    state = json["state"];
    city = json["city"];
    bio = json["bio"];
    profileVerificationStatus = json["profile_verification_status"];
    loginVerificationStatus = json["login_verification_status"];
    isPrivate = json["is_private"];
    isAdmin = json["is_admin"];
    deletedAt = json["deleted_at"];
    blockedByAdmin = json["bloked_by_admin"];
    createdAt = json["createdAt"];
    updatedAt = json["updatedAt"];
    userType = json["user_type"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["user_name"] = userName;
    data["email"] = email;
    data["mobile_num"] = mobileNum;
    data["profile_pic"] = profilePic;
    data["dob"] = dob;
    data["user_id"] = userId;
    data["first_name"] = firstName;
    data["last_name"] = lastName;
    data["full_name"] = fullName;
    data["country_code"] = countryCode;
    data["socket_ids"] = socketIds;
    data["login_type"] = loginType;
    data["gender"] = gender;
    data["country"] = country;
    data["country_short_name"] = countryShortName;
    data["state"] = state;
    data["city"] = city;
    data["bio"] = bio;
    data["profile_verification_status"] = profileVerificationStatus;
    data["login_verification_status"] = loginVerificationStatus;
    data["is_private"] = isPrivate;
    data["is_admin"] = isAdmin;
    data["deleted_at"] = deletedAt;
    data["bloked_by_admin"] = blockedByAdmin;
    data["createdAt"] = createdAt;
    data["updatedAt"] = updatedAt;
    data["user_type"] = userType;
    return data;
  }
}

class StarredMessageChat {
  String? groupIcon;
  int? chatId;
  String? chatType;
  String? groupName;

  StarredMessageChat({
    this.groupIcon,
    this.chatId,
    this.chatType,
    this.groupName,
  });

  StarredMessageChat.fromJson(Map<String, dynamic> json) {
    groupIcon = json["group_icon"];
    chatId = json["chat_id"];
    chatType = json["chat_type"];
    groupName = json["group_name"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["group_icon"] = groupIcon;
    data["chat_id"] = chatId;
    data["chat_type"] = chatType;
    data["group_name"] = groupName;
    return data;
  }
}
