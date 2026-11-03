import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';

/// Admin surface for a group: the three WhatsApp permission switches, the
/// invite link (with reset) and the pending join requests an admin approves
/// or declines. All calls are JWT-scoped; the server enforces admin rights.
class GroupAdminRepository {
  GroupAdminRepository(this._api);

  final ApiClient _api;

  String _group(int groupId) => '${ApiEndpoints.conversations}/$groupId';

  Map<String, dynamic> _map(dynamic response) {
    dynamic data = response;
    if (response is Map && response['data'] != null) data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// Current switches + whether the caller is an admin.
  Future<Map<String, dynamic>> permissions(int groupId) async =>
      _map(await _api.request('${_group(groupId)}/permissions'));

  /// Flip one or more switches; only the keys sent are changed.
  Future<Map<String, dynamic>> updatePermissions(
    int groupId,
    Map<String, bool> patch,
  ) async => _map(
    await _api.request(
      '${_group(groupId)}/permissions',
      method: 'PATCH',
      body: patch,
    ),
  );

  /// Current invite link, created server-side on first request.
  Future<Map<String, dynamic>> inviteLink(int groupId) async =>
      _map(await _api.request('${_group(groupId)}/invite-link'));

  /// Rotate the link - the previous one stops working.
  Future<Map<String, dynamic>> resetInviteLink(int groupId) async => _map(
    await _api.request(
      '${_group(groupId)}/invite-link/reset',
      method: 'POST',
      body: const {},
    ),
  );

  /// `POST /conversations/:id/members/:userId/send-history` - WhatsApp's
  /// "send old messages": the member can then see the history from before
  /// they joined.
  Future<void> sendHistory(int groupId, int userId) async {
    await _api.request(
      '${_group(groupId)}/members/$userId/send-history',
      method: 'POST',
      body: const {},
    );
  }

  Future<List<Map<String, dynamic>>> joinRequests(int groupId) async {
    final response = await _api.request('${_group(groupId)}/join-requests');
    dynamic data = response;
    if (response is Map && response['data'] != null) data = response['data'];
    if (data is! List) return const [];
    return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<void> decide(
    int groupId,
    String requestId, {
    required bool approve,
  }) async {
    await _api.request(
      '${_group(groupId)}/join-requests/$requestId/${approve ? 'approve' : 'decline'}',
      method: 'POST',
      body: const {},
    );
  }
}
