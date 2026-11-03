import 'package:whoxa/core/api/id_codec.dart';

// Raw NEW-shaped DTO for `/stories` (§8.2/§8.3 of the migration guide).
// Confirmed against actual `GET /stories/feed` + `GET /stories/user/:id`
// responses: `{storyId, uuid, userId, type, mediaId (number), media: {
// cdnUrl, thumbnailUrl, mimeType, durationSeconds }, caption,
// backgroundColor, fontStyle, visibility, createdAt, expiresAt, deletedAt,
// hasViewed}`. The media URL is nested under `media.cdnUrl`, NOT a flat
// `mediaUrl`/`cdnUrl` field, and `mediaId` is a number not a string —
// casting either the old way threw and broke the whole Status tab.
class StoryDto {
  final String id;
  final String userId;
  final String type; // "image" | "video" | "text"
  final String? mediaId;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? caption;
  final String? backgroundColor;
  final String? fontStyle;
  final bool hasViewed;
  final String? createdAt;
  final String? expiresAt;

  StoryDto({
    required this.id,
    required this.userId,
    required this.type,
    this.mediaId,
    this.mediaUrl,
    this.thumbnailUrl,
    this.caption,
    this.backgroundColor,
    this.fontStyle,
    this.hasViewed = false,
    this.createdAt,
    this.expiresAt,
  });

  factory StoryDto.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['media'];
    final media = rawMedia is Map ? rawMedia.cast<String, dynamic>() : const {};
    return StoryDto(
      id: IdCodec.toId(json['storyId'] ?? json['id']),
      userId: IdCodec.toId(
        json['userId'] ?? json['authorId'] ?? json['user_id'],
      ),
      type: (json['type'] as String?) ?? 'image',
      mediaId: IdCodec.toIdOrNull(json['mediaId']),
      mediaUrl:
          (media['cdnUrl'] ??
                  json['mediaUrl'] ??
                  json['cdnUrl'] ??
                  (rawMedia is String ? rawMedia : null))
              as String?,
      thumbnailUrl: media['thumbnailUrl'] as String?,
      caption: json['caption'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
      fontStyle: json['fontStyle'] as String?,
      hasViewed: (json['hasViewed'] as bool?) ?? false,
      createdAt: json['createdAt'] as String?,
      expiresAt: json['expiresAt'] as String?,
    );
  }

  static List<StoryDto> listFromResponse(dynamic response) {
    final items =
        response is List
            ? response
            : (response is Map ? response['items'] ?? response['data'] : null);
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => StoryDto.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
