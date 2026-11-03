import 'dart:convert';
import 'dart:developer' as developer;
import 'package:hive/hive.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

/// Service responsible for caching paginated chat data for the Universal Screen
///
/// Features:
/// - Page-based caching with persistent storage
/// - Session-based cache for fast access
/// - Cache invalidation and cleanup
/// - Memory-efficient storage management
///
/// Persistence: backed by a Hive box (`chat_message_cache`) rather than
/// flutter_secure_storage. This cache holds non-secret, potentially bulky
/// JSON blobs (message pages) that are disposable and re-fetchable from the
/// server — Keychain/Keystore-backed secure storage was overkill for it and
/// slower than a purpose-built local key-value store. If Hive is ever
/// unavailable (box fails to open), every method here degrades to a no-op
/// persistent cache and falls back to the in-memory session cache only —
/// same behavior as a cache miss, never a crash or data loss, since nothing
/// here is a source of truth.
class ChatCacheService {
  static const String _boxName = 'chat_message_cache';
  static const String _cacheKeyPrefix = 'chat_cache_';
  static const String _cacheMetaKey = 'chat_cache_meta_';
  static const int _maxCachedPages = 10; // Limit cache size
  static const Duration _cacheExpiry = Duration(hours: 24);

  // In-memory cache for current session
  final Map<String, Map<int, List<Records>>> _sessionCache = {};
  final Map<String, Map<int, DateTime>> _cacheTimestamps = {};
  final Map<String, ChatPaginationInfo> _paginationInfo = {};

  Box<String>? _box;

  /// Lazily opens (once) and returns the Hive box backing this cache.
  /// Returns null if the box can't be opened for any reason, so callers can
  /// fall back to in-memory-only behavior instead of throwing.
  Future<Box<String>?> _openBox() async {
    if (_box != null && _box!.isOpen) return _box;
    try {
      _box =
          Hive.isBoxOpen(_boxName)
              ? Hive.box<String>(_boxName)
              : await Hive.openBox<String>(_boxName);
      return _box;
    } catch (e) {
      developer.log('❌ Failed to open chat cache box: $e');
      return null;
    }
  }

  /// Reads [key] from the Hive box, falling back to the legacy
  /// flutter_secure_storage entry (same key string, from before this cache
  /// moved to Hive) on a miss. A legacy hit is migrated into the Hive box
  /// and removed from secure storage on the spot, so existing users don't
  /// lose their cached chat history (and see a one-time "loading" instead
  /// of instant render) purely because the storage backend changed — and
  /// every chat only pays this fallback cost once, the first time it's
  /// touched after the migration.
  Future<String?> _getWithLegacyFallback(Box<String>? box, String key) async {
    final value = box?.get(key);
    if (value != null) return value;

    try {
      final legacyValue = await SecurePrefs.getString(key);
      if (legacyValue != null && legacyValue.isNotEmpty) {
        developer.log('🔁 Migrating legacy cache entry to Hive: $key');
        await box?.put(key, legacyValue);
        await SecurePrefs.remove(key);
        return legacyValue;
      }
    } catch (e) {
      developer.log('❌ Legacy cache fallback failed for $key: $e');
    }
    return null;
  }

  /// Get cache key for a specific chat and page
  String _getCacheKey(String chatId, int page) => '$_cacheKeyPrefix${chatId}_page_$page';

  /// Get metadata cache key for a chat
  String _getMetaKey(String chatId) => '$_cacheMetaKey$chatId';

  /// Initialize cache for a specific chat
  Future<void> initializeCacheForChat(String chatId) async {
    try {
      developer.log('🔧 Initializing cache for chat: $chatId');
      
      // Load pagination metadata
      final box = await _openBox();
      final metaJson = await _getWithLegacyFallback(box, _getMetaKey(chatId));
      if (metaJson != null) {
        final metaData = jsonDecode(metaJson);
        _paginationInfo[chatId] = ChatPaginationInfo.fromJson(metaData);
        developer.log('📊 Loaded pagination info for chat $chatId');
      }

      // Initialize session cache if not exists
      _sessionCache[chatId] ??= {};
      _cacheTimestamps[chatId] ??= {};
      
      developer.log('✅ Cache initialized for chat: $chatId');
    } catch (e) {
      developer.log('❌ Error initializing cache for chat $chatId: $e');
    }
  }

