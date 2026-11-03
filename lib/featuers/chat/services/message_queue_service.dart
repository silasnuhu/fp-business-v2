import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart';
import 'package:whoxa/featuers/chat/repository/conversation_repository.dart';
import 'package:whoxa/featuers/chat/repository/message_repository.dart';
import 'package:whoxa/utils/enums.dart';

/// Queued message item with all necessary data for sending
class QueuedMessage {
  final String tempId;
  final int chatId;
  final int? userId;
  final String messageContent;
  final MessageType messageType;
  final Map<String, dynamic>? filePaths;
  final int? replyToMessageId;
  final int? storyId;
  final Duration voiceDuration;
  int retryCount;

  QueuedMessage({
    required this.tempId,
    required this.chatId,
    this.userId,
    required this.messageContent,
    required this.messageType,
    this.filePaths,
    this.replyToMessageId,
    this.storyId,
    this.voiceDuration = Duration.zero,
    this.retryCount = 0,
  });
}

/// Service responsible for managing message send queue with FIFO processing
///
/// Features:
/// - FIFO queue for sequential message sending
/// - One-at-a-time API calls (no parallel sends)
/// - Automatic retry on failure (configurable)
/// - Status callbacks for UI updates
class MessageQueueService {
  static final MessageQueueService _instance = MessageQueueService._internal();
  factory MessageQueueService() => _instance;
  MessageQueueService._internal();

  MessageRepository get _messageRepository =>
      MessageRepository(GetIt.instance<ApiClient>());
  ConversationRepository get _conversationRepository =>
      ConversationRepository(GetIt.instance<ApiClient>());
  final Uuid _uuid = const Uuid();

  /// Maximum retry attempts for failed messages
  static const int maxRetryAttempts = 3;

  /// FIFO queue for pending messages
  final Queue<QueuedMessage> _messageQueue = Queue<QueuedMessage>();

  /// Currently processing message
  QueuedMessage? _currentMessage;

  /// Whether the queue processor is running
  bool _isProcessing = false;

  /// Stream controller for message status updates
  final StreamController<MessageStatusUpdate> _statusController =
      StreamController<MessageStatusUpdate>.broadcast();

  /// Stream of message status updates (for UI to listen)
  Stream<MessageStatusUpdate> get statusUpdates => _statusController.stream;

  /// Callback for when a message is successfully sent
  /// Returns the API response data with message_id
  Function(String tempId, Map<String, dynamic> response)? onMessageSent;

  /// Callback for when a message fails to send
  Function(String tempId, String error)? onMessageFailed;

  /// Callback for when a message starts sending
  Function(String tempId)? onMessageSending;

  /// Generate a unique temporary ID for optimistic messages
  String generateTempId() => _uuid.v4();

  /// Add a message to the queue
  /// Returns the temporary ID assigned to the message
  String enqueue({
    required int chatId,
    int? userId,
    required String messageContent,
    required MessageType messageType,
    Map<String, dynamic>? filePaths,
    int? replyToMessageId,
    int? storyId,
    Duration voiceDuration = Duration.zero,
    String? existingTempId, // For retry scenarios
  }) {
    final tempId = existingTempId ?? generateTempId();

    final queuedMessage = QueuedMessage(
      tempId: tempId,
      chatId: chatId,
      userId: userId,
      messageContent: messageContent,
      messageType: messageType,
      filePaths: filePaths,
      replyToMessageId: replyToMessageId,
      storyId: storyId,
      voiceDuration: voiceDuration,
    );

    _messageQueue.add(queuedMessage);
    debugPrint('📤 Message queued: $tempId (Queue size: ${_messageQueue.length})');

    // Start processing if not already running
    _processQueue();

    return tempId;
  }

  /// Retry a failed message by its tempId
  void retryMessage(Records failedMessage) {
    if (failedMessage.tempId == null) {
      debugPrint('❌ Cannot retry message without tempId');
      return;
    }

    debugPrint('🔄 Retrying message: ${failedMessage.tempId}');

    // Emit status update for UI
    _statusController.add(MessageStatusUpdate(
      tempId: failedMessage.tempId!,
      status: MessageSendingStatus.sending,
    ));

    // Re-queue the message (will be picked up by processor)
    final queuedMessage = QueuedMessage(
      tempId: failedMessage.tempId!,
      chatId: failedMessage.chatId ?? 0,
      userId: failedMessage.senderId,
      messageContent: failedMessage.messageContent ?? '',
      messageType: _parseMessageType(failedMessage.messageType ?? 'text'),
      replyToMessageId: failedMessage.replyTo,
      retryCount: failedMessage.retryCount + 1,
    );

    _messageQueue.add(queuedMessage);
    _processQueue();
  }

