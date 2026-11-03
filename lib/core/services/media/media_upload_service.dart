// ignore_for_file: use_null_aware_elements

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/utils/logger.dart';

/// Reusable upload state machine for NEW's presigned-upload flow (§8.2):
///   1. POST /media/upload-url {filename, mimeType, sizeBytes, context}
///      -> {mediaId, uploadUrl, storageKey, expiresIn}
///   2. PUT raw bytes to uploadUrl (S3 direct by default; a relative
///      `/media/local-upload/:token` path if MEDIAFLOW=LOCAL)
///   3. POST /media/{id}/confirm {storageKey, mimeType, sizeBytes, width?,
///      height?, durationSeconds?, thumbnailUrl?} -> cdnUrl
///
/// One instance is meant to be reused across chat attachments, stories, and
/// avatars — the only thing that varies is `context` (chat|group|status|
/// avatar) and which field the resulting mediaId gets attached to
/// (attachmentMediaIds / mediaId / avatarMediaId) by the caller.
class MediaUploadService {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'MediaUploadService',
  );

  MediaUploadService(this._apiClient);

  /// Uploads [file] and returns the resulting mediaId, or null on failure.
  /// [context] must be one of chat|group|status|avatar (§8.2/§8.4).
  Future<String?> uploadFile({
    required File file,
    required String context,
    void Function(double progress)? onProgress,
  }) async {
    final uploaded = await upload(
      file: file,
      context: context,
      onProgress: onProgress,
    );
    return uploaded?.mediaId;
  }

  /// Same flow as [uploadFile], but also sends the optional confirm-body
  /// metadata and returns the confirmed media's `cdnUrl` alongside its id.
  /// [width]/[height] apply to images and videos; [durationSeconds] and
  /// [thumbnailUrl] (the `cdnUrl` of a separately uploaded thumbnail image)
  /// are video-only.
  Future<UploadedMedia?> upload({
    required File file,
    required String context,
    int? width,
    int? height,
    double? durationSeconds,
    String? thumbnailUrl,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final fileName = file.uri.pathSegments.last;
      final mimeType = _guessMimeType(fileName);
      final sizeBytes = await file.length();

      final uploadUrlResponse = await _apiClient.request(
        '${ApiEndpoints.media}/upload-url',
        method: 'POST',
        body: {
          'filename': fileName,
          'mimeType': mimeType,
          'sizeBytes': sizeBytes,
          'context': context,
        },
      );

      final data =
          uploadUrlResponse is Map<String, dynamic>
              ? (uploadUrlResponse['data'] as Map<String, dynamic>? ??
                  uploadUrlResponse)
              : null;
      final mediaId = data?['mediaId']?.toString();
      final rawUploadUrl = data?['uploadUrl']?.toString();
      final storageKey = data?['storageKey']?.toString();

      if (mediaId == null || rawUploadUrl == null) {
        _logger.e('upload-url response missing mediaId/uploadUrl: $data');
        return null;
      }

      // A relative uploadUrl means the local (non-S3) upload flow — prefix
      // with the bare host. The guide doesn't confirm whether the server
      // returns this absolute or relative; this handles both defensively.
      final uploadUrl =
          rawUploadUrl.startsWith('http')
              ? rawUploadUrl
              : '${ApiEndpoints.socketUrl}$rawUploadUrl';

      onProgress?.call(0.1);

      // Plain, unauthenticated PUT of raw bytes — a fresh Dio instance so
      // the app's Bearer/logging interceptors never attach to this request
      // (an S3 presigned URL / local-upload token already carries its own
      // auth in the URL itself).
      final bytes = await file.readAsBytes();
      await Dio().put(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': mimeType,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(0.1 + 0.8 * (sent / total));
        },
      );

      final confirmResponse = await _apiClient.request(
        '${ApiEndpoints.media}/$mediaId/confirm',
        method: 'POST',
        body: {
          'storageKey': storageKey,
          'mimeType': mimeType,
          'sizeBytes': sizeBytes,
          if (width != null) 'width': width,
          if (height != null) 'height': height,
          if (durationSeconds != null) 'durationSeconds': durationSeconds,
          if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        },
      );

      final confirmed =
          confirmResponse is Map<String, dynamic>
              ? (confirmResponse['data'] as Map<String, dynamic>? ??
                  confirmResponse)
              : null;
      final cdnUrl = confirmed?['cdnUrl']?.toString();

      onProgress?.call(1.0);
      _logger.i('Uploaded ${file.path} -> mediaId $mediaId ($cdnUrl)');
      return UploadedMedia(mediaId: mediaId, cdnUrl: cdnUrl);
    } catch (e) {
      _logger.e('Media upload failed for ${file.path}: $e');
      return null;
    }
  }

  static String _guessMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mkv':
        return 'video/x-matroska';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Result of a confirmed upload: the id to attach to a story/message/avatar
/// and the public URL the server assigned it.
class UploadedMedia {
  final String mediaId;
  final String? cdnUrl;

  const UploadedMedia({required this.mediaId, this.cdnUrl});
}
