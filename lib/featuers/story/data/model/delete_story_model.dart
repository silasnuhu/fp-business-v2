class DeleteStoryModel {
  bool? status;
  String? message;
  bool? toast;

  DeleteStoryModel({this.status, this.message, this.toast});

  DeleteStoryModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    toast = json['toast'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    data['toast'] = toast;
    return data;
  }
}
