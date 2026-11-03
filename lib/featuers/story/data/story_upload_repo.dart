import 'dart:io';

import 'package:video_compress/video_compress.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/id_codec.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/core/services/media/media_upload_service.dart';
import 'package:whoxa/featuers/chat/repository/conversation_repository.dart';
import 'package:whoxa/featuers/story/data/model/delete_story_model.dart';
import 'package:whoxa/featuers/story/data/model/get_all_story_model.dart';
import 'package:whoxa/featuers/story/data/model/story_upload_model.dart'
    as upload_model;
import 'package:whoxa/featuers/story/data/model/viewed_story_model.dart'
    as viewed_model;
import 'package:whoxa/featuers/story/data/model/viewed_user_list_model.dart'
    as viewers_model;
import 'package:whoxa/featuers/story/data/story_dto.dart';
import 'package:whoxa/featuers/story/data/story_repository.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

// NEW's story surface (§8.2/§8.3) is JSON+pre-uploaded mediaId, a flat
// cursor-paginated feed, path-param view/delete, and an author-only
// separate viewers call — a full protocol change, not a field rename. This
// repo keeps the OLD method names/signatures and OLD-shaped response
// models (GetAllStoriesModel's bucketed recent/viewed/my-stories shape,
// etc.) so `story_provider.dart` and every screen under
// lib/featuers/story/screens/ need zero changes — the adapting happens
// entirely in here, same pattern as ConversationAdapter/MessageAdapter
// from earlier phases.
class StoryUploadRepo {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger();
  late final StoryRepository _storyRepository = StoryRepository(_apiClient);
  late final MediaUploadService _mediaUploadService = MediaUploadService(
    _apiClient,
  );
  late final ConversationRepository _conversationRepository =
      ConversationRepository(_apiClient);

  StoryUploadRepo(this._apiClient);

  //************************************************************************************/
  //************************************** UPLOAD STORY ********************************/
  //************************************************************************************/
  upload_model.StoryUploadModel storyUploadModel =
      upload_model.StoryUploadModel();

