import 'package:uuid/uuid.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/api/id_codec.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/chat/data/message_dto.dart';
import 'package:whoxa/featuers/chat/utils/message_utils.dart';
import 'package:whoxa/utils/enums.dart';
import 'package:whoxa/utils/logger.dart';

// REST client for NEW's `/messages`, `/conversations/:id/pins`,
// `/messages/:id/star`, `/messages/:id/reactions`, and `/polls` resources
// (§6.2/§6.3/§17 of the migration guide) — replaces OLD's multipart
// send-message and the various delete/pin/star socket round-trips.
class MessageRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'MessageRepository',
  );
  final _uuid = const Uuid();

  MessageRepository(this._apiClient);

  /// Sends a message. Media types (Image/Video/File/Gif/Voice) require a
  /// pre-uploaded `attachmentMediaIds` list — NEW has no raw-file-upload
  /// path on send at all anymore (§6.2/§6.7 breaking change #6). Since the
  /// media module (Phase 6) isn't built yet, this refuses those types
  /// immediately with a clear message instead of sending a doomed request.
  /// Social/Contact/Location/StoryReply payload shapes are carried in the
  /// untyped `metadata` bag, best-effort — the guide confirms NEW does no
  /// server-side shape validation on it but doesn't give an exact contract
  /// (§6.8). A story reply goes out as `type: 'feed_reference'` (the only
  /// story-related value in NEW's message-type enum) with the referenced
  /// story snapshot carried entirely in `metadata` — the backend stores it
  /// verbatim and does no server-side wiring, so the client both sends and
  /// re-hydrates the story preview from that bag (see MessageAdapter).
  Future<MessageDto> sendMessage({
    required int conversationId,
    required MessageType messageType,
    required String messageContent,
    int? replyToMessageId,
    int? forwardOfMessageId,
    Map<String, dynamic>? metadata,
    List<String>? attachmentMediaIds,
  }) async {
    final hasAttachments =
        attachmentMediaIds != null && attachmentMediaIds.isNotEmpty;
    // A GIF sent by URL (Giphy-style) carries the URL in `body` and needs no
    // upload at all, so it is exempt from the media-not-built guard — mirrors
    // the same `isGifUrl` case in ChatProvider.sendMessage.
    final isGifUrl =
        messageType == MessageType.Gif &&
        messageContent.startsWith('http') &&
        messageContent.contains('gif');
    // A forward needs no freshly-uploaded attachment either — MessagesService
    // .send() copies `forwardSource.attachments` onto the new message itself
    // whenever the request carries no `attachmentMediaIds` of its own
    // (messages.service.ts: `attachmentMediaIds: dto.attachmentMediaIds
    // ?.length ? ... : forwardSource?.attachments...`). Without this
    // exemption forwarding any image/video/voice/document message hit the
    // "media upload has not been built" guard, even though nothing needs
    // uploading.
    final isForward = forwardOfMessageId != null && forwardOfMessageId > 0;
    if (MessageTypeUtils.requiresFileUpload(messageType) &&
        !hasAttachments &&
        !isGifUrl &&
        !isForward) {
      throw AppError(
        'Sending photos, videos, voice notes, and documents isn\'t available yet — media upload has not been built.',
      );
    }

    final internalType = MessageTypeUtils.messageContentType(messageType);
    final wireType = MessageTypeUtils.toNewOutgoingType(internalType);

    final body = <String, dynamic>{
      'clientMessageId': _uuid.v4(),
      'type': wireType,
      // SendMessageDto requires `body` as a string whenever `type` is
      // 'text' OR no `attachmentMediaIds` are sent (validated before
      // MessagesService.send() ever runs, so its own `dto.body ??
      // forwardSource?.body` fallback never gets a chance to help) — a
      // forward with no local text/attachments to resend would otherwise
      // omit the key entirely and get rejected with a 400. Caller
      // (ChatProvider.forwardMessage) already threads the real source
      // content through when it can find it locally; this empty-string
      // fallback only fires if that lookup failed.
      if (messageContent.isNotEmpty || isForward) 'body': messageContent,
      if (hasAttachments) 'attachmentMediaIds': attachmentMediaIds,
      if (replyToMessageId != null && replyToMessageId > 0)
        'replyToMessageId': replyToMessageId.toString(),
      if (forwardOfMessageId != null && forwardOfMessageId > 0)
        'forwardOfMessageId': forwardOfMessageId.toString(),
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    };

    _logger.d('Sending message to conversation $conversationId: $body');
    final response = await _apiClient.request(
      '${ApiEndpoints.messages}/$conversationId',
      method: 'POST',
      body: body,
    );
    return MessageDto.fromJson(response as Map<String, dynamic>);
  }

  /// Cursor-based message list. `beforeSeq` pages backward (older messages,
  /// the common "load more" direction); `afterSeq` pages forward.
  Future<MessagesPage> getMessages(
    int conversationId, {
    int? beforeSeq,
    int? afterSeq,
    int limit = 30,
  }) async {
    final params = <String>['limit=$limit'];
    if (beforeSeq != null) params.add('beforeSeq=$beforeSeq');
    if (afterSeq != null) params.add('afterSeq=$afterSeq');
    final response = await _apiClient.request(
      '${ApiEndpoints.messages}/$conversationId?${params.join('&')}',
      method: 'GET',
    );
    return MessagesPage.fromJson(response);
  }

  /// `GET /messages/:conversationId/media?category=&beforeSeq=&limit=` —
  /// `category` must be one of `media` | `document` | `link`
  /// (`QueryConversationMediaDto`, max `limit` 100). Replaces the old,
  /// now-nonexistent `POST /chat/chat-media`.
  Future<MessagesPage> getConversationMedia(
    int conversationId, {
    required String category,
    int? beforeSeq,
    int limit = 30,
  }) async {
    final params = <String>['category=$category', 'limit=$limit'];
    if (beforeSeq != null) params.add('beforeSeq=$beforeSeq');
    final response = await _apiClient.request(
      '${ApiEndpoints.messages}/$conversationId/media?${params.join('&')}',
      method: 'GET',
    );
    return MessagesPage.fromJson(response);
  }

  /// `GET /messages/:conversationId/search?query=&beforeSeq=&limit=`
  /// (`SearchMessagesDto`, max `limit` 50). Conversation-scoped only — NEW
  /// has no cross-conversation search endpoint, replacing the old, now
  /// nonexistent `POST /chat/search-message`.
  Future<MessagesPage> searchMessages(
    int conversationId, {
    required String query,
    int? beforeSeq,
    int limit = 30,
  }) async {
    final params = <String>[
      'query=${Uri.encodeQueryComponent(query)}',
      'limit=$limit',
    ];
    if (beforeSeq != null) params.add('beforeSeq=$beforeSeq');
    final response = await _apiClient.request(
      '${ApiEndpoints.messages}/$conversationId/search?${params.join('&')}',
      method: 'GET',
    );
    return MessagesPage.fromJson(response);
  }

  Future<void> markRead(int conversationId, int upToSeq) async {
    await _apiClient.request(
      '${ApiEndpoints.messages}/$conversationId/read',
      method: 'POST',
      body: {'upToSeq': upToSeq},
    );
  }

  Future<void> markDelivered(int conversationId, int upToSeq) async {
    await _apiClient.request(
      '${ApiEndpoints.messages}/$conversationId/delivered',
      method: 'POST',
      body: {'upToSeq': upToSeq},
    );
  }

  Future<void> pinMessage(int conversationId, int messageId) async {
    await _apiClient.request(
      '${ApiEndpoints.conversations}/$conversationId/pins/$messageId',
      method: 'POST',
    );
  }

  Future<void> unpinMessage(int conversationId, int messageId) async {
    await _apiClient.request(
      '${ApiEndpoints.conversations}/$conversationId/pins/$messageId',
      method: 'DELETE',
    );
  }

  Future<MessagesPage> getPinnedMessages(int conversationId) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.conversations}/$conversationId/pins',
      method: 'GET',
    );
    return MessagesPage.fromJson(response);
  }

  Future<void> starMessage(int messageId) async {
    await _apiClient.request(
      '${ApiEndpoints.messages}/$messageId/star',
      method: 'POST',
    );
  }

  Future<void> unstarMessage(int messageId) async {
    await _apiClient.request(
      '${ApiEndpoints.messages}/$messageId/star',
      method: 'DELETE',
    );
  }

  /// No `chat_id` filter anymore (§6.3) — always returns starred messages
  /// across every conversation.
  Future<MessagesPage> getStarredMessages({String? cursor, int limit = 30}) async {
    final params = <String>['limit=$limit'];
    if (cursor != null && cursor.isNotEmpty) {
      params.add('cursor=${Uri.encodeQueryComponent(cursor)}');
    }
    final response = await _apiClient.request(
      '${ApiEndpoints.messages}/starred?${params.join('&')}',
      method: 'GET',
    );
    return MessagesPage.fromJson(response);
  }

  Future<void> deleteForMe(int messageId) async {
    await _apiClient.request(
      '${ApiEndpoints.messages}/$messageId/me',
      method: 'DELETE',
    );
  }

  /// `PATCH /messages/:messageId {body}` — sender-only, text body only (type,
  /// attachments, reply-to are immutable). Returns the full updated message;
  /// the same payload is also broadcast as `message_updated` to the room.
  /// Server errors: 404 not found, 403 not the sender, 400 already deleted.
  Future<MessageDto> editMessage(int messageId, String body) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.messages}/$messageId',
      method: 'PATCH',
      body: {'body': body},
    );
    final json =
        response is Map<String, dynamic> && response['data'] is Map
            ? (response['data'] as Map).cast<String, dynamic>()
            : response as Map<String, dynamic>;
    return MessageDto.fromJson(json);
  }

  /// Does not clear pin/star state on the message (§6.7 breaking change #11).
  Future<void> deleteForEveryone(int messageId) async {
    await _apiClient.request(
      '${ApiEndpoints.messages}/$messageId',
      method: 'DELETE',
    );
  }

  // Reactions — brand new capability, no OLD equivalent, no socket event
  // fires on add/remove (§6.4/§6.7) — callers must poll/re-fetch. Verified
  // against actual backend DTO (ReactDto, src/reactions/dto/react.dto.ts):
  // the request field is `reactionCode`, not `emoji` — sending `emoji`
  // gets rejected outright (global ValidationPipe's forbidNonWhitelisted +
  // missing required field = HTTP 400 on every call).
  Future<void> addReaction(int messageId, String emoji) async {
    await _apiClient.request(
      '${ApiEndpoints.messages}/$messageId/reactions',
      method: 'POST',
      body: {'reactionCode': emoji},
    );
  }

  // DELETE :messageId/reactions takes no body at all (removes the caller's
  // own reaction regardless of which one) — nothing to send here.
  Future<void> removeReaction(int messageId, String emoji) async {
    await _apiClient.request(
      '${ApiEndpoints.messages}/$messageId/reactions',
      method: 'DELETE',
    );
  }

  Future<List<dynamic>> getReactions(int messageId) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.messages}/$messageId/reactions',
      method: 'GET',
    );
    if (response is List) return response;
    if (response is Map && response['data'] is List) {
      return response['data'] as List;
    }
    return const [];
  }

  // Polls — own resource now, multi-select opaque optionIds, no socket
  // event fires on vote (§6.2/§6.4/§6.7) — callers must poll/re-fetch.
  // Verified against actual backend DTO (CreatePollDto,
  // src/polls/dto/create-poll.dto.ts): there is no `allowMultiple` field at
  // all — it's `pollType: 'single_choice' | 'multiple_choice'`. Sending
  // `allowMultiple` was being rejected outright (global ValidationPipe's
  // forbidNonWhitelisted = HTTP 400 on every poll creation).
  Future<Map<String, dynamic>> createPoll(
    int conversationId, {
    required String question,
    required List<String> options,
    bool allowMultiple = false,
  }) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.conversations}/$conversationId/polls',
      method: 'POST',
      body: {
        'question': question,
        'options': options,
        'pollType': allowMultiple ? 'multiple_choice' : 'single_choice',
      },
    );
    return response is Map<String, dynamic> ? response : {};
  }

  Future<Map<String, dynamic>?> getPoll(String pollId) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.polls}/$pollId',
      method: 'GET',
    );
    return response is Map<String, dynamic> ? response : null;
  }

  /// Multi-select, opaque option ids — not OLD's single text `option`.
  Future<void> votePoll(String pollId, List<String> optionIds) async {
    await _apiClient.request(
      '${ApiEndpoints.polls}/$pollId/vote',
      method: 'POST',
      body: {'optionIds': optionIds},
    );
  }

  Future<void> closePoll(String pollId) async {
    await _apiClient.request(
      '${ApiEndpoints.polls}/$pollId/close',
      method: 'POST',
    );
  }
}

String idOf(dynamic value) => IdCodec.toId(value);
