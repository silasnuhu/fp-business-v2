import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/services/media/media_repository.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
import 'package:whoxa/featuers/chat/data/conversation_adapter.dart';
import 'package:whoxa/featuers/chat/repository/conversation_repository.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

class ArchiveChatProvider with ChangeNotifier {
  final ConsoleAppLogger _logger = ConsoleAppLogger();
  late final ConversationRepository _conversationRepository;
  late final MediaRepository _mediaRepository;

  // ✅ NEW: Callback to notify ChatProvider of archive changes
  Function(int chatId, bool isArchived)? _onArchiveStatusChanged;

  List<Chats> _archivedChats = [];
  Pagination? _pagination;
  bool _isLoading = false;
  bool _hasMoreData = true;
  final int _pageSize = 10;

  // NEW backend's `GET /conversations?archived=true` returns `{items,
  // nextCursor}` with NO total, and `_archivedChats` above only ever holds
  // the pages actually scrolled into view — so its `.length` is useless as a
  // badge count (caps at `_pageSize`, resets on every refresh). `_archivedTotal`
  // is kept accurate by a cheap cursor sweep (`refreshArchivedCount`) that
  // walks every archived page counting rows only, no per-row enrichment.
  int _archivedTotal = 0;
  bool _isCountingArchived = false;

  /// Page size for the count-only sweep — bigger than `_pageSize` since it
  /// skips the N+1 peer-profile / preview fetches the display fetch does.
  static const int _countSweepPageSize = 50;

  /// Safety cap so a pathologically large archive can't spin forever.
  static const int _countSweepMaxPages = 40;
  // NEW: cursor pagination instead of page numbers (§5.2/§10) — `_pagination`
  // above is kept only so nothing reading `.pagination` elsewhere breaks; it
  // is always null now.
  String? _nextCursor;

  ArchiveChatProvider(ApiClient apiClient) {
    _conversationRepository = ConversationRepository(apiClient);
    _mediaRepository = MediaRepository(apiClient);
  }

  List<Chats> get archivedChats => _archivedChats;
  Pagination? get pagination => _pagination;
  bool get isLoading => _isLoading;
  bool get hasMoreData => _hasMoreData;
  bool get hasArchivedChats => _archivedChats.isNotEmpty;

  /// Accurate number of archived conversations for this user (not just the
  /// pages currently loaded into `archivedChats`). Drives the "Archived" row
  /// badge on the home screen. Kept live by [refreshArchivedCount], which is
  /// re-run after every fetch and after every archive/unarchive.
  int get archivedTotal => _archivedTotal;
  
  // ✅ NEW: Set callback for archive status changes
  void setOnArchiveStatusChanged(Function(int chatId, bool isArchived) callback) {
    _onArchiveStatusChanged = callback;
  }

  // ✅ CRITICAL: Store the last requested chat ID for context
  int? _lastRequestedChatId;

  // ✅ NEW: Track archive operation status
  bool _lastArchiveSuccess = false;
  String? _lastArchiveError;

  void setLastRequestedChatId(int chatId) {
    _lastRequestedChatId = chatId;
  }

  bool get lastArchiveSuccess => _lastArchiveSuccess;
  String? get lastArchiveError => _lastArchiveError;

