import 'package:whoxa/core/api/id_codec.dart';

// NEW-shaped DTOs for the `/messages` resource. Field names are confirmed
// directly against `MessagesService`/`ConversationsService.toPublicMessage`
// on the backend (both the send-request body and the GET-response shape),
// not inferred.
class MessagesPage {
  final List<MessageDto> items;
  final String? nextCursor;
  final bool hasMore;

  MessagesPage({required this.items, this.nextCursor, this.hasMore = false});

  factory MessagesPage.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    final rawItems = json is List ? json : (map['items'] ?? map['data']);
    final items =
        rawItems is List
            ? rawItems
                .whereType<Map>()
                .map((e) => MessageDto.fromJson(e.cast<String, dynamic>()))
                .toList()
            : <MessageDto>[];
    return MessagesPage(
      items: items,
      nextCursor: map['nextCursor'] as String?,
      hasMore: (map['hasMore'] as bool?) ?? (map['nextCursor'] != null),
    );
  }
}

/// One entry of `MessageDto.attachments` (`{attachmentId, mediaId,
/// displayOrder, cdnUrl, thumbnailUrl, mimeType}` per
/// `MessagesService.toPublicMessage`).
class MessageAttachmentDto {
  final String attachmentId;
  final String mediaId;
  final int displayOrder;
  final String cdnUrl;
  final String? thumbnailUrl;
  final String? mimeType;

  MessageAttachmentDto({
    required this.attachmentId,
    required this.mediaId,
    required this.displayOrder,
    required this.cdnUrl,
    this.thumbnailUrl,
    this.mimeType,
  });

  factory MessageAttachmentDto.fromJson(Map<String, dynamic> json) {
    return MessageAttachmentDto(
      attachmentId: IdCodec.toId(json['attachmentId']),
      mediaId: IdCodec.toId(json['mediaId']),
      displayOrder: IdCodec.toIntOrZero(json['displayOrder']),
      cdnUrl: json['cdnUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      mimeType: json['mimeType'] as String?,
    );
  }
}

/// One entry of `MessageDto.reactions` (`{userId, reactionCode, createdAt}`
/// per `MessagesService.toPublicMessage`).
class MessageReactionDto {
  final String userId;
  final String reactionCode;
  final String? createdAt;

  MessageReactionDto({
    required this.userId,
    required this.reactionCode,
    this.createdAt,
  });

  factory MessageReactionDto.fromJson(Map<String, dynamic> json) {
    return MessageReactionDto(
      userId: IdCodec.toId(json['userId']),
      reactionCode: json['reactionCode'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
    );
  }
}

class MessageDto {
  final String id;
  final String uuid;
  final String conversationId;
  final String? clientMessageId;
  final String type;
  final String? body;
  final List<String> attachmentMediaIds;
  final List<MessageAttachmentDto> attachments;
  final List<MessageReactionDto> reactions;
  final String? replyToMessageId;
  final String? forwardOfMessageId;
  final int forwardCount;
  final bool isEdited;
  final String? editedAt;
  final bool isDeletedForEveryone;
  final Map<String, dynamic>? metadata;
  /// The embedded poll relation `MessagesService.toPublicMessage` ships on
  /// `type: 'poll'` messages — `{pollId, question, pollType, options: [...]}`,
  /// the same shape `GET /polls/:id` returns. Null for every other type.
  final Map<String, dynamic>? poll;
  final String senderId;
  final int conversationSeq;
  final String? createdAt;
  final String? updatedAt;

  /// Only `GET /messages/starred` carries these (MessagesService.listStarred
  /// joins the conversation onto each row): the starred list is cross-chat,
  /// so each item has to say which conversation it came from. Null on every
  /// other message endpoint, where the conversation is already known from
  /// the request path.
  final String? conversationType; // "direct" | "group"
  final String? conversationTitle;
  final String? otherParticipantId; // direct conversations only

  MessageDto({
    required this.id,
    this.uuid = '',
    required this.conversationId,
    this.clientMessageId,
    required this.type,
    this.body,
    this.attachmentMediaIds = const [],
    this.attachments = const [],
    this.reactions = const [],
    this.replyToMessageId,
    this.forwardOfMessageId,
    this.forwardCount = 0,
    this.isEdited = false,
    this.editedAt,
    this.isDeletedForEveryone = false,
    this.metadata,
    this.poll,
    required this.senderId,
    required this.conversationSeq,
    this.createdAt,
    this.updatedAt,
    this.conversationType,
    this.conversationTitle,
    this.otherParticipantId,
  });

