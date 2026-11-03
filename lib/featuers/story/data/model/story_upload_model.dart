class StoryUploadModel {
  bool? status;
  Data? data;
  String? message;
  int? toast;

  StoryUploadModel({this.status, this.data, this.message, this.toast});

  StoryUploadModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
    message = json['message'];
    toast = json['toast'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['message'] = message;
    data['toast'] = toast;
    return data;
  }
}

class Data {
  String? media;
  String? expiresAt;
  int? storyId;
  String? storyType;
  int? userId;
  String? caption;
  String? updatedAt;
  String? createdAt;

  Data({
    this.media,
    this.expiresAt,
    this.storyId,
    this.storyType,
    this.userId,
    this.caption,
    this.updatedAt,
    this.createdAt,
  });

  Data.fromJson(Map<String, dynamic> json) {
    media = json['media'];
    expiresAt = json['expiresAt'];
    storyId = json['story_id'];
    storyType = json['story_type'];
    userId = json['user_id'];
    caption = json['caption'];
    updatedAt = json['updatedAt'];
    createdAt = json['createdAt'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['media'] = media;
    data['expiresAt'] = expiresAt;
    data['story_id'] = storyId;
    data['story_type'] = storyType;
    data['user_id'] = userId;
    data['caption'] = caption;
    data['updatedAt'] = updatedAt;
    data['createdAt'] = createdAt;
    return data;
  }
}
