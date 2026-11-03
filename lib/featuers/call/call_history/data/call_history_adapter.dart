import 'package:whoxa/core/api/id_codec.dart';
import 'package:whoxa/featuers/call/call_history/models/call_history_model.dart';
import 'package:whoxa/widgets/global.dart';

// Adapts NEW's `GET /calls/history?cursor=&limit=` response (§7.6/§7.4) onto
// the existing OLD-shaped `CallHistoryResponse`/`CallRecord` models so
// `CallHistoryProvider`/`call_history_screen.dart` need no changes — same
// DTO+Adapter pattern used for conversations/messages/stories elsewhere in
// this migration.
//
// The migration guide confirms the endpoint and that call history now comes
// from dedicated `Call`/`CallParticipant` tables (not `Message` rows), but
// gives NO literal JSON sample for either the list envelope or a single
// call-history entry. Field lookups below try several reasonable
// candidates and are flagged best-effort — verify against a live NEW
// backend response and tighten once the real shape is known.
class CallHistoryAdapter {
  static CallHistoryResponse adapt(
    Map<String, dynamic> raw, {
    required int page,
    // Back-fill maps for the two blanks NEW's `GET /calls/history` leaves:
    //  - `peerProfiles[peerUserId]` -> a `GET /users/:id` profile map, used
    //    to fill the 1:1 caller name/avatar (participants[] has userId only).
    //  - `groupTitles[chatId]` -> a resolved conversation title, used to
    //    fill a group call's name (history's `conversation` has id+type only).
    // Both are resolved N+1 by `CallHistoryRepository` and are optional so
    // an un-enriched first pass still works.
    Map<int, Map<String, dynamic>>? peerProfiles,
    Map<int, String>? groupTitles,
  }) {
    final rawItems =
        (raw['items'] ?? raw['calls'] ?? raw['data'] ?? raw['records'])
            as List<dynamic>? ??
        const [];
    final nextCursor =
        raw['nextCursor'] ?? raw['next_cursor'] ?? raw['cursor'];

    final records = rawItems
        .whereType<Map>()
        .map(
          (e) => _adaptRecord(
            e.cast<String, dynamic>(),
            peerProfiles: peerProfiles,
            groupTitles: groupTitles,
          ),
        )
        .toList();

    // Bridges NEW's cursor pagination onto the existing page-number UI
    // state machine: "one more page exists" iff a nextCursor came back.
    final pagination = PaginationInfo(
      totalPages: (nextCursor != null && nextCursor.toString().isNotEmpty)
          ? page + 1
          : page,
      totalRecords: records.length,
      currentPage: page,
      recordsPerPage: records.length,
    );

    return CallHistoryResponse(
      status: true,
      data: CallHistoryData(records: records, pagination: pagination),
      message: '',
      toast: 0,
    );
  }

