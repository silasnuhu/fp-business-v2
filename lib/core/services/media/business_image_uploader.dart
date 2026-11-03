import 'dart:io';

import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/services/media/media_upload_service.dart';
import 'package:whoxa/utils/logger.dart';

/// Uploads business images (cover photo, product photos) and returns the URL
/// to store in `cover_image_url` / `images[]`.
///
/// The catalog and business-profile endpoints don't take files (§2.2, §4.1):
/// the image goes through the media upload API first and the returned URL is
/// what gets saved.
class BusinessImageUploader {
  /// `context` for `POST /media/upload-url`: the backend added a dedicated
  /// `business` context for cover and catalog images.
  static const String uploadContext = 'business';

  final MediaUploadService _media;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'BusinessImageUploader',
  );

  BusinessImageUploader(ApiClient apiClient)
    : _media = MediaUploadService(apiClient);

  /// Returns the confirmed `cdnUrl`, or null if the upload failed.
  Future<String?> upload(File file) async {
    final uploaded = await _media.upload(file: file, context: uploadContext);
    final url = uploaded?.cdnUrl;
    if (url == null || url.isEmpty) {
      _logger.e('Upload of ${file.path} returned no cdnUrl');
      return null;
    }
    return url;
  }

  /// Uploads every file, in order. Throws if any upload fails so a product is
  /// never saved with a silently missing photo.
  Future<List<String>> uploadAll(List<File> files) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await upload(file);
      if (url == null) {
        throw Exception('Image upload failed');
      }
      urls.add(url);
    }
    return urls;
  }
}
