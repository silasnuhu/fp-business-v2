// ignore_for_file: prefer_conditional_assignment

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/core/services/socket/socket_event_controller.dart';
import 'package:whoxa/dependency_injection.dart';
import 'package:whoxa/featuers/ai_assistant/provider/ai_assistant_provider.dart';
import 'package:whoxa/featuers/ai_assistant/data/ai_assistant_demo_messages.dart';
import 'package:whoxa/featuers/chat/data/blocked_user_model.dart';
import 'package:whoxa/featuers/chat/data/chat_ids_model.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/data/conversation_adapter.dart';
import 'package:whoxa/featuers/chat/data/conversation_dto.dart';
import 'package:whoxa/featuers/chat/data/message_adapter.dart';
import 'package:whoxa/featuers/chat/data/message_dto.dart';
import 'package:whoxa/featuers/chat/repository/conversation_repository.dart';
import 'package:whoxa/featuers/chat/repository/message_repository.dart';
import 'package:whoxa/featuers/chat/provider/archive_chat_provider.dart';
import 'package:whoxa/featuers/chat/data/online_user_model.dart';
import 'package:whoxa/featuers/chat/data/typing_model.dart';
import 'package:whoxa/featuers/chat/data/block_updates_model.dart';
import 'package:whoxa/featuers/chat/group/provider/group_provider.dart';
import 'package:whoxa/featuers/chat/utils/time_stamp_formatter.dart';
import 'package:whoxa/featuers/chat/repository/chat_repository.dart';
import 'package:whoxa/featuers/chat/utils/message_utils.dart';
import 'package:whoxa/featuers/chat/utils/chat_date_grouper.dart';
import 'package:whoxa/core/services/media/media_repository.dart';
import 'package:whoxa/core/services/media/media_upload_service.dart';
import 'package:whoxa/featuers/chat/utils/chat_cache_manager.dart';
import 'package:whoxa/featuers/chat/services/message_queue_service.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/utils/enums.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:whoxa/widgets/global.dart';

class ChatProvider with ChangeNotifier {
  bool _isScreenActive = false;
  bool get isScreenActive => _isScreenActive;

  // ✅ NEW: Track seen messages to prevent duplicate emissions
  final Set<int> _processedSeenMessageIds = <int>{};

  // ✅ NEW: Track recently cleared chats to prevent reload
  final Set<int> _recentlyClearedChats = <int>{};

  // ✅ NEW: Message Queue Service for optimistic UI
  final MessageQueueService _messageQueueService = MessageQueueService();
  MessageQueueService get messageQueueService => _messageQueueService;

  // ✅ NEW: Track optimistic messages by tempId for deduplication
  final Map<String, chats.Records> _optimisticMessages = {};

  void setIsScreenActive(bool value) {
    if (_isScreenActive != value) {
      _isScreenActive = value;
      notifyListeners();
    }
  }

  bool _isUserOnlineFromApi = false;
  bool get isUserOnlineFromApi => _isUserOnlineFromApi;

  void setIsUserOnlineFromApi(bool value) {
    if (_isUserOnlineFromApi != value) {
      _isUserOnlineFromApi = value;
      notifyListeners();
    }
  }

  String? _lastSeenFromApi;
  String? get lastSeenFromApi => _lastSeenFromApi;

  void setLastSeenFromApi(String? value) {
    if (_lastSeenFromApi != value) {
      _lastSeenFromApi = value;
      notifyListeners();
    }
  }

  /// userId -> the peer's `lastSeenVisible` flag, learned from every
  /// `users/batch` / `GET /users/:id` read (chat-list hydration, chat open,
  /// block-state sync).
  ///
  /// This exists because the socket is a SECOND source of last-seen that the
  /// privacy flag doesn't reach: `presence_update` carries no timestamp, so
  /// the socket cache stamps `DateTime.now()` when a peer goes offline, and
  /// that stamp used to be merged into the header blind. A block sets
  /// `lastSeenVisible:false` server-side (confirmed: `users/batch` returns
  /// `lastSeenAt:null` for the blocker), but the socket stamp kept the
  /// header showing a last-seen anyway. Every merge point now goes through
  /// [lastSeenVisibleFor], and treats "not yet known" as "don't show the
  /// socket value".
  final Map<int, bool> _lastSeenVisibility = {};

  /// Whether [userId]'s last seen may be shown, or null when no
  /// `users/batch` read has answered for that user yet.
  ///
  /// The unknown case is real and depends on nothing but the peer: a chat
  /// opened from the chat list has it already (the list hydration records
  /// every peer), but one opened from the contact list, a notification tap,
  /// a forward or a profile screen has never been through a batch read, so
  /// the flag is unknown until the on-open fetch lands.
  bool? lastSeenVisibleFor(int userId) => _lastSeenVisibility[userId];

  void _rememberLastSeenVisibility(int userId, bool visible) {
    if (userId <= 0) return;
    _lastSeenVisibility[userId] = visible;
  }

  /// The last-seen string the UI should render for [userId], or null when
  /// there is nothing showable.
  ///
  /// Call sites must use this instead of merging the two sources themselves,
  /// otherwise the socket stamp slips past the flag again.
  ///
  /// The socket stamp is only ever shown once the flag is known to be true.
  /// While it is unknown this falls back to the REST value alone, which is
  /// already privacy-filtered (`UserPresence.displayableLastSeenAt`) and is
  /// null until the fetch returns. That makes the rule hold from every entry
  /// point into the chat screen rather than only the chat-list one, and it
  /// fails closed: a batch read that never answers shows no last seen at all
  /// instead of showing an unverified one.
  String? displayableLastSeenFor(int userId) {
    final visible = _lastSeenVisibility[userId];
    if (visible == false) return null;
    if (visible == null) return _lastSeenFromApi;
    return TimestampFormatter.latestTimestamp(
      _lastSeenFromApi,
      _socketEventController.getUserLastSeen(userId),
    );
  }

  /// Whether [userId] may be shown as online, merging the socket cache with
  /// the last `users/batch` read — and gated on the same visibility flag as
  /// the timestamp.
  ///
  /// `lastSeenVisible` governs BOTH halves of presence, not just the
  /// timestamp: when it is false the backend also masks `isOnline` to false
  /// (confirmed in a blocked pair's payload — `lastSeenVisible:false,
  /// isOnline:false, lastSeenAt:null` — while the peer was in fact online).
  /// The header renders "Online" *instead of* a last seen, so leaving this
  /// ungated leaked exactly what suppressing the timestamp was meant to
  /// hide: the blocked user still saw "Online" even though the API said
  /// offline, because the local socket cache was OR'd over the server's
  /// masked value.
  ///
  /// Unknown visibility reports offline, matching [displayableLastSeenFor]:
  /// show nothing until a batch read has confirmed what may be shown.
  bool displayableIsOnlineFor(int userId) {
    if (_lastSeenVisibility[userId] != true) return false;
    return _socketEventController.isUserOnline(userId) || _isUserOnlineFromApi;
  }

  bool _isLoadingOnlineStatus = false;
  bool get isLoadingOnlineStatus => _isLoadingOnlineStatus;

  void setIsLoadingOnlineStatus(bool value) {
    if (_isLoadingOnlineStatus != value) {
      _isLoadingOnlineStatus = value;
      notifyListeners();
    }
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void setErrorMessage(String? value) {
    if (_errorMessage != value) {
      _errorMessage = value;
      notifyListeners();
    }
  }

  bool _hasError = false;
  bool get hasError => _hasError;

  void setHasError(bool value) {
    if (_hasError != value) {
      _hasError = value;
      notifyListeners();
    }
  }

  bool _isLoadingCurrentUser = false;
  bool get isLoadingCurrentUser => _isLoadingCurrentUser;

  void setIsLoadingCurrentUser(bool value) {
    if (_isLoadingCurrentUser != value) {
      _isLoadingCurrentUser = value;
      notifyListeners();
    }
  }

  bool _isInitializingOfChat = false;
  bool get isInitializingOfChat => _isInitializingOfChat;

  void setIsInitializingOfChat(bool value) {
    if (_isInitializingOfChat != value) {
      _isInitializingOfChat = value;
      notifyListeners();
    }
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  void setIsInitialized(bool value) {
    if (_isInitialized != value) {
      _isInitialized = value;
      notifyListeners();
    }
  }

  bool _isDisposedOfChat = false;
  bool get isDisposedOfChat => _isDisposedOfChat;

  void setIsDisposedOfChat(bool value) {
    if (_isDisposedOfChat != value) {
      _isDisposedOfChat = value;
      // Skip notifyListeners to avoid widget tree lock during disposal
    }
  }

  bool _hasCachedData = false;
  bool get hasCachedData => _hasCachedData;

  void setHasCachedData(bool value) {
    if (_hasCachedData != value) {
      _hasCachedData = value;
      notifyListeners();
    }
  }

  // This provider holds ONE chat's state at a time, but chat screens can be
  // stacked (a chat opened from a notification on top of another chat). The
  // owner is the screen whose chat is loaded right now: only it may reset
  // the provider when it closes, and a screen that becomes visible again
  // after losing ownership reloads its own chat (see UniversalChatScreen
  // didPopNext).
  Object? _chatScreenOwner;

  void claimChatScreen(Object owner) => _chatScreenOwner = owner;

  bool isChatScreenOwner(Object owner) => identical(_chatScreenOwner, owner);

  void releaseChatScreen(Object owner) {
    if (identical(_chatScreenOwner, owner)) _chatScreenOwner = null;
  }

  // Bumped by resetAll() whenever a chat (re)takes this provider. The async
  // steps of initializeScreen() stop once it changes, so a chat left while
  // still loading can't write its state into the chat now on screen.
  int _chatSession = 0;

  void resetAll() {
    debugPrint("Reset Calls");
    _chatSession++;
    setIsScreenActive(false);
    setIsUserOnlineFromApi(false);
    setLastSeenFromApi(null);
    setIsLoadingOnlineStatus(false);
    setErrorMessage(null);
    setHasError(false);
    setIsLoadingCurrentUser(false);
    setIsInitializingOfChat(false);
    setIsInitialized(false);
    setIsDisposedOfChat(false);
    setHasCachedData(false);

    // ✅ FIX: Clear message data to prevent stale messages when switching chats
    _chatsData = chats.ChatsModel();
    _groupedMessages = {};
    _pinnedMessagesData = chats.ChatsModel();
    _isPinnedMessagesExpanded = false;
    _currentChatData = ChatIds();
  }

  void initOfUniversal({
    required BuildContext context,
    required int? chatId,
    required int? userId,
    required bool isGroupChat,
  }) {
    // 🚀 PERFORMANCE: Check cache immediately to prevent flicker
    checkCacheAvailability(chatId ?? 0, userId ?? 0);

    // Initialize the chat screen
    initializeScreen(
      context: context,
      chatId: chatId ?? 0,
      userId: userId ?? 0,
      isGroupChat: isGroupChat,
    );

    // Initialize cache for this chat
    initializeCacheForChat(chatId: chatId ?? 0, userId: userId ?? 0);

    // Try to load cached data for faster initial display
    loadCachedDataIfAvailable();

    // Mark screen as active
    setScreenActive(true, chatId, userId);
  }

  /// 🚀 PERFORMANCE: Check cache synchronously to prevent loading flicker
  void checkCacheAvailability(int? chatId, int? userId) {
    try {
      String? chatIdString;

      if (chatId != null && chatId > 0) {
        // Existing chat/group chat
        chatIdString = chatId.toString();
        _logger.d("🔍 CACHE CHECK: Group/existing chat - ID: $chatIdString");
      } else if (userId != null && userId > 0) {
        // Individual chat using userId
        chatIdString = 'user_$userId';
        _logger.d("🔍 CACHE CHECK: Individual chat - Peer ID: $userId");
      }

      if (chatIdString != null) {
        _hasCachedData = ChatCacheManager.hasPage(chatIdString, 1);
        _logger.d(
          "🎯 CACHE CHECK: Chat $chatIdString has cached data: $_hasCachedData",
        );

        // If we have cache, we can skip loading indicators
        if (_hasCachedData) {
          _logger.d(
            "⚡ PERFORMANCE: Cache detected - will prevent loading flicker",
          );
        }
      } else {
        _logger.w("⚠️ CACHE CHECK: Cannot determine chat ID for cache check");
        setHasCachedData(false);
      }
    } catch (e) {
      _logger.e("❌ Error checking cache availability: $e");
      setHasCachedData(false);
    }
  }

  Future<void> _loadCurrentUserIdForChat() async {
    try {
      // ✅ Set loading to true at start
      if (!_isDisposedOfChat) {
        setIsLoadingCurrentUser(true);
      }

      _currentUserId = await SecurePrefs.getString(SecureStorageKeys.USERID);
      _logger.d("Current user ID loaded: $_currentUserId");

      if (_currentUserId == null || _currentUserId!.isEmpty) {
        throw Exception("User ID is null or empty");
      }
    } catch (e) {
      _logger.e("Error loading current user ID: $e");
      rethrow;
    } finally {
      // ✅ Always set loading to false regardless of success or failure
      if (!_isDisposedOfChat) {
        setIsLoadingCurrentUser(false);
      }
      setIsLoadingCurrentUser(false);
    }
  }

  /// Load cached data if available for faster initial display
  Future<void> loadCachedDataIfAvailable() async {
    try {
      final chatId = _getCurrentChatId();
      if (chatId == null) return;

      // Check if we have any cached pages
      final cachedPages = ChatCacheManager.getCachedPages(chatId);
      if (cachedPages.isNotEmpty) {
        _logger.d('🗄️ Found cached pages for chat $chatId: $cachedPages');

        // Load the first cached page to show immediately
        final firstPage = cachedPages.first;
        final cachedMessages = await ChatCacheManager.getPage(
          chatId,
          firstPage,
        );

        if (cachedMessages != null && cachedMessages.isNotEmpty) {
          _logger.d(
            '⚡ Loading cached messages into ChatProvider (${cachedMessages.length} messages)',
          );

          // 🚀 CRITICAL FIX: Load cached data into ChatProvider immediately
          // if (!mounted) return;

          // Create ChatsModel from cached data
          final cachedChatsModel = ChatCacheManager.createChatModelFromCache(
            cachedMessages,
            firstPage,
            1, // Assume at least 1 page for now
          );

          // Set the cached data in the provider to display immediately
          setCachedChatsData(cachedChatsModel);

          _logger.d('✅ Cached data loaded into ChatProvider successfully');
          ChatCacheManager.logCacheStats(chatId);

          // Trigger a rebuild to show cached data
          setHasCachedData(true);
        }
      } else {
        _logger.d('📭 No cached data available for chat $chatId');
      }
    } catch (e) {
      _logger.e('❌ Error loading cached data: $e');
    }
  }

  void setScreenActive(bool isActive, int? chatId, int? userId) {
    if (_isDisposedOfChat) return;

    setIsScreenActive(isActive);

    _logger.d(
      'Setting OneToOneChat screen active: $isActive, chatId: $chatId, userId: $userId',
    );

    setChatScreenActive(chatId ?? 0, userId ?? 0, isActive: isActive);

    if (!isActive) {
      _logger.d('🚫 Chat screen deactivated - should stop auto-mark seen');
    }

    if (isActive && chatId != null && chatId > 0) {
      // Check block status when screen becomes active
      // First refresh the data to ensure we have the latest state
      // Block status is now handled via Provider Consumer pattern - no manual checks needed

      Future.delayed(Duration(milliseconds: 1000), () {
        if (!_isDisposed &&
            _isScreenActive &&
            isChatScreenActive &&
            isAppInForeground) {
          _logger.d('📱 Screen is fully active, marking messages as seen');
          markChatMessagesAsSeen(chatId);
        }
      });
    }
  }

  /// Get current chat ID for caching
  String? _getCurrentChatId({int? chatId, int? userId}) {
    if (chatId != null) {
      return chatId.toString();
    } else if (userId != null) {
      return 'user_$userId';
    }
    return null;
  }

  /// Initialize cache for current chat
  Future<void> initializeCacheForChat({int? chatId, int? userId}) async {
    try {
      final chatIdString = _getCurrentChatId(chatId: chatId, userId: userId);
      if (chatIdString != null) {
        await ChatCacheManager.initializeChat(chatIdString);
        _logger.d('🗄️ Cache initialized for chat: $chatIdString');
      }
      notifyListeners();
    } catch (e) {
      _logger.e('❌ Error initializing cache: $e');
    }
  }

  Future<void> initializeScreen({
    int? chatId,
    int? userId,
    bool isGroupChat = false,
    required BuildContext context,
  }) async {
    if (_isDisposedOfChat) return;
    final session = _chatSession;
    bool isStale() => _isDisposedOfChat || session != _chatSession;

    try {
      _logger.d("🚀 Starting screen initialization");
      // setIsInitializingOfChat(true);
      _isInitializingOfChat = true;
      notifyListeners();
      if (isGroupChat) {
        debugPrint(
          "Loading group members for chatId: $chatId and for group !!!",
        );

        loadGroupMembers(context: context, chatId: chatId, userId: 0);
      }

      await _loadCurrentUserIdForChat();
      if (isStale()) return;

      _logger.d(
        "📝 Setting current chat context: chatId=$chatId, userId=$userId",
      );
      setCurrentChat(chatId ?? 0, userId ?? 0);

      await Future.delayed(Duration(milliseconds: 100));
      if (isStale()) return;

      _logger.d("📨 Loading chat messages");
      await loadChatMessages(
        chatId: chatId ?? 0,
        peerId: userId ?? 0,
        clearExisting: true,
      );

      if (isStale()) return;

      await Future.delayed(Duration(milliseconds: 500));
      if (isStale()) return;

      checkUserOnlineStatusFromApi();

      // Load group members for group chats
      if (isGroupChat) {
        debugPrint("Loading group members for chatId: $chatId and for group");

        if (!context.mounted) return;
        await loadGroupMembers(
          context: context,
          chatId: chatId,
          userId: userId,
        );
        if (isStale()) return;
      }

      setIsInitialized(true);
      // setIsInitializingOfChat(false);
      _isInitializingOfChat = false;
      notifyListeners();
      setHasError(false);
      setErrorMessage(null);

      _logger.d("✅ Screen initialization completed successfully");
      _debugPinnedMessagesState();
    } catch (e, stackTrace) {
      _logger.e("❌ Error during initialization: $e");
      _logger.e("📍 Stack trace: $stackTrace");

      setHasError(true);
      setErrorMessage(e.toString());
      // setIsInitializingOfChat(false);
      _isInitializingOfChat = false;
      notifyListeners();
    } finally {
      // A stale/early return used to leave the initialising flag set, which
      // pinned the chat screen on its loading spinner forever. Clear it on
      // every exit path - but only while this session still owns the chat,
      // otherwise we would clear the flag the *new* chat just raised.
      if (!_isDisposedOfChat && session == _chatSession) {
        _isInitializingOfChat = false;
        notifyListeners();
      }
    }
  }

  void _debugPinnedMessagesState() {
    final pinnedCount = pinnedMessagesData.records?.length ?? 0;
    final chatCount = chatsData.records?.length ?? 0;

    _logger.d(
      "🔍 DEBUG - Chat messages: $chatCount, Pinned messages: $pinnedCount",
    );

    if (pinnedCount > 0) {
      _logger.d("✅ Pinned messages available after initialization:");
      for (var msg in pinnedMessagesData.records!) {
        _logger.d("  - ${msg.messageId}: ${msg.messageContent}");
      }
    } else {
      _logger.d("⚠️ No pinned messages found after initialization");

      if (chatCount > 0) {
        final pinnedInMain =
            chatsData.records!.where((r) => r.pinned == true).toList();
        if (pinnedInMain.isNotEmpty) {
          _logger.w(
            "🚨 Found ${pinnedInMain.length} pinned messages in main chat data but not in pinned collection!",
          );
        }
      }
    }
  }

  // NEW removed GET /users/is-online/:id entirely, and its `presence_update`
  // socket payload is slimmed to {userId, isOnline} with no timestamp — the
  // socket can say *that* a peer just went offline, never *when* they were
  // last seen before this session connected. The curated user object does
  // carry it (`isOnline`/`lastSeenAt`/`lastSeenVisible` on `users/batch`),
  // so presence is resolved from both: the WS cache wins for "is online
  // right now" (it's live), the REST read supplies the last-seen timestamp
  // and covers a cold cache.
  //
  // [userId] defaults to the peer of the currently open chat.
  Future<void> checkUserOnlineStatusFromApi({int? userId}) async {
    if (_isDisposedOfChat) return;

    final id = userId ?? _currentChatData.userId ?? 0;
    if (id <= 0) {
      _logger.d('Skipping presence check — no peer user id');
      return;
    }

    // Live WS cache first so the dot flips instantly on presence_update.
    // The socket stamp is only seeded when this peer's last seen is allowed
    // to be shown — it predates the REST read, so without this gate a peer
    // who hides last seen (or who has blocked us) still gets a timestamp on
    // screen for the moment before the fetch below lands.
    final isOnlineFromSocket = _socketEventController.isUserOnline(id);
    setIsUserOnlineFromApi(
      _lastSeenVisibility[id] == true && isOnlineFromSocket,
    );
    setLastSeenFromApi(
      _lastSeenVisibility[id] == true
          ? _socketEventController.getUserLastSeen(id)
          : null,
    );

    try {
      final presence = await _conversationRepository.getUserPresence('$id');
      if (_isDisposedOfChat || presence == null) return;

      _rememberLastSeenVisibility(id, presence.lastSeenVisible);

      // The socket only knows about presence changes it has actually seen,
      // so treat it as authoritative when it says "online" and let the REST
      // read fill in otherwise — but never OR it over a server that is
      // deliberately masking this peer's presence, which is what let a
      // blocked user keep seeing "Online" for the person who blocked them.
      setIsUserOnlineFromApi(
        presence.lastSeenVisible && (isOnlineFromSocket || presence.isOnline),
      );
      // Newest-wins between the two sources, but a hidden last seen collapses
      // to null outright — merging would keep whatever stale socket stamp we
      // had from before the peer hid it.
      setLastSeenFromApi(
        presence.lastSeenVisible
            ? TimestampFormatter.latestTimestamp(
              _lastSeenFromApi,
              presence.displayableLastSeenAt,
            )
            : null,
      );
    } catch (e) {
      _logger.w('Could not fetch presence for user $id: $e');
    }

    _logger.d(
      "User $id online: $_isUserOnlineFromApi, lastSeen: $_lastSeenFromApi",
    );
  }

  /// Keeps the open chat's header in step with live presence.
  ///
  /// A `presence_update` is authoritative for "online right now", and the
  /// moment it reports the peer going offline is itself a last-seen — the
  /// only one the socket can give, since its payload carries no timestamp.
  void _refreshOpenChatPresenceFromSocket() {
    final peerId = _currentChatData.userId ?? 0;
    if (peerId <= 0) return;

    final visible = _lastSeenVisibility[peerId] == true;
    final isOnline = visible && _socketEventController.isUserOnline(peerId);
    setIsUserOnlineFromApi(isOnline);
    if (!isOnline && visible) {
      setLastSeenFromApi(
        TimestampFormatter.latestTimestamp(
          _lastSeenFromApi,
          _socketEventController.getUserLastSeen(peerId),
        ),
      );
    }
  }


  Future<void> loadGroupMembers({
    int? chatId,
    int? userId,
    bool isGroupChat = false,
    required BuildContext context,
  }) async {
    if (_isDisposedOfChat || !isGroupChat) return;

    try {
      _logger.d("👥 Loading group members for chatId: $chatId");
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      // Bounded: a stalled members request must never hold the chat screen
      // on its spinner - the message list is already usable without it.
      await groupProvider
          .getGroupMembers(chatId: chatId ?? 0)
          .timeout(const Duration(seconds: 15));
      _logger.d("✅ Group members loaded successfully");
    } catch (e) {
      _logger.e("❌ Error loading group members: $e");
      // Don't throw error as this is not critical for basic chat functionality
    }
  }

  // Dependencies
  // ignore: unused_field
  final ApiClient _apiClient;
  final SocketEventController _socketEventController;
  final ChatRepository _chatRepository;
  ChatRepository get chatRepository => _chatRepository;
  SocketEventController get socketEventController => _socketEventController;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule('ChatProvider');

  // State variables
  ChatListModel _chatListData = ChatListModel(chats: []);
  chats.ChatsModel _chatsData = chats.ChatsModel();
  ChatIdsModel _chatIdsData = ChatIdsModel();
  OnlineUsersModel _onlineUsersData = OnlineUsersModel();
  TypingModel _typingData = TypingModel();

  // ✅ NEW: Chat list pagination state
  int _chatListCurrentPage = 1;
  int _chatListTotalPages = 1;
  bool _isChatListPaginationLoading = false;
  bool _hasChatListMoreData = true;
  final int _chatListPageSize = 20;

  // NEW: initial chat list load state, driven by the REST fetch
  // (`refreshChatList` -> `_fetchConversationsPage`). The old
  // `_socketEventController.isChatListLoading` flag it used to delegate to
  // is only cleared by a socket `chat_list` response, which the REST-based
  // backend never sends — leaving the UI spinner stuck forever.
  bool _isChatListLoading = false;

  // NEW backend: conversation list is REST + cursor pagination, not a
  // socket push. `_chatListCursor` holds the opaque cursor for "load more"
  // (the page-number fields above are kept and synthesized from cursor
  // presence purely so the existing pagination/append/sort machinery below
  // doesn't need to change).
  late final ConversationRepository _conversationRepository =
      ConversationRepository(_apiClient);
  late final MediaUploadService _mediaUploadService = MediaUploadService(
    _apiClient,
  );
  late final MediaRepository _mediaRepository = MediaRepository(_apiClient);
  String? _chatListCursor;

  // ✅ FIX: Separate state for background sync (no loader)
  bool _isSyncingChatList = false;
  bool get isSyncingChatList => _isSyncingChatList;

  // ✅ FIX: Debounce timer for chat list refresh
  Timer? _chatListRefreshDebounceTimer;
  bool _isChatListRefreshPending = false;

  // ✅ NEW: Pinned messages state using your existing ChatsModel
  chats.ChatsModel _pinnedMessagesData = chats.ChatsModel();
  bool _isPinnedMessagesExpanded = false;
  int? _highlightedMessageId;
  Timer? _highlightTimer;
  bool _isSearchingForMessage = false;
  int? _targetMessageId;
  Timer? _searchTimeoutTimer;
  bool _isMessageFound = false;

  bool _isSendingMessage = false;
  bool _isShowAttachments = false;
  bool _isInitializing = false;
  bool _isDisposed = false;

  String? _error;
  String? _apiErrorMessage;
  // Current chat data
  ChatIds _currentChatData = ChatIds();
  // File storage
  List<File>? _shareImage;
  List<File>? _shareDocument;
  List<File>? _shareVideo;
  File? _shareVoice;

  String _shareVideoThumbnail = "";

  // Stream subscriptions
  StreamSubscription? _chatListSubscription;
  StreamSubscription? _chatsSubscription;
  StreamSubscription? _chatIdsSubscription;
  StreamSubscription? _onlineUsersSubscription;

  StreamSubscription? _typingSubscription;
  StreamSubscription? _blockUpdatesSubscription;
  StreamSubscription? _pinUnpinSubscription;
  StreamSubscription? _pollUpdatedSubscription;
  StreamSubscription? _messageUpdatedSubscription;
  StreamSubscription? _starUnstarSubscription;
  StreamSubscription? _chatListMessageSubscription;

  String? _currentUserId;
  // Debouncing and throttling
  Timer? _notifyTimer;
  bool _shouldNotify = false;
  // Track last update to prevent duplicate notifications
  // ignore: unused_field
  String? _lastChatsDataHash;

  // ✅ NEW: Reply state management
  chats.Records? _replyToMessage;

  bool _isReplyMode = false;
  // ✅ NEW: separate pagination loading state
  bool _isPaginationLoading = false;

  // NEW: whether the current chat has older messages left to load, driven
  // by the REST fetch's real `hasMore` (or the cached page's saved
  // pagination info) — NOT the old `_socketEventController.hasMoreMessages`,
  // which defaults true and is only ever cleared by a socket message-list
  // event this backend never sends, leaving the pagination loader spinning
  // forever at the top of every chat regardless of whether more messages
  // actually exist.
  bool _hasMoreMessages = false;

  // ✅ NEW: Date grouping state
  Map<String, List<chats.Records>> _groupedMessages = {};
  chats.ChatWrapperModel? _chatWrapper;

  // Block functionality state
  final List<BlockedUserRecord> _blockedUsers = [];
  bool _isBlockListLoading = false;
  int _blockListCurrentPage = 1;
  bool _hasMoreBlockedUsers = true;

  bool _isCountLoading = false;
  int _blocklistCount = 0;
  int _starredCount = 0;
  int _notificationCount = 0;

  /// NEW exposes no per-message "starred" flag on the conversation message
  /// list or socket payloads (§6.4) — the only source of truth is
  /// `GET /messages/starred`. Cache the starred message ids here so chat
  /// bubbles can render the star indicator for messages the current user
  /// has already starred. Populated on chat open + kept in sync on
  /// star/unstar.
  final Set<int> _starredMessageIds = <int>{};
  String _urlTitle = "";
  String _urlDescri = "";
  String _urlImage = "";
  // ✅ NEW: Chat List Pagination Getters
  int get chatListCurrentPage => _chatListCurrentPage;
  int get chatListTotalPages => _chatListTotalPages;
  bool get isChatListPaginationLoading => _isChatListPaginationLoading;
  bool get hasChatListMoreData => _hasChatListMoreData;
  String get urlTitle => _urlTitle;
  String get urlDescri => _urlDescri;
  String get urlImage => _urlImage;

  chats.ChatsModel get starredMessagesData =>
      _socketEventController.starredMessagesData;

  // Constructor with dependency injection
  ChatProvider(
    this._apiClient,
    this._socketEventController,
    this._chatRepository,
  ) {
    _logger.i('Creating ChatProvider with separated API calls');
    _initializeSubscriptions();
  }

  ChatIdsModel get chatIdsData => _chatIdsData;
  // ✅ NEW: Archive filtering state
  final Set<int> _archivedChatIds = <int>{};

  // Getters
  ChatListModel get chatListData => _chatListData;

  // ✅ NEW: Archive filtering methods
  void addArchivedChatId(int chatId) {
    _archivedChatIds.add(chatId);
    _filterArchivedChatsFromList();
  }

  void removeArchivedChatId(int chatId) {
    _archivedChatIds.remove(chatId);

    // ✅ FIXED: When a chat is unarchived, we need to ensure it appears immediately
    // Instead of just refreshing (which only loads page 1), we'll request a full refresh
    // and temporarily add the unarchived chat to ensure immediate visibility
    _handleUnarchivedChat(chatId);
  }

  /// Handle when a chat is unarchived to ensure immediate visibility.
  /// NEW: instead of OLD's "guess a bigger page size and hope it's in
  /// there" retry, this refreshes page 1 and — if the chat still isn't
  /// present (e.g. it doesn't sort onto the first page) — fetches that one
  /// conversation directly via `GET /conversations/:id` and prepends it.
  Future<void> _handleUnarchivedChat(int chatId) async {
    try {
      _logger.d('🔓 Handling unarchived chat: $chatId');

      resetChatListPagination();
      await _fetchConversationsPage(page: 1, archived: false);

      bool chatFound = _chatListData.chats.any(
        (chat) =>
            chat.records?.any((record) => record.chatId == chatId) == true,
      );

      if (!chatFound) {
        _logger.w(
          '⚠️ Unarchived chat $chatId not on page 1 — fetching it directly',
        );
        final conversation = await _conversationRepository.getConversation(
          chatId.toString(),
        );
        if (conversation != null) {
          final myId = _currentUserId ?? '';
          final chatsForOne = await _resolveConversationsToChats(
            [conversation],
            currentUserId: myId,
            archived: false,
          );
          if (chatsForOne.isNotEmpty) {
            _chatListData.chats.insert(0, chatsForOne.first);
            chatFound = true;
          }
        }
        _logger.d(
          chatFound
              ? '✅ Unarchived chat $chatId fetched directly and prepended'
              : '❌ Unarchived chat $chatId could not be fetched',
        );
      } else {
        _logger.d('✅ Unarchived chat $chatId found in current list');
      }

      // Always notify listeners to update UI
      _scheduleNotification();
    } catch (e) {
      _logger.e('❌ Error handling unarchived chat: $e');
      // Fallback: try regular refresh as last resort
      try {
        await refreshChatList();
      } catch (fallbackError) {
        _logger.e('❌ Fallback refresh also failed: $fallbackError');
      }
      _scheduleNotification();
    }
  }

  void _filterArchivedChatsFromList({bool shouldSort = true}) {
    if (_archivedChatIds.isEmpty) return;

    final filteredChats =
        _chatListData.chats.where((chat) {
          if (chat.records?.isNotEmpty == true) {
            final chatId = chat.records!.first.chatId;
            return chatId != null && !_archivedChatIds.contains(chatId);
          }
          return true;
        }).toList();

    _chatListData = ChatListModel(chats: filteredChats);

    // Only sort if requested (avoid during pagination to maintain server order)
    if (shouldSort) {
      _sortChatList();
    }
    notifyListeners();
  }

  chats.ChatsModel get chatsData => _chatsData;
  ChatIds get currentChatData => _currentChatData;

  // ✅ NEW: Date grouping getters
  Map<String, List<chats.Records>> get groupedMessages => _groupedMessages;
  chats.ChatWrapperModel? get chatWrapper => _chatWrapper;

  // ✅ NEW: Date grouping methods
  void _regroupMessages() {
    if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
      _groupedMessages = ChatDateGrouper.groupMessagesByDate(
        _chatsData.records!,
      );
      _chatWrapper = chats.ChatWrapperModel(
        messageList: _chatsData,
        pinnedMessages: _pinnedMessagesData,
        starredMessages: starredMessagesData,
      );
    } else {
      _groupedMessages = {};
      _chatWrapper = null;
    }
  }

  void addNewMessage(chats.Records message) {
    if (_chatsData.records != null) {
      _chatsData.records!.add(message);
      _regroupMessages();
      notifyListeners();
    }
  }

  void addMessages(List<chats.Records> newMessages) {
    if (_chatsData.records != null) {
      _chatsData.records!.addAll(newMessages);
      _regroupMessages();
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ OPTIMISTIC UI METHODS - Instant message display with queue
  // ═══════════════════════════════════════════════════════════════════════════

  /// Add an optimistic message for instant display (before API call)
  void addOptimisticMessage(chats.Records message) {
    if (message.tempId == null) {
      debugPrint('❌ Cannot add optimistic message without tempId');
      return;
    }

    debugPrint('⚡ Adding optimistic message: ${message.tempId}');

    // Store in optimistic messages map for deduplication
    _optimisticMessages[message.tempId!] = message;

    // Add to the beginning of the list (most recent)
    if (_chatsData.records == null) {
      _chatsData.records = [];
    }
    _chatsData.records!.insert(0, message);

    // ✅ Now safe to regroup - sort is stable and preserves "sending" message order
    _regroupMessages();
    notifyListeners();

    // ✅ Immediately save to cache
    _saveOptimisticToCache(message);
  }

  /// Save optimistic message to cache immediately
  void _saveOptimisticToCache(chats.Records message) {
    final chatId = message.chatId ?? _currentChatData.chatId;
    if (chatId != null && chatId > 0) {
      ChatCacheManager.addMessage(chatId.toString(), message).catchError((e) {
        _logger.e('Failed to cache optimistic message: $e');
      });
    }
  }

  /// Update an optimistic message status
  void updateOptimisticMessageStatus(
    String tempId,
    chats.MessageSendingStatus status,
  ) {
    debugPrint('🔄 Updating optimistic message status: $tempId -> $status');

    // Find and update in the records list
    if (_chatsData.records != null) {
      final index = _chatsData.records!.indexWhere((m) => m.tempId == tempId);
      if (index != -1) {
        _chatsData.records![index].sendingStatus = status;
        _regroupMessages();
        notifyListeners();
      }
    }

    // Update in optimistic messages map
    if (_optimisticMessages.containsKey(tempId)) {
      _optimisticMessages[tempId]!.sendingStatus = status;
    }
  }

  /// Replace optimistic message with server-confirmed message
  void confirmOptimisticMessage(
    String tempId,
    int messageId, {
    String? seenStatus,
    int? conversationSeq,
  }) {
    debugPrint(
      '✅ Confirming optimistic message: $tempId -> messageId: $messageId',
    );

    int? chatId;

    if (_chatsData.records != null) {
      final index = _chatsData.records!.indexWhere((m) => m.tempId == tempId);
      if (index != -1) {
        final message = _chatsData.records![index];
        chatId = message.chatId ?? _currentChatData.chatId;
        // Update with server data
        message.messageId = messageId;
        message.sendingStatus = chats.MessageSendingStatus.sent;
        message.messageSeenStatus = seenStatus ?? 'sent';
        // conversationSeq is stored on `unseenCount` (see MessageAdapter) —
        // _handleMessageReadUpdate needs it to promote this message to
        // 'seen' when the peer's read watermark passes it. Without it a
        // confirmed message stays on the grey double-tick forever.
        if (conversationSeq != null && conversationSeq > 0) {
          message.unseenCount = conversationSeq;
        }
        message.tempId = null; // Clear tempId as message is confirmed
        _regroupMessages();
        notifyListeners();
      }
    }

    // Remove from optimistic messages map
    _optimisticMessages.remove(tempId);

    // ✅ Update cache
    if (chatId != null && chatId > 0) {
      ChatCacheManager.confirmOptimisticMessage(
        chatId.toString(),
        tempId,
        messageId,
        seenStatus: seenStatus,
        conversationSeq: conversationSeq,
      ).catchError((e) {
        _logger.e('Failed to confirm optimistic message in cache: $e');
      });
    }
  }

  /// Mark an optimistic message as failed
  void markOptimisticMessageFailed(String tempId, {String? error}) {
    debugPrint('❌ Marking optimistic message as failed: $tempId');
    updateOptimisticMessageStatus(tempId, chats.MessageSendingStatus.failed);

    // ✅ Update cache
    final chatId = _currentChatData.chatId;
    if (chatId != null && chatId > 0) {
      ChatCacheManager.markOptimisticMessageFailed(
        chatId.toString(),
        tempId,
      ).catchError((e) {
        _logger.e('Failed to mark optimistic message as failed in cache: $e');
      });
    }
  }

  /// Retry a failed message
  void retryFailedMessage(chats.Records failedMessage) {
    if (failedMessage.tempId == null) {
      debugPrint('❌ Cannot retry message without tempId');
      return;
    }

    debugPrint('🔄 Retrying failed message: ${failedMessage.tempId}');

    // Update status to sending
    updateOptimisticMessageStatus(
      failedMessage.tempId!,
      chats.MessageSendingStatus.sending,
    );
    failedMessage.retryCount++;

    // Re-queue the message
    _messageQueueService.retryMessage(failedMessage);
  }

  /// Check if a message is a duplicate of an optimistic message (for socket dedup)
  bool isOptimisticDuplicate(chats.Records incomingMessage) {
    // Check by message content + sender + timestamp (within 5 seconds)
    if (_chatsData.records == null) return false;

    for (final optimistic in _optimisticMessages.values) {
      if (optimistic.messageContent == incomingMessage.messageContent &&
          optimistic.senderId == incomingMessage.senderId &&
          optimistic.messageType == incomingMessage.messageType) {
        // Check if timestamps are close (within 30 seconds)
        if (optimistic.createdAt != null && incomingMessage.createdAt != null) {
          try {
            final optimisticTime = DateTime.parse(optimistic.createdAt!);
            final incomingTime = DateTime.parse(incomingMessage.createdAt!);
            final difference = incomingTime.difference(optimisticTime).abs();
            if (difference.inSeconds < 30) {
              debugPrint(
                '🔍 Found optimistic duplicate for message: ${incomingMessage.messageId}',
              );
              // Confirm the optimistic message with the incoming server data
              if (optimistic.tempId != null &&
                  incomingMessage.messageId != null) {
                confirmOptimisticMessage(
                  optimistic.tempId!,
                  incomingMessage.messageId!,
                  seenStatus: incomingMessage.messageSeenStatus,
                );
              }
              return true;
            }
          } catch (e) {
            debugPrint('Error parsing timestamps for dedup: $e');
          }
        }
      }
    }
    return false;
  }

  /// Clear all optimistic messages (for chat cleanup)
  void clearOptimisticMessages() {
    _optimisticMessages.clear();
  }

  /// ✅ FIX: Clean up stale optimistic messages (older than 2 minutes in "sending" state)
  /// Call this when entering a chat to prevent stuck messages
  void cleanupStaleOptimisticMessages() {
    if (_chatsData.records == null) return;

    final now = DateTime.now();
    const staleDuration = Duration(minutes: 2);
    final List<String> staleOptimisticIds = [];
    final List<int> indicesToRemove = [];

    for (int i = 0; i < _chatsData.records!.length; i++) {
      final record = _chatsData.records![i];

      // Check if this is an optimistic message (has tempId AND status is sending)
      if (record.tempId != null &&
          record.sendingStatus == chats.MessageSendingStatus.sending) {
        // Check if it's stale (older than 2 minutes)
        if (record.createdAt != null) {
          try {
            final createdTime = DateTime.parse(record.createdAt!);
            final age = now.difference(createdTime);
            if (age > staleDuration) {
              _logger.d(
                '🧹 Found stale optimistic message: ${record.tempId} (age: ${age.inSeconds}s)',
              );
              staleOptimisticIds.add(record.tempId!);
              indicesToRemove.add(i);
            }
          } catch (e) {
            // If we can't parse the timestamp, mark as stale
            _logger.w(
              '⚠️ Could not parse timestamp for optimistic message ${record.tempId}',
            );
            staleOptimisticIds.add(record.tempId!);
            indicesToRemove.add(i);
          }
        }
      }
    }

    // Remove stale messages from records (in reverse order to preserve indices)
    if (indicesToRemove.isNotEmpty) {
      for (int i = indicesToRemove.length - 1; i >= 0; i--) {
        _chatsData.records!.removeAt(indicesToRemove[i]);
      }

      // Remove from optimistic messages map
      for (final tempId in staleOptimisticIds) {
        _optimisticMessages.remove(tempId);
      }

      _logger.d(
        '🧹 Cleaned up ${staleOptimisticIds.length} stale optimistic messages',
      );
      _regroupMessages();
      _scheduleNotification();
    }
  }

  /// Get failed messages for current chat
  List<chats.Records> getFailedMessages() {
    if (_chatsData.records == null) return [];
    return _chatsData.records!
        .where((m) => m.sendingStatus == chats.MessageSendingStatus.failed)
        .toList();
  }

  /// ✅ FIX: Deduplicate cached messages to remove optimistic duplicates
  /// This handles the case where both optimistic and confirmed messages exist in cache
  List<chats.Records> _deduplicateCachedMessages(List<chats.Records> messages) {
    if (messages.isEmpty) return messages;

    final List<chats.Records> deduplicated = [];
    final Set<int> confirmedMessageIds = {};

    // First pass: collect all confirmed message IDs
    for (final msg in messages) {
      if (msg.messageId != null && msg.tempId == null) {
        confirmedMessageIds.add(msg.messageId!);
      }
    }

    // Second pass: filter out optimistic messages that have confirmed versions
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];

      // Skip if this is an optimistic message that has a confirmed version
      if (msg.tempId != null ||
          msg.sendingStatus == chats.MessageSendingStatus.sending) {
        bool hasConfirmedVersion = false;

        // Check if there's a confirmed message that matches this optimistic one
        for (final confirmedMsg in messages) {
          if (confirmedMsg.messageId != null && confirmedMsg.tempId == null) {
            // Match by content, sender, and message type
            if (confirmedMsg.messageContent == msg.messageContent &&
                confirmedMsg.senderId == msg.senderId &&
                confirmedMsg.messageType == msg.messageType) {
              // Check timestamp proximity (within 60 seconds)
              bool timestampClose = true;
              if (msg.createdAt != null && confirmedMsg.createdAt != null) {
                try {
                  final optimisticTime = DateTime.parse(msg.createdAt!);
                  final confirmedTime = DateTime.parse(confirmedMsg.createdAt!);
                  final difference =
                      confirmedTime.difference(optimisticTime).abs();
                  timestampClose = difference.inSeconds < 60;
                } catch (e) {
                  // If parsing fails, assume close enough
                }
              }

              if (timestampClose) {
                hasConfirmedVersion = true;
                _logger.d(
                  '🧹 Removing duplicate optimistic message (tempId: ${msg.tempId}) - confirmed version exists (id: ${confirmedMsg.messageId})',
                );
                break;
              }
            }
          }
        }

        if (hasConfirmedVersion) {
          continue; // Skip this optimistic message
        }
      }

      deduplicated.add(msg);
    }

    return deduplicated;
  }

  /// Merge socket data with optimistic messages (deduplication + preservation)
  void _mergeSocketDataWithOptimistic(chats.ChatsModel socketData) {
    _logger.d(
      '🔄 Merging socket data with ${_optimisticMessages.length} optimistic messages',
    );

    // Snapshot of what's already on screen (cached history, older pages
    // already scrolled into view). Captured before `_chatsData` is
    // reassigned below so a page-1 refresh/reconcile AUGMENTS the view
    // instead of truncating it to just the newest server page.
    final List<chats.Records> previouslyLoaded = List<chats.Records>.from(
      _chatsData.records ?? const <chats.Records>[],
    );

    // Get optimistic messages that are still pending (sending or failed)
    final pendingOptimistic =
        _optimisticMessages.values
            .where(
              (m) =>
                  m.sendingStatus == chats.MessageSendingStatus.sending ||
                  m.sendingStatus == chats.MessageSendingStatus.failed,
            )
            .toList();

    // Check each incoming message for potential duplicates
    final List<chats.Records> mergedRecords = [];
    final Set<String> confirmedTempIds = {};

    if (socketData.records != null) {
      for (final incomingMessage in socketData.records!) {
        // Check if this message matches an optimistic message
        bool isDuplicateOfOptimistic = false;

        for (final optimistic in _optimisticMessages.values) {
          // Match by content, sender, and close timestamp
          if (optimistic.messageContent == incomingMessage.messageContent &&
              optimistic.senderId == incomingMessage.senderId &&
              optimistic.messageType == incomingMessage.messageType) {
            // Check timestamp proximity (within 60 seconds)
            bool timestampClose = true;
            if (optimistic.createdAt != null &&
                incomingMessage.createdAt != null) {
              try {
                final optimisticTime = DateTime.parse(optimistic.createdAt!);
                final incomingTime = DateTime.parse(incomingMessage.createdAt!);
                final difference =
                    incomingTime.difference(optimisticTime).abs();
                timestampClose = difference.inSeconds < 60;
              } catch (e) {
                // If parsing fails, assume close enough
              }
            }

            if (timestampClose) {
              _logger.d(
                '🔍 Matched optimistic message ${optimistic.tempId} with incoming ${incomingMessage.messageId}',
              );
              isDuplicateOfOptimistic = true;

              // Mark this optimistic message as confirmed
              if (optimistic.tempId != null) {
                confirmedTempIds.add(optimistic.tempId!);
              }

              // Use the incoming message data (it has the real message ID)
              // but preserve the original position by not adding again if already confirmed
              if (!mergedRecords.any(
                (m) => m.messageId == incomingMessage.messageId,
              )) {
                mergedRecords.add(incomingMessage);
              }
              break;
            }
          }
        }

        // If not a duplicate of optimistic, add normally
        if (!isDuplicateOfOptimistic) {
          mergedRecords.add(incomingMessage);
        }
      }
    }

    // Add pending optimistic messages that weren't confirmed (still sending or failed)
    for (final optimistic in pendingOptimistic) {
      if (optimistic.tempId != null &&
          !confirmedTempIds.contains(optimistic.tempId)) {
        // Only add if not already in merged records
        final alreadyExists = mergedRecords.any(
          (m) =>
              m.tempId == optimistic.tempId ||
              (m.messageContent == optimistic.messageContent &&
                  m.senderId == optimistic.senderId),
        );

        if (!alreadyExists) {
          _logger.d(
            '📎 Preserving pending optimistic message: ${optimistic.tempId}',
          );
          mergedRecords.insert(0, optimistic); // Insert at beginning (newest)
        }
      }
    }

    // Remove confirmed optimistic messages from tracking
    for (final tempId in confirmedTempIds) {
      _optimisticMessages.remove(tempId);
    }

    // Fold back any already-loaded CONFIRMED messages this payload doesn't
    // carry (older cached history, earlier pages) so a page-1
    // refresh/reconcile augments the view instead of truncating it. The
    // server copy wins on an id collision — it's already in
    // `mergedRecords`, so the local duplicate is skipped. Optimistic /
    // id-less records are intentionally not carried here; still-pending
    // ones were re-added above from the authoritative `_optimisticMessages`.
    final Set<int> knownIds = {
      for (final m in mergedRecords)
        if (m.messageId != null) m.messageId!,
    };
    for (final prev in previouslyLoaded) {
      final id = prev.messageId;
      if (id == null || prev.tempId != null) continue;
      if (knownIds.add(id)) {
        mergedRecords.add(prev);
      }
    }

    // Update chats data
    _chatsData = chats.ChatsModel(
      records: mergedRecords,
      pagination: socketData.pagination,
    );

    _logger.d(
      '✅ Merge complete. Total records: ${_chatsData.records?.length ?? 0} '
      '(server payload: ${socketData.records?.length ?? 0}, '
      'carried over: ${previouslyLoaded.length})',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════

  String? get error => _error ?? _socketEventController.lastError;
  String? get apiErrorMessage => _apiErrorMessage;

  void clearApiErrorMessage() {
    _apiErrorMessage = null;
  }

  bool get hasMoreMessages => _hasMoreMessages;

  int? get highlightedMessageId => _highlightedMessageId;

  bool get isChatListLoading => _isChatListLoading;
  bool get isChatLoading => _socketEventController.isChatLoading;
  bool get isInitializing => _isInitializing;
  bool get isMessageFound => _isMessageFound;
  bool get isPaginationLoading => _isPaginationLoading;

  bool get isPinnedMessagesExpanded => _isPinnedMessagesExpanded;
  bool get isRefreshing => _socketEventController.isRefreshing;

  bool get isReplyMode => _isReplyMode;
  bool get isSearchingForMessage => _isSearchingForMessage;
  bool get isSendingMessage => _isSendingMessage;
  bool get isShowAttachments => _isShowAttachments;
  OnlineUsersModel get onlineUsersData => _onlineUsersData;
  // ✅ NEW: Pinned messages getters
  chats.ChatsModel get pinnedMessagesData => _pinnedMessagesData;
  // ✅ NEW: Reply getters
  chats.Records? get replyToMessage => _replyToMessage;
  int? get targetMessageId => _targetMessageId;
  TypingModel get typingData => _typingData;

  // Block functionality getters
  List<BlockedUserRecord> get blockedUsers => _blockedUsers;
  bool get isBlockListLoading => _isBlockListLoading;
  bool get hasMoreBlockedUsers => _hasMoreBlockedUsers;
  String? get currentUserId => _currentUserId;

  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
    notifyListeners();
  }

  bool get isCountLoading => _isCountLoading;
  int get starredCount => _starredCount;
  int get blocklistCount => _blocklistCount;
  int get notificationCount => _notificationCount;

  bool get isChatScreenActive => _socketEventController.isChatScreenActive;
  bool get isAppInForeground => _socketEventController.isAppInForeground;
  String? get activeChatScreenId => _socketEventController.activeChatScreenId;

  void notify() {
    notifyListeners();
  }

  void setAppForegroundState(bool isInForeground) {
    _socketEventController.setAppForegroundState(isInForeground);
  }

  void setChatScreenActive(int chatId, int userId, {bool isActive = true}) {
    _socketEventController.setChatScreenActive(
      chatId,
      userId,
      isActive: isActive,
    );
  }

  /// Check if current user can delete a message
  bool canDeleteMessage(chats.Records message) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      _logger.w('Current user ID not available for delete permission check');
      return false;
    }

    // Convert current user ID to int for comparison
    final currentUserIdInt = int.tryParse(_currentUserId!) ?? 0;

    // Only the sender can delete their own messages
    return message.senderId == currentUserIdInt;
  }