  static CallRecord _adaptRecord(
    Map<String, dynamic> json, {
    Map<int, Map<String, dynamic>>? peerProfiles,
    Map<int, String>? groupTitles,
  }) {
    final rawCallId = json['id'] ?? json['callId'] ?? json['call_id'];
    final rawConversationId =
        json['conversationId'] ??
        json['conversation_id'] ??
        json['chatId'] ??
        json['chat_id'];
    final conversation =
        (json['conversation'] ?? json['chat']) as Map<String, dynamic>? ?? {};

    final rawStatus =
        (json['status'] ?? json['callStatus'] ?? json['call_status'])
            ?.toString()
            .toLowerCase() ??
        '';
    // Normalize NEW's status vocabulary onto the exact strings
    // `CallRecord.getCallDirection`/`getCallTypeText` already check for
    // ("missed", "rejected", "ended", "ringing") — unconfirmed mapping.
    final String callStatus;
    if (rawStatus.contains('miss')) {
      callStatus = 'missed';
    } else if (rawStatus.contains('declin') || rawStatus.contains('reject')) {
      callStatus = 'rejected';
    } else if (rawStatus.contains('ring') || rawStatus == 'initiated') {
      callStatus = 'ringing';
    } else {
      callStatus = 'ended';
    }

    final startedAtRaw =
        json['startedAt'] ?? json['started_at'] ?? json['createdAt'];
    final endedAtRaw = json['endedAt'] ?? json['ended_at'];
    final startedAt = DateTime.tryParse(startedAtRaw?.toString() ?? '');
    final endedAt = DateTime.tryParse(endedAtRaw?.toString() ?? '');

    int durationSeconds =
        (json['durationSeconds'] ?? json['duration'] ?? json['call_duration'])
            is num
        ? (json['durationSeconds'] ?? json['duration'] ?? json['call_duration'])
              .toInt()
        : 0;
    if (durationSeconds == 0 && startedAt != null && endedAt != null) {
      durationSeconds = endedAt.difference(startedAt).inSeconds;
      if (durationSeconds < 0) durationSeconds = 0;
    }

    // Verified against actual backend source (CallsService.mapCall(),
    // src/calls/calls.service.ts): the field is `initiatedBy`, not
    // `initiatorId`/`callerId` — none of the previously-guessed candidates
    // ever matched, so senderId always read null.
    final initiatorRaw =
        json['initiatedBy'] ?? json['initiatorId'] ?? json['callerId'];
    final senderId = int.tryParse(
      IdCodec.toIdOrNull(initiatorRaw) ?? initiatorRaw?.toString() ?? '',
    );

    // Best-effort "the other participant" for a direct call's caller/peer
    // display. Confirmed against actual backend source: `mapCall()`'s
    // `participants[]` only carries {callId,userId,status,joinedAt,leftAt,
    // durationSeconds,deviceType} — NO name/avatar fields at all, and there
    // is no separate `caller`/`counterpart`/`peer` object either. So
    // peerName/peerAvatar below are confirmed-always-blank from this
    // response alone; only peerUserId can actually resolve. Fixing the
    // display name/avatar requires the same N+1 `getUserBasicProfile`
    // lookup pattern used for conversations (ConversationAdapter) — not
    // done here since CallHistoryAdapter has no repository access; flagging
    // rather than silently leaving it unexplained.
    final participants =
        (json['participants'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList() ??
        const [];
    final peer = participants.firstWhere(
      (p) =>
          (p['userId'] ?? p['user_id'])?.toString() != userID.toString(),
      orElse: () => const {},
    );

    final peerUserId = int.tryParse(
      (peer['userId'] ?? peer['user_id'] ?? peer['id'])?.toString() ?? '',
    );
    var peerName =
        peer['fullName']?.toString() ??
        peer['full_name']?.toString() ??
        peer['userName']?.toString() ??
        '';
    var peerAvatar =
        peer['avatarUrl']?.toString() ?? peer['profile_pic']?.toString() ?? '';

    // Back-fill from the separately-fetched `GET /users/:id` profile
    // (camelCase `toPublicUser()` shape, snake_case kept as a fallback) so
    // 1:1 calls with a peer who isn't a saved contact stop rendering as
    // "Unknown User".
    final resolvedPeer = (peerUserId != null && peerProfiles != null)
        ? peerProfiles[peerUserId]
        : null;
    if (resolvedPeer != null) {
      if (peerName.isEmpty) {
        peerName =
            (resolvedPeer['fullName'] ??
                    resolvedPeer['full_name'] ??
                    resolvedPeer['userName'] ??
                    resolvedPeer['user_name'] ??
                    '')
                .toString();
      }
      if (peerAvatar.isEmpty) {
        peerAvatar =
            (resolvedPeer['profilePic'] ?? resolvedPeer['profile_pic'] ?? '')
                .toString();
      }
    }

    final callType =
        (json['type'] ?? json['callType'] ?? json['call_type'])?.toString() ??
        'audio';

    final chatType = (conversation['type'] ?? conversation['chat_type'])
        ?.toString();
    final isGroup = chatType == 'group';

    final chatIdInt =
        int.tryParse(
          IdCodec.toIdOrNull(rawConversationId) ??
              rawConversationId?.toString() ??
              '',
        ) ??
        0;

    // History's `conversation` carries only {id,type} — no title — so a
    // group call renders nameless until a resolved title is handed in.
    final rawGroupName =
        conversation['title']?.toString() ??
        conversation['group_name']?.toString();
    String? resolvedGroupName = rawGroupName;
    if ((resolvedGroupName == null || resolvedGroupName.isEmpty) &&
        chatIdInt != 0 &&
        groupTitles != null) {
      resolvedGroupName = groupTitles[chatIdInt];
    }

    return CallRecord(
      messageContent: '',
      messageThumbnail: '',
      replyTo: 0,
      socialId: 0,
      messageId: 0,
      messageType: '',
      messageLength: '',
      messageSeenStatus: '',
      messageSize: '',
      deletedFor: const [],
      starredFor: const [],
      deletedForEveryone: false,
      pinned: false,
      peerUser: peerUserId != null
          ? [
              PeerUser(
                userId: peerUserId,
                fullName: peerName,
                userName: peerName,
                profilePic: peerAvatar,
              ),
            ]
          : const [],
      forwardedFrom: 0,
      createdAt: (startedAt ?? DateTime.now()).toIso8601String(),
      updatedAt: (endedAt ?? startedAt ?? DateTime.now()).toIso8601String(),
      chatId: chatIdInt,
      senderId: senderId,
      calls: [
        CallInfo(
          callId:
              int.tryParse(IdCodec.toIdOrNull(rawCallId) ?? '') ??
              0,
          callType: callType,
          callDuration: durationSeconds,
          callStatus: callStatus,
          caller: peerUserId != null
              ? CallerInfo(
                  userName: peerName,
                  fullName: peerName,
                  profilePic: peerAvatar,
                  userId: peerUserId,
                )
              : null,
        ),
      ],
      chat: ChatInfo(
        groupIcon: isGroup
            ? (conversation['avatarUrl']?.toString() ??
                  conversation['group_icon']?.toString() ??
                  '')
            : '',
        chatId: chatIdInt,
        chatType: chatType ?? 'private',
        groupName: isGroup ? resolvedGroupName : null,
      ),
    );
  }
}
