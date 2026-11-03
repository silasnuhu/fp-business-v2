// File: lib/features/groups/data/models/group_members_response.dart

class GroupMembersResponse {
  final bool status;
  final GroupMembersData data;
  final String message;
  final bool toast;

  GroupMembersResponse({
    required this.status,
    required this.data,
    required this.message,
    required this.toast,
  });

  factory GroupMembersResponse.fromJson(Map<String, dynamic> json) {
    return GroupMembersResponse(
      status: json['status'] ?? false,
      data: GroupMembersData.fromJson(json['data'] ?? {}),
      message: json['message'] ?? '',
      toast: json['toast'] ?? false,
    );
  }
}

class GroupMembersData {
  final List<GroupMember> records;

  GroupMembersData({required this.records});

  factory GroupMembersData.fromJson(Map<String, dynamic> json) {
    return GroupMembersData(
      records:
          (json['Records'] as List?)
              ?.map((x) => GroupMember.fromJson(x))
              .toList() ??
          [],
    );
  }
}

class GroupMember {
  final int participantId;
  final bool isAdmin;
  final bool updateCounter;
  final bool isDeleted;
  final int lastMessageId;
  final String createdAt;
  final String updatedAt;
  final int chatId;
  final int userId;
  final bool isLocked;

  // Nested User object from API
  final User? user;

  // Additional fields for local state
  bool? isOnline;
  String? lastSeen;

  GroupMember({
    required this.participantId,
    required this.isAdmin,
    required this.updateCounter,
    required this.isDeleted,
    required this.lastMessageId,
    required this.createdAt,
    required this.updatedAt,
    required this.chatId,
    required this.userId,
    required this.isLocked,
    this.user,
    this.isOnline,
    this.lastSeen,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      participantId: json['participant_id'] ?? 0,
      isAdmin: json['is_admin'] ?? false,
      updateCounter: json['update_counter'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      lastMessageId: json['last_message_id'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      chatId: json['chat_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      isLocked: json['is_locked'] ?? false,
      user: json['User'] != null ? User.fromJson(json['User']) : null,
      isOnline: json['is_online'],
      lastSeen: json['last_seen'],
    );
  }

  // Helper getters using nested User data
  String get displayName =>
      user?.fullName?.isNotEmpty == true
          ? user!.fullName!
          : user?.userName?.isNotEmpty == true
          ? user!.userName!
          : 'User $userId';

  String get profilePic => user?.profilePic ?? '';
  String get email => user?.email ?? '';
  String get userName => user?.userName ?? '';
  String get countryCode => user?.countryCode ?? '';
  String get country => user?.country ?? '';
  String get mobileNum => user?.mobileNum ?? '';

  String get memberRole => isAdmin ? 'Admin' : 'Member';

  String get joinedDate {
    try {
      final date = DateTime.parse(createdAt);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  // Copy with method for updating local state
  GroupMember copyWith({bool? isOnline, String? lastSeen}) {
    return GroupMember(
      participantId: participantId,
      isAdmin: isAdmin,
      updateCounter: updateCounter,
      isDeleted: isDeleted,
      lastMessageId: lastMessageId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      chatId: chatId,
      userId: userId,
      isLocked: isLocked,
      user: user,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

// New User class for nested User object
class User {
  final String? userName;
  final String? email;
  final String? profilePic;
  final int? userId;
  final String? fullName;
  final String? countryCode;
  final String? country;
  final String? mobileNum;
  final String? userType;

  User({
    this.userName,
    this.email,
    this.profilePic,
    this.userId,
    this.fullName,
    this.countryCode,
    this.country,
    this.mobileNum,
    this.userType,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // NEW backend's `GET /users/:id` (toPublicUser) returns camelCase keys
    // (userName / fullName / firstName / profilePic / ...). OLD used
    // snake_case (user_name / full_name / profile_pic). Read camelCase
    // first and fall back to snake_case so both shapes parse — otherwise
    // every field comes back null and the group member list shows
    // "Unknown User" for everyone.
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return null;
    }

    // fullName can be absent even when firstName/lastName are present.
    final firstName = pick(['first_name', 'firstName']);
    final lastName = pick(['last_name', 'lastName']);
    final composedName =
        [firstName, lastName].where((e) => e != null).join(' ').trim();

    // NEW nests a profile object with its own displayName.
    final profile = json['profile'];
    String? profileDisplayName;
    if (profile is Map) {
      final v = profile['display_name'] ?? profile['displayName'];
      if (v != null && v.toString().trim().isNotEmpty) {
        profileDisplayName = v.toString().trim();
      }
    }

    return User(
      userName: pick(['user_name', 'userName']),
      email: pick(['email']),
      profilePic: pick(['profile_pic', 'profilePic']),
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse('${json['user_id'] ?? json['userId'] ?? ''}'),
      fullName: pick(['full_name', 'fullName']) ??
          (composedName.isNotEmpty ? composedName : null) ??
          (profileDisplayName?.isNotEmpty == true
              ? profileDisplayName
              : null),
      countryCode: pick(['country_code', 'countryCode']),
      country: pick(['country']),
      mobileNum: pick(['mobile_num', 'mobileNum']),
      userType: pick(['user_type', 'userType']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_name': userName,
      'email': email,
      'profile_pic': profilePic,
      'user_id': userId,
      'full_name': fullName,
      'country_code': countryCode,
      'country': country,
      'mobile_num': mobileNum,
      'user_type': userType,
    };
  }
}
