class LoginModel {
  bool? status;
  Data? data;
  String? message;
  bool? toast;

  LoginModel({this.status, this.data, this.message, this.toast});

  LoginModel.fromJson(Map<String, dynamic> json) {
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
  bool? newUser;

  Data({this.newUser});

  Data.fromJson(Map<String, dynamic> json) {
    newUser = json['newUser'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['newUser'] = newUser;
    return data;
  }
}
