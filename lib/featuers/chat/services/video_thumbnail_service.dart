import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whoxa/utils/logger.dart';

/// Generates and caches poster-frame thumbnails for chat video attachments.
///
/// The NEW backend ships a *stubbed* video-thumbnail queue processor
/// (`notifications/processors/video-thumbnail.processor.ts` never runs
/// ffmpeg), so `attachment.thumbnailUrl` is effectively always null and
/// video bubbles had nothing to render. This service fills that gap on the
/// client: it extracts a frame from the video — local file *or* remote CDN
/// URL — once, writes it to the app cache dir, and hands the file back for
/// `Image.file`.
///
/// Caching is three-tiered so a screen full of the same forwarded clip, or
/// scrolling a photo back into view, never re-extracts:
///   * in-memory `source -> path` map (process lifetime)
///   * on-disk JPEG keyed by a stable hash of the source
///   * in-flight de-dupe so N simultaneous bubbles share one extraction
class VideoThumbnailService {
  VideoThumbnailService._();

  static final VideoThumbnailService instance = VideoThumbnailService._();

  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'VideoThumbnailService',
  );

  final Map<String, String> _memoryCache = {};
  final Map<String, Future<String?>> _inFlight = {};
  Directory? _cacheDir;

  /// Container extensions we'll attempt a thumbnail for. A source with no
  /// recognisable extension (a bare CDN URL) is still attempted — the native
  /// retriever decides what it can decode.
  static const Set<String> supportedExtensions = {
    'mp4',
    'mov',
    'm4v',
    'mkv',
    'webm',
    '3gp',
    '3gpp',
    'avi',
    'ts',
  };

  bool isSupportedVideo(String? source) {
    if (source == null || source.trim().isEmpty) return false;
    final ext = _extensionOf(source);
    if (ext == null) return true; // extension-less CDN URL — let the OS try
    return supportedExtensions.contains(ext);
  }

  /// True when [source] ends in a known *video* container extension — used to
  /// reject a "thumbnail" URL that is really just the video URL echoed back.
  bool isVideoExtension(String source) {
    final ext = _extensionOf(source);
    return ext != null && supportedExtensions.contains(ext);
  }

  /// Returns a ready thumbnail file path for [source] (a local path or an
  /// http(s) URL), generating + caching on first use. `null` on failure.
  Future<String?> getThumbnail(String source) async {
    final key = source.trim();
    if (key.isEmpty) return null;

    final cached = _memoryCache[key];
    if (cached != null && File(cached).existsSync()) return cached;

    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _generate(key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Seed the cache with a thumbnail already produced elsewhere (e.g. at send
  /// time, straight from the picked local file) so the outgoing bubble shows
  /// it instantly and the uploaded copy is never re-fetched just to decode a
  /// frame. [source] should be the URL the bubble will ultimately render.
  void seed(String source, String thumbnailPath) {
    final key = source.trim();
    if (key.isEmpty || thumbnailPath.isEmpty) return;
    if (File(thumbnailPath).existsSync()) {
      _memoryCache[key] = thumbnailPath;
    }
  }

  /// Cap on how much of a remote video we'll pull down purely to extract a
  /// frame when the native retriever can't stream it directly.
  static const int _maxDownloadBytes = 80 * 1024 * 1024;

  Future<String?> _generate(String source) async {
    try {
      final dir = await _ensureCacheDir();
      final target = '${dir.path}/vthumb_${_stableHash(source)}.jpg';

      final onDisk = File(target);
      if (onDisk.existsSync() && onDisk.lengthSync() > 0) {
        _memoryCache[source] = target;
        return target;
      }

      final isRemote =
          source.startsWith('http://') || source.startsWith('https://');

      // 1. Fast path — let the native retriever stream the frame directly.
      final direct = await _extractFrame(source, target);
      if (direct != null) {
        _memoryCache[source] = direct;
        return direct;
      }

      // 2. Fallback — some remote hosts (R2, redirect chains, MP4s whose
      //    `moov` atom sits at the end) can't be streamed frame-wise by the
      //    platform retriever. Pull the file down once and extract locally.
      if (isRemote) {
        final localVideo = await _downloadToTemp(source);
        if (localVideo != null) {
          try {
            final viaDownload = await _extractFrame(localVideo.path, target);
            if (viaDownload != null) {
              _memoryCache[source] = viaDownload;
              return viaDownload;
            }
          } finally {
            try {
              await localVideo.delete();
            } catch (_) {}
          }
        }
      }

      _logger.w('Thumbnail generation produced no file for $source');
      return null;
    } catch (e, s) {
      _logger.e('Video thumbnail generation failed for $source', e, s);
      return null;
    }
  }

  /// Runs one `thumbnailFile` pass. Returns the written path, or null if the
  /// plugin threw or produced an empty file.
  Future<String?> _extractFrame(String video, String target) async {
    try {
      final XFile file = await VideoThumbnail.thumbnailFile(
        video: video,
        thumbnailPath: target,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        maxHeight: 640,
        quality: 80,
      );
      final path = file.path;
      final f = File(path);
      if (path.isEmpty || !f.existsSync() || f.lengthSync() == 0) return null;
      return path;
    } catch (e) {
      _logger.d('Frame extract failed for $video: $e');
      return null;
    }
  }

  Future<File?> _downloadToTemp(String url) async {
    try {
      final dir = await _ensureCacheDir();
      final ext = _extensionOf(url) ?? 'mp4';
      final tmpPath = '${dir.path}/srcvid_${_stableHash(url)}.$ext';
      final cancelToken = CancelToken();
      await Dio().download(
        url,
        tmpPath,
        cancelToken: cancelToken,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 45),
        ),
        onReceiveProgress: (received, total) {
          if (received > _maxDownloadBytes ||
              (total > 0 && total > _maxDownloadBytes)) {
            cancelToken.cancel('video exceeds thumbnail download cap');
          }
        },
      );
      final f = File(tmpPath);
      if (f.existsSync() && f.lengthSync() > 0) return f;
      return null;
    } catch (e) {
      _logger.d('Video download for thumbnail failed ($url): $e');
      return null;
    }
  }

  Future<Directory> _ensureCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/video_thumbnails');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  String? _extensionOf(String source) {
    final clean = source.split('?').first.split('#').first;
    final slash = clean.lastIndexOf('/');
    final name = slash == -1 ? clean : clean.substring(slash + 1);
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  /// Deterministic, run-stable FNV-1a hash so on-disk cache files survive an
  /// app restart (Dart's `String.hashCode` is not guaranteed stable).
  String _stableHash(String input) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