  factory MessageDto.fromJson(Map<String, dynamic> json) {
    final rawAttachmentIds = json['attachmentMediaIds'];
    final rawAttachments = json['attachments'];
    final rawReactions = json['reactions'];
    return MessageDto(
      id: IdCodec.toId(json['messageId'] ?? json['id']),
      uuid: json['uuid'] as String? ?? '',
      conversationId: IdCodec.toId(json['conversationId']),
      clientMessageId: json['clientMessageId'] as String?,
      type: json['type'] as String? ?? 'text',
      // `GET /conversations/:id/pins` names the text field `messageBody`
      // rather than `body` (ReactionsService.listPins) — fall back to it so
      // pinned-message previews aren't blank.
      body: json['body'] as String? ?? json['messageBody'] as String?,
      attachmentMediaIds:
          rawAttachmentIds is List
              ? rawAttachmentIds.map((e) => e.toString()).toList()
              : const [],
      attachments:
          rawAttachments is List
              ? rawAttachments
                  .whereType<Map>()
                  .map(
                    (e) =>
                        MessageAttachmentDto.fromJson(e.cast<String, dynamic>()),
                  )
                  .toList()
              : const [],
      reactions:
          rawReactions is List
              ? rawReactions
                  .whereType<Map>()
                  .map(
                    (e) => MessageReactionDto.fromJson(e.cast<String, dynamic>()),
                  )
                  .toList()
              : const [],
      replyToMessageId: IdCodec.toIdOrNull(json['replyToMessageId']),
      forwardOfMessageId: IdCodec.toIdOrNull(json['forwardOfMessageId']),
      forwardCount: IdCodec.toIntOrZero(json['forwardCount']),
      isEdited: json['isEdited'] as bool? ?? false,
      editedAt: json['editedAt'] as String?,
      isDeletedForEveryone: json['isDeletedForEveryone'] as bool? ?? false,
      metadata:
          json['metadata'] is Map
              ? (json['metadata'] as Map).cast<String, dynamic>()
              : null,
      poll:
          json['poll'] is Map
              ? (json['poll'] as Map).cast<String, dynamic>()
              : null,
      senderId: IdCodec.toId(json['senderId']),
      // MessagesService serializes this as `message.conversationSeq.toString()`
      // (BigInt-backed), never a plain JSON number — see IdCodec.toIntOrZero.
      conversationSeq: IdCodec.toIntOrZero(json['conversationSeq']),
      // `GET /messages/starred` items carry `starredAt` instead of
      // `createdAt`/`updatedAt` (MessagesService.listStarred) — fall back to
      // it so starred-list rows have a timestamp to render.
      createdAt: json['createdAt'] as String? ?? json['starredAt'] as String?,
      updatedAt:
          json['updatedAt'] as String? ?? json['starredAt'] as String?,
      conversationType: json['conversationType'] as String?,
      conversationTitle: json['conversationTitle'] as String?,
      otherParticipantId: IdCodec.toIdOrNull(json['otherParticipantId']),
    );
  }

  /// The primary attachment's CDN URL, if any — the field the OLD-shaped
  /// UI models (`Records.message_content` etc.) expect a direct media URL
  /// in, since NEW moved that into a separate `attachments[]` array.
  String? get primaryAttachmentUrl =>
      attachments.isEmpty ? null : attachments.first.cdnUrl;

  String? get primaryAttachmentThumbnailUrl =>
      attachments.isEmpty
          ? null
          : (attachments.first.thumbnailUrl ?? attachments.first.cdnUrl);

  /// For `type == 'poll'` messages: the id lives on the embedded `poll`
  /// relation the message payload carries. Older payloads put only a
  /// `{ pollId }` in `metadata` instead, so both are accepted; either way
  /// it lets a client re-resolve the poll via `GET /polls/:pollId`.
  String? get pollId {
    final raw = poll?['pollId'] ?? metadata?['pollId'] ?? metadata?['poll_id'];
    if (raw == null) return null;
    final s = raw.toString();
    return s.isEmpty ? null : s;
  }
}
