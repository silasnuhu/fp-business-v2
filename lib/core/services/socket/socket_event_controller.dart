/// SocketEventController
///
/// Central hub that manages socket events and provides streams for UI components.
/// This controller handles all socket communication including chat messages,
/// online users, typing indicators, and chat list management.
///
/// Key Features:
/// - Real-time chat messaging
/// - Online/offline user status tracking
/// - Typing indicators
/// - Message pagination
/// - Automatic reconnection handling
///
/// Usage:
/// ```dart
/// final controller = SocketEventController(socketService, socketEvents);
/// await controller.initialize();
/// controller.setCurrentChat(chatId, peerId);
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'package:whoxa/main.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:whoxa/core/services/socket/socket_service.dart';
import 'package:whoxa/featuers/chat/data/online_user_model.dart';
import 'package:whoxa/featuers/chat/data/chat_ids_model.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart' as chatlist;
import 'package:whoxa/featuers/chat/data/chats_model.dart';
import 'package:whoxa/featuers/chat/data/message_dto.dart';
import 'package:whoxa/featuers/chat/data/message_adapter.dart';
import 'package:whoxa/featuers/chat/data/typing_model.dart';
import 'package:whoxa/featuers/chat/data/block_updates_model.dart';
import 'package:whoxa/featuers/chat/provider/archive_chat_provider.dart';
import 'package:whoxa/featuers/chat/utils/chat_cache_manager.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

class SocketEventController with ChangeNotifier {
  // ═══════════════════════════════════════════════════════════════════════════
  // DEPENDENCIES
  // ═══════════════════════════════════════════════════════════════════════════

  final SocketService _socketService;
  final SocketEvents _socketEvents;
  ArchiveChatProvider? _archiveChatProvider;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'SocketEventController',
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTANTS
  // ═══════════════════════════════════════════════════════════════════════════

  static const int _defaultPageSize = 20;
  static const int _maxRecentMessages = 50;
  static const int _recentMessageCleanupThreshold = 25;

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE VARIABLES
  // ═══════════════════════════════════════════════════════════════════════════
  //
  SocketService get socketService => _socketService;

  // Data models
  chatlist.ChatListModel _chatListData = chatlist.ChatListModel(chats: []);
  ChatsModel _chatsData = ChatsModel();
  final ChatIdsModel _chatIdsData = ChatIdsModel();
  OnlineUsersModel _onlineUsersData = OnlineUsersModel(onlineUsers: []);
  TypingModel _typingData = TypingModel();
  BlockUpdatesModel _blockUpdatesData = BlockUpdatesModel();

  // Loading states
  bool _isChatLoading = false;
  bool _isChatListLoading = false;
  bool _hasMoreMessages = true;
  bool _isConnected = false;
  bool _isInitialized = false;
  bool _isPaginationLoading = false;

  // Cache protection flag to prevent server responses from overriding fresh cached data
  bool _isRefreshing = false;

  // Current chat context
  int? _currentChatId;
  int? _currentUserId;
  int? _lastChatRefresh; // Track last refresh time to prevent spam

  // Error handling
  String? _lastError;

  // Duplicate message prevention
  final Set<int> _recentlyProcessedMessages = <int>{};

  // Track already seen messages to prevent duplicate emissions
  final Set<int> _seenMessages = <int>{};

  // Track emission and acknowledgment statistics
  final Map<String, int> _emissionStats = {};

  // Typing status tracking
  final Map<int, bool> _userTypingStatus = {}; // userId -> isTyping
  final Map<String, bool> _chatTypingStatus = {}; // chatId -> isTyping
  int? _currentTypingUserId;

  // ✅ NEW: Chat focus tracking
  bool _isChatScreenActive = false;
  bool _isAppInForeground = true;
  String? _activeChatScreenId;
  bool _isPendingFocusChange = false;

  bool get isChatScreenActive => _isChatScreenActive;
  bool get isAppInForeground => _isAppInForeground;
  String? get activeChatScreenId => _activeChatScreenId;
  int? get currentChatId => _currentChatId;

  // Message lock when new message received
  bool _isUpdatingChatList = false;
  final List<Records> _pendingMessages = [];

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT FOCUS
  // ═══════════════════════════════════════════════════════════════════════════

