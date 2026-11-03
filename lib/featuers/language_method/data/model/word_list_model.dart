class WordListModel {
  bool? status;
  Data? data;
  String? message;
  bool? toast;

  WordListModel({this.status, this.data, this.message, this.toast});

  WordListModel.fromJson(Map<String, dynamic> json) {
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
  int? keyId;
  String? key;
  String? translation;

  Records({this.keyId, this.key, this.translation});

  Records.fromJson(Map<String, dynamic> json) {
    keyId = json['key_id'];
    key = json['key'];
    translation = json['Translation'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['key_id'] = keyId;
    data['key'] = key;
    data['Translation'] = translation;
    return data;
  }
}
