// Shared client-side media compression for outgoing uploads (chat, story).
// Mirrors the thresholds already proven in StoryProvider — extracted here so
// the chat send path can reuse the same behavior instead of uploading raw
// picked files.

import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:whoxa/utils/logger.dart';

final ConsoleAppLogger _logger = ConsoleAppLogger.forModule('MediaCompress');

/// Compresses an image before upload. Returns the original [file] unchanged
/// if compression fails for any reason — never blocks a send on this.
Future<File> compressOutgoingImage(File file) async {
  try {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 70,
    );

    if (compressed != null) {
      _logger.i('Image compressed: ${file.path} -> ${compressed.path}');
      return File(compressed.path);
    }
  } catch (e) {
    _logger.e('Image compression failed, sending original', e);
  }
  return file;
}

/// Compresses a video before upload if it's larger than 10MB (matching
/// StoryProvider's threshold). Returns the original [file] unchanged if it's
/// already small, or if compression fails for any reason.
Future<File> compressOutgoingVideo(File file) async {
  try {
    double originalSizeMB;
    try {
      final info = await VideoCompress.getMediaInfo(file.path);
      originalSizeMB = (info.filesize ?? 0) / (1024 * 1024);
    } catch (_) {
      originalSizeMB = (await file.length()) / (1024 * 1024);
    }

    if (originalSizeMB <= 10.0) {
      return file;
    }

    _logger.i(
      'Video ${originalSizeMB.toStringAsFixed(2)}MB > 10MB — compressing',
    );
    final compressedInfo = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
      frameRate: 30,
    );

    if (compressedInfo?.path != null) {
      _logger.i('Video compressed: ${file.path} -> ${compressedInfo!.path}');
      return File(compressedInfo.path!);
    }
  } catch (e) {
    _logger.e('Video compression failed, sending original', e);
  }
  return file;
}