  /// Check if data exists in cache for a specific page
  bool hasPageInCache(String chatId, int page) {
    // First check session cache
    if (_sessionCache[chatId]?.containsKey(page) == true) {
      // Check if cache is still valid
      final timestamp = _cacheTimestamps[chatId]?[page];
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return true;
      } else {
        // Remove expired cache
        _sessionCache[chatId]?.remove(page);
        _cacheTimestamps[chatId]?.remove(page);
      }
    }
    return false;
  }

  /// Get cached messages for a specific page
  Future<List<Records>?> getCachedPage(String chatId, int page) async {
    try {
      // First try session cache
      if (hasPageInCache(chatId, page)) {
        developer.log('🎯 Retrieved page $page from session cache for chat $chatId');
        return _sessionCache[chatId]![page];
      }

      // Try persistent storage
      final cacheKey = _getCacheKey(chatId, page);
      final box = await _openBox();
      final cachedJson = await _getWithLegacyFallback(box, cacheKey);

      if (cachedJson != null) {
        final cachedData = jsonDecode(cachedJson);
        final timestamp = DateTime.parse(cachedData['timestamp']);
        
        // Check if cache is still valid
        if (DateTime.now().difference(timestamp) < _cacheExpiry) {
          final messages = (cachedData['messages'] as List)
              .map((json) => Records.fromJson(json))
              .toList();
          
          // Update session cache
          _sessionCache[chatId] ??= {};
          _cacheTimestamps[chatId] ??= {};
          _sessionCache[chatId]![page] = messages;
          _cacheTimestamps[chatId]![page] = timestamp;
          
          developer.log('💾 Retrieved page $page from persistent cache for chat $chatId');
          return messages;
        } else {
          // Remove expired cache
          await box?.delete(cacheKey);
          developer.log('🗑️ Removed expired cache for chat $chatId page $page');
        }
      }
      
      return null;
    } catch (e) {
      developer.log('❌ Error retrieving cached page $page for chat $chatId: $e');
      return null;
    }
  }

  /// Cache messages for a specific page
  Future<void> cachePage(
    String chatId, 
    int page, 
    List<Records> messages,
    {ChatPaginationInfo? paginationInfo}
  ) async {
    try {
      developer.log('💾 Caching page $page for chat $chatId with ${messages.length} messages');
      
      // Update session cache
      _sessionCache[chatId] ??= {};
      _cacheTimestamps[chatId] ??= {};
      _sessionCache[chatId]![page] = List.from(messages);
      _cacheTimestamps[chatId]![page] = DateTime.now();

      final box = await _openBox();

      // Update pagination info if provided
      if (paginationInfo != null) {
        _paginationInfo[chatId] = paginationInfo;
        await box?.put(
          _getMetaKey(chatId),
          jsonEncode(paginationInfo.toJson()),
        );
      }

      // Save to persistent storage
      final cacheKey = _getCacheKey(chatId, page);
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'messages': messages.map((msg) => msg.toJson()).toList(),
      };

      await box?.put(cacheKey, jsonEncode(cacheData));
      
      // Clean up old cache if needed
      await _cleanupOldCache(chatId);
      
      developer.log('✅ Successfully cached page $page for chat $chatId');
    } catch (e) {
      developer.log('❌ Error caching page $page for chat $chatId: $e');
    }
  }

  /// Get all cached pages for a chat
  List<int> getCachedPages(String chatId) {
    final sessionPages = _sessionCache[chatId]?.keys.toList() ?? [];
    return sessionPages..sort();
  }

  /// Get cached messages for multiple pages
  Future<Map<int, List<Records>>> getCachedPagesData(String chatId, List<int> pages) async {
    final Map<int, List<Records>> result = {};
    
    for (final page in pages) {
      final messages = await getCachedPage(chatId, page);
      if (messages != null) {
        result[page] = messages;
      }
    }
    
    return result;
  }

  /// Get pagination info for a chat
  ChatPaginationInfo? getPaginationInfo(String chatId) {
    return _paginationInfo[chatId];
  }

  /// Clear cache for a specific chat
  Future<void> clearChatCache(String chatId) async {
    try {
      developer.log('🗑️ Clearing cache for chat: $chatId');
      
      // Clear session cache
      _sessionCache.remove(chatId);
      _cacheTimestamps.remove(chatId);
      _paginationInfo.remove(chatId);

      // Clear persistent storage
      final box = await _openBox();

      // Get all possible cached pages and remove them
      for (int page = 1; page <= _maxCachedPages; page++) {
        final cacheKey = _getCacheKey(chatId, page);
        await box?.delete(cacheKey);
      }

      // Remove metadata
      await box?.delete(_getMetaKey(chatId));
      
      developer.log('✅ Cache cleared for chat: $chatId');
    } catch (e) {
      developer.log('❌ Error clearing cache for chat $chatId: $e');
    }
  }

  /// Clear all cache data
  ///
  /// Called from the logout flow (AuthProvider.logout), which previously
  /// relied on the *following* SecurePrefs.clear() call to blanket-wipe the
  /// persisted cache as a side effect of clearing all of secure storage.
  /// Now that this cache lives in its own Hive box, that side effect no
  /// longer reaches it, so this explicitly clears the box too — otherwise a
  /// previous user's cached chat pages would keep sitting on disk (unread,
  /// since chat IDs won't collide across accounts, but not actually wiped)
  /// after logout on a shared/handed-down device.
  Future<void> clearAllCache() async {
    try {
      developer.log('🗑️ Clearing all chat cache');

      _sessionCache.clear();
      _cacheTimestamps.clear();
      _paginationInfo.clear();

      final box = await _openBox();
      await box?.clear();

      developer.log('✅ All cache cleared');
    } catch (e) {
      developer.log('❌ Error clearing all cache: $e');
    }
  }

  /// Clean up old cache entries to prevent storage bloat
  Future<void> _cleanupOldCache(String chatId) async {
    try {
      final cachedPages = getCachedPages(chatId);
      
      if (cachedPages.length > _maxCachedPages) {
        // Remove oldest pages (keep most recent ones)
        final pagesToRemove = cachedPages.take(cachedPages.length - _maxCachedPages);
        final box = await _openBox();

        for (final page in pagesToRemove) {
          _sessionCache[chatId]?.remove(page);
          _cacheTimestamps[chatId]?.remove(page);
          await box?.delete(_getCacheKey(chatId, page));
        }
        
        developer.log('🧹 Cleaned up ${pagesToRemove.length} old cache pages for chat $chatId');
      }
    } catch (e) {
      developer.log('❌ Error cleaning up cache: $e');
    }
  }

  /// Get cache size info for debugging
  Map<String, dynamic> getCacheInfo() {
    final info = <String, dynamic>{};
    
    for (final chatId in _sessionCache.keys) {
      info[chatId] = {
        'cached_pages': getCachedPages(chatId),
        'total_messages': _sessionCache[chatId]?.values
            .fold<int>(0, (sum, messages) => sum + messages.length) ?? 0,
      };
    }
    
    return info;
  }

  /// Update cached messages (for real-time updates)
  Future<void> updateMessage(String chatId, Records updatedMessage) async {
    try {
      // Update in all cached pages that contain this message
      final cachedPages = getCachedPages(chatId);
      bool messageUpdated = false;
      
      for (final page in cachedPages) {
        final messages = _sessionCache[chatId]![page]!;
        final messageIndex = messages.indexWhere((msg) => msg.messageId == updatedMessage.messageId);
        
        if (messageIndex != -1) {
          messages[messageIndex] = updatedMessage;
          messageUpdated = true;
          
          // Update persistent cache for this page
          await cachePage(chatId, page, messages);
          developer.log('🔄 Updated message ${updatedMessage.messageId} in cached page $page');
        }
      }
      
      if (!messageUpdated) {
        developer.log('⚠️ Message ${updatedMessage.messageId} not found in cache for update');
      }
    } catch (e) {
      developer.log('❌ Error updating cached message: $e');
    }
  }

  /// Add new message to cache (for real-time messages)
  /// ✅ ENHANCED: Now properly handles optimistic message replacement
  Future<void> addNewMessage(String chatId, Records newMessage) async {
    try {
      // Add to the first page (most recent messages)
      const int firstPage = 1;

      if (hasPageInCache(chatId, firstPage)) {
        final messages = _sessionCache[chatId]![firstPage]!;

        // ✅ Check if message already exists (by messageId)
        final existsById = newMessage.messageId != null &&
            messages.any((m) => m.messageId == newMessage.messageId);

        if (existsById) {
          developer.log('⚠️ Message ${newMessage.messageId} already in cache, skipping add');
          return;
        }

        // ✅ FIX: Check for matching optimistic message and REPLACE it
        final optimisticIndex = _findMatchingOptimisticMessage(messages, newMessage);

        if (optimisticIndex != -1) {
          // Replace the optimistic message with the confirmed server message
          final optimisticMsg = messages[optimisticIndex];
          developer.log('🔄 Replacing optimistic message (tempId: ${optimisticMsg.tempId}) with server message (id: ${newMessage.messageId})');
          messages[optimisticIndex] = newMessage;
          await cachePage(chatId, firstPage, messages);
          developer.log('✅ Replaced optimistic message in cache');
          return;
        }

        // No optimistic match found, add as new
        messages.insert(0, newMessage);
        await cachePage(chatId, firstPage, messages);
        developer.log('➕ Added new message to cached page $firstPage');
      }
    } catch (e) {
      developer.log('❌ Error adding new message to cache: $e');
    }
  }

  /// ✅ NEW: Find a matching optimistic message by content, sender, and timestamp
  int _findMatchingOptimisticMessage(List<Records> messages, Records serverMessage) {
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];

      // Only check optimistic messages (has tempId or sendingStatus is sending)
      if (msg.tempId == null && msg.sendingStatus != MessageSendingStatus.sending) {
        continue;
      }

      // Match by content, sender, and message type
      if (msg.messageContent == serverMessage.messageContent &&
          msg.senderId == serverMessage.senderId &&
          msg.messageType == serverMessage.messageType) {

        // Check timestamp proximity (within 60 seconds)
        bool timestampClose = true;
        if (msg.createdAt != null && serverMessage.createdAt != null) {
          try {
            final optimisticTime = DateTime.parse(msg.createdAt!);
            final serverTime = DateTime.parse(serverMessage.createdAt!);
            final difference = serverTime.difference(optimisticTime).abs();
            timestampClose = difference.inSeconds < 60;
          } catch (e) {
            // If parsing fails, assume close enough
            developer.log('⚠️ Timestamp parse error during optimistic match: $e');
          }
        }

        if (timestampClose) {
          return i;
        }
      }
    }
    return -1;
  }

  /// ✅ NEW: Update optimistic message by tempId
  Future<void> updateOptimisticMessage(String chatId, String tempId, Records updatedMessage) async {
    try {
      final cachedPages = getCachedPages(chatId);
      bool messageUpdated = false;

      for (final page in cachedPages) {
        final messages = _sessionCache[chatId]![page]!;
        final messageIndex = messages.indexWhere((msg) => msg.tempId == tempId);

        if (messageIndex != -1) {
          messages[messageIndex] = updatedMessage;
          messageUpdated = true;

          await cachePage(chatId, page, messages);
          developer.log('🔄 Updated optimistic message $tempId in cached page $page');
          break;
        }
      }

      if (!messageUpdated) {
        developer.log('⚠️ Optimistic message $tempId not found in cache for update');
      }
    } catch (e) {
      developer.log('❌ Error updating optimistic cached message: $e');
    }
  }

  /// ✅ NEW: Confirm optimistic message (replace tempId with real messageId)
  Future<void> confirmOptimisticMessage(
    String chatId,
    String tempId,
    int messageId,
    {String? seenStatus, int? conversationSeq}
  ) async {
    try {
      final cachedPages = getCachedPages(chatId);

      for (final page in cachedPages) {
        final messages = _sessionCache[chatId]![page]!;
        final messageIndex = messages.indexWhere((msg) => msg.tempId == tempId);

        if (messageIndex != -1) {
          final message = messages[messageIndex];
          message.messageId = messageId;
          message.sendingStatus = MessageSendingStatus.sent;
          message.messageSeenStatus = seenStatus ?? 'sent';
          // conversationSeq lives on `unseenCount` (see MessageAdapter) so a
          // cache-restored message can still be promoted to 'seen' by a
          // later read-watermark update.
          if (conversationSeq != null && conversationSeq > 0) {
            message.unseenCount = conversationSeq;
          }
          message.tempId = null;

          await cachePage(chatId, page, messages);
          developer.log('✅ Confirmed optimistic message $tempId -> $messageId in cache');
          break;
        }
      }
    } catch (e) {
      developer.log('❌ Error confirming optimistic message in cache: $e');
    }
  }

  /// ✅ NEW: Mark optimistic message as failed
  Future<void> markOptimisticMessageFailed(String chatId, String tempId) async {
    try {
      final cachedPages = getCachedPages(chatId);

      for (final page in cachedPages) {
        final messages = _sessionCache[chatId]![page]!;
        final messageIndex = messages.indexWhere((msg) => msg.tempId == tempId);

        if (messageIndex != -1) {
          messages[messageIndex].sendingStatus = MessageSendingStatus.failed;

          await cachePage(chatId, page, messages);
          developer.log('❌ Marked optimistic message $tempId as failed in cache');
          break;
        }
      }
    } catch (e) {
      developer.log('❌ Error marking optimistic message as failed in cache: $e');
    }
  }
}

/// Pagination information for cached chat data
class ChatPaginationInfo {
  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final bool hasMore;

  ChatPaginationInfo({
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.hasMore,
  });

  Map<String, dynamic> toJson() => {
    'currentPage': currentPage,
    'totalPages': totalPages,
    'totalRecords': totalRecords,
    'hasMore': hasMore,
  };

  factory ChatPaginationInfo.fromJson(Map<String, dynamic> json) => ChatPaginationInfo(
    currentPage: json['currentPage'] ?? 1,
    totalPages: json['totalPages'] ?? 1,
    totalRecords: json['totalRecords'] ?? 0,
    hasMore: json['hasMore'] ?? false,
  );
}