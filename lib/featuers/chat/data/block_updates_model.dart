class BlockUpdatesModel {
  int? userId;
  int? chatId;
  bool? isBlocked;

  BlockUpdatesModel({this.userId, this.chatId, this.isBlocked});

  BlockUpdatesModel.fromJson(Map<String, dynamic> json) {
    // Handle user_id field
    if (json["user_id"] != null) {
      if (json["user_id"] is int) {
        userId = json["user_id"];
      } else if (json["user_id"] is String) {
        userId = int.tryParse(json["user_id"]) ?? 0;
      } else {
        userId = 0;
      }
    }

    // Handle chat_id field
    if (json["chat_id"] != null) {
      if (json["chat_id"] is int) {
        chatId = json["chat_id"];
      } else if (json["chat_id"] is String) {
        chatId = int.tryParse(json["chat_id"]) ?? 0;
      } else {
        chatId = 0;
      }
    }

    // Handle is_blocked field
    if (json["is_blocked"] != null) {
      if (json["is_blocked"] is bool) {
        isBlocked = json["is_blocked"];
      } else if (json["is_blocked"] is String) {
        isBlocked = json["is_blocked"].toString().toLowerCase() == 'true';
      } else if (json["is_blocked"] is int) {
        isBlocked = json["is_blocked"] == 1;
      } else {
        isBlocked = false;
      }
    } else {
      isBlocked = false;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["user_id"] = userId;
    data["chat_id"] = chatId;
    data["is_blocked"] = isBlocked;
    return data;
  }
}