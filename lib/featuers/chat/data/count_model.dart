class CountModel {
  final bool status;
  final Data? data;
  final String message;
  final int toast;

  CountModel({
    required this.status,
    this.data,
    required this.message,
    required this.toast,
  });

  factory CountModel.fromJson(Map<String, dynamic> json) {
    return CountModel(
      status: json['status'] ?? false,
      data: json['data'] != null ? Data.fromJson(json['data']) : null,
      message: json['message'] ?? '',
      toast: json['toast'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (data != null) 'data': data!.toJson(),
      'message': message,
      'toast': toast,
    };
  }
}

class Data {
  final int totalStaredMessages;
  final int totalBlockedUsers;
  final int unreadNotificationCount;

  Data({
    required this.totalStaredMessages,
    required this.totalBlockedUsers,
    required this.unreadNotificationCount,
  });

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      totalStaredMessages: json['total_stared_messages'] ?? 0,
      totalBlockedUsers: json['total_blocked_users'] ?? 0,
      unreadNotificationCount: json['unread_notification_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_stared_messages': totalStaredMessages,
      'total_blocked_users': totalBlockedUsers,
      'unread_notification_count': unreadNotificationCount,
    };
  }
}
