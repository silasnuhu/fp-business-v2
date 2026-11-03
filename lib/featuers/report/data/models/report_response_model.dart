class ReportResponse {
  final bool status;
  final Map<String, dynamic> data;
  final String message;
  final bool toast;

  ReportResponse({
    required this.status,
    required this.data,
    required this.message,
    required this.toast,
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      status: json['status'] ?? false,
      data:
          json['data'] is Map
              ? Map<String, dynamic>.from(json['data'] as Map)
              : <String, dynamic>{},
      message: json['message']?.toString() ?? '',
      toast: json['toast'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'data': data, 'message': message, 'toast': toast};
  }
}

/// Body for `POST /report/report-user`: `user_id` when reporting a user,
/// `chat_id` when reporting a group.
class ReportUserRequest {
  final int? userId;
  final int? chatId;
  final int reportTypeId;

  ReportUserRequest({this.userId, this.chatId, required this.reportTypeId});

  Map<String, dynamic> toJson() {
    return {
      if (userId != null) 'user_id': userId,
      if (chatId != null) 'chat_id': chatId,
      'report_type_id': reportTypeId,
    };
  }
}
