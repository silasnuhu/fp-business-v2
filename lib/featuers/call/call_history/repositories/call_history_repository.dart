import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/featuers/call/call_history/data/call_history_adapter.dart';
import 'package:whoxa/featuers/call/call_history/models/call_history_model.dart';
import 'package:whoxa/featuers/call/call_repository.dart';
import 'package:whoxa/featuers/chat/repository/conversation_repository.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/widgets/global.dart';

// NEW: `GET /calls/history?cursor=&limit=` (§7.6) replaces OLD's
// page-paginated POST derived from Message rows. `CallHistoryProvider`
// still drives this by page number, so cursor state is tracked here and
// bridged: page 1 (refresh) starts a fresh cursor chain, each subsequent
// page consumes the cursor returned by the previous call — same
// page<->cursor bridging pattern used for archived chats elsewhere.
class CallHistoryRepository {
  final CallRepository _callRepository;
  final ConversationRepository _conversationRepository;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  CallHistoryRepository(ApiClient apiClient)
    : _callRepository = CallRepository(apiClient),
      _conversationRepository = ConversationRepository(apiClient);

  String? _cursor;

  // Resolved-once caches kept for this repository's lifetime so "load
  // more" never re-fetches a peer / group already seen. NEW's
  // `GET /calls/history` gives `participants[]` with userId only (no
  // name/avatar) and a `conversation` of {id,type} only (no title), so the
  // 1:1 caller name/avatar and the group call's name have to be back-filled
  // with N+1 `GET /users/:id` / `GET /conversations/:id` lookups — same
  // pattern ConversationAdapter uses for the chat list.
  final Map<int, Map<String, dynamic>> _peerProfileCache = {};
  final Map<int, String> _groupTitleCache = {};

  // Group-call callers whose profile was already read once: that read is
  // what records their `premiumUser` flag (blue tick) for the tile.
  final Set<int> _groupCallersNoted = {};

  Future<CallHistoryResponse> getCallHistory({int page = 1}) async {
    _logger.i('Fetching call history for user: $userID, page: $page');
    try {
      if (page <= 1) _cursor = null;
      final response = await _callRepository.getHistory(cursor: _cursor);

      // First pass: adapt with only what the raw response carries, so we
      // can see which caller / group names came back blank.
      final firstPass = CallHistoryAdapter.adapt(response, page: page);
      await _resolveMissingNames(firstPass.data.records);

      // Second pass: re-adapt, now handing the adapter the resolved peer
      // profiles / group titles so the blanks get filled.
      final adapted = CallHistoryAdapter.adapt(
        response,
        page: page,
        peerProfiles: _peerProfileCache,
        groupTitles: _groupTitleCache,
      );

      _cursor =
          (response['nextCursor'] ??
                  response['next_cursor'] ??
                  response['cursor'])
              ?.toString();

      _logger.i('Call history fetched successfully for page $page');
      return adapted;
    } catch (e) {
      _logger.e('Error fetching call history:', e.toString());
      rethrow;
    }
  }

  /// N+1 back-fill for the two identity blanks `GET /calls/history` leaves:
  /// a 1:1 call's peer profile (`GET /users/:id`) and a group call's title
  /// (`GET /conversations/:id`). Deduped per call and cached across pages;
  /// a failed lookup is simply skipped (tile keeps its existing fallback).
  Future<void> _resolveMissingNames(List<CallRecord> records) async {
    final me = userID.toString();
    final peerIdsToFetch = <int>{};
    final groupIdsToFetch = <int>{};
    final groupCallerIds = <int>{};

    for (final record in records) {
      final isGroup = record.chat?.chatType == 'group';
      if (isGroup) {
        final chatId = record.chat?.chatId ?? 0;
        final hasTitle = (record.chat?.groupName ?? '').trim().isNotEmpty;
        if (chatId != 0 &&
            !hasTitle &&
            !_groupTitleCache.containsKey(chatId)) {
          groupIdsToFetch.add(chatId);
        }
        final callerId = record.primaryCall?.caller?.userId ?? 0;
        if (callerId != 0 && !_groupCallersNoted.contains(callerId)) {
          groupCallerIds.add(callerId);
        }
      } else {
        final caller = record.primaryCall?.caller;
        final peerId = caller?.userId ?? 0;
        final hasName =
            (caller?.userName ?? '').trim().isNotEmpty ||
            (caller?.fullName ?? '').trim().isNotEmpty;
        if (peerId != 0 &&
            peerId.toString() != me &&
            !hasName &&
            !_peerProfileCache.containsKey(peerId)) {
          peerIdsToFetch.add(peerId);
        }
      }
    }

    if (peerIdsToFetch.isEmpty &&
        groupIdsToFetch.isEmpty &&
        groupCallerIds.isEmpty) {
      return;
    }

    await Future.wait(<Future<void>>[
      for (final id in peerIdsToFetch)
        _conversationRepository.getUserBasicProfile(id.toString()).then((raw) {
          final profile = unwrapEnvelope(raw);
          if (profile != null && profile.isNotEmpty) {
            _peerProfileCache[id] = profile;
          }
        }),
      // One batch read; it records `premiumUser` for the verified badge.
      if (groupCallerIds.isNotEmpty)
        _conversationRepository
            .getUserBasicProfiles([for (final id in groupCallerIds) '$id'])
            .then((_) => _groupCallersNoted.addAll(groupCallerIds)),
      for (final id in groupIdsToFetch)
        _conversationRepository.getConversation(id.toString()).then((convo) {
          final title = convo?.title?.trim() ?? '';
          if (title.isNotEmpty) _groupTitleCache[id] = title;
        }),
    ]);
  }
}