  /// Process the queue (one message at a time)
  Future<void> _processQueue() async {
    // Prevent multiple processors
    if (_isProcessing) return;
    _isProcessing = true;

    while (_messageQueue.isNotEmpty) {
      _currentMessage = _messageQueue.removeFirst();
      final message = _currentMessage!;

      debugPrint('🚀 Processing message: ${message.tempId}');

      // Notify that message is being sent
      onMessageSending?.call(message.tempId);
      _statusController.add(MessageStatusUpdate(
        tempId: message.tempId,
        status: MessageSendingStatus.sending,
      ));

      try {
        // NEW: JSON send via MessageRepository, not the old multipart
        // ChatRepository.sendMessage (§6.2/§6.7). NEW also has no implicit
        // 1:1 creation on send (§5.2) — resolve/create the conversation
        // first if this queued message targets a brand-new chat.
        var conversationId = message.chatId;
        if (conversationId == 0 && message.userId != null) {
          final conversation = await _conversationRepository.createConversation(
            type: 'direct',
            participantIds: [message.userId.toString()],
          );
          conversationId = int.tryParse(conversation.id) ?? 0;
        }

        if (conversationId <= 0) {
          _handleFailure(message, 'Could not resolve a conversation to send to.');
          _currentMessage = null;
          continue;
        }

        final sent = await _messageRepository.sendMessage(
          conversationId: conversationId,
          messageType: message.messageType,
          messageContent: message.messageContent,
          replyToMessageId: message.replyToMessageId,
        );

        // Adapts MessageDto onto the {data:{message_id,chat_id}} shape
        // ChatProvider's onMessageSent callback already expects, so that
        // callback doesn't need to change. `conversation_seq` is carried
        // through too so confirmOptimisticMessage can store it for
        // read-receipt (message_read_update) matching — without it a
        // confirmed message never turns blue.
        final response = <String, dynamic>{
          'data': {
            'message_id': sent.id,
            'chat_id': sent.conversationId,
            'conversation_seq': sent.conversationSeq,
          },
        };

        debugPrint('✅ Message sent: ${message.tempId}');
        onMessageSent?.call(message.tempId, response);
        _statusController.add(MessageStatusUpdate(
          tempId: message.tempId,
          status: MessageSendingStatus.sent,
          response: response,
        ));
      } catch (e) {
        // Exception during send
        _handleFailure(message, e.toString());
      }

      _currentMessage = null;
    }

    _isProcessing = false;
    debugPrint('📭 Queue empty, processor stopped');
  }

  /// Handle message send failure
  void _handleFailure(QueuedMessage message, String error) {
    debugPrint('❌ Message failed: ${message.tempId} - $error');

    // Auto-retry if under max attempts
    if (message.retryCount < maxRetryAttempts) {
      debugPrint('🔄 Auto-retrying (${message.retryCount + 1}/$maxRetryAttempts)');
      message.retryCount++;
      _messageQueue.addFirst(message); // Add back to front for immediate retry
    } else {
      // Max retries exceeded
      debugPrint('💀 Max retries exceeded for: ${message.tempId}');
      onMessageFailed?.call(message.tempId, error);
      _statusController.add(MessageStatusUpdate(
        tempId: message.tempId,
        status: MessageSendingStatus.failed,
        error: error,
      ));
    }
  }

  /// Parse message type string to enum
  MessageType _parseMessageType(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return MessageType.Text;
      case 'image':
        return MessageType.Image;
      case 'video':
        return MessageType.Video;
      case 'voice':
        return MessageType.Voice;
      case 'file':
      case 'document':
        return MessageType.File;
      case 'gif':
        return MessageType.Gif;
      case 'link':
        return MessageType.Link;
      case 'location':
        return MessageType.Location;
      case 'contact':
        return MessageType.Contact;
      case 'story_reply':
      case 'feed_reference':
        return MessageType.StoryReply;
      default:
        return MessageType.Text;
    }
  }

  /// Get current queue size
  int get queueSize => _messageQueue.length;

  /// Check if a message is in the queue
  bool isInQueue(String tempId) {
    return _messageQueue.any((m) => m.tempId == tempId) ||
        _currentMessage?.tempId == tempId;
  }

  /// Remove a message from the queue (cancel before sending)
  bool removeFromQueue(String tempId) {
    final lengthBefore = _messageQueue.length;
    _messageQueue.removeWhere((m) => m.tempId == tempId);
    return _messageQueue.length < lengthBefore;
  }

  /// Clear all pending messages
  void clearQueue() {
    _messageQueue.clear();
    debugPrint('🗑️ Queue cleared');
  }

  /// Dispose resources
  void dispose() {
    _statusController.close();
  }
}

/// Status update for a message in the queue
class MessageStatusUpdate {
  final String tempId;
  final MessageSendingStatus status;
  final Map<String, dynamic>? response;
  final String? error;

  MessageStatusUpdate({
    required this.tempId,
    required this.status,
    this.response,
    this.error,
  });
}
