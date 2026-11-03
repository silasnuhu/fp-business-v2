import 'package:flutter/services.dart';

/// Pinned chat shortcuts (Android home screen).
///
/// Native side lives in `MainActivity.kt` (`com.flickpitch.app/shortcuts`):
///  • `pinChat`            → ShortcutManagerCompat.requestPinShortcut
///  • `consumePendingChat` → returns the chat a launcher shortcut launched us
///    with, then clears it so it only navigates once.
class ChatShortcutService {
  ChatShortcutService._();
  static const MethodChannel _channel = MethodChannel(
    'com.flickpitch.app/shortcuts',
  );

  /// Ask Android to place a "chat with X" icon on the home screen.
  /// Returns false on older devices or if the user declines.
  static Future<bool> pin({
    required int chatId,
    required int userId,
    required String chatName,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('pinChat', {
        'chatId': chatId,
        'userId': userId,
        'chatName': chatName,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Chat requested by a pinned shortcut, if we were launched by one.
  static Future<Map<String, dynamic>?> consumePending() async {
    try {
      final raw = await _channel.invokeMethod('consumePendingChat');
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    } catch (_) {
      return null;
    }
  }
}
