class MarkReadNotifiModel {
  bool? status;
  List<int>? data;
  String? message;
  bool? toast;

  MarkReadNotifiModel({this.status, this.data, this.message, this.toast});

  MarkReadNotifiModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    data = json['data'].cast<int>();
    message = json['message'];
    toast = json['toast'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['data'] = this.data;
    data['message'] = message;
    data['toast'] = toast;
    return data;
  }
}
