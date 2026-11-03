import 'dart:developer' as developer;
import 'package:whoxa/featuers/chat/data/chats_model.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/services/chat_cache_service.dart';

/// Extension for ChatProvider to add caching functionality
/// 
/// This extension provides:
/// - Intelligent page caching for Universal Chat Screen
/// - Cache-first data loading strategy
/// - Session persistence across tab switches
/// - Optimized pagination with cache integration
extension CachedChatProviderExtension on ChatProvider {
  
  static final ChatCacheService _cacheService = ChatCacheService();
  
  /// Initialize cache for a specific chat
  Future<void> initializeCacheForChat(String chatId) async {
    await _cacheService.initializeCacheForChat(chatId);
  }
  
  /// Load messages with cache-first strategy
  /// 
  /// This method:
  /// 1. Checks cache for requested page
  /// 2. Returns cached data if available and valid
  /// 3. Falls back to server fetch if cache miss
  /// 4. Updates cache with fresh data
  Future<ChatsModel?> loadMessagesWithCache({
    required String chatId,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    try {
      developer.log('🔍 Loading messages for chat $chatId, page $page (forceRefresh: $forceRefresh)');
      
      // Initialize cache if not already done
      await _cacheService.initializeCacheForChat(chatId);
      
      // Check cache first (unless force refresh)
      if (!forceRefresh && _cacheService.hasPageInCache(chatId, page)) {
        final cachedMessages = await _cacheService.getCachedPage(chatId, page);
        if (cachedMessages != null && cachedMessages.isNotEmpty) {
          developer.log('✅ Returning cached data for chat $chatId, page $page (${cachedMessages.length} messages)');
          
          // Create ChatsModel from cached data
          final chatModel = ChatsModel(
            records: cachedMessages,
            pagination: _createPaginationFromCache(chatId, page),
          );
          
          // Update provider state with cached data
          _updateProviderWithCachedData(chatModel, page);
          
          return chatModel;
        }
      }
      
      // Cache miss or force refresh - fetch from server
      developer.log('📡 Fetching fresh data from server for chat $chatId, page $page');
      
      // Use existing loadMoreMessages method or direct API call
      // This will depend on your current implementation
      final freshData = await _fetchMessagesFromServer(chatId, page);
      
      if (freshData != null && freshData.records != null) {
        // Cache the fresh data
        final paginationInfo = ChatPaginationInfo(
          currentPage: freshData.pagination?.currentPage ?? page,
          totalPages: freshData.pagination?.totalPages ?? 1,
          totalRecords: freshData.pagination?.totalRecords ?? 0,
          hasMore: (freshData.pagination?.currentPage ?? page) < (freshData.pagination?.totalPages ?? 1),
        );
        
        await _cacheService.cachePage(
          chatId,
          page,
          freshData.records!,
          paginationInfo: paginationInfo,
        );
        
        developer.log('💾 Cached fresh data for chat $chatId, page $page');
      }
      
      return freshData;
      
    } catch (e) {
      developer.log('❌ Error loading messages with cache for chat $chatId: $e');
      
      // Fallback to cache if server fails
      final cachedMessages = await _cacheService.getCachedPage(chatId, page);
      if (cachedMessages != null) {
        developer.log('🔄 Falling back to cached data due to server error');
        return ChatsModel(
          records: cachedMessages,
          pagination: _createPaginationFromCache(chatId, page),
        );
      }
      
      rethrow;
    }
  }
  
  /// Load multiple pages efficiently with cache
  Future<Map<int, ChatsModel>> loadMultiplePagesWithCache({
    required String chatId,
    required List<int> pages,
    bool forceRefresh = false,
  }) async {
    final Map<int, ChatsModel> result = {};
    
    // Check which pages are in cache
    final List<int> cachedPages = [];
    final List<int> uncachedPages = [];
    
    for (final page in pages) {
      if (!forceRefresh && _cacheService.hasPageInCache(chatId, page)) {
        cachedPages.add(page);
      } else {
        uncachedPages.add(page);
      }
    }
    
    // Load cached pages
    for (final page in cachedPages) {
      final cachedMessages = await _cacheService.getCachedPage(chatId, page);
      if (cachedMessages != null) {
        result[page] = ChatsModel(
          records: cachedMessages,
          pagination: _createPaginationFromCache(chatId, page),
        );
      }
    }
    
    // Load uncached pages from server
    for (final page in uncachedPages) {
      final freshData = await loadMessagesWithCache(
        chatId: chatId,
        page: page,
        forceRefresh: true,
      );
      if (freshData != null) {
        result[page] = freshData;
      }
    }
    
    developer.log('📊 Loaded ${result.length} pages for chat $chatId (${cachedPages.length} from cache, ${uncachedPages.length} from server)');
    
    return result;
  }
  
  /// Enhanced loadMoreMessages with caching support
  Future<void> loadMoreMessagesWithCache() async {
    try {
      final currentChatId = getCurrentChatId(); // You'll need to implement this
      if (currentChatId == null) {
        developer.log('⚠️ No current chat ID available for pagination');
        return;
      }
      
      // Get next page number
      final nextPage = (currentPage ?? 0) + 1;
      
      // Check if we have more pages to load
      final paginationInfo = _cacheService.getPaginationInfo(currentChatId);
      if (paginationInfo != null && !paginationInfo.hasMore) {
        developer.log('🏁 No more pages to load for chat $currentChatId');
        return;
      }
      
      // Load next page with cache
      final nextPageData = await loadMessagesWithCache(
        chatId: currentChatId,
        page: nextPage,
      );
      
      if (nextPageData != null && nextPageData.records != null) {
        // Append to existing messages (your existing logic)
        _appendMessagesToCurrentList(nextPageData.records!);
        developer.log('📄 Loaded page $nextPage with ${nextPageData.records!.length} messages');
      }
      
    } catch (e) {
      developer.log('❌ Error in loadMoreMessagesWithCache: $e');
      // Fallback to original loadMoreMessages
      await loadMoreMessages();
    }
  }
  
  /// Get cached pages info for current chat
  List<int> getCachedPagesForCurrentChat() {
    final currentChatId = getCurrentChatId();
    if (currentChatId == null) return [];
    
    return _cacheService.getCachedPages(currentChatId);
  }
  
  /// Clear cache for current chat
  Future<void> clearCurrentChatCache() async {
    final currentChatId = getCurrentChatId();
    if (currentChatId != null) {
      await _cacheService.clearChatCache(currentChatId);
      developer.log('🗑️ Cleared cache for current chat: $currentChatId');
    }
  }
  
  /// Update cached message (for real-time updates)
  Future<void> updateCachedMessage(Records updatedMessage) async {
    final currentChatId = getCurrentChatId();
    if (currentChatId != null) {
      await _cacheService.updateMessage(currentChatId, updatedMessage);
    }
  }
  
  /// Add new message to cache (for real-time messages)
  Future<void> addNewMessageToCache(Records newMessage) async {
    final currentChatId = getCurrentChatId();
    if (currentChatId != null) {
      await _cacheService.addNewMessage(currentChatId, newMessage);
    }
  }
  
  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheInfo() {
    return _cacheService.getCacheInfo();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Create pagination object from cached data
  Pagination? _createPaginationFromCache(String chatId, int page) {
    final paginationInfo = _cacheService.getPaginationInfo(chatId);
    if (paginationInfo == null) return null;
    
    return Pagination(
      currentPage: paginationInfo.currentPage,
      totalPages: paginationInfo.totalPages,
      totalRecords: paginationInfo.totalRecords,
      recordsPerPage: 20, // Default page size
    );
  }
  
  /// Update provider state with cached data
  void _updateProviderWithCachedData(ChatsModel chatModel, int page) {
    // This should integrate with your existing provider state management
    // You might need to modify this based on your current implementation
    
    // Example implementation:
    if (page == 1) {
      // First page - replace data
      updateCurrentChatData(chatModel);
    } else {
      // Subsequent pages - append data
      appendToChatData(chatModel);
    }
  }
  
  /// Fetch messages from server (you'll need to implement based on your API)
  Future<ChatsModel?> _fetchMessagesFromServer(String chatId, int page) async {
    // This should call your existing API method
    // For example, it might trigger a socket event or HTTP request
    
    // Placeholder implementation - you'll need to adapt this
    // to your existing message loading mechanism
    
    try {
      // Option 1: Use existing loadMoreMessages and capture the result
      await loadMoreMessages();
      
      // Option 2: Direct API call (implement based on your architecture)
      // return await chatRepository.getMessages(chatId: chatId, page: page);
      
      // For now, return null to indicate you need to implement this
      // based on your specific architecture
      return null;
      
    } catch (e) {
      developer.log('❌ Error fetching messages from server: $e');
      return null;
    }
  }
  
  /// Get current chat ID (implement based on your state management)
  String? getCurrentChatId() {
    // For now, return null - this will be set by the UI layer
    // The Universal Screen will call the methods with explicit chatId
    return null;
  }
  
  /// Get current page number
  int? get currentPage {
    // Use existing pagination state from ChatProvider
    return chatListCurrentPage;
  }
  
  /// Update current chat data (implement based on your state management)
  void updateCurrentChatData(ChatsModel chatModel) {
    // Use existing provider methods to update chat data
    // This would integrate with your existing state management
    // Note: notifyListeners() will be called by the provider's existing methods
  }
  
  /// Append to current chat data (implement based on your state management)  
  void appendToChatData(ChatsModel chatModel) {
    // Use existing provider methods to append chat data
    // This would integrate with your existing state management
    // Note: notifyListeners() will be called by the provider's existing methods
  }
  
  /// Append messages to current list (implement based on your state management)
  void _appendMessagesToCurrentList(List<Records> messages) {
    // Use existing provider methods to append messages
    // This would integrate with your existing state management
    // Note: notifyListeners() will be called by the provider's existing methods
  }
}