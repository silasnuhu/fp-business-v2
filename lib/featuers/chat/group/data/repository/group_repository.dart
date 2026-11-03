// File: lib/features/groups/repository/group_repo.dart
// ignore_for_file: use_null_aware_elements

import 'dart:io';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/api/id_codec.dart';
import 'package:whoxa/core/services/media/media_repository.dart';
import 'package:whoxa/core/services/media/media_upload_service.dart';
import 'package:whoxa/featuers/chat/group/data/model/create_group_response.dart';
import 'package:whoxa/featuers/chat/group/data/model/group_member_response.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/utils/logger.dart';

// NEW merges group creation, update, membership, and (partially) member
// listing into the single `/conversations` resource — see
// ApiEndpoints.conversations for the full path map (§5.2/§5.3/§17).
// Promote/demote-admin has been dropped entirely: there is no such
// endpoint in NEW at all, and this repo no longer exposes those methods —
// see GroupProvider/group_info.dart for how the UI is flagged/disabled.
class GroupRepo {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule('GroupRepo');
  late final MediaUploadService _mediaUploadService = MediaUploadService(
    _apiClient,
  );
  late final MediaRepository _mediaRepository = MediaRepository(_apiClient);
  GroupRepo(this._apiClient);

  /// Creates a group conversation. `groupIcon`/multipart upload is dropped —
  /// NEW wants a pre-uploaded `avatarMediaId`, so the picked file goes
  /// through the same presigned flow chat attachments use
  /// (MediaUploadService: POST /media/upload-url -> PUT raw bytes ->
  /// POST /media/:id/confirm) with `context: group`, and only the resulting
  /// mediaId is sent here. `description` has no API exposure in NEW at all
  /// (schema-only field, §5.6) — accepted for call-site compatibility but
  /// never sent.
  Future<CreateGroupResponse> createGroup({
    required List<int> participants,
    required String groupName,
    required String description,
    File? groupIcon,
  }) async {
    // Upload the picked picture first; a failed upload must not fail the
    // whole group creation, so we just create the group without a picture.
    String? avatarMediaId;
    if (groupIcon != null) {
      _logger.i('createGroup: uploading group icon ${groupIcon.path}');
      avatarMediaId = await _mediaUploadService.uploadFile(
        file: groupIcon,
        context: 'group',
      );
      if (avatarMediaId == null) {
        _logger.w(
          'createGroup: group icon upload failed — creating group without a picture',
        );
      } else {
        _logger.i('createGroup: group icon uploaded -> mediaId $avatarMediaId');
      }
    }

    final body = {
      'type': 'group',
      'participantIds': participants.map((id) => id.toString()).toList(),
      'title': groupName,
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (avatarMediaId != null) 'avatarMediaId': avatarMediaId,
    };

    final resp = await _apiClient.request(
      ApiEndpoints.conversations,
      method: 'POST',
      body: body,
    );
    _logger.d('createGroup body passed: $body');
    return _toCreateGroupResponse(resp as Map<String, dynamic>);
  }

  /// Same picture flow as `createGroup`: a newly picked `groupIcon` goes
  /// through MediaUploadService (`/media/upload-url` -> PUT bytes ->
  /// `/media/:id/confirm`) with `context: group`, and only the resulting
  /// mediaId is PATCHed as `avatarMediaId`. `pictureType` has no NEW
  /// equivalent (it was OLD's multipart discriminator) and `groupDescription`
  /// is never sent — no API exposure.
  Future<Map<String, dynamic>?> updateGroup({
    required int chatId,
    required String groupName,
    required String groupDescription,
    String? pictureType,
    File? groupIcon,
  }) async {
    _logger.i('Updating group with chat ID: $chatId');

    // Upload first; a failed upload must not lose the name edit, so the
    // PATCH still goes out — just without a picture change.
    String? avatarMediaId;
    if (groupIcon != null) {
      _logger.i('updateGroup: uploading group icon ${groupIcon.path}');
      avatarMediaId = await _mediaUploadService.uploadFile(
        file: groupIcon,
        context: 'group',
      );
      if (avatarMediaId == null) {
        _logger.w(
          'updateGroup: group icon upload failed — updating group without a picture change',
        );
      } else {
        _logger.i('updateGroup: group icon uploaded -> mediaId $avatarMediaId');
      }
    }

    try {
      final resp = await _apiClient.request(
        '${ApiEndpoints.conversations}/$chatId',
        method: 'PATCH',
        body: {
          'title': groupName,
          if (avatarMediaId != null) 'avatarMediaId': avatarMediaId,
        },
      );
      _logger.i('Group updated successfully');
      _logger.d('Update response: $resp');

      // Resolve the (bare) avatarMediaId to the media row's `cdnUrl` so
      // callers get something displayable — `GET /media/:id` returns
      // metadata, not bytes. Echoed back under `group_icon` as well, the key
      // OLD's response used and group_info.dart still reads, so the edited
      // picture shows immediately without that screen having to change.
      final data = resp is Map<String, dynamic> ? resp : null;
      final avatarUrl = await _mediaRepository.getDisplayUrl(
        (data?['avatarMediaId'] ?? avatarMediaId)?.toString(),
      );

      // No throw = 2xx = success; NEW's PATCH response shape for this
      // endpoint isn't confirmed by the guide, so `status` is synthesized
      // rather than assumed present in the body.
      return {
        'status': true,
        'data':
            data == null
                ? null
                : {
                  ...data,
                  if (avatarUrl != null) 'group_icon': avatarUrl,
                },
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };
    } catch (e) {
      _logger.e('Error updating group', e);
      rethrow;
    }
  }

