import 'package:whoxa/core/api/id_codec.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart';
import 'package:whoxa/featuers/chat/data/message_dto.dart';
import 'package:whoxa/featuers/chat/utils/message_utils.dart';

// Maps NEW's `MessageDto` onto the existing `Records` model so the huge
// message-rendering surface in universal_chat_screen.dart and its ~15
// per-type widget files don't need to change at all — including the
// `messageType` normalization (document/audio -> doc/voice) so every
// existing `case 'doc':`/`case 'voice':` keeps matching.
class MessageAdapter {
  /// [currentUserId] is only used to resolve the viewer's own vote on an
  /// embedded poll; every other mapping is viewer-independent.
  static Records toRecord(MessageDto message, {String? currentUserId}) {
    // For attachment-bearing types the actual media lives in
    // `attachments[].cdnUrl`, not `body` (`body` is only populated for
    // text messages / captions) — fall back to it so image/video/voice/doc
    // bubbles have a URL to render instead of coming back blank.
    final content = message.primaryAttachmentUrl ?? message.body;

    // NEW logs call outcomes as `type: 'call_log'` bubbles carrying the
    // call detail in `metadata` ({callId, callType, status, durationSeconds})
    // with no body/attachments. The whole call-rendering surface
    // (message_content_widget's `case 'call':`, CallMessageWidget,
    // CallDisplayService, CallPreviewMapper) still keys off the OLD shape —
    // `messageType == 'call'` plus a `calls[]` array of `CallData` — so
    // synthesize that here. Without it the bubble falls through to the
    // "Unsupported message type" default branch.
    final isCallLog = message.type == 'call_log';

    // NEW emits group/conversation lifecycle events as `type: 'system'`
    // bubbles carrying `metadata.event` (e.g. 'group_created'). The whole
    // rendering surface (message_content_widget's switch, chat-list preview)
    // keys off the OLD per-event messageType strings ('group-created',
    // 'member-added', …) — so translate here. Without it a system bubble
    // falls through to the "Unsupported message type: system" default branch.
    final isSystem = message.type == 'system';

    // NEW carries a story reply as `type: 'feed_reference'` with the
    // referenced story snapshot living entirely in `metadata` (§6.8 — no
    // server-side story relation on a message). The whole reply-rendering
    // surface (message_content_widget's `case 'story_reply':`,
    // StoryReplyMessageWidget) keys off the OLD shape — `messageType ==
    // 'story_reply'` plus a populated `Records.story` / `Records.user` — so
    // rebuild that here. Without it the bubble falls through to
    // "Unsupported message type: feed_reference".
    final isStoryReply = message.type == 'feed_reference';
    final storySnapshot = isStoryReply ? _storyFromMetadata(message) : null;

    return Records(
      // For a story reply `body` holds the user's typed text — never fall
      // back to an attachment URL there.
      messageContent: isStoryReply ? message.body : content,
      messageThumbnail: message.primaryAttachmentThumbnailUrl,
      replyTo: int.tryParse(message.replyToMessageId ?? ''),
      messageId: int.tryParse(message.id),
      messageType:
          isCallLog
              ? 'call'
              : isSystem
              ? _systemMessageType(message.metadata?['event'] as String?)
              : _incomingType(message),
      calls: isCallLog ? _callsFromMetadata(message) : null,
      voiceDuration: _voiceDurationFromMetadata(message),
      story: storySnapshot,
      // StoryReplyMessageWidget renders "<user.fullName> • Status" from
      // `Records.user` (force-unwrapped) — point it at the story owner so
      // it neither NPEs nor shows the wrong name.
      user: isStoryReply ? _storyOwnerUser(message) : null,
      createdAt: message.createdAt,
      updatedAt: message.updatedAt,
      chatId: int.tryParse(message.conversationId),
      senderId: int.tryParse(message.senderId),
      deletedForEveryone: message.isDeletedForEveryone,
      isEdited: message.isEdited,
      editedAt: message.editedAt,
      deletedFor: const [],
      starredFor: const [],
      // `type: 'poll'` messages carry the full poll (question + options +
      // tallies) inline on the message payload, in the same shape
      // `GET /polls/:id` returns — map it straight through so the bubble
      // renders its options without a second round-trip. `pollId` is kept
      // too, so ChatProvider can re-resolve/refresh the poll on vote.
      pollData:
          message.poll == null
              ? null
              : PollData.fromNewApi(
                message.poll!,
                currentUserId: currentUserId,
              ),
      pollId: message.pollId,
      // conversationSeq is carried via `unseenCount` — an unused-by-NEW
      // field on this model — purely as internal storage so the watermark
      // comparison in computeSeenStatus below has somewhere to read it
      // from without adding a new field to a model shared with local
      // on-disk cache serialization.
      unseenCount: message.conversationSeq,
    );
  }

  /// Same rule the composer uses to send a message as a link (`isURL` in
  /// widgets/global.dart): text that starts with http(s):// or www.
  static final _linkTextRegex = RegExp(
    r'^(http[s]?:\/\/|www\.)\S+',
    caseSensitive: false,
  );

