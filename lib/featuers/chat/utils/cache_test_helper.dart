import 'dart:developer' as developer;
import 'package:whoxa/featuers/chat/data/chats_model.dart';
import 'package:whoxa/featuers/chat/utils/chat_cache_manager.dart';

/// Test helper class for validating cache functionality
/// 
/// This class provides methods to test and validate the caching system
/// Use this during development to ensure cache works correctly
class CacheTestHelper {
  
  /// Test basic cache operations
  static Future<bool> testBasicCacheOperations() async {
    try {
      developer.log('🧪 Testing basic cache operations...');
      
      const testChatId = 'test_chat_123';
      const testPage = 1;
      
      // Create test messages
      final testMessages = _createTestMessages(5);
      
      // Initialize cache
      await ChatCacheManager.initializeChat(testChatId);
      
      // Test caching
      await ChatCacheManager.cachePage(testChatId, testPage, testMessages);
      
      // Test retrieval
      final retrievedMessages = await ChatCacheManager.getPage(testChatId, testPage);
      
      // Validate
      if (retrievedMessages == null || retrievedMessages.length != testMessages.length) {
        developer.log('❌ Cache test failed: Message count mismatch');
        return false;
      }
      
      // Test cache existence check
      final hasPage = ChatCacheManager.hasPage(testChatId, testPage);
      if (!hasPage) {
        developer.log('❌ Cache test failed: hasPage returned false');
        return false;
      }
      
      // Test cached pages list
      final cachedPages = ChatCacheManager.getCachedPages(testChatId);
      if (!cachedPages.contains(testPage)) {
        developer.log('❌ Cache test failed: Page not in cached pages list');
        return false;
      }
      
      developer.log('✅ Basic cache operations test passed');
      return true;
      
    } catch (e) {
      developer.log('❌ Cache test failed with error: $e');
      return false;
    }
  }
  
  /// Test multiple page caching
  static Future<bool> testMultiplePageCaching() async {
    try {
      developer.log('🧪 Testing multiple page caching...');
      
      const testChatId = 'test_chat_multi_456';
      const numPages = 5;
      
      await ChatCacheManager.initializeChat(testChatId);
      
      // Cache multiple pages
      for (int page = 1; page <= numPages; page++) {
        final testMessages = _createTestMessages(10 + page); // Different sizes
        await ChatCacheManager.cachePage(testChatId, page, testMessages);
      }
      
      // Verify all pages are cached
      final cachedPages = ChatCacheManager.getCachedPages(testChatId);
      if (cachedPages.length != numPages) {
        developer.log('❌ Multi-page test failed: Expected $numPages, got ${cachedPages.length}');
        return false;
      }
      
      // Test retrieval of each page
      for (int page = 1; page <= numPages; page++) {
        final messages = await ChatCacheManager.getPage(testChatId, page);
        if (messages == null || messages.length != (10 + page)) {
          developer.log('❌ Multi-page test failed: Page $page retrieval failed');
          return false;
        }
      }
      
      developer.log('✅ Multiple page caching test passed');
      return true;
      
    } catch (e) {
      developer.log('❌ Multi-page cache test failed: $e');
      return false;
    }
  }
  
  /// Test session persistence simulation
  static Future<bool> testSessionPersistence() async {
    try {
      developer.log('🧪 Testing session persistence...');
      
      const testChatId = 'test_chat_persist_789';
      const testPage = 1;
      
      // Initialize and cache data
      await ChatCacheManager.initializeChat(testChatId);
      final originalMessages = _createTestMessages(8);
      await ChatCacheManager.cachePage(testChatId, testPage, originalMessages);
      
      // Simulate screen rebuild by reinitializing
      await ChatCacheManager.initializeChat(testChatId);
      
      // Check if data persists
      final persistedMessages = await ChatCacheManager.getPage(testChatId, testPage);
      
      if (persistedMessages == null || persistedMessages.length != originalMessages.length) {
        developer.log('❌ Session persistence test failed: Data not persisted');
        return false;
      }
      
      // Validate message content persisted correctly
      for (int i = 0; i < originalMessages.length; i++) {
        if (originalMessages[i].messageId != persistedMessages[i].messageId) {
          developer.log('❌ Session persistence test failed: Message ID mismatch');
          return false;
        }
      }
      
      developer.log('✅ Session persistence test passed');
      return true;
      
    } catch (e) {
      developer.log('❌ Session persistence test failed: $e');
      return false;
    }
  }
  