  /// [storyType] stays "image"/"video" (this method's callers don't yet
  /// offer NEW's new text-only story type — that's new UI work, not
  /// wired here). Uploads the file via the canonical presigned-upload flow
  /// (context: "status") first, then creates the story referencing the
  /// resulting mediaId. For video, `thumbnailPath` is uploaded first as its
  /// own image and its `cdnUrl` is passed as the video's `thumbnailUrl` on
  /// confirm, along with the video's duration/dimensions.
  Future<upload_model.StoryUploadModel> stroyUploadRepo(
    String storyType,
    File storyFile,
    String? caption,
    String? thumbnailPath,
  ) async {
    _logger.i('StoryType: $storyType');
    _logger.i('StoryFile: $storyFile');
    _logger.i('StoryCaption: $caption');

    try {
      String? thumbnailUrl;
      _VideoMeta? videoMeta;
      if (storyType == 'video') {
        if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
          thumbnailUrl = await _uploadThumbnail(File(thumbnailPath));
        }
        videoMeta = await _readVideoMeta(storyFile.path);
      }

      final uploaded = await _mediaUploadService.upload(
        file: storyFile,
        context: 'status',
        width: videoMeta?.width,
        height: videoMeta?.height,
        durationSeconds: videoMeta?.durationSeconds,
        thumbnailUrl: thumbnailUrl,
      );
      if (uploaded == null) {
        throw Exception('Failed to upload story media');
      }

      final story = await _storyRepository.createStory(
        type: storyType,
        mediaId: uploaded.mediaId,
        caption: (caption != null && caption.isNotEmpty) ? caption : null,
      );

      storyUploadModel = upload_model.StoryUploadModel(
        status: true,
        message: 'Story uploaded',
        data: upload_model.Data(
          media: story.mediaUrl,
          expiresAt: story.expiresAt,
          storyId: int.tryParse(story.id),
          storyType: story.type,
          userId: int.tryParse(story.userId),
          caption: story.caption,
          createdAt: story.createdAt,
        ),
      );
      return storyUploadModel;
    } catch (e) {
      _logger.e('Error adding stroy:', e.toString());
      rethrow;
    }
  }

  /// A missing thumbnail shouldn't block the story itself, so failures
  /// here just log and return null.
  Future<String?> _uploadThumbnail(File thumbnail) async {
    if (!await thumbnail.exists()) return null;
    final uploaded = await _mediaUploadService.upload(
      file: thumbnail,
      context: 'status',
    );
    if (uploaded?.cdnUrl == null) {
      _logger.w('Story thumbnail upload failed, continuing without it');
    }
    return uploaded?.cdnUrl;
  }

  Future<_VideoMeta?> _readVideoMeta(String path) async {
    try {
      final info = await VideoCompress.getMediaInfo(path);
      int? width = info.width;
      int? height = info.height;
      // Dimensions are reported pre-rotation; swap for portrait recordings.
      if (info.orientation == 90 || info.orientation == 270) {
        final tmp = width;
        width = height;
        height = tmp;
      }
      final durationMs = info.duration;
      return _VideoMeta(
        width: width,
        height: height,
        durationSeconds:
            durationMs != null
                ? double.parse((durationMs / 1000).toStringAsFixed(1))
                : null,
      );
    } catch (e) {
      _logger.w('Could not read video metadata for $path: $e');
      return null;
    }
  }

  //************************************************************************************/
  //************************************** GET ALL STORIES *****************************/
  //************************************************************************************/
  GetAllStoriesModel getStories = GetAllStoriesModel();

  /// NEW's flat `GET /stories/feed` (others) + `GET /stories/user/:id`
  /// (mine) replace OLD's single bucketed response — reconstructs the same
  /// recent/viewed/my-stories shape client-side: an author whose stories
  /// are ALL `hasViewed` goes in `viewedStories`, everyone else with at
  /// least one unviewed story goes in `recentStories`. Per-author profile
  /// fields are resolved via `GET /users/:id` (batched), same as
  /// ConversationAdapter's peer-profile resolution in Phase 4 — field
  /// names there are best-effort/unconfirmed, same caveat applies here.
  Future<GetAllStoriesModel> getAllStoriesRepo() async {
    try {
      final myId = await SecurePrefs.getString(SecureStorageKeys.USERID) ?? '';

      final results = await Future.wait([
        _storyRepository.getFeed(limit: 100),
        myId.isNotEmpty
            ? _storyRepository.getUserStories(myId)
            : Future.value(<StoryDto>[]),
      ]);
      final feed = results[0];
      final mine = results[1];

      final othersByAuthor = <String, List<StoryDto>>{};
      for (final story in feed) {
        if (story.userId == myId) continue; // avoid double-counting
        othersByAuthor.putIfAbsent(story.userId, () => []).add(story);
      }

      final profiles = await Future.wait(
        othersByAuthor.keys.map(
          (id) => _conversationRepository.getUserBasicProfile(id),
        ),
      );
      final profileByAuthor = <String, Map<String, dynamic>?>{};
      var i = 0;
      for (final id in othersByAuthor.keys) {
        profileByAuthor[id] = unwrapEnvelope(profiles[i]);
        i++;
      }

      final recent = <RecentStories>[];
      final viewed = <ViewedStories>[];
      othersByAuthor.forEach((authorId, stories) {
        final profile = profileByAuthor[authorId];
        final allViewed = stories.every((s) => s.hasViewed);
        final viewedCount = stories.where((s) => s.hasViewed).length;
        final mappedStories = stories.map(_toStories).toList();

        // `getUserBasicProfile` hits `GET /users/:id` =
        // `UsersService.toPublicUser()` (camelCase). `profilePic`/name parts
        // can all legitimately be null (photo hidden, name never set) — the
        // story viewer dereferences these non-null, so default them here.
        final fullName =
            (profile?['fullName'] ?? profile?['full_name']) as String?;
        String? firstName =
            (profile?['firstName'] ?? profile?['first_name']) as String?;
        String? lastName =
            (profile?['lastName'] ?? profile?['last_name']) as String?;
        if ((firstName == null || firstName.isEmpty) &&
            fullName != null &&
            fullName.trim().isNotEmpty) {
          final parts = fullName.trim().split(RegExp(r'\s+'));
          firstName = parts.first;
          lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }
        final userName =
            (profile?['userName'] ?? profile?['user_name']) as String?;
        final profilePic =
            (profile?['profilePic'] ?? profile?['profile_pic']) as String? ??
            '';

        if (allViewed) {
          viewed.add(
            ViewedStories(
              userId: int.tryParse(authorId),
              fullName: fullName,
              firstName: firstName ?? '',
              lastName: lastName ?? '',
              userName: userName,
              profilePic: profilePic,
              stories: mappedStories,
              storyCount: mappedStories.length,
              viewedCount: viewedCount,
            ),
          );
        } else {
          recent.add(
            RecentStories(
              userId: int.tryParse(authorId),
              fullName: fullName,
              firstName: firstName ?? '',
              lastName: lastName ?? '',
              userName: userName,
              profilePic: profilePic,
              stories: mappedStories,
              storyCount: mappedStories.length,
              viewedCount: viewedCount,
            ),
          );
        }
      });

      final myStories = mine.map(_toMyStories).toList();

      return getStories = GetAllStoriesModel(
        status: true,
        data: Data(
          recentStories: recent,
          viewedStories: viewed,
          myStories: myStories,
        ),
      );
    } catch (e) {
      _logger.e('Error stroy fetch:', e.toString());
      rethrow;
    }
  }

  Stories _toStories(StoryDto s) {
    return Stories(
      media: s.mediaUrl,
      thumbnail: s.thumbnailUrl,
      storyId: int.tryParse(s.id),
      userId: int.tryParse(s.userId),
      caption: s.caption,
      createdAt: s.createdAt,
      storyType: s.type,
    );
  }

  MyStories _toMyStories(StoryDto s) {
    return MyStories(
      media: s.mediaUrl,
      thumbnail: s.thumbnailUrl,
      storyId: int.tryParse(s.id),
      caption: s.caption,
      storyType: s.type,
      expiresAt: s.expiresAt,
      createdAt: s.createdAt,
      userId: int.tryParse(s.userId),
    );
  }

  //************************************************************************************/
  //************************************** VIEWED STORIES *****************************/
  //************************************************************************************/
  viewed_model.ViewedStoriesModel viewedStories =
      viewed_model.ViewedStoriesModel();

  /// Was `PUT .../view-story` with body {story_id} — now `POST
  /// /stories/:id/view`, path param.
  Future<viewed_model.ViewedStoriesModel> viewedStoryRepo({
    required String storyID,
  }) async {
    try {
      await _storyRepository.viewStory(storyID);
      return viewedStories = viewed_model.ViewedStoriesModel(status: true);
    } catch (e) {
      _logger.e('Error story viewed:', e.toString());
      rethrow;
    }
  }

  //************************************************************************************/
  //************************************** REMOVE STORIES *****************************/
  //************************************************************************************/
  DeleteStoryModel deleteStoryModel = DeleteStoryModel();

  /// Was `DELETE` with body {story_id} — now `DELETE /stories/:id`, path
  /// param, soft-delete (deletedAt) rather than a hard delete (§8.2).
  Future<DeleteStoryModel> removeStoryRepo({required String storyId}) async {
    _logger.d("storyID:$storyId");
    try {
      await _storyRepository.deleteStory(storyId);
      return deleteStoryModel = DeleteStoryModel(
        status: true,
        message: 'Story deleted',
      );
    } catch (e) {
      _logger.e('Error story remove:', e.toString());
      rethrow;
    }
  }

  //************************************************************************************/
  //************************************** VIEWED STORY USER LIST **********************/
  //************************************************************************************/
  viewers_model.ViewedUserListModel viewedUserListModel =
      viewers_model.ViewedUserListModel();

  /// Was `POST /story/get-story` with body {story_id} (an embedded-viewer
  /// fetch masquerading as a "get story" call) — now the separate,
  /// author-only `GET /stories/:id/viewers` (§8.2/§8.3). Per-viewer profile
  /// field names here are best-effort/unconfirmed, same caveat as
  /// elsewhere — the guide doesn't give this response shape verbatim.
  Future<viewers_model.ViewedUserListModel> viewedUserRepo({
    required String storyID,
  }) async {
    try {
      final viewers = await _storyRepository.getViewers(storyID);
      final views =
          viewers.whereType<Map>().map((v) {
            final json = v.cast<String, dynamic>();
            return viewers_model.Views(
              userId: int.tryParse(
                IdCodec.toId(json['userId'] ?? json['user_id']),
              ),
              // New backend (GET /stories/:id/viewers) returns camelCase
              // (userName / fullName / profilePic); keep snake_case fallbacks
              // for the old shape.
              fullName:
                  json['fullName'] as String? ?? json['full_name'] as String?,
              userName:
                  json['userName'] as String? ?? json['user_name'] as String?,
              profilePic:
                  json['profilePic'] as String? ??
                  json['profile_pic'] as String?,
              viewedAt:
                  json['viewedAt'] as String? ?? json['viewed_at'] as String?,
            );
          }).toList();

      // Viewer profiles carry `premiumUser`; record it for the blue tick, and
      // read `users/batch` once for viewers whose payload did not include it.
      final viewerIds = <String>[];
      for (final v in viewers.whereType<Map>()) {
        final json = v.cast<String, dynamic>();
        ContactNameService.instance.noteUserProfile(json);
        final id = IdCodec.toId(json['userId'] ?? json['user_id']);
        if (id.isNotEmpty && json['premiumUser'] == null) viewerIds.add(id);
      }
      if (viewerIds.isNotEmpty) {
        _conversationRepository
            .getUserBasicProfiles(viewerIds)
            .catchError((_) => <String, Map<String, dynamic>>{});
      }

      return viewedUserListModel = viewers_model.ViewedUserListModel(
        status: true,
        data: viewers_model.Data(storyId: int.tryParse(storyID), views: views),
      );
    } catch (e) {
      _logger.e('Error story viewed:', e.toString());
      rethrow;
    }
  }
}

class _VideoMeta {
  final int? width;
  final int? height;
  final double? durationSeconds;

  const _VideoMeta({this.width, this.height, this.durationSeconds});
}
