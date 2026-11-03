class AvatarModel {
  bool? status;
  Data? data;
  String? message;
  bool? toast;

  AvatarModel({this.status, this.data, this.message, this.toast});

  AvatarModel.fromJson(Map<String, dynamic> json) {
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
  List<Records>? records;

  Data({this.records});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['Records'] != null) {
      records = <Records>[];
      json['Records'].forEach((v) {
        records!.add(Records.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (records != null) {
      data['Records'] = records!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Records {
  String? avatarMedia;
  int? avatarId;
  String? name;
  String? avatarGender;
  bool? status;
  String? createdAt;
  String? updatedAt;

  Records(
      {this.avatarMedia,
      this.avatarId,
      this.name,
      this.avatarGender,
      this.status,
      this.createdAt,
      this.updatedAt});

  Records.fromJson(Map<String, dynamic> json) {
    avatarMedia = json['avatar_media'];
    avatarId = json['avatar_id'];
    name = json['name'];
    avatarGender = json['avatar_gender'];
    status = json['status'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['avatar_media'] = avatarMedia;
    data['avatar_id'] = avatarId;
    data['name'] = name;
    data['avatar_gender'] = avatarGender;
    data['status'] = status;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    return data;
  }
}
