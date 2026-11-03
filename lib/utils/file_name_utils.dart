/// Helpers for turning a remote attachment URL into something worth showing
/// to a user.
///
/// The backend stores every upload under a storage key shaped like
/// `uploads/<userId>/<uuid>-<sanitised-original-name>` (see the media
/// service's `generateStorageKey`), so the naive `url.split('/').last`
/// every document widget used produced titles like
/// `9f1c2e7a-4b0d-4a91-8c3e-2b7d8f0a1e55-Q3_Report.pdf`. Strip that
/// machine-generated prefix so the row shows `Q3_Report.pdf`.
library;

final RegExp _uuidPrefix = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}-',
);

/// Best-effort original file name for [url].
///
/// Falls back to [fallback] when [url] is null/empty or carries no usable
/// path segment.
String prettyFileNameFromUrl(String? url, {String fallback = 'Document'}) {
  if (url == null) return fallback;

  var name = url.trim();
  if (name.isEmpty) return fallback;

  // Drop query string / fragment (`?v=..`, `#page=2`).
  name = name.split(RegExp(r'[?#]')).first;

  // Last non-empty path segment.
  final segments = name.split('/')..removeWhere((s) => s.isEmpty);
  if (segments.isEmpty) return fallback;
  name = segments.last;

  // Percent-decode (`My%20File.pdf` -> `My File.pdf`).
  try {
    name = Uri.decodeComponent(name);
  } catch (_) {
    // Malformed escape — keep the raw segment.
  }

  // Strip the storage-key UUID prefix.
  name = name.replaceFirst(_uuidPrefix, '');

  name = name.trim();
  return name.isEmpty ? fallback : name;
}