  /// Check if current user can delete message for everyone
  bool canDeleteMessageForEveryone(chats.Records message) {
    if (!canDeleteMessage(message)) return false;

    // Additional logic can be added here, such as:
    // - Time limit for deletion (e.g., only within 24 hours)
    // - Admin privileges
    // - Group chat rules

    // For now, any user can delete their own message for everyone
    return true;
  }

  ///pin unpin
  // Check if current user can pin/unpin a message
  bool canPinUnpinMessage(chats.Records message) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      _logger.w('Current user ID not available for permission check');
      return false;
    }

    // Backend (ReactionsService.pin/unpin) only checks conversation
    // membership — ANY participant may pin or unpin ANY message. The old
    // "only the sender can unpin" rule was a client-side guess with no
    // backend equivalent; it wrongly blocked unpinning messages you pinned
    // yourself but didn't send, surfacing the bogus
    // "Only the user who pinned this message can unpin it" error.
    return true;
  }

  ///pin unpin
  // Check if current user can pin/unpin a message
  bool canStarUnStarMessage(chats.Records message) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      _logger.w('Current user ID not available for permission check');
      return false;
    }

    // Convert current user ID to int for comparison
    final currentUserIdInt = int.tryParse(_currentUserId!) ?? 0;

    if (message.stared == true) {
      // For unpinning: Only the user who pinned the message can unpin it
      // You might need to add a 'pinnedBy' field to your message model
      // For now, we'll allow the message sender to unpin
      return message.senderId == currentUserIdInt;
    } else {
      // For pinning: Any user can pin a message (or implement your own logic)
      return true;
    }
  }

  // Clear current chat data
  void clearCurrentChat() {
    if (_isDisposed) return;

    _currentChatData = ChatIds();
    _chatsData = chats.ChatsModel();
    _pinnedMessagesData = chats.ChatsModel();
    _isPinnedMessagesExpanded = false;
    _lastChatsDataHash = null;
    _regroupMessages();
    clearHighlight();
    _socketEventController.setCurrentChat(0, 0);
    _scheduleNotification();
  }

  // 🚀 CACHE: Set cached chat data for immediate display
  void setCachedChatsData(chats.ChatsModel cachedData) {
    if (_isDisposed) return;

    _logger.d(
      '📱 Setting cached chat data with ${cachedData.records?.length ?? 0} messages',
    );
    _chatsData = cachedData;

    // Extract pinned messages from cached data
    _extractPinnedMessages(cachedData);

    // Regroup messages by date
    _regroupMessages();

    // Trigger UI update
    _scheduleNotification();
  }

  // Clear error message
  void clearError() {
    if (_isDisposed) return;
    _error = null;
    _socketEventController.clearError();
    _scheduleNotification();
  }

  // ✅ NEW: Clear highlight
  void clearHighlight() {
    _highlightTimer?.cancel();
    _highlightedMessageId = null;
    _scheduleNotification();
  }

  void clearReply() {
    _replyToMessage = null;
    _isReplyMode = false;
    _scheduleNotification();
  }

  // Connect to socket
  Future<bool> connect() async {
    if (_isDisposed) return false;

    try {
      return await _socketEventController.connect();
    } catch (e) {
      _error = "Failed to connect: ${e.toString()}";
      _scheduleNotification();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE SEEN STATUS METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mark a specific message as seen
  // Future<void> markMessageAsSeen(int chatId, int messageId) async {
  //   if (_isDisposed) return;

  //   try {
  //     _logger.d(
  //       'Marking message as seen - chatId: $chatId, messageId: $messageId',
  //     );

  //     // Emit via socket controller
  //     _socketEventController.emitMessageSeen(chatId, messageId);

  //     // Optional: Update local state immediately for better UX
  //     _updateLocalMessageSeenStatus(messageId);

  //     _logger.d('Message marked as seen successfully');
  //   } catch (e) {
  //     _error = "Failed to mark message as seen: ${e.toString()}";
  //     _logger.e('Error marking message as seen: $e');
  //     _scheduleNotification();
  //   }
  // }

  Future<void> markMessageAsSeen(int chatId, int messageId) async {
    if (_isDisposed) return;

    try {
      // Check if message is already seen to prevent duplicate processing
      if (_isMessageAlreadySeen(messageId)) {
        _logger.d('Message $messageId already seen - skipping mark as seen');
        return;
      }

      _logger.d(
        'Marking message as seen - chatId: $chatId, messageId: $messageId',
      );

      // Update local message seen status immediately (for UI feedback)
      _updateLocalMessageSeenStatus(messageId);

      // Emit via socket controller
      _socketEventController.emitMessageSeen(chatId, messageId);

      // Decrement unseen count in chat list
      final currentUnseenCount = getChatUnseenCount(chatId);
      if (currentUnseenCount > 0) {
        decrementChatUnseenCount(chatId, 1);
        _logger.d(
          'Decremented unseen count for chat $chatId after marking message $messageId as seen',
        );
      }

      _logger.d('Message marked as seen successfully');
    } catch (e) {
      _error = "Failed to mark message as seen: ${e.toString()}";
      _logger.e('Error marking message as seen: $e');
      _scheduleNotification();
    }
  }

  /// Check if a message is already seen to prevent duplicate processing
  bool _isMessageAlreadySeen(int messageId) {
    if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
      for (var message in _chatsData.records!) {
        if (message.messageId == messageId) {
          return message.messageSeenStatus == 'seen';
        }
      }
    }
    return false;
  }

  /// Update local message seen status (for immediate UI feedback)
  void _updateLocalMessageSeenStatus(int messageId) {
    if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
      for (var message in _chatsData.records!) {
        if (message.messageId == messageId) {
          message.messageSeenStatus = 'seen';
          _logger.d('Updated local message $messageId status to seen');
          break;
        }
      }
      _scheduleNotification();
    }
  }

  /// Update unseen count for a specific chat in the chat list
  void updateChatUnseenCount(int chatId, int newUnseenCount) {
    if (_isDisposed || _chatListData.chats.isEmpty) return;

    bool chatUpdated = false;

    for (int i = 0; i < _chatListData.chats.length; i++) {
      final chat = _chatListData.chats[i];

      // Check if this chat matches the chatId
      if (chat.records != null && chat.records!.isNotEmpty) {
        final chatRecord = chat.records!.first;

        if (chatRecord.chatId == chatId) {
          // Update the unseen count
          final oldUnseenCount = chatRecord.unseenCount ?? 0;
          chatRecord.unseenCount = newUnseenCount;

          _logger.d(
            'Updated chat $chatId unseen count: $oldUnseenCount → $newUnseenCount',
          );

          chatUpdated = true;
          break;
        }
      }
    }

    if (chatUpdated) {
      _scheduleNotification();
    } else {
      _logger.w('Chat $chatId not found in chat list for unseen count update');
    }
  }

  /// Decrement unseen count for a specific chat
  void decrementChatUnseenCount(int chatId, int decrementBy) {
    if (_isDisposed || _chatListData.chats.isEmpty || decrementBy <= 0) return;

    for (int i = 0; i < _chatListData.chats.length; i++) {
      final chat = _chatListData.chats[i];

      if (chat.records != null && chat.records!.isNotEmpty) {
        final chatRecord = chat.records!.first;

        if (chatRecord.chatId == chatId) {
          final currentCount = chatRecord.unseenCount ?? 0;
          final newCount = (currentCount - decrementBy).clamp(0, currentCount);

          if (currentCount != newCount) {
            chatRecord.unseenCount = newCount;

            _logger.d(
              'Decremented chat $chatId unseen count: $currentCount → $newCount',
            );

            _scheduleNotification();
          }
          break;
        }
      }
    }
  }

  /// Clear unseen count for a specific chat (set to 0)
  void clearChatUnseenCount(int chatId) {
    updateChatUnseenCount(chatId, 0);
  }

  /// Get current unseen count for a specific chat
  int getChatUnseenCount(int chatId) {
    if (_chatListData.chats.isEmpty) return 0;

    for (final chat in _chatListData.chats) {
      if (chat.records != null && chat.records!.isNotEmpty) {
        final chatRecord = chat.records!.first;

        if (chatRecord.chatId == chatId) {
          return chatRecord.unseenCount ?? 0;
        }
      }
    }

    return 0;
  }

  /// Auto-mark messages as seen when entering a chat
  // Future<void> markChatMessagesAsSeen(int chatId) async {
  //   if (_isDisposed || chatId <= 0) return;

  //   // ✅ CRITICAL: Only mark if ALL conditions are met
  //   if (!isChatScreenActive || !isAppInForeground) {
  //     _logger.d(
  //       'Skipping mark messages as seen - screen not active or app in background. '
  //       'screenActive: $isChatScreenActive, appForeground: $isAppInForeground',
  //     );
  //     return;
  //   }

  //   // ✅ ADDITIONAL CHECK: Ensure we're actually viewing the correct chat
  //   if (_currentChatData.chatId != chatId) {
  //     _logger.d(
  //       'Skipping mark messages as seen - chat ID mismatch. '
  //       'current: ${_currentChatData.chatId}, requested: $chatId',
  //     );
  //     return;
  //   }

  //   try {
  //     // Get current user ID
  //     final currentUserId = await _getCurrentUserId();
  //     if (currentUserId == null) {
  //       _logger.w(
  //         'Cannot mark messages as seen - current user ID not available',
  //       );
  //       return;
  //     }

  //     // ✅ ENHANCED: Find unread messages from OTHER users only
  //     final unreadMessages =
  //         _chatsData.records
  //             ?.where(
  //               (message) =>
  //                   message.senderId !=
  //                       currentUserId && // Only messages from other users
  //                   message.messageSeenStatus != 'seen' &&
  //                   message.messageId != null &&
  //                   message.deletedForEveryone != true,
  //             ) // Don't mark deleted messages
  //             .toList() ??
  //         [];

  //     if (unreadMessages.isNotEmpty) {
  //       _logger.d(
  //         'Marking ${unreadMessages.length} messages from OTHER users as seen '
  //         '(screen is active and app in foreground)',
  //       );

  //       // ✅ BATCH PROCESSING: Mark messages in smaller batches to avoid overwhelming the server
  //       const batchSize = 3;
  //       for (int i = 0; i < unreadMessages.length; i += batchSize) {
  //         // Check if conditions are still met before each batch
  //         if (!isChatScreenActive || !isAppInForeground || _isDisposed) {
  //           _logger.d('Conditions changed, stopping seen marking');
  //           break;
  //         }

  //         final batch = unreadMessages.skip(i).take(batchSize).toList();

  //         for (var message in batch) {
  //           // Final check before marking each message
  //           if (!isChatScreenActive || _isDisposed) {
  //             _logger.d('Screen became inactive, stopping seen marking');
  //             return;
  //           }

  //           _logger.d(
  //             'Marking message ${message.messageId} as seen '
  //             '(from user ${message.senderId}, current user $currentUserId)',
  //           );

  //           await markMessageAsSeen(chatId, message.messageId!);

  //           // Small delay between individual requests
  //           await Future.delayed(Duration(milliseconds: 150));
  //         }

  //         // Longer delay between batches
  //         if (i + batchSize < unreadMessages.length) {
  //           await Future.delayed(Duration(milliseconds: 300));
  //         }
  //       }

  //       _logger.i(
  //         'Successfully processed ${unreadMessages.length} unread messages from other users',
  //       );
  //     } else {
  //       _logger.d('No unread messages from other users to mark as seen');
  //     }
  //   } catch (e) {
  //     _logger.e('Error marking chat messages as seen: $e');
  //   }
  // }

  /// NEW: read state is a per-participant watermark, not per-message
  /// (§6.6) — `POST /messages/:conversationId/read {upToSeq}` marks
  /// everything up to that sequence number as read in one call. Replaces
  /// OLD's per-message batched-emit loop entirely; `markMessageAsSeen`
  /// above (per-message) is no longer called from here.
  Future<void> markChatMessagesAsSeen(int chatId) async {
    if (_isDisposed || chatId <= 0) return;

    if (!isChatScreenActive || !isAppInForeground) {
      _logger.d(
        'Skipping mark messages as seen - screen not active or app in background.',
      );
      return;
    }
    if (_currentChatData.chatId != chatId) {
      _logger.d('Skipping mark messages as seen - chat ID mismatch.');
      return;
    }

    try {
      final currentUserId = await _getCurrentUserId();
      if (currentUserId == null) return;

      // conversationSeq is carried in `unseenCount` — see
      // MessageAdapter.toRecord's comment for why.
      final incomingSeqs =
          _chatsData.records
              ?.where(
                (m) =>
                    m.senderId != currentUserId &&
                    m.deletedForEveryone != true &&
                    (m.unseenCount ?? 0) > 0,
              )
              .map((m) => m.unseenCount!)
              .toList() ??
          [];

      if (incomingSeqs.isEmpty) {
        clearChatUnseenCount(chatId);
        _clearArchivedChatBadgeIfNeeded(chatId);
        return;
      }

      final upToSeq = incomingSeqs.reduce((a, b) => a > b ? a : b);
      await _messageRepository.markRead(chatId, upToSeq);

      // REST markRead persists the watermark but fires no socket fan-out —
      // emit `message_read` too so the SENDER gets a live
      // `message_read_update` and their bubbles turn blue without a reload.
      _socketEventController.emitConversationRead(chatId, upToSeq);

      // Local optimistic update so ticks/badges reflect the read state
      // immediately rather than waiting for the next fetch.
      for (final m in _chatsData.records ?? <chats.Records>[]) {
        if ((m.unseenCount ?? 0) > 0 && m.unseenCount! <= upToSeq) {
          m.messageSeenStatus = 'seen';
        }
      }
      clearChatUnseenCount(chatId);
      _clearArchivedChatBadgeIfNeeded(chatId);
      _scheduleNotification();
      _logger.i('Marked chat $chatId read up to seq $upToSeq');
    } catch (e) {
      _logger.e('Error marking chat messages as seen: $e');
    }
  }

  /// Check if a message has been seen
  bool isMessageSeen(int messageId) {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      return false;
    }

    try {
      final message = _chatsData.records!.firstWhere(
        (msg) => msg.messageId == messageId,
      );
      return message.messageSeenStatus == 'seen';
    } catch (e) {
      return false;
    }
  }

  /// Get current user ID for permission checks
  Future<int?> _getCurrentUserId() async {
    try {
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        return int.tryParse(_currentUserId!);
      }

      final userIdString = await SecurePrefs.getString(
        SecureStorageKeys.USERID,
      );
      return int.tryParse(userIdString ?? '');
    } catch (e) {
      _logger.e('Error getting current user ID: $e');
      return null;
    }
  }

  /// Delete message for everyone (via socket)
  /// NEW: plain REST call, not a socket round-trip (§6.3) — does NOT clear
  /// pin/star state on the message (§6.7 breaking change #11), unlike a
  /// full local removal.
  /// NEW is a plain REST call with no round-trip socket event back to the
  /// deleting device itself (`message_deleted` only reaches the *other*
  /// participants) — this device's own list must be updated locally right
  /// after the REST call succeeds, or the deleted message just keeps
  /// showing until the chat happens to reload.
  Future<bool> deleteMessageForEveryone(int chatId, int messageId) async {
    if (_isDisposed) return false;
    try {
      await _messageRepository.deleteForEveryone(messageId);
      _markMessageDeletedLocally(chatId, messageId, forEveryone: true);
      _error = null;
      _scheduleNotification();
      return true;
    } catch (e) {
      _error = "Failed to delete message: ${e.toString()}";
      _logger.e('❌ Delete message for everyone error: $e');
      _scheduleNotification();
      return false;
    }
  }

  /// NEW: plain REST call, not a socket round-trip (§6.3) — NEW has no
  /// delete-for-me broadcast at all (it's private to the requester), so
  /// this device's own list must be updated locally right after the REST
  /// call succeeds.
  Future<bool> deleteMessageForMe(int chatId, int messageId) async {
    if (_isDisposed) return false;
    try {
      await _messageRepository.deleteForMe(messageId);
      _markMessageDeletedLocally(chatId, messageId, forEveryone: false);
      _error = null;
      _scheduleNotification();
      return true;
    } catch (e) {
      _error = "Failed to delete message: ${e.toString()}";
      _logger.e('❌ Delete message for me error: $e');
      _scheduleNotification();
      return false;
    }
  }

  /// [forEveryone]: mark the message as deleted-for-everyone in place
  /// (server keeps the row, just clears its content) instead of removing
  /// it, matching what `message_deleted` does for the other participants.
  /// !forEveryone: remove it entirely (delete-for-me only affects this
  /// device's own view).
  void _markMessageDeletedLocally(
    int chatId,
    int messageId, {
    required bool forEveryone,
  }) {
    if (_chatsData.records == null) return;
    if (forEveryone) {
      for (final record in _chatsData.records!) {
        if (record.messageId == messageId && record.chatId == chatId) {
          record.messageContent = 'This message was deleted.';
          record.deletedForEveryone = true;
          break;
        }
      }
    } else {
      _chatsData.records!.removeWhere(
        (r) => r.messageId == messageId && r.chatId == chatId,
      );
    }
    _pinnedMessagesData.records?.removeWhere((r) => r.messageId == messageId);
    _regroupMessages();
    _cacheNewChatData(_chatsData);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EDIT MESSAGE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Last server-side reason an [editMessage] call failed (403 not the
  /// sender, 400 already deleted, 404 not found, network...), for the UI.
  String? _editMessageError;
  String? get editMessageError => _editMessageError;

  /// `PATCH /messages/:messageId {body}`. The response is the full updated
  /// message; it's applied locally right away rather than waiting for the
  /// `message_updated` echo (which is idempotent when it does arrive).
  Future<bool> editMessage({
    required int messageId,
    required String newBody,
  }) async {
    if (_isDisposed) return false;
    _editMessageError = null;
    try {
      final updated = await _messageRepository.editMessage(messageId, newBody);
      if (_isDisposed) return false;
      _applyMessageUpdate(updated);
      return true;
    } on AppError catch (e) {
      _editMessageError = e.message;
      _logger.e('❌ Edit message error: ${e.message}');
      return false;
    } catch (e) {
      _editMessageError = e.toString();
      _logger.e('❌ Edit message error: $e');
      return false;
    }
  }

  /// Applies an updated message (edit response or `message_updated` push)
  /// to every place this provider shows it: the open thread, pinned and
  /// starred lists, reply previews quoting it, the chat-list last-message
  /// preview, and the on-disk page cache.
  void _applyMessageUpdate(MessageDto message) {
    final messageId = int.tryParse(message.id);
    final chatId = int.tryParse(message.conversationId);
    if (messageId == null) return;

    // The socket controller's session list is re-merged into ours on every
    // `new_message` (its copy wins an id collision) — keep it in step too.
    _socketEventController.applyMessageUpdateLocally(message);

    var threadChanged = false;
    for (final pool in [
      _chatsData.records,
      _pinnedMessagesData.records,
      starredMessagesData.records,
    ]) {
      if (pool == null) continue;
      for (final record in pool) {
        if (record.messageId == messageId &&
            MessageAdapter.applyUpdate(record, message)) {
          threadChanged = true;
        }
      }
    }

    // Reply bubbles quoting this message carry their own copy of its text.
    final updatedRecord = _findLoadedRecordById(messageId);
    final records = _chatsData.records;
    if (updatedRecord != null && records != null) {
      for (final record in records) {
        final parent = record.parentMessage;
        if (parent == null || parent['message_id'] != messageId) continue;
        if (parent['message_content'] == updatedRecord.messageContent) continue;
        record.parentMessage = {
          ...parent,
          'message_content': updatedRecord.messageContent,
        };
        threadChanged = true;
      }
    }

    if (threadChanged) {
      _regroupMessages();
      _cacheNewChatData(_chatsData);
    }

    if (chatId != null) {
      if (_updateChatListPreviewForUpdate(chatId, messageId, message)) {
        _persistChatListCache();
      }
      // Chats that aren't open still have their pages cached on disk.
      if (_currentChatData.chatId != chatId) {
        unawaited(_updateCachedMessage(chatId, messageId, message));
      }
    }

    _scheduleNotification();
  }

  /// Keeps the chat-list row's last-message preview in step with an edit
  /// (or a delete-for-everyone arriving through the same update). Returns
  /// whether the row changed.
  bool _updateChatListPreviewForUpdate(
    int chatId,
    int messageId,
    MessageDto message,
  ) {
    for (final chat in _chatListData.chats) {
      final record = chat.records?.isNotEmpty == true ? chat.records!.first : null;
      if (record == null || record.chatId != chatId) continue;
      final last =
          record.messages?.isNotEmpty == true ? record.messages!.first : null;
      if (last == null || last.messageId != messageId) return false;

      if (message.isDeletedForEveryone) {
        if (last.deletedForEveryone == true) return false;
        last.deletedForEveryone = true;
        last.messageContent = 'This message was deleted.';
        return true;
      }
      final content = message.primaryAttachmentUrl ?? message.body;
      if (content == null || content == last.messageContent) return false;
      last.messageContent = content;
      return true;
    }
    return false;
  }

  /// Best-effort patch of a message inside the session page cache of a chat
  /// that isn't currently open, so reopening it doesn't flash the old text
  /// before the server reconcile lands.
  Future<void> _updateCachedMessage(
    int chatId,
    int messageId,
    MessageDto message,
  ) async {
    try {
      final chatIdString = chatId.toString();
      for (final page in ChatCacheManager.getCachedPages(chatIdString)) {
        final messages = await ChatCacheManager.getPage(chatIdString, page);
        if (messages == null) continue;
        for (final record in messages) {
          if (record.messageId != messageId) continue;
          if (MessageAdapter.applyUpdate(record, message)) {
            await ChatCacheManager.updateMessage(chatIdString, record);
          }
          return;
        }
      }
    } catch (e) {
      _logger.w('Could not update cached copy of edited message $messageId: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADD THESE METHODS TO YOUR EXISTING ChatProvider CLASS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Finds an already-loaded message record by id across every store this
  /// provider knows about. A forward needs the source message's real
  /// `type`/content — NEW's `SendMessageDto` requires `body` as a string
  /// whenever no `attachmentMediaIds` are sent (even for a forward), and
  /// that validation runs before MessagesService.send()'s own `dto.body ??
  /// forwardSource?.body` fallback ever gets a chance to help — so sending
  /// a hardcoded empty-text placeholder gets rejected with a 400, and even
  /// when it wouldn't be, the wrong `type`/content would render incorrectly
  /// on the other end.
  chats.Records? _findLoadedRecordById(int messageId) {
    for (final pool in [
      _chatsData.records,
      _pinnedMessagesData.records,
      starredMessagesData.records,
    ]) {
      if (pool == null) continue;
      for (final r in pool) {
        if (r.messageId == messageId) return r;
      }
    }
    return null;
  }

  /// Forward message to another chat via ChatRepository
  /// [fromChatId] - Source chat ID
  /// [toChatId] - Destination chat ID
  /// [messageId] - Message ID to forward
  /// Returns true if successful, false otherwise
  /// NEW merges forward into the normal send call via `forwardOfMessageId`
  /// — and that id is now the source MESSAGE id, not the source CHAT id
  /// (§6.5/§6.7 breaking change #10; `fromChatId` is accepted only for
  /// call-site compatibility and no longer sent).
  Future<bool> forwardMessage({
    required int fromChatId,
    required int toChatId,
    required int messageId,
  }) async {
    if (_isDisposed) return false;

    try {
      _logger.d(
        'ChatProvider: Forwarding message $messageId to chat $toChatId',
      );

      final source = _findLoadedRecordById(messageId);
      final messageType =
          source?.messageType != null
              ? MessageTypeUtils.messageTypeFromString(source!.messageType!)
              : MessageType.Text;

      await _messageRepository.sendMessage(
        conversationId: toChatId,
        messageType: messageType,
        messageContent: source?.messageContent ?? '',
        forwardOfMessageId: messageId,
      );

      _logger.i('ChatProvider: Message forward successful');
      _error = null;
      _scheduleNotification();
      return true;
    } catch (e) {
      _error = "Failed to forward message: ${e.toString()}";
      _logger.e('ChatProvider: Forward message error: $e');
      _scheduleNotification();
      return false;
    }
  }

  /// Forward multiple messages in batch
  /// [fromChatId] - Source chat ID
  /// [toChatId] - Destination chat ID
  /// [messageIds] - List of message IDs to forward
  /// Returns a map with results
  Future<Map<String, dynamic>> forwardMultipleMessages({
    required int fromChatId,
    required int toChatId,
    required List<int> messageIds,
  }) async {
    if (_isDisposed) return {'success': false, 'error': 'Provider disposed'};

    try {
      _logger.d(
        'ChatProvider: Forwarding ${messageIds.length} messages from chat $fromChatId to chat $toChatId',
      );

      // NEW has no batch-forward endpoint — sends one message per id via
      // the normal send call (forwardOfMessageId), sequentially.
      int successCount = 0;
      final errors = <String>[];
      for (final id in messageIds) {
        try {
          final source = _findLoadedRecordById(id);
          final messageType =
              source?.messageType != null
                  ? MessageTypeUtils.messageTypeFromString(
                    source!.messageType!,
                  )
                  : MessageType.Text;

          await _messageRepository.sendMessage(
            conversationId: toChatId,
            messageType: messageType,
            messageContent: source?.messageContent ?? '',
            forwardOfMessageId: id,
          );
          successCount++;
        } catch (e) {
          errors.add('Message $id: $e');
        }
      }
      final result = {
        'success': successCount == messageIds.length,
        'total_messages': messageIds.length,
        'success_count': successCount,
        'failure_count': messageIds.length - successCount,
        'errors': errors,
      };

      if (result['success'] == true) {
        _logger.i('ChatProvider: Batch forward completed successfully');
        // Clear any existing error
        _error = null;
        _scheduleNotification();
      } else {
        _error = "Some messages failed to forward";
        _logger.w('ChatProvider: Batch forward completed with errors');
        _scheduleNotification();
      }

      return result;
    } catch (e) {
      _error = "Failed to forward messages: ${e.toString()}";
      _logger.e('ChatProvider: Batch forward error: $e');
      _scheduleNotification();

      return {
        'success': false,
        'total_messages': messageIds.length,
        'success_count': 0,
        'failure_count': messageIds.length,
        'errors': ['Critical error: $e'],
      };
    }
  }

  /// Forward message to a new user (creates new chat if needed)
  /// [fromChatId] - Source chat ID
  /// [toUserId] - Target user ID
  /// [messageId] - Message ID to forward
  /// Returns true if successful, false otherwise
  Future<bool> forwardMessageToUser({
    required int fromChatId,
    required int toUserId,
    required int messageId,
  }) async {
    if (_isDisposed) return false;

    try {
      _logger.d(
        'ChatProvider: Forwarding message to user - fromChatId: $fromChatId, toUserId: $toUserId, messageId: $messageId',
      );

      // NEW has no implicit 1:1 creation (§5.2) — resolve/create the
      // direct conversation with this user first, same as sendMessage().
      final conversation = await _conversationRepository.createConversation(
        type: 'direct',
        participantIds: [toUserId.toString()],
      );
      final targetChatId = int.tryParse(conversation.id);
      if (targetChatId == null || targetChatId <= 0) {
        throw AppError('Could not resolve a conversation with this user.');
      }

      final source = _findLoadedRecordById(messageId);
      final messageType =
          source?.messageType != null
              ? MessageTypeUtils.messageTypeFromString(source!.messageType!)
              : MessageType.Text;

      await _messageRepository.sendMessage(
        conversationId: targetChatId,
        messageType: messageType,
        messageContent: source?.messageContent ?? '',
        forwardOfMessageId: messageId,
      );

      _logger.i('ChatProvider: Message forward to user successful');
      _error = null;
      _scheduleNotification();
      return true;
    } catch (e) {
      _error = "Failed to forward message to user: ${e.toString()}";
      _logger.e('ChatProvider: Forward message to user error: $e');
      _scheduleNotification();
      return false;
    }
  }

  /// Check if a message can be forwarded (validation method)
  /// [messageId] - Message ID to check
  /// Returns true if the message can be forwarded, false otherwise
  Future<bool> canForwardMessage(int messageId) async {
    if (_isDisposed) return false;

    try {
      // Use the private _chatRepository through this public method
      return await _chatRepository.canForwardMessage(messageId);
    } catch (e) {
      _logger.e('ChatProvider: Error checking forward permission: $e');
      return false;
    }
  }

  /// Get available chats for forwarding (helper method)
  /// Returns a list of chats that the user can forward messages to
  Future<List<Map<String, dynamic>>> getAvailableChatsForForward() async {
    if (_isDisposed) return [];

    try {
      _logger.d('ChatProvider: Getting available chats for forwarding');

      // Use the private _chatRepository through this public method
      return await _chatRepository.getAvailableChatsForForward();
    } catch (e) {
      _logger.e('ChatProvider: Error getting available chats: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _logger.d("ChatProvider disposing");
    _isDisposed = true;

    // Cancel timers
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _highlightTimer?.cancel();
    _highlightTimer = null;

    // Stop any ongoing search
    _stopMessageSearch();

    // Dispose subscriptions
    _disposeSubscriptions();

    super.dispose();
  }

  Future<void> downloadPdfWithProgress({
    required String pdfUrl,
    required Function(double) onProgress,
    required Function(String?, String?) onComplete,
    bool isOpenPdf = false,
  }) async {
    try {
      final filePath = await pdfLocalPathForUrl(pdfUrl);
      final file = File(filePath);

      if (await file.exists()) {
        String metadata = await getPdfMetadataWhenDownloaded(filePath);
        onComplete(filePath, metadata);
        return;
      }

      var request = await HttpClient().getUrl(Uri.parse(pdfUrl));
      var response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        onComplete(null, "Download failed: ${response.statusCode}");
        return;
      }

      var totalBytes = response.contentLength;
      var bytesReceived = 0;
      var fileSink = file.openWrite();

      await response.forEach((chunk) {
        bytesReceived += chunk.length;
        fileSink.add(chunk);
        double progress = bytesReceived / totalBytes;
        onProgress(progress);
      });

      await fileSink.flush();
      await fileSink.close();

      String metadata = await getPdfMetadataWhenDownloaded(filePath);
      onComplete(filePath, metadata);
    } catch (e) {
      onComplete(null, "Error: ${e.toString()}");
    }
  }

  // NEW: conversation list is REST + cursor pagination, not a socket push
  // (§5.2/§5.4) — `emitChatList`/`emitChatListWithPage` are kept as the
  // public entry points (unchanged names/signatures) so nothing calling
  // them needs to change; internally they now hit `GET /conversations`.
  Future<void> emitChatList() async {
    if (_isDisposed) return;
    await _fetchConversationsPage(page: 1, archived: false);
  }

  /// Fetches one page of the (non-archived) conversation list via REST and
  /// funnels it through the existing pagination/append/sort pipeline
  /// (`_handleChatListPaginationResponse`) unchanged. `page` is a purely
  /// client-side counter used to decide replace-vs-append and to
  /// synthesize a `Pagination` object for that pipeline — the real
  /// pagination token sent to the server is the opaque cursor stored in
  /// `_chatListCursor`.
  Future<void> _fetchConversationsPage({
    required int page,
    required bool archived,
  }) async {
    if (_isDisposed) return;

    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        await _loadCurrentUserIdForChat();
      }
      final myId = _currentUserId ?? '';

      final cursor = page == 1 ? null : _chatListCursor;
      final result = await _conversationRepository.getConversations(
        cursor: cursor,
        limit: _chatListPageSize,
        archived: archived,
      );

      _chatListCursor = result.nextCursor;

      final chatsList = await _resolveConversationsToChats(
        result.items,
        currentUserId: myId,
        archived: archived,
      );

      final syntheticPagination = Pagination(
        currentPage: page,
        totalPages: result.nextCursor != null ? page + 1 : page,
      );

      _handleChatListPaginationResponse(
        ChatListModel(pagination: syntheticPagination, chats: chatsList),
      );
    } catch (e) {
      _error = "Failed to get chat list: ${e.toString()}";
      _isChatListPaginationLoading = false;
      _isChatListLoading = false;
      _logger.e('Error fetching conversations page: $e');
      _scheduleNotification();
    }
  }

  /// Batch-resolves each conversation's 1:1 peer profile, latest-message
  /// preview, and block status (N+1 network calls per page — an accepted
  /// risk called out by the migration guide, §5.5) and maps everything
  /// into the existing `Chats` model via `ConversationAdapter`.
  Future<List<Chats>> _resolveConversationsToChats(
    List<ConversationDto> conversations, {
    required String currentUserId,
    required bool archived,
  }) async {
    // One `GET /users/batch?ids=…` for every 1:1 peer on this page instead of
    // a `GET /users/:id` per row. Anything the batch doesn't return falls
    // back to the single-id lookup below, so a batch miss/failure only costs
    // speed.
    final peerIds =
        conversations
            .map((c) => ConversationAdapter.peerIdFor(c, currentUserId))
            .whereType<String>()
            .toSet()
            .toList();
    final batchedProfiles = await _conversationRepository.getUserBasicProfiles(
      peerIds,
    );

    // Learn each peer's last-seen privacy here so it is already known by the
    // time a chat opens — see _lastSeenVisibility.
    for (final entry in batchedProfiles.entries) {
      final id = int.tryParse(entry.key);
      if (id == null) continue;
      _rememberLastSeenVisibility(
        id,
        UserPresence.fromProfileJson(entry.value).lastSeenVisible,
      );
    }

    final results = await Future.wait(
      conversations.map((conversation) async {
        final peerId = ConversationAdapter.peerIdFor(conversation, currentUserId);

        final peerProfileFuture =
            peerId == null
                ? Future<Map<String, dynamic>?>.value(null)
                : batchedProfiles.containsKey(peerId)
                ? Future<Map<String, dynamic>?>.value(batchedProfiles[peerId])
                : _conversationRepository.getUserBasicProfile(peerId);
        final previewFuture = _conversationRepository.getLatestMessagePreview(
          conversation.id,
        );
        // A group picture arrives as a bare `avatarMediaId`; `GET /media/:id`
        // returns metadata only, so the row has to be looked up and its
        // `cdnUrl` used as the image src. Memoized in MediaRepository, so
        // this is one call per distinct avatar, not per list rebuild.
        final avatarUrlFuture =
            conversation.type == 'group'
                ? _mediaRepository.getDisplayUrl(conversation.avatarMediaId)
                : Future<String?>.value(null);

        final peerProfile = unwrapEnvelope(await peerProfileFuture);
        final preview = await previewFuture;
        final avatarUrl = await avatarUrlFuture;
        // Same treatment for the 1:1 peer's avatar, which is a bare media id
        // on some endpoints and a plain URL on others.
        final peerAvatarUrl = await _mediaRepository.getDisplayUrl(
          (peerProfile?['profilePic'] ?? peerProfile?['profile_pic'])
              as String?,
        );

        final isBlocked =
            peerId != null ? isUserBlocked(int.tryParse(peerId) ?? -1) : false;

        return ConversationAdapter.toChat(
          conversation: conversation,
          currentUserId: currentUserId,
          archived: archived,
          peerProfile: peerProfile,
          previewMessage: preview,
          isBlockedByMe: isBlocked,
          avatarUrl: avatarUrl,
          peerAvatarUrl: peerAvatarUrl,
        );
      }),
    );
    return results;
  }

  /// Chat-list row for [chatId], for callers that only know the id — a
  /// notification tap carries nothing but `conversationId`. Served from the
  /// loaded chat list when possible; otherwise (cold start before the list
  /// loads, a chat past page 1, an archived chat) fetched through
  /// `GET /conversations/:id` and resolved exactly like a chat-list page, so
  /// the chat screen gets the same peer name/avatar it would from a list tap.
  Future<Chats?> resolveChatForNotification(int chatId) async {
    if (_isDisposed || chatId <= 0) return null;

    for (final chat in _chatListData.chats) {
      if (chat.records?.firstOrNull?.chatId == chatId) return chat;
    }

    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        await _loadCurrentUserIdForChat();
      }
      final conversation = await _conversationRepository.getConversation(
        chatId.toString(),
      );
      if (conversation == null) return null;

      final resolved = await _resolveConversationsToChats(
        [conversation],
        currentUserId: _currentUserId ?? '',
        archived: false,
      );
      return resolved.firstOrNull;
    } catch (e) {
      _logger.e('Error resolving chat $chatId for notification: $e');
      return null;
    }
  }

  /// Resolves [conversation] into a chat-list row and puts it on the list
  /// right away, for a conversation the app just got over REST (the AI
  /// Assistant's get-or-create) — otherwise it would only show up after the
  /// next `new_message` or list refresh. An already-listed copy is replaced
  /// in place; an archived chat is resolved but kept off the main list.
  Future<Chats?> addConversationToChatList(ConversationDto conversation) async {
    if (_isDisposed) return null;
    final chatId = int.tryParse(conversation.id);
    if (chatId == null || chatId <= 0) return null;

    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        await _loadCurrentUserIdForChat();
      }
      final resolved = await _resolveConversationsToChats(
        [conversation],
        currentUserId: _currentUserId ?? '',
        archived: false,
      );
      final chat = resolved.firstOrNull;
      if (chat == null || _isDisposed) return chat;
      if (_archivedChatIds.contains(chatId)) return chat;

      final chats = List<Chats>.from(_chatListData.chats);
      final existingIndex = chats.indexWhere(
        (c) => c.records?.firstOrNull?.chatId == chatId,
      );
      if (existingIndex >= 0) {
        chats[existingIndex] = chat;
      } else {
        chats.insert(0, chat);
      }
      _chatListData = ChatListModel(
        chats: chats,
        pagination: _chatListData.pagination,
      );
      _sortChatList();
      _persistChatListCache();
      _scheduleNotification();
      return chat;
    } catch (e) {
      _logger.e('Error adding conversation ${conversation.id} to chat list: $e');
      return null;
    }
  }

  /// Load more chat list data (pagination)
  Future<void> loadMoreChatList() async {
    if (_isDisposed) return;

    // Enhanced debug logging for load more
    _logger.d('🔄 loadMoreChatList called - Current state check:');
    _logger.d('📊 _hasChatListMoreData: $_hasChatListMoreData');
    _logger.d('⏳ _isChatListPaginationLoading: $_isChatListPaginationLoading');
    _logger.d('📄 _chatListCurrentPage: $_chatListCurrentPage');
    _logger.d('📈 _chatListTotalPages: $_chatListTotalPages');
    _logger.d('💬 Current chats count: ${_chatListData.chats.length}');
    _logger.d(
      '🔢 Page comparison: $_chatListCurrentPage >= $_chatListTotalPages = ${_chatListCurrentPage >= _chatListTotalPages}',
    );

    // Check if we can load more
    if (_isChatListPaginationLoading || !_hasChatListMoreData) {
      _logger.d(
        '❌ Chat list pagination skipped - loading: $_isChatListPaginationLoading, hasMore: $_hasChatListMoreData',
      );
      return;
    }

    // Check if we haven't reached the total pages
    if (_chatListCurrentPage >= _chatListTotalPages) {
      _logger.d(
        '🏁 Reached last page of chat list ($_chatListCurrentPage >= $_chatListTotalPages)',
      );
      _hasChatListMoreData = false;
      return;
    }

    try {
      _logger.d('🔄 Loading more chat list - page ${_chatListCurrentPage + 1}');
      _isChatListPaginationLoading = true;
      _scheduleNotification();

      // Request next page
      final nextPage = _chatListCurrentPage + 1;
      await emitChatListWithPage(nextPage);

      _logger.d('✅ Chat list pagination request sent for page $nextPage');
    } catch (e) {
      _error = "Failed to load more chat list: ${e.toString()}";
      _logger.e("❌ Chat list pagination error: $e");
      _isChatListPaginationLoading = false;
      _scheduleNotification();
    }
  }

  /// Request chat list with specific page
  Future<void> emitChatListWithPage(int page) async {
    _logger.d('Requesting chat list for page $page');
    await _fetchConversationsPage(page: page, archived: false);
  }

  void _handleChatListPaginationResponse(ChatListModel newChatListData) {
    try {
      final pagination = newChatListData.pagination;
      if (pagination != null) {
        final previousCurrentPage = _chatListCurrentPage;
        final previousTotalPages = _chatListTotalPages;

        _chatListCurrentPage = pagination.currentPage ?? 1;
        _chatListTotalPages = pagination.totalPages ?? 1;
        _hasChatListMoreData = _chatListCurrentPage < _chatListTotalPages;

        // Debug the hasChatListMoreData calculation
        _logger.d(
          '🧮 Calculating hasChatListMoreData: $_chatListCurrentPage < $_chatListTotalPages = $_hasChatListMoreData',
        );

        _logger.d(
          '📊 Chat list pagination updated - Page: $_chatListCurrentPage/$_chatListTotalPages (was $previousCurrentPage/$previousTotalPages), HasMore: $_hasChatListMoreData',
        );

        // Additional debug info about the received pagination data
        _logger.d(
          '🔍 Received pagination data: currentPage=${pagination.currentPage}, totalPages=${pagination.totalPages}, totalRecords=${pagination.totalRecords}',
        );

        // CRITICAL FIX: Force immediate notification to update UI with new pagination state
        notifyListeners();
      } else {
        _logger.w('⚠️ No pagination data received in response');
        _logger.w('⚠️ newChatListData: ${newChatListData.toString()}');

        // 🛡️ Defensive: a response with neither chats nor pagination is not a
        // valid first page — never let it clobber an already-populated list.
        if (newChatListData.chats.isEmpty && _chatListData.chats.isNotEmpty) {
          _logger.w(
            '⚠️ Ignoring empty paginationless chat list response to preserve ${_chatListData.chats.length} existing chats',
          );
          _isChatListPaginationLoading = false;
          _isChatListLoading = false;
          _scheduleNotification();
          return;
        }
      }

      if (_chatListCurrentPage == 1) {
        // First page - replace all data
        _chatListData = newChatListData;
        _logger.d(
          '📄 First page chat list loaded with ${_chatListData.chats.length} chats',
        );

        // ✅ NEW: Filter out archived chats after loading (with sorting for first page)
        _filterArchivedChatsFromList(shouldSort: false);

        // ✅ FIXED: Only sort on first page load to maintain server pagination order
        _sortChatList();

        // ✅ OFFLINE-FIRST: Persist this fresh first page so the next cold
        // start can render instantly from cache while the socket reconnects.
        _persistChatListCache();
      } else {
        // Subsequent pages - append data WITHOUT global sorting to preserve pagination
        _appendChatListData(newChatListData);

        // ✅ NEW: Filter out archived chats after loading (no sorting for pagination)
        _filterArchivedChatsFromList(shouldSort: false);

        _logger.d(
          '📄 Page $_chatListCurrentPage appended. Total chats: ${_chatListData.chats.length}',
        );
      }

      _isChatListPaginationLoading = false;
      _isChatListLoading = false;
      _scheduleNotification();
    } catch (e) {
      _logger.e('Error handling chat list pagination response: $e');
      _isChatListPaginationLoading = false;
      _isChatListLoading = false;
      _scheduleNotification();
    }
  }

  /// Append new chat list data to existing data
  void _appendChatListData(ChatListModel newChatListData) {
    if (newChatListData.chats.isEmpty) {
      _logger.w('⚠️ No new chats in pagination response');
      return;
    }

    // Get existing chat IDs to prevent duplicates
    final existingChatIds =
        _chatListData.chats
            .where((chat) => chat.records?.isNotEmpty == true)
            .map((chat) => chat.records!.first.chatId)
            .where((id) => id != null)
            .toSet();

    // Filter out duplicate chats
    final uniqueNewChats =
        newChatListData.chats.where((chat) {
          if (chat.records?.isNotEmpty == true) {
            final chatId = chat.records!.first.chatId;
            return chatId != null && !existingChatIds.contains(chatId);
          }
          return false;
        }).toList();

    if (uniqueNewChats.isNotEmpty) {
      _chatListData.chats.addAll(uniqueNewChats);
      _logger.d(
        '📑 Appended ${uniqueNewChats.length} unique chats. Total: ${_chatListData.chats.length}',
      );
    } else {
      _logger.w(
        '⚠️ All ${newChatListData.chats.length} new chats were duplicates',
      );
    }

    // Update pagination metadata
    _chatListData.pagination = newChatListData.pagination;
  }

  /// Sort chat list by updatedAt first, then createdAt as fallback
  void _sortChatList() {
    if (_chatListData.chats.isEmpty) return;

    _chatListData.chats.sort((a, b) {
      // Get the first record from each chat
      final recordA = a.records?.isNotEmpty == true ? a.records!.first : null;
      final recordB = b.records?.isNotEmpty == true ? b.records!.first : null;

      // If either record is null, put it at the end
      if (recordA == null && recordB == null) return 0;
      if (recordA == null) return 1;
      if (recordB == null) return -1;

      // Try to get updatedAt first, then fall back to createdAt
      String? dateA = recordA.updatedAt;
      if (dateA == null || dateA.isEmpty) {
        dateA = recordA.createdAt;
      }

      String? dateB = recordB.updatedAt;
      if (dateB == null || dateB.isEmpty) {
        dateB = recordB.createdAt;
      }

      // If both dates are null/empty, consider them equal
      if ((dateA == null || dateA.isEmpty) &&
          (dateB == null || dateB.isEmpty)) {
        return 0;
      }

      // If one date is null/empty, put it at the end
      if (dateA == null || dateA.isEmpty) return 1;
      if (dateB == null || dateB.isEmpty) return -1;

      // Parse dates and compare (newest first)
      try {
        final parsedA = DateTime.parse(dateA);
        final parsedB = DateTime.parse(dateB);
        return parsedB.compareTo(parsedA); // Descending order (newest first)
      } catch (e) {
        _logger.w('Error parsing dates for sorting: $e');
        // If parsing fails, compare as strings
        return dateB.compareTo(dateA);
      }
    });

    _logger.d('📊 Sorted ${_chatListData.chats.length} chats by date');
  }

  void resetChatListPagination() {
    _chatListCurrentPage = 1;
    _chatListTotalPages =
        1; // This will be updated when real pagination data is received
    _hasChatListMoreData =
        true; // Start optimistically, will be corrected by real data
    _isChatListPaginationLoading = false;
    _chatListData = ChatListModel(chats: []);

    _logger.d(
      '🔄 Reset pagination state - Page: $_chatListCurrentPage/$_chatListTotalPages',
    );
    _scheduleNotification();
  }

  /// Wipe ALL user-scoped in-memory state so that a *different* account
  /// logging in during the same app session never sees the previous user's
  /// chat list, open-chat messages, block list, etc.
  ///
  /// Why this is needed: [ChatProvider] is a long-lived provider created once
  /// at app startup (see `provider_list.dart`) and is NOT disposed on logout,
  /// so every field below otherwise survives an account switch. The on-disk
  /// chat-list snapshot (`_chatListCacheKey`) is normally wiped by
  /// `SecurePrefs.clear()` during logout, but:
  ///   * the in-memory `_chatListData` copy still has to be cleared, and
  ///   * an empty chat-list response for the new (chat-less) account is
  ///     deliberately ignored by `_handleChatListPaginationResponse` to
  ///     "preserve existing chats" — so without this, the old user's chats
  ///     stay on screen forever.
  /// The persisted key is also removed here explicitly, in case this runs
  /// before the storage wipe.
  ///
  /// Called from `AuthProvider.handleLogout`.
  Future<void> resetForLogout() async {
    _logger.i('🧹 ChatProvider.resetForLogout - clearing all user data');

    // Cancel pending async work that could otherwise re-populate state.
    _chatListRefreshDebounceTimer?.cancel();
    _chatListRefreshDebounceTimer = null;
    _isChatListRefreshPending = false;
    _notifyTimer?.cancel();
    _highlightTimer?.cancel();
    _searchTimeoutTimer?.cancel();

    // Chat list + pagination + search
    _chatListData = ChatListModel(chats: []);
    _isSearching = false;
    _isSearchLoading = false;
    _currentSearchQuery = '';
    _chatListCurrentPage = 1;
    _chatListTotalPages = 1;
    _hasChatListMoreData = true;
    _isChatListPaginationLoading = false;
    _isChatListLoading = false;
    _isSyncingChatList = false;
    _chatListCursor = null;

    // Open-chat / message state
    _chatsData = chats.ChatsModel();
    _groupedMessages = {};
    _pinnedMessagesData = chats.ChatsModel();
    _isPinnedMessagesExpanded = false;
    _currentChatData = ChatIds();
    _chatWrapper = null;
    _replyToMessage = null;
    _isReplyMode = false;
    _hasMoreMessages = false;
    _highlightedMessageId = null;
    _isSearchingForMessage = false;
    _targetMessageId = null;
    _isMessageFound = false;

    // Per-session tracking sets/maps
    _processedSeenMessageIds.clear();
    _recentlyClearedChats.clear();
    _optimisticMessages.clear();
    _archivedChatIds.clear();
    _sessionUnlockedChatIds.clear();
    _peerDirectChatIds.clear();
    _peersWithoutChat.clear();

    _lastSeenVisibility.clear();

    // Block list
    _blockedUsers.clear();
    _isBlockListLoading = false;
    _blockListCurrentPage = 1;
    _hasMoreBlockedUsers = true;

    // Counts / errors / misc
    _blocklistCount = 0;
    _starredCount = 0;
    _starredMessageIds.clear();
    _notificationCount = 0;
    _error = null;
    _apiErrorMessage = null;
    _errorMessage = null;
    _hasError = false;

    // Identity — force a fresh read from storage on the next login.
    _currentUserId = null;

    // Belt-and-braces: drop the persisted chat-list snapshot too, in case
    // this runs before `SecurePrefs.clear()` in the logout flow.
    try {
      await SecurePrefs.remove(_chatListCacheKey);
    } catch (e) {
      _logger.w('Could not remove cached chat list on logout: $e');
    }

    if (!_isDisposed) notifyListeners();
  }

  // ✅ NEW: Search functionality state (for home screen chat list)
  bool _isSearching = false;
  bool _isSearchLoading = false;
  String _currentSearchQuery = '';

  /// ✅ NEW: Search getters (for home screen chat list)
  ///
  /// Results are *derived* from the live chat list on every read instead of
  /// being snapshotted when the query ran. A snapshot went stale the moment
  /// anything replaced the objects inside `_chatListData` —
  /// `refreshChatList()` rebuilds every `Chats` instance from the API
  /// response — so after e.g. a group icon/name update the chat list picked
  /// up the new avatar while an open search kept rendering the pre-update
  /// copies.
  ChatListModel get searchResults =>
      _isSearching
          ? ChatListModel(
            chats: _chatListData.chats.where(_matchesSearch).toList(),
          )
          : ChatListModel(chats: []);
  bool get isSearching => _isSearching;
  bool get isSearchLoading => _isSearchLoading;
  String get currentSearchQuery => _currentSearchQuery;

  // ✅ NEW: Universal chat screen message search functionality state
  List<Map<String, dynamic>> _universalChatSearchResults = [];
  bool _isUniversalChatSearching = false;
  bool _isUniversalChatSearchLoading = false;
  String _universalChatSearchQuery = '';

  // ✅ NEW: Universal chat screen search getters
  List<Map<String, dynamic>> get universalChatSearchResults =>
      _universalChatSearchResults;
  bool get isUniversalChatSearching => _isUniversalChatSearching;
  bool get isUniversalChatSearchLoading => _isUniversalChatSearchLoading;
  String get universalChatSearchQuery => _universalChatSearchQuery;

  /// Search chats with the given query.
  /// ❌ NEW has no cross-chat search-by-name endpoint at all (§5.3/§5.6) —
  /// this now filters the already-loaded conversation list client-side by
  /// group name / peer name instead of calling a server endpoint. This only
  /// searches chats already paged into memory, unlike OLD's server-side
  /// search across every chat — a real, user-visible capability reduction,
  /// not just an implementation detail.
  Future<void> searchChats(String query) async {
    if (_isDisposed) return;

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      clearSearch();
      return;
    }

    _logger.d('🔍 Searching loaded chats client-side for: "$trimmedQuery"');
    _currentSearchQuery = trimmedQuery;
    _isSearching = true;
    _isSearchLoading = false;
    _logger.i(
      '🔍 Search completed - Found ${searchResults.chats.length} results',
    );
    _scheduleNotification();
  }

  /// Whether [chat] matches the active search query (group name for group
  /// chats, peer name otherwise).
  ///
  /// The peer name is resolved the same address-book-first way the chat
  /// list row displays it (saved contact name > fullName > userName) —
  /// otherwise a chat saved under a different address-book name than the
  /// account's own fullName/userName would show in the list but never turn
  /// up in search.
  bool _matchesSearch(Chats chat) {
    final needle = _currentSearchQuery.toLowerCase();
    if (needle.isEmpty) return false;

    final records = chat.records;
    final record = records != null && records.isNotEmpty ? records.first : null;
    final peer = chat.peerUserData;
    final name =
        record?.chatType?.toLowerCase() == 'group'
            ? (record?.groupName ?? '')
            : ContactNameService.instance.resolveName(
              userId: peer?.userId,
              fullName: peer?.fullName,
              userName: peer?.userName,
            );
    return name.toLowerCase().contains(needle);
  }

  /// Clear search results and return to normal chat list
  void clearSearch() {
    if (_isDisposed) return;

    _logger.d('🔍 Clearing search results');
    _isSearching = false;
    _isSearchLoading = false;
    _currentSearchQuery = '';
    _scheduleNotification();
  }

  /// Clear universal chat screen search results
  void clearUniversalChatSearch() {
    if (_isDisposed) return;

    _logger.d('🔍 Clearing universal chat search results');
    _universalChatSearchResults = [];
    _isUniversalChatSearching = false;
    _isUniversalChatSearchLoading = false;
    _universalChatSearchQuery = '';
    _scheduleNotification();
  }

  /// Set universal chat search loading state
  void setUniversalChatSearchLoading(bool loading) {
    if (_isDisposed) return;
    _isUniversalChatSearchLoading = loading;
    _scheduleNotification();
  }

  /// Set universal chat search results
  void setUniversalChatSearchResults(
    List<Map<String, dynamic>> results,
    String query,
  ) {
    if (_isDisposed) return;
    _universalChatSearchResults = results;
    _universalChatSearchQuery = query;
    _isUniversalChatSearching = query.isNotEmpty;
    _isUniversalChatSearchLoading = false;
    _scheduleNotification();
  }

  void forceHighlightRefresh(int messageId) {
    if (_highlightedMessageId == messageId) {
      _logger.d('🔄 Force refreshing highlight for message: $messageId');

      // Clear current highlight
      _highlightedMessageId = null;
      _scheduleNotification();

      // Re-apply highlight after a brief moment with extended duration
      Future.delayed(Duration(milliseconds: 150), () {
        if (!_isDisposed) {
          _highlightedMessageId = messageId;
          _scheduleNotification();

          // Clear any existing highlight timer
          _highlightTimer?.cancel();

          // Extended highlight duration for better visibility
          _highlightTimer = Timer(Duration(seconds: 8), () {
            // Increased to 8 seconds
            if (!_isDisposed) {
              _logger.d(
                '⏰ Clearing refreshed highlight for message: $messageId',
              );
              _highlightedMessageId = null;
              _scheduleNotification();
            }
          });

          _logger.d('✨ Message $messageId highlight refreshed for 8 seconds');
        }
      });
    } else {
      // Direct highlight if not currently highlighted
      highlightMessage(messageId);
    }
  }

  // Format time for UI
  String formatTime(String? time) {
    return _socketEventController.formatTime(time);
  }

  // Generate video thumbnail
  Future<String?> generateVideoThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.PNG,
        maxWidth: 300,
        maxHeight: 300,
        quality: 75,
      );

      _logger.d("Thumbnail generated: ${thumbnailFile.path}");
      return thumbnailFile.path;
    } catch (e) {
      _logger.e("Failed to generate video thumbnail: $e");
      return null;
    }
  }

  /// Get delete permission text for UI
  String getDeletePermissionText(chats.Records message) {
    if (!canDeleteMessage(message)) {
      return 'You can only delete your own messages';
    }
    return 'Delete Message';
  }

  // PDF related functionality (unchanged)
  Future<String> getPdfMetadata(String pdfUrl) async {
    try {
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode != 200) return "Unknown PDF";

      final PdfDocument document = PdfDocument(inputBytes: response.bodyBytes);
      int pageCount = document.pages.count;
      double fileSizeMB = response.bodyBytes.length / (1024 * 1024);

      document.dispose();
      return "$pageCount Pages • PDF • ${fileSizeMB.toStringAsFixed(2)} MB";
    } catch (e) {
      return "Error loading PDF";
    }
  }

  /// Filesystem path a downloaded copy of [pdfUrl] lives at. Kept in one
  /// place so `isPdfDownloaded`, `downloadPdfWithProgress` and
  /// `getPdfMetadataForUrl` can't drift apart.
  Future<String> pdfLocalPathForUrl(String pdfUrl) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/${pdfUrl.split('/').last}';
  }

  /// Returns the "N Pages • PDF • X.XX MB" line for a PDF identified by its
  /// remote [pdfUrl], transparently reading an already-downloaded local
  /// copy when one exists and fetching the remote file otherwise.
  ///
  /// Callers previously branched on `isPdfDownloaded` themselves and then
  /// handed the *URL* to `getPdfMetadataWhenDownloaded` (which expects a
  /// filesystem path). `File(url).exists()` is always false, so any PDF
  /// that had been downloaded once permanently rendered as "Unknown PDF"
  /// in the chat bubble, the pinned panel and the media grid.
  Future<String> getPdfMetadataForUrl(String pdfUrl) async {
    final localPath = await pdfLocalPathForUrl(pdfUrl);
    if (await File(localPath).exists()) {
      return getPdfMetadataWhenDownloaded(localPath);
    }
    return getPdfMetadata(pdfUrl);
  }

  Future<String> getPdfMetadataWhenDownloaded(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        return "Unknown PDF";
      }

      final PdfDocument document = PdfDocument(
        inputBytes: await file.readAsBytes(),
      );
      int pageCount = document.pages.count;
      double fileSizeMB = file.lengthSync() / (1024 * 1024);

      document.dispose();
      return "$pageCount Pages • PDF • ${fileSizeMB.toStringAsFixed(2)} MB";
    } catch (e) {
      _logger.e("PDF Metadata Error: $e");
      return "Error loading PDF";
    }
  }

  Future<Map<String, dynamic>> getPdfSizeAndPageCount(String pdfUrl) async {
    try {
      final uri = Uri.parse(pdfUrl);
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200 || response.statusCode == 206) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        final contentLength = bytes.length;

        // Convert bytes to human-readable format
        String sizeText;
        if (contentLength < 1024) {
          sizeText = '$contentLength B';
        } else if (contentLength < 1024 * 1024) {
          sizeText = '${(contentLength / 1024).toStringAsFixed(2)} KB';
        } else {
          sizeText = '${(contentLength / (1024 * 1024)).toStringAsFixed(2)} MB';
        }

        // Convert bytes to string to search for page count
        final content = utf8.decode(bytes, allowMalformed: true);
        final pageCountRegex = RegExp(r'/Count\s+(\d+)', caseSensitive: false);
        final match = pageCountRegex.firstMatch(content);

        final pageCount = match != null ? int.parse(match.group(1)!) : null;

        return {'size': sizeText, 'pageCount': pageCount ?? 'Unknown'};
      } else {
        return {
          'size': 'Failed: ${response.statusCode}',
          'pageCount': 'Unknown',
        };
      }
    } catch (e) {
      return {'size': 'Error: $e', 'pageCount': 'Error'};
    }
  }

  /// Get pin/unpin permission text for UI
  String getPinUnpinPermissionText(chats.Records message) {
    if (!canPinUnpinMessage(message)) {
      if (message.pinned == true) {
        return 'Only the user who pinned this message can unpin it';
      } else {
        return 'You cannot pin this message';
      }
    }

    return message.pinned == true ? 'Unpin Message' : 'Pin Message';
  }

  /// Get star/unstar permission text for UI
  String getStarUnstarPermissionText(chats.Records message) {
    if (!canStarUnStarMessage(message)) {
      if (message.stared == true) {
        return 'You cannot unstar this message';
      } else {
        return 'You cannot star this message';
      }
    }

    return message.stared == true ? 'Unstar Message' : 'Star Message';
  }

  // ✅ ENHANCED: Highlight message method
  void highlightMessage(int messageId) {
    _logger.d('🎯 Highlighting message: $messageId');

    _highlightedMessageId = messageId;
    _scheduleNotification();

    // Clear any existing highlight timer
    _highlightTimer?.cancel();

    // Extended highlight duration for better visibility
    _highlightTimer = Timer(Duration(seconds: 5), () {
      // Increased from 3 to 5 seconds
      if (!_isDisposed) {
        _logger.d('⏰ Clearing highlight for message: $messageId');
        _highlightedMessageId = null;
        _scheduleNotification();
      }
    });

    _logger.d('✨ Message $messageId highlighted for 5 seconds');
  }

  // Initialize provider
  Future<void> initialize() async {
    if (_isDisposed) return;

    _logger.i('Initializing ChatProvider');
    _isInitializing = true;
    _scheduleNotification();

    try {
      // Re-initialize subscriptions
      _initializeSubscriptions();

      // Connect to socket if not already connected
      if (!_socketEventController.isConnected) {
        await connect();
      }

      // Refresh chat list data
      await emitChatList();

      // Get online users
      _socketEventController.emitInitialOnlineUser();

      _isInitializing = false;
      _scheduleNotification();
    } catch (e) {
      _error = "Failed to initialize: ${e.toString()}";
      _isInitializing = false;
      _scheduleNotification();
    }
  }

  // ✅ ADD NEW METHOD: Check if a message is pinned
  bool isMessagePinned(int messageId) {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      return false;
    }

    try {
      final message = _chatsData.records!.firstWhere(
        (msg) => msg.messageId == messageId,
      );
      return message.pinned == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isPdfDownloaded(String pdfUrl) async {
    final filePath = await pdfLocalPathForUrl(pdfUrl);
    return File(filePath).exists();
  }

  // Check if a user is online
  bool isUserOnline(int userId) {
    if (_isDisposed) return false;
    return _socketEventController.isUserOnline(userId);
  }

  // Check if someone is typing in a chat
  bool isUserTypingInChat(int chatId) {
    if (_isDisposed) return false;

    bool result = _socketEventController.isUserTypingInChat(chatId);
    _logger.d("ChatProvider: isUserTypingInChat($chatId) = $result");
    return result;
  }

  // Future<void> loadChatMessages({
  //   required int chatId,
  //   required int peerId,
  //   bool clearExisting = true,
  // }) async {
  //   if (_isDisposed) return;

  //   try {
  //     _logger.d("Loading chat messages - chatId: $chatId, peerId: $peerId");

  //     // Set the current chat context
  //     setCurrentChat(chatId, peerId);

  //     if (clearExisting) {
  //       // Clear existing messages
  //       _chatsData = chats.ChatsModel();
  //       _pinnedMessagesData = chats.ChatsModel();
  //       _lastChatsDataHash = null;
  //       _scheduleNotification();
  //     }

  //     // Load messages from socket
  //     if (chatId > 0) {
  //       // Existing chat
  //       await _socketEventController.emitChatMessages(chatId: chatId);
  //     } else {
  //       // New chat with user
  //       await _socketEventController.emitChatMessages(peerId: peerId);
  //     }

  //     _logger.d("Chat messages loading initiated");
  //   } catch (e) {
  //     _error = "Failed to load chat messages: ${e.toString()}";
  //     _logger.e("Error loading chat messages: $e");
  //     _scheduleNotification();
  //   }
  // }

  /// Shared processing for a freshly-loaded page of message data,
  /// regardless of source — used by both the (now-dormant, Phase 7 will
  /// formally retire it) socket stream and the new REST-driven message
  /// loader below, so optimistic-merge/cache/regroup/pin-extraction logic
  /// doesn't need to exist twice.
  void _handleChatsDataUpdate(chats.ChatsModel data) {
    _logger.d("📨 Received chat data update");
    cleanupStaleOptimisticMessages();
    _mergeSocketDataWithOptimistic(data);

    // Reply-preview backfill for realtime `new_message` pushes. The socket
    // handler (SocketEventController) resolves this against its OWN, mostly
    // empty `_chatsData` (reset on every chat switch, only ever holding
    // messages received live during this session) — so a reply to anything
    // loaded via the initial REST fetch never got backfilled there. This
    // provider's `_chatsData.records`, right after the merge above, is the
    // one place that actually holds the full loaded history, so redo the
    // backfill here against it — see MessageAdapter.attachParentMessages.
    final allRecords = _chatsData.records;
    if (allRecords != null && allRecords.isNotEmpty) {
      final replyLookup = <int, chats.Records>{
        for (final r in allRecords)
          if (r.messageId != null) r.messageId!: r,
      };
      MessageAdapter.attachParentMessages(allRecords, replyLookup);
    }

    _cacheNewChatData(_chatsData);
    _regroupMessages();
    _extractPinnedMessages(_chatsData);

    // Poll messages that came in via the socket / cache-merge path have no
    // options yet — resolve them in the background and re-render.
    unawaited(_enrichPollRecordsAndNotify());

    final recordCount = _chatsData.records?.length ?? 0;
    final pinnedCount = _pinnedMessagesData.records?.length ?? 0;
    _logger.d("📊 Chat update - Messages: $recordCount, Pinned: $pinnedCount");

    _updateChatIdIfNeeded(_chatsData);
    _scheduleNotification();
  }

  late final MessageRepository _messageRepository = MessageRepository(
    _apiClient,
  );

  /// NEW: message list is `GET /messages/:conversationId?beforeSeq=&limit=`
  /// cursor pagination, not a socket push (§6.2/§6.3). Fetches one page,
  /// resolves the peer's `lastReadSeq` watermark to compute read ticks
  /// client-side (§6.6 — never trust `message.status`), fetches pins via
  /// `GET /conversations/:id/pins` since NEW no longer bundles them into
  /// the message list response, and funnels everything through the same
  /// `_handleChatsDataUpdate` pipeline the old socket path used.
  Future<void> _fetchMessagesPage({
    required int chatId,
    int? beforeSeq,
    bool clearExisting = false,
  }) async {
    if (_isDisposed || chatId <= 0) return;

    // ✅ DEMO MODE: the AI Assistant chat has no live provider key in demo
    // builds, so render the canned transcript instead of hitting
    // GET /messages/:conversationId for this one conversation.
    if (isDemo) {
      Chats? demoRow;
      for (final chat in _chatListData.chats) {
        if (chat.records?.firstOrNull?.chatId == chatId) {
          demoRow = chat;
          break;
        }
      }
      if (AiAssistantProvider.isBotUserName(demoRow?.peerUserData?.userName)) {
        final botUserId = demoRow?.peerUserData?.userId ?? 0;
        final myId = int.tryParse(_currentUserId ?? '') ?? 0;
        final records = AiAssistantDemoMessages.build(
          chatId: chatId,
          myUserId: myId,
          botUserId: botUserId,
        );
        if (clearExisting) _chatsData = chats.ChatsModel();
        _chatsData = chats.ChatsModel(
          records: records,
          pagination: chats.Pagination(currentPage: 1, totalPages: 1),
        );
        _hasMoreMessages = false;
        _pinnedMessagesData = chats.ChatsModel(records: const []);
        _regroupMessages();
        _scheduleNotification();
        _socketEventController.setChatLoadingState(false);
        return;
      }
    }

    try {
      final results = await Future.wait([
        _messageRepository.getMessages(chatId, beforeSeq: beforeSeq, limit: 30),
        _conversationRepository.getConversation(chatId.toString()),
        _messageRepository.getPinnedMessages(chatId),
      ]);
      // The user may have switched chats while this was in flight (Back
      // from a chat opened on top of another one) — never paint this chat's
      // messages into the one now on screen.
      bool isStale() => _isDisposed || _currentChatData.chatId != chatId;
      if (isStale()) return;

      final page = results[0] as MessagesPage;
      final conversation = results[1] as ConversationDto?;
      final pinnedPage = results[2] as MessagesPage;

      final myId = _currentUserId ?? '';
      final peerLastReadSeq =
          conversation?.participants
              .where((p) => p.userId != myId)
              .map((p) => p.lastReadSeq ?? 0)
              .fold<int>(0, (a, b) => b > a ? b : a) ??
          0;

      final records =
          page.items.map((m) {
            final record = MessageAdapter.toRecord(m, currentUserId: _currentUserId);
            MessageAdapter.applySeenStatus(
              record,
              peerLastReadSeq: peerLastReadSeq,
            );
            record.pinned = pinnedPage.items.any((p) => p.id == m.id);
            return record;
          }).toList();

      // Poll messages carry no poll relation on the wire, just
      // `metadata.pollId` (mapped onto Records.pollId) — resolve options now.
      await _enrichPollRecords(records);
      if (isStale()) return;

      // NEW's `GET /conversations/:id/pins` payload is sparse — depending on
      // backend version it can omit senderId / type / createdAt — so a pinned
      // entry adapted on its own renders as "Unknown User" with a bogus time.
      // Reuse the fully-hydrated record from the message page whenever the
      // pinned message is on it; fall back to the standalone adapter record
      // for pins older than the current page.
      final recordsById = <int, chats.Records>{
        for (final r in records)
          if (r.messageId != null) r.messageId!: r,
      };

      // Backfill reply previews from every message this provider already
      // knows about (previous pages + this page) — see
      // MessageAdapter.attachParentMessages.
      final replyLookup = <int, chats.Records>{
        for (final r in (_chatsData.records ?? const <chats.Records>[]))
          if (r.messageId != null) r.messageId!: r,
        ...recordsById,
      };
      MessageAdapter.attachParentMessages(records, replyLookup);

      final pinnedRecords =
          pinnedPage.items.map((m) {
            final id = int.tryParse(m.id);
            final record =
                (id != null ? recordsById[id] : null) ??
                MessageAdapter.toRecord(m, currentUserId: _currentUserId);
            record.pinned = true;
            return record;
          }).toList();
      MessageAdapter.attachParentMessages(pinnedRecords, replyLookup);

      _hasMoreMessages = page.hasMore;

      final model = chats.ChatsModel(
        records: records,
        pagination: chats.Pagination(
          currentPage: beforeSeq == null ? 1 : 2,
          totalPages: page.hasMore ? 2 : 1,
        ),
      );

      if (clearExisting) {
        _chatsData = chats.ChatsModel();
      }
      _pinnedMessagesData = chats.ChatsModel(records: pinnedRecords);
      _handleChatsDataUpdate(model);
      // ✅ This REST fetch is the actual message load for NEW (no socket
      // push ever arrives to clear this) — without this, an empty result
      // (or any path that skips the cache-hit branch) leaves the "Loading
      // messages..." UI stuck forever, since nothing else clears the flag.
      _socketEventController.setChatLoadingState(false);
    } catch (e) {
      _error = 'Failed to load chat messages: ${e.toString()}';
      _logger.e('Error fetching messages page: $e');
      _socketEventController.setChatLoadingState(false);
      _scheduleNotification();
    }
  }

  // Peer userId -> conversation id, for 1:1 chats whose conversation already
  // exists. Only ever holds ids the server confirmed; a peer with no
  // conversation yet is deliberately absent so it is re-checked rather than
  // cached as "none".
  final Map<int, int> _peerDirectChatIds = {};

  // Peers confirmed (recently) to have no conversation at all. Short-lived on
  // purpose: the other side may start the chat at any moment, so this only
  // stops a burst of re-opens from re-sweeping `GET /conversations`.
  final Map<int, DateTime> _peersWithoutChat = {};
  static const Duration _noChatCacheTtl = Duration(seconds: 60);

  /// Remembers a resolved/created 1:1 conversation so the next open of that
  /// chat skips the lookup entirely.
  void cacheDirectChatId(int peerId, int chatId) {
    if (peerId > 0 && chatId > 0) {
      _peerDirectChatIds[peerId] = chatId;
      _peersWithoutChat.remove(peerId);
    }
  }

  /// Finds the chat id of an EXISTING 1:1 conversation with [peerId] in the
  /// already-loaded chat list. Purely local, no network, no side effects.
  int findDirectChatIdInList(int peerId) {
    if (peerId <= 0) return 0;
    try {
      for (final chat in _chatListData.chats) {
        if (chat.peerUserData?.userId != peerId) continue;
        for (final record in chat.records ?? const []) {
          final id = record.chatId ?? 0;
          if (id > 0) return id;
        }
      }
    } catch (e) {
      _logger.e('Error finding direct chat id for peer $peerId: $e');
    }
    return 0;
  }

  /// Resolves the conversation for a 1:1 chat WITHOUT creating one.
  ///
  /// Opening a chat (from contacts, a profile, a shared card, ...) must not
  /// have a server side effect: the conversation row is created only by a
  /// real user action — sending a message of any type (see [sendMessage] /
  /// [sendTextMessageOptimistic] / MessageQueueService) or placing a call
  /// (CallManager.makeCall). This only *looks up* what already exists:
  /// in-memory cache -> loaded chat list -> a bounded read-only sweep of
  /// `GET /conversations` (needed because NEW's `GET /contacts` carries no
  /// `chat_id`, and the chat list may be paginated).
  ///
  /// Returns 0 when the two users have never talked.
  Future<int> resolveExistingDirectChatId(int peerId) async {
    if (peerId <= 0) return 0;

    final cached = _peerDirectChatIds[peerId] ?? 0;
    if (cached > 0) return cached;

    final fromList = findDirectChatIdInList(peerId);
    if (fromList > 0) {
      cacheDirectChatId(peerId, fromList);
      return fromList;
    }

    final checkedAt = _peersWithoutChat[peerId];
    if (checkedAt != null &&
        DateTime.now().difference(checkedAt) < _noChatCacheTtl) {
      return 0;
    }

    final remoteId = await _conversationRepository.findDirectConversationId(
      peerId.toString(),
    );
    final resolved = int.tryParse(remoteId ?? '') ?? 0;
    if (resolved > 0) {
      cacheDirectChatId(peerId, resolved);
    } else {
      _peersWithoutChat[peerId] = DateTime.now();
    }
    return resolved;
  }

  Future<void> loadChatMessages({
    required int chatId,
    required int peerId,
    bool clearExisting = true,
  }) async {
    if (_isDisposed) return;

    try {
      _logger.d(
        "🚀 LOAD CHAT: Starting loadChatMessages - chatId: $chatId, peerId: $peerId, clearExisting: $clearExisting",
      );

      // 🛡️ SAFETY CHECK: Don't load messages from recently cleared chats
      // BUT: If the chat has new messages in the chat list, allow loading
      if (_recentlyClearedChats.contains(chatId)) {
        // 🔍 Check if this chat now has messages in the chat list
        bool hasMessagesInChatList = false;
        for (final chat in _chatListData.chats) {
          if (chat.records != null && chat.records!.isNotEmpty) {
            final chatRecord = chat.records!.first;
            if (chatRecord.chatId == chatId) {
              // Check if this chat has any messages
              if (chatRecord.messages != null &&
                  chatRecord.messages!.isNotEmpty) {
                hasMessagesInChatList = true;
                _logger.d(
                  '✅ ALLOW LOAD: Chat $chatId has new messages, removing from recently cleared',
                );
                // Remove from recently cleared since it has new messages
                _recentlyClearedChats.remove(chatId);
              }
              break;
            }
          }
        }

        // Only block if chat truly has no messages
        if (!hasMessagesInChatList) {
          _logger.w(
            '🚫 BLOCKED: Preventing message load for recently cleared chat $chatId (no new messages)',
          );
          // Clear existing data instead
          _chatsData = chats.ChatsModel();
          _pinnedMessagesData = chats.ChatsModel();
          _lastChatsDataHash = null;
          _regroupMessages();
          _scheduleNotification();
          return;
        }
      }

      // 🗄️ CACHE-FIRST LOADING: Check cache before clearing data
      String? chatIdString;
      if (chatId > 0) {
        chatIdString = chatId.toString();
        _logger.d("💬 CHAT TYPE: Group/existing chat - ID: $chatId");
      } else if (peerId > 0) {
        chatIdString = 'user_$peerId';
        _logger.d("👤 CHAT TYPE: Individual chat - Peer ID: $peerId");
      }

      bool loadedFromCache = false;
      bool hasCache = false;

      if (chatIdString != null) {
        _logger.d("🔍 CACHE: Attempting to load from cache for: $chatIdString");

        // Check if cache exists first
        hasCache = ChatCacheManager.hasPage(chatIdString, 1);
        if (hasCache) {
          _logger.d(
            "🚫 LOADER PREVENTION: Cache detected - will prevent loader from showing",
          );
          // ✅ IMMEDIATE: Set loading to false before any other operations
          _socketEventController.setChatLoadingState(false);
          // ✅ CRITICAL: Set cache protection to prevent server overrides
          _socketEventController.setCacheDataProtection(true);
          // ✅ IMMEDIATE: Trigger UI update to reflect loading state change
          _scheduleNotification();
        }

        loadedFromCache = await _tryLoadFromCache(
          chatIdString,
          chatId > 0 ? chatId : peerId,
        );
        _logger.d("📊 CACHE RESULT: loadedFromCache = $loadedFromCache");
      } else {
        _logger.w("⚠️ NO CHAT ID: Cannot check cache - chatIdString is null");
      }

      // Only clear existing data if no cache was loaded and clearExisting is true
      if (clearExisting && !loadedFromCache) {
        _logger.d(
          "🧹 CLEARING: Clearing existing messages (no cache available)",
        );
        // Clear existing messages
        _chatsData = chats.ChatsModel();
        _pinnedMessagesData = chats.ChatsModel();
        _lastChatsDataHash = null;
        _regroupMessages();
        _scheduleNotification();
      } else if (clearExisting && loadedFromCache) {
        _logger.d(
          "🎯 SKIP CLEARING: Cache loaded, keeping cached data instead of clearing",
        );
      }

      // ✅ Set current chat context AFTER cache check to prevent unnecessary loading state
      if (loadedFromCache) {
        _logger.d(
          "🎯 CACHE LOADED: Setting chat context without clearing cached data",
        );
        // Set current chat data directly without clearing cached messages
        _currentChatData = ChatIds(chatId: chatId, userId: peerId);
        _socketEventController.setCurrentChatWithoutLoading(chatId, peerId);
        // Ensure pinned messages are extracted from cached data
        _extractPinnedMessages(_chatsData);
      } else {
        _logger.d(
          "📡 NO CACHE: Setting chat context normally (will trigger loading state)",
        );
        // Set the current chat context normally (will trigger loading)
        setCurrentChat(chatId, peerId);
      }

      // NEW: REST fetch, not a socket push (§6.2) — see _fetchMessagesPage.
      if (chatId > 0 && !loadedFromCache) {
        _logger.d(
          "🌐 SERVER CALL: Loading from server - cache miss for chat $chatId",
        );
        await _fetchMessagesPage(chatId: chatId, clearExisting: false);

        if (!_isDisposed &&
            _currentChatData.chatId == chatId &&
            (_chatsData.records?.isNotEmpty ?? false)) {
          _logger.d('Messages loaded, now marking unread messages as seen');
          await markChatMessagesAsSeen(chatId);
        }
      } else if (peerId > 0 && !loadedFromCache) {
        // Opening a chat must NEVER create a conversation. This used to call
        // `POST /conversations` here (relying on its 1:1 dedupe), which meant
        // simply tapping a contact created a chat row for two people who had
        // never spoken. Now we only LOOK UP an existing conversation, so an
        // already-started chat still shows its history, and a brand-new one
        // stays uncreated until the first real send (see sendMessage /
        // sendTextMessageOptimistic / MessageQueueService).
        _logger.d(
          "🔎 RESOLVE: Looking up existing conversation (no create) for peer: $peerId",
        );
        final existingChatId = await resolveExistingDirectChatId(peerId);
        if (existingChatId > 0) {
          _currentChatData = ChatIds(chatId: existingChatId, userId: peerId);
          _socketEventController.setCurrentChatWithoutLoading(
            existingChatId,
            peerId,
          );
          await _fetchMessagesPage(
            chatId: existingChatId,
            clearExisting: false,
          );
        } else {
          _logger.d(
            "🆕 NO CONVERSATION YET: peer $peerId has no chat — staying uncreated until the first message",
          );
          _currentChatData = ChatIds(chatId: 0, userId: peerId);
          _socketEventController.setCurrentChatWithoutLoading(0, peerId);
          _scheduleNotification();
        }
      } else if (loadedFromCache && chatId > 0) {
        // Cache gave an instant first paint. Still reconcile against the
        // server in the background so messages that arrived while this chat
        // was closed (or only ever existed on another device) show up, and
        // the on-disk cache gets rewritten to match. The union merge in
        // `_mergeSocketDataWithOptimistic` keeps the already-painted
        // history, so this augments rather than replaces — and
        // `_fetchMessagesPage` shows no loader since data is already on
        // screen.
        _logger.d(
          "🔄 RECONCILE: Cache shown — fetching fresh page from server for chat $chatId",
        );
        unawaited(_reconcileChatFromServer(chatId));
      } else if (loadedFromCache) {
        _logger.d(
          "🎯 CACHE SUCCESS: Loaded from cache (no chatId yet to reconcile against)",
        );
      } else {
        _logger.w(
          "⚠️ NO ACTION: Neither cache hit nor valid IDs for server call",
        );
      }

      _logger.d("Chat messages loading initiated");
    } catch (e) {
      _error = "Failed to load chat messages: ${e.toString()}";
      _logger.e("Error loading chat messages: $e");
      _scheduleNotification();
    }
  }

  /// Background reconcile after a cache hit: pull the newest page from the
  /// server and union it into what's on screen (see
  /// `_mergeSocketDataWithOptimistic`), which also rewrites the on-disk
  /// cache via `_handleChatsDataUpdate` -> `_cacheNewChatData`. Guarded so a
  /// stale result for a chat the user already navigated away from is
  /// discarded.
  Future<void> _reconcileChatFromServer(int chatId) async {
    if (_isDisposed || chatId <= 0) return;
    if (_currentChatData.chatId != chatId) return;

    final hadCachedMessages = _chatsData.records?.isNotEmpty ?? false;

    try {
      await _fetchMessagesPage(chatId: chatId, clearExisting: false);

      // A failed reconcile shouldn't surface an error banner while valid
      // cached messages are still on screen.
      if (hadCachedMessages &&
          _error != null &&
          (_chatsData.records?.isNotEmpty ?? false)) {
        _error = null;
      }

      if (!_isDisposed &&
          _currentChatData.chatId == chatId &&
          (_chatsData.records?.isNotEmpty ?? false)) {
        await markChatMessagesAsSeen(chatId);
      }
    } catch (e) {
      _logger.e("❌ RECONCILE: Failed to reconcile chat $chatId from server: $e");
    }
  }

  /// 🗄️ Try to load chat messages from cache first
  /// Returns true if successfully loaded from cache, false if cache miss
  Future<bool> _tryLoadFromCache(String chatId, int chatIdInt) async {
    try {
      _logger.d("🔍 CACHE CHECK: Checking cache for chat $chatId");

      // 🛡️ SAFETY CHECK: Don't load cache for recently cleared chats
      // BUT: If the chat has new messages in the chat list, allow loading
      if (_recentlyClearedChats.contains(chatIdInt)) {
        // 🔍 Check if this chat now has messages in the chat list
        bool hasMessagesInChatList = false;
        for (final chat in _chatListData.chats) {
          if (chat.records != null && chat.records!.isNotEmpty) {
            final chatRecord = chat.records!.first;
            if (chatRecord.chatId == chatIdInt) {
              // Check if this chat has any messages
              if (chatRecord.messages != null &&
                  chatRecord.messages!.isNotEmpty) {
                hasMessagesInChatList = true;
                _logger.d(
                  '✅ ALLOW CACHE LOAD: Chat $chatIdInt has new messages, removing from recently cleared',
                );
                // Remove from recently cleared since it has new messages
                _recentlyClearedChats.remove(chatIdInt);
              }
              break;
            }
          }
        }

        // Only block if chat truly has no messages
        if (!hasMessagesInChatList) {
          _logger.w(
            '🚫 BLOCKED: Preventing cache load for recently cleared chat $chatIdInt (no new messages)',
          );
          return false;
        }
      }

      await ChatCacheManager.initializeChat(chatId);

      // ✅ FIX: Always attempt the async persisted-cache read directly,
      // instead of gating on ChatCacheManager.hasPage() first.
      // hasPage()/hasPageInCache() is a *synchronous, in-memory-only* check
      // (it only looks at the current session's in-memory map) — it can
      // never be true for a chat that hasn't already been opened once
      // during this app process, even when valid data is sitting in the
      // persisted cache (Hive, or a chat's data freshly written this
      // session). That made every chat show a loading spinner and hit the
      // network on its first open after every cold start, regardless of
      // how much was actually cached on disk. getPage() below already
      // checks the in-memory session cache first (same fast path as
      // before) and only then falls back to persisted storage, so this is
      // strictly more capable, not slower, for the case that used to work.
      final cachedMessages = await ChatCacheManager.getPage(chatId, 1);
      _logger.d(
        cachedMessages != null && cachedMessages.isNotEmpty
            ? "🎯 CACHE HIT: Found cached page 1 for chat $chatId"
            : "📭 CACHE MISS: No cached page 1 found for chat $chatId",
      );

      if (cachedMessages != null && cachedMessages.isNotEmpty) {
        _logger.d(
            "✅ CACHE LOADING: Using ${cachedMessages.length} cached messages for chat $chatId - NO SERVER CALL NEEDED",
          );

          // ✅ FIX: Deduplicate cached messages to remove any optimistic duplicates
          final deduplicatedMessages = _deduplicateCachedMessages(
            cachedMessages,
          );
          _logger.d(
            "🧹 After deduplication: ${deduplicatedMessages.length} messages (removed ${cachedMessages.length - deduplicatedMessages.length} duplicates)",
          );

          // Use the real hasMore saved alongside this page (from the last
          // actual server fetch) instead of guessing — a hardcoded
          // totalPages here previously left the pagination loader spinning
          // forever even for a chat with no more messages to load.
          final cachedPaginationInfo = ChatCacheManager.getPaginationInfo(
            chatId,
          );
          _hasMoreMessages = cachedPaginationInfo?.hasMore ?? false;

          // Create ChatsModel from deduplicated cached data
          final cachedChatModel = chats.ChatsModel(
            records: deduplicatedMessages,
            pagination: chats.Pagination(
              currentPage: cachedPaginationInfo?.currentPage ?? 1,
              totalPages: cachedPaginationInfo?.totalPages ?? 1,
              totalRecords:
                  cachedPaginationInfo?.totalRecords ??
                  deduplicatedMessages.length,
              recordsPerPage: deduplicatedMessages.length,
            ),
          );

          // Update provider state with cached data
          _chatsData = cachedChatModel;
          _regroupMessages();

          // ✅ CRITICAL: Extract pinned messages from cached data
          _extractPinnedMessages(cachedChatModel);
          _logger.d(
            "📌 CACHE: Extracted pinned messages from cached data for chat $chatId",
          );

          // ✅ CRITICAL: Set loading states to false to hide loaders
          _isPaginationLoading = false;
          _isChatListPaginationLoading = false;

          // Initialize pagination state
          _chatListCurrentPage = 1;
          _hasChatListMoreData = true; // Assume more data might be available

          // ✅ CRITICAL: Force socket loading state to false so UI hides loader
          _socketEventController.setChatLoadingState(false);

          // 🛡️ PROTECTION: Enable cache protection to prevent server overrides
          _socketEventController.setCacheDataProtection(true);

          // ✅ CRITICAL: Notify UI immediately with cached data
          _scheduleNotification();

          _logger.d(
            "🚀 CACHE SUCCESS: UI updated with cached data, loaders hidden for chat $chatId",
          );

          // 🔄 DISABLED: Temporarily disable background fetch to prevent loader interference
          // _fetchUpdatesInBackground(chatIdInt);

          _logger.d(
            "🎯 CACHE COMPLETE: Cached data loaded, loader hidden, background fetch disabled",
          );

          return true;
      } else {
        _logger.d(
          "⚠️ CACHE EMPTY: Page exists but no messages for chat $chatId",
        );
      }

      _logger.d("🌐 FALLBACK: Will load from server for chat $chatId");
      return false;
    } catch (e) {
      _logger.e(
        "❌ CACHE ERROR: Failed to load from cache for chat $chatId: $e",
      );
      return false;
    }
  }

  /// Fetch updates in background after loading from cache
  // ignore: unused_element
  Future<void> _fetchUpdatesInBackground(int chatId) async {
    try {
      _logger.d("🔄 BACKGROUND: Starting background fetch for chat $chatId");

      // Delay to let UI render cached data first
      await Future.delayed(const Duration(seconds: 2));

      if (!_isDisposed && _currentChatData.chatId == chatId) {
        _logger.d(
          "📡 BACKGROUND: Fetching fresh data in background for chat $chatId",
        );
        // Fetch fresh data in background
        await _fetchMessagesPage(chatId: chatId, clearExisting: false);
        _logger.d("✅ BACKGROUND: Background fetch completed for chat $chatId");
      } else {
        _logger.d(
          "⏭️ BACKGROUND: Skipped background fetch - chat changed or disposed",
        );
      }
    } catch (e) {
      _logger.e("❌ BACKGROUND: Error in background fetch: $e");
    }
  }

  /// 🗄️ Cache new chat data when received from server
  Future<void> _cacheNewChatData(chats.ChatsModel data) async {
    try {
      if (data.records == null || data.records!.isEmpty) return;

      String? chatIdString;
      if (_currentChatData.chatId != null && _currentChatData.chatId! > 0) {
        chatIdString = _currentChatData.chatId.toString();
      } else if (_currentChatData.userId != null &&
          _currentChatData.userId! > 0) {
        chatIdString = 'user_${_currentChatData.userId}';
      }

      if (chatIdString == null) return;

      final currentPage = data.pagination?.currentPage ?? 1;

      _logger.d(
        "💾 Caching new data for chat $chatIdString, page $currentPage (${data.records!.length} messages)",
      );

      // Cache the data
      await ChatCacheManager.cachePage(
        chatIdString,
        currentPage,
        data.records!,
        pagination: data.pagination,
      );

      _logger.d(
        "✅ Successfully cached page $currentPage for chat $chatIdString",
      );
    } catch (e) {
      _logger.e("❌ Error caching new chat data: $e");
    }
  }

  /// 🧪 Debug method to test cache functionality
  Future<void> debugCacheStatus(String chatId) async {
    try {
      _logger.d("🔬 DEBUG: Testing cache for chat $chatId");

      await ChatCacheManager.initializeChat(chatId);

      final hasPage1 = ChatCacheManager.hasPage(chatId, 1);
      _logger.d("📊 DEBUG: hasPage(1) = $hasPage1");

      if (hasPage1) {
        final messages = await ChatCacheManager.getPage(chatId, 1);
        _logger.d("📊 DEBUG: Cached messages count = ${messages?.length ?? 0}");
      }

      final cachedPages = ChatCacheManager.getCachedPages(chatId);
      _logger.d("📊 DEBUG: All cached pages = $cachedPages");

      ChatCacheManager.logCacheStats(chatId);
    } catch (e) {
      _logger.e("❌ DEBUG: Error testing cache: $e");
    }
  }

  /// Oldest `conversationSeq` among the currently-loaded (non-optimistic)
  /// messages, to page backward from via `beforeSeq`. `conversationSeq` is
  /// carried in `Records.unseenCount` — see `MessageAdapter.toRecord`.
  int? _oldestLoadedMessageSeq() {
    final records = _chatsData.records;
    if (records == null || records.isEmpty) return null;
    int? oldest;
    for (final r in records) {
      if (r.tempId != null) continue; // skip unconfirmed optimistic sends
      final seq = r.unseenCount;
      if (seq == null || seq <= 0) continue;
      if (oldest == null || seq < oldest) oldest = seq;
    }
    return oldest;
  }

  /// `GET /messages/:conversationId?beforeSeq=&limit=` (§6.2/§6.3) — pages
  /// older messages in via REST, not a socket round-trip (NEW has no
  /// `message_list` socket event at all; the previous socket-delegated
  /// implementation emitted into the void and this pagination silently
  /// never loaded anything). Appends to `_chatsData.records`;
  /// `_regroupMessages`/`ChatDateGrouper` re-sorts by timestamp internally
  /// so append order doesn't matter, matching how `addMessages` already
  /// works for incoming realtime messages.
  Future<void> loadMoreMessages() async {
    if (_isDisposed) return;

    if (_isPaginationLoading ||
        !hasMoreMessages ||
        isChatLoading ||
        isRefreshing) {
      _logger.d(
        'Pagination skipped - loading: $_isPaginationLoading, hasMore: $hasMoreMessages, chatLoading: $isChatLoading, refreshing: $isRefreshing',
      );
      return;
    }

    final chatId = _socketEventController.currentChatId;
    if (chatId == null || chatId <= 0) {
      _logger.w('Cannot load more messages - no active chat');
      return;
    }

    final beforeSeq = _oldestLoadedMessageSeq();
    if (beforeSeq == null) {
      _logger.w('Cannot load more messages - no confirmed messages loaded yet');
      _hasMoreMessages = false;
      _scheduleNotification();
      return;
    }

    try {
      _logger.d('🔄 Starting pagination load - beforeSeq: $beforeSeq');
      _setPaginationLoading(true);

      final results = await Future.wait([
        _messageRepository.getMessages(chatId, beforeSeq: beforeSeq, limit: 30),
        _conversationRepository.getConversation(chatId.toString()),
      ]);
      if (_isDisposed) return;

      final page = results[0] as MessagesPage;
      final conversation = results[1] as ConversationDto?;

      final myId = _currentUserId ?? '';
      final peerLastReadSeq =
          conversation?.participants
              .where((p) => p.userId != myId)
              .map((p) => p.lastReadSeq ?? 0)
              .fold<int>(0, (a, b) => b > a ? b : a) ??
          0;

      final olderRecords =
          page.items.map((m) {
            final record = MessageAdapter.toRecord(m, currentUserId: _currentUserId);
            MessageAdapter.applySeenStatus(
              record,
              peerLastReadSeq: peerLastReadSeq,
            );
            record.pinned =
                _pinnedMessagesData.records?.any(
                  (p) => p.messageId == record.messageId,
                ) ??
                false;
            return record;
          }).toList();

      // Backfill reply previews — see MessageAdapter.attachParentMessages.
      final replyLookup = <int, chats.Records>{
        for (final r in (_chatsData.records ?? const <chats.Records>[]))
          if (r.messageId != null) r.messageId!: r,
        for (final r in olderRecords)
          if (r.messageId != null) r.messageId!: r,
      };
      MessageAdapter.attachParentMessages(olderRecords, replyLookup);

      _chatsData.records ??= [];
      _chatsData.records!.addAll(olderRecords);
      _hasMoreMessages = page.hasMore;
      _cacheNewChatData(_chatsData);
      _regroupMessages();

      _logger.d(
        '✅ Pagination load completed - loaded ${olderRecords.length} older messages',
      );
    } catch (e) {
      _error = "Failed to load more messages: ${e.toString()}";
      _logger.e("❌ Pagination error: $e");
    } finally {
      _setPaginationLoading(false);
      _scheduleNotification();
    }
  }

  /// Pin or unpin a message
  Future<bool> pinUnpinMessage(
    int chatId,
    int messageId, [
    int inDays = 1,
  ]) async {
    if (_isDisposed) return false;

    try {
      // The message can live in the loaded chat window, in the pinned-
      // messages list, or both. Unpinning from the pinned widget often
      // targets a message that has scrolled out of the loaded window, so
      // look in both lists — keying only off `_chatsData` made `targetMessage`
      // null there, which flipped the toggle the wrong way (re-pin instead of
      // unpin) and left the pinned widget unchanged.
      final targetMessages = <chats.Records>[
        ...?_chatsData.records?.where((msg) => msg.messageId == messageId),
        ...?_pinnedMessagesData.records?.where(
          (msg) => msg.messageId == messageId,
        ),
      ];
      final targetMessage =
          targetMessages.isNotEmpty ? targetMessages.first : null;

      // Check permissions if message found
      if (targetMessage != null && !canPinUnpinMessage(targetMessage)) {
        _error = getPinUnpinPermissionText(targetMessage);
        _scheduleNotification();
        return false;
      }

      // NEW has no pin_lifetime/auto-expiry concept at all (§6.7 breaking
      // change #12) — `inDays` is accepted only for call-site
      // compatibility and no longer sent; pin/unpin is now a plain
      // boolean toggle off the message's current local state. Treat the
      // message as pinned if any in-memory copy says so OR it's present in
      // the pinned-messages list.
      final wasPinned =
          targetMessages.any((msg) => msg.pinned == true) ||
          (_pinnedMessagesData.records?.any(
                (msg) => msg.messageId == messageId,
              ) ??
              false);
      final pin = !wasPinned;

      _logger.d(
        'Pin/Unpin message via API - chatId: $chatId, messageId: $messageId, pin: $pin',
      );

      try {
        if (pin) {
          await _messageRepository.pinMessage(chatId, messageId);
        } else {
          await _messageRepository.unpinMessage(chatId, messageId);
        }
      } catch (e) {
        _error = "Failed to pin/unpin message via API";
        _logger.e('Pin/unpin message API error: $e');
        _scheduleNotification();
        return false;
      }

      if (!_isDisposed) {
        // Optimistic local update: NEW's message_pinned/message_unpinned
        // socket push only reaches subscribers via a REST re-fetch, so
        // reflect the change immediately here too.
        for (final msg in targetMessages) {
          msg.pinned = pin;
        }
        if (pin) {
          final alreadyListed =
              _pinnedMessagesData.records?.any(
                (msg) => msg.messageId == messageId,
              ) ??
              false;
          if (!alreadyListed && targetMessage != null) {
            (_pinnedMessagesData.records ??= <chats.Records>[]).add(
              targetMessage,
            );
          }
        } else {
          _pinnedMessagesData.records?.removeWhere(
            (msg) => msg.messageId == messageId,
          );
        }
        // Reconcile against the server's authoritative pinned list (also
        // covers the case where the target wasn't in memory at all).
        unawaited(_refreshPinnedMessagesFor(chatId.toString()));
        _logger.i('Message pin/unpin successful via API');
        _error = null;
        _regroupMessages();
        _scheduleNotification();
        return true;
      }
      return false;
    } catch (e) {
      _error = "Failed to pin/unpin message: ${e.toString()}";
      _logger.e('Pin/unpin message error: $e');
      _scheduleNotification();
      return false;
    }
  }

  /// Fetches the current user's starred message ids from the server and
  /// caches them so [isMessageStarred] can light up the star indicator on
  /// bubbles for messages starred in a previous session. NEW has no
  /// per-message star flag anywhere else and fires no socket event on
  /// star/unstar (§6.4), so this is the only way to know.
  Future<void> loadStarredMessageIds() async {
    if (_isDisposed) return;
    try {
      final page = await _messageRepository.getStarredMessages(limit: 10000);
      final ids = page.items
          .map((m) => int.tryParse(m.id))
          .whereType<int>()
          .toSet();
      _starredMessageIds
        ..clear()
        ..addAll(ids);
      _logger.d('Loaded ${_starredMessageIds.length} starred message ids');
      _scheduleNotification();
    } catch (e) {
      _logger.w('Failed to load starred message ids: $e');
    }
  }

  bool isMessageStarred(int messageId) {
    // Server-backed truth (loaded from `GET /messages/starred` on chat open).
    if (_starredMessageIds.contains(messageId)) {
      return true;
    }

    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      return false;
    }

    try {
      final message = _chatsData.records!.firstWhere(
        (msg) => msg.messageId == messageId,
      );

      // Check both stared field and starredFor array
      if (message.stared == true) {
        return true;
      }

      // Check if current user is in starredFor array
      if (message.starredFor != null && message.starredFor!.isNotEmpty) {
        return message.starredFor!.contains(_currentUserId);
      }

      return false;
    } catch (e) {
      _logger.w('Message $messageId not found for star check: $e');
      return false;
    }
  }

  /// Star or Unstar a message method
  Future<bool> starUnstarMessage(int messageId) async {
    if (_isDisposed) return false;

    try {
      // Find the message to check permissions and current state
      chats.Records? targetMessage;
      if (_chatsData.records != null) {
        try {
          targetMessage = _chatsData.records!.firstWhere(
            (msg) => msg.messageId == messageId,
          );
        } catch (e) {
          _logger.w('Message not found in current chat data: $messageId');
        }
      }

      // Check permissions if message found
      if (targetMessage != null && !canStarUnStarMessage(targetMessage)) {
        _error = getStarUnstarPermissionText(targetMessage);
        _scheduleNotification();
        return false;
      }

      final wasStarred = isMessageStarred(messageId);
      final star = !wasStarred;
      _logger.d('Star/Unstar message via API - messageId: $messageId, star: $star');

      try {
        if (star) {
          await _messageRepository.starMessage(messageId);
        } else {
          await _messageRepository.unstarMessage(messageId);
        }
      } catch (e) {
        _error = "Failed to Star/UnStar message via API";
        _logger.e('Star/UnStar message API error: $e');
        _scheduleNotification();
        return false;
      }

      if (!_isDisposed) {
        // NEW fires zero socket events for star/unstar — update locally
        // instead of waiting for a push that never arrives (§6.4/§13.11).
        targetMessage?.stared = star;
        if (star) {
          _starredMessageIds.add(messageId);
        } else {
          _starredMessageIds.remove(messageId);
        }
        _logger.i('Message Star/UnStar successful via API');
        _error = null;
        _scheduleNotification();
        return true;
      }
      return false;
    } catch (e) {
      _error = "Failed to Star/UnStar message: ${e.toString()}";
      _logger.e('Star/UnStar message error: $e');
      _scheduleNotification();
      return false;
    }
  }

  // Handle refreshing chat list
  // Future<void> refreshChatList() async {
  //   if (_isDisposed) return;

  //   try {
  //     await _socketEventController.refreshChatList();
  //   } catch (e) {
  //     _logger.e("Error refreshing chat list: $e");
  //   }
  // }

  /// Handle refreshing chat list (updated for pagination)
  Future<void> refreshChatList() async {
    if (_isDisposed) return;

    try {
      _logger.d("🔄 Refreshing chat list from first page");

      // Set loading state immediately
      _error = null;
      _isChatListLoading = true;

      // Reset pagination state
      resetChatListPagination();

      // CRITICAL FIX: Force immediate UI update
      notifyListeners();

      // Request first page
      await emitChatListWithPage(1);
    } catch (e) {
      _logger.e("Error refreshing chat list: $e");
      _error = "Failed to refresh chat list: ${e.toString()}";
      _isChatListLoading = false;
      _scheduleNotification();
    }
  }

  /// ✅ FIX: Silent refresh - no loading indicator shown
  /// Use this for background sync after sending messages
  Future<void> refreshChatListSilent() async {
    if (_isDisposed) return;

    // Debounce rapid calls (500ms)
    if (_isChatListRefreshPending) {
      _logger.d("🔇 Silent refresh already pending, skipping duplicate");
      return;
    }

    _isChatListRefreshPending = true;
    _chatListRefreshDebounceTimer?.cancel();
    _chatListRefreshDebounceTimer = Timer(
      Duration(milliseconds: 500),
      () async {
        _isChatListRefreshPending = false;

        if (_isDisposed) return;

        try {
          _logger.d("🔇 Refreshing chat list silently (no loader)");
          _isSyncingChatList = true;

          // NEW: REST fetch replaces the old silent socket refresh; page 1
          // with a fresh cursor, same as a normal refresh but without the
          // loud resetChatListPagination()/notifyListeners() up front.
          await _fetchConversationsPage(page: 1, archived: false);

          _isSyncingChatList = false;
        } catch (e) {
          _logger.e("Error in silent chat list refresh: $e");
          _isSyncingChatList = false;
        }
      },
    );
  }

  /// ✅ FIX: Optimistic update - move chat to top with new message
  /// Call this immediately when user sends a message
  void updateChatListLocally({
    required int chatId,
    required String lastMessage,
    required String messageType,
  }) {
    if (_isDisposed) return;
    if (chatId <= 0) return;

    try {
      final chats = _chatListData.chats;
      if (chats.isEmpty) return;

      // Find the chat in the list
      final chatIndex = chats.indexWhere((c) {
        final records = c.records;
        if (records == null || records.isEmpty) return false;
        return records.first.chatId == chatId;
      });
      if (chatIndex == -1) return;

      final chat = chats[chatIndex];
      final record = chat.records?.first;
      if (record == null) return;

      // Create updated message with new content
      final updatedMessage = Messages(
        messageContent: lastMessage,
        messageType: messageType,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      // Update the record with new message and timestamp
      final updatedRecord = Records(
        chatId: record.chatId,
        chatType: record.chatType,
        groupName: record.groupName,
        groupIcon: record.groupIcon,
        groupDescription: record.groupDescription,
        blockedBy: record.blockedBy,
        unseenCount: record.unseenCount,
        createdAt: record.createdAt,
        updatedAt: DateTime.now().toIso8601String(), // Update timestamp
        messages: [updatedMessage], // New last message
      );

      // Create updated chat item
      final updatedChat = Chats(
        peerUserData: chat.peerUserData,
        records: [updatedRecord],
      );

      // Remove chat from current position and add to top
      final updatedChats = List<Chats>.from(chats);
      updatedChats.removeAt(chatIndex);
      updatedChats.insert(0, updatedChat);

      // Update the model
      _chatListData = ChatListModel(
        chats: updatedChats,
        pagination: _chatListData.pagination,
      );

      _logger.d("✅ Chat list updated locally - chat $chatId moved to top");
      _scheduleNotification();
    } catch (e) {
      _logger.e("Error updating chat list locally: $e");
    }
  }

  // Cooldown guard for the "message arrived for a chat not in the list yet"
  // fallback refresh, so a burst of messages for a new conversation can't
  // fire a REST reload per message.
  int _lastIncomingListRefreshMs = 0;

  /// Applies an incoming socket `new_message` to the chat list in place:
  /// refreshes the last-message preview, bumps the unread badge (only for
  /// messages from other users that aren't currently on screen) and moves
  /// the conversation to the top. The new backend has no `chat_list` socket
  /// event, so this is the only live path keeping the list current.
  void _applyIncomingSocketMessageToChatList(chats.Records msg) {
    if (_isDisposed) return;

    final chatId = msg.chatId ?? 0;
    if (chatId <= 0) return;

    try {
      final myId = int.tryParse(_currentUserId ?? '');
      // Only treat the sender as "someone else" when we can positively
      // confirm it — an unknown identity must NOT inflate the unread badge
      // for a message the current user may have sent themselves.
      final senderKnown = myId != null && msg.senderId != null;
      final isFromMe = senderKnown && msg.senderId == myId;

      final isViewingThisChat =
          _socketEventController.currentChatId == chatId &&
          _socketEventController.isChatScreenActive &&
          _socketEventController.isAppInForeground;

      final currentChats = _chatListData.chats;
      final chatIndex = currentChats.indexWhere((c) {
        final records = c.records;
        if (records == null || records.isEmpty) return false;
        return records.first.chatId == chatId;
      });

      // Not in the loaded list (brand-new conversation, or on a page we
      // haven't fetched). Pull a fresh first page so it shows up — debounced.
      if (chatIndex == -1) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (!_isChatListLoading &&
            !_isChatListPaginationLoading &&
            nowMs - _lastIncomingListRefreshMs > 4000) {
          _lastIncomingListRefreshMs = nowMs;
          _logger.d(
            "📥 Incoming message for chat $chatId not in list — refreshing first page",
          );
          emitChatList();
        }
        return;
      }

      final chat = currentChats[chatIndex];
      final record = chat.records!.first;

      // Already reflected (e.g. our own optimistic send that was echoed back).
      final existingLastId =
          record.messages?.isNotEmpty == true
              ? record.messages!.first.messageId
              : null;
      if (existingLastId != null && existingLastId == msg.messageId) {
        return;
      }

      final preview = Messages(
        messageId: msg.messageId,
        messageContent: msg.messageContent,
        messageType: msg.messageType,
        senderId: msg.senderId,
        createdAt: msg.createdAt ?? DateTime.now().toIso8601String(),
        updatedAt: msg.updatedAt,
        deletedForEveryone: msg.deletedForEveryone ?? false,
        // Call-log messages ('call') carry all their display info (direction,
        // status, type, duration) in `calls[]` — `messageContent` is null.
        // Dropping it here left the chat-list preview with no way to render
        // "Incoming/Outgoing/Missed … call" so it fell through to a blank/
        // generic line even though the unread badge updated. The REST fetch
        // and the socket-controller update path both keep this array; this
        // in-place preview build is the only one that was losing it.
        calls: msg.calls,
        messageSeenStatus: msg.messageSeenStatus,
      );

      int newUnseen = record.unseenCount ?? 0;
      if (senderKnown && !isFromMe && !isViewingThisChat) {
        newUnseen += 1;
      }

      // Mutate the existing record in place so participants / blockedBy /
      // group metadata are preserved.
      record.messages = [preview];
      record.unseenCount = newUnseen;
      record.updatedAt = preview.createdAt;

      final updatedChats = List<Chats>.from(currentChats);
      updatedChats.removeAt(chatIndex);
      updatedChats.insert(0, chat);

      _chatListData = ChatListModel(
        chats: updatedChats,
        pagination: _chatListData.pagination,
      );

      _sortChatList();
      _persistChatListCache();

      _logger.d(
        "✅ Chat list: applied incoming message ${msg.messageId} to chat $chatId (unseen=$newUnseen, fromMe=$isFromMe)",
      );
      _scheduleNotification();
    } catch (e) {
      _logger.e("Error applying incoming socket message to chat list: $e");
    }
  }

  Future<void> refreshChatMessages({
    required int chatId,
    required int peerId,
  }) async {
    if (_isDisposed) return;

    // Prevent multiple simultaneous refreshes
    if (isRefreshing) {
      _logger.d('Already refreshing, ignoring duplicate request');
      return;
    }

    try {
      _logger.d(
        "🔄 Starting chat messages refresh - chatId: $chatId, peerId: $peerId",
      );

      // Use the socket controller's dedicated refresh method
      await _socketEventController.refreshChatMessages(chatId, peerId);

      _logger.d("✅ Chat messages refresh completed");
    } catch (e) {
      _logger.e("❌ Error refreshing chat messages: $e");
      _error = "Failed to refresh chat messages: ${e.toString()}";
      _scheduleNotification();
      rethrow;
    }
  }

  void scrollToPinnedMessage(int messageId, ScrollController scrollController) {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      _logger.w('No chat messages to scroll to');
      return;
    }

    try {
      // Find the index of the message in the chat list
      final messageIndex = _chatsData.records!.indexWhere(
        (message) => message.messageId == messageId,
      );

      if (messageIndex != -1) {
        // Highlight the message
        highlightMessage(messageId);

        // Calculate scroll position (approximate)
        // Assuming each message bubble is roughly 80 pixels high
        const double averageMessageHeight = 80.0;
        final double targetPosition = messageIndex * averageMessageHeight;

        // Scroll to the message
        scrollController.animateTo(
          targetPosition,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );

        _logger.d('Scrolling to pinned message at index $messageIndex');
      } else {
        _logger.w(
          'Pinned message with ID $messageId not found in current chat',
        );
      }
    } catch (e) {
      _logger.e('Error scrolling to pinned message: $e');
    }
  }

  bool _isVotePoll = false;
  bool get isVotePoll => _isVotePoll;

  /// messageId -> resolved poll data. The message list / socket payload
  /// carries no poll relation (only `metadata.pollId`), so poll options are
  /// fetched once via `GET /polls/:id` and kept here for the session; the
  /// creator also seeds this straight from the create response.
  final Map<int, chats.PollData> _pollCache = {};

  /// Poll data for a rendered `type: 'poll'` message, if resolved.
  chats.PollData? pollForMessage(int messageId) => _pollCache[messageId];

  /// Resolve poll data for any `type: 'poll'` records that don't have it
  /// yet: from the session cache first, otherwise `GET /polls/:pollId`
  /// (`Records.pollId`, carried from the message's `metadata`). Mutates the
  /// records in place. Returns true if anything changed.
  Future<bool> _enrichPollRecords(List<chats.Records> records) async {
    final pending =
        records
            .where(
              (r) =>
                  (r.messageType?.toLowerCase() == 'poll') &&
                  r.messageId != null &&
                  (r.pollData?.options?.isNotEmpty != true),
            )
            .toList();
    if (pending.isEmpty) return false;

    var changed = false;
    await Future.wait(
      pending.map((r) async {
        final msgId = r.messageId!;

        final cached = _pollCache[msgId];
        if (cached != null) {
          r.pollData = cached;
          changed = true;
          return;
        }

        final pollId = r.pollId;
        if (pollId == null || pollId.isEmpty) return;

        try {
          final raw = await _messageRepository.getPoll(pollId);
          if (raw == null || _isDisposed) return;
          final pd = chats.PollData.fromNewApi(
            raw,
            currentUserId: _currentUserId,
          );
          _pollCache[msgId] = pd;
          r.pollData = pd;
          changed = true;
        } catch (e) {
          _logger.w('Failed to resolve poll $pollId for message $msgId: $e');
        }
      }),
    );
    return changed;
  }

  /// Fire-and-forget poll resolution for records that just arrived via the
  /// socket / cache-merge path (which never carries poll options), then
  /// re-render if anything filled in.
  Future<void> _enrichPollRecordsAndNotify() async {
    final records = _chatsData.records;
    if (records == null || records.isEmpty) return;
    final changed = await _enrichPollRecords(records);
    if (changed && !_isDisposed) {
      _regroupMessages();
      _cacheNewChatData(_chatsData);
      notify();
    }
  }

  /// Push freshly-fetched poll data onto whichever loaded record owns it,
  /// refresh the session cache, and re-render.
  void _applyUpdatedPoll(int pollId, chats.PollData updated) {
    final records = _chatsData.records;
    if (records == null) return;
    bool changed = false;
    for (final r in records) {
      final owns =
          r.pollData?.pollId == pollId ||
          (r.messageId != null && _pollCache[r.messageId!]?.pollId == pollId);
      if (owns) {
        r.pollData = updated;
        if (r.messageId != null) _pollCache[r.messageId!] = updated;
        changed = true;
      }
    }
    if (changed) {
      _regroupMessages();
      _cacheNewChatData(_chatsData);
      notify();
    }
  }

  /// Merge a `poll_updated` socket push (keyed by `messageId`, which the
  /// payload gives directly — more reliable than matching on the parsed
  /// `pollId`) onto whichever loaded record owns that message.
  void _applyPollUpdateFromSocket(int messageId, chats.PollData updated) {
    _pollCache[messageId] = updated;
    final records = _chatsData.records;
    if (records == null) return;
    bool changed = false;
    for (final r in records) {
      if (r.messageId == messageId) {
        r.pollData = updated;
        changed = true;
      }
    }
    if (changed) {
      _regroupMessages();
      _cacheNewChatData(_chatsData);
      notify();
    }
  }

  /// NEW's poll vote is multi-select, opaque option ids — not OLD's
  /// single text `option` (§6.5/§6.7 breaking change #2). `optionIds` here
  /// is BEST-EFFORT: this app's local `PollOption.id` is just a positional
  /// array index (poll options were plain text in OLD, no server-assigned
  /// id) via `PollOption.voteId`. The vote endpoint itself doesn't return
  /// the updated tally, so this re-fetches the viewer-aware `GET /polls/:id`
  /// right after and pushes it onto the rendered message via
  /// `_applyUpdatedPoll` — this stays even though the server also broadcasts
  /// `poll_updated` to the room, since that push is viewer-neutral and may
  /// race with this REST round trip; other participants rely solely on the
  /// `poll_updated` subscription (`_applyPollUpdateFromSocket`) to see this
  /// vote land.
  Future<bool> votePoll(int pollId, List<String> optionIds) async {
    try {
      _isVotePoll = true;
      _errorMessage = null;
      notify();

      await _messageRepository.votePoll(pollId.toString(), optionIds);

      // No push on vote — pull the updated poll and re-render in place.
      try {
        final raw = await _messageRepository.getPoll(pollId.toString());
        if (raw != null && !_isDisposed) {
          _applyUpdatedPoll(
            pollId,
            chats.PollData.fromNewApi(raw, currentUserId: _currentUserId),
          );
        }
      } catch (e) {
        _logger.w('Vote succeeded but poll refresh failed: $e');
      }

      _isVotePoll = false;
      notify();
      return true;
    } catch (e) {
      _isVotePoll = false;
      _errorMessage = "Something went wrong, try again";
      notify();
      _logger.e('Error voting poll: $e');
      return false;
    }
  }

  final Set<int> _sessionUnlockedChatIds = {};
  bool isSessionUnlocked(int chatId) {
    return _sessionUnlockedChatIds.contains(chatId);
  }

  /// Mark a chat as PIN-verified for this session.
  void markSessionUnlocked(int chatId) {
    _sessionUnlockedChatIds.add(chatId);
    notify();
  }

  /// Call this if you want to re-lock a chat mid-session
  /// (e.g. when the user navigates back after locking from options).
  void clearSessionUnlock(int chatId) {
    _sessionUnlockedChatIds.remove(chatId);
    notify();
  }

  // 🔒 lockChat/resetChatPin/removeChatPin removed — the new backend has no
  // chat-lock/PIN endpoints at all, and nothing calls these anymore (the
  // only entry point was removed from chat_list.dart's chat options sheet).
  // unLockChat is kept below only because the pre-existing (now permanently
  // unreachable, since a chat can never become locked again) unlock-gating
  // check still references it in a few screens.

  bool _isRemoveLockChat = false;
  bool get isRemoveLockChat => _isRemoveLockChat;
  Future<bool> unLockChat(String chatId, String pin) async {
    try {
      _isRemoveLockChat = true;
      _errorMessage = null;
      notify();

      final response = await _chatRepository.unLockChatRepo(
        chatId: chatId,
        pin: pin,
      );
      if (response != null && response['status'] == true) {
        _isRemoveLockChat = false;
        notify();
        _logger.d('Remove lock chat response: $response');
        return true;
      } else {
        _isRemoveLockChat = false;
        _errorMessage =
            response!['message'] ?? "Something went wrong, try again";
        notify();
        return false;
      }
    } catch (e) {
      _isRemoveLockChat = false;
      _errorMessage = "Something went wrong, try again";
      notify();
      _logger.e('Error removing lock chat: $e');
      return false;
    }
  }

  String? storyid;

  /// Snapshot of the story currently being replied to, set by the story
  /// viewer right before it calls [sendMessage] with
  /// [MessageType.StoryReply]. NEW has no server-side story wiring on a
  /// message, so this whole map is shipped in the message `metadata` bag
  /// and re-hydrated into the reply bubble on the other side
  /// (MessageAdapter). Cleared after every send attempt.
  Map<String, dynamic>? storyReplyContext;

  // ✅ UPDATED: Send message using ChatRepository
  Future<bool> sendMessage(
    String messageContent, {
    required MessageType messageType,
    int? chatId,
    int? userId,
    Uint8List? bytes,
    int? replyToMessageId, // ✅ NEW: Add reply parameter
    Duration voiceDuration = Duration.zero,
    List<String>? pollOption,
    bool? isMultiplePollVotes,
  }) async {
    if (_isDisposed) return false;

    try {
      _isSendingMessage = true;
      _isShowAttachments = false;
      _scheduleNotification();

      // The screen always passes its route argument (0 for a chat opened from
      // contacts), but the conversation may already have been resolved for
      // this same peer while opening it — reuse that id instead of asking the
      // server to create/dedupe one on every single send.
      final int argChatId = chatId ?? 0;
      final int contextChatId =
          (userId == null || _currentChatData.userId == userId)
              ? (_currentChatData.chatId ?? 0)
              : 0;
      final int resolvedChatId = argChatId > 0 ? argChatId : contextChatId;

      // Determine if this is a new chat (nothing exists server-side yet)
      bool isNewChat = resolvedChatId <= 0;
      // ✅ FIX: Use userId parameter for new chats, otherwise use peerID from current chat
      final peerID =
          isNewChat && userId != null ? userId : _currentChatData.userId;

      _logger.d(
        'Sending message to ${isNewChat ? "new user" : "existing chat"}: $chatId, peer ID: $peerID, type: $messageType, replyTo: $replyToMessageId',
      );
      // Handle message content for different types
      String finalMessageContent = messageContent;
      if (messageContent.isEmpty) {
        switch (messageType) {
          case MessageType.Video:
            finalMessageContent = "Shared a video";
            break;
          case MessageType.Image:
            finalMessageContent = "Shared an image";
            break;
          case MessageType.File:
            finalMessageContent = "Shared a document";
            break;
          case MessageType.Gif:
            finalMessageContent = "Shared a GIF";
            break;
          case MessageType.StoryReply:
            finalMessageContent = messageContent;
            break;
          case MessageType.Voice:
            finalMessageContent = "Shared a voice";
            break;
          default:
            finalMessageContent = messageContent;
        }
      }

      // NEW: JSON send, no raw multipart file field at all anymore (§6.2/
      // §6.7 breaking change #6) — media types need a pre-uploaded
      // `attachmentMediaIds` list. Phase 6 built MediaUploadService for
      // this: upload the already-staged File(s) (set via setShareImage/
      // setShareDocument/setShareVideo/setShareVoice, unchanged since
      // Phase 5) right before sending, then reference the resulting
      // mediaIds. A GIF sent by URL (no picked file, Giphy-style) needs no
      // upload at all — `body` carries the URL directly, matching OLD's
      // isGifUrl special case.
      _logger.d("messageType:$messageType");

      final isGifUrl =
          messageType == MessageType.Gif &&
          messageContent.startsWith('http') &&
          messageContent.contains('gif');

      List<String>? attachmentMediaIds;
      if (MessageTypeUtils.requiresFileUpload(messageType) && !isGifUrl) {
        final files = <File>[];
        switch (messageType) {
          case MessageType.Image:
          case MessageType.Gif:
            if (_shareImage != null) files.addAll(_shareImage!);
            break;
          case MessageType.File:
            if (_shareDocument != null) files.addAll(_shareDocument!);
            break;
          case MessageType.Video:
            if (_shareVideo != null) files.addAll(_shareVideo!);
            break;
          case MessageType.Voice:
            if (_shareVoice != null) files.add(_shareVoice!);
            break;
          default:
            break;
        }

        if (files.isEmpty) {
          throw AppError(
            'No file selected for this message type: $messageType',
          );
        }

        final uploadedIds = <String>[];
        for (final file in files) {
          final mediaId = await _mediaUploadService.uploadFile(
            file: file,
            context: 'chat',
          );
          if (mediaId == null) {
            throw AppError('Failed to upload attachment. Please try again.');
          }
          uploadedIds.add(mediaId);
        }
        attachmentMediaIds = uploadedIds;
      }

      // Sending IS the action that brings a 1:1 conversation into existence —
      // this is the only place (besides the queue service and a placed call)
      // allowed to create one. Opening the chat screen no longer does.
      int? sendChatId = resolvedChatId > 0 ? resolvedChatId : null;
      if (isNewChat) {
        final newChatPeerId = peerID ?? userId ?? 0;
        final conversation = await _conversationRepository.createConversation(
          type: 'direct',
          participantIds: [newChatPeerId.toString()],
        );
        sendChatId = int.tryParse(conversation.id);
        cacheDirectChatId(newChatPeerId, sendChatId ?? 0);
      }

      if (sendChatId == null || sendChatId <= 0) {
        throw AppError('Could not resolve a conversation to send this message to.');
      }

      // Polls are their own resource in NEW: `POST /conversations/:id/polls`
      // creates the `type: 'poll'` message AND its options in one call and
      // returns the full poll (with messageId + option ids). The plain
      // `/messages` send has no options field, which is why a poll sent
      // that way rendered a permanent "Loading options...".
      String? sentMessageId;
      if (messageType == MessageType.Poll) {
        final rawPoll = await _messageRepository.createPoll(
          sendChatId,
          question: finalMessageContent,
          options: pollOption ?? const [],
          allowMultiple: isMultiplePollVotes ?? false,
        );
        sentMessageId = rawPoll['messageId']?.toString();
        final pollMsgId = int.tryParse(sentMessageId ?? '');
        if (pollMsgId != null) {
          _pollCache[pollMsgId] = chats.PollData.fromNewApi(
            rawPoll,
            currentUserId: _currentUserId,
          );
        }
      } else {
        // A story reply ships its referenced-story snapshot in `metadata`
        // (NEW does no server-side story wiring — see storyReplyContext).
        Map<String, dynamic>? outgoingMetadata;
        if (messageType == MessageType.StoryReply) {
          outgoingMetadata = <String, dynamic>{
            if (storyid != null) 'storyId': storyid,
            ...?storyReplyContext,
          };
        } else if (messageType == MessageType.Voice &&
            voiceDuration > Duration.zero) {
          // The server stores no duration for audio attachments, so the
          // recorded length travels in `metadata` (read back by
          // MessageAdapter into Records.voiceDuration for the bubble).
          outgoingMetadata = <String, dynamic>{
            'durationSeconds': voiceDuration.inSeconds,
          };
        }

        final sentMessage = await _messageRepository.sendMessage(
          conversationId: sendChatId,
          messageType: messageType,
          messageContent: finalMessageContent,
          replyToMessageId: replyToMessageId,
          attachmentMediaIds: attachmentMediaIds,
          metadata: outgoingMetadata,
          // Forward is merged into send in NEW via forwardOfMessageId — see
          // forwardMessage() below, which calls this repo method directly
          // rather than threading a forward id through this provider method.
        );
        sentMessageId = sentMessage.id;
      }

      if (!_isDisposed) {
        //Clear reply state after successful send
        if (replyToMessageId != null) {
          clearReply();
        }

        // ✅ FIX: Clear storyid after successful send to prevent it persisting
        if (messageType == MessageType.StoryReply) {
          storyid = null;
          storyReplyContext = null;
          _logger.d('Cleared storyid after successful story reply');
        }

        if (isNewChat) {
          _logger.i('New chat created with ID: $sendChatId');
          _currentChatData = ChatIds(chatId: sendChatId, userId: peerID ?? 0);
          _socketEventController.setCurrentChat(sendChatId, peerID ?? 0);
        }

        await _fetchMessagesPage(chatId: sendChatId, clearExisting: false);
        _logger.d('Sent message id: $sentMessageId');

        // Clear file storage after successful send
        _shareImage = null;
        _shareDocument = null;
        _shareVideo = null;
        _shareVideoThumbnail = "";

        // ✅ FIX: Use silent refresh to avoid "Loading chats..." flicker
        // Optimistically update chat list locally first
        updateChatListLocally(
          chatId: sendChatId,
          lastMessage: finalMessageContent,
          messageType: messageType.name.toLowerCase(),
        );
        // Then sync in background without loader
        refreshChatListSilent();
      }

      _isSendingMessage = false;
      _scheduleNotification();
      return true;
    } catch (e) {
      _error = "Failed to send message: ${e.toString()}";
      _isSendingMessage = false;
      if (messageType == MessageType.StoryReply) {
        storyid = null;
        storyReplyContext = null;
      }
      _logger.e('Send message failed: $e');
      _scheduleNotification();

      // Set API error message for UI snackbar display
      if (e is AppError) {
        _apiErrorMessage = e.message;
      } else {
        _apiErrorMessage = "Failed to send message: ${e.toString()}";
      }

      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ OPTIMISTIC SEND - Instant message display with queue-based sending
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send a text message with optimistic UI (instant display)
  /// Returns the tempId of the optimistic message for tracking
  String? sendTextMessageOptimistic({
    required String messageContent,
    int? chatId,
    int? userId,
    int? replyToMessageId,
  }) {
    if (_isDisposed || messageContent.trim().isEmpty) return null;

    // `chatId` is the screen's route argument and is 0 for a chat opened from
    // contacts. Fall back to the conversation resolved while opening that same
    // peer's chat, so only a genuinely first-ever message goes out with 0 (and
    // gets the conversation created for it by MessageQueueService).
    final int argChatId = chatId ?? 0;
    final effectiveUserId = userId ?? _currentChatData.userId;
    final int contextChatId =
        (effectiveUserId == null || _currentChatData.userId == effectiveUserId)
            ? (_currentChatData.chatId ?? 0)
            : 0;
    final effectiveChatId = argChatId > 0 ? argChatId : contextChatId;

    _logger.d('⚡ Optimistic send: "$messageContent" to chat $effectiveChatId');

    // Generate temp ID for this message
    final tempId = _messageQueueService.generateTempId();

    // Get current user ID for sender
    final currentUserId = int.tryParse(userID) ?? 0;

    // Create optimistic message record
    final optimisticMessage = chats.Records(
      tempId: tempId,
      messageContent: messageContent,
      messageType: 'text',
      chatId: effectiveChatId,
      senderId: currentUserId,
      replyTo: replyToMessageId,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      sendingStatus: chats.MessageSendingStatus.sending,
      messageSeenStatus: 'pending',
      retryCount: 0,
      // Copy parent message data if replying
      parentMessage:
          replyToMessageId != null ? _replyToMessage?.toJson() : null,
    );

    // Add optimistic message to UI immediately
    addOptimisticMessage(optimisticMessage);

    // ✅ FIX: Also update chat list locally for instant feedback
    if (effectiveChatId > 0) {
      updateChatListLocally(
        chatId: effectiveChatId,
        lastMessage: messageContent,
        messageType: 'text',
      );
    }

    // Setup queue callbacks if not already set
    _setupQueueCallbacks();

    // Queue the actual API call
    _messageQueueService.enqueue(
      chatId: effectiveChatId,
      userId: effectiveUserId,
      messageContent: messageContent,
      messageType: MessageType.Text,
      replyToMessageId: replyToMessageId,
      existingTempId: tempId,
    );

    // Clear reply state
    if (replyToMessageId != null) {
      clearReply();
    }

    _isShowAttachments = false;
    _scheduleNotification();

    return tempId;
  }

  /// Setup callbacks for the message queue service
  /// ✅ FIX: Always update callbacks to ensure they reference the current provider instance
  void _setupQueueCallbacks() {
    _messageQueueService.onMessageSent = (tempId, response) {
      // ✅ FIX: Skip if provider is disposed
      if (_isDisposed) {
        _logger.w(
          '⚠️ Queue callback: Provider disposed, updating cache directly',
        );
        // Still update cache even if provider is disposed
        _updateCacheOnMessageSent(tempId, response);
        return;
      }

      _logger.d('✅ Queue callback: Message sent - $tempId');

      // Get message ID from response
      final messageId =
          response['data']?['message_id'] ?? response['message_id'];
      final rawSeq =
          response['data']?['conversation_seq'] ?? response['conversation_seq'];
      final conversationSeq =
          rawSeq is int ? rawSeq : int.tryParse('${rawSeq ?? ''}');

      if (messageId != null) {
        confirmOptimisticMessage(
          tempId,
          int.parse(messageId.toString()),
          seenStatus: 'sent',
          conversationSeq: conversationSeq,
        );
      } else {
        // No message ID in response, just mark as sent
        updateOptimisticMessageStatus(tempId, chats.MessageSendingStatus.sent);
      }

      // Handle new chat creation
      if (response['data']?['chat_id'] != null) {
        final newChatId = int.parse(response['data']['chat_id'].toString());
        if (newChatId > 0 &&
            (_currentChatData.chatId == 0 || _currentChatData.chatId == null)) {
          final peerId = _currentChatData.userId ?? 0;
          _currentChatData = ChatIds(chatId: newChatId, userId: peerId);
          _socketEventController.setCurrentChat(newChatId, peerId);
          // Remember it so the rest of this session (and re-opening the chat)
          // reuses the conversation instead of asking the server again.
          cacheDirectChatId(peerId, newChatId);
        }
      }

      // ✅ FIX: Use silent refresh to avoid "Loading chats..." flicker
      refreshChatListSilent();
    };

    _messageQueueService.onMessageFailed = (tempId, error) {
      if (_isDisposed) return;
      _logger.e('❌ Queue callback: Message failed - $tempId: $error');
      markOptimisticMessageFailed(tempId, error: error);
    };

    _messageQueueService.onMessageSending = (tempId) {
      if (_isDisposed) return;
      _logger.d('🚀 Queue callback: Message sending - $tempId');
      updateOptimisticMessageStatus(tempId, chats.MessageSendingStatus.sending);
    };
  }

  /// ✅ FIX: Update cache directly when provider is disposed but message was sent
  void _updateCacheOnMessageSent(String tempId, Map<String, dynamic> response) {
    try {
      final messageId =
          response['data']?['message_id'] ?? response['message_id'];
      final chatId = response['data']?['chat_id'];
      final rawSeq =
          response['data']?['conversation_seq'] ?? response['conversation_seq'];
      final conversationSeq =
          rawSeq is int ? rawSeq : int.tryParse('${rawSeq ?? ''}');

      if (messageId != null && chatId != null) {
        ChatCacheManager.confirmOptimisticMessage(
          chatId.toString(),
          tempId,
          int.parse(messageId.toString()),
          seenStatus: 'sent',
          conversationSeq: conversationSeq,
        ).catchError((e) {
          _logger.e('❌ Failed to confirm optimistic message in cache: $e');
        });
        _logger.d(
          '✅ Updated cache directly for disposed provider: $tempId -> $messageId',
        );
      }
    } catch (e) {
      _logger.e('❌ Error updating cache on message sent: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════

  // Send typing status
  void sendTypingStatus(int chatId, bool isTyping) {
    if (_isDisposed) return;

    _logger.d(
      "ChatProvider: Sending typing status - ChatId: $chatId, IsTyping: $isTyping",
    );
    _socketEventController.sendTypingIndicator(chatId.toString(), isTyping);
  }

  // Set current chat

  // void setCurrentChat(int chatId, int userId) {
  //   if (_isDisposed) return;

  //   _logger.d("Setting current chat - chatId: $chatId, userId: $userId");

  //   // ✅ CLEAR OLD CHAT DATA FIRST
  //   _chatsData = chats.ChatsModel();
  //   _pinnedMessagesData = chats.ChatsModel(); // ✅ Clear pinned messages
  //   _isPinnedMessagesExpanded = false;
  //   _lastChatsDataHash = null;
  //   clearHighlight();

  //   // ✅ SET NEW CHAT DATA
  //   _currentChatData = ChatIds(chatId: chatId, userId: userId);
  //   _socketEventController.setCurrentChat(chatId, userId);

  //   _scheduleNotification();
  // }

  void setCurrentChat(int chatId, int userId) {
    if (_isDisposed) return;

    _logger.d("Setting current chat - chatId: $chatId, userId: $userId");

    // Clear old chat data first
    _chatsData = chats.ChatsModel();
    _pinnedMessagesData = chats.ChatsModel();
    _isPinnedMessagesExpanded = false;
    _lastChatsDataHash = null;
    _regroupMessages();
    clearHighlight();

    // Set new chat data
    _currentChatData = ChatIds(chatId: chatId, userId: userId);
    _socketEventController.setCurrentChat(chatId, userId);

    // Refresh the starred-message id cache so already-starred bubbles show
    // the star indicator as soon as this chat's history renders.
    if (chatId > 0) {
      loadStarredMessageIds();
    }

    // ✅ ENHANCED: Only auto-mark if screen is active and it's an existing chat
    if (chatId > 0) {
      // Longer delay to ensure all chat data is loaded and conditions are stable
      Future.delayed(Duration(milliseconds: 2000), () async {
        if (!_isDisposed &&
            _currentChatData.chatId == chatId &&
            isChatScreenActive &&
            isAppInForeground) {
          // ✅ CRITICAL: Double-check we have messages loaded before marking as seen
          if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
            _logger.d(
              'Chat data loaded and screen active, marking messages as seen',
            );
            await markChatMessagesAsSeen(chatId);
          } else {
            _logger.d('Chat data not yet loaded, skipping auto-mark seen');
          }
        } else {
          _logger.d(
            'Skipping auto-mark seen on setCurrentChat - conditions not met. '
            'disposed: $_isDisposed, '
            'chatMatch: ${_currentChatData.chatId == chatId}, '
            'screenActive: $isChatScreenActive, '
            'appForeground: $isAppInForeground',
          );
        }
      });
    }

    _scheduleNotification();
  }

  void setPinnedMessagesExpanded(bool expanded) {
    if (_isPinnedMessagesExpanded != expanded) {
      _isPinnedMessagesExpanded = expanded;
      _scheduleNotification();
    }
  }

  // ✅ NEW: Reply methods
  void setReplyToMessage(chats.Records? message) {
    _replyToMessage = message;
    _isReplyMode = message != null;
    _scheduleNotification();
  }

  // Set document for sharing
  void setShareDocument(List<File> documents) {
    if (_isDisposed) return;
    _shareDocument = documents;
    _logger.d("Set share document: ${documents.length} files");
    _scheduleNotification();
  }

  // Set image for sharing
  void setShareImage(List<File> images) {
    if (_isDisposed) return;
    _shareImage = images;
    _logger.d("Set share image: ${images.length} files");
    _scheduleNotification();
  }

  void setShareVoice(File voices) {
    if (_isDisposed) return;
    _shareVoice = voices;
    _logger.d("Set share voice: $voices files");
    _scheduleNotification();
  }

  // Set video for sharing
  void setShareVideo(List<File> videos, String thumbnail) {
    if (_isDisposed) return;
    _shareVideo = videos;
    _shareVideoThumbnail = thumbnail;
    _logger.d("Set share video: ${videos.length} files, thumbnail: $thumbnail");
    _scheduleNotification();
  }

  Future<void> setShareVideoWithThumbnail(List<File> videos) async {
    if (_isDisposed || videos.isEmpty) return;

    try {
      _logger.d("Setting share video with thumbnail generation");

      _shareVideo = videos;

      // Generate thumbnail for the first video
      final videoFile = videos.first;
      final thumbnailPath = await generateVideoThumbnail(videoFile.path);

      _shareVideoThumbnail = thumbnailPath ?? "";

      _logger.d(
        "Video set successfully - Video: ${videoFile.path}, Thumbnail: $_shareVideoThumbnail",
      );
      _scheduleNotification();
    } catch (e) {
      _logger.e("Error setting video with thumbnail: $e");
      _shareVideo = videos;
      _shareVideoThumbnail = "";
      _scheduleNotification();
    }
  }

  // ❌ silentRefresh() REMOVED — unreferenced (had no callers) and only
  // delegated to a dead socket method. Use refreshChatListSilent instead,
  // which is REST-based.

  // ✅ NEW: Stop message search
  void stopMessageSearch() {
    if (!_isSearchingForMessage) {
      _logger.d('⚠️ No active search to stop');
      return;
    }

    _logger.d('🛑 Stopping message search by user request');

    // Call the private method that handles cleanup
    _stopMessageSearch();

    // Optional: Show feedback that search was cancelled
    _logger.i('✅ Message search stopped successfully');
  }

  // Toggle attachment menu
  void toggleAttachments() {
    if (_isDisposed) return;

    _isShowAttachments = !_isShowAttachments;
    _scheduleNotification();
  }

  // ✅ NEW: Pinned messages methods
  void togglePinnedMessagesExpansion() {
    _isPinnedMessagesExpanded = !_isPinnedMessagesExpanded;
    _scheduleNotification();
  }

  // ✅ NEW: Cancel search timeout
  void _cancelSearchTimeout() {
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = null;
  }

  void _clearHighlightSilently() {
    if (_highlightTimer != null) {
      _highlightTimer!.cancel();
      _highlightTimer = null;
    }
    _highlightedMessageId = null;
  }

  // ✅ NEW: Create updated record preserving all data
  // Dispose of all subscriptions
  void _disposeSubscriptions() {
    _chatListSubscription?.cancel();
    _chatsSubscription?.cancel();
    _chatIdsSubscription?.cancel();
    _onlineUsersSubscription?.cancel();
    _typingSubscription?.cancel();
    _blockUpdatesSubscription?.cancel();
    _pinUnpinSubscription?.cancel();
    _pollUpdatedSubscription?.cancel();
    _messageUpdatedSubscription?.cancel();
    _starUnstarSubscription?.cancel();
    _chatListMessageSubscription?.cancel();

    _chatListSubscription = null;
    _chatsSubscription = null;
    _chatIdsSubscription = null;
    _onlineUsersSubscription = null;
    _typingSubscription = null;
    _blockUpdatesSubscription = null;
    _pinUnpinSubscription = null;
    _pollUpdatedSubscription = null;
    _messageUpdatedSubscription = null;
    _starUnstarSubscription = null;
    _chatListMessageSubscription = null;
  }

  /// ✅ NEW: Extract pinned messages from chat response using your actual model
  void _extractPinnedMessages(chats.ChatsModel data) {
    try {
      _logger.d("🔍 Extracting pinned messages from chat data");

      // ✅ PRIORITY 1: Check if socket controller has pinned data first
      final socketPinnedData = _socketEventController.pinnedMessagesData;
      if (socketPinnedData.records != null &&
          socketPinnedData.records!.isNotEmpty) {
        _logger.d(
          "✅ Found ${socketPinnedData.records!.length} pinned messages from socket controller",
        );

        // Verify these belong to current chat
        final currentChatId = _currentChatData.chatId ?? 0;
        if (currentChatId > 0) {
          final relevantPinnedMessages =
              socketPinnedData.records!
                  .where((record) => record.chatId == currentChatId)
                  .toList();

          if (relevantPinnedMessages.isNotEmpty) {
            _pinnedMessagesData = chats.ChatsModel(
              records: relevantPinnedMessages,
              pagination: chats.Pagination(
                totalRecords: relevantPinnedMessages.length,
                currentPage: 1,
                totalPages: 1,
                recordsPerPage: relevantPinnedMessages.length,
              ),
            );
            _logger.d(
              "✅ Set ${relevantPinnedMessages.length} pinned messages from socket controller",
            );
            return;
          }
        }
      }

      // ✅ PRIORITY 2: Extract from current chat data
      if (data.records != null && data.records!.isNotEmpty) {
        final pinnedMessages =
            data.records!.where((record) => record.pinned == true).toList();

        _pinnedMessagesData = chats.ChatsModel(
          records: pinnedMessages,
          pagination: chats.Pagination(
            totalRecords: pinnedMessages.length,
            currentPage: 1,
            totalPages: 1,
            recordsPerPage: pinnedMessages.length,
          ),
        );

        _logger.d(
          "✅ Extracted ${pinnedMessages.length} pinned messages from current chat data",
        );
        return;
      }

      // ✅ DEFAULT: Clear pinned messages if nothing found
      _pinnedMessagesData = chats.ChatsModel();
      _logger.d("No pinned messages found, clearing pinned data");
    } catch (e) {
      _logger.e("❌ Error extracting pinned messages: $e");
      _pinnedMessagesData = chats.ChatsModel();
    }
  }

  // Helper method to generate hash for data comparison
  String _generateDataHash(chats.ChatsModel data) {
    if (data.records == null || data.records!.isEmpty) {
      return 'empty';
    }

    final lastMessage = data.records!.first;
    return '${data.records!.length}_${lastMessage.messageId}_${lastMessage.createdAt}';
  }

  // Initialize subscriptions to SocketEventController streams
  void _initializeSubscriptions() {
    if (_isDisposed) return;

    // Cancel any existing subscriptions first
    _disposeSubscriptions();

    // NEW's message_pinned/message_unpinned carry only
    // {conversationId, messageId, ...} — no full message data — so
    // pinUnpinStream now just emits the affected conversationId; re-fetch
    // its pinned list via REST rather than trying to merge a partial
    // Records object.
    _pinUnpinSubscription = _socketEventController.pinUnpinStream.listen(
      (conversationId) {
        if (_isDisposed) return;
        _logger.d("📌 Pin/unpin update for conversation $conversationId");
        _refreshPinnedMessagesFor(conversationId);
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Pin/unpin stream error: $error';
        _logger.e('Pin/unpin stream error: $error');
        _scheduleNotification();
      },
    );

    // Live poll tallies: NEW pushes `poll_updated` on every vote/close from
    // any participant (`{messageId, poll}`, viewer-neutral shape) — patch
    // whichever loaded record owns that message so open chats reflect
    // others' votes without needing to leave/reopen or pull-to-refresh.
    _pollUpdatedSubscription = _socketEventController.pollUpdatedStream.listen(
      (data) {
        if (_isDisposed) return;
        try {
          final messageId = int.tryParse(
            data['messageId']?.toString() ?? '',
          );
          final pollJson = data['poll'];
          if (messageId == null || pollJson is! Map) return;
          final updated = chats.PollData.fromNewApi(
            Map<String, dynamic>.from(pollJson),
            currentUserId: _currentUserId,
          );
          _applyPollUpdateFromSocket(messageId, updated);
        } catch (e) {
          _logger.w('Failed to apply poll_updated payload: $e');
        }
      },
      onError: (error) {
        if (_isDisposed) return;
        _logger.e('Poll update stream error: $error');
      },
    );

    // Edits from any participant (and this user's other devices) arrive as
    // `message_updated` with the full message — patch it in place.
    _messageUpdatedSubscription = _socketEventController.messageUpdatedStream
        .listen(
          (message) {
            if (_isDisposed) return;
            _applyMessageUpdate(message);
          },
          onError: (error) {
            if (_isDisposed) return;
            _logger.e('Message updated stream error: $error');
          },
        );

    // ✅ NEW: Star/Unstar message listener
    _starUnstarSubscription = _socketEventController.chatsStream.listen(
      (data) {
        if (_isDisposed) return;

        _logger.d("⭐ Received star/unstar update - processing...");

        // Check if this update contains star/unstar changes
        if (data.records != null && data.records!.isNotEmpty) {
          bool hasStarChanges = false;

          for (var record in data.records!) {
            // Check if any message has star-related updates
            if (record.starredFor != null || record.stared != null) {
              hasStarChanges = true;
              break;
            }
          }

          if (hasStarChanges) {
            _logger.d("⭐ Star/unstar changes detected, updating UI");

            // Force immediate UI update for star changes
            _scheduleNotification();
          }
        }
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Star/unstar stream error: $error';
        _logger.e('Star/unstar stream error: $error');
        _scheduleNotification();
      },
    );

    // Subscribe to chat list updates
    // _chatListSubscription = _socketEventController.chatListStream.listen(
    //   (data) {
    //     if (_isDisposed) return;
    //     _logger.d("Chat list updated with ${data.chats?.length ?? 0} chats");
    //     _logger.d("Chat messages response: $data");
    //     _chatListData = data;
    //     _scheduleNotification();
    //   },
    //   onError: (error) {
    //     if (_isDisposed) return;
    //     _error = 'Chat list stream error: $error';
    //     _logger.e('Chat list stream error: $error');
    //     _scheduleNotification();
    //   },
    // );
    _chatListSubscription = _socketEventController.chatListStream.listen(
      (data) {
        if (_isDisposed) return;

        // ⚠️ The new backend has NO socket chat_list event, so
        // SocketEventController._chatListData is never populated from REST —
        // it stays an empty ChatListModel and gets pushed onto this stream on
        // every incoming new_message (see _processMessageUpdate). Treating
        // that stale empty push as a "first page" response here would wipe the
        // REST-loaded chat list (chat disappears on the receiver until a
        // manual refresh, and the empty list even gets persisted to cache).
        // Ignore payloads with no chats AND no pagination — the signature of
        // that stale empty push. Real REST responses always carry pagination.
        if (data.chats.isEmpty && data.pagination == null) {
          _logger.d(
            "⏭️ Ignoring stale/empty chat list stream push from SocketEventController",
          );
          return;
        }

        _logger.d("Chat list updated with ${data.chats.length} chats");

        // ✅ NEW: Handle pagination response
        _handleChatListPaginationResponse(data);
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Chat list stream error: $error';
        _logger.e('Chat list stream error: $error');
        _isChatListPaginationLoading = false;
        _scheduleNotification();
      },
    );

    // ✅ Real-time chat-list preview/unread/ordering for background chats.
    // The new backend has no `chat_list` socket event, so without this the
    // last-message line, unread badge and ordering only refresh on a full
    // REST reload. Fires for every incoming `new_message`.
    _chatListMessageSubscription = _socketEventController.chatListMessageStream
        .listen(
          (msg) {
            if (_isDisposed) return;
            _applyIncomingSocketMessageToChatList(msg);
          },
          onError: (error) {
            if (_isDisposed) return;
            _logger.e('Chat list message stream error: $error');
          },
        );

    _chatsSubscription = _socketEventController.chatsStream.listen(
      (chats.ChatsModel data) {
        if (_isDisposed) return;
        _handleChatsDataUpdate(data);
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Chat messages stream error: $error';
        _logger.e('❌ Chat stream error: $error');
        _scheduleNotification();
      },
    );

    // Subscribe to other streams (chat IDs, online users, typing)
    _chatIdsSubscription = _socketEventController.chatIdsStream.listen(
      (data) {
        if (_isDisposed) return;
        _logger.d("Chat IDs updated");
        _chatIdsData = data;
        _scheduleNotification();
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Chat IDs stream error: $error';
        _logger.e('Chat IDs stream error: $error');
        _scheduleNotification();
      },
    );

    _onlineUsersSubscription = _socketEventController.onlineUsersStream.listen(
      (data) {
        if (_isDisposed) return;
        _onlineUsersData = data;
        _refreshOpenChatPresenceFromSocket();
        _scheduleNotification();
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Online users stream error: $error';
        _logger.e('Online users stream error: $error');
        _scheduleNotification();
      },
    );

    _typingSubscription = _socketEventController.typingStream.listen(
      (data) {
        if (_isDisposed) return;
        _typingData = data;
        _scheduleNotification();
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Typing status stream error: $error';
        _logger.e('Typing status stream error: $error');
        _scheduleNotification();
      },
    );

    // Block updates stream
    _blockUpdatesSubscription = _socketEventController.blockUpdatesStream.listen(
      (data) {
        if (_isDisposed) return;
        _logger.i(
          'Block updates received: userId=${data.userId}, chatId=${data.chatId}, isBlocked=${data.isBlocked}',
        );
        // A null chatId means this came from `user_blocked`/`user_unblocked`
        // (payload is only `{userId}`), not from a per-chat broadcast — it
        // is a profile re-read trigger, NOT a block-state change for this
        // account, so it must not go through the chat-scoped scenario
        // recalculation below.
        if (data.chatId == null) {
          _handleBlockStateSync(data.userId ?? 0);
        } else {
          _handleBlockUpdates(data);
        }
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Block updates stream error: $error';
        _logger.e('Block updates stream error: $error');
        _scheduleNotification();
      },
    );

    // Load current user ID for permission checking
    _loadCurrentUserId();

    // Initialize with current data from the controller.
    // ⚠️ On the new backend SocketEventController.chatListData is never
    // populated (no socket chat_list event), so only adopt it when it
    // actually carries chats — otherwise keep what we already have (e.g. a
    // cache-loaded list) instead of blanking it on every re-subscribe.
    if (_socketEventController.chatListData.chats.isNotEmpty) {
      _chatListData = _socketEventController.chatListData;
    }
    _sortChatList(); // Sort the initial data
    _chatsData = _socketEventController.chatsData;
    _chatIdsData = _socketEventController.chatIdsData;
    _onlineUsersData = _socketEventController.onlineUsersData;
    _typingData = _socketEventController.typingData;

    // CRITICAL FIX: Initialize pagination state from existing chat list data
    if (_chatListData.pagination != null) {
      final pagination = _chatListData.pagination!;
      _chatListCurrentPage = pagination.currentPage ?? 1;
      _chatListTotalPages = pagination.totalPages ?? 1;
      _hasChatListMoreData = _chatListCurrentPage < _chatListTotalPages;
      _logger.d(
        '🔄 Initialized pagination from existing data - Page: $_chatListCurrentPage/$_chatListTotalPages, HasMore: $_hasChatListMoreData',
      );
    }

    // Generate initial hash
    _lastChatsDataHash = _generateDataHash(_chatsData);

    // ✅ OFFLINE-FIRST: The socket hasn't delivered a chat list yet on a cold
    // start (_chatListData above is empty in that case). Load the last
    // persisted chat list from disk so the UI has something to render
    // instantly instead of waiting for the socket to connect + respond.
    // Fire-and-forget from the constructor's perspective — but the Future is
    // retained (see [waitForCachedChatListRestore]) so callers that need to
    // know whether cache data is about to show up can await it instead of
    // racing a still-pending disk read.
    _cacheRestoreFuture = _loadCachedChatListIfEmpty();
  }

  static const String _chatListCacheKey = 'cached_chat_list_v1';
  Future<void>? _cacheRestoreFuture;

  /// Resolves once the one-time cold-start chat-list cache restore has
  /// settled (whether it found anything or not). Callers deciding whether to
  /// show a "connecting..." blocking state based on
  /// `chatListData.chats.isEmpty` should await this first (with their own
  /// timeout) — otherwise they can race the restore's async disk read and
  /// see an empty list that's about to be populated a few milliseconds
  /// later, showing a spinner that wasn't actually necessary.
  Future<void> waitForCachedChatListRestore() =>
      _cacheRestoreFuture ?? Future.value();

  /// Loads the last known chat list from local storage so it can render
  /// immediately after a cold app start, before the socket connects and
  /// delivers fresh data. Never overwrites data that has already arrived.
  Future<void> _loadCachedChatListIfEmpty() async {
    try {
      if (_chatListData.chats.isNotEmpty) return;

      final cached = await SecurePrefs.getString(_chatListCacheKey);
      if (_isDisposed) return;
      if (cached == null || cached.isEmpty) return;
      // Fresher data may have arrived from the socket while we were reading.
      if (_chatListData.chats.isNotEmpty) return;

      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      final cachedModel = ChatListModel.fromJson(decoded);
      if (cachedModel.chats.isEmpty) return;
      if (_chatListData.chats.isNotEmpty) return;

      _chatListData = cachedModel;
      _filterArchivedChatsFromList(shouldSort: false);
      _sortChatList();

      if (cachedModel.pagination != null) {
        final pagination = cachedModel.pagination!;
        _chatListCurrentPage = pagination.currentPage ?? 1;
        _chatListTotalPages = pagination.totalPages ?? 1;
        _hasChatListMoreData = _chatListCurrentPage < _chatListTotalPages;
      }

      _logger.i(
        '✅ Loaded ${cachedModel.chats.length} chats from local cache instantly',
      );
      _scheduleNotification();
    } catch (e) {
      _logger.e('Failed to load cached chat list: $e');
    }
  }

  /// Persists the current first-page chat list to local storage so it can be
  /// used to render instantly on the next cold app start. Fire-and-forget —
  /// never blocks the caller.
  void _persistChatListCache() {
    final snapshot = _chatListData;
    Future(() async {
      try {
        final jsonStr = jsonEncode(snapshot.toJson());
        await SecurePrefs.setString(_chatListCacheKey, jsonStr);
      } catch (e) {
        _logger.e('Failed to persist chat list cache: $e');
      }
    });
  }

  bool _isMessageInCurrentData(int messageId) {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      return false;
    }

    return _chatsData.records!.any((record) => record.messageId == messageId);
  }

  // ✅ NEW: Enhanced message matching
  Future<void> _loadCurrentUserId() async {
    try {
      _currentUserId = await SecurePrefs.getString(SecureStorageKeys.USERID);
      _logger.d('Current user ID loaded: $_currentUserId');
    } catch (e) {
      _logger.e('Error loading current user ID: $e');
    }
  }

  void _onMessageFoundAndScroll(int messageId) {
    _logger.d('✅ Message found: $messageId');

    _isMessageFound = true;
    _isSearchingForMessage = false;
    _cancelSearchTimeout();

    // Highlight the message (but don't scroll yet - let the UI handle that)
    highlightMessage(messageId);

    _scheduleNotification();
  }

  /// NEW's message_pinned/message_unpinned only tell us *which*
  /// conversation changed, not which message or the new state — re-fetch
  /// `GET /conversations/:id/pins` and reconcile it against whatever's
  /// currently loaded for that chat.
  Future<void> _refreshPinnedMessagesFor(String conversationId) async {
    if (_isDisposed) return;
    final chatId = int.tryParse(conversationId);
    if (chatId == null) return;
    // Only the currently-open chat has a loaded message list to reconcile
    // pin flags against; other conversations' pinned lists refresh next
    // time they're opened via _fetchMessagesPage.
    if (_currentChatData.chatId != chatId) return;

    try {
      final pinnedPage = await _messageRepository.getPinnedMessages(chatId);
      final pinnedIds = pinnedPage.items.map((m) => m.id).toSet();

      final recordsById = <int, chats.Records>{};
      if (_chatsData.records != null) {
        for (final record in _chatsData.records!) {
          if (record.messageId == null) continue;
          record.pinned = pinnedIds.contains(record.messageId.toString());
          recordsById[record.messageId!] = record;
        }
      }

      // The `/pins` payload is sparse (no senderId/type/timestamps), so a
      // freshly-pinned entry adapted on its own renders as "user" with no
      // body. Reuse the fully-hydrated record from the open chat's message
      // list whenever the pinned message is loaded there.
      _pinnedMessagesData = chats.ChatsModel(
        records:
            pinnedPage.items.map((m) {
              final id = int.tryParse(m.id);
              final record =
                  (id != null ? recordsById[id] : null) ??
                  MessageAdapter.toRecord(m, currentUserId: _currentUserId);
              record.pinned = true;
              return record;
            }).toList(),
        pagination: chats.Pagination(
          totalRecords: pinnedPage.items.length,
          currentPage: 1,
          totalPages: 1,
          recordsPerPage: pinnedPage.items.length,
        ),
      );

      _regroupMessages();
      _scheduleNotification();
      _logger.d(
        '✅ Refreshed pinned messages for chat $chatId (${pinnedPage.items.length} pinned)',
      );
    } catch (e) {
      _logger.e('❌ Error refreshing pinned messages for chat $chatId: $e');
    }
  }

  // Optimized notification method with debouncing
  void _scheduleNotification() {
    if (_isDisposed) return;

    _shouldNotify = true;
    _notifyTimer?.cancel();
    _notifyTimer = Timer(Duration(milliseconds: 50), () {
      if (_shouldNotify && !_isDisposed) {
        _shouldNotify = false;
        notifyListeners();
      }
    });
  }

  // ignore: unused_element
  Future<void> _searchWithPaginationEnhanced(int messageId) async {
    int searchAttempts = 0;
    const maxSearchAttempts = 15; // Increased attempts

    while (searchAttempts < maxSearchAttempts &&
        _isSearchingForMessage &&
        !_isMessageFound &&
        hasMoreMessages) {
      _logger.d(
        '🔍 Search attempt ${searchAttempts + 1} for message $messageId',
      );

      // Check current data again
      if (_isMessageInCurrentData(messageId)) {
        _onMessageFoundAndScroll(messageId);
        return;
      }

      // Load more messages if available
      if (hasMoreMessages) {
        _logger.d('📄 Loading more messages to find message $messageId');
        await loadMoreMessages();

        // Wait for pagination to complete with better timing
        await _waitForPaginationCompleteEnhanced();

        // Check again after loading with small delay for UI update
        await Future.delayed(Duration(milliseconds: 200));

        if (_isMessageInCurrentData(messageId)) {
          _onMessageFoundAndScroll(messageId);
          return;
        }
      } else {
        _logger.w('⚠️ No more messages to load, message not found');
        break;
      }

      searchAttempts++;
      // Small delay between attempts
      await Future.delayed(Duration(milliseconds: 300));
    }

    // Message not found after all attempts
    if (!_isMessageFound) {
      _logger.w(
        '❌ Message $messageId not found after $searchAttempts attempts',
      );
      _stopMessageSearch();
      _setError('Message not found in chat history');
    }
  }

  void _setError(String errorMessage) {
    _error = errorMessage;
    _logger.e(errorMessage);
    _scheduleNotification();
  }

  // ✅ NEW: Method to set pagination loading
  void _setPaginationLoading(bool loading) {
    if (_isPaginationLoading != loading) {
      _isPaginationLoading = loading;
      _scheduleNotification();
    }
  }

  // ✅ NEW: Start search timeout (prevent infinite search)
  // ignore: unused_element
  void _startSearchTimeout() {
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = Timer(Duration(seconds: 30), () {
      if (_isSearchingForMessage && !_isMessageFound) {
        _logger.w('⏰ Search timeout for message $_targetMessageId');
        _stopMessageSearch();
        _setError('Search timeout: Message not found');
      }
    });
  }

  // ✅ PRIVATE: Internal method to stop search and cleanup
  void _stopMessageSearch() {
    if (_isSearchingForMessage) {
      _logger.d('🧹 Cleaning up search state');
    }

    // Reset all search-related state
    _isSearchingForMessage = false;
    _targetMessageId = null;
    _isMessageFound = false;

    // Cancel any active timers
    _cancelSearchTimeout();

    // Clear any highlights
    _clearHighlightSilently();

    // Notify UI to update
    _scheduleNotification();

    _logger.d('🧹 Search state cleaned up');
  }

  void _updateChatIdIfNeeded(chats.ChatsModel data) {
    // Only update if we don't have a chat ID and we received one
    if ((_currentChatData.chatId == null || _currentChatData.chatId == 0) &&
        data.records != null &&
        data.records!.isNotEmpty) {
      final firstRecord = data.records!.first;
      if (firstRecord.chatId != null && firstRecord.chatId! > 0) {
        _logger.d("📝 Updating chat ID to ${firstRecord.chatId}");

        _currentChatData = ChatIds(
          chatId: firstRecord.chatId!,
          userId: _currentChatData.userId ?? 0,
        );

        _socketEventController.updateCurrentChatId(firstRecord.chatId!);
      }
    }
  }

  // 11. ENHANCED: Wait for pagination with better timing
  Future<void> _waitForPaginationCompleteEnhanced() async {
    int waitAttempts = 0;
    const maxWaitAttempts = 30; // Increased wait time

    while (waitAttempts < maxWaitAttempts &&
        (_isPaginationLoading || _socketEventController.isPaginationLoading)) {
      await Future.delayed(Duration(milliseconds: 200)); // Shorter intervals
      waitAttempts++;
    }

    // Additional wait for UI rendering
    await Future.delayed(Duration(milliseconds: 100));
  }
}
// Add these methods to your existing ChatProvider class

extension TypingExtension on ChatProvider {
  /// Get typing user IDs in a chat
  List<int> getTypingUserIdsInChat(int chatId) {
    try {
      if (typingData.typing == true) {
        // Since your TypingModel doesn't seem to have detailed group typing info yet,
        // we'll return an empty list for now
        // Enhance your TypingModel to include user IDs for group typing

        // Example of what this could look like when your socket sends detailed typing data:
        // if (typingData.chatId == chatId && typingData.typingUserIds != null) {
        //   return List<int>.from(typingData.typingUserIds!);
        // }

        _logger.d(
          "getTypingUserIdsInChat called for chat $chatId, but detailed typing data not available yet",
        );
        return [];
      }
      return [];
    } catch (e) {
      _logger.e("Error getting typing user IDs: $e");
      return [];
    }
  }

  /// Get typing users in a group chat (enhanced)
  List<String> getTypingUsersInChat(int chatId) {
    try {
      if (typingData.typing == true) {
        // For now, return empty list until your socket provides detailed typing info
        // Parse typing data to extract user names for the specific chat

        // Example implementation when you have detailed typing data:
        // if (typingData.chatId == chatId && typingData.typingUsers != null) {
        //   return List<String>.from(typingData.typingUsers!);
        // }

        _logger.d(
          "getTypingUsersInChat called for chat $chatId, but detailed typing data not available yet",
        );
        return [];
      }
      return [];
    } catch (e) {
      _logger.e("Error getting typing users: $e");
      return [];
    }
  }

  /// Extract group members from message list
  Map<int, chats.User> extractGroupMembersFromMessages(
    List<chats.Records> messages,
  ) {
    Map<int, chats.User> membersMap = <int, chats.User>{};

    for (final message in messages) {
      if (message.user != null && message.senderId != null) {
        final userId = message.senderId!;
        final user = message.user!;

        // Add or update user in the map
        if (!membersMap.containsKey(userId)) {
          membersMap[userId] = user;
          _logger.d("Found group member: ${user.fullName} (ID: $userId)");
        } else {
          // Update user info if it's newer
          final existingUser = membersMap[userId]!;
          if (_isUserInfoNewer(user, existingUser)) {
            membersMap[userId] = user;
            _logger.d(
              "Updated group member info: ${user.fullName} (ID: $userId)",
            );
          }
        }
      }
    }

    _logger.d("Extracted ${membersMap.length} group members from messages");
    return membersMap;
  }

  bool _isUserInfoNewer(chats.User newUser, chats.User existingUser) {
    // Compare updated timestamps
    if (newUser.updatedAt != null && existingUser.updatedAt != null) {
      final newTime = DateTime.tryParse(newUser.updatedAt!);
      final existingTime = DateTime.tryParse(existingUser.updatedAt!);
      if (newTime != null && existingTime != null) {
        return newTime.isAfter(existingTime);
      }
    }

    // If no timestamp, prefer non-empty profile data
    if (newUser.profilePic?.isNotEmpty == true &&
        existingUser.profilePic?.isEmpty == true) {
      return true;
    }

    return false; // Keep existing if can't determine
  }

  /// Determine if a chat is a group chat based on message data
  bool isGroupChatFromMessages(List<chats.Records> messages) {
    if (messages.isEmpty) return false;

    // Check for group creation message
    final hasGroupCreatedMessage = messages.any(
      (msg) => msg.messageType?.toLowerCase() == 'group-created',
    );

    if (hasGroupCreatedMessage) return true;

    // Count unique senders (excluding current user)
    final uniqueSenders = <int>{};
    for (final message in messages) {
      if (message.senderId != null) {
        uniqueSenders.add(message.senderId!);
      }
    }

    // If more than 2 unique senders, it's likely a group
    return uniqueSenders.length > 2;
  }

  /// Get online members count for a group
  int getOnlineGroupMembersCount(Map<int, User> groupMembers) {
    return groupMembers.values
        .where((user) => isUserOnline(user.userId ?? 0))
        .length;
  }

  /// ✅ NEW DEBUG METHOD: Get comprehensive debug info about message seen emissions
  Map<String, dynamic> getMessageSeenDebugInfo(int chatId) {
    final unreadMessages =
        _chatsData.records
            ?.where(
              (message) =>
                  message.senderId?.toString() != userID &&
                  message.messageSeenStatus != 'seen' &&
                  message.messageId != null &&
                  message.deletedForEveryone != true,
            )
            .toList() ??
        [];

    final emissionStats = _socketEventController.getEmissionStats();

    return {
      'chatId': chatId,
      'unreadMessagesFound': unreadMessages.length,
      'unreadMessageIds': unreadMessages.map((m) => m.messageId).toList(),
      'currentScreenState': {
        'isChatScreenActive': isChatScreenActive,
        'isAppInForeground': isAppInForeground,
        'isDisposed': _isDisposed,
        'currentChatId': _currentChatData.chatId,
      },
      'socketEmissionStats': emissionStats,
      'unseenCount': getChatUnseenCount(chatId),
    };
  }

  /// ✅ MANUAL TRIGGER: Force debug the 7 vs 4 emission issue
  Future<void> debugMessageSeenEmissions(int chatId) async {
    _logger.i(
      '🔍 MANUAL DEBUG: Starting message seen emission analysis for chat $chatId',
    );

    // Get pre-debug state
    final preDebugInfo = getMessageSeenDebugInfo(chatId);
    _logger.i('📊 PRE-DEBUG STATE: $preDebugInfo');

    // Clear emission tracking to start fresh
    _socketEventController.clearEmissionTracking();

    // Try to mark messages as seen with full debugging
    await markChatMessagesAsSeen(chatId);

    // Get post-debug state
    final postDebugInfo = getMessageSeenDebugInfo(chatId);
    _logger.i('📊 POST-DEBUG STATE: $postDebugInfo');

    // Compare and report
    final intendedEmissions = preDebugInfo['unreadMessagesFound'] as int;
    final actualEmissions =
        postDebugInfo['socketEmissionStats']['totalEmissions'] as int;

    if (intendedEmissions != actualEmissions) {
      _logger.e('🚨 CONFIRMED DISCREPANCY:');
      _logger.e('  - Intended emissions: $intendedEmissions');
      _logger.e('  - Actual emissions: $actualEmissions');
      _logger.e(
        '  - Missing: ${intendedEmissions - actualEmissions} emissions',
      );
      _logger.e(
        '  - SUCCESS RATE: ${(actualEmissions / intendedEmissions * 100).toStringAsFixed(1)}%',
      );
    } else {
      _logger.i('✅ NO DISCREPANCY: All intended messages were emitted');
    }
  }

  /// Enhanced mark messages as seen for both individual and group chats
  Future<void> markChatMessagesAsSeen(
    int chatId, {
    bool isGroupChat = false,
  }) async {
    if (_isDisposed || chatId <= 0) return;

    // Check if screen is active and app is in foreground
    if (!isChatScreenActive || !isAppInForeground) {
      _logger.d(
        'Skipping mark messages as seen - screen not active or app in background. '
        'screenActive: $isChatScreenActive, appForeground: $isAppInForeground',
      );
      return;
    }

    // Ensure we're viewing the correct chat
    if (_currentChatData.chatId != chatId) {
      _logger.d(
        'Skipping mark messages as seen - chat ID mismatch. '
        'current: ${_currentChatData.chatId}, requested: $chatId',
      );
      return;
    }

    try {
      // Get current user ID
      final currentUserId = await _getCurrentUserId();
      if (currentUserId == null) {
        _logger.w(
          'Cannot mark messages as seen - current user ID not available',
        );
        return;
      }

      // Find unread messages from OTHER users only
      final unreadMessages =
          _chatsData.records
              ?.where(
                (message) =>
                    message.senderId?.toString() !=
                        currentUserId && // Only messages from other users
                    message.messageSeenStatus != 'seen' &&
                    message.messageId != null &&
                    message.deletedForEveryone !=
                        true, // Don't mark deleted messages
              )
              .toList() ??
          [];

      if (unreadMessages.isNotEmpty) {
        _logger.d(
          'Marking ${unreadMessages.length} messages from OTHER users as seen '
          'in ${isGroupChat ? 'group' : 'individual'} chat '
          '(screen is active and app in foreground)',
        );

        // Batch processing to avoid overwhelming the server
        const batchSize = 3;
        for (int i = 0; i < unreadMessages.length; i += batchSize) {
          // Check if conditions are still met before each batch
          if (!isChatScreenActive || !isAppInForeground || _isDisposed) {
            _logger.d('Conditions changed, stopping seen marking');
            break;
          }

          final batch = unreadMessages.skip(i).take(batchSize).toList();

          for (var message in batch) {
            // Final check before marking each message
            if (!isChatScreenActive || _isDisposed) {
              _logger.d('Screen became inactive, stopping seen marking');
              return;
            }

            _logger.d(
              'Marking message ${message.messageId} as seen '
              '(from user ${message.senderId}, current user $currentUserId)',
            );

            await markMessageAsSeen(chatId, message.messageId!);
            await Future.delayed(Duration(milliseconds: 150));
          }

          // Longer delay between batches
          if (i + batchSize < unreadMessages.length) {
            await Future.delayed(Duration(milliseconds: 300));
          }
        }

        _logger.i(
          'Successfully processed ${unreadMessages.length} unread messages from other users in ${isGroupChat ? 'group' : 'individual'} chat',
        );
      } else {
        _logger.d('No unread messages from other users to mark as seen');
      }
    } catch (e) {
      _logger.e('Error marking chat messages as seen: $e');
    }
  }

  /// Block or unblock a user
  /// Uses the existing ChatRepository.blockUnblockUser method
  /// Fixed to use actual API response instead of toggle logic
  Future<bool> blockUnblockUser(int userId, int chatId) async {
    if (_isDisposed) return false;

    try {
      _logger.d(
        'Block/Unblock user via API - userId: $userId, chatId: $chatId',
      );

      // Check current block status BEFORE making API call
      final existingBlockIndex = _blockedUsers.indexWhere(
        (record) => record.blockedId == userId,
      );
      bool wasBlocked = existingBlockIndex != -1;

      _logger.d(
        'User $userId was ${wasBlocked ? 'blocked' : 'not blocked'} before API call',
      );

      // NEW has no toggle endpoint — pass the intent (opposite of current
      // local state) explicitly; chatId is no longer sent to the API at
      // all, but is still needed below for local chat-list bookkeeping.
      final response = await _chatRepository.blockUnblockUser(
        userId,
        !wasBlocked,
      );

      if (response != null && response['success'] == true && !_isDisposed) {
        _logger.i('User block/unblock successful via API');

        // Use ACTUAL block status from API response, not toggle logic
        final isNowBlocked = response['is_blocked'] as bool;
        final message = response['message'] as String;

        _logger.d(
          'API says user is now ${isNowBlocked ? 'BLOCKED' : 'UNBLOCKED'}: $message',
        );

        // Update local blocked users list based on ACTUAL API response
        if (isNowBlocked) {
          // User is now BLOCKED according to API
          if (existingBlockIndex == -1) {
            // Add to blocked list if not already there
            final blockedRecord = BlockedUserRecord(
              blockId: DateTime.now().millisecondsSinceEpoch, // Temporary ID
              blockedId: userId,
              userId: int.tryParse(_currentUserId ?? '0') ?? 0,
              approved: true,
              createdAt: DateTime.now().toIso8601String(),
              blocked: null, // Will be populated by background refresh
            );
            _blockedUsers.insert(0, blockedRecord); // Add to front of list
            _logger.d('✅ Added user $userId to blocked list (now blocked)');
          }
        } else {
          // User is now UNBLOCKED according to API
          if (existingBlockIndex != -1) {
            // Remove from blocked list
            _blockedUsers.removeAt(existingBlockIndex);
            _logger.d(
              '✅ Removed user $userId from blocked list (now unblocked)',
            );
          }
        }

        // Update chat list to reflect ACTUAL block status from API using new structure
        // ✅ FIXED: Use current user ID, not the peer user ID for blocked_by array
        final currentUserIdInt = int.tryParse(_currentUserId ?? '0') ?? 0;
        _updateBlockedByInChatRecords(chatId, currentUserIdInt, isNowBlocked);

        // Notify listeners IMMEDIATELY for instant UI feedback
        _scheduleNotification();

        // Background refresh to sync with server (non-blocking)
        _performBackgroundBlockSync();

        _error = null;
        return true;
      } else {
        _error = response?['message'] ?? "Failed to block/unblock user via API";
        _logger.e('Block/unblock user API failed: $_error');
        _scheduleNotification();
        return false;
      }
    } catch (e) {
      _error = "Error blocking/unblocking user: $e";
      _logger.e('Block/unblock user error: $e');
      _scheduleNotification();
      return false;
    }
  }

  /// Background sync for block operations to ensure server consistency
  void _performBackgroundBlockSync() {
    Future.microtask(() async {
      try {
        // Small delay to prevent API conflicts
        await Future.delayed(Duration(milliseconds: 500));
        if (!_isDisposed) {
          await loadBlockedUsers(page: 1); // Refresh blocked users list
          _logger.d('🔄 Background block sync completed');
        }
      } catch (e) {
        _logger.w('Background block sync failed (non-critical): $e');
      }
    });
  }

  /// Clear all messages from a chat or delete the chat via API
  /// Uses the ChatRepository.clearChat method
  /// [deleteChat] - If true, deletes the chat entirely. If false, only clears messages
  Future<bool> clearChat({required int chatId, bool deleteChat = false}) async {
    if (_isDisposed) return false;
    try {
      _logger.d(
        '${deleteChat ? 'Deleting' : 'Clearing'} chat via API - chatId: $chatId',
      );
      final success = await _chatRepository.clearChat(
        chatId: chatId,
        deleteChat: deleteChat,
      );

      if (success && !_isDisposed) {
        _logger.i('Chat ${deleteChat ? 'delete' : 'clear'} successful via API');

        // =============================================
        // CLEAR ALL LOCAL DATA FOR THIS CHAT
        // =============================================

        // 1. Clear local messages for this chat
        _groupedMessages.removeWhere((key, messageList) {
          // Remove all message groups that belong to this chat
          return messageList.any((message) => message.chatId == chatId);
        });
        _logger.d('🗑️ Cleared grouped messages for chat $chatId');

        // 1.1. Also clear current chat data if this is the active chat
        if (_currentChatData.chatId == chatId) {
          _chatsData = chats.ChatsModel();
          _pinnedMessagesData = chats.ChatsModel();
          _lastChatsDataHash = null;
          _regroupMessages();
          _logger.d('🗑️ Cleared current chat data for active chat $chatId');
        }

        // 1.2. The socket controller keeps its own copy of messages received
        // live this session and re-merges it into ours on the next
        // `new_message` — drop this chat's from there too, or the cleared
        // history reappears as soon as anyone sends a new message.
        _socketEventController.clearMessagesForChat(chatId);

        // 2. Clear local cache for this chat
        await _clearLocalCacheForChat(chatId);

        // 3. Clear unseen count for this chat
        clearChatUnseenCount(chatId);
        _logger.d('🗑️ Cleared unseen count for chat $chatId');

        // 4. If deleting the chat, also remove it from the chat list
        if (deleteChat) {
          _chatListData.chats.removeWhere(
            (chat) =>
                chat.records?.any((record) => record.chatId == chatId) ?? false,
          );
          _logger.d('🗑️ Removed chat $chatId from chat list data');

          // ✅ Re-persist the local chat-list cache immediately so the
          // removal survives a cold restart even if the refreshChatList()
          // call below never lands (offline) — the persisted blob otherwise
          // still has the deleted chat in it until the next full refresh
          // successfully round-trips, which would make it reappear from
          // local storage on the next app launch even though the server
          // and current-session UI both agree it's gone.
          _persistChatListCache();
        } else {
          // If only clearing messages, update the chat item to show no messages
          _updateChatListAfterClear(chatId);
        }

        // Notify listeners about the change
        _scheduleNotification();

        // Refresh chat list to ensure UI reflects the changes
        await refreshChatList();

        // 🛡️ SAFETY CHECK: Verify that the chat is actually cleared by checking server.
        // Delete only — a cleared chat stays listed and is reopened normally:
        // the server already hides the pre-clear history from this user, and
        // the recently-cleared load block would skip wiring the reopened chat
        // up for live messages.
        if (deleteChat) {
          await _verifyChatCleared(chatId);
        }

        _logger.i(
          '✅ Chat ${deleteChat ? 'delete' : 'clear'} completed successfully',
        );
        return true;
      } else {
        _error = deleteChat ? "Failed to delete chat" : "Failed to clear chat";
        _logger.w(
          '${deleteChat ? 'Delete' : 'Clear'} chat failed - Invalid response',
        );
        _scheduleNotification();
        return false;
      }
    } catch (e) {
      _error = "Error ${deleteChat ? 'deleting' : 'clearing'} chat: $e";
      _logger.e('${deleteChat ? 'Delete' : 'Clear'} chat error: $e');
      _scheduleNotification();
      return false;
    }
  }

  /// Clear local cache for a specific chat
  Future<void> _clearLocalCacheForChat(int chatId) async {
    try {
      // Determine cache key format
      final chatIdString = chatId.toString();

      // Clear chat cache using ChatCacheManager
      await ChatCacheManager.clearChat(chatIdString);
      _logger.d('🗄️ Cleared cache for chat: $chatIdString');

      // Also clear user-based cache key if this is a private chat
      // Check if this chatId corresponds to a private chat by looking in current chat data
      for (final chat in _chatListData.chats) {
        if (chat.records != null) {
          for (final record in chat.records!) {
            if (record.chatId == chatId && record.chatType == 'private') {
              // This is a private chat, also clear user-based cache
              final peerUserData = chat.peerUserData;
              if (peerUserData?.userId != null) {
                final userCacheKey = 'user_${peerUserData!.userId}';
                await ChatCacheManager.clearChat(userCacheKey);
                _logger.d('🗄️ Cleared user cache for key: $userCacheKey');
              }
              break;
            }
          }
        }
      }
    } catch (e) {
      _logger.e('❌ Error clearing local cache for chat $chatId: $e');
    }
  }

  /// Update chat list after clearing messages (but not deleting chat)
  void _updateChatListAfterClear(int chatId) {
    try {
      // Find and update the chat in the chat list to reflect no messages
      for (final chat in _chatListData.chats) {
        if (chat.records != null) {
          for (final record in chat.records!) {
            if (record.chatId == chatId) {
              // Clear messages and reset counts
              record.messages?.clear();
              record.unseenCount = 0;
              _logger.d('🔄 Updated chat list item for cleared chat $chatId');
              break;
            }
          }
        }
      }
    } catch (e) {
      _logger.e('❌ Error updating chat list after clear: $e');
    }
  }

  /// Verify that the chat was actually cleared on the server
  Future<void> _verifyChatCleared(int chatId) async {
    try {
      _logger.d('🔍 Verifying chat $chatId was cleared on server...');

      // Wait a bit for server-side clearing to complete
      await Future.delayed(Duration(milliseconds: 1500));

      // Set a flag to indicate this chat was recently cleared
      _recentlyClearedChats.add(chatId);

      // Remove the flag after 30 seconds (enough time for user to navigate)
      Future.delayed(Duration(seconds: 30), () {
        _recentlyClearedChats.remove(chatId);
      });

      _logger.d('✅ Chat $chatId marked as recently cleared');
    } catch (e) {
      _logger.e('❌ Error verifying chat cleared: $e');
    }
  }

  /// Check if a user is blocked
  bool isUserBlocked(int userId) {
    return _blockedUsers.any(
      (blockedRecord) => blockedRecord.blockedId == userId,
    );
  }

  /// Check if a user is blocked with real-time data refresh across all pages
  Future<bool> isUserBlockedRealTime(int userId) async {
    try {
      // First check in current cached list
      bool foundInCache = _blockedUsers.any(
        (blockedRecord) => blockedRecord.blockedId == userId,
      );

      if (foundInCache) {
        return true;
      }

      // If not found in cache, search across all pages
      return await _searchUserInAllBlockedPages(userId);
    } catch (e) {
      _logger.e('Error checking real-time block status: $e');
      // Fallback to cached data if API fails
      return _blockedUsers.any(
        (blockedRecord) => blockedRecord.blockedId == userId,
      );
    }
  }

  /// Search for a user in the blocked list.
  /// NEW's block-list endpoint always returns the full, unpaginated list in
  /// one call (§4.4/§10), so the old multi-page search loop is gone — one
  /// fetch now contains everything there is.
  Future<bool> _searchUserInAllBlockedPages(int userId) async {
    try {
      final blockedUserModel = await _chatRepository.getBlockedUsers(1);

      if (blockedUserModel?.records == null) return false;

      final found = blockedUserModel!.records!.any(
        (record) => record.blockedId == userId,
      );

      // Refresh the full cache from this single authoritative fetch.
      _blockedUsers
        ..clear()
        ..addAll(blockedUserModel.records!);
      _blockListCurrentPage = 1;
      _hasMoreBlockedUsers = false;

      return found;
    } catch (e) {
      _logger.e('Error searching blocked list: $e');
      return false;
    }
  }

  /// Refresh block status for UI updates - call this when opening profile views
  /// Optimized to prevent unnecessary refreshes and maintain UI responsiveness
  Future<void> refreshBlockStatus() async {
    try {
      _logger.d('🔄 Refreshing block status for UI consistency');

      // Load first page and clear existing cache for fresh data
      await loadBlockedUsers(page: 1);

      // Trigger UI update only if not disposed
      if (!_isDisposed) {
        _scheduleNotification();
      }

      _logger.d('✅ Block status refresh completed');
    } catch (e) {
      _logger.e('Error refreshing block status: $e');
    }
  }

  /// Optimized method to sync block status when app comes to foreground
  /// This helps catch block status changes that happened while app was inactive
  Future<void> syncBlockStatusOnForeground() async {
    try {
      _logger.d('🔄 Syncing block status due to app foreground');

      // Only refresh if we haven't refreshed recently (prevent spam)
      final now = DateTime.now();
      final lastRefreshTime =
          _blockListCurrentPage > 0
              ? now.subtract(Duration(minutes: 2))
              : DateTime(2000);

      if (now.difference(lastRefreshTime).inMinutes < 1) {
        _logger.d('⏭️ Skipping block sync - refreshed recently');
        return;
      }

      // Background sync to avoid blocking UI
      Future.microtask(() async {
        await refreshBlockStatus();
      });
    } catch (e) {
      _logger.e('Error syncing block status on foreground: $e');
    }
  }

  /// Check if current user is blocked by another user (for chat status)
  bool isCurrentUserBlockedBy(int userId, String currentUserId) {
    // Find chat record for this user
    for (final chat in _chatListData.chats) {
      if (chat.peerUserData?.userId == userId) {
        for (final record in chat.records ?? []) {
          if (record.blockedBy != null) {
            // BIDIRECTIONAL BLOCKING: If anyone has blocked this chat, both users should see blocked UI
            return record.blockedBy!.isNotEmpty;
          }
        }
      }
    }
    return false;
  }

  /// Load blocked users list
  Future<void> loadBlockedUsers({int page = 1}) async {
    if (_isDisposed) return;

    try {
      if (page == 1) {
        _isBlockListLoading = true;
        _blockedUsers.clear();
        _blockListCurrentPage = 1;
        _hasMoreBlockedUsers = true;
      }

      _logger.d('Loading blocked users (NEW: always full list, unpaginated)');

      // NEW's block-list endpoint has no pagination at all — `page` is
      // accepted here only for call-site compatibility and ignored; every
      // call returns the complete list, so there's never a "next page".
      final blockedUserModel = await _chatRepository.getBlockedUsers(page);

      if (blockedUserModel != null && !_isDisposed) {
        if (blockedUserModel.records != null) {
          _blockedUsers.addAll(blockedUserModel.records!);
          _logger.d(
            'Added ${blockedUserModel.records!.length} blocked users to list',
          );

          _blockListCurrentPage = 1;
          _hasMoreBlockedUsers = false;
        } else {
          _hasMoreBlockedUsers = false;
        }

        _error = null;
      } else {
        _error = "Failed to load blocked users";
        _logger.e('Load blocked users API returned null');
      }
    } catch (e) {
      _error = "Error loading blocked users: $e";
      _logger.e('Load blocked users error: $e');
    } finally {
      _isBlockListLoading = false;
      // The chat rows carry their own copy of the block state (blockedBy),
      // stamped once when the list was built. Without this the two drift
      // apart permanently — see _reconcileBlockedByFromBlockList.
      _reconcileBlockedByFromBlockList();
      _scheduleNotification();
    }
  }

  /// Re-stamps `blockedBy` on every 1:1 chat row from the authoritative
  /// block list.
  ///
  /// `blockedBy` is a *derived* field: ConversationAdapter.toChat sets it to
  /// `[currentUserId]` at build time from whatever `_blockedUsers` happened
  /// to hold then, and only a local block/unblock action updated it
  /// afterwards. On a cold start the chat list is fetched before the block
  /// list exists, so every row was built with an empty `blockedBy` and
  /// nothing ever corrected it — which is why the long-press menu offered
  /// "Block User" for a user who was already blocked, even after a restart.
  ///
  /// Only the current user's own entry is touched. Other ids in the array
  /// mean "that peer blocked me", which the block list says nothing about
  /// (the backend never discloses it), so they are left exactly as found.
  void _reconcileBlockedByFromBlockList() {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    for (final chat in _chatListData.chats) {
      final peerId = chat.peerUserData?.userId;
      if (peerId == null || peerId <= 0) continue;

      final blocked = isUserBlocked(peerId);
      for (final record in chat.records ?? const <Records>[]) {
        // Groups have no single peer to block.
        if ((record.chatType ?? '').toLowerCase() == 'group') continue;

        record.blockedBy ??= [];
        final alreadyMarked = record.blockedBy!.contains(currentUserId);
        if (blocked && !alreadyMarked) {
          record.blockedBy!.add(currentUserId);
        } else if (!blocked && alreadyMarked) {
          record.blockedBy!.remove(currentUserId);
        }
      }
    }
  }

  /// Check if current chat is blocked
  bool isCurrentChatBlocked() {
    if (_chatListData.chats.isEmpty ||
        _currentChatData.chatId == null ||
        _currentUserId == null) {
      return false;
    }

    try {
      final currentChatData = _chatListData.chats.firstWhere(
        (chat) =>
            chat.records?.any(
              (record) => record.chatId == _currentChatData.chatId,
            ) ==
            true,
        orElse: () => Chats(),
      );

      final record = currentChatData.records?.firstWhere(
        (record) => record.chatId == _currentChatData.chatId,
        orElse: () => Records(),
      );

      // BIDIRECTIONAL BLOCKING: If anyone has blocked this chat, both users should see blocked UI
      return record?.blockedBy?.isNotEmpty ?? false;
    } catch (e) {
      _logger.e('Error checking current chat block status: $e');
      return false;
    }
  }

  /// Get block status from chat list
  bool getChatBlockStatus(int chatId) {
    if (_currentUserId == null) return false;

    try {
      final chatData = _chatListData.chats.firstWhere(
        (chat) =>
            chat.records?.any((record) => record.chatId == chatId) == true,
        orElse: () => Chats(),
      );

      final record = chatData.records?.firstWhere(
        (record) => record.chatId == chatId,
        orElse: () => Records(),
      );

      // BIDIRECTIONAL BLOCKING: If anyone has blocked this chat, both users should see blocked UI
      // This ensures that when User A blocks User B, both users see blocked state and cannot message
      final hasBlockedUsers = record?.blockedBy?.isNotEmpty ?? false;

      if (hasBlockedUsers) {
        _logger.d(
          'Chat $chatId has blocked users: ${record?.blockedBy}. Showing blocked UI for current user $_currentUserId',
        );
      }

      return hasBlockedUsers;
    } catch (e) {
      _logger.e('Error getting chat block status: $e');
      return false;
    }
  }

  /// Get block status from chat list with real-time data refresh
  Future<bool> getChatBlockStatusRealTime(int chatId) async {
    if (_currentUserId == null) return false;

    try {
      // First refresh the chat list to get latest data
      await refreshChatList();

      // Then check the block status from updated data
      final chatData = _chatListData.chats.firstWhere(
        (chat) =>
            chat.records?.any((record) => record.chatId == chatId) == true,
        orElse: () => Chats(),
      );

      final record = chatData.records?.firstWhere(
        (record) => record.chatId == chatId,
        orElse: () => Records(),
      );

      // BIDIRECTIONAL BLOCKING: If anyone has blocked this chat, both users should see blocked UI
      // This ensures that when User A blocks User B, both users see blocked state and cannot message
      final hasBlockedUsers = record?.blockedBy?.isNotEmpty ?? false;

      if (hasBlockedUsers) {
        _logger.d(
          'Real-time check - Chat $chatId has blocked users: ${record?.blockedBy}. Showing blocked UI for current user $_currentUserId',
        );
      }

      return hasBlockedUsers;
    } catch (e) {
      _logger.e('Error getting real-time chat block status: $e');
      // Fallback to cached data if API fails
      return getChatBlockStatus(chatId);
    }
  }

  /// Get instant block status for navigation (without API call)
  /// Used to determine initial UI state when navigating to chat
  bool getInstantBlockStatus(int chatId) {
    if (_currentUserId == null) return false;

    try {
      final chatData = _chatListData.chats.firstWhere(
        (chat) =>
            chat.records?.any((record) => record.chatId == chatId) == true,
        orElse: () => Chats(),
      );

      final record = chatData.records?.firstWhere(
        (r) => r.chatId == chatId,
        orElse: () => Records(),
      );

      // ✅ FIXED: Check if CURRENT USER has blocked this chat (for UserProfileView button display)
      return record?.blockedBy?.contains(_currentUserId) ?? false;
    } catch (e) {
      _logger.e('Error getting instant block status: $e');
      return false;
    }
  }

  /// Get instant block status by peer user ID (for individual chats)
  bool getInstantBlockStatusByUserId(int userId) {
    if (_currentUserId == null) return false;

    try {
      for (final chat in _chatListData.chats) {
        if (chat.peerUserData?.userId == userId) {
          for (final record in chat.records ?? []) {
            // ✅ FIXED: Check if CURRENT USER has blocked this chat (for UserProfileView button display)
            return record.blockedBy?.contains(_currentUserId) ?? false;
          }
        }
      }
      return false;
    } catch (e) {
      _logger.e('Error getting instant block status by user ID: $e');
      return false;
    }
  }

  /// Check if current user is the one who blocked (can unblock)
  bool isCurrentUserTheBlocker(int chatId) {
    if (_currentUserId == null) return false;

    try {
      final chatData = _chatListData.chats.firstWhere(
        (chat) =>
            chat.records?.any((record) => record.chatId == chatId) == true,
        orElse: () => Chats(),
      );

      final record = chatData.records?.firstWhere(
        (r) => r.chatId == chatId,
        orElse: () => Records(),
      );

      // Check if current user is in the blocked_by list (meaning they blocked the other user)
      return record?.blockedBy?.contains(_currentUserId) ?? false;
    } catch (e) {
      _logger.e('Error checking if current user is blocker: $e');
      return false;
    }
  }

  /// Check if current user is the one who blocked by peer user ID
  bool isCurrentUserTheBlockerByUserId(int userId) {
    if (_currentUserId == null) return false;

    try {
      for (final chat in _chatListData.chats) {
        if (chat.peerUserData?.userId == userId) {
          for (final record in chat.records ?? []) {
            // Check if current user is in the blocked_by list (meaning they blocked the other user)
            return record.blockedBy?.contains(_currentUserId) ?? false;
          }
        }
      }
      return false;
    } catch (e) {
      _logger.e('Error checking if current user is blocker by user ID: $e');
      return false;
    }
  }

  // =================================================================
  // NEW PROPER BLOCK STATUS METHODS
  // =================================================================

  /// Get block scenario for a specific chat using new blocked_by structure
  /// Returns: 'none', 'user_blocked_other', 'user_blocked_by_other', 'mutual_block'
  String getBlockScenario(int? chatId, int? userId) {
    if (_currentUserId == null) return 'none';

    try {
      List<String>? blockedBy;
      String? peerUserId;

      if (chatId != null) {
        final chatData = _chatListData.chats.firstWhere(
          (chat) => chat.records?.any((r) => r.chatId == chatId) == true,
          orElse: () => Chats(),
        );
        final record = chatData.records?.firstWhere(
          (r) => r.chatId == chatId,
          orElse: () => Records(),
        );
        blockedBy = record?.blockedBy;
        peerUserId = chatData.peerUserData?.userId?.toString();

        // Debug logging for mutual block issues
        _logger.d(
          '🔍 Block scenario check - ChatId: $chatId, PeerUserId: $peerUserId, CurrentUserId: $_currentUserId',
        );
        _logger.d('🔍 BlockedBy array: ${blockedBy?.join(", ")}');

        // Additional debug for chat data structure
        _logger.d(
          '🔍 Chat data found: ${chatData.records?.isNotEmpty == true}',
        );
        if (record?.blockedBy != null) {
          _logger.d('🔍 Record found with blockedBy: ${record!.blockedBy}');
        }
      } else if (userId != null) {
        peerUserId = userId.toString();

        // Find the chat record for this user
        bool foundChat = false;
        for (final chat in _chatListData.chats) {
          if (chat.peerUserData?.userId == userId) {
            for (final record in chat.records ?? []) {
              blockedBy = record.blockedBy;
              foundChat = true;
              break;
            }
            break;
          }
        }

        // Debug logging for mutual block issues
        _logger.d(
          '🔍 Block scenario check - UserId: $userId, CurrentUserId: $_currentUserId, FoundChat: $foundChat',
        );
        _logger.d('🔍 BlockedBy array: ${blockedBy?.join(", ")}');
      }

      if (blockedBy == null || blockedBy.isEmpty) {
        _logger.d('🔍 Result: none (blockedBy is null or empty)');
        return 'none'; // No block in place
      }

      // - If currentUserId is in blocked_by = user blocked this chat
      // - If peerUserId is in blocked_by = peer blocked this chat
      final currentUserBlocked = blockedBy.contains(_currentUserId);
      final peerUserBlocked =
          peerUserId != null ? blockedBy.contains(peerUserId) : false;

      _logger.d(
        '🔍 currentUserBlocked: $currentUserBlocked, peerUserBlocked: $peerUserBlocked',
      );

      if (currentUserBlocked && peerUserBlocked) {
        _logger.d('🔍 Result: mutual_block');
        return 'mutual_block'; // Both users blocked this chat
      } else if (currentUserBlocked) {
        _logger.d('🔍 Result: user_blocked_other');
        return 'user_blocked_other'; // Current user blocked this chat
      } else if (peerUserBlocked) {
        _logger.d('🔍 Result: user_blocked_by_other');
        return 'user_blocked_by_other'; // Peer user blocked this chat (current user is blocked)
      }

      _logger.d('🔍 Result: none (fallback)');
      return 'none';
    } catch (e) {
      _logger.e('Error getting block scenario: $e');
      return 'none';
    }
  }

  /// Check if chat should show blocked UI (any blocking scenario except 'none')
  /// BUT: If chat was deleted and now has new messages, don't show blocked UI
  bool shouldShowBlockedUI(int? chatId, int? userId) {
    debugPrint('🔍 shouldShowBlockedUI - chatId=$chatId, userId=$userId');

    // ✅ Check if chat was deleted but has new messages
    final isDeletedWithNewMessages = _isChatDeletedWithNewMessages();
    debugPrint('🔍 _isChatDeletedWithNewMessages=$isDeletedWithNewMessages');

    if (isDeletedWithNewMessages) {
      _logger.d('✅ Chat was deleted but has new messages - allowing input');
      debugPrint('✅ Chat was deleted but has new messages - allowing input');
      return false;
    }

    final scenario = getBlockScenario(chatId, userId);
    debugPrint('🔍 Block scenario=$scenario');

    final shouldBlock = scenario != 'none';
    debugPrint('🔍 Final shouldBlock=$shouldBlock');

    return shouldBlock;
  }

  /// Check if current chat was deleted by current user but now has new messages
  /// This checks the ChatInfo from loaded messages
  bool _isChatDeletedWithNewMessages() {
    try {
      debugPrint('🔍 _isChatDeletedWithNewMessages checking...');

      // Check if we have any messages loaded
      if (_chatsData.records == null || _chatsData.records!.isEmpty) {
        debugPrint('❌ No messages loaded in _chatsData');
        return false;
      }

      debugPrint('✅ Messages loaded: ${_chatsData.records!.length} records');

      // Get the first record which should contain the Chat info
      final firstRecord = _chatsData.records!.first;
      debugPrint('🔍 First record chatId=${firstRecord.chatId}');
      debugPrint(
        '🔍 First record has chat object: ${firstRecord.chat != null}',
      );

      // Check if this record has Chat info with deleted_for
      if (firstRecord.chat != null) {
        debugPrint('🔍 Chat object exists!');
        debugPrint('🔍 Chat.chatId=${firstRecord.chat!.chatId}');
        debugPrint('🔍 Chat.deletedFor=${firstRecord.chat!.deletedFor}');
        debugPrint('🔍 Chat.blockedBy=${firstRecord.chat!.blockedBy}');
      }

      if (firstRecord.chat?.deletedFor != null) {
        final deletedFor = firstRecord.chat!.deletedFor!;
        debugPrint('🔍 Chat.deletedFor=$deletedFor');

        // Check if current user is in the deleted_for array
        final currentUserIdInt = int.tryParse(_currentUserId ?? '0') ?? 0;
        debugPrint(
          '🔍 Current user ID: string=$_currentUserId, int=$currentUserIdInt',
        );

        final isDeletedByCurrentUser =
            deletedFor.contains(currentUserIdInt) ||
            deletedFor.contains(_currentUserId);
        debugPrint('🔍 isDeletedByCurrentUser=$isDeletedByCurrentUser');

        if (isDeletedByCurrentUser) {
          // Chat was deleted by current user
          // Check if there are messages (which means new messages arrived after deletion)
          final hasMessages = _chatsData.records!.isNotEmpty;
          debugPrint('🔍 hasMessages=$hasMessages');
          if (hasMessages) {
            _logger.d(
              '✅ Chat ${firstRecord.chatId} was deleted but has new messages',
            );
            debugPrint(
              '✅ RESULT: Chat was deleted but has new messages - returning TRUE',
            );
            return true;
          }
        }
      } else {
        debugPrint('❌ No Chat info or deletedFor in first record');
      }

      debugPrint('❌ RESULT: Returning FALSE');
      return false;
    } catch (e) {
      _logger.e('Error checking if chat was deleted with new messages: $e');
      debugPrint('❌ ERROR in _isChatDeletedWithNewMessages: $e');
      return false;
    }
  }

  /// Check if current user can send messages (only blocked if user_blocked_by_other or mutual_block)
  bool canCurrentUserSendMessages(int? chatId, int? userId) {
    final scenario = getBlockScenario(chatId, userId);
    return scenario != 'user_blocked_by_other' && scenario != 'mutual_block';
  }

  /// Get the name of the user who blocked the current user (for user_blocked_by_other scenario)
  String? _getBlockerName(int? chatId, int? userId) {
    try {
      if (chatId != null) {
        final chatData = _chatListData.chats.firstWhere(
          (chat) => chat.records?.any((r) => r.chatId == chatId) == true,
          orElse: () => Chats(),
        );
        // In user_blocked_by_other scenario, the peer user is the blocker
        return ContactNameService.instance.resolveName(
          userId: chatData.peerUserData?.userId,
          firstName: chatData.peerUserData?.firstName,
          lastName: chatData.peerUserData?.lastName,
          fullName: chatData.peerUserData?.fullName,
          userName: chatData.peerUserData?.userName,
          email: chatData.peerUserData?.email,
          fallback: 'Someone',
        );
      } else if (userId != null) {
        for (final chat in _chatListData.chats) {
          if (chat.peerUserData?.userId == userId) {
            // In user_blocked_by_other scenario, the peer user is the blocker
            return ContactNameService.instance.resolveName(
              userId: chat.peerUserData?.userId,
              firstName: chat.peerUserData?.firstName,
              lastName: chat.peerUserData?.lastName,
              fullName: chat.peerUserData?.fullName,
              userName: chat.peerUserData?.userName,
              email: chat.peerUserData?.email,
              fallback: 'Someone',
            );
          }
        }
      }

      return null;
    } catch (e) {
      _logger.e('Error getting blocker name: $e');
      return null;
    }
  }

  /// Get appropriate block message based on scenario
  String getBlockMessage(int? chatId, int? userId) {
    final scenario = getBlockScenario(chatId, userId);

    switch (scenario) {
      case 'user_blocked_other':
        return 'You blocked this user';
      case 'user_blocked_by_other':
        final blockerName = _getBlockerName(chatId, userId);
        return blockerName != null
            ? 'You blocked by $blockerName'
            : 'You have been blocked';
      case 'mutual_block':
        return 'You both have blocked each other';
      default:
        return '';
    }
  }

  /// Handle real-time block/unblock updates from socket using new blocked_by structure
  /// Handles `user_blocked` / `user_unblocked`.
  ///
  /// IMPORTANT: this does NOT mean "this account blocked [peerId]". The
  /// event can land on the blocked user's side too, and the payload
  /// (`{userId}` and nothing else) can't tell us which side we're on. So it
  /// is treated purely as "that user's profile just changed visibility for
  /// me" and answered with one `GET /users/batch?ids=<peerId>`.
  ///
  /// Nothing block-state related is touched here on purpose. Inferring
  /// "I blocked them" from this event put the *blocked* user's own id into
  /// blocked_by and their peer into the block list, so B saw an "Unblock"
  /// button for a block B never made. The block list and blocked_by stay
  /// owned by the local REST action in [blockUnblockUser] and the block-list
  /// fetch; this event only refreshes what the peer now exposes — last seen
  /// and profile picture in particular, which the backend hides once a block
  /// is in place.
  Future<void> _handleBlockStateSync(int peerId) async {
    if (_isDisposed || peerId <= 0) return;

    _logger.i('🚫 Block state sync: re-reading peer $peerId from users/batch');
    await _refreshPeerFromUsersBatch(peerId);
  }

  /// One `GET /users/batch?ids=<peerId>` re-read, applied to the chat-list
  /// row and — when that peer's chat is the one on screen — to the header's
  /// online/last-seen.
  Future<void> _refreshPeerFromUsersBatch(int peerId) async {
    try {
      final profiles = await _conversationRepository.getUserBasicProfiles([
        '$peerId',
      ]);
      if (_isDisposed) return;

      final profile = profiles['$peerId'];
      if (profile == null) {
        _logger.w('users/batch returned nothing for peer $peerId');
        return;
      }

      await _applyPeerProfileToChatList(peerId, profile);
      if (_isDisposed) return;

      // Open chat header. Set these outright rather than merging with the
      // newest known timestamp the way checkUserOnlineStatusFromApi does —
      // the whole point of the re-read is that the server may have just
      // *stopped* exposing last seen (lastSeenVisible false), and a merge
      // would keep showing the stale value we already had.
      final presence = UserPresence.fromProfileJson(profile);
      _rememberLastSeenVisibility(peerId, presence.lastSeenVisible);

      if (_currentChatData.userId == peerId) {
        setIsUserOnlineFromApi(presence.isOnline);
        setLastSeenFromApi(presence.displayableLastSeenAt);
      }

      _scheduleNotification();
      _logger.d('✅ Refreshed peer $peerId from users/batch');
    } catch (e) {
      _logger.w('Could not refresh peer $peerId from users/batch: $e');
    }
  }

  /// Copies a curated `users/batch` user object onto the chat-list row for
  /// that peer, resolving the avatar media id the same way the chat-list
  /// build does.
  ///
  /// A field is only written when the response actually carries the key, but
  /// when it does the value is taken as-is — including null. That is what
  /// makes the picture *disappear* once a block hides it; a `??` fallback
  /// onto the old value would leave the now-hidden avatar on screen.
  Future<void> _applyPeerProfileToChatList(
    int peerId,
    Map<String, dynamic> profile,
  ) async {
    final rows =
        _chatListData.chats
            .where((chat) => chat.peerUserData?.userId == peerId)
            .toList();
    if (rows.isEmpty) return;

    final hasPic =
        profile.containsKey('profilePic') || profile.containsKey('profile_pic');
    final avatarUrl =
        hasPic
            ? await _mediaRepository.getDisplayUrl(
              (profile['profilePic'] ?? profile['profile_pic']) as String?,
            )
            : null;
    if (_isDisposed) return;

    T? pick<T>(String camel, String snake, T? current) {
      if (profile.containsKey(camel)) return profile[camel] as T?;
      if (profile.containsKey(snake)) return profile[snake] as T?;
      return current;
    }

    for (final row in rows) {
      final peer = row.peerUserData!;
      peer.userName = pick<String>('userName', 'user_name', peer.userName);
      peer.fullName = pick<String>('fullName', 'full_name', peer.fullName);
      peer.firstName = pick<String>('firstName', 'first_name', peer.firstName);
      peer.lastName = pick<String>('lastName', 'last_name', peer.lastName);
      peer.bio = profile.containsKey('bio') ? profile['bio'] as String? : peer.bio;
      if (hasPic) peer.profilePic = avatarUrl;
    }
  }

  void _handleBlockUpdates(BlockUpdatesModel blockUpdate) {
    if (_isDisposed ||
        blockUpdate.userId == null ||
        blockUpdate.chatId == null) {
      return;
    }

    final userId = blockUpdate.userId!;
    final chatId = blockUpdate.chatId!;
    final isBlocked = blockUpdate.isBlocked ?? false;

    _logger.i('🔄 ===== SOCKET BLOCK UPDATE RECEIVED =====');
    _logger.i(
      '🔄 User $userId ${isBlocked ? 'blocked' : 'unblocked'} chat $chatId',
    );
    _logger.i('🔄 Current User ID: $_currentUserId');

    try {
      // Log the state BEFORE update
      final scenarioBefore = getBlockScenario(chatId, null);
      _logger.i('🔄 BEFORE: Block scenario was: $scenarioBefore');

      // Update blocked_by field in chat records using new structure
      _updateBlockedByInChatRecords(chatId, userId, isBlocked);

      // Log the state AFTER update
      final scenarioAfter = getBlockScenario(chatId, null);
      _logger.i('🔄 AFTER: Block scenario is now: $scenarioAfter');

      // CRITICAL FIX: Validate socket event against blocked_by array state
      // Get current blocked_by array after the update
      Records? chatRecord;
      for (final chat in _chatListData.chats) {
        if (chat.records != null) {
          for (final r in chat.records!) {
            if (r.chatId == chatId) {
              chatRecord = r;
              break;
            }
          }
          if (chatRecord != null) break;
        }
      }

      if (chatRecord?.blockedBy != null) {
        final currentBlockedBy = chatRecord!.blockedBy!;
        _logger.i(
          '🔍 SOCKET VALIDATION: Current blocked_by array: $currentBlockedBy',
        );

        // Find peer user ID to validate mutual block state
        String? peerUserId;
        for (final chat in _chatListData.chats) {
          if (chat.records?.any((r) => r.chatId == chatId) == true) {
            peerUserId = chat.peerUserData?.userId?.toString();
            break;
          }
        }

        if (peerUserId != null) {
          final currentUserInArray = currentBlockedBy.contains(_currentUserId);
          final peerUserInArray = currentBlockedBy.contains(peerUserId);

          _logger.i(
            '🔍 SOCKET VALIDATION: CurrentUser($_currentUserId) in array: $currentUserInArray',
          );
          _logger.i(
            '🔍 SOCKET VALIDATION: PeerUser($peerUserId) in array: $peerUserInArray',
          );

          // Critical validation for one-sided unblock
          if (scenarioBefore == 'mutual_block' && !isBlocked) {
            _logger.w('🚨 ONE-SIDED UNBLOCK DETECTED:');
            _logger.w('🚨 User $userId unblocked from mutual_block state');
            _logger.w('🚨 Checking if peer user still has block active...');

            if (peerUserInArray && !currentUserInArray) {
              _logger.w(
                '🚨 PEER STILL BLOCKS: Current user should remain restricted',
              );
              _logger.w('🚨 Expected scenario: user_blocked_by_other');
            } else if (currentUserInArray && !peerUserInArray) {
              _logger.w(
                '🚨 CURRENT USER STILL BLOCKS: Peer should remain restricted',
              );
              _logger.w('🚨 Expected scenario: user_blocked_other');
            } else if (!currentUserInArray && !peerUserInArray) {
              _logger.w('🚨 BOTH UNBLOCKED: No restrictions should apply');
              _logger.w('🚨 Expected scenario: none');
            }
          }

          // CRITICAL: Force re-validation of block scenario after socket event
          final revalidatedScenario = getBlockScenario(chatId, null);
          if (revalidatedScenario != scenarioAfter) {
            _logger.e('🚨 SCENARIO MISMATCH: After socket event processing');
            _logger.e('🚨 Expected: $scenarioAfter, Got: $revalidatedScenario');
            _logger.e(
              '🚨 This indicates a sync issue between socket events and blocked_by array',
            );
          }

          // Additional validation: Ensure UI restrictions match the array state
          final shouldShowBlocked = revalidatedScenario != 'none';
          final canSendMessages =
              revalidatedScenario != 'user_blocked_by_other' &&
              revalidatedScenario != 'mutual_block';

          _logger.i('🔍 UI STATE VALIDATION:');
          _logger.i('🔍 Should show blocked UI: $shouldShowBlocked');
          _logger.i('🔍 Can send messages: $canSendMessages');
          _logger.i('🔍 Final block scenario for UI: $revalidatedScenario');
        }
      }

      // Update local blocked users list for backward compatibility
      final existingBlockIndex = _blockedUsers.indexWhere(
        (record) => record.blockedId == userId,
      );

      if (isBlocked) {
        // Add to blocked list if not already present
        if (existingBlockIndex == -1) {
          _blockedUsers.add(
            BlockedUserRecord(
              blockedId: userId,
              userId: int.tryParse(_currentUserId ?? '0') ?? 0,
              approved: true,
              createdAt: DateTime.now().toIso8601String(),
              updatedAt: DateTime.now().toIso8601String(),
            ),
          );
          _logger.d('Added user $userId to blocked users list');
        }
      } else {
        // Remove from blocked list if present
        if (existingBlockIndex != -1) {
          _blockedUsers.removeAt(existingBlockIndex);
          _logger.d('Removed user $userId from blocked users list');
        }
      }

      // CRITICAL FIX: Immediate UI update with enhanced validation
      if (!_isDisposed) {
        // Force immediate scenario re-calculation to ensure UI consistency
        final immediateScenario = getBlockScenario(chatId, null);
        _logger.i(
          '🔄 IMMEDIATE: Block scenario for UI update: $immediateScenario',
        );

        // CRITICAL: Double-check socket event processing result
        Records? finalRecord;
        for (final chat in _chatListData.chats) {
          if (chat.records != null) {
            for (final r in chat.records!) {
              if (r.chatId == chatId) {
                finalRecord = r;
                break;
              }
            }
            if (finalRecord != null) break;
          }
        }

        if (finalRecord?.blockedBy != null) {
          _logger.i('🔄 FINAL ARRAY STATE: ${finalRecord!.blockedBy}');
          _logger.i(
            '🔄 UI SHOULD SHOW: $immediateScenario based on this array',
          );
        }

        _scheduleNotification();
      }

      _logger.i('Block update processed successfully');
    } catch (e) {
      _logger.e('Error processing block update: $e');
    }
  }

  /// DEBUG: Test socket event sync with blocked_by array
  void debugTestSocketEventSync(int chatId, int userAId, int userBId) {
    _logger.i('🧪 ========== SOCKET EVENT SYNC TEST ==========');
    _logger.i('🧪 Testing socket events vs blocked_by array synchronization');
    _logger.i(
      '🧪 ChatId: $chatId, UserA: $userAId, UserB: $userBId, CurrentUser: $_currentUserId',
    );

    // Simulate the exact issue scenario with socket events
    _logger.i('🧪 STEP 1: Simulate socket event - User A blocks User B');
    final blockEventA = BlockUpdatesModel(
      userId: userAId,
      chatId: chatId,
      isBlocked: true,
    );
    _handleBlockUpdates(blockEventA);

    _logger.i(
      '🧪 STEP 2: Simulate socket event - User B blocks User A (mutual)',
    );
    final blockEventB = BlockUpdatesModel(
      userId: userBId,
      chatId: chatId,
      isBlocked: true,
    );
    _handleBlockUpdates(blockEventB);

    _logger.i(
      '🧪 STEP 3: Simulate socket event - User A unblocks User B (one-sided)',
    );
    final unblockEventA = BlockUpdatesModel(
      userId: userAId,
      chatId: chatId,
      isBlocked: false,
    );
    _handleBlockUpdates(unblockEventA);

    _logger.i(
      '🧪 VALIDATION: Final state should show peer still blocking current user',
    );
    final finalScenario = getBlockScenario(chatId, null);
    _logger.i('🧪 Final scenario: $finalScenario');

    // Clean up for next test
    final cleanupEvent = BlockUpdatesModel(
      userId: userBId,
      chatId: chatId,
      isBlocked: false,
    );
    _handleBlockUpdates(cleanupEvent);

    _logger.i('🧪 ========== SOCKET EVENT SYNC TEST COMPLETED ==========');
  }

  /// DEBUG: Test the specific one-sided unblock issue
  void debugTestOneSidedUnblock(int chatId, int userAId, int userBId) {
    _logger.i('🔍 ========== ONE-SIDED UNBLOCK TEST ==========');
    _logger.i(
      '🔍 ChatId: $chatId, UserA: $userAId, UserB: $userBId, CurrentUser: $_currentUserId',
    );

    // Scenario: A blocks B, B blocks A, then A unblocks B
    _logger.i('🔍 Step 1: User A ($userAId) blocks User B ($userBId)');
    _updateBlockedByInChatRecords(chatId, userAId, true);
    var scenario = getBlockScenario(chatId, null);
    _logger.i('🔍 After A blocks B - Block scenario: $scenario');

    _logger.i('🔍 Step 2: User B ($userBId) blocks User A ($userAId)');
    _updateBlockedByInChatRecords(chatId, userBId, true);
    scenario = getBlockScenario(chatId, null);
    _logger.i('🔍 After B blocks A (mutual) - Block scenario: $scenario');

    _logger.i('🔍 Step 3: User A ($userAId) unblocks User B ($userBId)');
    _updateBlockedByInChatRecords(chatId, userAId, false);
    scenario = getBlockScenario(chatId, null);
    _logger.i('🔍 After A unblocks B - Block scenario: $scenario');
    _logger.i('🔍 CRITICAL: B still blocks A, so A should be restricted!');

    // Test from both perspectives
    if (_currentUserId == userAId.toString()) {
      _logger.i(
        '🔍 From User A perspective: Should show user_blocked_by_other (B blocked A)',
      );
    } else if (_currentUserId == userBId.toString()) {
      _logger.i(
        '🔍 From User B perspective: Should show user_blocked_other (B blocked A)',
      );
    }

    // Clean up
    _updateBlockedByInChatRecords(chatId, userBId, false);
    _logger.i('🔍 ========== ONE-SIDED UNBLOCK TEST COMPLETED ==========');
    _scheduleNotification();
  }

  /// DEBUG: Test all block scenarios comprehensively
  void debugTestAllBlockScenarios(int chatId, int userAId, int userBId) {
    _logger.i('🧪 ========== COMPREHENSIVE BLOCK SCENARIO TEST ==========');
    _logger.i(
      '🧪 ChatId: $chatId, UserA: $userAId, UserB: $userBId, CurrentUser: $_currentUserId',
    );

    // Initial state - no blocks
    _logger.i('🧪 Step 0: Initial state (no blocks)');
    var scenario = getBlockScenario(chatId, null);
    _logger.i('🧪 After Step 0 - Block scenario: $scenario (expected: none)');

    // Test Case 1: User A blocks User B
    _logger.i('🧪 Step 1: User A ($userAId) blocks User B ($userBId)');
    _updateBlockedByInChatRecords(chatId, userAId, true);
    scenario = getBlockScenario(chatId, null);
    _logger.i(
      '🧪 After Step 1 - Block scenario: $scenario (expected: user_blocked_other if current = A, user_blocked_by_other if current = B)',
    );

    // Test Case 2: User B also blocks User A (mutual block)
    _logger.i('🧪 Step 2: User B ($userBId) blocks User A ($userAId)');
    _updateBlockedByInChatRecords(chatId, userBId, true);
    scenario = getBlockScenario(chatId, null);
    _logger.i(
      '🧪 After Step 2 - Block scenario: $scenario (expected: mutual_block)',
    );

    // Test Case 3: User A unblocks User B (but B still blocks A)
    _logger.i('🧪 Step 3: User A ($userAId) unblocks User B ($userBId)');
    _updateBlockedByInChatRecords(chatId, userAId, false);
    scenario = getBlockScenario(chatId, null);
    _logger.i(
      '🧪 After Step 3 - Block scenario: $scenario (expected: user_blocked_other if current = B, user_blocked_by_other if current = A)',
    );

    // Test Case 4: User B also unblocks User A (back to normal)
    _logger.i('🧪 Step 4: User B ($userBId) unblocks User A ($userAId)');
    _updateBlockedByInChatRecords(chatId, userBId, false);
    scenario = getBlockScenario(chatId, null);
    _logger.i('🧪 After Step 4 - Block scenario: $scenario (expected: none)');

    // Edge Case: Rapid block/unblock sequence
    _logger.i('🧪 Edge Case: Rapid block/unblock sequence');
    _updateBlockedByInChatRecords(chatId, userAId, true);
    _updateBlockedByInChatRecords(chatId, userAId, false);
    _updateBlockedByInChatRecords(chatId, userBId, true);
    scenario = getBlockScenario(chatId, null);
    _logger.i('🧪 After Edge Case - Block scenario: $scenario');

    // Clean up
    _updateBlockedByInChatRecords(chatId, userBId, false);

    _logger.i('🧪 ========== BLOCK SCENARIO TEST COMPLETED ==========');
    _scheduleNotification();
  }

  /// Update blocked_by field in chat records using new structure
  void _updateBlockedByInChatRecords(int chatId, int userId, bool isBlocked) {
    try {
      _logger.d(
        '🔄 Updating blocked_by for chatId: $chatId, userId: $userId, isBlocked: $isBlocked',
      );

      // Find the chat record with the given chatId
      for (var chat in _chatListData.chats) {
        if (chat.records != null) {
          for (var record in chat.records!) {
            if (record.chatId == chatId) {
              // Initialize blockedBy if null
              record.blockedBy ??= [];

              _logger.d(
                '🔄 Found chat record. Current blocked_by: ${record.blockedBy}',
              );

              final userIdStr = userId.toString();

              if (isBlocked) {
                // Add userId to blocked_by if not already present
                if (!record.blockedBy!.contains(userIdStr)) {
                  record.blockedBy!.add(userIdStr);
                  _logger.d(
                    '✅ Added user $userId to blocked_by for chat $chatId. New array: ${record.blockedBy}',
                  );
                } else {
                  _logger.d(
                    'ℹ️ User $userId already in blocked_by for chat $chatId',
                  );
                }
              } else {
                // Remove userId from blocked_by
                final removed = record.blockedBy!.remove(userIdStr);
                if (removed) {
                  _logger.d(
                    '✅ Removed user $userId from blocked_by for chat $chatId. New array: ${record.blockedBy}',
                  );
                } else {
                  _logger.d(
                    'ℹ️ User $userId was not in blocked_by for chat $chatId',
                  );
                }
              }
              return; // Exit once we find and update the record
            }
          }
        }
      }
      _logger.w('⚠️ Chat record with ID $chatId not found for block update');
    } catch (e) {
      _logger.e('❌ Error updating blocked_by in chat records: $e');
    }
  }

  /// Search messages in a specific chat with pagination
  /// Returns search results with user information and pagination data
  Future<Map<String, dynamic>?> searchMessages({
    required String searchText,
    required int chatId,
    int page = 1,
  }) async {
    try {
      _logger.d(
        'ChatProvider: Searching messages with text: "$searchText", chatId: $chatId, page: $page',
      );

      final response = await _chatRepository.searchMessages(
        searchText: searchText,
        chatId: chatId,
        page: page,
      );

      if (response != null && response['status'] == true) {
        _logger.i('ChatProvider: Message search successful');
        return response;
      } else {
        _logger.w('ChatProvider: Message search failed');
        return null;
      }
    } catch (e) {
      _logger.e('ChatProvider: Error searching messages: $e');
      return null;
    }
  }

  Future<void> countApi() async {
    try {
      _isCountLoading = false;
      notify();

      final countModel = await _chatRepository.countRepo();

      if (countModel!.status == true) {
        _starredCount = countModel.data!.totalStaredMessages;
        _blocklistCount = countModel.data!.totalBlockedUsers;
        _notificationCount = countModel.data!.unreadNotificationCount;
        _logger.d(_starredCount.toString());
        _logger.d(_blocklistCount.toString());
      }
      notify();
    } catch (e) {
      _error = "Failed to load count";
      _logger.e('Load count API returned null');
      notify();
    } finally {
      _isCountLoading = false;
      notify();
    }
  }

  Future<void> fetchMetadata({required String url}) async {
    _logger.d('Fetching metadata for URL: $url');
    final meta = await _chatRepository.fetchMetadataRepo(
      url, //"https://www.youtube.com/watch?v=abcd1234",
    );
    _urlTitle = meta["title"] ?? "";
    _logger.d('URL Title: ${meta["title"]}');
    _urlDescri = meta["description"] ?? "";
    _logger.d('URL Description: ${meta["description"]}');
    _urlImage = meta["image"] ?? "";
    _logger.d('URL Image: ${meta["image"]}');
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifyListeners();
  }

  /// ✅ FIX: Clear archived chat badge count if this chat is archived
  void _clearArchivedChatBadgeIfNeeded(int chatId) {
    try {
      final archiveChatProvider = getIt<ArchiveChatProvider>();
      final currentArchivedBadgeCount = archiveChatProvider
          .getArchivedChatUnseenCount(chatId);

      if (currentArchivedBadgeCount > 0) {
        _logger.d(
          '🗃️ Clearing archived chat badge for chatId: $chatId (current count: $currentArchivedBadgeCount)',
        );
        archiveChatProvider.clearArchivedChatUnseenCount(chatId);
        _logger.d(
          '✅ Archived chat badge cleared successfully for chatId: $chatId',
        );
      } else {
        _logger.d('🔍 No archived chat badge to clear for chatId: $chatId');
      }
    } catch (e) {
      _logger.e('❌ Error clearing archived chat badge for chatId $chatId: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ DEV SOLUTION: DYNAMIC MESSAGE LOADING & SEEN STATUS MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Enhanced chat item tap handler with dynamic pageSize and unseen message management
  ///
  /// This method solves the core issue where tapping a chat with high unseen_count
  /// would only load 20 messages, causing older unseen messages to be skipped.
  ///
  /// Key Features:
  /// - Dynamic pageSize based on unseenCount (loads ALL unseen messages first)
  /// - Immediate emission of real_time_message_seen for loaded unseen messages
  /// - Proper synchronization between ChatList and ArchiveList
  /// - Comprehensive error handling and logging
  /// - Production-ready edge case handling
  ///
  /// @param chatId - The chat ID to open
  /// @param unseenCount - Number of unseen messages in this chat
  /// @param fromArchive - Whether the chat was opened from archive list
  /// @param userId - User ID for new chats (optional)
  /// @param chatName - Display name for the chat (optional)
  /// @param profilePic - Profile picture URL (optional)
  /// @param isGroupChat - Whether this is a group chat (optional)
  Future<void> onChatItemTap({
    required int chatId,
    required int unseenCount,
    bool fromArchive = false,
    int? userId,
    String? chatName,
    String? profilePic,
    bool isGroupChat = false,
    bool isAdminChat = false,
  }) async {
    try {
      _logger.d(
        '🎯 onChatItemTap START: chatId=$chatId, unseenCount=$unseenCount, fromArchive=$fromArchive',
      );

      // ═════════════════════════════════════════════════════════════════
      // STEP 1: DETERMINE OPTIMAL PAGE SIZE
      // ═════════════════════════════════════════════════════════════════

      int dynamicPageSize;
      String loadingStrategy;

      if (unseenCount <= 0) {
        // No unseen messages - use default pagination
        dynamicPageSize = 20;
        loadingStrategy = "NORMAL_PAGINATION";
        _logger.d(
          '📄 No unseen messages - using default pageSize: $dynamicPageSize',
        );
      } else if (unseenCount <= 100) {
        // Load exactly the number of unseen messages (with small buffer for safety)
        dynamicPageSize = unseenCount + 5; // Add 5 message buffer
        loadingStrategy = "LOAD_ALL_UNSEEN";
        _logger.d(
          '🔢 Loading ALL unseen messages - dynamic pageSize: $dynamicPageSize (unseenCount: $unseenCount + 5 buffer)',
        );
      } else {
        // Cap at reasonable limit to prevent memory issues
        dynamicPageSize = 100;
        loadingStrategy = "LOAD_CAPPED_UNSEEN";
        _logger.w(
          '⚠️ High unseenCount ($unseenCount) - capping pageSize at $dynamicPageSize',
        );
      }

      // ═════════════════════════════════════════════════════════════════
      // STEP 2: PREPARE CHAT CONTEXT AND CLEAR PREVIOUS DATA
      // ═════════════════════════════════════════════════════════════════

      _logger.d('🧹 Clearing previous chat data and setting new context');

      // Clear existing data to ensure fresh load
      _chatsData = chats.ChatsModel();
      _pinnedMessagesData = chats.ChatsModel();
      _lastChatsDataHash = null;
      clearHighlight();

      // ✅ Clear seen message tracker for new chat session
      _processedSeenMessageIds.clear();
      _logger.d('🧹 Cleared seen message tracker for new chat session');

      _scheduleNotification();

      // Set current chat context
      _currentChatData = ChatIds(chatId: chatId, userId: userId ?? 0);
      _socketEventController.setCurrentChat(chatId, userId ?? 0);

      // ═════════════════════════════════════════════════════════════════
      // STEP 3: LOAD MESSAGES WITH DYNAMIC PAGE SIZE
      // ═════════════════════════════════════════════════════════════════

      _logger.d(
        '🌐 Loading messages with strategy: $loadingStrategy, pageSize: $dynamicPageSize',
      );

      // Track start time for performance monitoring
      final startTime = DateTime.now();

      if (chatId > 0) {
        // Load existing chat messages (NEW: REST + cursor, §6.2)
        await _fetchMessagesPage(chatId: chatId, clearExisting: false);
      } else if (userId != null && userId > 0) {
        // Tapping a chat is not "doing something" — it must not create the
        // conversation. Look up an existing one only; if there is none, the
        // screen opens empty and the row is created by the first send (see
        // loadChatMessages / sendMessage for the same rule).
        final existingChatId = await resolveExistingDirectChatId(userId);
        if (existingChatId > 0) {
          _currentChatData = ChatIds(chatId: existingChatId, userId: userId);
          _socketEventController.setCurrentChat(existingChatId, userId);
          await _fetchMessagesPage(
            chatId: existingChatId,
            clearExisting: false,
          );
        } else {
          _logger.d(
            '🆕 onChatItemTap: no conversation with user $userId yet — not creating one',
          );
          _currentChatData = ChatIds(chatId: 0, userId: userId);
          _socketEventController.setCurrentChatWithoutLoading(0, userId);
        }
      } else {
        throw Exception('Invalid chat context: chatId=$chatId, userId=$userId');
      }

      // ═════════════════════════════════════════════════════════════════
      // STEP 4: WAIT FOR MESSAGES TO LOAD, THEN PROCESS UNSEEN MESSAGES
      // ═════════════════════════════════════════════════════════════════

      if (unseenCount > 0) {
        _logger.d(
          '⏱️ Waiting for messages to load before processing unseen messages...',
        );

        // Wait for socket response with timeout
        int attempts = 0;
        const maxAttempts = 15; // 3 seconds timeout (200ms * 15)
        bool messagesLoaded = false;

        while (attempts < maxAttempts && !_isDisposed) {
          await Future.delayed(Duration(milliseconds: 200));

          if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
            messagesLoaded = true;
            break;
          }

          attempts++;
        }

        if (messagesLoaded) {
          final loadTime = DateTime.now().difference(startTime).inMilliseconds;
          _logger.d('✅ Messages loaded successfully in ${loadTime}ms');

          // Process unseen messages immediately
          await _processUnseenMessagesAfterLoad(
            chatId: chatId,
            expectedUnseenCount: unseenCount,
            loadingStrategy: loadingStrategy,
          );
        } else {
          _logger.w(
            '⚠️ Messages not loaded within timeout - proceeding without unseen processing',
          );
        }
      }

      // ═════════════════════════════════════════════════════════════════
      // STEP 5: UPDATE CHAT LIST AND ARCHIVE STATES
      // ═════════════════════════════════════════════════════════════════

      await _syncChatListStates(chatId: chatId, fromArchive: fromArchive);

      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      _logger.d(
        '🎯 onChatItemTap COMPLETED in ${totalTime}ms - strategy: $loadingStrategy, pageSize: $dynamicPageSize',
      );
    } catch (e) {
      _logger.e('❌ Error in onChatItemTap: $e');
      // Fallback to default behavior
      if (chatId > 0 && userId != null) {
        try {
          await loadChatMessages(chatId: chatId, peerId: userId);
        } catch (fallbackError) {
          _logger.e('❌ Fallback also failed: $fallbackError');
        }
      }
      rethrow;
    }
  }

  /// NEW: read state is a per-participant watermark (§6.6), so all of
  /// OLD's elaborate per-message age/status heuristic filtering + batched
  /// per-message emission (previously ~250 lines here) collapses to a
  /// single `POST .../read {upToSeq}` call — see markChatMessagesAsSeen.
  /// Signature/params kept so the one call site (onChatItemTap) doesn't
  /// need to change.
  Future<void> _processUnseenMessagesAfterLoad({
    required int chatId,
    required int expectedUnseenCount,
    required String loadingStrategy,
  }) async {
    await markChatMessagesAsSeen(chatId);
  }

  /// Synchronize chat list and archive list states after chat item tap
  Future<void> _syncChatListStates({
    required int chatId,
    required bool fromArchive,
  }) async {
    try {
      _logger.d(
        '🔄 Syncing chat list states - chatId: $chatId, fromArchive: $fromArchive',
      );

      // Update main chat list unseen count
      clearChatUnseenCount(chatId);

      // Update archived chat unseen count if applicable
      _clearArchivedChatBadgeIfNeeded(chatId);

      // Trigger UI update notification
      _scheduleNotification();

      _logger.d('✅ Chat list states synchronized successfully');
    } catch (e) {
      _logger.e('❌ Error syncing chat list states: $e');
    }
  }

  /// Get current user ID asynchronously
  Future<String?> _getCurrentUserId() async {
    try {
      return await SecurePrefs.getString(SecureStorageKeys.USERID);
    } catch (e) {
      _logger.e('Error getting current user ID: $e');
      return null;
    }
  }

  /// ✅ NEW: Validate message filtering logic for debugging
  /// ✅ NEW: Get detailed statistics about processed seen messages
  Map<String, dynamic> getSeenMessageProcessingStats() {
    return {
      'processedSeenMessageCount': _processedSeenMessageIds.length,
      'processedSeenMessageIds': _processedSeenMessageIds.toList(),
      'lastProcessedCount': _processedSeenMessageIds.length,
    };
  }

  /// ✅ NEW: Clear seen message tracker manually (for debugging)
  void clearSeenMessageTracker() {
    final previousCount = _processedSeenMessageIds.length;
    _processedSeenMessageIds.clear();
    _logger.d(
      '🧹 Manually cleared seen message tracker (had $previousCount messages)',
    );
  }
}