  void handleArchiveChat(dynamic chatData) {
    try {
      _logger.d('handleArchiveChat called with data: $chatData (type: ${chatData.runtimeType})');

      // ✅ HANDLE BOTH STRING AND MAP RESPONSES
      // If the response is a String (e.g., for demo accounts or errors)
      if (chatData is String) {
        _logger.w('Received String response for archive_chat: $chatData');
        _lastArchiveSuccess = false;
        _lastArchiveError = chatData;

        // Clear the last requested chat ID
        if (_lastRequestedChatId != null) {
          _lastRequestedChatId = null;
        }

        notifyListeners();
        return;
      }

      // ✅ HANDLE MAP RESPONSE (normal case)
      if (chatData is! Map<String, dynamic>) {
        _logger.e('Unexpected data type for archive_chat: ${chatData.runtimeType}');
        _lastArchiveSuccess = false;
        _lastArchiveError = 'Invalid response format';
        notifyListeners();
        return;
      }

      // ✅ FIXED: Handle the actual response format from the socket
      // Response format: {success: true, message: "chat archived : false/true"}
      if (chatData['success'] == true && chatData['message'] != null) {
        final message = chatData['message'].toString();
        _logger.d('Archive response message: $message');

        // ✅ NEW: Mark as success
        _lastArchiveSuccess = true;
        _lastArchiveError = null;

        // Extract archive status from message
        final isArchived = message.contains('archived : true');
        final isUnarchived = message.contains('archived : false');

        if (_lastRequestedChatId != null) {
          final chatId = _lastRequestedChatId!;

          if (isArchived) {
            _logger.d('Chat $chatId was archived');
            // Note: For archive, we don't add to _archivedChats here because
            // the archived chat list will be refreshed separately
            _onArchiveStatusChanged?.call(chatId, true);
          } else if (isUnarchived) {
            _logger.d('Chat $chatId was unarchived - notifying ChatProvider to add back to main list');

            // ✅ CRITICAL: Remove from archived list first
            _archivedChats.removeWhere((chat) => chat.records?.first.chatId == chatId);

            // ✅ ENHANCED: Always notify ChatProvider to add back to main list
            _onArchiveStatusChanged?.call(chatId, false);
          }

          // Clear the last requested chat ID after processing
          _lastRequestedChatId = null;
        } else {
          _logger.w('No chat ID context available for archive response');
        }
      } else {
        // ✅ NEW: Mark as failure
        _lastArchiveSuccess = false;
        _lastArchiveError = chatData['message']?.toString() ?? 'Unknown error occurred';
        _logger.w('Archive operation failed: $_lastArchiveError');
        _logger.w('Unexpected archive response format: $chatData');

        // Clear the last requested chat ID after processing
        if (_lastRequestedChatId != null) {
          _lastRequestedChatId = null;
        }
      }

      // ✅ NEW: Always notify listeners for real-time UI updates
      notifyListeners();
    } catch (e) {
      _logger.e('Error handling archive chat event: $e');
      // ✅ NEW: Still notify listeners even on error to ensure UI consistency
      notifyListeners();
    }
  }

  void handleArchivedChatList(Map<String, dynamic> payload) {
    try {
      _logger.d('handleArchivedChatList called with payload: $payload');

      _isLoading = false;
      
      // ✅ FIXED: Better null safety and validation
      if (payload.isEmpty) {
        _logger.w('Empty payload received for archived chat list');
        notifyListeners();
        return;
      }
      
      _pagination = payload['pagination'] != null
          ? Pagination.fromJson(payload['pagination'])
          : null;

      List<Chats> newChats = [];
      if (payload['Chats'] != null && payload['Chats'] is List) {
        try {
          newChats = List<Chats>.from(
            payload['Chats'].map((e) => Chats.fromJson(e)),
          );
        } catch (e) {
          _logger.e('Error parsing archived chats data: $e');
          notifyListeners();
          return;
        }
      }

      // ✅ FIXED: Better pagination handling
      final currentPage = _pagination?.currentPage ?? 1;
      if (currentPage == 1) {
        _archivedChats = newChats;
      } else {
        // ✅ FIXED: Prevent duplicates when adding to existing list
        final existingChatIds = _archivedChats
            .map((chat) => chat.records?.first.chatId)
            .where((id) => id != null)
            .toSet();
        
        final newUniqueChats = newChats.where((chat) {
          final chatId = chat.records?.first.chatId;
          return chatId != null && !existingChatIds.contains(chatId);
        }).toList();
        
        _archivedChats.addAll(newUniqueChats);
      }

      _hasMoreData = _pagination != null && _pagination!.currentPage != null && _pagination!.totalPages != null
          ? (_pagination!.currentPage! < _pagination!.totalPages!)
          : false;

      // ✅ IMPROVED: Only notify for new chats to prevent redundant updates
      if (_onArchiveStatusChanged != null && currentPage == 1) {
        for (final chat in newChats) {
          final chatId = chat.records?.first.chatId;
          if (chatId != null) {
            _onArchiveStatusChanged!(chatId, true);
          }
        }
      }

      notifyListeners();
    } catch (e) {
      _logger.e('Error handling archived chat list event: $e');
      _isLoading = false;
      // ✅ FIXED: Ensure state is consistent even on error
      _hasMoreData = false;
      notifyListeners();
    }
  }

