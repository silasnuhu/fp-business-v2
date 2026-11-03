import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:whoxa/core/services/socket/socket_event_controller.dart';
import 'package:whoxa/featuers/ai_assistant/repository/ai_assistant_repository.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/data/conversation_adapter.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/widgets/global.dart';

/// Where to navigate after [AiAssistantProvider.openChat].
typedef AiChatTarget = ({int chatId, int botUserId, int unseenCount});

/// AI Assistant state: the backend `enabled` flag (drives the home-screen
/// entry point), which chat/user is the bot, and the live preview of a reply
/// that is still generating.
///
/// The AI chat itself is a normal 1:1 conversation — history, sending and the
/// final bot reply all go through the regular chat flow. Only the preview
/// (`ai_message_chunk` / `ai_message_error`) is handled here.
class AiAssistantProvider extends ChangeNotifier {
  static const String botUserName = 'ai_assistant';
  static const String botDisplayName = 'AI Assistant';

  /// A preview with no chunk, final reply or error after this long is
  /// dropped, so a lost socket event can't leave the bubble up forever.
  static const Duration _replyTimeout = Duration(seconds: 90);

  final AiAssistantRepository _repository;
  final SocketEventController _socketEventController;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'AiAssistantProvider',
  );

  StreamSubscription<Map<String, dynamic>>? _chunkSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<chats.Records>? _messageSubscription;

  AiAssistantConfig? _config;
  bool _isOpening = false;
  bool _isDisposed = false;
  int? _chatId;
  int? _botUserId;

  // chatId -> reply text so far; '' means a reply is pending but no chunk
  // has arrived yet.
  final Map<int, String> _replyPreviews = {};
  final Map<int, Timer> _replyTimeouts = {};

  AiAssistantProvider(this._repository, this._socketEventController) {
    _chunkSubscription = _socketEventController.aiMessageChunkStream.listen(
      _onChunk,
    );
    _errorSubscription = _socketEventController.aiMessageErrorStream.listen(
      _onError,
    );
    _messageSubscription = _socketEventController.chatListMessageStream.listen(
      _onNewMessage,
    );
  }

  bool get isEnabled => _config?.enabled == true;
  bool get isOpening => _isOpening;

  static bool isBotUserName(String? userName) =>
      userName?.trim().toLowerCase() == botUserName;

  bool isAiChat(int? chatId) =>
      chatId != null && chatId > 0 && chatId == _chatId;

  bool isBotUser(int? userId) =>
      userId != null && userId > 0 && userId == _botUserId;

  /// Records the AI chat when it was identified some other way than
  /// [openChat] (e.g. opened from the chat list, by the peer's userName).
  void rememberAiChat({int? chatId, int? botUserId}) {
    if (chatId != null && chatId > 0) _chatId = chatId;
    if (botUserId != null && botUserId > 0) _botUserId = botUserId;
  }

  /// The in-progress reply for [chatId]: null when none, '' while waiting
  /// for the first chunk, otherwise the text streamed so far.
  String? replyPreviewFor(int? chatId) =>
      chatId == null ? null : _replyPreviews[chatId];

  /// Called each time the home tabbar mounts (app start / after login):
  /// forgets the previous user's AI chat and re-reads the config.
  Future<void> startSession() async {
    _chatId = null;
    _botUserId = null;
    _clearAllPreviews();
    await loadConfig();
  }

  Future<void> loadConfig() async {
    try {
      _config = await _repository.getConfig();
      _logger.i(
        'AI Assistant config: enabled=${_config!.enabled}, '
        'provider=${_config!.provider}, model=${_config!.model}',
      );
    } catch (e) {
      // Keep the last known value; with none, the entry point stays hidden.
      _logger.w('Failed to load AI Assistant config: $e');
    }
    _notify();
  }

  /// Gets (or, on the very first call, creates) the AI chat and merges it
  /// into the chat list. Returns null when it couldn't be opened.
  Future<AiChatTarget?> openChat(ChatProvider chatProvider) async {
    if (_isOpening) return null;
    _isOpening = true;
    _notify();

    try {
      final conversation = await _repository.getChat();
      final chatId = int.tryParse(conversation?.id ?? '');
      if (conversation == null || chatId == null || chatId <= 0) {
        _logger.w('AI Assistant chat response had no conversationId');
        return null;
      }

      final myId =
          userID.isNotEmpty ? userID : (chatProvider.currentUserId ?? '');
      final botUserId = int.tryParse(
        ConversationAdapter.peerIdFor(conversation, myId) ?? '',
      );
      if (botUserId == null || botUserId <= 0) {
        _logger.w('AI Assistant chat $chatId has no bot participant');
        return null;
      }
      rememberAiChat(chatId: chatId, botUserId: botUserId);

      final chat = await chatProvider.addConversationToChatList(conversation);
      return (
        chatId: chatId,
        botUserId: botUserId,
        unseenCount: chat?.records?.firstOrNull?.unseenCount ?? 0,
      );
    } catch (e) {
      _logger.e('Failed to open AI Assistant chat: $e');
      return null;
    } finally {
      _isOpening = false;
      _notify();
    }
  }

  void _onChunk(Map<String, dynamic> data) {
    final chatId = int.tryParse(data['conversationId']?.toString() ?? '');
    final delta = data['delta']?.toString() ?? '';
    if (chatId == null || chatId <= 0) return;

    // Only the AI chat ever streams, so this also identifies it.
    _chatId ??= chatId;
    _replyPreviews[chatId] = (_replyPreviews[chatId] ?? '') + delta;
    _restartTimeout(chatId);
    _notify();
  }

  void _onError(String conversationId) {
    final chatId = int.tryParse(conversationId);
    if (chatId == null) return;
    // The fallback "something went wrong" reply still arrives as a normal
    // `new_message`, so there's nothing to show here.
    _clearPreview(chatId);
  }

  void _onNewMessage(chats.Records message) {
    final chatId = message.chatId;
    if (chatId == null || chatId <= 0) return;

    final senderId = message.senderId?.toString();
    if (senderId != null && senderId == userID) {
      // The server echo of our own text into the AI chat means it was
      // persisted and the bot has started on a reply: show the "thinking"
      // preview until the first chunk. Keyed off the echo rather than the
      // local send so a failed send never shows it.
      final type = message.messageType?.toLowerCase();
      if (isAiChat(chatId) &&
          (type == 'text' || type == 'link') &&
          !_replyPreviews.containsKey(chatId)) {
        _replyPreviews[chatId] = '';
        _restartTimeout(chatId);
        _notify();
      }
      return;
    }

    // Anything else in this 1:1 is the bot's persisted reply, which
    // replaces the preview.
    if (_replyPreviews.containsKey(chatId)) _clearPreview(chatId);
  }

  void _restartTimeout(int chatId) {
    _replyTimeouts.remove(chatId)?.cancel();
    _replyTimeouts[chatId] = Timer(_replyTimeout, () => _clearPreview(chatId));
  }

  void _clearPreview(int chatId) {
    _replyTimeouts.remove(chatId)?.cancel();
    if (_replyPreviews.remove(chatId) != null) _notify();
  }

  void _clearAllPreviews() {
    for (final timer in _replyTimeouts.values) {
      timer.cancel();
    }
    _replyTimeouts.clear();
    _replyPreviews.clear();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _chunkSubscription?.cancel();
    _errorSubscription?.cancel();
    _messageSubscription?.cancel();
    _clearAllPreviews();
    super.dispose();
  }
}
