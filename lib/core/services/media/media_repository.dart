import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/services/media/media_url.dart';
import 'package:whoxa/utils/logger.dart';

/// Resolves a bare `mediaId` to a displayable URL.
///
/// `GET /media/:id` (auth required) returns METADATA ONLY — the
/// `toPublicMedia` object `{mediaId, cdnUrl, mimeType, width, height, …}` —
/// never the bytes. So a media id can't be handed to an image widget
/// directly: the id has to be looked up first and the row's `cdnUrl` is what
/// actually gets fetched/displayed.
///
/// Resolutions are memoized process-wide (including misses, so a deleted
/// asset's 404 isn't re-requested on every list rebuild) and de-duplicated
/// while in flight, so N chat-list rows sharing one avatar cost one call.
class MediaRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule('MediaRepository');

  MediaRepository(this._apiClient);

  // Keyed by mediaId. Static so the cache survives provider rebuilds — media
  // rows are immutable once confirmed, so a resolved cdnUrl never goes stale.
  static final Map<String, String?> _cdnUrlCache = {};
  static final Map<String, Future<String?>> _inFlight = {};

  /// Clears the memoized lookups (e.g. on logout, so the next user doesn't
  /// read a previous session's resolutions).
  static void clearCache() {
    _cdnUrlCache.clear();
    _inFlight.clear();
  }

  /// Turns [value] into something an image widget can load:
  ///  - already a URL (or a server-relative `/uploads/…` path) -> normalized
  ///    and returned without a network call
  ///  - a bare media id (`"20"`) -> `GET /media/20`, returns its `cdnUrl`
  ///  - null / empty / unresolvable -> null
  Future<String?> getDisplayUrl(String? value) async {
    if (value == null) return null;
    final raw = value.trim();
    if (raw.isEmpty) return null;

    // Anything already URL-shaped needs no lookup.
    final direct = MediaUrl.normalize(raw);
    if (direct != null) return direct;

    if (_cdnUrlCache.containsKey(raw)) return _cdnUrlCache[raw];

    final pending = _inFlight[raw];
    if (pending != null) return pending;

    final future = _fetchCdnUrl(raw);
    _inFlight[raw] = future;
    try {
      final url = await future;
      _cdnUrlCache[raw] = url;
      return url;
    } finally {
      _inFlight.remove(raw);
    }
  }

  Future<String?> _fetchCdnUrl(String mediaId) async {
    try {
      final response = await _apiClient.request(
        '${ApiEndpoints.media}/$mediaId',
        method: 'GET',
      );
      final data =
          response is Map<String, dynamic>
              ? (response['data'] as Map<String, dynamic>? ?? response)
              : null;
      if (data == null) {
        _logger.w('media/$mediaId returned an unexpected shape: $response');
        return null;
      }
      // `thumbnailUrl` is only set for video; for an avatar/image `cdnUrl` is
      // the one to display.
      return MediaUrl.normalize(data['cdnUrl']?.toString());
    } catch (e) {
      // A 404 ("Media not found") or an auth blip must not break the list —
      // the caller falls back to its default avatar.
      _logger.w('Could not resolve media $mediaId: $e');
      return null;
    }
  }
}
