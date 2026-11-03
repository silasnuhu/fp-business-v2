class ViewedStoriesModel {
  bool? status;
  Data? data;
  String? message;
  bool? toast;

  ViewedStoriesModel({this.status, this.data, this.message, this.toast});

  ViewedStoriesModel.fromJson(Map<String, dynamic> json) {
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
  int? storyId;
  String? caption;
  String? storyType;
  String? expiresAt;
  List<String>? views;
  String? createdAt;
  String? updatedAt;
  int? userId;

  Data({
    this.media,
    this.storyId,
    this.caption,
    this.storyType,
    this.expiresAt,
    this.views,
    this.createdAt,
    this.updatedAt,
    this.userId,
  });

  Data.fromJson(Map<String, dynamic> json) {
    media = json['media'];
    storyId = json['story_id'];
    caption = json['caption'];
    storyType = json['story_type'];
    expiresAt = json['expiresAt'];
    views = json['views'].cast<String>();
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    userId = json['user_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['media'] = media;
    data['story_id'] = storyId;
    data['caption'] = caption;
    data['story_type'] = storyType;
    data['expiresAt'] = expiresAt;
    data['views'] = views;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['user_id'] = userId;
    return data;
  }
}