  /// NEW's `type` mapped to the internal type. Links travel as `type: 'text'`
  /// (NEW has no link type), so a text whose body is a link is turned back
  /// into `'link'` to render with the link-preview bubble.
  static String _incomingType(MessageDto message) {
    final type = MessageTypeUtils.fromNewIncomingType(message.type);
    if (type == 'text' && _linkTextRegex.hasMatch(message.body?.trim() ?? '')) {
      return 'link';
    }
    return type;
  }

  /// Voice messages carry their recorded length as `metadata.durationSeconds`
  /// (sent by ChatProvider.sendMessage). Returned as "mm:ss", the format the
  /// voice bubble parses; null when absent (older messages, other types).
  static String? _voiceDurationFromMetadata(MessageDto message) {
    if (message.type != 'audio' && message.type != 'voice') return null;
    final seconds = IdCodec.toIntOrNull(message.metadata?['durationSeconds']);
    if (seconds == null || seconds <= 0) return null;
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  /// Patches an already-loaded [record] in place from an updated message
  /// payload (`PATCH /messages/:id` response or the `message_updated` socket
  /// event, same full shape). Only the server-owned, mutable fields are
  /// copied — body, edited flag/time, delete-for-everyone — so everything the
  /// client derived locally (reply preview, seen status, conversationSeq,
  /// pin/star state) survives. Returns whether anything changed.
  static bool applyUpdate(Records record, MessageDto message) {
    final fresh = toRecord(message);
    var changed = false;

    if (message.isDeletedForEveryone) {
      // Deleted-for-everyone always wins over showing edited text.
      if (record.deletedForEveryone != true) {
        record.deletedForEveryone = true;
        record.messageContent = 'This message was deleted.';
        changed = true;
      }
      return changed;
    }

    // Same content resolution as toRecord — attachment-bearing types keep
    // their media URL in `messageContent`, so an update to the caption never
    // clobbers the image/video/voice URL.
    if (fresh.messageContent != null &&
        fresh.messageContent != record.messageContent) {
      record.messageContent = fresh.messageContent;
      changed = true;
    }
    if (message.isEdited && record.isEdited != true) {
      record.isEdited = true;
      changed = true;
    }
    if (message.editedAt != null && message.editedAt != record.editedAt) {
      record.editedAt = message.editedAt;
      changed = true;
    }
    if (message.updatedAt != null) record.updatedAt = message.updatedAt;
    return changed;
  }

  /// Builds the single-element `calls[]` array a `type: 'call_log'` message
  /// needs so CallDisplayService can render it. The call-log `metadata`
  /// shape written by the backend (CallsService.logCallMessage) is
  /// `{ callId, callType: 'audio'|'video', status: 'missed'|'declined'|'ended',
  /// durationSeconds }`. `userId` is set to the message sender (the call
  /// initiator) — CallDisplayService derives outgoing/incoming direction
  /// from it.
  static List<CallData> _callsFromMetadata(MessageDto message) {
    final md = message.metadata ?? const <String, dynamic>{};
    final rawDuration = md['durationSeconds'];
    return [
      CallData(
        callId: int.tryParse('${md['callId'] ?? ''}'),
        callType: md['callType'] as String?,
        callStatus: md['status'] as String?,
        callDuration:
            rawDuration is int
                ? rawDuration
                : int.tryParse('${rawDuration ?? ''}'),
        users: const [],
        userId: int.tryParse(message.senderId),
        chatId: int.tryParse(message.conversationId),
        messageId: int.tryParse(message.id),
        createdAt: message.createdAt,
        updatedAt: message.updatedAt,
      ),
    ];
  }

  /// Rebuilds the OLD-shaped `Records.story` from a `type: 'feed_reference'`
  /// message's free-form `metadata` bag (written by the story viewer before
  /// send — see ChatProvider.storyReplyContext). Every field
  /// StoryReplyMessageWidget force-unwraps (`storyType`, `user`,
  /// `user.userId`, and `media` for non-video) is defaulted here so the
  /// bubble renders instead of throwing. Accepts both the app's camelCase
  /// keys and a few snake_case aliases in case another client wrote them.
  static Story? _storyFromMetadata(MessageDto message) {
    final md = message.metadata;
    if (md == null || md.isEmpty) return null;

    String? str(List<String> keys) {
      for (final k in keys) {
        final v = md[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return null;
    }

    final rawStoryId = str(['storyId', 'story_id']);
    // No id => nothing useful to render / navigate to.
    if (rawStoryId == null) return null;

    final rawType = (str(['storyType', 'story_type']) ?? 'image').toLowerCase();
    final storyType =
        (rawType == 'video' || rawType == 'text') ? rawType : 'image';

    return Story(
      storyId: int.tryParse(rawStoryId),
      media:
          str(['storyMediaUrl', 'media', 'mediaUrl', 'media_url', 'url']) ?? '',
      thumbnail: str([
        'storyThumbnailUrl',
        'thumbnail',
        'thumbnailUrl',
        'thumbnail_url',
      ]),
      caption: str(['storyCaption', 'caption', 'story_caption']),
      storyType: storyType,
      expiresAt: str(['expiresAt', 'expires_at']),
      isExpired: md['isExpired'] as bool? ?? md['is_expired'] as bool? ?? false,
      views: const [],
      userId: int.tryParse(
        str(['storyOwnerId', 'ownerUserId', 'userId', 'user_id']) ?? '',
      ),
      user: _storyOwnerStoryUser(md, str),
    );
  }

  static StoryUser _storyOwnerStoryUser(
    Map<String, dynamic> md,
    String? Function(List<String>) str,
  ) {
    return StoryUser(
      userId: int.tryParse(
        str(['storyOwnerId', 'ownerUserId', 'userId', 'user_id']) ?? '',
      ),
      userName: str(['ownerUserName', 'userName', 'user_name']),
      fullName: str(['ownerFullName', 'fullName', 'full_name']),
      profilePic: str(['ownerProfilePic', 'profilePic', 'profile_pic']),
    );
  }

  /// The `Records.user` a story-reply bubble reads for its `<name> • Status`
  /// header — the story owner, not the message sender.
  static User? _storyOwnerUser(MessageDto message) {
    final md = message.metadata;
    if (md == null || md.isEmpty) return null;

    String? str(List<String> keys) {
      for (final k in keys) {
        final v = md[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return null;
    }

    return User(
      userId: int.tryParse(
        str(['storyOwnerId', 'ownerUserId', 'userId', 'user_id']) ?? '',
      ),
      userName: str(['ownerUserName', 'userName', 'user_name']),
      fullName:
          str(['ownerFullName', 'fullName', 'full_name']) ??
          str(['ownerUserName', 'userName', 'user_name']) ??
          'Unknown',
      profilePic: str(['ownerProfilePic', 'profilePic', 'profile_pic']),
    );
  }

  /// Maps a NEW `type: 'system'` message's `metadata.event` onto the
  /// OLD per-event messageType string every renderer already handles
  /// (message_content_widget's switch, chat_list's preview builder).
  /// Unknown/future events fall back to a generic 'system' bucket that
  /// renders as a quiet centered line rather than "Unsupported message type".
  static String _systemMessageType(String? event) {
    switch (event) {
      case 'group_created':
        return 'group-created';
      case 'member_added':
      case 'members_added':
        return 'member-added';
      case 'member_removed':
        return 'member-removed';
      case 'member_left':
        return 'member-left';
      case 'admin_promoted':
      case 'promoted_as_admin':
        return 'promoted-as-admin';
      case 'admin_removed':
      case 'removed_as_admin':
        return 'removed-as-admin';
      default:
        return 'system';
    }
  }

  /// Reply-preview backfill. NEW's message payload only ever carries the
  /// *id* being replied to (`replyToMessageId` -> `Records.replyTo`) — never
  /// the referenced message's own content/type/sender the way OLD's
  /// `ParentMessage` object did. Every reply-preview renderer across the
  /// per-type message widgets (text/image/voice/poll/etc., all via
  /// `ChatRelatedWidget.getSenderName`/`buildTextPreview`/etc.) reads that
  /// from `Records.parentMessage`, which toRecord() above never sets — so
  /// after the backend migration no reply bubble showed a preview at all.
  /// Call this once per fetched/pushed batch of records with a lookup of
  /// every message currently known to the provider (this batch plus
  /// whatever's already loaded), to synthesize `parentMessage` wherever the
  /// referenced message is available locally. `sender_id` alone is enough
  /// for the "You" case `getSenderName` checks first; when the parent isn't
  /// loaded (e.g. an older message outside the current page) `parentMessage`
  /// stays null and that one bubble simply renders without a preview, same
  /// as the "unknown parent" case under OLD.
  static void attachParentMessages(
    Iterable<Records> records,
    Map<int, Records> lookup,
  ) {
    for (final record in records) {
      if (record.parentMessage != null) continue;
      final replyId = record.replyTo;
      if (replyId == null) continue;
      final parent = lookup[replyId];
      if (parent == null) continue;
      record.parentMessage = {
        'message_id': parent.messageId,
        'message_content': parent.messageContent,
        'message_type': parent.messageType,
        'message_thumbnail': parent.messageThumbnail,
        'sender_id': parent.senderId,
      };
    }
  }

  /// Computes the read tick status client-side from the watermark model
  /// (§6.6) and writes it into the EXISTING `messageSeenStatus` field so
  /// chat_related_widget.dart's tick renderer needs zero changes. Do NOT
  /// trust any `message.status`/`message_seen_status` NEW sends on the
  /// wire — it's never written by the backend and always reads "sent"
  /// (§6.6/§13 item 10).
  /// Note: the existing tick widget only distinguishes "seen" (blue) from
  /// "sent" (grey) — it has no separate "delivered" visual state, so
  /// `peerLastDeliveredSeq` isn't used here; a delivered-but-unread message
  /// renders the same as sent-but-undelivered, matching the UI's existing
  /// (two-state) expressiveness rather than inventing a third visual.
  static void applySeenStatus(Records message, {required int peerLastReadSeq}) {
    final seq = message.unseenCount ?? 0;
    message.messageSeenStatus =
        (seq > 0 && seq <= peerLastReadSeq) ? 'seen' : 'sent';
  }
}
