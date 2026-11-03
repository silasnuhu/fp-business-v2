import 'package:whoxa/core/api/api_endpoint.dart';

/// Normalizes the media references NEW's REST payloads carry into absolute,
/// loadable URLs.
///
/// NOTE: a bare media id (`avatarMediaId: "20"`) is deliberately NOT turned
/// into `<baseUrl>/media/20` here — that endpoint returns the media METADATA
/// object, not the bytes, so it can't be given to an image widget. An id has
/// to go through [MediaRepository.getDisplayUrl], which looks the row up and
/// returns its `cdnUrl`. This helper returns null for such values so callers
/// fall back to their default avatar rather than requesting a JSON document
/// as an image.
class MediaUrl {
  /// - `null` / empty            -> `null`
  /// - `https://…` / `http://…`  -> returned unchanged
  /// - `/uploads/…` (LOCAL mode) -> prefixed with the bare host
  /// - a bare media id           -> `null` (needs a `/media/:id` lookup)
  static String? normalize(String? value) {
    if (value == null) return null;

    final raw = value.trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    // A server-relative path (LOCAL storage serves files at /uploads/...)
    // hangs off the bare origin, not the /api/v1 prefix.
    if (raw.startsWith('/')) return '${ApiEndpoints.socketUrl}$raw';

    return null;
  }
}
