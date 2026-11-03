// The NEW backend serializes almost all numeric IDs as BigInt-safe strings,
// except a handful of legacy-compatibility endpoints (`users/updateUser`,
// `users/find-user`) which still return plain numbers. Models should read
// every id field through this so a per-endpoint int/String divergence in the
// wire format doesn't leak into app code. See §11 "Universal ID change" and
// §13 item 6 in docs/doc_v1/OLD_VS_NEW_API_MIGRATION_GUIDE.md.
class IdCodec {
  static String toId(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static String? toIdOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Same BigInt-safety reasoning as the id helpers above, but for numeric
  /// (non-id) fields the backend also serializes via `.toString()` — seq
  /// counters like `lastMessageSeq`/`conversationSeq`/`lastReadSeq` (see
  /// ConversationsService.toPublicConversation / MessagesService — every
  /// one of them is BigInt-backed and `.toString()`'d before going on the
  /// wire, never a plain JSON number). Casting these `as num?` throws the
  /// moment a real (non-default) value comes back from the server.
  static int toIntOrZero(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
