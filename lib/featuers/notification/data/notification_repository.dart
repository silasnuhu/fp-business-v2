import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/notification/data/notification_dto.dart';
import 'package:whoxa/utils/logger.dart';

// REST client for NEW's genuinely new per-user notification feed
// (§9.2/§9.3) — OLD had no such thing, only an admin broadcast-to-all
// system with no NEW equivalent at all.
class NotificationRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'NotificationRepository',
  );

  NotificationRepository(this._apiClient);

  Future<List<NotificationDto>> getNotifications({
    String? cursor,
    int limit = 30,
  }) async {
    final params = <String>['limit=$limit'];
    if (cursor != null && cursor.isNotEmpty) {
      params.add('cursor=${Uri.encodeQueryComponent(cursor)}');
    }
    final response = await _apiClient.request(
      '${ApiEndpoints.notifications}?${params.join('&')}',
      method: 'GET',
    );
    return NotificationDto.listFromResponse(response);
  }

  /// Returns 0 on any failure rather than throwing — this backs a UI badge,
  /// so a transient/unexpected error shouldn't surface to the user.
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.request(
        '${ApiEndpoints.notifications}/unread-count',
        method: 'GET',
      );
      if (response is Map<String, dynamic>) {
        final count = response['count'] ?? response['unreadCount'] ?? response['data'];
        if (count is int) return count;
        if (count is Map && count['count'] is int) return count['count'] as int;
      }
      if (response is int) return response;
      return 0;
    } catch (e) {
      _logger.e('Error fetching unread notification count: $e');
      return 0;
    }
  }

  Future<void> markRead(String notificationId) async {
    await _apiClient.request(
      '${ApiEndpoints.notifications}/$notificationId/read',
      method: 'POST',
    );
  }

  Future<void> markAllRead() async {
    await _apiClient.request(
      '${ApiEndpoints.notifications}/read-all',
      method: 'POST',
    );
  }
}
