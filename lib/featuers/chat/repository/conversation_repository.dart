// ignore_for_file: use_null_aware_elements

import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/api/id_codec.dart';
import 'package:whoxa/featuers/chat/data/conversation_dto.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/utils/logger.dart';

// REST client for NEW's `/conversations` resource (§5.2/§5.3/§17 of the
// migration guide) — replaces OLD's socket-only chat_list/archived_chat_list
// events, create-group, update-group, add/remove-member, and the
// archive_chat toggle. See ApiEndpoints.conversations for the full path map.
class ConversationRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'ConversationRepository',
  );

  ConversationRepository(this._apiClient);

  Future<ConversationsPage> getConversations({
    String? cursor,
    int limit = 20,
    bool? archived,
  }) async {
    final params = <String>['limit=$limit'];
    if (cursor != null && cursor.isNotEmpty) {
      params.add('cursor=${Uri.encodeQueryComponent(cursor)}');
    }
    if (archived != null) params.add('archived=$archived');

    final response = await _apiClient.request(
      '${ApiEndpoints.conversations}?${params.join('&')}',
      method: 'GET',
    );
    return ConversationsPage.fromJson(response);
  }

  Future<ConversationDto?> getConversation(String id) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.conversations}/$id',
      method: 'GET',
    );
    return response is Map<String, dynamic>
        ? ConversationDto.fromJson(response)
        : null;
  }

  /// Read-only lookup of an EXISTING 1:1 conversation with [peerUserId].
  ///
  /// `POST /conversations` dedupes onto the existing direct row, so it was
  /// previously used as a "resolve or create" — but that means merely opening
  /// a chat screen creates the conversation server-side. This sweeps
  /// `GET /conversations` instead so a lookup never has a side effect;
  /// creation is left to the first real user action (sending a message, or
  /// placing a call). Returns `null` when the two users have never talked.
  ///
  /// Bounded to [maxPages] pages so a huge conversation list can't turn one
  /// chat-open into an unbounded scan.
  Future<String?> findDirectConversationId(
    String peerUserId, {
    int maxPages = 5,
    int pageSize = 50,
  }) async {
    if (peerUserId.isEmpty || peerUserId == '0') return null;

    try {
      String? cursor;
      for (var page = 0; page < maxPages; page++) {
        final result = await getConversations(cursor: cursor, limit: pageSize);
        for (final conversation in result.items) {
          if (conversation.type != 'direct') continue;
          final matches = conversation.participants.any(
            (p) => p.userId == peerUserId,
          );
          if (matches) return conversation.id;
        }
        cursor = result.nextCursor;
        if (cursor == null || cursor.isEmpty) break;
      }
    } catch (e) {
      // A failed lookup must not block opening the chat — the screen just
      // opens empty and the conversation is created on the first send.
      _logger.w('findDirectConversationId failed for peer $peerUserId: $e');
    }
    return null;
  }

  /// Creates a 1:1 or group conversation. OLD's implicit-1:1-on-first-message
  /// and separate `/chat/create-group` both collapse into this one endpoint.
  ///
  /// Call this ONLY from a real user action (message send, call placement) —
  /// never from a screen-open path. Use [findDirectConversationId] to resolve
  /// an existing 1:1 without creating one.
  Future<ConversationDto> createConversation({
    required String type, // "direct" | "group"
    required List<String> participantIds,
    String? title,
    String? avatarMediaId,
  }) async {
    final body = {
      'type': type,
      'participantIds': participantIds,
      if (title != null) 'title': title,
      if (avatarMediaId != null) 'avatarMediaId': avatarMediaId,
    };
    final response = await _apiClient.request(
      ApiEndpoints.conversations,
      method: 'POST',
      body: body,
    );
    return ConversationDto.fromJson(response as Map<String, dynamic>);
  }

  /// Updates title/avatar only — NEW requires admin/owner role, and has no
  /// field for `group_description` at all (schema-only, no API exposure,
  /// §5.6 breaking change #8), so it is never sent here.
  Future<void> updateConversation(
    String id, {
    String? title,
    String? avatarMediaId,
  }) async {
    final body = {
      if (title != null) 'title': title,
      if (avatarMediaId != null) 'avatarMediaId': avatarMediaId,
    };
    await _apiClient.request(
      '${ApiEndpoints.conversations}/$id',
      method: 'PATCH',
      body: body,
    );
  }

  Future<void> addParticipants(String id, List<String> userIds) async {
    await _apiClient.request(
      '${ApiEndpoints.conversations}/$id/participants',
      method: 'POST',
      body: {'userIds': userIds},
    );
  }

  /// No admin-continuity safety logic on NEW's side (auto-promote, auto-
  /// delete-if-empty) and no realtime "you were removed" notice — §5.6.
  Future<void> removeParticipant(String id, String userId) async {
    await _apiClient.request(
      '${ApiEndpoints.conversations}/$id/participants/$userId',
      method: 'DELETE',
    );
  }

  Future<void> leaveConversation(String id) async {
    await _apiClient.request(
      '${ApiEndpoints.conversations}/$id/leave',
      method: 'POST',
    );
  }

  /// Two explicit calls, no more toggle — caller must track/know intent.
  Future<void> setArchived(String id, bool archived) async {
    await _apiClient.request(
      '${ApiEndpoints.conversations}/$id/${archived ? "archive" : "unarchive"}',
      method: 'PATCH',
    );
  }

  /// Per-user pin: pinned chats render in the PINNED section of the list.
  Future<void> setPinned(String id, bool pinned) async {
    await _apiClient.request(
      '${ApiEndpoints.conversations}/$id/${pinned ? "pin" : "unpin"}',
      method: 'PATCH',
    );
  }

  /// Per-user favourite tag - purely a label, never hides the chat.
  Future<void> setFavorite(String id, bool favorite) async {
    await _apiClient.request(
      '${ApiEndpoints.conversations}/$id/${favorite ? "favorite" : "unfavorite"}',
      method: 'PATCH',
    );
  }

  /// Always wipes history AND hides the conversation — there is no "clear
  /// but keep listed" mode in NEW at all (§5.6 breaking change #6).
  Future<void> deleteConversation(String id) async {
    await _apiClient.request(
      '${ApiEndpoints.conversations}/$id',
      method: 'DELETE',
    );
  }

  /// Best-effort single-message preview fetch for the chat-list tile, ahead
  /// of Phase 5's full message module. NEW's `GET /messages/:id?limit=`
  /// response item shape isn't given verbatim by the guide (only the
  /// *send* request body is, §6.2) — field names below are inferred
  /// (`body`, `type`, `senderId`, `createdAt`, `conversationSeq`) and
  /// flagged accordingly; verify against a live response.
  Future<Map<String, dynamic>?> getLatestMessagePreview(
    String conversationId,
  ) async {
    try {
      final response = await _apiClient.request(
        '/messages/$conversationId?limit=1',
        method: 'GET',
      );
      final items =
          response is Map<String, dynamic>
              ? (response['items'] ?? response['data'])
              : (response is List ? response : null);
      if (items is List && items.isNotEmpty) {
        return (items.first as Map).cast<String, dynamic>();
      }
      return null;
    } catch (e) {
      _logger.e('Error fetching conversation preview: $e');
      return null;
    }
  }

  /// Best-effort minimal profile lookup for resolving a 1:1 peer's name/
  /// avatar and group participants' names, since NEW's `participants[]`
  /// carries only `{userId, role}` (§5.5 — "no name/avatar/email"). `GET
  /// /users/:id` is itself on NEW's "newer RESTful surface, not yet used by
  /// frontend" list (§4.2) with an unconfirmed response shape — field names
  /// below mirror the curated user object confirmed for verify-OTP (§3.5).
  /// Batched version of [getUserBasicProfile] — `GET /users/batch?ids=4,13,12`
  /// returns `{items: [...]}`, one curated user object per id, so a chat-list
  /// page costs ONE profile call instead of one per row. Ids the server
  /// doesn't return (deleted user, no access) are simply absent from the map.
  ///
  /// Ids are requested in chunks so a long list can't blow the URL length
  /// limit, and a failed chunk yields an empty result for those ids rather
  /// than throwing — callers fall back to the per-id lookup.
  Future<Map<String, Map<String, dynamic>>> getUserBasicProfiles(
    List<String> userIds, {
    int chunkSize = 100,
  }) async {
    final ids = userIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    final profiles = <String, Map<String, dynamic>>{};
    if (ids.isEmpty) return profiles;

    for (var start = 0; start < ids.length; start += chunkSize) {
      final end =
          start + chunkSize < ids.length ? start + chunkSize : ids.length;
      final chunk = ids.sublist(start, end);
      try {
        final response = await _apiClient.request(
          '${ApiEndpoints.userBlock}/batch?ids=${chunk.join(',')}',
          method: 'GET',
        );
        final items =
            response is Map<String, dynamic>
                ? (response['items'] ??
                    (response['data'] is Map
                        ? (response['data'] as Map)['items']
                        : response['data']))
                : (response is List ? response : null);
        if (items is! List) {
          _logger.w('users/batch returned an unexpected shape: $response');
          continue;
        }
        for (final item in items.whereType<Map>()) {
          final json = item.cast<String, dynamic>();
          final id = (json['userId'] ?? json['user_id'])?.toString();
          if (id != null && id.isNotEmpty) profiles[id] = json;
          ContactNameService.instance.noteUserProfile(json);
        }
      } catch (e) {
        // Best-effort: the caller falls back to per-id lookups for whatever
        // is missing, so a batch failure degrades speed, not correctness.
        _logger.w('users/batch failed for ${chunk.length} ids: $e');
      }
    }
    return profiles;
  }

  /// Presence for [userIds], read off the same curated `users/batch`
  /// payload the chat list already uses — `isOnline`, `lastSeenAt` and the
  /// `lastSeenVisible` privacy flag ride along on every user object, so
  /// this costs no extra round trip beyond the profile fetch itself.
  ///
  /// This is the only REST source of a last-seen timestamp: NEW dropped
  /// `GET /users/is-online/:id`, and the `presence_update` socket event
  /// carries `{userId, isOnline}` with no timestamp, so the socket can say
  /// *that* someone went offline but never *when* they were last seen
  /// before this session started.
  Future<Map<String, UserPresence>> getUserPresences(
    List<String> userIds,
  ) async {
    final profiles = await getUserBasicProfiles(userIds);
    return profiles.map(
      (id, json) => MapEntry(id, UserPresence.fromProfileJson(json)),
    );
  }

  /// Convenience single-id form of [getUserPresences].
  Future<UserPresence?> getUserPresence(String userId) async {
    final presences = await getUserPresences([userId]);
    return presences[userId];
  }

  Future<Map<String, dynamic>?> getUserBasicProfile(String userId) async {
    try {
      final response = await _apiClient.request(
        '${ApiEndpoints.userBlock}/$userId',
        method: 'GET',
      );
      if (response is! Map<String, dynamic>) return null;
      ContactNameService.instance.noteUserProfile(unwrapEnvelope(response));
      return response;
    } catch (e) {
      _logger.e('Error fetching user profile for $userId: $e');
      return null;
    }
  }
}