  /// NEW has no dedicated group-members endpoint at all (§5.3) — members
  /// now come from the conversation's own `participants[]` (`{userId,
  /// role}` only), so this fetches the conversation and batch-resolves each
  /// participant's basic profile via `GET /users/:id` to fill in the
  /// name/avatar fields the UI expects. `participantId`/`updateCounter`/
  /// `lastMessageId`/`isLocked` have no NEW equivalent and are defaulted.
  Future<GroupMembersResponse> getGroupMembers({required int chatId}) async {
    _logger.i('Fetching group members for chat ID: $chatId (via conversation)');

    try {
      final convResp = await _apiClient.request(
        '${ApiEndpoints.conversations}/$chatId',
        method: 'GET',
      );
      final participants =
          (convResp is Map<String, dynamic> ? convResp['participants'] : null)
              as List?;
      if (participants == null) {
        return GroupMembersResponse(
          status: true,
          data: GroupMembersData(records: []),
          message: '',
          toast: false,
        );
      }

      final members = await Future.wait(
        participants.whereType<Map>().map((p) async {
          final userId = IdCodec.toId(p['userId'] ?? p['user_id']);
          final role = p['role'] as String? ?? 'member';
          final leftAt = p['leftAt'];

          Map<String, dynamic>? profileJson;
          // Retry a couple of times — this fan-out runs right after group
          // creation (brand-new userIds, guaranteed cache-miss) and right
          // after a call ends (device mid-teardown of call sockets), both
          // moments prone to a single transient timeout that would otherwise
          // silently leave this member's name as "Unknown User".
          for (var attempt = 0; attempt < 3; attempt++) {
            try {
              final profileResp = await _apiClient.request(
                '${ApiEndpoints.userBlock}/$userId',
                method: 'GET',
              );
              profileJson =
                  profileResp is Map<String, dynamic>
                      ? (profileResp['data'] as Map<String, dynamic>? ??
                          profileResp)
                      : null;
              ContactNameService.instance.noteUserProfile(profileJson);
              break;
            } catch (e) {
              _logger.e(
                'Error fetching profile for participant $userId '
                '(attempt ${attempt + 1}/3): $e',
              );
              if (attempt < 2) {
                await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
              }
            }
          }

          return GroupMember(
            participantId: 0,
            isAdmin: role == 'owner',
            updateCounter: false,
            isDeleted: leftAt != null,
            lastMessageId: 0,
            createdAt: '',
            updatedAt: '',
            chatId: chatId,
            userId: int.tryParse(userId) ?? 0,
            isLocked: false,
            user: profileJson != null ? User.fromJson(profileJson) : null,
          );
        }),
      );

      _logger.i('Group members fetched successfully');
      return GroupMembersResponse(
        status: true,
        data: GroupMembersData(records: members),
        message: '',
        toast: false,
      );
    } catch (e) {
      _logger.e('Error fetching group members', e);
      rethrow;
    }
  }

  /// NEW drops `chat_id`/`delete_chat` body fields (id now in the path) and
  /// has NO admin-continuity safety logic (auto-promote-oldest-if-last-
  /// admin-leaves, auto-delete-if-empty) and NO realtime "you were removed"
  /// notice (§5.6) — flagged, not silently ported, since there was no such
  /// client-side logic to port in the first place (it was purely
  /// server-side in OLD).
  Future<bool> removeGroupMember({
    required int chatId,
    required int userId,
  }) async {
    _logger.i('Removing member $userId from chat $chatId');
    try {
      await _apiClient.request(
        '${ApiEndpoints.conversations}/$chatId/participants/$userId',
        method: 'DELETE',
      );
      _logger.i('Member removed successfully');
      return true;
    } catch (e) {
      _logger.e('Error removing group member', e);
      rethrow;
    }
  }

  // Add Group Member
  Future<bool> addGroupMember({
    required int chatId,
    required List<int> userIds,
  }) async {
    _logger.i('Adding member to chat $chatId');
    try {
      await _apiClient.request(
        '${ApiEndpoints.conversations}/$chatId/participants',
        method: 'POST',
        body: {'userIds': userIds.map((id) => id.toString()).toList()},
      );
      _logger.i('Member added successfully');
      return true;
    } catch (e) {
      _logger.e('Error adding group member', e);
      rethrow;
    }
  }

  CreateGroupResponse _toCreateGroupResponse(Map<String, dynamic> json) {
    // Adapts NEW's ConversationDto-shaped create response onto the
    // existing CreateGroupResponse/GroupData model so group_provider.dart
    // and its UI callers don't need to change. `groupIcon`/`isGroupBlocked`/
    // `deletedAt` have no NEW equivalent on this response and default to
    // empty/false.
    return CreateGroupResponse(
      status: true,
      data: GroupData(
        groupIcon: (json['avatarMediaId'] as String?) ?? '',
        isGroupBlocked: false,
        chatId: int.tryParse(IdCodec.toId(json['id'])) ?? 0,
        chatType: (json['type'] as String?) ?? 'group',
        groupName: (json['title'] as String?) ?? '',
        groupDescription: null,
        updatedAt: (json['updatedAt'] as String?) ?? '',
        createdAt: (json['createdAt'] as String?) ?? '',
        deletedat: null,
        deletedAt: null,
      ),
      message: 'Group created',
      toast: false,
    );
  }
}
