// ignore_for_file: use_null_aware_elements

import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/story/data/story_dto.dart';
import 'package:whoxa/utils/logger.dart';

// REST client for NEW's `/stories` resource (§8.2/§8.3). Replaces OLD's
// multipart upload-story + bucketed get-stories with a JSON+mediaId flow
// and a flat, cursor-paginated feed.
class StoryRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'StoryRepository',
  );

  StoryRepository(this._apiClient);

  /// Creates a story. Media must already be uploaded (MediaUploadService)
  /// — `type: "text"` stories need no mediaId at all (new capability, no
  /// OLD equivalent). `visibleToUserIds` is audience targeting, also new.
  Future<StoryDto> createStory({
    required String type,
    String? mediaId,
    String? caption,
    String? backgroundColor,
    String? fontStyle,
    String? visibility,
    List<String>? visibleToUserIds,
  }) async {
    final body = {
      'type': type,
      if (mediaId != null) 'mediaId': mediaId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
      if (fontStyle != null) 'fontStyle': fontStyle,
      if (visibility != null) 'visibility': visibility,
      if (visibleToUserIds != null) 'visibleToUserIds': visibleToUserIds,
    };
    final response = await _apiClient.request(
      ApiEndpoints.stories,
      method: 'POST',
      body: body,
    );
    return StoryDto.fromJson(response as Map<String, dynamic>);
  }

  /// Flat, cursor-paginated feed — replaces OLD's server-bucketed
  /// recent/viewed/my-stories shape (§8.2 breaking change: entirely
  /// different response structure).
  Future<List<StoryDto>> getFeed({String? cursor, int limit = 50}) async {
    final params = <String>['limit=$limit'];
    if (cursor != null && cursor.isNotEmpty) {
      params.add('cursor=${Uri.encodeQueryComponent(cursor)}');
    }
    final response = await _apiClient.request(
      '${ApiEndpoints.stories}/feed?${params.join('&')}',
      method: 'GET',
    );
    return StoryDto.listFromResponse(response);
  }

  Future<List<StoryDto>> getUserStories(String userId) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.stories}/user/$userId',
      method: 'GET',
    );
    return StoryDto.listFromResponse(response);
  }

  /// Was `PUT .../view-story` with a body — now a path param, POST.
  Future<void> viewStory(String storyId) async {
    await _apiClient.request(
      '${ApiEndpoints.stories}/$storyId/view',
      method: 'POST',
    );
  }

  /// Was `DELETE` with a body — now a path param; soft-delete (deletedAt)
  /// rather than a hard delete (§8.2).
  Future<void> deleteStory(String storyId) async {
    await _apiClient.request(
      '${ApiEndpoints.stories}/$storyId',
      method: 'DELETE',
    );
  }

  /// Author-only — replaces the embedded viewer array OLD had on the story
  /// row itself (§8.2/§8.3).
  Future<List<dynamic>> getViewers(String storyId) async {
    try {
      final response = await _apiClient.request(
        '${ApiEndpoints.stories}/$storyId/viewers',
        method: 'GET',
      );
      if (response is List) return response;
      if (response is Map && response['data'] is List) {
        return response['data'] as List;
      }
      return const [];
    } catch (e) {
      _logger.e('Error fetching story viewers: $e');
      return const [];
    }
  }

  // New capability, no OLD equivalent.
  Future<void> reactToStory(String storyId, String emoji) async {
    await _apiClient.request(
      '${ApiEndpoints.stories}/$storyId/react',
      method: 'POST',
      body: {'emoji': emoji},
    );
  }

  Future<void> removeReaction(String storyId) async {
    await _apiClient.request(
      '${ApiEndpoints.stories}/$storyId/react',
      method: 'DELETE',
    );
  }
}
