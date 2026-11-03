class NotificationListModel {
  bool? status;
  Data? data;
  String? message;
  bool? toast;

  NotificationListModel({this.status, this.data, this.message, this.toast});

  NotificationListModel.fromJson(Map<String, dynamic> json) {
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
  Pagination? pagination;

  Data({this.records, this.pagination});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['Records'] != null) {
      records = <Records>[];
      json['Records'].forEach((v) {
        records!.add(Records.fromJson(v));
      });
    }
    pagination =
        json['Pagination'] != null
            ? Pagination.fromJson(json['Pagination'])
            : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (records != null) {
      data['Records'] = records!.map((v) => v.toJson()).toList();
    }
    if (pagination != null) {
      data['Pagination'] = pagination!.toJson();
    }
    return data;
  }
}

class Records {
  int? notificationId;
  String? title;
  String? message;
  List<int>? users;
  String? createdAt;
  String? updatedAt;

  Records({
    this.notificationId,
    this.title,
    this.message,
    this.users,
    this.createdAt,
    this.updatedAt,
  });

  Records.fromJson(Map<String, dynamic> json) {
    notificationId = json['notification_id'];
    title = json['title'];
    message = json['message'];
    users = (json['users'] as List?)?.cast<int>();
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['notification_id'] = notificationId;
    data['title'] = title;
    data['message'] = message;
    data['users'] = users;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    return data;
  }
}

class Pagination {
  int? totalPages;
  int? totalRecords;
  int? currentPage;
  int? recordsPerPage;

  Pagination({
    this.totalPages,
    this.totalRecords,
    this.currentPage,
    this.recordsPerPage,
  });

  Pagination.fromJson(Map<String, dynamic> json) {
    totalPages = json['total_pages'];
    totalRecords = json['total_records'];
    currentPage = json['current_page'];
    recordsPerPage = json['records_per_page'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_pages'] = totalPages;
    data['total_records'] = totalRecords;
    data['current_page'] = currentPage;
    data['records_per_page'] = recordsPerPage;
    return data;
  }
}
