class CreateGroupResponse {
  final bool status;
  final GroupData data;
  final String message;
  final bool toast;

  CreateGroupResponse({
    required this.status,
    required this.data,
    required this.message,
    required this.toast,
  });

  factory CreateGroupResponse.fromJson(Map<String, dynamic> json) {
    return CreateGroupResponse(
      status: json['status'] as bool,
      data: GroupData.fromJson(json['data'] as Map<String, dynamic>),
      message: json['message'] as String,
      toast: json['toast'] as bool,
    );
  }
}

class GroupData {
  final String groupIcon;
  final bool isGroupBlocked;
  final int chatId;
  final String chatType;
  final String groupName;
  final String?
  groupDescription; // Made nullable since it's missing from response
  final String updatedAt;
  final String createdAt;
  final String? deletedat; // Made nullable since it can be null
  final String? deletedAt; // Made nullable since it can be null

  GroupData({
    required this.groupIcon,
    required this.isGroupBlocked,
    required this.chatId,
    required this.chatType,
    required this.groupName,
    this.groupDescription, // Now optional
    required this.updatedAt,
    required this.createdAt,
    this.deletedat, // Now optional
    this.deletedAt, // Now optional
  });

  factory GroupData.fromJson(Map<String, dynamic> json) {
    return GroupData(
      groupIcon: json['group_icon'] as String,
      isGroupBlocked: json['is_group_blocked'] as bool,
      chatId: json['chat_id'] as int,
      chatType: json['chat_type'] as String,
      groupName: json['group_name'] as String,
      groupDescription: json['group_description'] as String?, // Safe null cast
      updatedAt: json['updatedAt'] as String,
      createdAt: json['createdAt'] as String,
      deletedat: json['deleted_at'] as String?, // Safe null cast
      deletedAt: json['deletedAt'] as String?, // Safe null cast
    );
  }
}