  // ✅ NEW: Methods to manage chat focus
  void setChatScreenActive(int chatId, int userId, {bool isActive = true}) {
    _logger.d(
      'Chat screen focus request: active=$isActive, chatId=$chatId, userId=$userId',
    );

    // ✅ TRACK WHEN FOCUS CHANGES
    _isPendingFocusChange = true;

    // ✅ IMMEDIATE STATE UPDATE
    _isChatScreenActive = isActive;
    _activeChatScreenId = isActive ? '${chatId}_$userId' : null;

    _logger.d(
      '✅ Chat screen focus updated: active=$_isChatScreenActive, screenId=$_activeChatScreenId',
    );

    // ✅ CLEAR PENDING FLAG AFTER SHORT DELAY
    Future.delayed(Duration(milliseconds: 200), () {
      _isPendingFocusChange = false;
    });

    // Safely notify listeners after frame to avoid setState during dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void setAppForegroundState(bool isInForeground) {
    _isAppInForeground = isInForeground;
    _logger.d('App foreground state changed: $isInForeground');

    // If app goes to background, consider chat screen inactive
    if (!isInForeground) {
      _isChatScreenActive = false;
      _activeChatScreenId = null;
    }

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAM CONTROLLERS
  // ═══════════════════════════════════════════════════════════════════════════

  final StreamController<chatlist.ChatListModel> _chatListStreamController =
      StreamController<chatlist.ChatListModel>.broadcast();
  final StreamController<ChatsModel> _chatsStreamController =
      StreamController<ChatsModel>.broadcast();
  final StreamController<ChatIdsModel> _chatIdsStreamController =
      StreamController<ChatIdsModel>.broadcast();
  final StreamController<OnlineUsersModel> _onlineUsersStreamController =
      StreamController<OnlineUsersModel>.broadcast();
  final StreamController<TypingModel> _typingStreamController =
      StreamController<TypingModel>.broadcast();
  final StreamController<BlockUpdatesModel> _blockUpdatesStreamController =
      StreamController<BlockUpdatesModel>.broadcast();
  // NEW's `message_pinned`/`message_unpinned` payloads are slim
  // ({conversationId, messageId, ...}) — no full message data like OLD's
  // combined event — so this now just broadcasts which conversation needs
  // its pinned list re-fetched via REST, rather than a full ChatsModel.
  final StreamController<String> _pinUnpinStreamController =
      StreamController<String>.broadcast();

  // `poll_updated` pushes `{messageId, poll}` (viewer-neutral broadcast
  // shape) on every vote/close — forwarded raw so subscribers (ChatProvider)
  // decide how to merge it (they need `currentUserId` to recover the
  // viewer's own vote state, which this payload doesn't carry).
  final StreamController<Map<String, dynamic>> _pollUpdatedStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // `message_updated` pushes the full edited message — forwarded parsed so
  // subscribers (ChatProvider) patch their own loaded copies in place.
  final StreamController<MessageDto> _messageUpdatedStreamController =
      StreamController<MessageDto>.broadcast();

  // AI Assistant streaming preview — `ai_message_chunk` (`{conversationId,
  // delta}`) and `ai_message_error` (`{conversationId}`), forwarded raw to
  // AiAssistantProvider, which owns the in-progress reply text.
  final StreamController<Map<String, dynamic>> _aiMessageChunkStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _aiMessageErrorStreamController =
      StreamController<String>.broadcast();

  // Stream for real-time message notifications (only socket messages, not pagination)
  final StreamController<Records> _newMessageStreamController =
      StreamController<Records>.broadcast();

  // Stream that fires for EVERY incoming `new_message` socket event,
  // regardless of which chat is open. `_newMessageStreamController` above
  // only fires for the currently-open chat, so it can't drive chat-list
  // preview/unread/reorder updates for background chats — this one can.
  final StreamController<Records> _chatListMessageStreamController =
      StreamController<Records>.broadcast();

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ═══════════════════════════════════════════════════════════════════════════

  SocketEventController(
    this._socketService,
    this._socketEvents, [
    this._archiveChatProvider,
  ]) {
    _logger.i('Creating SocketEventController');
    _setupSocketEventListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC GETTERS
  // ═══════════════════════════════════════════════════════════════════════════

  // Data getters
  chatlist.ChatListModel get chatListData => _chatListData;
  ChatsModel get chatsData => _chatsData;
  ChatIdsModel get chatIdsData => _chatIdsData;
  OnlineUsersModel get onlineUsersData => _onlineUsersData;
  TypingModel get typingData => _typingData;
  BlockUpdatesModel get blockUpdatesData => _blockUpdatesData;

  // State getters
  bool get isChatLoading => _isChatLoading;
  bool get isChatListLoading => _isChatListLoading;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  bool get isPaginationLoading => _isPaginationLoading;
  bool get isRefreshing => _isRefreshing;

  // Stream getters
  Stream<chatlist.ChatListModel> get chatListStream =>
      _chatListStreamController.stream;
  Stream<ChatsModel> get chatsStream => _chatsStreamController.stream;
  Stream<ChatIdsModel> get chatIdsStream => _chatIdsStreamController.stream;
  Stream<OnlineUsersModel> get onlineUsersStream =>
      _onlineUsersStreamController.stream;
  Stream<TypingModel> get typingStream => _typingStreamController.stream;
  Stream<BlockUpdatesModel> get blockUpdatesStream =>
      _blockUpdatesStreamController.stream;

  /// Emits a conversationId whenever NEW pushes `message_pinned`/
  /// `message_unpinned` for it — subscribers should re-fetch that
  /// conversation's pinned list via REST.
  Stream<String> get pinUnpinStream => _pinUnpinStreamController.stream;

  /// Raw `{messageId, poll}` payload from every `poll_updated` push (vote or
  /// close, from any participant).
  Stream<Map<String, dynamic>> get pollUpdatedStream =>
      _pollUpdatedStreamController.stream;

  /// Every `message_updated` push (e.g. an edit), from any participant.
  Stream<MessageDto> get messageUpdatedStream =>
      _messageUpdatedStreamController.stream;

  /// Every `ai_message_chunk` push: `{conversationId, delta}`.
  Stream<Map<String, dynamic>> get aiMessageChunkStream =>
      _aiMessageChunkStreamController.stream;

  /// The conversationId of every `ai_message_error` push.
  Stream<String> get aiMessageErrorStream =>
      _aiMessageErrorStreamController.stream;

  // Stream for real-time message notifications (socket messages only)
  Stream<Records> get newMessageStream => _newMessageStreamController.stream;

  /// Fires for every incoming `new_message` socket event (any chat, open or
  /// not). Subscribers use this to keep the chat-list last-message preview,
  /// unread badge and ordering live on the new backend, which has no
  /// `chat_list` socket event.
  Stream<Records> get chatListMessageStream =>
      _chatListMessageStreamController.stream;

  // ═══════════════════════════════════════════════════════════════════════════
  // LOADER STATE
  // ═══════════════════════════════════════════════════════════════════════════

  // ✅ Add starred messages data storage to your SocketEventController class
  final ChatsModel _starredMessagesData = ChatsModel();
  ChatsModel get starredMessagesData => _starredMessagesData;

  void _setIsChatLoading(bool value) {
    if (_isChatLoading != value) {
      _isChatLoading = value;
      notifyListeners();
    }
  }

  /// 🗄️ Public method to set chat loading state (for cache integration)
  void setChatLoadingState(bool value) {
    _setIsChatLoading(value);
  }

  /// 🛡️ Set cache protection flag to prevent server overrides
  void setCacheDataProtection(bool value) {
    if (value) {
      _logger.d(
        '🛡️ Cache data protection ENABLED - server responses will be merged instead of replaced',
      );
    } else {
      _logger.d(
        '🔓 Cache data protection DISABLED - server responses will replace data normally',
      );
    }
  }

  void _setPaginationLoading(bool value) {
    if (_isPaginationLoading != value) {
      _isPaginationLoading = value;
      notifyListeners();
    }
  }

  void _setRefreshing(bool value) {
    if (_isRefreshing != value) {
      _isRefreshing = value;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the socket controller
  ///
  /// This method should be called once when the controller is first used.
  /// It establishes socket connection and loads initial data.
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.d('SocketEventController already initialized');
      return;
    }

    _logger.i('Initializing SocketEventController');

    try {
      // Setup event listeners if not already set up
      _setupSocketEventListeners();

      // Connect to socket
      final connectionSuccess = await connect();
      if (!connectionSuccess) {
        throw Exception('Failed to establish socket connection');
      }

      // Load initial data
      await Future.wait([emitChatList(), emitInitialOnlineUser()]);

      _isInitialized = true;
      _logger.i('SocketEventController initialized successfully');
    } catch (e) {
      _lastError = 'Initialization failed: ${e.toString()}';
      _logger.e(_lastError!);
      notifyListeners();
      rethrow;
    }
  }

  /// Connect to the socket server
  Future<bool> connect() async {
    try {
      _isConnected = await _socketService.connect();

      if (_isConnected) {
        _logger.i('Socket connected successfully');
        _clearError();
        return true;
      } else {
        _setError('Failed to connect to socket');
        return false;
      }
    } catch (e) {
      _setError('Socket connection error: ${e.toString()}');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT MANAGEMENT METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set the current active chat context
  ///
  /// [chatId] - The ID of the chat (0 for new chats)
  /// [peerId] - The ID of the peer user
  void setCurrentChat(int chatId, int peerId) {
    _logger.d('Setting current chat - chatId: $chatId, peerId: $peerId');

    // Validate input parameters
    if (!_isValidChatContext(chatId, peerId)) {
      _logger.e('Invalid chat context: chatId=$chatId, peerId=$peerId');
      return;
    }

    // Clear typing context when switching chats
    _clearTypingContext();

    // Check if context has actually changed
    final bool contextChanged =
        _currentChatId != chatId || _currentUserId != peerId;

    _currentChatId = chatId;
    _currentUserId = peerId;

    if (contextChanged) {
      _logger.d('Chat context changed, resetting state');
      _resetChatState();
      _loadMessagesForCurrentChat();
    } else {
      _logger.d('Chat context unchanged, skipping reload');
    }

    notifyListeners();
  }

  /// ✅ Set current chat without triggering loading state (for cached data)
  void setCurrentChatWithoutLoading(int chatId, int peerId) {
    _logger.d(
      'Setting current chat WITHOUT LOADING: chatId=$chatId, peerId=$peerId',
    );

    // Update chat context without triggering loading
    _currentChatId = chatId;
    _currentUserId = peerId;

    // Update typing context for chat ID transition
    if (chatId > 0) {
      _updateTypingContextForChatId(chatId);
    }

    // Ensure loading state is false since we're using cached data
    _setIsChatLoading(false);

    notifyListeners();
  }

  /// Update the current chat ID (used when a new chat gets an ID)
  void updateCurrentChatId(int newChatId) {
    if (newChatId <= 0) {
      _logger.w('Attempted to update chat ID with invalid value: $newChatId');
      return;
    }

    _logger.d('Updating current chat ID from $_currentChatId to $newChatId');
    _currentChatId = newChatId;

    // Update typing context for chat ID transition
    _updateTypingContextForChatId(newChatId);

    notifyListeners();
  }

  Future<void> _loadMessagesForCurrentChat() async {
    if (_currentChatId == null && _currentUserId == null) {
      _logger.e('Cannot load messages: No valid chat context');
      return;
    }

    try {
      // ✅ Set initial loading state (not pagination or refresh)
      _setIsChatLoading(true);

      // ✅ FIX: Add timeout safety mechanism
      Timer(Duration(seconds: 15), () {
        if (_isChatLoading) {
          _logger.w('🕐 Chat loading timeout - forcing loading state to false');
          _setIsChatLoading(false);
        }
      });

      // Reset pagination
      _hasMoreMessages = true;

      if (_currentChatId != null && _currentChatId! > 0) {
        _logger.d('Loading messages for existing chat: $_currentChatId');
        await emitChatMessages(chatId: _currentChatId!, page: 1);
      } else if (_currentUserId != null && _currentUserId! > 0) {
        _logger.d('Loading messages for new chat with user: $_currentUserId');
        await emitChatMessages(peerId: _currentUserId!, page: 1);
      }
    } catch (e) {
      _logger.e('Error loading messages for current chat: $e');
      _setError('Failed to load messages: ${e.toString()}');
      _setIsChatLoading(false);
    }
  }

  Future<void> refreshChatMessages(int chatId, int peerId) async {
    if (_isRefreshing) {
      _logger.d('Already refreshing, skipping duplicate request');
      return;
    }

    try {
      _logger.d('🔄 Starting chat messages refresh in SocketEventController');
      _setRefreshing(true);

      // ✅ IMPORTANT: Reset pagination for refresh
      _hasMoreMessages = true;

      // ✅ Clear existing messages before refresh
      _chatsData = ChatsModel();
      _chatsStreamController.add(_chatsData);

      // ✅ Request fresh data from server
      if (chatId > 0) {
        await emitChatMessages(chatId: chatId, page: 1);
      } else {
        await emitChatMessages(peerId: peerId, page: 1);
      }

      _logger.d('✅ Refresh request sent successfully');
    } catch (e) {
      _logger.e('❌ Error refreshing chat messages: $e');
      _setRefreshing(false); // Reset on error
      rethrow;
    }
    // Note: _setRefreshing(false) will be called by the message list listener
  }

  /// Reset chat state for new chat context
  void _resetChatState() {
    _chatsData = ChatsModel();
    _hasMoreMessages = true;
    _chatsStreamController.add(_chatsData);

    // Clear seen messages set when switching chats
    _seenMessages.clear();
    clearEmissionTracking(); // Clear emission tracking for new chat
    _logger.d(
      'Cleared seen messages cache and emission tracking for new chat context',
    );
  }

  /// Reset chat data completely
  void resetChat() {
    _logger.d('Resetting chat data');
    _resetChatState();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE LOADING METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // ⚠️ NEW has no `message_list`/`chat_list` socket events at all (confirmed
  // absent from ClientEvents/ServerEvents in the backend's socket.types.ts)
  // — the app is REST-paginated instead (`ConversationRepository.
  // getConversations`, `MessageRepository.getMessages`; see
  // ChatProvider.loadMoreMessages/emitChatList/refreshChatList for the real
  // implementations). The methods below are kept only for their
  // `_isChatLoading`/`_isChatListLoading`/timeout-fallback state-machine
  // side effects, which `ChatProvider`'s cache/loading-gate logic still
  // reads (`isChatLoading`, `setChatLoadingState`, `setCacheDataProtection`)
  // — the actual `_socketService.emit(...)` calls to the dead events were
  // removed since nothing on the server has ever listened for them.

  /// Emit request to load chat messages
  ///
  /// [chatId] - ID of existing chat (use 0 for new chats)
  /// [peerId] - ID of peer user (for new chats)
  /// [page] - Page number for pagination
  /// [pageSize] - Number of messages per page
  Future<void> emitChatMessages({
    int chatId = 0,
    int peerId = 0,
    int page = 1,
    int pageSize = _defaultPageSize,
  }) async {
    // Use current context if parameters not provided
    final int effectiveChatId = chatId > 0 ? chatId : (_currentChatId ?? 0);
    final int effectivePeerId = peerId > 0 ? peerId : (_currentUserId ?? 0);

    // Validate parameters
    if (!_isValidChatContext(effectiveChatId, effectivePeerId)) {
      _logger.e(
        'Invalid chat context for message loading: chatId=$effectiveChatId, peerId=$effectivePeerId',
      );
      return;
    }

    _setIsChatLoading(true);

    // ✅ FIX: Add timeout safety mechanism — NEW never responds to this (no
    // such socket event exists server-side), so this timeout is the only
    // thing that clears `_isChatLoading` for callers still reading it.
    Timer(Duration(seconds: 15), () {
      if (_isChatLoading) {
        _logger.w('🕐 Socket request timeout - forcing loading state to false');
        _setIsChatLoading(false);
      }
    });
  }

  /// Emit chat-list refresh request. NEW has no `chat_list` socket event —
  /// kept only for the `_isChatListLoading` state-machine side effect (see
  /// note above); the real chat list load is `ChatProvider.emitChatList`'s
  /// REST call to `ConversationRepository.getConversations`.
  Future<void> emitChatList({int page = 1, int pageSize = 20}) async {
    try {
      _isChatListLoading = true;
      notifyListeners();
    } catch (e) {
      _setError('Error requesting paginated chat list: ${e.toString()}');
      _isChatListLoading = false;
      notifyListeners();
    }
  }

  /// Refresh chat list (with optional silent mode). See note above — no
  /// socket event to emit to; kept only for the loading-flag side effect.
  Future<void> refreshChatList({bool silent = false}) async {
    if (!silent) {
      _isChatListLoading = true;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONLINE USERS METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// ⚠️ Request initial online users data.
  /// NEW's `presence_snapshot` is delivered once automatically on connect
  /// and is explicitly NOT re-requestable on demand (§5.4/§7.8 breaking
  /// change #9) — there is no confirmed NEW event this can emit to trigger
  /// a fresh snapshot. Left as a harmless no-op (the emit below targets an
  /// event NEW's server doesn't listen for a manual re-request on) rather
  /// than guessing at a workaround; callers relying on this to refresh
  /// presence after being backgrounded/reconnecting will see stale data
  /// until the next full reconnect.
  Future<void> emitInitialOnlineUser() async {
    try {
      _logger.d(
        'Requesting initial online users (NEW: not re-requestable, see method doc)',
      );
      _socketService.emit(_socketEvents.presenceSnapshot, data: {});
    } catch (e) {
      _setError('Error requesting online users: ${e.toString()}');
    }
  }

  /// Check if a specific user is online
  bool isUserOnline(int userId) {
    if (_onlineUsersData.onlineUsers?.isEmpty ?? true) {
      return false;
    }

    final user = _onlineUsersData.onlineUsers!.firstWhere(
      (user) => user.userId == userId,
      orElse: () => OnlineUsers(userId: userId, isOnline: false),
    );

    return user.isOnline == true;
  }

  /// Get user's last seen timestamp
  String? getUserLastSeen(int userId) {
    if (_onlineUsersData.onlineUsers == null) return null;

    final user = _onlineUsersData.onlineUsers!.firstWhere(
      (user) => user.userId == userId,
      orElse: () => OnlineUsers(userId: userId),
    );

    return user.updatedAt;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TYPING INDICATOR METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send typing indicator
  void sendTypingIndicator(String chatId, bool isTyping) {
    try {
      final int chatIdInt = int.tryParse(chatId) ?? 0;

      if (chatIdInt == 0 && _currentUserId != null && _currentUserId! > 0) {
        _sendTypingIndicatorForNewChat(_currentUserId!, isTyping);
      } else if (chatIdInt > 0) {
        _sendTypingIndicatorForExistingChat(chatIdInt, isTyping);
      } else {
        _logger.w('Cannot send typing indicator - invalid chat context');
      }
    } catch (e) {
      _setError('Error sending typing indicator: ${e.toString()}');
    }
  }

  /// Check if someone is typing in a chat
  bool isUserTypingInChat(int chatId) {
    final bool socketTyping = _typingData.typing == true;
    if (!socketTyping) return false;

    if (chatId == 0 && _currentUserId != null && _currentUserId! > 0) {
      return _currentTypingUserId == _currentUserId;
    }

    if (chatId > 0) {
      return _typingData.chatId == chatId.toString();
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE STATUS METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // ❌ markMessageAsSeen(String, String) REMOVED — unreferenced (the real
  // per-message seen path is `emitMessageSeen(int, int)` below; bulk seen
  // state is `ChatProvider.markChatMessagesAsSeen`'s REST watermark call).

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Format timestamp for UI display
  String formatTime(String? time) {
    if (time == null) return "";

    try {
      final dateTime = DateTime.parse(time);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return DateFormat('MMM d, yyyy').format(dateTime);
      } else if (difference.inDays > 0) {
        return AppString.trParams(
          difference.inDays == 1 ? '{n} day ago' : '{n} days ago',
          {'n': '${difference.inDays}'},
        );
      } else if (difference.inHours > 0) {
        return AppString.nHrAgo('${difference.inHours}');
      } else if (difference.inMinutes > 0) {
        return AppString.nMinAgo('${difference.inMinutes}');
      } else {
        return AppString.justNow;
      }
    } catch (e) {
      _logger.e('Error formatting time: $e');
      return "";
    }
  }

  /// Clear error message
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  // ❌ silentRefresh() REMOVED — unreferenced (ChatProvider.silentRefresh,
  // its only caller, was itself dead and has been removed too; the real
  // silent refresh path is ChatProvider.refreshChatListSilent, which is
  // REST-based).

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set chat loading state

  /// Set error message and notify listeners
  void _setError(String error) {
    _lastError = error;
    _logger.e(error);
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _lastError = null;
  }

  /// Validate chat context parameters
  bool _isValidChatContext(int chatId, int peerId) {
    return chatId > 0 || peerId > 0;
  }

  /// Send typing indicator for new chat
  void _sendTypingIndicatorForNewChat(int userId, bool isTyping) {
    _logger.d(
      'Sending typing indicator for new chat - UserID: $userId, IsTyping: $isTyping',
    );

    _userTypingStatus[userId] = isTyping;
    _currentTypingUserId = isTyping ? userId : null;

    // NEW's typing_start/typing_stop are conversation-scoped
    // ({conversationId}) — there's no conversation yet before the first
    // message is sent, so there's nothing to emit to. The local state above
    // still drives this device's own composer; the peer just can't see a
    // live typing indicator until the conversation actually exists.
  }

  /// Send typing indicator for existing chat
  void _sendTypingIndicatorForExistingChat(int chatId, bool isTyping) {
    _logger.d(
      'Sending typing indicator for existing chat - ChatID: $chatId, IsTyping: $isTyping',
    );

    final String chatIdStr = chatId.toString();
    _chatTypingStatus[chatIdStr] = isTyping;
    _currentTypingUserId = null;

    _socketService.emit(
      isTyping ? _socketEvents.typingStart : _socketEvents.typingStop,
      data: {"conversationId": chatIdStr},
    );
  }

  /// Update typing context when chat ID changes
  void _updateTypingContextForChatId(int newChatId) {
    if (_currentTypingUserId != null && newChatId > 0) {
      final String newChatIdStr = newChatId.toString();
      _chatTypingStatus[newChatIdStr] =
          _userTypingStatus[_currentTypingUserId] ?? false;
      _currentTypingUserId = null;

      _logger.d(
        'Switched typing context from user-based to chat-based for chat ID: $newChatId',
      );
    }
  }

  /// Clear typing context
  void _clearTypingContext() {
    _userTypingStatus.clear();
    _chatTypingStatus.clear();
    _currentTypingUserId = null;
  }

  /// Get current user ID asynchronously
  Future<int?> _getCurrentUserIdAsync() async {
    try {
      final String? userIdString = await SecurePrefs.getString(
        SecureStorageKeys.USERID,
      );
      return int.tryParse(userIdString ?? '');
    } catch (e) {
      _logger.e('Error getting current user ID: $e');
      return null;
    }
  }

  /// Check if message is duplicate
  bool _isDuplicateMessage(int? messageId) {
    if (messageId == null) return false;

    if (_recentlyProcessedMessages.contains(messageId)) {
      _logger.d(
        'Message $messageId was recently processed, skipping duplicate',
      );
      return true;
    }

    _recentlyProcessedMessages.add(messageId);

    // Clean up old message IDs to prevent memory growth
    if (_recentlyProcessedMessages.length > _maxRecentMessages) {
      final list = _recentlyProcessedMessages.toList();
      list.removeRange(0, _recentMessageCleanupThreshold);
      _recentlyProcessedMessages.clear();
      _recentlyProcessedMessages.addAll(list);
    }

    return false;
  }

  // ❌ emitDeleteMessageForMe/emitDeleteMessageForEveryone REMOVED —
  // unreferenced (superseded by ChatProvider.deleteMessageForMe/
  // deleteMessageForEveryone's REST calls to MessageRepository; NEW deletes
  // are REST-only, not a socket round-trip).

  // ═══════════════════════════════════════════════════════════════════════════
  // SOCKET EVENT LISTENERS SETUP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Setup all socket event listeners
  void _setupSocketEventListeners() {
    _setupPinUnpinMessageListener();
    _setupOnlineUsersListeners();
    _setupTypingListener();
    _setupNewMessageListener();
    _setupMessageSeenListeners();
    _setupConnectionListeners();
    _setupMessageDeletionListeners();
    _setupMessageUpdatedListener();
    _setupMissedCallListener();
    _setupCallEventListeners();
    _setupPollUpdatedListener();
    _setupBlockListeners();
    _setupAiAssistantListeners();
  }

  /// AI Assistant streaming preview. Chunks are never persisted — the
  /// finished reply lands as a normal `new_message` from the bot user.
  void _setupAiAssistantListeners() {
    _socketService.off(_socketEvents.aiMessageChunk);
    _socketService.on(_socketEvents.aiMessageChunk, (data) {
      try {
        if (data is! Map) return;
        _aiMessageChunkStreamController.add(Map<String, dynamic>.from(data));
      } catch (e) {
        _logger.e('❌ Error handling ai_message_chunk: $e');
      }
    });

    _socketService.off(_socketEvents.aiMessageError);
    _socketService.on(_socketEvents.aiMessageError, (data) {
      _logger.w('🤖 Received ai_message_error: $data');
      try {
        if (data is! Map) return;
        final conversationId = data['conversationId']?.toString();
        if (conversationId == null || conversationId.isEmpty) return;
        _aiMessageErrorStreamController.add(conversationId);
      } catch (e) {
        _logger.e('❌ Error handling ai_message_error: $e');
      }
    });
  }

  /// NEW broadcasts `poll_updated` (`{messageId, poll}`) to the whole
  /// conversation room on every vote and on close — forward it verbatim,
  /// ChatProvider does the merge.
  void _setupPollUpdatedListener() {
    _socketService.on(_socketEvents.pollUpdated, (data) {
      _logger.d('🗳️ Received poll_updated: $data');
      try {
        if (data is! Map) return;
        _pollUpdatedStreamController.add(Map<String, dynamic>.from(data));
      } catch (e) {
        _logger.e('❌ Error handling poll_updated: $e');
      }
    });
  }

  // ❌ _setupChatListListener/_setupChatLockListner/_setupChatUnlockLockListner
  // and their helpers (_parseChatListResponse/_processUnifiedChatListResponse/
  // _processRegularChatList/_updateChatListLockState/_chatLockStatus/
  // isChatLocked) all REMOVED — `chat_list`/`chat_locked`/`chat_unlocked`
  // don't exist on the new backend (chat list is REST-paginated; chat-lock
  // has no backend support at all, see the removed UI entry point in
  // chat_list.dart). `_chatListData`/`_chatListStreamController` themselves
  // are kept — other live handlers below still write to them.

  void _setupPinUnpinMessageListener() {
    _socketService.on(_socketEvents.messagePinned, (data) {
      _handlePinUnpinPayload(data, pinned: true);
    });
    _socketService.on(_socketEvents.messageUnpinned, (data) {
      _handlePinUnpinPayload(data, pinned: false);
    });
  }

  /// NEW emits `message_pinned`/`message_unpinned` as slim
  /// `{conversationId, messageId, ...}` payloads (not a full message-records
  /// array like the old combined event) — push the conversationId onto
  /// `pinUnpinStream` so subscribers (ChatProvider) re-fetch that
  /// conversation's pinned list via REST rather than trying to reconstruct
  /// a Records object from this payload alone.
  void _handlePinUnpinPayload(dynamic data, {required bool pinned}) {
    _logger.d('📌 Received message_${pinned ? 'pinned' : 'unpinned'}: $data');
    try {
      if (data is! Map) return;
      final conversationId =
          (data['conversationId'] ?? data['chat_id'])?.toString();
      if (conversationId == null) return;
      _pinUnpinStreamController.add(conversationId);
    } catch (e) {
      _logger.e(
        '❌ Error handling message_${pinned ? 'pinned' : 'unpinned'}: $e',
      );
    }
  }

  // ❌ _updateExistingMessagePinStatus/_updatePinnedMessagesCollection
  // REMOVED — they operated on a full Records object that NEW's slim
  // message_pinned/message_unpinned payload doesn't carry; see
  // ChatProvider's pinUnpinStream subscription for the REST-refresh
  // replacement.

  // ❌ _setupMessageListListener/_setupStarUnstarMessageListener and their
  // helpers (_updateExistingMessageStarStatus/_updateStarredMessagesCollection/
  // _parseMessageListResponse/_extractValidMessageData/_hasValidRecords/
  // _isValidChatsModel/_logProblematicResponseData/_mergeWithExistingData/
  // _processMessageListResponse/_appendPaginatedMessages/
  // _handleResponseLoadingStates) ALL REMOVED — `message_list`/
  // `star_unstar_message` don't exist on the new backend (message paging is
  // REST via MessageRepository.getMessages; star/unstar never broadcasts a
  // socket event at all — re-fetch after the local REST action instead).
  // `starredMessagesData` is kept (still referenced by ChatProvider) but is
  // now permanently empty since nothing populates it anymore; confirmed
  // unused by any screen/widget already, so this isn't a behavior change.

  // ✅ NEW: Add pinned messages data storage
  final ChatsModel _pinnedMessagesData = ChatsModel();
  ChatsModel get pinnedMessagesData => _pinnedMessagesData;

  /// Reset all loading states (used on error or dispose)
  void _resetAllLoadingStates() {
    _logger.d('🔄 Resetting all loading states');

    // ✅ RESET ALL LOADING FLAGS
    _setIsChatLoading(false);
    _setPaginationLoading(false);
    _setRefreshing(false);

    // ✅ RESET CHAT LIST LOADING
    _isChatListLoading = false;

    // ✅ FORCE IMMEDIATE UI UPDATE
    notifyListeners();

    _logger.d('✅ All loading states reset');
  }

  /// Setup online users event listeners.
  /// NEW's presence is global (not shared-chat-scoped) and slimmed to bare
  /// ids/booleans (§5.4/§7.5): `presence_snapshot` is `{onlineUserIds:
  /// string[]}` (connect-time-only, not re-requestable — the old
  /// `initial_online_user` re-request path below is now a no-op call
  /// that will simply never get a response), and `presence_update` is
  /// `{userId, isOnline}` (replaces both old `online_user`/`offline_user`
  /// as one event). Neither payload carries a profile or a timestamp, so
  /// `OnlineUsers` objects built here only ever have `userId`/`isOnline`
  /// populated — no name/avatar, and `updatedAt` is stamped with local
  /// receive-time as a best-effort stand-in, not a true server "last seen"
  /// (§6.8/§13: no confirmed NEW source for a last-seen timestamp).
  void _setupOnlineUsersListeners() {
    _socketService.on(_socketEvents.presenceSnapshot, (data) {
      _logger.d('Received presence snapshot: $data');
      try {
        final ids = (data is Map ? data['onlineUserIds'] : null) as List? ?? [];
        _onlineUsersData = OnlineUsersModel(
          onlineUsers:
              ids
                  .map(
                    (id) => OnlineUsers(
                      userId: int.tryParse(id.toString()),
                      isOnline: true,
                      updatedAt: DateTime.now().toIso8601String(),
                    ),
                  )
                  .toList(),
        );
        _onlineUsersStreamController.add(_onlineUsersData);
        notifyListeners();
      } catch (e) {
        _setError('Error parsing presence snapshot: ${e.toString()}');
      }
    });

    _socketService.on(_socketEvents.presenceUpdate, (data) {
      _logger.d('Presence update: $data');
      try {
        final userId = int.tryParse((data['userId'] ?? '').toString());
        final isOnline = data['isOnline'] as bool? ?? false;
        if (userId == null) return;
        _updateUserOnlineStatus(
          OnlineUsers(
            userId: userId,
            isOnline: isOnline,
            updatedAt: DateTime.now().toIso8601String(),
          ),
          isOnline,
        );
        _onlineUsersStreamController.add(_onlineUsersData);
        notifyListeners();
      } catch (e) {
        _setError('Error handling presence update: ${e.toString()}');
      }
    });
  }

  /// Update user online status in the list
  void _updateUserOnlineStatus(OnlineUsers user, bool isOnline) {
    _onlineUsersData.onlineUsers ??= [];

    final existingUserIndex = _onlineUsersData.onlineUsers!.indexWhere(
      (existingUser) => existingUser.userId == user.userId,
    );

    if (existingUserIndex != -1) {
      // Update existing user
      _onlineUsersData.onlineUsers![existingUserIndex].isOnline = isOnline;
      _onlineUsersData.onlineUsers![existingUserIndex].updatedAt =
          user.updatedAt;
    } else if (isOnline) {
      // Add new online user
      _onlineUsersData.onlineUsers!.add(user);
    }
  }

  /// Setup typing event listener
  /// NEW's `user_typing` payload is `{conversationId, userId, isTyping}`
  /// (confirmed against ClientEvents/ServerEvents in socket.types.ts) —
  /// different field names than OLD's `{typing, chat_id}`. Remap into
  /// `TypingModel`'s expected keys rather than changing the model, since
  /// it's used by call sites elsewhere that assume those field names.
  void _setupTypingListener() {
    _socketService.on(_socketEvents.userTyping, (data) {
      _logger.d('Received user_typing event: $data');
      try {
        if (data is! Map) return;
        _typingData = TypingModel.fromJson({
          'typing': data['isTyping'],
          'chat_id': data['conversationId'],
        });
        _typingStreamController.add(_typingData);
        notifyListeners();
      } catch (e) {
        _setError('Error parsing user_typing event: ${e.toString()}');
      }
    });
  }

  /// Setup block/unblock listeners.
  ///
  /// OLD's combined `block_updates` (`{user_id, chat_id, is_blocked}`) is
  /// gone; NEW emits two separate events, `user_blocked`/`user_unblocked`,
  /// each with a bare `{userId: "<other user id>"}` payload.
  ///
  /// The payload says nothing about which side of the block this session is
  /// on — it is observed to reach the blocked user as well as the blocker,
  /// and `userId` is just "the other party" either way. So this is NOT a
  /// signal that this account blocked someone; treating it as one made the
  /// blocked user's UI offer an "Unblock" button for a block they never
  /// made. It means only "that user's profile visibility changed for me".
  ///
  /// `chatId` is left null on purpose — subscribers use a null chat id to
  /// tell these events apart from the old per-chat broadcast, and answer
  /// them with a `GET /users/batch?ids=<userId>` re-read, which is what
  /// actually refreshes `lastSeenVisible`/`isOnline`/`lastSeenAt` and the
  /// profile picture.
  void _setupBlockListeners() {
    // `_setupSocketEventListeners` runs again on every re-init/reconnect, so
    // drop any previous callback first — otherwise socket.io stacks one
    // handler per run and each block fires N redundant batch re-reads.
    _socketService.off(_socketEvents.userBlocked);
    _socketService.off(_socketEvents.userUnblocked);

    _socketService.on(_socketEvents.userBlocked, (data) {
      _handleBlockStatePayload(data, isBlocked: true);
    });
    _socketService.on(_socketEvents.userUnblocked, (data) {
      _handleBlockStatePayload(data, isBlocked: false);
    });
  }

  void _handleBlockStatePayload(dynamic data, {required bool isBlocked}) {
    _logger.d('🚫 Received user_${isBlocked ? '' : 'un'}blocked: $data');
    try {
      if (data is! Map) return;
      final userId = int.tryParse(
        (data['userId'] ?? data['user_id'] ?? '').toString(),
      );
      if (userId == null || userId <= 0) {
        _logger.w(
          'user_${isBlocked ? '' : 'un'}blocked without a userId: $data',
        );
        return;
      }

      _blockUpdatesData = BlockUpdatesModel(
        userId: userId,
        // No chat id in NEW's payload — see _setupBlockListeners.
        chatId: null,
        isBlocked: isBlocked,
      );
      _blockUpdatesStreamController.add(_blockUpdatesData);
      notifyListeners();
    } catch (e) {
      _logger.e('❌ Error handling user_${isBlocked ? '' : 'un'}blocked: $e');
    }
  }

  /// Setup new message event listener

  // void _setupNewMessageListener() {
  //   _socketService.on(_socketEvents.recieve, (data) {
  //     _logger.d('Received new message: $data');

  //     try {
  //       final socketResponse = ChatsModel.fromJson(data);

  //       if (socketResponse.records?.isEmpty ?? true) {
  //         _logger.e('No records found in socket response');
  //         return;
  //       }

  //       final newMessage = socketResponse.records!.first;

  //       // Check for duplicate messages
  //       if (_isDuplicateMessage(newMessage.messageId)) {
  //         return;
  //       }

  //       _logger.d(
  //         'Processing new message - Chat ID: ${newMessage.chatId}, Sender ID: ${newMessage.senderId}',
  //       );

  //       // Update chat list with new message
  //       _updateChatListWithNewMessage(newMessage);

  //       // Handle current chat updates
  //       _handleNewMessageForCurrentChat(newMessage);

  //       // ✅ NEW: Auto-mark message as seen if user is currently viewing this chat
  //       _autoMarkMessageAsSeenIfActive(newMessage);

  //       // Notify listeners
  //       _chatListStreamController.add(_chatListData);
  //       notifyListeners();
  //     } catch (e, stackTrace) {
  //       _setError('Error handling new message: ${e.toString()}');
  //       _logger.e('Stack trace: $stackTrace');
  //     }
  //   });
  // }
  void _setupNewMessageListener() {
    // NEW's actual push for a sent message is `new_message`
    // (ServerEvents.NEW_MESSAGE, confirmed against socket.types.ts) with a
    // flat `toPublicMessage`-shaped payload — NOT `receive` wrapped in
    // `{records: [...]}` like OLD sent. A handler on `receive` alone would
    // never fire against this backend, which is why sent messages never
    // showed up for the other participant in real time. Parse it through
    // the same MessageDto/MessageAdapter pipeline the REST message fetch
    // already uses, then feed the resulting Records into the exact same
    // downstream handlers OLD's socket payload used to.
    //
    // `_setupSocketEventListeners` runs more than once across the app's
    // lifecycle (constructor + re-init on socket reconnect), so without
    // this `off()` first, socket.io accumulates a duplicate callback per
    // run — every real message then triggers this handler 2-3x. The
    // `_isDuplicateMessage` guard below already no-ops the repeats before
    // they reach `_processChatListUpdateWithLock`, so it isn't currently
    // visible as a UI bug, just wasted parsing work — but it's a footgun
    // if that guard ever changes. Same fix already applied to
    // archiveChatEvent/archivedChatListEvent in setArchiveChatProvider.
    _socketService.off(_socketEvents.newMessage);
    _socketService.on(_socketEvents.newMessage, (data) async {
      _logger.d('📨 Received new_message via socket');

      try {
        if (data is! Map) {
          _logger.e('new_message payload was not a map: $data');
          return;
        }

        final messageDto = MessageDto.fromJson(data.cast<String, dynamic>());
        final newMessage = MessageAdapter.toRecord(messageDto);

        // The backend echoes our OWN sent messages back on `new_message`
        // too. MessageAdapter.toRecord leaves `messageSeenStatus` null (only
        // the REST fetch path fills it via applySeenStatus). Left null it
        // renders a permanent "pending" clock on our own bubble — and when
        // this echo replaces the optimistic bubble in _addMessageToCurrentChat
        // that clock sticks forever. Default our own echoed sends to 'sent';
        // a later `message_read_update` promotes them to 'seen'. The
        // `conversationSeq` needed for that promotion is already carried on
        // `newMessage.unseenCount` by toRecord.
        final selfUserId = await _getCurrentUserIdAsync();
        if (selfUserId != null &&
            newMessage.senderId == selfUserId &&
            (newMessage.messageSeenStatus == null ||
                newMessage.messageSeenStatus!.isEmpty)) {
          newMessage.messageSeenStatus = 'sent';
        }

        // Reply-preview backfill — NEW's payload only carries the id being
        // replied to, never the referenced message's content/type/sender
        // (see MessageAdapter.attachParentMessages). Resolve it against
        // whatever's already loaded for this chat, if anything.
        if (newMessage.replyTo != null && _chatsData.records != null) {
          MessageAdapter.attachParentMessages(
            [newMessage],
            <int, Records>{
              for (final r in _chatsData.records!)
                if (r.messageId != null) r.messageId!: r,
            },
          );
        }

        logger.v("newMessage:${json.encode(newMessage)}");

        // Check for duplicate messages
        if (_isDuplicateMessage(newMessage.messageId)) {
          return;
        }

        // Broadcast to chat-list subscribers so the last-message preview,
        // unread badge and ordering update live for background chats too.
        _chatListMessageStreamController.add(newMessage);

        _logger.d('=== Socket Message Debug ===');
        _logger.d('Chat ID: ${newMessage.chatId}');
        _logger.d('Message Type: ${newMessage.messageType}');
        _logger.d('Sender ID: ${newMessage.senderId}');
        _logger.d('===========================');

        // ✅ SIMPLE FIX: Use mutex lock
        _processChatListUpdateWithLock(newMessage);

        // Handle current chat updates (this doesn't conflict)
        _handleNewMessageForCurrentChat(newMessage);

        // ✅ FIX: Update cache for this chat even if user is NOT viewing it
        // This prevents duplicate messages when user re-enters the chat
        _updateChatCacheWithSocketMessage(newMessage);

        // Auto-mark message as seen if user is actively viewing this chat
        _autoMarkMessageAsSeenIfActive(newMessage);
      } catch (e, stackTrace) {
        _setError('Error handling new message: ${e.toString()}');
        _logger.e('Stack trace: $stackTrace');
      }
    });
  }

  // ❌ _socketAdminMessage/_socketPollMessage REMOVED — neither
  // `admin_message` nor `poll_voted` exist on the new backend (confirmed
  // absent from ServerEvents in socket.types.ts, and directly confirmed by
  // reading polls.service.ts — voting never emits any socket event). System/
  // admin messages arrive as regular `new_message` events with
  // `type: 'system'` instead of a separate event; poll vote state has no
  // live push at all and needs a re-fetch (`MessageRepository.getPoll`)
  // after the local vote, with no way to see *other* users' votes live.

  // ✅ NEW: Process with mutex lock
  void _processChatListUpdateWithLock(Records newMessage) {
    if (_isUpdatingChatList) {
      // If already updating, add to pending and process later
      _pendingMessages.add(newMessage);
      _logger.d(
        '📝 Chat list busy, added message ${newMessage.messageId} to pending queue',
      );
      return;
    }

    // Process immediately
    _processMessageUpdate(newMessage);
  }

  Future<void> _processMessageUpdate(Records newMessage) async {
    _isUpdatingChatList = true;

    try {
      _logger.d(
        '🔒 Acquired chat list lock for message ${newMessage.messageId}',
      );

      // Update chat list with new message
      await _updateChatListWithNewMessage(newMessage);

      // Notify listeners
      _chatListStreamController.add(_chatListData);
      notifyListeners();

      _logger.d('✅ Updated chat list for message ${newMessage.messageId}');
    } catch (e) {
      _logger.e('❌ Error updating chat list: $e');
    } finally {
      _isUpdatingChatList = false;
      _logger.d('🔓 Released chat list lock');

      // Process any pending messages
      if (_pendingMessages.isNotEmpty) {
        final nextMessage = _pendingMessages.removeAt(0);
        _logger.d('📤 Processing pending message ${nextMessage.messageId}');

        // Small delay to prevent overwhelming
        Future.delayed(Duration(milliseconds: 100), () {
          _processMessageUpdate(nextMessage);
        });
      }
    }
  }

  /// Auto-mark message as seen if user is actively viewing the chat
  /// Fixed auto-mark message as seen method in SocketEventController
  void _autoMarkMessageAsSeenIfActive(Records newMessage) async {
    try {
      // ✅ ENHANCED: Better timing check
      if (_isPendingFocusChange) {
        _logger.d('⏭️ Skipping auto-mark - focus change is pending');
        return;
      }

      // Get current user ID
      final currentUserId = await _getCurrentUserIdAsync();
      if (currentUserId == null) {
        _logger.w('Cannot auto-mark message - current user ID not available');
        return;
      }

      // Skip if message is from current user
      if (newMessage.senderId == currentUserId) {
        _logger.d('⏭️ Skipping auto-mark - message is from current user');
        return;
      }

      // ✅ SIMPLIFIED: Check if user is actively viewing the chat where message arrived
      final isViewingThisChat =
          _isAppInForeground &&
          _isChatScreenActive &&
          _currentChatId != null &&
          _currentChatId == newMessage.chatId &&
          !_isPendingFocusChange;

      if (isViewingThisChat && newMessage.messageId != null) {
        _logger.d(
          '👁️ AUTO-MARKING message as seen (actively viewing this chat)',
        );

        // ✅ IMMEDIATE: Mark as seen right away
        emitMessageSeen(newMessage.chatId!, newMessage.messageId!);
        _logger.d('✅ Message seen event emitted immediately');
      } else {
        _logger.d(
          '⏭️ NOT auto-marking message - user not actively viewing this chat',
        );
      }
    } catch (e) {
      _logger.e('Error in auto-mark message as seen: $e');
    }
  }

  void forceClearChatFocus() {
    _logger.d('🧹 Force clearing chat focus');
    _isChatScreenActive = false;
    _activeChatScreenId = null;
    _isPendingFocusChange = false;
    notifyListeners();
  }

  /// Handle new message for current active chat
  void _handleNewMessageForCurrentChat(Records newMessage) {
    if (_currentChatId != null && newMessage.chatId == _currentChatId) {
      // Message belongs to current active chat
      _addMessageToCurrentChat(newMessage);
      _setPaginationLoading(false);

      // ✅ FIX: When messages arrive via socket, stop the loading indicator
      if (_isChatLoading) {
        _logger.d(
          '💾 Socket message received - stopping chat loading indicator',
        );
        _setIsChatLoading(false);
      }
    } else if (_currentChatId == 0 && newMessage.chatId != null) {
      // New chat scenario - update current chat ID
      _logger.d('New chat created with ID: ${newMessage.chatId}');
      updateCurrentChatId(newMessage.chatId!);
      _addMessageToCurrentChat(newMessage);
      _setPaginationLoading(false);

      // ✅ FIX: When messages arrive via socket, stop the loading indicator
      if (_isChatLoading) {
        _logger.d(
          '💾 Socket message received - stopping chat loading indicator',
        );
        _setIsChatLoading(false);
      }
    }
  }

  /// Add message to current chat if not duplicate
  void _addMessageToCurrentChat(Records newMessage) {
    final bool messageExists =
        _chatsData.records?.any(
          (record) => record.messageId == newMessage.messageId,
        ) ??
        false;

    // ✅ FIX: Also check for optimistic messages by content matching
    int? optimisticMatchIndex;
    if (!messageExists && _chatsData.records != null) {
      for (int i = 0; i < _chatsData.records!.length; i++) {
        final record = _chatsData.records![i];
        // Check if this is an optimistic message (has tempId or sendingStatus)
        if (record.tempId != null ||
            record.sendingStatus == MessageSendingStatus.sending) {
          // Match by content, sender, and message type
          if (record.messageContent == newMessage.messageContent &&
              record.senderId == newMessage.senderId &&
              record.messageType == newMessage.messageType) {
            // Check timestamp proximity (within 60 seconds)
            bool timestampClose = true;
            if (record.createdAt != null && newMessage.createdAt != null) {
              try {
                final optimisticTime = DateTime.parse(record.createdAt!);
                final incomingTime = DateTime.parse(newMessage.createdAt!);
                final difference =
                    incomingTime.difference(optimisticTime).abs();
                timestampClose = difference.inSeconds < 60;
              } catch (e) {
                // If parsing fails, assume close enough
              }
            }
            if (timestampClose) {
              optimisticMatchIndex = i;
              _logger.d(
                '🔄 Found optimistic message match at index $i (tempId: ${record.tempId})',
              );
              break;
            }
          }
        }
      }
    }

    // ✅ FIX: If we found an optimistic match, replace it instead of adding
    if (optimisticMatchIndex != null) {
      _chatsData.records![optimisticMatchIndex] = newMessage;
      _logger.d(
        '✅ REAL-TIME: Replaced optimistic message with confirmed message ID: ${newMessage.messageId}',
      );
      // 🗄️ Update cache with the confirmed message
      _addMessageToCache(newMessage);
      _chatsStreamController.add(_chatsData);
      return;
    }

    if (!messageExists) {
      _chatsData.records ??= [];
      _chatsData.records!.add(
        newMessage,
      ); // Add to end (bottom) for newest-to-oldest display

      _logger.d(
        '✅ REAL-TIME: Added new message to current chat. Total messages: ${_chatsData.records!.length}',
      );
      _logger.d(
        '📨 MESSAGE DETAILS: ID=${newMessage.messageId}, Content="${newMessage.messageContent}", From=${newMessage.senderId}, Chat=${newMessage.chatId}',
      );

      // ✅ CRITICAL DEBUG: Log actionedUser when adding to current chat
      if (newMessage.messageType == 'member-left' ||
          newMessage.messageType == 'member-removed' ||
          newMessage.messageType == 'member-added') {
        _logger.d('🔍 MEMBER ACTION MESSAGE:');
        _logger.d('  Type: ${newMessage.messageType}');
        _logger.d(
          '  ActionedUser: ${newMessage.actionedUser?.userId ?? "NULL"}',
        );
        _logger.d(
          '  ActionedUser Name: ${newMessage.actionedUser?.fullName ?? "NULL"}',
        );
        _logger.d('  Sender: ${newMessage.senderId}');
      }

      // 🗄️ CRITICAL FIX: Update cache with the new message
      _addMessageToCache(newMessage);

      // 🔔 NOTIFICATION: Emit new message for UI notification (real-time only)
      _newMessageStreamController.add(newMessage);

      _chatsStreamController.add(_chatsData);
    } else {
      // Already present — usually because the optimistic REST path
      // (confirmOptimisticMessage) confirmed it first. That path doesn't
      // record `conversationSeq`, so without this backfill a later
      // `message_read_update` can't match this message and it never turns
      // blue. Copy the seq (and a seen status, if we somehow lack one)
      // from this echo before discarding it.
      final records = _chatsData.records;
      if (records != null) {
        for (final existing in records) {
          if (existing.messageId != newMessage.messageId) continue;
          var changed = false;
          if ((existing.unseenCount ?? 0) == 0 &&
              (newMessage.unseenCount ?? 0) > 0) {
            existing.unseenCount = newMessage.unseenCount;
            changed = true;
          }
          if ((existing.messageSeenStatus == null ||
                  existing.messageSeenStatus!.isEmpty) &&
              newMessage.messageSeenStatus != null) {
            existing.messageSeenStatus = newMessage.messageSeenStatus;
            changed = true;
          }
          if (changed) {
            _addMessageToCache(existing);
            _chatsStreamController.add(_chatsData);
          }
          break;
        }
      }
      _logger.d('Message already exists in current chat, skipping duplicate');
    }
  }

  /// Add new message to cache
  void _addMessageToCache(Records newMessage) {
    try {
      // Determine chat ID for cache key
      String? chatIdString;
      if (_currentChatId != null && _currentChatId! > 0) {
        chatIdString = _currentChatId.toString();
      } else if (_currentUserId != null && _currentUserId! > 0) {
        chatIdString = 'user_$_currentUserId';
      }

      if (chatIdString != null) {
        _logger.d(
          '🗄️ CACHE: Adding new message to cache for chat $chatIdString',
        );
        // Run cache update asynchronously to avoid blocking UI
        ChatCacheManager.addMessage(chatIdString, newMessage).catchError((
          error,
        ) {
          _logger.e('❌ CACHE: Failed to add message to cache: $error');
        });
      } else {
        _logger.w('⚠️ CACHE: Cannot determine chat ID for caching new message');
      }
    } catch (e) {
      _logger.e('❌ CACHE: Error adding message to cache: $e');
    }
  }

  /// ✅ FIX: Update cache for socket messages even when user is not viewing that chat
  /// This prevents duplicate messages when user re-enters the chat
  void _updateChatCacheWithSocketMessage(Records newMessage) {
    try {
      // Skip if this is the current chat (already handled by _addMessageToCache)
      if (_currentChatId != null &&
          _currentChatId! > 0 &&
          newMessage.chatId == _currentChatId) {
        _logger.d(
          '⏭️ CACHE: Skipping socket cache update for current chat (already handled)',
        );
        return;
      }

      // Get chat ID from the message
      final chatId = newMessage.chatId;
      if (chatId == null || chatId <= 0) {
        _logger.w(
          '⚠️ CACHE: Cannot update cache - no valid chat ID in socket message',
        );
        return;
      }

      final chatIdString = chatId.toString();
      _logger.d(
        '🗄️ CACHE: Updating cache for non-current chat $chatIdString with socket message',
      );

      // Update cache asynchronously - this will replace optimistic messages if found
      ChatCacheManager.addMessage(chatIdString, newMessage).catchError((error) {
        _logger.e(
          '❌ CACHE: Failed to update cache for chat $chatIdString: $error',
        );
      });
    } catch (e) {
      _logger.e('❌ CACHE: Error updating cache with socket message: $e');
    }
  }

  /// Setup message seen event listener
  /// NEW's read-receipt model is a per-conversation watermark
  /// (`message_read_update` -> `{conversationId, userId, upToSeq}`,
  /// confirmed against ServerEvents in socket.types.ts), not a per-message
  /// event — OLD's `real_time_message_seen`/`message_seen_status` pair
  /// doesn't exist on this backend at all. Mark every message WE sent in
  /// that conversation with `conversationSeq <= upToSeq` as seen by the
  /// other participant.
  void _setupMessageSeenListeners() {
    _socketService.on(_socketEvents.messageReadUpdate, (data) async {
      _logger.d('📩 Received message_read_update: $data');
      try {
        await _handleMessageReadUpdate(data);
      } catch (e) {
        _logger.e('❌ Error handling message_read_update: $e');
      }
    });
  }

  Future<void> _handleMessageReadUpdate(dynamic data) async {
    if (data is! Map) return;
    final conversationId = data['conversationId']?.toString();
    final readerUserId = data['userId']?.toString();
    final upToSeq = int.tryParse((data['upToSeq'] ?? '').toString());
    if (conversationId == null || upToSeq == null) return;

    final currentUserId = await _getCurrentUserIdAsync();
    if (currentUserId == null) return;
    // Ignore our own watermark advancing (this event fires for everyone in
    // the room, including the reader themselves).
    if (readerUserId != null && int.tryParse(readerUserId) == currentUserId) {
      return;
    }

    if (_chatsData.records == null) return;
    bool anyUpdated = false;
    for (final message in _chatsData.records!) {
      if (message.chatId?.toString() != conversationId) continue;
      if (message.senderId != currentUserId) continue; // only our own sends
      final seq = message.unseenCount ?? 0;
      if (seq > 0 && seq <= upToSeq && message.messageSeenStatus != 'seen') {
        message.messageSeenStatus = 'seen';
        anyUpdated = true;
      }
    }

    if (anyUpdated) {
      _chatsStreamController.add(_chatsData);
      notifyListeners();
      _logger.d('✅ Applied message_read_update up to seq $upToSeq');
    }
  }

  /// ✅ NEW: Update message seen status in chat data
  Future<bool> _updateMessageSeenStatus(
    int messageId,
    String seenStatus,
    int? senderId,
    int currentUserId,
  ) async {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      _logger.w('⚠️ No chat messages to update seen status');
      return false;
    }

    bool messageFound = false;

    for (int i = 0; i < _chatsData.records!.length; i++) {
      final message = _chatsData.records![i];

      // ✅ FIXED: Match by message ID (not chat ID)
      if (message.messageId == messageId) {
        _logger.d('📝 Found message $messageId for status update');

        // ✅ SIMPLIFIED: Just update the message seen status
        // This handles both scenarios:
        // 1. I mark someone else's message as seen (senderId == currentUserId in params)
        // 2. Someone else marks my message as seen (senderId != currentUserId in params)
        _logger.d(
          '📝 Message details: senderId=${message.senderId}, currentUserId=$currentUserId, paramSenderId=$senderId',
        );

        // Always update for now - we'll add filtering if needed
        _logger.d(
          '✅ Updating message $messageId status: ${message.messageSeenStatus} → $seenStatus',
        );

        // Create updated message with new seen status
        // ✅ CRITICAL FIX: Preserve ALL fields including story data
        final updatedMessage = Records(
          messageContent: message.messageContent,
          replyTo: message.replyTo,
          socialId: message.socialId,
          messageId: message.messageId,
          messageType: message.messageType,
          messageThumbnail: message.messageThumbnail, // ✅ PRESERVE
          messageLength: message.messageLength,
          messageSeenStatus: seenStatus, // ✅ UPDATE STATUS
          messageSize: message.messageSize,
          deletedFor: message.deletedFor,
          starredFor: message.starredFor,
          deletedForEveryone: message.deletedForEveryone,
          pinned: message.pinned,
          stared: message.stared, // ✅ PRESERVE
          pinLifetime: message.pinLifetime,
          pinnedTill: message.pinnedTill,
          createdAt: message.createdAt,
          updatedAt: message.updatedAt,
          chatId: message.chatId,
          senderId: message.senderId,
          storyId: message.storyId, // ✅ CRITICAL: PRESERVE STORY ID
          unseenCount: message.unseenCount, // ✅ PRESERVE
          parentMessage: message.parentMessage,
          replies: message.replies,
          user: message.user,
          story: message.story, // ✅ CRITICAL: PRESERVE STORY DATA
          actionedUser: message.actionedUser, // ✅ PRESERVE
          social: message.social, // ✅ PRESERVE
          peerUserData: message.peerUserData,
          isFollowing: message.isFollowing, // ✅ PRESERVE
          calls: message.calls, // ✅ PRESERVE
          chat: message.chat, // ✅ PRESERVE
          voiceDuration: message.voiceDuration,
          pollData: message.pollData,
        );

        // Replace the message in the list
        _chatsData.records![i] = updatedMessage;
        messageFound = true;

        _logger.d('✅ Message $messageId status updated to: $seenStatus');
        break;
      }
    }

    if (!messageFound) {
      _logger.w(
        '⚠️ Message $messageId not found in current chat for seen status update',
      );
    }

    return messageFound;
  }

  /// Setup socket connection event listeners
  void _setupConnectionListeners() {
    _socketService.onConnect(() {
      _logger.i('🟢 Socket connected - updating UI');
      _isConnected = true;
      _clearError();

      // Refresh data on reconnect
      if (_chatListData.chats.isEmpty) {
        emitChatList();
      }
      emitInitialOnlineUser();
      notifyListeners();

      // Additional notification after a short delay to ensure UI updates
      Future.delayed(Duration(milliseconds: 100), () {
        if (_isInitialized) {
          notifyListeners();
          _logger.d('🔄 Additional UI notification sent after reconnection');
        }
      });
    });

    _socketService.onDisconnect(() {
      _logger.w('🔴 Socket disconnected - updating UI');
      _isConnected = false;
      notifyListeners();

      // Additional notification after a short delay to ensure UI updates
      Future.delayed(Duration(milliseconds: 100), () {
        if (_isInitialized) {
          notifyListeners();
          _logger.d('🔄 Additional UI notification sent after disconnection');
        }
      });
    });

    _socketService.onError((error) {
      _logger.e('❌ Socket error: $error');
      _setError('Socket error: $error');
    });
  }

  /// Update chat list with new message
  // Future<void> _updateChatListWithNewMessage(Records newMessage) async {
  //   if (_chatListData.chats.isEmpty) {
  //     _logger.d('Chat list is empty, cannot update');
  //     return;
  //   }

  //   bool chatFound = false;

  //   // Find and update the matching chat
  //   for (int i = 0; i < _chatListData.chats.length; i++) {
  //     final chat = _chatListData.chats[i];

  //     if (chat.records?.isEmpty ?? true) continue;

  //     final chatRecord = chat.records!.first;

  //     if (_isMatchingChat(newMessage)) {
  //       chatFound = true;

  //       // Check for duplicate message
  //       if (_isMessageAlreadyInChat(chatRecord, newMessage)) {
  //         _logger.d(
  //           'Message ${newMessage.messageId} already exists in chat list',
  //         );
  //         return;
  //       }

  //       // Update chat with new message
  //       await _updateChatRecord(chatRecord, newMessage, i);
  //       break;
  //     }
  //   }

  //   if (!chatFound) {
  //     _logger.d('Chat not found in list, refreshing chat list');
  //     emitChatList();
  //   }
  //   _setPaginationLoading(false);
  // }

  // Future<void> _updateChatListWithNewMessage(Records newMessage) async {
  //   if (_chatListData.chats.isEmpty) {
  //     _logger.d('Chat list is empty, cannot update');
  //     return;
  //   }

  //   bool chatFound = false;
  //   int? targetChatIndex;

  //   _logger.d('🔍 Looking for chat to update with new message:');
  //   _logger.d('  New Message Chat ID: ${newMessage.chatId}');
  //   _logger.d('  New Message Sender ID: ${newMessage.senderId}');
  //   _logger.d('  New Message Peer User: ${newMessage.peerUserData?.userId}');

  //   // Get current user ID once for all comparisons
  //   final currentUserId = await _getCurrentUserIdAsync();
  //   _logger.d('  Current User ID: $currentUserId');

  //   // Find and update the matching chat
  //   for (int i = 0; i < _chatListData.chats.length; i++) {
  //     final chat = _chatListData.chats[i];

  //     if (chat.records?.isEmpty ?? true) continue;

  //     final chatRecord = chat.records!.first;

  //     _logger.d('📋 Checking chat at index $i:');
  //     _logger.d('  Chat Record Chat ID: ${chatRecord.chatId}');
  //     _logger.d('  Chat Record Chat Type: ${chatRecord.chatType}');

  //     // ✅ Log all possible peer user sources for debugging
  //     _logAllPeerUserSources(chat, chatRecord, i);

  //     // ✅ ROBUST: Try multiple matching strategies
  //     if (_isMatchingChatRobust(newMessage, chatRecord, chat, currentUserId)) {
  //       chatFound = true;
  //       targetChatIndex = i;

  //       _logger.d('✅ Found matching chat at index $i');

  //       // Check for duplicate message
  //       if (_isMessageAlreadyInChat(chatRecord, newMessage)) {
  //         _logger.d(
  //           'Message ${newMessage.messageId} already exists in chat list',
  //         );
  //         return;
  //       }

  //       // Update chat with new message
  //       await _updateChatRecord(chatRecord, newMessage, i);
  //       break;
  //     }
  //   }

  //   if (!chatFound) {
  //     _logger.d('❌ Chat not found in list, refreshing chat list');
  //     _logChatListSummary();
  //     emitChatList();
  //   } else {
  //     _logger.d('✅ Successfully updated chat at index $targetChatIndex');
  //   }

  //   _setPaginationLoading(false);
  // }

  // Future<void> _updateChatListWithNewMessage(Records newMessage) async {
  //   if (_chatListData.chats.isEmpty) {
  //     _logger.d('Chat list is empty, cannot update');
  //     return;
  //   }

  //   bool chatFound = false;
  //   final currentUserId = await _getCurrentUserIdAsync();

  //   _logger.d('🔍 Looking for chat to update:');
  //   _logger.d('  New Message Chat ID: ${newMessage.chatId}');
  //   _logger.d('  New Message Sender ID: ${newMessage.senderId}');
  //   _logger.d('  New Message Peer User: ${newMessage.peerUserData?.userId}');
  //   _logger.d('  Current User ID: $currentUserId');

  //   // ✅ ENHANCED: More detailed matching logic
  //   for (int i = 0; i < _chatListData.chats.length; i++) {
  //     final chat = _chatListData.chats[i];

  //     if (chat.records?.isEmpty ?? true) continue;

  //     final chatRecord = chat.records!.first;

  //     _logger.d('📋 Checking chat at index $i:');
  //     _logger.d('  Chat Record Chat ID: ${chatRecord.chatId}');
  //     _logger.d('  Chat Record Chat Type: ${chatRecord.chatType}');
  //     _logger.d('  Chat Peer User ID: ${chat.peerUserData?.userId}');

  //     // ✅ PRIORITY 1: Exact chat ID match
  //     if (newMessage.chatId != null &&
  //         chatRecord.chatId != null &&
  //         newMessage.chatId == chatRecord.chatId) {
  //       chatFound = true;
  //       _logger.d('✅ Found exact chat ID match at index $i');

  //       if (!_isMessageAlreadyInChat(chatRecord, newMessage)) {
  //         await _updateChatRecord(chatRecord, newMessage, i);
  //       }
  //       break;
  //     }
  //     // ✅ PRIORITY 2: Individual chat peer matching
  //     else if (chatRecord.chatType?.toLowerCase() != 'group') {
  //       final chatPeerUserId = chat.peerUserData?.userId;

  //       bool isMatch = false;

  //       // Case 1: New message FROM the peer user TO current user
  //       if (newMessage.senderId == chatPeerUserId) {
  //         isMatch = true;
  //         _logger.d('✅ Match: Message FROM peer user $chatPeerUserId');
  //       }
  //       // Case 2: New message FROM current user TO the peer user
  //       else if (newMessage.senderId == currentUserId &&
  //           newMessage.peerUserData?.userId == chatPeerUserId) {
  //         isMatch = true;
  //         _logger.d('✅ Match: Message TO peer user $chatPeerUserId');
  //       }

  //       if (isMatch) {
  //         chatFound = true;
  //         _logger.d('✅ Found individual chat match at index $i');

  //         if (!_isMessageAlreadyInChat(chatRecord, newMessage)) {
  //           await _updateChatRecord(chatRecord, newMessage, i);
  //         }
  //         break;
  //       }
  //     }
  //   }

  //   if (!chatFound) {
  //     _logger.d('❌ No matching chat found, scheduling refresh');

  //     // Schedule a refresh instead of doing it immediately
  //     Future.delayed(Duration(seconds: 1), () {
  //       emitChatList();
  //     });
  //   }
  // }

  Future<void> _updateChatListWithNewMessage(Records newMessage) async {
    // ✅ CRITICAL FIX: Always check archived chats first, regardless of main chat list status
    await _updateArchivedChatWithNewMessage(newMessage);

    if (_chatListData.chats.isEmpty) {
      _logger.d('Chat list is empty, attempting to create new chat entry');

      // ✅ FIX: When chat list is empty, check if we can create a new chat entry
      if (newMessage.messageType == 'group-created' ||
          newMessage.messageType == 'group_created' ||
          (newMessage.chat != null && newMessage.chatId != null) ||
          (newMessage.peerUserData != null)) {
        _logger.d('🔄 Creating new chat entry for message with available data');
        await _createNewChatEntry(newMessage);
      } else {
        _logger.d('❌ Cannot create new chat entry - insufficient data');
        // Still trigger a chat list refresh as fallback
        emitChatList(page: 1);
      }
      return;
    }

    bool chatFound = false;
    final currentUserId = await _getCurrentUserIdAsync();

    _logger.d('🔍 Looking for chat to update:');
    _logger.d('  New Message Chat ID: ${newMessage.chatId}');
    _logger.d('  New Message Sender ID: ${newMessage.senderId}');

    // ✅ STEP 1: First pass - EXACT chat ID matching (prioritizes groups and existing chats)
    if (newMessage.chatId != null && newMessage.chatId! > 0) {
      for (int i = 0; i < _chatListData.chats.length; i++) {
        final chat = _chatListData.chats[i];
        if (chat.records?.isEmpty ?? true) continue;

        final chatRecord = chat.records!.first;

        // ✅ EXACT MATCH: Chat ID must match exactly
        if (chatRecord.chatId == newMessage.chatId) {
          chatFound = true;
          _logger.d(
            '✅ Found EXACT chat ID match at index $i (ID: ${chatRecord.chatId}, Type: ${chatRecord.chatType})',
          );

          if (!_isMessageAlreadyInChat(chatRecord, newMessage)) {
            await _updateChatRecord(chatRecord, newMessage, i);
          }
          break; // ✅ CRITICAL: Stop after exact match
        }
      }
    }

    // ✅ STEP 2: Second pass - Only for individual chats without chat ID (new chats)
    if (!chatFound && (newMessage.chatId == null || newMessage.chatId == 0)) {
      _logger.d(
        '🔍 No exact chat ID match, trying peer user matching for new individual chat...',
      );

      for (int i = 0; i < _chatListData.chats.length; i++) {
        final chat = _chatListData.chats[i];
        if (chat.records?.isEmpty ?? true) continue;

        final chatRecord = chat.records!.first;
        final chatType = chatRecord.chatType?.toLowerCase();

        // ✅ ONLY match with individual chats (not groups)
        if (chatType != 'group') {
          final chatPeerUserId = chat.peerUserData?.userId;

          if (chatPeerUserId != null) {
            bool isMatch = false;

            // Case 1: Message FROM the peer user TO current user
            if (newMessage.senderId == chatPeerUserId) {
              isMatch = true;
              _logger.d('✅ Match: Message FROM peer user $chatPeerUserId');
            }
            // Case 2: Message FROM current user TO the peer user
            else if (newMessage.senderId == currentUserId &&
                newMessage.peerUserData?.userId == chatPeerUserId) {
              isMatch = true;
              _logger.d('✅ Match: Message TO peer user $chatPeerUserId');
            }

            if (isMatch) {
              chatFound = true;
              _logger.d('✅ Found individual chat match at index $i');

              if (!_isMessageAlreadyInChat(chatRecord, newMessage)) {
                await _updateChatRecord(chatRecord, newMessage, i);
              }
              break;
            }
          }
        }
      }
    }

    if (!chatFound) {
      _logger.d('❌ No matching chat found in main list');
      // ✅ UPDATED: Check if this is a group-created message OR if Chat data is available
      if (newMessage.messageType == 'group-created' ||
          newMessage.messageType == 'group_created' ||
          (newMessage.chat != null && newMessage.chatId != null)) {
        _logger.d('🔄 Creating new chat entry for message with Chat data');
        await _createNewChatEntry(newMessage);
      } else {
        // ✅ FIXED: Don't immediately refresh - this can interrupt pagination
        // Instead, only refresh if it's been a while since last update
        final now = DateTime.now().millisecondsSinceEpoch;
        const refreshCooldown = 5000; // 5 seconds

        if (_lastChatRefresh == null ||
            (now - _lastChatRefresh!) > refreshCooldown) {
          _logger.d('🔄 Scheduling controlled refresh...');
          _lastChatRefresh = now;
          Future.delayed(Duration(seconds: 2), () {
            if (_chatListData.chats.isEmpty ||
                !_chatListData.chats.any(
                  (chat) =>
                      chat.records?.any((r) => r.chatId == newMessage.chatId) ==
                      true,
                )) {
              emitChatList(page: 1); // Only refresh first page
            }
          });
        } else {
          _logger.d('⏱️ Refresh on cooldown, skipping');
        }
      }
    }
  }

  /// ✅ NEW: Update archived chat with new message (real-time updates)
  Future<void> _updateArchivedChatWithNewMessage(Records newMessage) async {
    try {
      _logger.d(
        '🗃️ Checking archive update for message: chatId=${newMessage.chatId}, senderId=${newMessage.senderId}',
      );

      // Only update archived chats if ArchiveChatProvider is available
      if (_archiveChatProvider == null) {
        _logger.d('⚠️ ArchiveChatProvider is null, skipping archive update');
        return;
      }

      _logger.d('✅ ArchiveChatProvider available, delegating archive update');

      // Give the archived provider the same context the main chat list uses
      // in `_updateUnreadCount`, so its row badge increments by 1 per foreign
      // message and stays at 0 while that chat is open — instead of echoing
      // `newMessage.unseenCount` (which is a conversationSeq, not a count).
      final currentUserId = await _getCurrentUserIdAsync();
      final newMessageChatId = newMessage.chatId ?? 0;
      final isActivelyViewingThisChat =
          _isChatScreenActive &&
          _isAppInForeground &&
          (_currentChatId ?? 0) > 0 &&
          _currentChatId == newMessageChatId;

      // Delegate to ArchiveChatProvider for archived chat updates
      _archiveChatProvider!.updateArchivedChatWithNewMessage(
        newMessage,
        currentUserId: currentUserId,
        isViewingThisChat: isActivelyViewingThisChat,
      );
    } catch (e) {
      _logger.e('❌ Error updating archived chat with new message: $e');
    }
  }

  /// Create a new chat entry for newly created chats (groups and private)
  Future<void> _createNewChatEntry(Records newMessage) async {
    try {
      _logger.d('🆕 Creating new chat entry for Chat ID: ${newMessage.chatId}');

      // Extract info from the new message
      final chatId = newMessage.chatId;
      final peerUserData = newMessage.peerUserData;
      final chatInfo =
          newMessage.chat; // ✅ Extract Chat object from socket response

      // ✅ Enhanced check: Allow creation with either chatId OR peerUserData
      if (chatId == null && peerUserData == null) {
        _logger.w(
          '❌ Cannot create chat entry - missing both chat ID and peer user data',
        );
        return;
      }

      // ✅ Determine chat type and extract appropriate info
      final chatType =
          chatInfo?.chatType ?? 'private'; // Default to private for new chats

      // ✅ Extract info based on chat type
      final groupName =
          chatType.toLowerCase() == 'group'
              ? (chatInfo?.groupName?.isNotEmpty == true
                  ? chatInfo!.groupName!
                  : 'New Group')
              : ContactNameService.instance.resolveName(
                userId: peerUserData?.userId,
                firstName: peerUserData?.firstName,
                lastName: peerUserData?.lastName,
                fullName: peerUserData?.fullName,
                userName: peerUserData?.userName,
                email: peerUserData?.email,
                fallback: 'Unknown User',
              );

      final groupIcon =
          chatType.toLowerCase() == 'group'
              ? (chatInfo?.groupIcon?.isNotEmpty == true
                  ? chatInfo!.groupIcon!
                  : '')
              : (peerUserData?.profilePic ?? '');

      final groupDescription = chatInfo?.groupDescription ?? '';

      // ✅ Determine if message should be marked as unseen
      final currentUserId = await _getCurrentUserIdAsync();
      final isFromCurrentUser = newMessage.senderId == currentUserId;
      final unseenCount =
          isFromCurrentUser ? 0 : 1; // Don't count own messages as unseen

      _logger.d('✅ Extracted chat info:');
      _logger.d('  Chat Name: $groupName');
      _logger.d('  Chat Icon: $groupIcon');
      _logger.d('  Chat Type: $chatType');
      _logger.d('  Chat ID: $chatId');
      _logger.d('  Unseen Count: $unseenCount');

      // Create a new Messages object from the new message
      final newMessages = chatlist.Messages(
        messageContent: newMessage.messageContent,
        replyTo: newMessage.replyTo ?? 0,
        socialId: newMessage.socialId ?? 0,
        messageId: newMessage.messageId,
        messageType: newMessage.messageType,
        messageLength: newMessage.messageLength ?? '',
        messageSeenStatus: newMessage.messageSeenStatus,
        messageSize: newMessage.messageSize ?? '',
        deletedFor: newMessage.deletedFor ?? [],
        starredFor: newMessage.starredFor ?? [],
        deletedForEveryone: newMessage.deletedForEveryone ?? false,
        pinned: newMessage.pinned ?? false,
        createdAt: newMessage.createdAt,
        updatedAt: newMessage.updatedAt,
        chatId: newMessage.chatId,
        senderId: newMessage.senderId,
        user: newMessage.user,
        social: null,
        calls: [],
      );

      // ✅ Create Records object with chat data
      final newChatRecord = chatlist.Records(
        groupIcon: groupIcon,
        chatId: chatId ?? 0, // Use 0 as fallback if chatId is null
        chatType: chatType,
        groupName: groupName,
        groupDescription: groupDescription,
        deletedAt: null,
        createdAt: newMessage.createdAt,
        updatedAt: newMessage.updatedAt,
        messages: [newMessages],
        unseenCount: unseenCount, // ✅ Proper unseen count logic
        blockedBy: [],
      );

      // Create PeerUserData if available
      chatlist.PeerUserData? peerData;
      if (peerUserData != null) {
        peerData = chatlist.PeerUserData(
          userName: peerUserData.userName ?? '',
          email: peerUserData.email ?? '',
          phoneNumber: '', // Use empty string as fallback
          profilePic: peerUserData.profilePic ?? '',
          userId: peerUserData.userId ?? 0,
          fullName: peerUserData.fullName ?? '',
          firstName: peerUserData.firstName,
          lastName: peerUserData.lastName,
          countryCode: peerUserData.countryCode ?? '',
          country: peerUserData.country ?? '',
          gender: peerUserData.gender ?? '',
          bio: peerUserData.bio ?? '',
          profileVerificationStatus:
              peerUserData.profileVerificationStatus ?? false,
          loginVerificationStatus:
              peerUserData.loginVerificationStatus ?? false,
          socketIds: [], // Use empty list as fallback
          updatedAt: peerUserData.updatedAt,
          createdAt: peerUserData.createdAt,
        );
      }

      // Create a new Chats object
      final newChat = chatlist.Chats(
        records: [newChatRecord],
        peerUserData: peerData,
      );

      // Insert at the beginning of the chat list (most recent first)
      _chatListData.chats.insert(0, newChat);

      _logger.d('✅ Successfully created new chat entry');
      _logger.d('📊 Chat list now has ${_chatListData.chats.length} chats');
      _logger.d(
        '💬 Chat added for: ${chatType == "group" ? "Group" : "Private"} chat with ${peerUserData?.fullName ?? "Unknown"}',
      );

      // Update listeners
      _chatListStreamController.add(_chatListData);
      notifyListeners();
    } catch (e) {
      _logger.e('❌ Error creating new chat entry: $e');
      // Fallback to refresh if creation fails
      emitChatList(page: 1);
    }
  }

  /// Check if message already exists in chat
  bool _isMessageAlreadyInChat(
    chatlist.Records chatRecord,
    Records newMessage,
  ) {
    return chatRecord.messages?.any(
          (msg) => msg.messageId == newMessage.messageId,
        ) ??
        false;
  }

  /// Update chat record with new message
  // Future<void> _updateChatRecord(
  //   chatlist.Records chatRecord,
  //   Records newMessage,
  //   int chatIndex,
  // ) async {
  //   _logger.d('Updating chat record at index $chatIndex');

  //   // Update or create message
  //   if (chatRecord.messages?.isNotEmpty ?? false) {
  //     final lastMessage = chatRecord.messages!.first;
  //     _updateMessageData(lastMessage, newMessage);
  //   } else {
  //     chatRecord.messages = [_createChatListMessage(newMessage)];
  //   }

  //   // Update chat record metadata
  //   chatRecord.createdAt = newMessage.createdAt;
  //   chatRecord.updatedAt = newMessage.updatedAt;

  //   // Update chat ID if it was a new chat
  //   if (chatRecord.chatId == null && newMessage.chatId != null) {
  //     chatRecord.chatId = newMessage.chatId;
  //   }

  //   // Update unread count
  //   await _updateUnreadCount(chatRecord, newMessage);

  //   // Move chat to top of list
  //   final updatedChat = _chatListData.chats.removeAt(chatIndex);
  //   _chatListData.chats.insert(0, updatedChat);

  //   _logger.d('Moved chat to top of list');
  // }

  /// ✅ IMPROVED: Better update logic with more thorough chat matching
  Future<void> _updateChatRecord(
    chatlist.Records chatRecord,
    Records newMessage,
    int chatIndex,
  ) async {
    _logger.d('📝 Updating chat record at index $chatIndex');
    _logger.d('  Chat ID: ${chatRecord.chatId} -> ${newMessage.chatId}');
    _logger.d('  Message: ${newMessage.messageContent}');

    try {
      // ✅ CRITICAL: Update chat ID if it was missing (new chat scenario)
      if (chatRecord.chatId == null && newMessage.chatId != null) {
        _logger.d('🆕 Setting chat ID for new chat: ${newMessage.chatId}');
        chatRecord.chatId = newMessage.chatId;
      }

      // ✅ Update or create message with intelligent handling
      if (chatRecord.messages?.isNotEmpty ?? false) {
        final lastMessage = chatRecord.messages!.first;

        // CRITICAL: Check if this is a brand new message or an update to existing message
        if (newMessage.messageId != null &&
            lastMessage.messageId != null &&
            newMessage.messageId != lastMessage.messageId &&
            newMessage.messageType != 'call') {
          // This is a genuinely new message (different ID, not a call event)
          // Insert it as the new first message
          _logger.d('🆕 Adding completely new message to front of list');
          chatRecord.messages!.insert(0, _createChatListMessage(newMessage));
        } else {
          // This is an update to the existing message (same ID or call event)
          _updateMessageData(lastMessage, newMessage);
          _logger.d('📝 Updated existing message data');
        }
      } else {
        chatRecord.messages = [_createChatListMessage(newMessage)];
        _logger.d('🆕 Created new message entry');
      }

      // ✅ Update chat record metadata
      chatRecord.createdAt = newMessage.createdAt;
      chatRecord.updatedAt = newMessage.updatedAt;

      // ✅ Update group information if available
      if (newMessage.chatId != null &&
          chatRecord.chatType?.toLowerCase() == 'group') {
        // You might want to update group info from the Chat object in the response
        _logger.d('📝 Updated group chat metadata');
      }

      // ✅ Update unread count
      await _updateUnreadCount(chatRecord, newMessage);

      // ✅ Move chat to top of list (most recent first)
      final updatedChat = _chatListData.chats.removeAt(chatIndex);
      _chatListData.chats.insert(0, updatedChat);

      _logger.d('✅ Moved chat to top of list');
      _logger.d('📊 Chat list now has ${_chatListData.chats.length} chats');
    } catch (e) {
      _logger.e('❌ Error updating chat record: $e');
      // Don't throw, just log the error and refresh the list
      emitChatList();
    }
  }

  /// Update message data in chat list
  /// ✅ HELPER: Update existing message data while preserving important fields
  void _updateMessageData(chatlist.Messages lastMessage, Records newMessage) {
    _logger.d('🔄 Updating message data:');
    _logger.d(
      '  Old: ${lastMessage.messageContent} (Type: ${lastMessage.messageType})',
    );
    _logger.d(
      '  New: ${newMessage.messageContent} (Type: ${newMessage.messageType})',
    );
    _logger.d('  Old calls count: ${lastMessage.calls?.length ?? 0}');
    _logger.d('  New calls count: ${newMessage.calls?.length ?? 0}');

    // CRITICAL FIX: Only replace with newer messages, not call events updating existing messages
    final oldMessageId = lastMessage.messageId;
    final newMessageId = newMessage.messageId;

    // If this is truly a newer/different message, update all fields
    if (newMessageId != null &&
        (oldMessageId == null || newMessageId > oldMessageId)) {
      _logger.d(
        '✅ Updating to newer message ID: $oldMessageId -> $newMessageId',
      );

      lastMessage.messageContent = newMessage.messageContent;
      lastMessage.messageType = newMessage.messageType;
      lastMessage.createdAt = newMessage.createdAt;
      lastMessage.updatedAt = newMessage.updatedAt;
      lastMessage.messageId = newMessage.messageId;
      lastMessage.senderId = newMessage.senderId;
      lastMessage.messageSeenStatus = newMessage.messageSeenStatus;

      // Update calls array if provided
      if (newMessage.calls != null && newMessage.calls!.isNotEmpty) {
        lastMessage.calls = newMessage.calls;
        _logger.d(
          '✅ Updated calls array with ${newMessage.calls!.length} calls',
        );
      }

      // Update user data if provided
      if (newMessage.user != null) {
        lastMessage.user = newMessage.user;
      }

      // ✅ CRITICAL FIX: Update actionedUser for member-left/removed/added messages
      // DEFENSIVE: Never overwrite existing actionedUser with null - preserve it!
      if (newMessage.actionedUser != null) {
        lastMessage.actionedUser = chatlist.User(
          userId: newMessage.actionedUser!.userId,
          userName: newMessage.actionedUser!.userName,
          fullName: newMessage.actionedUser!.fullName,
          profilePic: newMessage.actionedUser!.profilePic,
        );
        _logger.d('✅ Updated actionedUser: ${newMessage.actionedUser!.userId}');
      } else if (lastMessage.actionedUser != null) {
        // ANTI-FLICKER: Preserve existing actionedUser if new message doesn't have it
        _logger.d(
          '⚠️ Preserving existing actionedUser: ${lastMessage.actionedUser!.userId}',
        );
      }
    }
    // If it's the same message ID, only update specific fields (for call events)
    else if (newMessageId != null && oldMessageId == newMessageId) {
      _logger.d(
        '🔄 Updating same message ID: $newMessageId (likely call event update)',
      );

      // Only update timestamp and seen status for same message
      lastMessage.updatedAt = newMessage.updatedAt ?? lastMessage.updatedAt;
      lastMessage.messageSeenStatus =
          newMessage.messageSeenStatus ?? lastMessage.messageSeenStatus;

      // Update calls array if provided (this handles call_end events)
      if (newMessage.calls != null && newMessage.calls!.isNotEmpty) {
        lastMessage.calls = newMessage.calls;
        _logger.d('🔄 Updated calls array for existing message');
      }

      // Update message content ONLY for call messages to reflect final status
      if (lastMessage.messageType == 'call' &&
          newMessage.messageContent != null) {
        lastMessage.messageContent = newMessage.messageContent;
        _logger.d(
          '🔄 Updated call message content: ${newMessage.messageContent}',
        );
      }
    }
    // Fallback for cases where we don't have clear message ID info
    else {
      _logger.d('⚠️  Fallback update - preserving calls array');

      // Preserve the calls array from the old message if new message doesn't have calls
      final oldCalls = lastMessage.calls;

      lastMessage.messageContent = newMessage.messageContent;
      lastMessage.messageType = newMessage.messageType;
      lastMessage.createdAt = newMessage.createdAt;
      lastMessage.updatedAt = newMessage.updatedAt;
      lastMessage.messageId = newMessage.messageId;
      lastMessage.senderId = newMessage.senderId;
      lastMessage.messageSeenStatus = newMessage.messageSeenStatus;

      // Preserve or update calls array intelligently
      if (newMessage.calls != null && newMessage.calls!.isNotEmpty) {
        lastMessage.calls = newMessage.calls;
        _logger.d('✅ Updated with new calls array');
      } else if (oldCalls != null && oldCalls.isNotEmpty) {
        // Keep the old calls array if new message doesn't have calls
        lastMessage.calls = oldCalls;
        _logger.d('✅ Preserved existing calls array');
      }

      // ✅ CRITICAL FIX: Update actionedUser for member-left/removed/added messages
      // DEFENSIVE: Never overwrite existing actionedUser with null - preserve it!
      if (newMessage.actionedUser != null) {
        lastMessage.actionedUser = chatlist.User(
          userId: newMessage.actionedUser!.userId,
          userName: newMessage.actionedUser!.userName,
          fullName: newMessage.actionedUser!.fullName,
          profilePic: newMessage.actionedUser!.profilePic,
        );
        _logger.d('✅ Updated actionedUser: ${newMessage.actionedUser!.userId}');
      } else if (lastMessage.actionedUser != null) {
        // ANTI-FLICKER: Preserve existing actionedUser if new message doesn't have it
        _logger.d(
          '⚠️ Preserving existing actionedUser: ${lastMessage.actionedUser!.userId}',
        );
      }
    }

    // Update chat ID if it was missing
    if (lastMessage.chatId == null && newMessage.chatId != null) {
      lastMessage.chatId = newMessage.chatId;
    }

    _logger.d('📊 Final message state:');
    _logger.d('  Content: ${lastMessage.messageContent}');
    _logger.d('  Type: ${lastMessage.messageType}');
    _logger.d('  Calls: ${lastMessage.calls?.length ?? 0}');
    _logger.d('  Message ID: ${lastMessage.messageId}');
  }

  /// ✅ HELPER: Create a properly formatted chat list message
  chatlist.Messages _createChatListMessage(Records newMessage) {
    _logger.d('🆕 Creating new chat list message:');
    _logger.d('  Content: ${newMessage.messageContent}');
    _logger.d('  Type: ${newMessage.messageType}');
    _logger.d('  Calls count: ${newMessage.calls?.length ?? 0}');
    _logger.d('  ActionedUser: ${newMessage.actionedUser?.userId ?? 'null'}');

    return chatlist.Messages(
      messageContent: newMessage.messageContent,
      messageType: newMessage.messageType,
      createdAt: newMessage.createdAt,
      updatedAt: newMessage.updatedAt,
      messageId: newMessage.messageId,
      senderId: newMessage.senderId,
      messageSeenStatus: newMessage.messageSeenStatus,
      chatId: newMessage.chatId,
      calls: newMessage.calls, // CRITICAL FIX: Include calls array
      user: newMessage.user, // Include user data
      actionedUser:
          newMessage.actionedUser != null
              ? chatlist.User(
                userId: newMessage.actionedUser!.userId,
                userName: newMessage.actionedUser!.userName,
                fullName: newMessage.actionedUser!.fullName,
                profilePic: newMessage.actionedUser!.profilePic,
              )
              : null, // ✅ CRITICAL FIX: Include actionedUser for member-left messages
    );
  }

  // /// Update unread count for chat
  // Future<void> _updateUnreadCount(
  //   chatlist.Records chatRecord,
  //   Records newMessage,
  // ) async {
  //   final currentUserId = await _getCurrentUserIdAsync();

  //   if (newMessage.senderId != currentUserId) {
  //     // Message from another user
  //     final currentChatId = _currentChatId ?? 0;
  //     final newMessageChatId = newMessage.chatId ?? 0;

  //     // ✅ FIXED: Check if user is actively viewing THIS specific chat
  //     final isActivelyViewingThisChat =
  //         _isChatScreenActive &&
  //         _isAppInForeground &&
  //         currentChatId > 0 &&
  //         currentChatId == newMessageChatId;

  //     if (isActivelyViewingThisChat) {
  //       // Chat is currently active - keep unread count at 0
  //       chatRecord.unseenCount = 0;
  //       _logger.d('Chat is active, keeping unread count at 0');

  //       // ✅ NEW: Auto-mark the new message as seen
  //       if (newMessage.messageId != null) {
  //         Future.delayed(Duration(milliseconds: 300), () {
  //           emitMessageSeen(newMessageChatId, newMessage.messageId!);
  //         });
  //       }
  //     } else {
  //       // Chat is not currently active - increment unread count
  //       chatRecord.unseenCount = (chatRecord.unseenCount ?? 0) + 1;
  //       _logger.d('Incremented unread count to: ${chatRecord.unseenCount}');
  //     }
  //   } else {
  //     // Message from current user - don't increment unread count
  //     _logger.d('Message from current user, not incrementing unread count');
  //   }
  // }
  /// ✅ ENHANCED: Better unread count logic with proper user context
  Future<void> _updateUnreadCount(
    chatlist.Records chatRecord,
    Records newMessage,
  ) async {
    try {
      final currentUserId = await _getCurrentUserIdAsync();

      _logger.d('📊 Updating unread count:');
      _logger.d('  Current User ID: $currentUserId');
      _logger.d('  Message Sender ID: ${newMessage.senderId}');
      _logger.d('  Current Chat ID: $_currentChatId');
      _logger.d('  Message Chat ID: ${newMessage.chatId}');
      _logger.d('  Is Chat Screen Active: $_isChatScreenActive');
      _logger.d('  Is App In Foreground: $_isAppInForeground');

      // ✅ Only increment unread count for messages from other users
      if (newMessage.senderId != currentUserId) {
        // Message from another user
        final currentChatId = _currentChatId ?? 0;
        final newMessageChatId = newMessage.chatId ?? 0;

        // ✅ CRITICAL FIX: Check if user is actively viewing THIS specific chat
        final isActivelyViewingThisChat =
            _isChatScreenActive &&
            _isAppInForeground &&
            currentChatId > 0 &&
            currentChatId == newMessageChatId;

        _logger.d(
          '  Is Actively Viewing This Chat: $isActivelyViewingThisChat',
        );

        if (isActivelyViewingThisChat) {
          // Chat is currently active - keep unread count at 0
          chatRecord.unseenCount = 0;
          _logger.d('✅ Chat is active, keeping unread count at 0');

          // ✅ Auto-mark the new message as seen after a short delay
          if (newMessage.messageId != null && newMessageChatId > 0) {
            Future.delayed(Duration(milliseconds: 500), () {
              _logger.d('📩 Auto-marking message as seen');
              emitMessageSeen(newMessageChatId, newMessage.messageId!);
            });
          }
        } else {
          // Chat is not currently active - increment unread count
          final oldCount = chatRecord.unseenCount ?? 0;
          chatRecord.unseenCount = oldCount + 1;
          _logger.d(
            '📈 Incremented unread count: $oldCount -> ${chatRecord.unseenCount}',
          );
        }
      } else {
        // Message from current user - keep unread count as is (don't increment)
        _logger.d(
          '⏭️ Message from current user, not incrementing unread count',
        );
      }
    } catch (e) {
      _logger.e('❌ Error updating unread count: $e');
      // Fallback: increment unread count if we can't determine user context
      if (chatRecord.unseenCount == null) {
        chatRecord.unseenCount = 1;
      } else {
        chatRecord.unseenCount = chatRecord.unseenCount! + 1;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DELETE CHAT METHOD
  // ═══════════════════════════════════════════════════════════════════════════

  // ✅ NEW: Setup message deletion event listeners
  /// NEW has no delete-for-me broadcast at all — it's private to the
  /// requester (ChatProvider.deleteMessageForMe removes it locally right
  /// after its own REST call succeeds). Only delete-for-everyone is pushed
  /// live, as `message_deleted` (`{messageId, conversationId}`, confirmed
  /// against ServerEvents in socket.types.ts) — this is what propagates the
  /// deletion to the *other* participants' devices.
  void _setupMessageDeletionListeners() {
    _socketService.on(_socketEvents.messageDeletedEvent, (data) {
      _logger.d('🗑️ Received message_deleted: $data');
      _handleMessageDeletedEvent(data);
    });
  }

  void _handleMessageDeletedEvent(dynamic data) {
    try {
      if (data is! Map) {
        _logger.w('⚠️ Unexpected message_deleted format: ${data.runtimeType}');
        return;
      }
      final messageId = int.tryParse((data['messageId'] ?? '').toString());
      final chatId = int.tryParse((data['conversationId'] ?? '').toString());
      if (messageId == null || chatId == null) {
        _logger.w('⚠️ message_deleted missing messageId/conversationId');
        return;
      }

      if (_chatsData.records != null) {
        for (int i = 0; i < _chatsData.records!.length; i++) {
          final record = _chatsData.records![i];
          if (record.messageId == messageId && record.chatId == chatId) {
            record.messageContent = 'This message was deleted.';
            record.deletedForEveryone = true;

            _chatsStreamController.add(_chatsData);
            notifyListeners();

            _updateChatListAfterDeletion(
              messageId,
              chatId,
              isDeletedForEveryone: true,
            );
            break;
          }
        }
      }
    } catch (e) {
      _logger.e('❌ Error handling message_deleted: $e');
    }
  }

  // ✅ NEW: Update chat list after message deletion
  void _updateChatListAfterDeletion(
    int messageId,
    int chatId, {
    bool isDeletedForEveryone = false,
  }) {
    try {
      if (_chatListData.chats.isEmpty) return;

      for (int i = 0; i < _chatListData.chats.length; i++) {
        final chat = _chatListData.chats[i];

        if (chat.records?.isNotEmpty == true) {
          final chatRecord = chat.records!.first;

          // Check if this chat matches
          if (chatRecord.chatId == chatId) {
            // Check if the deleted message was the latest message
            if (chatRecord.messages?.isNotEmpty == true) {
              final latestMessage = chatRecord.messages!.first;

              if (latestMessage.messageId == messageId) {
                if (isDeletedForEveryone) {
                  // Update the message content to show "This message was deleted."
                  latestMessage.messageContent = "This message was deleted.";
                  latestMessage.messageType =
                      "text"; // Keep as text type for consistency
                } else {
                  // For delete for me, we need to refresh to get the previous message
                  _refreshChatListAfterLocalDeletion(chatId);
                  return;
                }

                // Notify chat list update
                _chatListStreamController.add(_chatListData);
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      _logger.e('❌ Error updating chat list after deletion: $e');
    }
  }

  // ✅ NEW: Refresh chat list after local deletion
  void _refreshChatListAfterLocalDeletion(int chatId) {
    // Trigger a refresh of the chat list to get the updated latest message
    Future.delayed(Duration(milliseconds: 500), () {
      refreshChatList(silent: true);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE UPDATED (EDIT) / CLEAR CHAT
  // ═══════════════════════════════════════════════════════════════════════════

  /// `message_updated` carries the full updated message. Patch this
  /// controller's own copy first — its `_chatsData` is re-merged into
  /// ChatProvider on every later `new_message` and the socket copy wins an
  /// id collision there, so a stale copy here would resurrect the old text —
  /// then hand the payload to ChatProvider, which owns the full history,
  /// chat-list preview and cache.
  void _setupMessageUpdatedListener() {
    // Re-run on every re-init/reconnect; drop the previous callback first so
    // socket.io doesn't stack one handler per run.
    _socketService.off(_socketEvents.messageUpdated);
    _socketService.on(_socketEvents.messageUpdated, (data) {
      _logger.d('✏️ Received message_updated: $data');
      try {
        if (data is! Map) {
          _logger.w(
            '⚠️ Unexpected message_updated format: ${data.runtimeType}',
          );
          return;
        }
        final message = MessageDto.fromJson(data.cast<String, dynamic>());
        if (message.id.isEmpty) return;
        applyMessageUpdateLocally(message);
        _messageUpdatedStreamController.add(message);
      } catch (e) {
        _logger.e('❌ Error handling message_updated: $e');
      }
    });
  }

  /// Patches the matching record (if this controller holds it) in place.
  /// Silent on purpose — ChatProvider re-renders from its own list, and
  /// emitting `chatsStream` here would trigger a needless full re-merge.
  void applyMessageUpdateLocally(MessageDto message) {
    final messageId = int.tryParse(message.id);
    final records = _chatsData.records;
    if (messageId == null || records == null) return;
    for (final record in records) {
      if (record.messageId == messageId) {
        MessageAdapter.applyUpdate(record, message);
        break;
      }
    }
  }

  /// Drops every message of [chatId] this controller still holds after the
  /// user cleared (or deleted) that chat. Without this, the next
  /// `new_message` re-emits this controller's session list and ChatProvider
  /// merges the cleared messages straight back into view.
  void clearMessagesForChat(int chatId) {
    final records = _chatsData.records;
    if (records == null || records.isEmpty) return;
    _chatsData.records =
        records.where((record) => record.chatId != chatId).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE SEEN STATUS METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Enhanced emit message seen with strict validation
  void emitMessageSeen(int chatId, int messageId) async {
    try {
      // Get current user ID first
      final currentUserId = await _getCurrentUserIdAsync();
      if (currentUserId == null) {
        _logger.w(
          'Cannot mark message as seen - current user ID not available',
        );
        return;
      }

      // ✅ STRICT VALIDATION: Log all validation checks
      _logger.d('🔍 VALIDATION START for message $messageId:');

      final isAlreadyTracked = _seenMessages.contains(messageId);
      _logger.d('  - Already tracked as seen: $isAlreadyTracked');

      bool isLocallyMarkedSeen = false;
      bool isMyOwnMessage = false;
      // conversationSeq is carried in `unseenCount` (see
      // MessageAdapter.toRecord) — NEW's read-receipt model is a
      // per-conversation watermark, not a per-message event, so this is
      // what actually gets sent as `upToSeq` below.
      int? messageSeq;
      if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
        final message = _chatsData.records!.firstWhere(
          (msg) => msg.messageId == messageId,
          orElse: () => Records(),
        );
        isLocallyMarkedSeen = message.messageSeenStatus == 'seen';
        isMyOwnMessage = message.senderId == currentUserId;
        messageSeq = message.unseenCount;
        _logger.d(
          '  - Locally marked as seen: $isLocallyMarkedSeen (status: ${message.messageSeenStatus})',
        );
        _logger.d(
          '  - Message sender: ${message.senderId} (current user: $currentUserId) - isMyMessage: $isMyOwnMessage',
        );

        // ✅ CRITICAL FIX: Only skip if message is from current user (my own message)
        if (isMyOwnMessage) {
          _logger.d(
            '  - ❌ SKIPPED: This is my own message, no need to mark as seen',
          );
          return;
        }
      }

      // ✅ ENHANCED DUPLICATE CHECK: Only skip if already tracked AND locally seen
      if (isAlreadyTracked && isLocallyMarkedSeen) {
        _logger.d(
          '❌ SKIPPED: Message $messageId already fully processed (tracked: $isAlreadyTracked, seen: $isLocallyMarkedSeen)',
        );
        return;
      }

      // ✅ FORCE EMIT: Even if tracked but not locally seen, emit again
      if (isAlreadyTracked && !isLocallyMarkedSeen) {
        _logger.w(
          '⚠️ RE-EMITTING: Message $messageId was tracked but not confirmed locally seen',
        );
        _seenMessages.remove(messageId); // Remove to allow re-emission
      }

      _logger.d(
        '✅ VALIDATION PASSED: Proceeding with emission for message $messageId',
      );
      _logger.d(
        '🚀 EMITTING message seen - chatId: $chatId, messageId: $messageId, currentUserId: $currentUserId',
      );

      // Add to seen messages set BEFORE emitting to prevent race conditions
      _seenMessages.add(messageId);

      // ✅ IMMEDIATE LOCAL UPDATE: Update UI immediately for better UX
      _logger.d(
        '🔄 IMMEDIATE: Updating local message $messageId status to seen',
      );
      bool localUpdateSuccess = await _updateMessageSeenStatus(
        messageId,
        'seen',
        null, // senderId doesn't matter for immediate local update
        currentUserId,
      );

      if (localUpdateSuccess) {
        // ✅ IMMEDIATE UI UPDATE: Force UI refresh
        _chatsStreamController.add(_chatsData);
        notifyListeners();
        _logger.d('🔄 IMMEDIATE: Local UI updated for message $messageId');
      }

      // NEW has no per-message seen event — it's a per-conversation
      // watermark (`message_read` -> `{conversationId, upToSeq}`, broadcast
      // to the room as `message_read_update`). Without a known seq for this
      // message there's nothing valid to send as `upToSeq`, so skip the
      // live broadcast in that case (the REST watermark call in
      // ChatProvider.markChatMessagesAsSeen still persists the read state).
      if (messageSeq != null && messageSeq > 0) {
        _socketService.emit(
          _socketEvents.messageRead,
          data: {"conversationId": chatId.toString(), "upToSeq": messageSeq},
        );
        _logger.d(
          '✅ SUCCESS: message_read emitted for chat $chatId up to seq $messageSeq',
        );
      } else {
        _logger.w(
          '⚠️ Skipped message_read emit for messageId $messageId — no known conversationSeq',
        );
      }

      // ✅ TRACK EMISSION FOR DEBUGGING
      _trackEmissionForDebugging(chatId, messageId);
    } catch (e) {
      _logger.e('❌ ERROR emitting message seen event: $e');
      _setError('Failed to mark message as seen: ${e.toString()}');
      // Remove from seen messages set if emission failed
      _seenMessages.remove(messageId);

      // ✅ TRACK FAILED EMISSION
      _logger.e('❌ FAILED EMISSION for messageId: $messageId, chatId: $chatId');
    }
  }

  /// Emit the per-conversation read watermark so the OTHER participant's
  /// client gets a live `message_read_update` and flips our sent bubbles to
  /// the blue tick. The backend broadcasts `message_read_update` ONLY from
  /// the socket `message_read` handler — the REST `POST /messages/:id/read`
  /// endpoint (ChatProvider.markChatMessagesAsSeen) persists the watermark
  /// but fires no socket fan-out — so without this emit the sender never
  /// sees "read" until they reload the chat. Backend also runs markRead()
  /// itself inside this handler (idempotent, forward-only), so emitting in
  /// addition to the REST call is safe.
  void emitConversationRead(int chatId, int upToSeq) {
    if (chatId <= 0 || upToSeq <= 0) return;
    try {
      _socketService.emit(
        _socketEvents.messageRead,
        data: {'conversationId': chatId.toString(), 'upToSeq': upToSeq},
      );
      _logger.d('✅ message_read emitted for chat $chatId up to seq $upToSeq');
    } catch (e) {
      _logger.e('❌ Failed to emit message_read for chat $chatId: $e');
    }
  }

  /// Track emissions for debugging the 7 vs 4 issue
  final Map<int, Map<String, dynamic>> _emissionTracker = {};

  void _trackEmissionForDebugging(int chatId, int messageId) {
    final key = messageId;
    _emissionTracker[key] = {
      'chatId': chatId,
      'messageId': messageId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'emitted': true,
    };

    _logger.d(
      '📊 EMISSION TRACKED: Total emissions in session: ${_emissionTracker.length}',
    );
    _logger.d('📊 EMISSION LIST: ${_emissionTracker.keys.toList()}');
  }

  /// Get emission statistics for debugging
  Map<String, dynamic> getEmissionStats() {
    final totalEmissions = _emissionTracker.length;
    final emittedMessages = _emissionTracker.keys.toList();
    final totalAcknowledged = _emissionStats['acknowledged'] ?? 0;

    return {
      'totalEmissions': totalEmissions,
      'totalAcknowledged': totalAcknowledged,
      'emittedMessageIds': emittedMessages,
      'seenMessagesCache': _seenMessages.toList(),
      'lastEmissionTime':
          _emissionTracker.values.isNotEmpty
              ? _emissionTracker.values.last['timestamp']
              : null,
      'emissionAckRatio':
          totalEmissions > 0 ? totalAcknowledged / totalEmissions : 0.0,
      'missingAcknowledgments': totalEmissions - totalAcknowledged,
    };
  }

  /// Get a detailed report of emission vs acknowledgment discrepancies
  Map<String, dynamic> getEmissionVsAcknowledgmentReport() {
    final stats = getEmissionStats();
    final totalEmissions = stats['totalEmissions'] as int;
    final totalAcknowledged = stats['totalAcknowledged'] as int;

    return {
      'summary': {
        'totalEmissions': totalEmissions,
        'totalAcknowledged': totalAcknowledged,
        'missingAcknowledgments': totalEmissions - totalAcknowledged,
        'successRate':
            totalEmissions > 0
                ? '${(totalAcknowledged / totalEmissions * 100).toStringAsFixed(1)}%'
                : '0%',
      },
      'details': {
        'emittedMessageIds': stats['emittedMessageIds'],
        'seenMessagesCache': stats['seenMessagesCache'],
        'emissionTracker': _emissionTracker,
        'emissionStats': _emissionStats,
      },
      'recommendations': _generateRecommendations(
        totalEmissions,
        totalAcknowledged,
      ),
    };
  }

  List<String> _generateRecommendations(int emissions, int acknowledgments) {
    final recommendations = <String>[];

    if (emissions == 0) {
      recommendations.add(
        'No emissions detected - check if markMessageAsSeen is being called',
      );
    } else if (acknowledgments == 0) {
      recommendations.add(
        'No acknowledgments received - check socket connection and event listeners',
      );
    } else if (acknowledgments < emissions) {
      final missing = emissions - acknowledgments;
      recommendations.add(
        '$missing acknowledgments missing - possible socket delivery issues',
      );
      recommendations.add(
        'Check network connectivity and server-side event handling',
      );
    } else if (acknowledgments > emissions) {
      recommendations.add(
        'More acknowledgments than emissions - possible duplicate event handling',
      );
    } else {
      recommendations.add(
        'Emission and acknowledgment counts match - system working correctly',
      );
    }

    return recommendations;
  }

  /// Batch emit multiple message seen events with strict validation
  /// Recommended for bulk operations to ensure no messages are lost
  Future<Map<String, dynamic>> batchEmitMessagesSeen({
    required int chatId,
    required List<int> messageIds,
    int batchSize = 5,
    Duration delayBetweenBatches = const Duration(milliseconds: 100),
  }) async {
    _logger.d(
      '🎯 BATCH EMISSION: Starting to emit ${messageIds.length} message seen events',
    );
    _logger.d('📋 MESSAGE IDS: $messageIds');
    _logger.d(
      '⚙️  BATCH SIZE: $batchSize, DELAY: ${delayBetweenBatches.inMilliseconds}ms',
    );

    final results = {
      'totalIntended': messageIds.length,
      'totalSuccessful': 0,
      'totalFailed': 0,
      'successfulIds': <int>[],
      'failedIds': <int>[],
      'errors': <String>[],
      'batchResults': <Map<String, dynamic>>[],
    };

    // Split into batches
    final batches = <List<int>>[];
    for (int i = 0; i < messageIds.length; i += batchSize) {
      final end =
          (i + batchSize < messageIds.length)
              ? i + batchSize
              : messageIds.length;
      batches.add(messageIds.sublist(i, end));
    }

    _logger.d('📦 SPLIT INTO ${batches.length} BATCHES');

    // Process each batch
    for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batch = batches[batchIndex];
      _logger.d(
        '📦 PROCESSING BATCH ${batchIndex + 1}/${batches.length}: ${batch.length} messages',
      );

      final batchResult = {
        'batchIndex': batchIndex + 1,
        'messageIds': batch,
        'successful': <int>[],
        'failed': <int>[],
        'errors': <String>[],
      };

      // Process each message in the batch
      for (final messageId in batch) {
        try {
          // Use the existing strict validation emission method
          await Future.microtask(() => emitMessageSeen(chatId, messageId));

          (batchResult['successful'] as List<int>).add(messageId);
          (results['successfulIds'] as List<int>).add(messageId);
          results['totalSuccessful'] = (results['totalSuccessful'] as int) + 1;

          _logger.d(
            '✅ BATCH SUCCESS: Message $messageId emitted in batch ${batchIndex + 1}',
          );
        } catch (e) {
          final error = 'Failed to emit message $messageId: $e';
          (batchResult['failed'] as List<int>).add(messageId);
          (batchResult['errors'] as List<String>).add(error);
          (results['failedIds'] as List<int>).add(messageId);
          (results['errors'] as List<String>).add(error);
          results['totalFailed'] = (results['totalFailed'] as int) + 1;

          _logger.e(
            '❌ BATCH FAILURE: Message $messageId failed in batch ${batchIndex + 1}: $e',
          );
        }
      }

      (results['batchResults'] as List<Map<String, dynamic>>).add(batchResult);

      // Add delay between batches to prevent overwhelming the socket
      if (batchIndex < batches.length - 1 &&
          delayBetweenBatches.inMilliseconds > 0) {
        _logger.d(
          '⏱️  BATCH DELAY: Waiting ${delayBetweenBatches.inMilliseconds}ms before next batch',
        );
        await Future.delayed(delayBetweenBatches);
      }
    }

    // Final report
    final totalIntended = results['totalIntended'] as int;
    final totalSuccessful = results['totalSuccessful'] as int;
    final totalFailed = results['totalFailed'] as int;

    final successRate =
        totalIntended > 0
            ? (totalSuccessful / totalIntended * 100).toStringAsFixed(1)
            : '0.0';

    _logger.d('📊 BATCH EMISSION COMPLETE:');
    _logger.d('  - Total Intended: $totalIntended');
    _logger.d('  - Total Successful: $totalSuccessful');
    _logger.d('  - Total Failed: $totalFailed');
    _logger.d('  - Success Rate: $successRate%');

    if (totalFailed > 0) {
      _logger.w('⚠️  FAILED MESSAGE IDS: ${results['failedIds']}');
    }

    return results;
  }

  /// Clear emission tracking (call when switching chats)
  void clearEmissionTracking() {
    _emissionTracker.clear();
    _emissionStats.clear();
    _logger.d('🧹 EMISSION TRACKING CLEARED');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPOSE METHOD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Setup archive chat event listeners
  // ❌ _setupArchiveChatListeners/_handleArchiveStatusChange REMOVED —
  // `archive_chat`/`archived_chat_list` don't exist on the new backend at
  // all (confirmed absent from ServerEvents in socket.types.ts); archiving
  // is REST-only (`PATCH /conversations/:id/archive`|`/unarchive`,
  // reflected via `GET /conversations?archived=true`). ArchiveChatProvider
  // already loads/refreshes via `ConversationRepository.getConversations`
  // (see `fetchArchivedChats`), and `ChatProvider.addArchivedChatId`/
  // `removeArchivedChatId` already update local state right after the
  // local archive/unarchive REST action succeeds — neither depended on
  // these dead listeners.

  /// Set the ArchiveChatProvider after it's available. Only stores the
  /// reference now — see the note above for why there's no socket listener
  /// setup here anymore. `updateArchivedChatWithNewMessage` (used by the
  /// live `new_message` handler) still needs this reference.
  void setArchiveChatProvider(ArchiveChatProvider archiveChatProvider) {
    _archiveChatProvider = archiveChatProvider;
    _logger.i('🔗 ArchiveChatProvider reference set');
  }

  /// Setup missed call event listener
  void _setupMissedCallListener() {
    _socketService.on(_socketEvents.missCall, (data) {
      _logger.d('Received missed call event: $data');

      try {
        // Parse missed call data
        final Map<String, dynamic> missedCallData = {};

        if (data is Map<String, dynamic>) {
          missedCallData.addAll(data);
        }

        final int? chatId = missedCallData['chat_id'];
        final int? messageId = missedCallData['message_id'];

        if (chatId == null) {
          _logger.e('Missing chat_id in missed call data');
          return;
        }

        _logger.i(
          'Processing missed call for chat_id: $chatId, message_id: $messageId',
        );

        // Update the chat list to show "missed call" as the latest message
        _updateChatWithMissedCallMessage(chatId, messageId, missedCallData);

        // Also update current chat messages if user is viewing this chat
        _updateCurrentChatWithMissedCallMessage(
          chatId,
          messageId,
          missedCallData,
        );
      } catch (e, stackTrace) {
        _logger.e('Error handling missed call: $e');
        _logger.e('Stack trace: $stackTrace');
      }
    });

    _logger.i('Missed call event listener setup completed');
  }

  /// Update chat with missed call message
  void _updateChatWithMissedCallMessage(
    int chatId,
    int? messageId,
    Map<String, dynamic> missedCallData,
  ) {
    try {
      // Find the chat in the chat list
      final chatIndex = _chatListData.chats.indexWhere((chat) {
        final record =
            chat.records?.isNotEmpty == true ? chat.records!.first : null;
        return record?.chatId == chatId;
      });

      if (chatIndex == -1) {
        _logger.w('Chat with ID $chatId not found in chat list');
        return;
      }

      final targetChat = _chatListData.chats[chatIndex];
      final chatRecord =
          targetChat.records?.isNotEmpty == true
              ? targetChat.records!.first
              : null;

      if (chatRecord == null) {
        _logger.e('No chat record found for chat ID $chatId');
        return;
      }

      // Create or update the latest message with "missed call" content
      chatRecord.messages ??= [];

      // Check if we need to create a new message or update existing one
      if (messageId != null && chatRecord.messages!.isNotEmpty) {
        // Try to find existing message by ID
        final existingMessageIndex = chatRecord.messages!.indexWhere(
          (msg) => msg.messageId == messageId,
        );

        if (existingMessageIndex != -1) {
          // Update existing message
          chatRecord.messages![existingMessageIndex].messageContent =
              "callmissed";

          // CRITICAL FIX: Also update the call status and users array for ChatList
          if (chatRecord.messages![existingMessageIndex].calls != null &&
              chatRecord.messages![existingMessageIndex].calls!.isNotEmpty) {
            for (var call
                in chatRecord.messages![existingMessageIndex].calls!) {
              call.callStatus = "missed";
              // Update users array from missed call event for correct logic
              if (missedCallData['users'] != null) {
                call.users =
                    (missedCallData['users'] as List)
                        .map(
                          (e) => e is int ? e : int.tryParse(e.toString()) ?? 0,
                        )
                        .toList();
              }
            }
            _logger.i(
              'Updated ChatList call status to "missed" and users array in calls array for message $messageId',
            );
          }

          _logger.i(
            'Updated existing message $messageId with "callmissed" content',
          );
        } else {
          // Add new message at the beginning (most recent)
          chatRecord.messages!.insert(
            0,
            chatlist.Messages(
              messageId: messageId,
              messageContent: "callmissed",
              messageType: "call",
              chatId: chatId,
              senderId: missedCallData['user_id'] ?? missedCallData['peer_id'],
              createdAt: DateTime.now().toIso8601String(),
              updatedAt: DateTime.now().toIso8601String(),
            ),
          );
          _logger.i('Added new missed call message with ID $messageId');
        }
      } else {
        // No message ID provided or no existing messages, create new message
        final newMessageId = messageId ?? DateTime.now().millisecondsSinceEpoch;
        chatRecord.messages!.insert(
          0,
          chatlist.Messages(
            messageId: newMessageId,
            messageContent: "callmissed",
            messageType: "call",
            chatId: chatId,
            senderId: missedCallData['user_id'] ?? missedCallData['peer_id'],
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        _logger.i(
          'Added new missed call message with generated ID $newMessageId',
        );
      }

      // Update chat timestamp to ensure proper sorting
      final currentTime = DateTime.now().toIso8601String();
      chatRecord.updatedAt = currentTime;

      // Also update the message timestamp to be the most recent
      if (chatRecord.messages?.isNotEmpty == true) {
        chatRecord.messages!.first.updatedAt = currentTime;
        chatRecord.messages!.first.createdAt = currentTime;
      }

      // Move this chat to the top of the list (most recent activity)
      final updatedChat = _chatListData.chats.removeAt(chatIndex);
      _chatListData.chats.insert(0, updatedChat);
      _logger.d(
        'Moved chat $chatId to top of chat list (from index $chatIndex to 0)',
      );

      // Notify listeners with updated chat list
      _chatListStreamController.add(_chatListData);
      notifyListeners();

      // Force a secondary update to ensure the chat stays at the top
      Future.delayed(Duration(milliseconds: 100), () {
        if (!_chatListStreamController.isClosed) {
          _chatListStreamController.add(_chatListData);
          notifyListeners();
          _logger.d('Secondary notification sent for chat list update');
        }
      });

      _logger.i('Successfully updated chat $chatId with missed call message');
    } catch (e, stackTrace) {
      _logger.e('Error updating chat with missed call message: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// Update current chat messages with missed call message if user is viewing this chat
  void _updateCurrentChatWithMissedCallMessage(
    int chatId,
    int? messageId,
    Map<String, dynamic> missedCallData,
  ) {
    try {
      // Check if user is currently viewing this chat
      if (_currentChatId == null || _currentChatId != chatId) {
        _logger.d(
          'Not updating current chat - user not viewing chat $chatId (current: $_currentChatId)',
        );
        return;
      }

      _logger.i(
        'Updating current chat messages for missed call - chat_id: $chatId, message_id: $messageId',
      );

      // Initialize records if null
      _chatsData.records ??= [];

      // Check if we need to create a new message or update existing one
      if (messageId != null && _chatsData.records!.isNotEmpty) {
        // Try to find existing message by ID
        final existingMessageIndex = _chatsData.records!.indexWhere(
          (msg) => msg.messageId == messageId,
        );

        if (existingMessageIndex != -1) {
          // Update existing message
          _chatsData.records![existingMessageIndex].messageContent =
              "callmissed";

          // CRITICAL FIX: Also update the call status and users array from missed call event
          if (_chatsData.records![existingMessageIndex].calls != null &&
              _chatsData.records![existingMessageIndex].calls!.isNotEmpty) {
            for (var call in _chatsData.records![existingMessageIndex].calls!) {
              call.callStatus = "missed";
              // Update users array from missed call event for correct logic
              if (missedCallData['users'] != null) {
                call.users =
                    (missedCallData['users'] as List)
                        .map(
                          (e) => e is int ? e : int.tryParse(e.toString()) ?? 0,
                        )
                        .toList();
              }
            }
            _logger.i(
              'Updated call status to "missed" and users array in calls array for message $messageId',
            );
          }

          _logger.i(
            'Updated existing current chat message $messageId with "callmissed" content',
          );
        } else {
          // Add new message at the beginning (most recent)
          _chatsData.records!.insert(
            0,
            Records(
              messageId: messageId,
              messageContent: "callmissed",
              messageType: "call",
              chatId: chatId,
              senderId: missedCallData['user_id'] ?? missedCallData['peer_id'],
              createdAt: DateTime.now().toIso8601String(),
              updatedAt: DateTime.now().toIso8601String(),
            ),
          );
          _logger.i(
            'Added new missed call message to current chat with ID $messageId',
          );
        }
      } else {
        // No message ID provided or no existing messages, create new message
        final newMessageId = messageId ?? DateTime.now().millisecondsSinceEpoch;
        _chatsData.records!.insert(
          0,
          Records(
            messageId: newMessageId,
            messageContent: "callmissed",
            messageType: "call",
            chatId: chatId,
            senderId: missedCallData['user_id'] ?? missedCallData['peer_id'],
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        _logger.i(
          'Added new missed call message to current chat with generated ID $newMessageId',
        );
      }

      // Notify listeners with updated current chat data
      _chatsStreamController.add(_chatsData);
      notifyListeners();

      _logger.i('Successfully updated current chat messages for missed call');
    } catch (e, stackTrace) {
      _logger.e('Error updating current chat with missed call message: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// Setup all call-related event listeners
  void _setupCallEventListeners() {
    _logger.i('Setting up call event listeners');

    // Handle call_ended events
    _socketService.on(_socketEvents.callEnded, (data) {
      _logger.d('Received call_ended event: $data');
      _handleCallEndedEvent(data);
    });

    // Handle user_joined events
    _socketService.on(_socketEvents.userJoinedCall, (data) {
      _logger.d('Received user_joined event: $data');
      _handleUserJoinedEvent(data);
    });

    // Handle receiving_call events (if this event exists)
    // Note: receiving_call might be handled differently - check if this event exists
    try {
      _socketService.on('receiving_call', (data) {
        _logger.d('Received receiving_call event: $data');
        _handleReceivingCallEvent(data);
      });
    } catch (e) {
      _logger.d('receiving_call event not available: $e');
    }

    _logger.i('Call event listeners setup completed');
  }

  /// Handle call_ended socket event
  void _handleCallEndedEvent(dynamic data) {
    try {
      _logger.d('Processing call_ended event: $data');

      if (data is! Map<String, dynamic>) {
        _logger.e('Invalid call_ended data format');
        return;
      }

      final int? chatId = data['chat_id'];
      final int? messageId = data['message_id'];

      if (chatId == null) {
        _logger.e('Missing chat_id in call_ended event');
        return;
      }

      _logger.i(
        'Processing call_ended for chat_id: $chatId, message_id: $messageId',
      );

      // Update the chat list to show "call ended" status
      _updateChatWithCallEvent(chatId, messageId, data, 'ended');

      // Also update current chat if user is viewing this chat
      _updateCurrentChatWithCallEvent(chatId, messageId, data, 'ended');
    } catch (e, stackTrace) {
      _logger.e('Error handling call_ended event: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// Handle user_joined socket event
  void _handleUserJoinedEvent(dynamic data) {
    try {
      _logger.d('Processing user_joined event: $data');

      if (data is! Map<String, dynamic>) {
        _logger.e('Invalid user_joined data format');
        return;
      }

      final callData = data['call'];
      if (callData == null) {
        _logger.e('Missing call data in user_joined event');
        return;
      }

      final int? chatId = callData['chat_id'];
      final int? messageId = callData['message_id'];

      if (chatId == null) {
        _logger.e('Missing chat_id in user_joined event');
        return;
      }

      _logger.i(
        'Processing user_joined for chat_id: $chatId, message_id: $messageId',
      );

      // Update the chat list to show "ongoing call" status
      _updateChatWithCallEvent(chatId, messageId, callData, 'ongoing');

      // Also update current chat if user is viewing this chat
      _updateCurrentChatWithCallEvent(chatId, messageId, callData, 'ongoing');
    } catch (e, stackTrace) {
      _logger.e('Error handling user_joined event: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// Handle receiving_call socket event
  void _handleReceivingCallEvent(dynamic data) {
    try {
      _logger.d('Processing receiving_call event: $data');

      if (data is! Map<String, dynamic>) {
        _logger.e('Invalid receiving_call data format');
        return;
      }

      final callData = data['call'];
      final chatData = data['chat'];

      if (callData == null || chatData == null) {
        _logger.e('Missing call or chat data in receiving_call event');
        return;
      }

      final int? chatId = chatData['chat_id'];
      final int? messageId = callData['message_id'];

      if (chatId == null) {
        _logger.e('Missing chat_id in receiving_call event');
        return;
      }

      _logger.i(
        'Processing receiving_call for chat_id: $chatId, message_id: $messageId',
      );

      // Update the chat list to show "ringing" status
      _updateChatWithCallEvent(chatId, messageId, callData, 'ringing');

      // Also update current chat if user is viewing this chat
      _updateCurrentChatWithCallEvent(chatId, messageId, callData, 'ringing');
    } catch (e, stackTrace) {
      _logger.e('Error handling receiving_call event: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// Generic method to update chat with call events
  void _updateChatWithCallEvent(
    int chatId,
    int? messageId,
    Map<String, dynamic> callData,
    String callStatus,
  ) {
    try {
      _logger.d(
        'UPDATE chatId:$chatId msgId:$messageId status:$callStatus preview:Updating...',
      );

      // Find the chat in the chat list
      final chatIndex = _chatListData.chats.indexWhere((chat) {
        final record =
            chat.records?.isNotEmpty == true ? chat.records!.first : null;
        return record?.chatId == chatId;
      });

      if (chatIndex == -1) {
        _logger.w(
          'Chat with ID $chatId not found in chat list for $callStatus event',
        );
        return;
      }

      final targetChat = _chatListData.chats[chatIndex];
      final chatRecord =
          targetChat.records?.isNotEmpty == true
              ? targetChat.records!.first
              : null;

      if (chatRecord?.messages?.isNotEmpty != true) {
        _logger.w('No messages found for chat ID $chatId');
        return;
      }

      // Find the message to update
      var messageToUpdate = chatRecord!.messages!.first;
      if (messageId != null) {
        final specificMessage =
            chatRecord.messages!
                .where((msg) => msg.messageId == messageId)
                .firstOrNull;
        if (specificMessage != null) {
          messageToUpdate = specificMessage;
        }
      }

      // CRITICAL FIX: Update both calls array AND message content for proper preview
      bool wasUpdated = false;

      // Update the call status in the calls array
      if (messageToUpdate.calls?.isNotEmpty == true) {
        for (var call in messageToUpdate.calls!) {
          call.callStatus = callStatus;
          // Update call duration if available
          if (callData['call_duration'] != null) {
            call.callDuration = callData['call_duration'];
          }
          // Update users array if available
          if (callData['users'] != null) {
            call.users =
                (callData['users'] as List)
                    .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
                    .toList();
          }
          if (callData['current_users'] != null) {
            call.currentUsers =
                (callData['current_users'] as List)
                    .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
                    .toList();
          }
        }
        wasUpdated = true;
        _logger.i(
          'Updated calls array with status "$callStatus" for message $messageId in chat $chatId',
        );
      }

      // CRITICAL FIX: Also update message content to reflect final call status
      // This prevents the preview from being stuck on "calling"
      if (messageToUpdate.messageType == 'call') {
        final oldContent = messageToUpdate.messageContent;

        // Map call status to appropriate message content
        switch (callStatus.toLowerCase()) {
          case 'ended':
            messageToUpdate.messageContent = 'ended';
            break;
          case 'missed':
            messageToUpdate.messageContent = 'callmissed';
            break;
          case 'ongoing':
            messageToUpdate.messageContent = 'ongoing';
            break;
          case 'ringing':
            messageToUpdate.messageContent = 'calling';
            break;
          default:
            messageToUpdate.messageContent = callStatus;
            break;
        }

        if (oldContent != messageToUpdate.messageContent) {
          wasUpdated = true;
          _logger.i(
            'Updated message content from "$oldContent" to "${messageToUpdate.messageContent}" for chat $chatId',
          );
        }
      }

      if (!wasUpdated) {
        _logger.w(
          'No calls array or message content found for call event update',
        );
        return;
      }

      // Update chat timestamp
      final currentTime = DateTime.now().toIso8601String();
      chatRecord.updatedAt = currentTime;
      messageToUpdate.updatedAt = currentTime;

      // Move chat to top if it's not already there
      if (chatIndex != 0) {
        final updatedChat = _chatListData.chats.removeAt(chatIndex);
        _chatListData.chats.insert(0, updatedChat);
        _logger.d('Moved chat $chatId to top of chat list');
      }

      // Notify listeners - this will trigger _buildMessagePreview to rebuild
      _chatListStreamController.add(_chatListData);
      notifyListeners();

      // Enhanced logging with preview information
      final callType = messageToUpdate.calls?.first.callType ?? 'voice';
      final duration = messageToUpdate.calls?.first.callDuration;
      final previewInfo =
          duration != null && duration > 0
              ? 'Ended $callType call (${_formatDurationForLog(duration)})'
              : '$callStatus $callType call';

      _logger.i(
        'UPDATE chatId:$chatId msgId:$messageId status:$callStatus type:$callType preview:"$previewInfo"',
      );

      _logger.i(
        'Successfully updated chat $chatId with call status: $callStatus',
      );
    } catch (e, stackTrace) {
      _logger.e('Error updating chat with call event: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// Helper method to format duration for logging
  String _formatDurationForLog(int? durationInSeconds) {
    if (durationInSeconds == null || durationInSeconds == 0) return '0s';
    if (durationInSeconds < 60) {
      return '${durationInSeconds}s';
    } else {
      final minutes = durationInSeconds ~/ 60;
      final seconds = durationInSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
  }

  /// Update current chat with call event if user is viewing this chat
  void _updateCurrentChatWithCallEvent(
    int chatId,
    int? messageId,
    Map<String, dynamic> callData,
    String callStatus,
  ) {
    try {
      // Check if user is currently viewing this chat
      if (_currentChatId == null || _currentChatId != chatId) {
        return;
      }

      if (_chatsData.records?.isNotEmpty != true) {
        return;
      }

      // Find and update the message in current chat
      var messageToUpdate = _chatsData.records!.first;
      if (messageId != null) {
        final specificMessage =
            _chatsData.records!
                .where((msg) => msg.messageId == messageId)
                .firstOrNull;
        if (specificMessage != null) {
          messageToUpdate = specificMessage;
        }
      }

      // Update call status
      if (messageToUpdate.calls?.isNotEmpty == true) {
        for (var call in messageToUpdate.calls!) {
          call.callStatus = callStatus;
          if (callData['call_duration'] != null) {
            call.callDuration = callData['call_duration'];
          }
          if (callData['users'] != null) {
            call.users =
                (callData['users'] as List)
                    .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
                    .toList();
          }
        }
        _logger.i('Updated current chat message call status to: $callStatus');
      }

      // Notify listeners
      _chatsStreamController.add(_chatsData);
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating current chat with call event: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// ✅ NEW: Reset method for logout scenarios (keeps streams alive)
  void reset() {
    _logger.d('Resetting SocketEventController to clean state');

    try {
      // Reset initialization flag
      _isInitialized = false;
      _isConnected = false;

      // ✅ CRITICAL FIX: Clear ALL data structures to prevent old user data
      _chatListData = chatlist.ChatListModel(chats: []);
      _chatsData = ChatsModel();
      _onlineUsersData = OnlineUsersModel(onlineUsers: []);
      _typingData = TypingModel();
      _blockUpdatesData = BlockUpdatesModel();
      _logger.d(
        '✅ Cleared all data models (chatList, chats, onlineUsers, etc.)',
      );

      // Clear all collections but keep streams alive
      _recentlyProcessedMessages.clear();
      _userTypingStatus.clear();
      _chatTypingStatus.clear();
      _seenMessages.clear();
      _pendingMessages.clear(); // ✅ Clear pending messages queue
      _emissionStats.clear(); // ✅ Clear emission stats
      _logger.d('✅ Cleared all tracking collections');

      // Reset chat state
      _resetChatState();
      _resetAllLoadingStates();

      // Clear current chat context
      _currentChatId = null;
      _currentUserId = null;
      _currentTypingUserId = null;
      _activeChatScreenId = null;
      _logger.d('✅ Cleared all context and tracking variables');

      // ✅ IMPORTANT: Clear stream controllers by emitting empty data
      // This ensures UI components receive fresh empty state
      _chatListStreamController.add(_chatListData);
      _chatsStreamController.add(_chatsData);
      _onlineUsersStreamController.add(_onlineUsersData);
      _typingStreamController.add(_typingData);
      _blockUpdatesStreamController.add(_blockUpdatesData);
      _logger.d('✅ Emitted empty state to all streams');

      _logger.d(
        'SocketEventController reset completed - ALL old user data cleared, ready for fresh initialization',
      );
    } catch (e) {
      _logger.e('Error during SocketEventController reset', e);
    }
  }

  @override
  void dispose() {
    _logger.d('Disposing SocketEventController');

    // Close all stream controllers
    _chatListStreamController.close();
    _chatsStreamController.close();
    _chatIdsStreamController.close();
    _onlineUsersStreamController.close();
    _typingStreamController.close();
    _blockUpdatesStreamController.close();
    _pinUnpinStreamController.close();
    _pollUpdatedStreamController.close();
    _messageUpdatedStreamController.close();
    _aiMessageChunkStreamController.close();
    _aiMessageErrorStreamController.close();
    _newMessageStreamController.close();
    _chatListMessageStreamController.close();

    // Clear collections
    _recentlyProcessedMessages.clear();
    _userTypingStatus.clear();
    _chatTypingStatus.clear();
    _seenMessages.clear();

    super.dispose();
  }
}