  /// NEW: archived list is `GET /conversations?archived=true&cursor=` —
  /// `page` is kept as a param (1 = fresh fetch, anything else = "load
  /// more" using the stored cursor) purely for call-site compatibility with
  /// `loadMoreArchivedChats` below; the real pagination token is the cursor.
  Future<void> fetchArchivedChats({int page = 1}) async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      notifyListeners();
      _logger.d('Fetching archived chats (page=$page, NEW: cursor-based)');

      final myId = await SecurePrefs.getString(SecureStorageKeys.USERID) ?? '';
      final cursor = page == 1 ? null : _nextCursor;

      final result = await _conversationRepository.getConversations(
        cursor: cursor,
        limit: _pageSize,
        archived: true,
      );
      _nextCursor = result.nextCursor;
      _hasMoreData = result.nextCursor != null;

      // One `GET /users/batch?ids=…` for the whole page's 1:1 peers; ids the
      // batch doesn't return fall back to the single-id lookup.
      final peerIds =
          result.items
              .map((c) => ConversationAdapter.peerIdFor(c, myId))
              .whereType<String>()
              .toSet()
              .toList();
      final batchedProfiles = await _conversationRepository
          .getUserBasicProfiles(peerIds);

      final newChats = await Future.wait(
        result.items.map((conversation) async {
          final peerId = ConversationAdapter.peerIdFor(conversation, myId);
          final peerProfile =
              peerId == null
                  ? null
                  : batchedProfiles[peerId] ??
                      unwrapEnvelope(
                        await _conversationRepository.getUserBasicProfile(
                          peerId,
                        ),
                      );
          final preview = await _conversationRepository.getLatestMessagePreview(
            conversation.id,
          );
          // `avatarMediaId`/`profilePic` can be bare media ids, and
          // `GET /media/:id` returns metadata rather than bytes — resolve
          // them to the row's `cdnUrl` before handing them to the UI.
          final avatarUrl =
              conversation.type == 'group'
                  ? await _mediaRepository.getDisplayUrl(
                    conversation.avatarMediaId,
                  )
                  : null;
          final peerAvatarUrl = await _mediaRepository.getDisplayUrl(
            (peerProfile?['profilePic'] ?? peerProfile?['profile_pic'])
                as String?,
          );
          return ConversationAdapter.toChat(
            conversation: conversation,
            currentUserId: myId,
            archived: true,
            peerProfile: peerProfile,
            previewMessage: preview,
            avatarUrl: avatarUrl,
            peerAvatarUrl: peerAvatarUrl,
          );
        }),
      );

      if (page == 1) {
        _archivedChats = newChats;
      } else {
        final existingIds =
            _archivedChats
                .map((c) => c.records?.first.chatId)
                .whereType<int>()
                .toSet();
        _archivedChats.addAll(
          newChats.where(
            (c) => !existingIds.contains(c.records?.first.chatId),
          ),
        );
      }

      _isLoading = false;
      notifyListeners();