/// Normalizes a raw `getUserBasicProfile`/`getLatestMessagePreview` map
/// (which may or may not be enveloped in {status,data}) down to its payload.
Map<String, dynamic>? unwrapEnvelope(Map<String, dynamic>? json) {
  if (json == null) return null;
  final data = json['data'];
  if (data is Map<String, dynamic>) return data;
  return json;
}

String idOf(dynamic value) => IdCodec.toId(value);

/// Presence slice of a curated user object (`users/batch` / `GET /users/:id`).
///
/// [lastSeenVisible] is the peer's own privacy setting: when false the
/// backend still returns a `lastSeenAt`, but it must not be shown — treat
/// the user as "no last seen available", exactly as if the timestamp were
/// missing.
class UserPresence {
  final bool isOnline;
  final String? lastSeenAt;
  final bool lastSeenVisible;

  const UserPresence({
    required this.isOnline,
    this.lastSeenAt,
    this.lastSeenVisible = true,
  });

  factory UserPresence.fromProfileJson(Map<String, dynamic> json) {
    return UserPresence(
      isOnline: (json['isOnline'] ?? json['is_online']) == true,
      lastSeenAt: (json['lastSeenAt'] ?? json['last_seen_at']) as String?,
      lastSeenVisible:
          (json['lastSeenVisible'] ?? json['last_seen_visible']) != false,
    );
  }

