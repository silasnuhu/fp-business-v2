/// Single source of truth for the letter-avatar initials shown whenever a user
/// (or group) has no profile picture.
///
/// Every list that carries user info — chat list, contacts, forward list, group
/// members, call history, poll voters, story viewers, profile screens — must
/// derive its fallback initials from here so the same person always renders the
/// same initials on every screen and on every device.
///
/// Rule: `"First Last"` -> `"FL"`, `"First"` -> `"F"`, blank / unknown -> `"?"`
/// (or `"G"` for a group). The name passed in should already be the app's
/// resolved display name (see `ContactNameService.resolveName`) so the initials
/// track the same string the UI shows as the title.
String avatarInitials(String? name, {bool isGroup = false}) {
  final fallback = isGroup ? 'G' : '?';

  if (name == null) return fallback;

  final trimmed = name.trim();
  if (trimmed.isEmpty ||
      trimmed == 'Unknown' ||
      trimmed == 'Unknown User' ||
      trimmed == 'Unknown Contact') {
    return fallback;
  }

  try {
    final parts = trimmed.split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);

    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
  } catch (_) {
    // Fall through to the fallback on any unexpected string-handling error.
  }

  return fallback;
}
