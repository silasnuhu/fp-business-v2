import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/communities/data/models/community_model.dart';
import 'package:whoxa/utils/logger.dart';

/// Communities API (`/communities`): the WhatsApp-Communities equivalent.
///
/// A community is a container with an invite code and N linked group
/// conversations. Members join the community once, then opt into the groups
/// they belong to.
class CommunitiesRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'CommunitiesRepository',
  );

  CommunitiesRepository(this._apiClient);

  List<Map<String, dynamic>> _records(dynamic response) {
    // listMine() returns a bare array; other endpoints wrap in {data: ...}.
    dynamic data = response;
    if (response is Map && response['data'] != null) data = response['data'];
    if (data is Map && data['Records'] is List) data = data['Records'];
    if (data is! List) return const [];
    return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Map<String, dynamic> _object(dynamic response) {
    dynamic data = response;
    if (response is Map && response['data'] != null) data = response['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  /// `GET /communities` — communities the caller has joined.
  Future<List<CommunitySummary>> listMine() async {
    final response = await _apiClient.request(ApiEndpoints.communities);
    return _records(response).map(CommunitySummary.fromJson).toList();
  }

  /// `POST /communities` — create a community owned by the caller.
  ///
  /// The server returns the invitation link, which is the only way other
  /// people can join, so the caller surfaces it straight after creation.
  Future<Map<String, dynamic>> createCommunity({
    required String name,
    String? description,
  }) async {
    final response = await _apiClient.request(
      ApiEndpoints.communities,
      method: 'POST',
      body: {
        'name': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return _object(response);
  }

  /// `GET /communities/:id` — detail + linked groups.
  Future<CommunityDetail> getDetail(String communityId) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId',
    );
    return CommunityDetail.fromJson(_object(response));
  }

  /// `POST /communities/invite/:code/join` — idempotent community join.
  Future<CommunityDetail> joinByInvite(String code) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.communities}/invite/$code/join',
      method: 'POST',
      body: const {},
    );
    return CommunityDetail.fromJson(_object(response));
  }

  /// `POST /communities/group-invite/:token/join` — a single group invite.
  /// Joining it also joins the community that owns the group.
  Future<Map<String, dynamic>> joinByGroupInvite(String token) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.communities}/group-invite/$token/join',
      method: 'POST',
      body: const {},
    );
    return _object(response);
  }

  /// `POST /communities/:id/groups/:conversationId/join`.
  Future<bool> joinGroup(String communityId, String conversationId) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId/groups/$conversationId/join',
      method: 'POST',
      body: const {},
    );
    final data = _object(response);
    return data['joined'] == true;
  }

  /// `DELETE /communities/:id/leave`.
  Future<void> leave(String communityId) async {
    await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId/leave',
      method: 'DELETE',
    );
  }

  /// `POST /conversations/:id/leave` - leave ONE group but stay in the
  /// community (WhatsApp lets you exit a single group).
  Future<void> leaveGroupConversation(String conversationId) async {
    await _apiClient.request(
      '${ApiEndpoints.conversations}/$conversationId/leave',
      method: 'POST',
      body: const {},
    );
  }

  /// `PATCH /communities/:id` - community admins only.
  Future<void> updateCommunity(
    String communityId, {
    String? name,
    String? description,
  }) async {
    await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId',
      method: 'PATCH',
      body: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      },
    );
  }

  /// `POST /communities/:id/members` - admins add existing accounts by
  /// username (the in-app picker) or email (ops imports).
  Future<Map<String, dynamic>> addMembers(
    String communityId, {
    List<String>? userNames,
    List<String>? emails,
  }) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId/members',
      method: 'POST',
      body: {
        if (userNames != null && userNames.isNotEmpty) 'userNames': userNames,
        if (emails != null && emails.isNotEmpty) 'emails': emails,
      },
    );
    return _object(response);
  }

  /// `DELETE /communities/:id/members/:userId`.
  Future<void> removeMember(String communityId, String userId) async {
    await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId/members/$userId',
      method: 'DELETE',
    );
  }

  /// `POST /communities/:id/groups` - admins create a linked group.
  Future<Map<String, dynamic>> createGroup(
    String communityId, {
    required String title,
    bool onlyAdminsCanPost = false,
  }) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId/groups',
      method: 'POST',
      body: {
        'title': title,
        'label': title,
        'onlyAdminsCanPost': onlyAdminsCanPost,
      },
    );
    return _object(response);
  }

  /// `DELETE /communities/:id/groups/:conversationId` - unlink a group.
  /// Announcement and General are rejected server-side.
  Future<void> removeGroup(String communityId, String conversationId) async {
    await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId/groups/$conversationId',
      method: 'DELETE',
    );
  }

  /// `PATCH /communities/:id/settings` - mute / pin for the caller only.
  Future<Map<String, dynamic>> setPreferences(
    String communityId, {
    bool? muted,
    bool? pinned,
  }) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId/settings',
      method: 'PATCH',
      body: {
        if (muted != null) 'muted': muted,
        if (pinned != null) 'pinned': pinned,
      },
    );
    return _object(response);
  }

  /// `GET /communities/:id/invite-link` - WhatsApp keeps ONE link for the
  /// whole community, separate from every group link. Any member can share
  /// it; `canReset` is true for community admins only.
  Future<Map<String, dynamic>> inviteLink(String communityId) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId/invite-link',
    );
    return _object(response);
  }

  /// `POST /communities/:id/invite-link/reset` - admins only; revokes the
  /// previous community link immediately.
  Future<Map<String, dynamic>> resetInviteLink(String communityId) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId/invite-link/reset',
      method: 'POST',
      body: const {},
    );
    return _object(response);
  }

  /// `GET /communities/:id/groups/:conversationId/invite-link` - the group's
  /// OWN link. Joining it joins the community and that one group.
  Future<Map<String, dynamic>> groupInviteLink(
    String communityId,
    String conversationId,
  ) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId/groups/$conversationId/invite-link',
    );
    return _object(response);
  }

  /// `POST .../groups/:conversationId/invite-link/reset` - community or
  /// group admins only.
  Future<Map<String, dynamic>> resetGroupInviteLink(
    String communityId,
    String conversationId,
  ) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.communities}/$communityId/groups/$conversationId/invite-link/reset',
      method: 'POST',
      body: const {},
    );
    return _object(response);
  }

  /// Convenience for the invite screen: extract the code from a pasted link
  /// (`https://business.flickpitch.com/c/XXXX`) or accept a raw code.
  ///
  /// A link can be EITHER a community invite or a single group invite
  /// (WhatsApp keeps the two separate). Try the community join first; if the
  /// server says the code is not a community, retry as a group token and then
  /// load the community detail so the screen opens in the same shape.
  Future<CommunityDetail> joinFromLinkOrCode(String input) async {
    var value = input.trim();
    try {
      final uri = Uri.parse(value);
      if (uri.pathSegments.isNotEmpty) {
        value = uri.pathSegments.last;
      }
    } catch (e) {
      _logger.e('Could not parse invite link: $e');
    }
    try {
      return await joinByInvite(value);
    } catch (e) {
      _logger.i('Not a community code, trying a group invite: $e');
      final groupLink = await joinByGroupInvite(value);
      final communityId = groupLink['communityId']?.toString();
      if (communityId == null || communityId.isEmpty) rethrow;
      return getDetail(communityId);
    }
  }
}
