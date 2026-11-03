class LanguageListModel {
  final bool status;
  final Data? data;
  final String message;
  final bool toast;

  LanguageListModel({
    required this.status,
    this.data,
    required this.message,
    required this.toast,
  });

  factory LanguageListModel.fromJson(Map<String, dynamic> json) {
    return LanguageListModel(
      status: json['status'] ?? false,
      data: json['data'] != null ? Data.fromJson(json['data']) : null,
      message: json['message'] ?? '',
      toast: json['toast'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (data != null) 'data': data!.toJson(),
      'message': message,
      'toast': toast,
    };
  }
}

class Data {
  final List<Records> records;
  final Pagination? pagination;

  Data({required this.records, this.pagination});

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      records:
          (json['Records'] as List<dynamic>? ?? [])
              .map((v) => Records.fromJson(v as Map<String, dynamic>))
              .toList(),
      pagination:
          json['Pagination'] != null
              ? Pagination.fromJson(json['Pagination'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Records': records.map((v) => v.toJson()).toList(),
      if (pagination != null) 'Pagination': pagination!.toJson(),
    };
  }
}

class Records {
  final int languageId;
  final String language;
  final String languageAlignment;
  final String country;
  final bool status;
  final bool defaultStatus;
  final String createdAt;
  final String updatedAt;

  Records({
    required this.languageId,
    required this.language,
    required this.languageAlignment,
    required this.country,
    required this.status,
    required this.defaultStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Records.fromJson(Map<String, dynamic> json) {
    return Records(
      languageId: json['language_id'] ?? 0,
      language: json['language'] ?? '',
      languageAlignment: json['language_alignment'] ?? '',
      country: json['country'] ?? '',
      status: json['status'] ?? false,
      defaultStatus: json['default_status'] ?? false,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language_id': languageId,
      'language': language,
      'language_alignment': languageAlignment,
      'country': country,
      'status': status,
      'default_status': defaultStatus,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class Pagination {
  final int totalPages;
  final int totalRecords;
  final int currentPage;
  final int recordsPerPage;

  Pagination({
    required this.totalPages,
    required this.totalRecords,
    required this.currentPage,
    required this.recordsPerPage,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      totalPages: json['total_pages'] ?? 0,
      totalRecords: json['total_records'] ?? 0,
      currentPage: json['current_page'] ?? 0,
      recordsPerPage: json['records_per_page'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_pages': totalPages,
      'total_records': totalRecords,
      'current_page': currentPage,
      'records_per_page': recordsPerPage,
    };
  }
}
