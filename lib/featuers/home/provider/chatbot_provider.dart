import 'package:flutter/foundation.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/services/socket/socket_event_controller.dart';
import 'package:whoxa/core/services/socket/socket_service.dart';
import 'package:whoxa/featuers/home/screens/bot_chat/bot_chat_screen.dart';

/// Model for a single bot chat entry returned by GET /api/chatbot/chats
class BotChat {
  final int chatId;
  final String groupName;
  final String groupDescription;
  final String groupIcon;
  final String chatType;
  final bool isBotChat;
  final String? updatedAt;

  BotChat({
    required this.chatId,
    required this.groupName,
    required this.groupDescription,
    required this.groupIcon,
    required this.chatType,
    required this.isBotChat,
    this.updatedAt,
  });

  factory BotChat.fromJson(Map<String, dynamic> json) {
    return BotChat(
      chatId: json['chat_id'] ?? 0,
      groupName: json['group_name'] ?? 'Flickpitchchat AI Assistant',
      groupDescription:
          json['group_description'] ?? 'Chat with AI powered by Flickpitchchat',
      groupIcon: json['group_icon'] ?? '',
      chatType: json['chat_type'] ?? 'bot',
      isBotChat: json['is_bot_chat'] ?? true,
      updatedAt: json['updated_at'],
    );
  }
}

class ChatbotProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  ChatbotProvider(this._apiClient);

  // ── Bot chats list state ──────────────────────────────────────────────────

  // List<BotChat> _botChats = [];
  // bool _isLoading = false;
  bool _isCreating = false;
  String? _error;

  // List<BotChat> get botChats => _botChats;
  // bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get error => _error;
  // bool get hasBotChats => _botChats.isNotEmpty;

  // ── Active chat session state (consumed by BotChatScreen) ─────────────────

  int? _activeChatId;
  final List<BotMessage> _messages = [];
  bool _isBotTyping = false;
  String? _streamingText;
  int _historyPage = 1;
  bool _allHistoryLoaded = false;
  bool _isPaginationLoading = false;

  List<BotMessage> get messages => List.unmodifiable(_messages);
  bool get isBotTyping => _isBotTyping;
  String? get streamingText => _streamingText;
  bool get allHistoryLoaded => _allHistoryLoaded;
  bool get isPaginationLoading => _isPaginationLoading;

  bool _limitReached = false;
  bool get limitReached => _limitReached;

  // ── History / pagination state ────────────────────────────────────────────

  bool _isChatHistoryLoad = false;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasNextPage = false;

  bool get isChatHistoryLoad => _isChatHistoryLoad;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasNextPage => _hasNextPage;

  // ── Create bot chat ───────────────────────────────────────────────────────

  Future<BotChat?> createBotChat({
    String chatName = 'Flickpitchchat AI Assistant',
    String description = 'Chat with AI powered by Flickpitchchat',
  }) async {
    _isCreating = true;
    _error = null;
    notifyListeners();

    try {
      final body = await _apiClient.request(
        ApiEndpoints.createBotChat,
        method: 'POST',
        body: {'chat_name': chatName, 'description': description},
      );

      if (body['success'] == true) {
        final newChat = BotChat.fromJson(body['data']['chat']);
        notifyListeners();
        return newChat;
      } else {
        _error = body['error'] ?? 'Failed to create bot chat';
        if (kDebugMode) {
          debugPrint('ChatbotProvider createBotChat error: $_error');
        }
        return null;
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('ChatbotProvider createBotChat exception: $e');
      }
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  bool _hasHistory = false;
  bool get hasHistory => _hasHistory;

  Future<void> checkHistoryExists() async {
    try {
      final body = await _apiClient.request(
        ApiEndpoints.getBotChatHistory,
        method: 'POST',
        body: {'message_limit': 1, 'message_page': 1},
      );

      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final List rawMessages =
            data.containsKey('messages')
                ? (data['messages'] as List? ?? [])
                : _extractMessagesFromConversations(
                  data['conversations'] as List? ?? [],
                );

        _hasHistory = rawMessages.isNotEmpty;
        notifyListeners();
      }
    } catch (e) {
      _hasHistory = false;
      if (kDebugMode) debugPrint('checkHistoryExists exception: $e');
    }
  }

  // ── Chat session init ─────────────────────────────────────────────────────

  /// Called once by [BotChatScreen] in `initState`.
  /// Resets all session state and wires socket listeners for [chatId].
  void initChatSession({
    required int chatId,
    required SocketEventController socketEventController,
  }) {
    _activeChatId = chatId;
    _messages.clear();
    _isBotTyping = false;
    _streamingText = null;
    _historyPage = 1;
    _allHistoryLoaded = false;
    _isPaginationLoading = false;
    _limitReached = false;
    notifyListeners();

    _listenToSocket(chatId, socketEventController);

    checkHistoryExists();
  }

  // ── Socket ────────────────────────────────────────────────────────────────

  void _listenToSocket(
    int chatId,
    SocketEventController socketEventController,
  ) {
    // Remove stale listeners before re-attaching
    socketEventController.socketService.off(SocketEvents().botMessageChunk);
    socketEventController.socketService.off(SocketEvents().botMessageComplete);

    // Streaming chunk arrives
    socketEventController.socketService.on(SocketEvents().botMessageChunk, (
      data,
    ) {
      if (data['chat_id'] != chatId) return;
      final bool isLimitReached =
          data['limit_reached'] == true ||
          data['limit_reached']?.toString().toLowerCase() == 'true';
      if (isLimitReached) {
        _limitReached = true;
        _isBotTyping = false;
        _streamingText = null;
        notifyListeners();
        return;
      }
      _isBotTyping = true;
      _streamingText = (_streamingText ?? '') + (data['chunk'] ?? '');
      notifyListeners();
    });

    // Full response complete
    socketEventController.socketService.on(SocketEvents().botMessageComplete, (
      data,
    ) {
      if (data['chat_id'] != chatId) return;
      final bool isLimitReached =
          data['limit_reached'] == true ||
          data['limit_reached']?.toString().toLowerCase() == 'true';
      if (isLimitReached) {
        _limitReached = true;
        _streamingText = null;
        _isBotTyping = false;
        notifyListeners();
        return;
      }
      _messages.add(
        BotMessage(
          messageId: data['message_id'] is int ? data['message_id'] : null,
          content: data['full_response'] ?? _streamingText ?? '',
          isBot: true,
          createdAt: DateTime.now(),
        ),
      );
      _streamingText = null;
      _isBotTyping = false;
      notifyListeners();
    });
  }

  // ── Send message ──────────────────────────────────────────────────────────

  /// Returns `true` if the message was queued; `false` if skipped
  /// (empty text, bot is still typing, or no active chat).
  bool sendMessage({
    required String text,
    required SocketEventController socketEventController,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty ||
        _isBotTyping ||
        _activeChatId == null ||
        _limitReached) {
      return false;
    }

    _messages.add(
      BotMessage(content: trimmed, isBot: false, createdAt: DateTime.now()),
    );
    _isBotTyping = true;
    _streamingText = null;
    notifyListeners();

    socketEventController.socketService.emit(
      SocketEvents().sendBotMessage,
      data: {'chat_id': _activeChatId, 'message_content': trimmed},
    );

    return true;
  }

  // ── Load more (scroll-triggered pagination) ───────────────────────────────

  Future<void> loadMoreHistory() async {
    if (_isPaginationLoading || _isChatHistoryLoad || _allHistoryLoaded) return;

    _isPaginationLoading = true;
    notifyListeners();

    final nextPage = _historyPage + 1;
    final moreMessages = await fetchConversationHistory(messagePage: nextPage);

    if (moreMessages == null || moreMessages.isEmpty) {
      _allHistoryLoaded = true;
    } else {
      _historyPage = nextPage;
      _allHistoryLoaded = !_hasNextPage;
      _messages.insertAll(0, moreMessages);
    }

    _isPaginationLoading = false;
    notifyListeners();
  }

  // ── Manual history refresh (appbar history button) ────────────────────────

  Future<void> refreshConversationHistory() async {
    if (_isChatHistoryLoad) return;

    final historyMessages = await fetchConversationHistory();
    if (historyMessages == null) return;

    _historyPage = 1;
    _allHistoryLoaded = false;
    _messages
      ..clear()
      ..addAll(historyMessages);
    notifyListeners();
  }

  // ── Fetch conversation history (API) ──────────────────────────────────────

  /// POST /chatbot/conversations — returns a flat list of [BotMessage] pairs.
  ///
  /// Page-based pagination:
  /// - [messageLimit] — messages per page (default 20)
  /// - [messagePage]  — 1-based page number (default 1)
  Future<List<BotMessage>?> fetchConversationHistory({
    int messageLimit = 20,
    int messagePage = 1,
  }) async {
    try {
      if (messagePage == 1) {
        _isChatHistoryLoad = true;
        notifyListeners();
      }

      final body = await _apiClient.request(
        ApiEndpoints.getBotChatHistory,
        method: 'POST',
        body: {'message_limit': messageLimit, 'message_page': messagePage},
      );

      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final List<BotMessage> historyMessages = [];

        // ── New API format: data.messages (flat list of Q&A pairs) ──────────
        // ── Old API format: data.conversations[].messages ───────────────────
        final List rawMessages =
            data.containsKey('messages')
                ? (data['messages'] as List? ?? [])
                : _extractMessagesFromConversations(
                  data['conversations'] as List? ?? [],
                );

        for (final qna in rawMessages) {
          // Question (user)
          final q = qna['question'];
          if (q != null && (q['content'] ?? '').toString().isNotEmpty) {
            historyMessages.add(
              BotMessage(
                messageId: q['message_id'],
                content: q['content'] ?? '',
                isBot: q['role'] == 'assistant',
                createdAt:
                    DateTime.tryParse(q['created_at'] ?? '') ?? DateTime.now(),
              ),
            );
          }

          // Answer (assistant) — may be null if bot hasn't replied yet
          final a = qna['answer'];
          if (a != null && (a['content'] ?? '').toString().isNotEmpty) {
            historyMessages.add(
              BotMessage(
                messageId: a['message_id'],
                content: a['content'] ?? '',
                isBot: a['role'] == 'assistant',
                createdAt:
                    DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now(),
              ),
            );
          }
        }

        // ── Pagination: new format at data.pagination, old at conversations[0].message_pagination ──
        final pagination =
            data['pagination'] as Map<String, dynamic>? ??
            ((data['conversations'] as List?)?.isNotEmpty == true
                ? (data['conversations'][0]['message_pagination']
                    as Map<String, dynamic>?)
                : null);
        if (pagination != null) {
          _currentPage = pagination['page'] ?? pagination['current_page'] ?? 1;
          _totalPages = pagination['total_pages'] ?? 1;
          _hasNextPage =
              pagination['has_next_page'] ?? (_currentPage < _totalPages);
        }

        return historyMessages;
      } else {
        _error = body['error'] ?? 'Failed to load conversation history';
        if (kDebugMode) {
          debugPrint('ChatbotProvider fetchConversationHistory error: $_error');
        }
        return null;
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('ChatbotProvider fetchConversationHistory exception: $e');
      }
      return null;
    } finally {
      _isChatHistoryLoad = false;
      notifyListeners();
    }
  }

  // ── Helper: flatten old API conversations[].messages into a flat Q&A list ─
  List _extractMessagesFromConversations(List conversations) {
    final List result = [];
    for (final conv in conversations) {
      final List messages = conv['messages'] as List? ?? [];
      result.addAll(messages);
    }
    return result;
  }
}