      // Keep the home-screen badge count accurate. If the first page already
      // returned everything (no next cursor) we know the exact total for free;
      // otherwise walk the rest with a cheap count-only sweep.
      if (page == 1 && result.nextCursor == null) {
        _setArchivedTotal(newChats.length);
      } else {
        unawaited(refreshArchivedCount());
      }
    } catch (e) {
      _logger.e('Error fetching archived chats: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// NEW: two explicit calls (PATCH .../archive | /unarchive), no more
  /// toggle — `isArchived` (the target state, not the current one) must be
  /// supplied by the caller.
  Future<bool> archiveUnarchiveChat(int chatId, bool isArchived) async {
    try {
      setLastRequestedChatId(chatId);
      await _conversationRepository.setArchived(
        chatId.toString(),
        isArchived,
      );

      _lastArchiveSuccess = true;
      _lastArchiveError = null;

      if (isArchived) {
        _onArchiveStatusChanged?.call(chatId, true);
      } else {
        _archivedChats.removeWhere(
          (chat) => chat.records?.first.chatId == chatId,
        );
        _onArchiveStatusChanged?.call(chatId, false);
      }

      // Reflect the change on the badge immediately, then reconcile against
      // the server with a count sweep (covers races / multi-device changes).
      _setArchivedTotal(_archivedTotal + (isArchived ? 1 : -1));
      unawaited(refreshArchivedCount());

      _lastRequestedChatId = null;
      notifyListeners();
      return true;
    } catch (e) {
      _logger.e('Error archiving/unarchiving chat: $e');
      _lastArchiveSuccess = false;
      _lastArchiveError = e.toString();
      _lastRequestedChatId = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadMoreArchivedChats() async {
    if (!_hasMoreData || _isLoading) {
      _logger.d('loadMoreArchivedChats: Cannot load more - hasMoreData: $_hasMoreData, isLoading: $_isLoading');
      return;
    }

    _logger.d('loadMoreArchivedChats: Loading next page via cursor');
    await fetchArchivedChats(page: 2);
  }

  /// Walks every archived-conversation page (rows only, no per-row peer /
  /// preview fetch) to compute an accurate [archivedTotal] independent of how
  /// many pages `archivedChats` currently holds. Safe to fire-and-forget.
  Future<void> refreshArchivedCount() async {
    if (_isCountingArchived) return;
    _isCountingArchived = true;
    try {
      int total = 0;
      String? cursor;
      for (var i = 0; i < _countSweepMaxPages; i++) {
        final result = await _conversationRepository.getConversations(
          cursor: cursor,
          limit: _countSweepPageSize,
          archived: true,
        );
        total += result.items.length;
        cursor = result.nextCursor;
        if (cursor == null || cursor.isEmpty) break;
      }
      _setArchivedTotal(total);
    } catch (e) {
      _logger.e('Error counting archived chats: $e');
    } finally {
      _isCountingArchived = false;
    }
  }

  void _setArchivedTotal(int value) {
    final next = value < 0 ? 0 : value;
    if (next == _archivedTotal) return;
    _archivedTotal = next;
    notifyListeners();
  }

  /// [resetCount] is for logout/teardown — a plain pull-to-refresh leaves the
  /// last known [archivedTotal] in place so the badge doesn't flash empty
  /// before the refetch lands.
  void clearArchivedChats({bool resetCount = false}) {
    _archivedChats.clear();
    _pagination = null;
    _nextCursor = null;
    _hasMoreData = true;
    if (resetCount) _archivedTotal = 0;
    notifyListeners();
  }

  /// ✅ NEW: Update archived chat with new message (real-time updates)
  ///
  /// [currentUserId] / [isViewingThisChat] let the unread badge follow the
  /// exact same rules as the main chat list (see
  /// `SocketEventController._updateUnreadCount`): +1 only for a message from
  /// another user, and forced to 0 while that chat is on screen.
  void updateArchivedChatWithNewMessage(
    dynamic newMessage, {
    int? currentUserId,
    bool isViewingThisChat = false,
  }) {
    try {
      _logger.d('🗃️ Updating archived chat with new message: chatId=${newMessage?.chatId}, senderId=${newMessage?.senderId}');
      _logger.d('🗃️ Current archived chats count: ${_archivedChats.length}');

      if (newMessage?.chatId == null) {
        _logger.w('Cannot update archived chat - no chat ID in message');
        return;
      }

      final messageChatId = newMessage.chatId;
      bool chatUpdated = false;

      // If no archived chats are loaded, check if this message is for an archived chat
      if (_archivedChats.isEmpty) {
        _logger.d('🔄 No archived chats loaded, checking if message is for archived chat...');
        
        // Check if the message has archive information
        final chatData = newMessage.chat;
        if (chatData != null && chatData.archivedFor != null) {
          _logger.d('📦 Message has archive info: ${chatData.archivedFor}');
          
          // If this chat is archived, we should load archived chats to show the update
          if (chatData.archivedFor.isNotEmpty) {
            _logger.d('🔄 Message is for archived chat, fetching archived chats...');
            Future.microtask(() => fetchArchivedChats());
            return; // Exit early, fetchArchivedChats will load the data
          }
        }
      }

      // Find the matching archived chat
      for (int i = 0; i < _archivedChats.length; i++) {
        final chat = _archivedChats[i];
        final record = chat.records?.isNotEmpty == true ? chat.records!.first : null;
        
        if (record?.chatId == messageChatId) {
          _logger.d('📝 Found matching archived chat at index $i - updating with new message');
          
          // Update the chat record with new message
          _updateArchivedChatRecord(
            record!,
            newMessage,
            i,
            currentUserId: currentUserId,
            isViewingThisChat: isViewingThisChat,
          );
          chatUpdated = true;
          break;
        }
      }

      if (chatUpdated) {
        // Notify listeners for real-time UI updates
        notifyListeners();
        _logger.d('✅ Archived chat updated successfully');
      } else {
        _logger.d('🔍 No matching archived chat found for chatId: $messageChatId');
      }

    } catch (e) {
      _logger.e('❌ Error updating archived chat with new message: $e');
    }
  }

  /// ✅ HELPER: Update archived chat record with new message
  void _updateArchivedChatRecord(
    dynamic chatRecord,
    dynamic newMessage,
    int chatIndex, {
    int? currentUserId,
    bool isViewingThisChat = false,
  }) {
    try {
      // Move the updated chat to the top of the list (like main chat list)
      if (chatIndex > 0) {
        final updatedChat = _archivedChats.removeAt(chatIndex);
        _archivedChats.insert(0, updatedChat);
        _logger.d('📈 Moved updated archived chat to top of list');
      }

      // Update or add the new message to the chat record
      if (chatRecord.messages?.isNotEmpty == true) {
        final existingMessage = chatRecord.messages!.first;
        
        // Update the existing message with new message data
        existingMessage.messageContent = newMessage.messageContent ?? existingMessage.messageContent;
        existingMessage.messageType = newMessage.messageType ?? existingMessage.messageType;
        existingMessage.createdAt = newMessage.createdAt ?? existingMessage.createdAt;
        existingMessage.senderId = newMessage.senderId ?? existingMessage.senderId;
        existingMessage.messageId = newMessage.messageId ?? existingMessage.messageId;
        
        // Update call data if present
        if (newMessage.calls != null) {
          existingMessage.calls = newMessage.calls;
        }
        
        _logger.d('📝 Updated existing message in archived chat');
      } else {
        // Create new Messages object using the Messages.fromJson method
        try {
          final newMessageData = {
            'message_content': newMessage.messageContent,
            'message_type': newMessage.messageType,
            'message_id': newMessage.messageId,
            'chat_id': newMessage.chatId,
            'sender_id': newMessage.senderId,
            'createdAt': newMessage.createdAt,
            'updatedAt': newMessage.updatedAt,
            'Calls': newMessage.calls,
            'User': newMessage.user,
            'message_seen_status': newMessage.messageSeenStatus,
            'deleted_for': newMessage.deletedFor ?? [],
            'starred_for': newMessage.starredFor ?? [],
            'deleted_for_everyone': newMessage.deletedForEveryone ?? false,
            'pinned': newMessage.pinned ?? false,
          };
          
          // Use the Messages.fromJson to create proper message object
          final messageObj = Messages.fromJson(newMessageData);
          chatRecord.messages = [messageObj];
          _logger.d('🆕 Created new properly formatted message for archived chat');
        } catch (e) {
          _logger.e('❌ Error creating message object: $e');
          // Fallback to simple update
          chatRecord.messages = [_createSimpleArchivedChatMessage(newMessage)];
        }
      }

      // Update chat record timestamps and unseen count
      if (newMessage.createdAt != null) {
        chatRecord.updatedAt = newMessage.createdAt;
      }

      // Unread badge — mirror the main chat list
      // (`SocketEventController._updateUnreadCount`).
      //
      // ⚠️ Do NOT copy `newMessage.unseenCount` here: on the NEW backend that
      // field does not carry a count, it carries the message's
      // `conversationSeq` (see `MessageAdapter.toRecord`). Assigning it made
      // the archived-row badge display an ever-growing sequence number that
      // climbed with every message and never reset after the chat was read.
      final int? senderId = int.tryParse('${newMessage.senderId}');
      final bool isFromOther = senderId != null &&
          currentUserId != null &&
          senderId != currentUserId;
      if (isViewingThisChat) {
        chatRecord.unseenCount = 0;
      } else if (isFromOther) {
        chatRecord.unseenCount = (chatRecord.unseenCount ?? 0) + 1;
      }

    } catch (e) {
      _logger.e('❌ Error updating archived chat record: $e');
    }
  }

  /// ✅ HELPER: Create a properly formatted archived chat message (fallback)
  dynamic _createSimpleArchivedChatMessage(dynamic newMessage) {
    // Create a simple message object as fallback
    return {
      'message_content': newMessage.messageContent,
      'message_type': newMessage.messageType,
      'message_id': newMessage.messageId,
      'chat_id': newMessage.chatId,
      'sender_id': newMessage.senderId,
      'createdAt': newMessage.createdAt,
      'updatedAt': newMessage.updatedAt,
      'calls': newMessage.calls,
    };
  }

  /// ✅ NEW: Clear unseen count for a specific archived chat
  void clearArchivedChatUnseenCount(int chatId) {
    try {
      _logger.d('🗃️ Clearing unseen count for archived chat: $chatId');
      
      bool updated = false;
      for (int i = 0; i < _archivedChats.length; i++) {
        final chat = _archivedChats[i];
        final record = chat.records?.isNotEmpty == true ? chat.records!.first : null;
        
        if (record?.chatId == chatId) {
          final oldCount = record?.unseenCount ?? 0;
          if (oldCount > 0) {
            record!.unseenCount = 0;
            updated = true;
            _logger.d('✅ Cleared archived chat $chatId unseen count: $oldCount → 0');
          }
          break;
        }
      }
      
      if (updated) {
        notifyListeners();
      } else {
        _logger.d('🔍 Archived chat $chatId not found or already has 0 unseen count');
      }
    } catch (e) {
      _logger.e('❌ Error clearing archived chat unseen count: $e');
    }
  }

  /// ✅ NEW: Get current unseen count for a specific archived chat
  int getArchivedChatUnseenCount(int chatId) {
    try {
      for (final chat in _archivedChats) {
        final record = chat.records?.isNotEmpty == true ? chat.records!.first : null;
        if (record?.chatId == chatId) {
          return record?.unseenCount ?? 0;
        }
      }
    } catch (e) {
      _logger.e('❌ Error getting archived chat unseen count: $e');
    }
    return 0;
  }
}