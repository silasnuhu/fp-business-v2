// Alternative: Enhance your TypingModel's fromJson to handle type conversion

class TypingModel {
  bool? typing;
  String? chatId;

  TypingModel({this.typing = false, this.chatId});

  // Enhanced fromJson with robust type handling
  TypingModel.fromJson(Map<String, dynamic> json) {
    // Handle typing field - convert various types to bool
    if (json["typing"] != null) {
      if (json["typing"] is bool) {
        typing = json["typing"];
      } else if (json["typing"] is String) {
        typing = json["typing"].toString().toLowerCase() == 'true';
      } else if (json["typing"] is int) {
        typing = json["typing"] == 1;
      } else {
        typing = false;
      }
    } else {
      typing = false;
    }

    // Handle chat_id field - convert to string regardless of input type
    if (json["chat_id"] != null) {
      chatId = json["chat_id"].toString();
    }
  }

  static List<TypingModel> fromList(List<Map<String, dynamic>> list) {
    return list.map(TypingModel.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["typing"] = typing;
    data["chat_id"] = chatId;
    return data;
  }
}
