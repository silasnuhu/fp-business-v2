import 'package:whoxa/core/api/id_codec.dart';

// Raw NEW-shaped DTO for `/notifications` (§9.2/§9.3 of the migration
// guide). The guide confirms this feed is genuinely new (OLD had no
// per-user feed at all) and gives the 4 endpoint paths, but no literal
// JSON sample of a notification object — field names below (`id`, `title`,
// `body`, `isRead`, `createdAt`) are inferred, not confirmed. NEW's writer
// (`NotificationsService.notifyMany()`) is now called from both
// `MessagesService` (on every message send) and `CallsService` (on ring),
// so this feed is populated in practice.
class NotificationDto {
  final String id;
  final String? title;
  final String? body;
  final bool isRead;
  final String? createdAt;

  NotificationDto({
    required this.id,
    this.title,
    this.body,
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    return NotificationDto(
      id: IdCodec.toId(json['id']),
      title: json['title'] as String?,
      body: (json['body'] ?? json['message']) as String?,
      isRead: (json['isRead'] as bool?) ?? (json['read'] as bool?) ?? false,
      createdAt: json['createdAt'] as String?,
    );
  }

  static List<NotificationDto> listFromResponse(dynamic response) {
    final items =
        response is List
            ? response
            : (response is Map ? response['items'] ?? response['data'] : null);
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => NotificationDto.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
