import 'package:whoxa/core/api/id_codec.dart';

// Raw NEW-shaped DTOs for the `/conversations` resource (§5.2/§5.5 of the
// migration guide). The guide describes this shape only in prose — no
// literal JSON sample is given — so field names here are inferred from the
// confirmed facts: `participants[].role` ("owner"|"member") replaces
// `is_admin`; `avatarMediaId` replaces `group_icon`; unread is computed as
// `lastMessageSeq - participant.lastReadSeq`; pagination is `nextCursor`
// only, no totals. These DTOs are consumed only by ConversationRepository
// and ConversationAdapter — UI code never sees them directly, it keeps
// reading the existing `Chats`/`Records`/`Participants` models via the
// adapter, so a wrong field guess here is a contained, single-file fix.
class ConversationsPage {
  final List<ConversationDto> items;
  final String? nextCursor;

  ConversationsPage({required this.items, this.nextCursor});

  factory ConversationsPage.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    final rawItems = json is List ? json : (map['items'] ?? map['data']);
    final items =
        rawItems is List
            ? rawItems
                .whereType<Map>()
                .map((e) => ConversationDto.fromJson(e.cast<String, dynamic>()))
                .toList()
            : <ConversationDto>[];
    return ConversationsPage(
      items: items,
      nextCursor: map['nextCursor'] as String?,
    );
  }
}

class ConversationDto {
  final String id;
  final String type; // "direct" | "group"
  final String? title;
  final String? description;
  final String? avatarMediaId;
  final String? createdBy;
  final int lastMessageSeq;
  final List<ConversationParticipantDto> participants;
  final String? createdAt;
  final String? updatedAt;

  ConversationDto({
    required this.id,
    required this.type,
    this.title,
    this.description,
    this.avatarMediaId,
    this.createdBy,
    required this.lastMessageSeq,
    required this.participants,
    this.createdAt,
    this.updatedAt,
  });

  factory ConversationDto.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'];
    return ConversationDto(
      // ConversationsService.toPublicConversation returns `conversationId`,
      // not `id` — confirmed against backend source. `id` is kept as a
      // fallback only in case some other endpoint ever shapes it that way.
      id: IdCodec.toId(json['conversationId'] ?? json['id']),
      type: json['type'] as String? ?? 'direct',
      title: json['title'] as String?,
      description: json['description']?.toString(),
      avatarMediaId: json['avatarMediaId'] as String?,
      createdBy: IdCodec.toIdOrNull(json['createdBy']),
      lastMessageSeq: IdCodec.toIntOrZero(json['lastMessageSeq']),
      participants:
          rawParticipants is List
              ? rawParticipants
                  .whereType<Map>()
                  .map(
                    (p) => ConversationParticipantDto.fromJson(
                      p.cast<String, dynamic>(),
                    ),
                  )
                  .toList()
              : <ConversationParticipantDto>[],
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class ConversationParticipantDto {
  final String userId;
  final String role; // "owner" | "member"
  final int? lastReadSeq;
  final int? lastDeliveredSeq;
  final String? leftAt;
  final bool isPinned;
  final bool isFavorite;
  final bool isMuted;
  final bool isArchived;
  final List<String> labelIds;

  ConversationParticipantDto({
    required this.userId,
    required this.role,
    this.lastReadSeq,
    this.lastDeliveredSeq,
    this.leftAt,
    this.isPinned = false,
    this.isFavorite = false,
    this.isMuted = false,
    this.isArchived = false,
    this.labelIds = const [],
  });

  factory ConversationParticipantDto.fromJson(Map<String, dynamic> json) {
    return ConversationParticipantDto(
      userId: IdCodec.toId(json['userId'] ?? json['user_id']),
      role: json['role'] as String? ?? 'member',
      lastReadSeq: IdCodec.toIntOrNull(json['lastReadSeq']),
      lastDeliveredSeq: IdCodec.toIntOrNull(json['lastDeliveredSeq']),
      leftAt: json['leftAt'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      labelIds:
          (json['labelIds'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
    );
  }
}
