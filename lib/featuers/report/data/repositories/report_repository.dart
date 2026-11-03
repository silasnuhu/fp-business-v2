import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/report/data/models/report_types_model.dart';
import 'package:whoxa/featuers/report/data/models/report_response_model.dart';

/// User/group reporting.
///
/// - `POST /report/report-types` →`{status, data: {Records: [{report_id,
///   report_text}]}, message, toast}`
/// - `POST /report/report-user`  → body `{user_id, report_type_id}` for a user,
///   or `{chat_id, report_type_id}` for a group.
class ReportRepository {
  final ApiClient _apiClient;

  ReportRepository(this._apiClient);

  Future<ReportTypesResponse> getReportTypes() async {
    final response = await _apiClient.request(
      ApiEndpoints.reportTypes,
      method: 'POST',
    );
    return ReportTypesResponse.fromJson(_asMap(response));
  }

  /// Reports a user ([userId]) or a group ([chatId]) — pass exactly one.
  Future<ReportResponse> report({
    int? userId,
    int? chatId,
    required int reportTypeId,
  }) async {
    assert(
      (userId == null) != (chatId == null),
      'Pass either userId (user) or chatId (group)',
    );
    final request = ReportUserRequest(
      userId: userId,
      chatId: chatId,
      reportTypeId: reportTypeId,
    );
    final response = await _apiClient.request(
      ApiEndpoints.reportUser,
      method: 'POST',
      body: request.toJson(),
    );
    return ReportResponse.fromJson(_asMap(response));
  }

  Map<String, dynamic> _asMap(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    return <String, dynamic>{};
  }
}
