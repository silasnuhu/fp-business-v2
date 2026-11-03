import 'package:whoxa/core/api/id_codec.dart';

class ReportTypesResponse {
  final bool status;
  final ReportTypesData data;
  final String message;
  final bool toast;

  ReportTypesResponse({
    required this.status,
    required this.data,
    required this.message,
    required this.toast,
  });

  factory ReportTypesResponse.fromJson(Map<String, dynamic> json) {
    return ReportTypesResponse(
      status: json['status'] ?? false,
      data: ReportTypesData.fromJson(
        json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : <String, dynamic>{},
      ),
      message: json['message']?.toString() ?? '',
      toast: json['toast'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'data': data.toJson(),
      'message': message,
      'toast': toast,
    };
  }
}

class ReportTypesData {
  final List<ReportType> reportTypes;

  ReportTypesData({required this.reportTypes});

  factory ReportTypesData.fromJson(Map<String, dynamic> json) {
    // The API returns the list under `Records`; `ReportTypes` is kept as a
    // fallback for the older response shape.
    final list = json['Records'] ?? json['ReportTypes'];
    return ReportTypesData(
      reportTypes:
          (list is List ? list : const [])
              .whereType<Map>()
              .map(
                (item) => ReportType.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'Records': reportTypes.map((item) => item.toJson()).toList()};
  }
}

class ReportType {
  final int reportTypeId;
  final String reportText;
  final String reportFor;
  final String createdAt;
  final String updatedAt;

  ReportType({
    required this.reportTypeId,
    required this.reportText,
    required this.reportFor,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportType.fromJson(Map<String, dynamic> json) {
    return ReportType(
      // `report_id` in the current API; `report_type_id` in the older shape.
      reportTypeId: IdCodec.toIntOrZero(
        json['report_id'] ?? json['report_type_id'],
      ),
      reportText: json['report_text']?.toString() ?? '',
      reportFor: json['report_for']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'report_type_id': reportTypeId,
      'report_text': reportText,
      'report_for': reportFor,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