  /// Test cache update functionality
  static Future<bool> testCacheUpdate() async {
    try {
      developer.log('🧪 Testing cache update functionality...');
      
      const testChatId = 'test_chat_update_999';
      
      await ChatCacheManager.initializeChat(testChatId);
      
      // Create and cache initial message
      final originalMessage = _createTestMessage(1, 'Original content');
      await ChatCacheManager.cachePage(testChatId, 1, [originalMessage]);
      
      // Update the message
      final updatedMessage = _createTestMessage(1, 'Updated content');
      await ChatCacheManager.updateMessage(testChatId, updatedMessage);
      
      // Retrieve and verify update
      final cachedMessages = await ChatCacheManager.getPage(testChatId, 1);
      if (cachedMessages == null || cachedMessages.isEmpty) {
        developer.log('❌ Cache update test failed: No messages found');
        return false;
      }
      
      if (cachedMessages.first.messageContent != 'Updated content') {
        developer.log('❌ Cache update test failed: Content not updated');
        return false;
      }
      
      developer.log('✅ Cache update test passed');
      return true;
      
    } catch (e) {
      developer.log('❌ Cache update test failed: $e');
      return false;
    }
  }
  
  /// Run all cache tests
  static Future<bool> runAllTests() async {
    developer.log('🚀 Starting comprehensive cache tests...');
    
    final results = await Future.wait([
      testBasicCacheOperations(),
      testMultiplePageCaching(),
      testSessionPersistence(),
      testCacheUpdate(),
    ]);
    
    final allPassed = results.every((result) => result);
    
    if (allPassed) {
      developer.log('🎉 All cache tests passed successfully!');
    } else {
      developer.log('⚠️  Some cache tests failed. Check logs above.');
    }
    
    return allPassed;
  }
  
  /// Create test messages for testing
  static List<Records> _createTestMessages(int count) {
    return List.generate(count, (index) => _createTestMessage(index + 1, 'Test message ${index + 1}'));
  }
  
  /// Create a single test message
  static Records _createTestMessage(int id, String content) {
    return Records(
      messageId: id,
      messageContent: content,
      messageType: 'text',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      senderId: 123,
      chatId: 456,
      messageSeenStatus: 'sent',
      pinned: false,
      stared: false,
      deletedForEveryone: false,
    );
  }
  
  /// Demo cache usage for a sample chat
  static Future<void> demoCache() async {
    developer.log('📚 Cache Demo Starting...');
    
    const demoChat = 'demo_chat_001';
    
    // Initialize
    await ChatCacheManager.initializeChat(demoChat);
    
    // Simulate loading pages
    for (int page = 1; page <= 3; page++) {
      final messages = _createTestMessages(15);
      await ChatCacheManager.cachePage(demoChat, page, messages);
      developer.log('📄 Cached page $page with ${messages.length} messages');
    }
    
    // Show cache stats
    ChatCacheManager.logCacheStats(demoChat);
    
    // Simulate tab switch - check cached data is available
    developer.log('🔄 Simulating tab switch...');
    final cachedPages = ChatCacheManager.getCachedPages(demoChat);
    developer.log('✅ Available cached pages after tab switch: $cachedPages');
    
    // Simulate accessing cached data
    for (final page in cachedPages) {
      final messages = await ChatCacheManager.getPage(demoChat, page);
      developer.log('📖 Retrieved page $page: ${messages?.length ?? 0} messages');
    }
    
    developer.log('🏁 Cache Demo Complete!');
  }
}