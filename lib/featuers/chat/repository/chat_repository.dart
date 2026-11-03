import 'dart:convert';
import 'dart:core';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:flutter/foundation.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/chat/data/blocked_user_model.dart';
import 'package:whoxa/featuers/chat/data/count_model.dart' as count_model;
import 'package:whoxa/featuers/chat/data/starred_messages_model.dart';
import 'package:whoxa/featuers/chat/data/models/chat_media_model.dart';
import 'package:whoxa/featuers/chat/data/message_dto.dart';
import 'package:whoxa/core/services/media/media_url.dart';
import 'package:whoxa/featuers/chat/repository/conversation_repository.dart';
import 'package:whoxa/featuers/chat/repository/message_repository.dart';
import 'package:whoxa/featuers/notification/data/notification_repository.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:http/http.dart' as http;

class ChatRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  ChatRepository(this._apiClient);

  // ❌ REMOVED: votePoll superseded by MessageRepository.votePoll (own
  // resource, multi-select opaque optionIds — §6.2/§6.5). See
  // ChatProvider.votePoll.

  // 🔒 lockChatRepo/resetChatPinRepo/removeChatLockRepo removed — the new
  // backend has no chat-lock/PIN endpoints at all (`/chat/lock-chat` etc.
  // don't exist server-side). unLockChatRepo is kept only because a
  // pre-existing (now unreachable) unlock-gating check still calls it.

  Future<Map<String, dynamic>?> unLockChatRepo({
    required String chatId,
    required String pin,
  }) async {
    try {
      _logger.d('Removing lock from chat');
      final response = await _apiClient.request(
        ApiEndpoints.unlockChat,
        method: 'POST',
        body: {'chat_id': chatId, 'pin': pin},
      );
      _logger.d('Remove lock chat response: $response');

      if (response != null && response['status'] == true) {
        return response;
      }

      _logger.w('Invalid response from remove lock chat API');
      return null;
    } catch (e) {
      _logger.e('Error removing lock from chat: $e');
      return null;
    }
  }

  /// NEW has explicit star/unstar verbs, not a toggle (§6.3) — every
  /// current caller of this method uses it from a starred-messages list to
  /// unstar an already-starred message, so it delegates to the unstar verb
  /// specifically rather than guessing a toggle direction. If a future
  /// caller needs to *star* a message, use ChatProvider.starUnstarMessage
  /// instead, which tracks local starred state to pick the right verb.
  Future<bool> starUnStarMessage({required int messageId}) async {
    try {
      await MessageRepository(_apiClient).unstarMessage(messageId);
      return true;
    } catch (e) {
      _logger.e('Unstar message error: $e');
      return false;
    }
  }

  /// Check if a message can be forwarded (validation method)
  /// [messageId] - Message ID to check
  /// Returns true if the message can be forwarded, false otherwise
  Future<bool> canForwardMessage(int messageId) async {
    try {
      // You can implement additional validation here if needed
      // For example, checking message type, permissions, etc.

      // Basic validation - message ID should be positive
      if (messageId <= 0) {
        _logger.w('Invalid message ID for forward check: $messageId');
        return false;
      }

      // Add any other business logic here
      // For example:
      // - Check if message is deleted
      // - Check if message type is forwardable
      // - Check user permissions

      return true;
    } catch (e) {
      _logger.e('Error checking forward permission for message $messageId: $e');
      return false;
    }
  }

  /// Get available chats for forwarding (helper method)
  /// Returns a list of chats that the user can forward messages to
  Future<List<Map<String, dynamic>>> getAvailableChatsForForward() async {
    try {
      _logger.d('Getting available chats for forwarding');

      // This would typically call an API endpoint to get user's chats
      // For now, we'll return an empty list as this would depend on your specific API

      // Example API call (uncomment and modify as needed):
      /*
    final response = await _apiClient.request(
      'get-user-chats', // Your endpoint for getting user's chats
      method: 'GET',
    );

    if (response != null && response['status'] == true) {
      final chats = response['data'] as List<dynamic>? ?? [];
      return chats.map((chat) => {
        'chat_id': chat['chat_id'],
        'chat_name': chat['chat_name'],
        'chat_type': chat['chat_type'], // individual, group, etc.
        'last_message_time': chat['last_message_time'],
      }).toList();
    }
    */

      _logger.d('Available chats retrieval completed');
      return [];
    } catch (e) {
      _logger.e('Error getting available chats for forward: $e');
      return [];
    }
  }

  /// Block or unblock a user via API.
  /// NEW splits OLD's single toggle endpoint into two explicit verbs on
  /// `/users/:id/block` (POST to block, DELETE to unblock) — `chat_id` is
  /// gone entirely (block/unblock no longer has chat-message/socket side
  /// effects), and there's no response body at all on success, just a 2xx
  /// status (§4.4/§4.5) — so the caller's own intent is echoed back rather
  /// than read from the server.
  /// [userId] - the id of the user to block/unblock
  /// [block] - true to block, false to unblock
  Future<Map<String, dynamic>?> blockUnblockUser(int userId, bool block) async {
    try {
      _logger.d('${block ? "Block" : "Unblock"} user - userId: $userId');

      await _apiClient.request(
        '${ApiEndpoints.userBlock}/$userId/block',
        method: block ? 'POST' : 'DELETE',
      );

      _logger.i('User ${block ? "block" : "unblock"} successful');
      return {
        'success': true,
        'is_blocked': block,
        'message': block ? 'User blocked' : 'User unblocked',
      };
    } catch (e) {
      _logger.e('Block/Unblock user error: $e');
      return {'success': false, 'is_blocked': !block, 'message': 'Error: $e'};
    }
  }

  /// Get list of blocked users via API.
  /// NEW always returns the full, unpaginated list in one call — no `page`
  /// param, no envelope, bare array response (§4.4/§4.5/§10). The `page`
  /// param is kept on this method's signature only so existing callers
  /// don't need to change; it's ignored.
  /// Returns BlockedUserModel containing blocked users list
  Future<BlockedUserModel?> getBlockedUsers(int page) async {
    try {
      _logger.d('Getting blocked users (NEW: always full list, unpaginated)');

      final response = await _apiClient.request(
        ApiEndpoints.blockList,
        method: 'GET',
      );

      _logger.d('Get blocked users response: $response');
      final model = BlockedUserModel.fromJson(response);
      // Record `premiumUser` so the blue tick shows next to each name.
      for (final record in model.records ?? const <BlockedUserRecord>[]) {
        final user = record.blocked;
        if (user?.userId == null || user?.premiumUser == null) continue;
        ContactNameService.instance.noteUserProfile({
          'userId': user!.userId,
          'premiumUser': user.premiumUser,
        });
      }
      return model;
    } catch (e) {
      _logger.e('Get blocked users error: $e');
      return null;
    }
  }

  count_model.CountModel? countModel;
  /// ❌ NEW removed the combined counts endpoint with no replacement
  /// (§9.3/§16: "no replacement found") — this now derives each count from
  /// its own confirmed NEW source instead of one call:
  ///  - `totalBlockedUsers`: the length of NEW's bare unpaginated
  ///    `GET /users/blocked` array (confirmed source).
  ///  - `unreadNotificationCount`: `GET /notifications/unread-count`
  ///    (confirmed source, Phase 9).
  ///  - `totalStaredMessages`: ⚠️ UNRESOLVED — NEW's starred list is cursor
  ///    paginated with no total-count field anywhere in the guide. This
  ///    returns the size of just the first fetched page as a best-effort
  ///    lower bound, NOT a true total — it will under-report whenever
  ///    there's more than one page of starred messages. Flagged rather
  ///    than silently presented as accurate; there is no way to get a real
  ///    total from NEW's confirmed surface today.
  Future<count_model.CountModel?> countRepo() async {
    try {
      final results = await Future.wait([
        getBlockedUsers(1),
        NotificationRepository(_apiClient).getUnreadCount(),
        MessageRepository(_apiClient).getStarredMessages(limit: 100),
      ]);
      final blocked = results[0] as BlockedUserModel?;
      final unreadNotifications = results[1] as int;
      final starredPage = results[2] as MessagesPage;

      return countModel = count_model.CountModel(
        status: true,
        message: '',
        toast: 0,
        data: count_model.Data(
          totalStaredMessages: starredPage.items.length,
          totalBlockedUsers: blocked?.records?.length ?? 0,
          unreadNotificationCount: unreadNotifications,
        ),
      );
    } catch (e) {
      _logger.e('Get count starred/block error: $e');
      return null;
    }
  }

  /// Get list of starred messages via API
  /// [page] - Page number for pagination (optional, defaults to 1)
  /// [limit] - Number of records per page (optional, defaults to 10)
  /// Returns StarredMessagesResponse containing starred messages list
  /// NEW's starred list (`GET /messages/starred?cursor=&limit=`) has no
  /// `chat_id` filter at all anymore (§6.3/§6.7 breaking change #13) —
  /// `chatId` is accepted only for call-site compatibility and, if passed,
  /// is applied as a client-side filter over the fetched page rather than
  /// a server-side one, which means a filtered view may show fewer results
  /// per "page" than expected since filtering happens after fetching.
  /// `page` is likewise cosmetic — NEW is cursor-based with no page
  /// numbers, so this always fetches from the start (this repo layer
  /// doesn't track a cursor across calls; ChatProvider-level callers
  /// should prefer MessageRepository.getStarredMessages directly for real
  /// pagination).
  Future<StarredMessagesResponse?> getStarredMessages({
    int page = 1,
    int limit = 10000,
    int? chatId,
  }) async {
    try {
      _logger.d(
        'Getting starred messages (NEW: cursor-based, no chat_id filter) - limit: $limit, chatId filter: $chatId',
      );

      final result = await MessageRepository(
        _apiClient,
      ).getStarredMessages(limit: limit);

      var items = result.items;
      if (chatId != null) {
        items = items.where((m) => m.conversationId == chatId.toString()).toList();
      }

      // `GET /messages/starred` identifies people by id only —
      // `senderId` and (for direct chats) `otherParticipantId`, with no
      // name or avatar attached. Resolve them in ONE `users/batch` call so
      // the list header ("<sender> ▶ <chat>") and the chat screen this
      // navigates to get real names instead of falling back to
      // "Unknown User".
      final profiles = await ConversationRepository(
        _apiClient,
      ).getUserBasicProfiles([
        for (final m in items) ...[
          m.senderId,
          if (m.otherParticipantId != null) m.otherParticipantId!,
        ],
      ]);

      final json = {
        'status': true,
        'data': {
          'Records':
              items.map((m) => _messageDtoToStarredJson(m, profiles)).toList(),
          'Pagination': {
            'current_page': 1,
            'total_pages': result.hasMore ? 2 : 1,
          },
        },
      };
      return StarredMessagesResponse.fromJson(json);
    } catch (e) {
      _logger.e('Get starred messages error: $e');
      return null;
    }
  }

  Map<String, dynamic> _messageDtoToStarredJson(
    MessageDto m,
    Map<String, Map<String, dynamic>> profiles,
  ) {
    var type = m.type;
    if (type == 'document') type = 'doc';
    if (type == 'audio') type = 'voice';
    final isGroup = m.conversationType == 'group';
    return {
      'message_content': m.body,
      'message_id': int.tryParse(m.id),
      'message_type': type,
      'createdAt': m.createdAt,
      'updatedAt': m.updatedAt,
      'chat_id': int.tryParse(m.conversationId),
      'sender_id': int.tryParse(m.senderId),
      'reply_to': int.tryParse(m.replyToMessageId ?? ''),
      // The starred list is cross-chat, so each row has to carry its own
      // chat context — without it the screen can't tell a group message
      // from a direct one and opens every tap as a 1:1 chat with userId 0.
      // `group_icon` has no counterpart in the starred payload; the chat
      // screen resolves the avatar itself.
      'Chat': {
        'chat_id': int.tryParse(m.conversationId),
        'chat_type': isGroup ? 'group' : 'private',
        'group_name': m.conversationTitle,
        'group_icon': null,
      },
      'User': _profileToStarredUserJson(profiles[m.senderId], m.senderId),
      if (!isGroup && m.otherParticipantId != null)
        'peer_user': _profileToStarredUserJson(
          profiles[m.otherParticipantId!],
          m.otherParticipantId!,
        ),
    };
  }

  /// Curated `users/batch` profile (camelCase, `toPublicUser`) -> the
  /// snake_case keys `StarredMessageRecord`'s `User`/`PeerUser` parse. A
  /// missing profile still yields the id, so name resolution can fall back
  /// to a saved contact rather than losing the user entirely.
  ///
  /// For the logged-in user's own starred messages the locally stored
  /// profile fills any gap, so your own avatar/name render on those rows
  /// even if `users/batch` doesn't echo the caller's own id back.
  Map<String, dynamic> _profileToStarredUserJson(
    Map<String, dynamic>? profile,
    String userId,
  ) {
    final json = profile ?? const <String, dynamic>{};
    final isMe = userId.isNotEmpty && userId == userID;
    final localFullName =
        [firstName, lastName].where((p) => p.trim().isNotEmpty).join(' ');

    return {
      'user_id':
          int.tryParse(
            (json['userId'] ?? json['user_id'])?.toString() ?? userId,
          ) ??
          int.tryParse(userId),
      'full_name':
          json['fullName'] ??
          json['full_name'] ??
          (isMe && localFullName.isNotEmpty ? localFullName : null),
      'first_name':
          json['firstName'] ??
          json['first_name'] ??
          (isMe && firstName.isNotEmpty ? firstName : null),
      'last_name':
          json['lastName'] ??
          json['last_name'] ??
          (isMe && lastName.isNotEmpty ? lastName : null),
      'user_name':
          json['userName'] ??
          json['user_name'] ??
          (isMe && userName.isNotEmpty ? userName : null),
      'email': json['email'] ?? (isMe && email.isNotEmpty ? email : null),
      'mobile_num': json['mobileNum'] ?? json['mobile_num'],
      'country_code': json['countryCode'] ?? json['country_code'],
      'profile_pic':
          MediaUrl.normalize(
            (json['profilePic'] ?? json['profile_pic']) as String?,
          ) ??
          (isMe ? MediaUrl.normalize(userProfile) : null),
      'user_type': json['userType'] ?? json['user_type'],
    };
  }

  /// Clear/delete a chat via API.
  /// [chatId] - The ID of the chat to clear/delete
  /// [deleteChat] - `true`: `DELETE /conversations/:id` wipes history AND
  /// hides the conversation. `false`: `POST /conversations/:id/clear` empties
  /// only the caller's own view of the history — the conversation stays in
  /// the chat list and the other participants' copies are untouched (403 if
  /// the caller isn't an active participant).
  /// Returns true if successful, false otherwise
  Future<bool> clearChat({required int chatId, bool deleteChat = false}) async {
    if (!deleteChat) {
      try {
        _logger.d('Clearing chat history - chatId: $chatId');
        await _apiClient.request(
          '${ApiEndpoints.conversations}/$chatId/clear',
          method: 'POST',
        );
        _logger.i('Chat clear successful');
        return true;
      } catch (e) {
        _logger.e('Clear chat error: $e');
        return false;
      }
    }

    try {
      _logger.d('Deleting chat - chatId: $chatId');
      await _apiClient.request(
        '${ApiEndpoints.conversations}/$chatId',
        method: 'DELETE',
      );
      _logger.i('Chat delete successful');
      return true;
    } catch (e) {
      _logger.e('Delete chat error: $e');
      return false;
    }
  }

  /// Get chat media files via API.
  /// [type] — legacy caller-facing values `'media'` | `'doc'` | `'link'`,
  /// mapped onto NEW's `category` query param (`'media'|'document'|'link'`
  /// — `QueryConversationMediaDto`). NEW has no `POST /chat/chat-media`
  /// endpoint at all; this now calls `GET /messages/:conversationId/media`
  /// and adapts the response into the existing `ChatMediaResponse` model so
  /// the media-gallery screens don't need to change.
  Future<ChatMediaResponse?> getChatMedia({
    required int chatId,
    required String type,
  }) async {
    try {
      final category = type == 'doc' ? 'document' : type;
      _logger.d('Getting chat media for chatId: $chatId, category: $category');

      final page = await MessageRepository(
        _apiClient,
      ).getConversationMedia(chatId, category: category, limit: 100);

      final json = {
        'status': true,
        'message': '',
        'toast': 0,
        'data': {
          'Records': page.items.map((m) => _messageDtoToMediaJson(m)).toList(),
          'pagenation': {'total_pages': page.hasMore ? 2 : 1},
        },
      };
      return ChatMediaResponse.fromJson(json);
    } catch (e) {
      _logger.e('Get chat media error: $e');
      return null;
    }
  }

  Map<String, dynamic> _messageDtoToMediaJson(MessageDto m) {
    var type = m.type;
    if (type == 'document') type = 'doc';
    if (type == 'audio') type = 'voice';
    return {
      'message_content': m.primaryAttachmentUrl ?? m.body,
      'message_thumbnail': m.primaryAttachmentThumbnailUrl ?? '',
      'message_id': int.tryParse(m.id),
      'message_type': type,
      'createdAt': m.createdAt,
      'updatedAt': m.updatedAt,
      'chat_id': int.tryParse(m.conversationId),
      'sender_id': int.tryParse(m.senderId),
      'reply_to': int.tryParse(m.replyToMessageId ?? ''),
      'deleted_for_everyone': m.isDeletedForEveryone,
    };
  }

  // ❌ REMOVED: NEW has no cross-chat search-by-name endpoint at all
  // (§5.3/§5.6). ChatProvider.searchChats now filters the already-loaded
  // conversation list client-side instead of calling a server endpoint.

  /// Search messages within a single conversation via
  /// `GET /messages/:conversationId/search` (`SearchMessagesDto`, max
  /// `limit` 50). NEW has no cross-conversation search endpoint at all —
  /// this now requires [chatId] and only ever searches within it; the old
  /// `POST /chat/search-message` path this used to call doesn't exist.
  /// [page] is kept only for call-site compatibility — NEW's search is
  /// cursor-based (`beforeSeq`), not page-numbered, so this always returns
  /// the first (most recent) page of matches.
  /// Returns the same `{status, data:{Records, pagenation}}` envelope shape
  /// callers already expect, built from the raw response so the search
  /// endpoint's extra `sender:{userId, fullName, profilePic}` object
  /// (absent from the general `MessageDto`) survives into `Records.User`.
  Future<Map<String, dynamic>?> searchMessages({
    required String searchText,
    required int chatId,
    int page = 1,
    int limit = 30,
  }) async {
    try {
      _logger.d(
        'Searching messages with text: "$searchText" in chatId: $chatId',
      );
      final params = <String>[
        'query=${Uri.encodeQueryComponent(searchText)}',
        'limit=$limit',
      ];
      final response = await _apiClient.request(
        '${ApiEndpoints.messages}/$chatId/search?${params.join('&')}',
        method: 'GET',
      );
      final map = response is Map<String, dynamic> ? response : <String, dynamic>{};
      final rawItems = map['items'];
      final items =
          rawItems is List ? rawItems.whereType<Map>() : const Iterable<Map>.empty();
      final hasMore = map['hasMore'] == true;

      return {
        'status': true,
        'message': '',
        'data': {
          'Records': items.map((e) => _searchItemToJson(e.cast<String, dynamic>())).toList(),
          'pagenation': {
            'current_page': 1,
            'total_pages': hasMore ? 2 : 1,
          },
        },
      };
    } catch (e) {
      _logger.e('Search messages error: $e');
      return null;
    }
  }

  Map<String, dynamic> _searchItemToJson(Map<String, dynamic> item) {
    final message = MessageDto.fromJson(item);
    var type = message.type;
    if (type == 'document') type = 'doc';
    if (type == 'audio') type = 'voice';
    final sender = item['sender'];
    final senderMap = sender is Map ? sender.cast<String, dynamic>() : const {};
    return {
      'message_content': message.primaryAttachmentUrl ?? message.body,
      'message_type': type,
      'message_id': int.tryParse(message.id),
      'createdAt': message.createdAt,
      'chat_id': int.tryParse(message.conversationId),
      'sender_id': int.tryParse(message.senderId),
      'User': {
        'full_name': senderMap['fullName'] ?? '',
        'profile_pic': senderMap['profilePic'] ?? '',
        'user_id': int.tryParse(message.senderId) ?? 0,
      },
    };
  }

  Future<Map<String, dynamic>> fetchMetadataRepo(String url) async {
    final localStorageKey = 'metadata_${Uri.encodeComponent(url)}';

    try {
      // ✅ Check cache
      final cachedData = await SecurePrefs.getString(localStorageKey);
      if (cachedData != null) {
        return Map<String, dynamic>.from(jsonDecode(cachedData));
      }

      // ✅ Make POST request with url in params (body)
      final response = await http.post(
        Uri.parse("https://api.microlink.io"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"url": url}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];

        final metadata = {
          "title": data["title"] ?? "",
          "description": data["description"] ?? "",
          "image": data["image"]?["url"] ?? data["logo"]?["url"] ?? "",
        };

        // ✅ Save in secure prefs
        await SecurePrefs.setString(localStorageKey, jsonEncode(metadata));

        return metadata;
      } else {
        return {"title": "", "description": "", "image": ""};
      }
    } catch (e) {
      debugPrint("❌ Error fetching metadata: $e");
      return {"title": "", "description": "", "image": ""};
    }
  }
}
