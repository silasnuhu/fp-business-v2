import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/api/id_codec.dart';

// REST client for NEW's call-session lifecycle (§7.4/§7.6). Deliberately
// scoped to session state only (initiate/answer/decline/leave/end/history).
// The media plane is a separate concern entirely: it runs on the `/calls`
// socket namespace as a PeerJS full mesh — see PeerJsCallController and
// PEERJS_MIGRATION.md. The ringing/session REST flow below is unchanged by
// that migration.
//
// Response shapes below are NOT given verbatim by the migration guide
// (only the endpoint paths/purposes are confirmed) — field names are
// best-effort/defensive (tries multiple reasonable keys), same pattern
// used for every other "shape not given verbatim" DTO in this migration.
// Verify against a live NEW backend before trusting beyond basic wiring.
class CallRepository {
  final ApiClient _apiClient;

  CallRepository(this._apiClient);

  Future<Map<String, dynamic>> initiateCall({
    required String conversationId,
    required String callType, // "audio" | "video"
  }) async {
    final response = await _apiClient.request(
      ApiEndpoints.calls,
      method: 'POST',
      body: {'conversationId': conversationId, 'callType': callType},
    );
    return response is Map<String, dynamic> ? response : {};
  }

  Future<void> answerCall(String callId) async {
    await _apiClient.request(
      '${ApiEndpoints.calls}/$callId/answer',
      method: 'POST',
    );
  }

  Future<void> declineCall(String callId) async {
    await _apiClient.request(
      '${ApiEndpoints.calls}/$callId/decline',
      method: 'POST',
    );
  }

  Future<void> leaveCall(String callId) async {
    await _apiClient.request(
      '${ApiEndpoints.calls}/$callId/leave',
      method: 'POST',
    );
  }

  Future<void> endCall(String callId) async {
    await _apiClient.request(
      '${ApiEndpoints.calls}/$callId/end',
      method: 'POST',
    );
  }

  Future<Map<String, dynamic>?> getCall(String callId) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.calls}/$callId',
      method: 'GET',
    );
    return response is Map<String, dynamic> ? response : null;
  }

  Future<Map<String, dynamic>> getHistory({
    String? cursor,
    int limit = 30,
  }) async {
    final params = <String>['limit=$limit'];
    if (cursor != null && cursor.isNotEmpty) {
      params.add('cursor=${Uri.encodeQueryComponent(cursor)}');
    }
    final response = await _apiClient.request(
      '${ApiEndpoints.calls}/history?${params.join('&')}',
      method: 'GET',
    );
    return response is Map<String, dynamic> ? response : {};
  }
}

/// Best-effort extraction of a call id from a REST response — tries the
/// couple of reasonable key shapes since the guide gives no literal sample.
String? extractCallId(Map<String, dynamic>? response) {
  if (response == null) return null;
  final call = response['call'] is Map ? response['call'] as Map : response;
  final id = call['id'] ?? call['callId'] ?? call['call_id'];
  return id != null ? IdCodec.toId(id) : null;
}