  /// The timestamp to render, or null when there is nothing showable —
  /// either the peer hides their last seen or the server has no value.
  String? get displayableLastSeenAt =>
      lastSeenVisible && (lastSeenAt?.trim().isNotEmpty ?? false)
          ? lastSeenAt
          : null;
}

/// Minimal label reference used by the chat list ("lists" in the UI).
class ChatLabelRef {
  const ChatLabelRef({required this.id, required this.text, required this.color});
  final String id;
  final String text;
  final String color;
}

extension ChatLabelRepository on ConversationRepository {
  /// GET /chat-labels -> data.Records
  Future<List<ChatLabelRef>> listLabels() async {
    final res = await _apiClient.request('/chat-labels', method: 'GET');
    final map = res is Map ? res : <String, dynamic>{};
    final data = map['data'] is Map ? map['data'] as Map : map;
    final raw = (data['Records'] ?? data['records'] ?? []) as List? ?? [];
    return raw.whereType<Map>().map((r) {
      final id = (r['label_id'] ?? r['labelId'] ?? r['id'] ?? '').toString();
      final text = (r['label_text'] ?? r['labelText'] ?? '') as String? ?? '';
      final color = (r['label_color'] ?? r['labelColor'] ?? '#7C4DFF') as String? ?? '#7C4DFF';
      return ChatLabelRef(id: id, text: text, color: color);
    }).where((l) => l.id.isNotEmpty).toList();
  }

  Future<void> assignLabel(String labelId, int conversationId) async {
    await _apiClient.request(
      '/chat-labels/$labelId/assign',
      method: 'POST',
      body: {'conversation_id': conversationId},
    );
  }

  Future<void> unassignLabel(String labelId, int conversationId) async {
    await _apiClient.request(
      '/chat-labels/$labelId/unassign',
      method: 'POST',
      body: {'conversation_id': conversationId},
    );
  }

  Future<ChatLabelRef?> createLabel(String text, {String color = '#7C4DFF'}) async {
    final res = await _apiClient.request(
      '/chat-labels',
      method: 'POST',
      body: {'label_text': text, 'label_color': color},
    );
    final map = res is Map ? res : <String, dynamic>{};
    final data = map['data'] is Map ? map['data'] as Map : map;
    final id = (data['label_id'] ?? data['labelId'] ?? '') .toString();
    if (id.isEmpty) return null;
    return ChatLabelRef(id: id, text: text, color: color);
  }
}
