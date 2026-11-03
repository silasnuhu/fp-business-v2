class ChatIdsModel {
  List<ChatIds>? chatIds;

  ChatIdsModel({this.chatIds});

  ChatIdsModel.fromJson(Map<String, dynamic> json) {
    chatIds = json["ChatIds"] == null
        ? null
        : (json["ChatIds"] as List).map((e) => ChatIds.fromJson(e)).toList();
  }

  static List<ChatIdsModel> fromList(List<Map<String, dynamic>> list) {
    return list.map(ChatIdsModel.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (chatIds != null) {
      data["ChatIds"] = chatIds?.map((e) => e.toJson()).toList();
    }
    return data;
  }
}

class ChatIds {
  int? chatId;
  int? userId;

  ChatIds({this.chatId, this.userId});

  ChatIds.fromJson(Map<String, dynamic> json) {
    chatId = json["chat_id"];
    userId = json["user_id"];
  }

  static List<ChatIds> fromList(List<Map<String, dynamic>> list) {
    return list.map(ChatIds.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["chat_id"] = chatId;
    data["user_id"] = userId;
    return data;
  }
}
