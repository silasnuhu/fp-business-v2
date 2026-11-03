import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/services/socket/socket_event_controller.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';
import 'package:whoxa/widgets/custom_check_circle.dart';
import 'package:whoxa/widgets/global.dart';

// Forward item model to unify different data types
class ForwardItem {
  final String id;
  final String name;
  final String phoneNumber;
  final String? profilePic;
  final ForwardItemType type;
  final int? chatId;
  final int? userId;
  final String? lastMessage;
  final String? lastMessageTime;
  final bool isOnline;
  final int unseenCount;
  final String? chatType;
  final bool isSelected;
  // `@handle` shown instead of a phone number the backend does not send.
  final String? userName;

  ForwardItem({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.profilePic,
    required this.type,
    this.chatId,
    this.userId,
    this.lastMessage,
    this.lastMessageTime,
    this.isOnline = false,
    this.unseenCount = 0,
    this.chatType,
    this.isSelected = false,
    this.userName,
  });

  // Create from chat list item (existing chats) - EXACTLY like main chat list
  factory ForwardItem.fromChatList(dynamic chat) {
    try {
      final peer = chat.peerUserData;
      final record =
          chat.records?.isNotEmpty == true ? chat.records!.first : null;
      final lastMessage =
          record?.messages?.isNotEmpty == true ? record.messages!.first : null;
      final unseenCount = record?.unseenCount ?? 0;
      final chatType = record?.chatType ?? 'Private';
      final isGroupChat = chatType.toLowerCase() == 'group';

      // Use the EXACT same name logic as main chat list
      final String displayName = _getDisplayName(chatType, record, peer);
      final String profilePic = _getProfilePic(isGroupChat, record, peer);

      // Generate unique ID - use chatId if available, otherwise use userId, fallback to timestamp
      final String uniqueId;
      if (record?.chatId != null) {
        uniqueId = 'chat_${record!.chatId}';
      } else if (peer?.userId != null) {
        uniqueId = 'user_${peer!.userId}';
      } else {
        // Fallback to timestamp + random to ensure uniqueness
        uniqueId =
            'temp_${DateTime.now().millisecondsSinceEpoch}_${peer?.email?.hashCode ?? peer?.userName?.hashCode ?? 0}';
      }

      // Validate display name is not empty
      if (displayName.trim().isEmpty) {
        throw Exception('Display name cannot be empty for chat');
      }

      return ForwardItem(
        id: uniqueId,
        name: displayName,
        phoneNumber: peer?.phoneNumber ?? '',
        profilePic: profilePic,
        type: ForwardItemType.recentChat,
        chatId: record?.chatId,
        userId: peer?.userId,
        lastMessage:
            lastMessage?.messageContent ??
            (record == null ? 'No messages yet' : null),
        lastMessageTime: lastMessage?.createdAt,
        unseenCount: unseenCount,
        chatType: chatType,
        userName: peer?.userName,
      );
    } catch (e) {
      // Log the error and rethrow with more context
      debugPrint('🔍 ForwardItem.fromChatList Error: $e');
      debugPrint('🔍 Chat data: ${chat.toString()}');
      rethrow;
    }
  }

  // Helper methods - EXACTLY like main chat list (saved contact name wins,
  // via the same ContactNameService priority chain used everywhere else).
  static String _getDisplayName(String chatType, dynamic record, dynamic peer) {
    if (chatType.toLowerCase() == 'group') {
      if (record?.groupName != null && record!.groupName!.trim().isNotEmpty) {
        return record.groupName!;
      }
      if (peer?.fullName != null && peer!.fullName!.trim().isNotEmpty) {
        return "${peer.fullName!} (Group)";
      }
      if (peer?.userName != null && peer!.userName!.trim().isNotEmpty) {
        return "${peer.userName!} (Group)";
      }
      return 'Group Chat';
    } else {
      return ContactNameService.instance.resolveName(
        userId: peer?.userId,
        firstName: peer?.firstName,
        lastName: peer?.lastName,
        fullName: peer?.fullName,
        userName: peer?.userName,
        email: peer?.email,
        fallback: 'Unknown User',
      );
    }
  }

  static String _getProfilePic(bool isGroupChat, dynamic record, dynamic peer) {
    if (isGroupChat) {
      if (record?.groupIcon != null && record!.groupIcon!.isNotEmpty) {
        return record.groupIcon!;
      }
      return peer?.profilePic ?? '';
    } else {
      return peer?.profilePic ?? '';
    }
  }

  // Create from contact item (contacts without existing chats)
  factory ForwardItem.fromContact(ContactModel contact, bool isOnline) {
    final parsedUserId =
        contact.userId != null ? int.tryParse(contact.userId!) : null;
    return ForwardItem(
      id: 'contact_${contact.userId ?? 0}',
      // `contact.name` is already the device address-book name; still route it
      // through the resolver so a synced saved-name change is reflected too.
      name: ContactNameService.instance.resolveName(
        userId: parsedUserId,
        fullName: contact.name.isNotEmpty ? contact.name : null,
        fallback: 'Unknown Contact',
      ),
      profilePic: null,
      type: ForwardItemType.contact,
      chatId: null,
      userId: parsedUserId,
      lastMessage: null,
      lastMessageTime: null,
      isOnline: isOnline,
      unseenCount: 0,
      phoneNumber: contact.phoneNumber,
    );
  }

  ForwardItem copyWith({bool? isSelected}) {
    return ForwardItem(
      id: id,
      phoneNumber: phoneNumber,
      name: name,
      profilePic: profilePic,
      type: type,
      chatId: chatId,
      userId: userId,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      isOnline: isOnline,
      unseenCount: unseenCount,
      chatType: chatType,
      isSelected: isSelected ?? this.isSelected,
      userName: userName,
    );
  }
}

enum ForwardItemType { recentChat, contact }

class ChatListForwardManager extends StatefulWidget {
  final Function(List<int> chatIds, List<int> userIds) onSelectionChanged;
  final Function(ForwardItem item) onItemTap;
  final Function(List<int> chatIds, List<int> userIds)? onForwardPressed;
  final bool showForwardButton;
  final List<int>? selectedMessageIds;
  final int? fromChatId;

  const ChatListForwardManager({
    super.key,
    required this.onSelectionChanged,
    required this.onItemTap,
    this.onForwardPressed,
    this.showForwardButton = true,
    this.selectedMessageIds,
    this.fromChatId,
  });

  @override
  State<ChatListForwardManager> createState() => _ChatListForwardManagerState();
}

class _ChatListForwardManagerState extends State<ChatListForwardManager>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late ScrollController _chatScrollController;
  late ScrollController _contactScrollController;

  // Data lists
  List<ForwardItem> _allRecentChats = [];
  List<ForwardItem> _allContacts = [];
  List<ForwardItem> _filteredRecentChats = [];
  List<ForwardItem> _filteredContacts = [];

  // Selection state
  final Set<String> _selectedItems = {};
  final Map<int, Set<String>> _userIdToItemIds =
      {}; // Track user ID to item IDs mapping

  // UI state
  String _searchQuery = '';
  int _currentTabIndex = 0;
  bool _hasLoadedChats = false;
  bool _hasLoadedContacts = false;
  bool _isLoadingChats = false;
  bool _isLoadingContacts = false;
  bool _isLoadingMoreChats = false;

  // Provider change tracking to prevent infinite loops
  int _lastChatCount = 0;
  int _lastContactCount = 0;

  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _chatScrollController = ScrollController();
    _contactScrollController = ScrollController();

    // Add scroll listeners for pagination
    _chatScrollController.addListener(_onChatScroll);
    _contactScrollController.addListener(_onContactScroll);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
          // Load data for the selected tab
          _loadDataForCurrentTab();
        });
      }
    });

    // Load initial data for the first tab (Recent Chats) and preload contacts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataForCurrentTab();
      _loadContacts(); // Preload contacts so they're ready when user switches tabs
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _chatScrollController.dispose();
    _contactScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterItems();
    });
  }

  /// Handle scroll events for chat list pagination
  void _onChatScroll() {
    final pixels = _chatScrollController.position.pixels;
    final maxExtent = _chatScrollController.position.maxScrollExtent;
    final distanceToEnd = maxExtent - pixels;

    debugPrint(
      '🔍 Forward Scroll Debug: pixels: $pixels, maxExtent: $maxExtent, distanceToEnd: $distanceToEnd',
    );

    if (pixels >= maxExtent - 100 && !_isLoadingMoreChats) {
      debugPrint('🔍 Forward Scroll Debug: Triggering load more chats');
      _loadMoreChats();
    } else {
      debugPrint(
        '🔍 Forward Scroll Debug: Not triggering - distanceToEnd: $distanceToEnd, isLoadingMore: $_isLoadingMoreChats',
      );
    }
  }

  /// Handle scroll events for contact list pagination
  void _onContactScroll() {
    // Contacts don't typically have pagination, but included for completeness
    // Could be used if contact list becomes paginated in the future
  }

  Future<void> _loadDataForCurrentTab() async {
    if (_currentTabIndex == 0 && !_hasLoadedChats) {
      await _loadRecentChats();
    } else if (_currentTabIndex == 1 && !_hasLoadedContacts) {
      await _loadContacts();
    }
    _filterItems();
  }

  /// Load all remaining pages to show complete chat list
  // ignore: unused_element
  Future<void> _loadAllRemainingPages() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    debugPrint(
      '🔍 Forward Load All Debug: Starting to load all remaining pages',
    );
    debugPrint(
      '🔍 Forward Load All Debug: Current page: ${chatProvider.chatListCurrentPage}',
    );
    debugPrint(
      '🔍 Forward Load All Debug: Total pages: ${chatProvider.chatListTotalPages}',
    );
    debugPrint(
      '🔍 Forward Load All Debug: hasChatListMoreData: ${chatProvider.hasChatListMoreData}',
    );

    while (chatProvider.hasChatListMoreData &&
        chatProvider.chatListCurrentPage < chatProvider.chatListTotalPages &&
        !chatProvider.isChatListPaginationLoading) {
      debugPrint(
        '🔍 Forward Load All Debug: Loading page ${chatProvider.chatListCurrentPage + 1}',
      );

      try {
        await chatProvider.loadMoreChatList();
        debugPrint(
          '🔍 Forward Load All Debug: Loaded page ${chatProvider.chatListCurrentPage}. Total chats now: ${chatProvider.chatListData.chats.length}',
        );

        // Update the recent chats data with new items
        _buildRecentChatsData(chatProvider);

        // Add a small delay to prevent overwhelming the API
        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('🔍 Forward Load All Debug: Error loading page: $e');
        break;
      }
    }

    debugPrint(
      '🔍 Forward Load All Debug: Finished loading all pages. Final chat count: ${chatProvider.chatListData.chats.length}',
    );
  }

  /// Load more chats when user scrolls near bottom (matches ChatList implementation)
  void _loadMoreChats() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    debugPrint('🔍 Forward Pagination Debug: Load more called');
    debugPrint(
      '🔍 Forward Pagination Debug: hasChatListMoreData: ${chatProvider.hasChatListMoreData}',
    );
    debugPrint(
      '🔍 Forward Pagination Debug: currentPage: ${chatProvider.chatListCurrentPage}',
    );
    debugPrint(
      '🔍 Forward Pagination Debug: totalPages: ${chatProvider.chatListTotalPages}',
    );

    // Check if we can load more
    if (!chatProvider.hasChatListMoreData) {
      debugPrint('🔍 Forward Pagination Debug: No more data available');
      return;
    }

    if (chatProvider.isChatListPaginationLoading || _isLoadingMoreChats) {
      debugPrint('🔍 Forward Pagination Debug: Already loading');
      return;
    }

    debugPrint('🔍 Forward Pagination Debug: Starting pagination load');
    setState(() {
      _isLoadingMoreChats = true;
    });

    try {
      await chatProvider.loadMoreChatList();
      debugPrint(
        '🔍 Forward Pagination Debug: Load complete. New currentPage: ${chatProvider.chatListCurrentPage}',
      );
      debugPrint(
        '🔍 Forward Pagination Debug: Provider now has ${chatProvider.chatListData.chats.length} total chats',
      );

      // Update the recent chats data with new items
      _buildRecentChatsData(chatProvider);

      // Force filter update to ensure UI reflects new data
      _filterItems();

      debugPrint(
        '🔍 Forward Pagination Debug: After update - _allRecentChats: ${_allRecentChats.length}, _filteredRecentChats: ${_filteredRecentChats.length}',
      );
    } catch (e) {
      debugPrint('🔍 Forward Pagination Debug: Error loading more chats: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreChats = false;
        });
      }
    }
  }

  Future<void> _loadRecentChats() async {
    if (_isLoadingChats) return;

    setState(() {
      _isLoadingChats = true;
    });

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      debugPrint(
        '🔍 Forward Initial Debug: Chat provider has ${chatProvider.chatListData.chats.length} chats',
      );
      debugPrint(
        '🔍 Forward Initial Debug: Current page: ${chatProvider.chatListCurrentPage}, Total pages: ${chatProvider.chatListTotalPages}',
      );

      if (chatProvider.chatListData.chats.isEmpty) {
        debugPrint('🔍 Forward Initial Debug: No chats found, refreshing...');
        await chatProvider.refreshChatList();
      }

      _buildRecentChatsData(chatProvider);

      // Update the last chat count after initial load
      _lastChatCount = chatProvider.chatListData.chats.length;

      setState(() {
        _hasLoadedChats = true;
      });

      // Let user manually scroll to load more pages (don't auto-load all pages)
      if (chatProvider.chatListTotalPages > 1 &&
          chatProvider.hasChatListMoreData) {
        debugPrint(
          '🔍 Forward Initial Debug: More pages available for manual loading...',
        );
        debugPrint(
          '🔍 Forward Initial Debug: Current page: ${chatProvider.chatListCurrentPage}, Total pages: ${chatProvider.chatListTotalPages}',
        );
        debugPrint(
          '🔍 Forward Initial Debug: hasChatListMoreData: ${chatProvider.hasChatListMoreData}',
        );
        debugPrint(
          '🔍 Forward Initial Debug: User can scroll down to load more chats',
        );
      }
    } finally {
      setState(() {
        _isLoadingChats = false;
      });
    }
  }

  Future<void> _loadContacts() async {
    if (_isLoadingContacts) return;

    setState(() {
      _isLoadingContacts = true;
    });

    try {
      final contactProvider = Provider.of<ContactListProvider>(
        context,
        listen: false,
      );

      if (contactProvider.chatContacts.isEmpty) {
        await contactProvider.refreshContacts();
      }

      _buildContactsList(contactProvider);

      // Update the last contact count after initial load
      _lastContactCount = contactProvider.chatContacts.length;

      setState(() {
        _hasLoadedContacts = true;
      });
    } finally {
      setState(() {
        _isLoadingContacts = false;
      });
    }
  }

  void _buildRecentChatsData(ChatProvider chatProvider) {
    // Store current selections to preserve them after rebuild
    final currentSelections = Set<String>.from(_selectedItems);

    List<ForwardItem> recentChats = [];
    int totalChats = chatProvider.chatListData.chats.length;
    int successfullyProcessed = 0;
    int failedToProcess = 0;
    int chatsWithoutRecords = 0;
    int chatsWithRecords = 0;

    debugPrint('🔍 Forward Chat Debug: =====================================');
    debugPrint('🔍 Forward Chat Debug: Total chats in provider: $totalChats');
    debugPrint(
      '🔍 Forward Chat Debug: Current selections: ${currentSelections.length}',
    );
    debugPrint('🔍 Forward Chat Debug: Including ALL chats (no exclusions)');

    // Clear previous user ID mappings to rebuild them
    _userIdToItemIds.clear();

    for (int i = 0; i < chatProvider.chatListData.chats.length; i++) {
      final chat = chatProvider.chatListData.chats[i];

      debugPrint('🔍 Forward Chat Debug: Processing chat ${i + 1}/$totalChats');
      debugPrint(
        '🔍 Forward Chat Debug: - peerUserData: ${chat.peerUserData?.fullName ?? chat.peerUserData?.userName ?? chat.peerUserData?.email ?? "No peer data"}',
      );
      debugPrint(
        '🔍 Forward Chat Debug: - userId: ${chat.peerUserData?.userId}',
      );
      debugPrint(
        '🔍 Forward Chat Debug: - records count: ${chat.records?.length ?? 0}',
      );

      try {
        final record =
            chat.records?.isNotEmpty == true ? chat.records!.first : null;

        // ← skip locked chats
        if (record?.participants?.first.isLocked == true) continue;
        // Always try to create ForwardItem for all chats
        final forwardItem = ForwardItem.fromChatList(chat);

        // REMOVED: Allow forwarding to current chat - user can forward messages to same chat

        recentChats.add(forwardItem);
        successfullyProcessed++;

        debugPrint(
          '🔍 Forward Chat Debug: ✅ Successfully created ForwardItem: ${forwardItem.name} (ID: ${forwardItem.id})',
        );

        // Track user ID mapping for duplicate detection
        if (forwardItem.userId != null) {
          _userIdToItemIds[forwardItem.userId!] ??= {};
          _userIdToItemIds[forwardItem.userId!]!.add(forwardItem.id);
        }

        if (chat.records?.isNotEmpty == true) {
          chatsWithRecords++;
        } else {
          chatsWithoutRecords++;
        }
      } catch (e, stackTrace) {
        failedToProcess++;
        debugPrint(
          '🔍 Forward Chat Debug: ❌ Could not create ForwardItem for chat ${i + 1}: $e',
        );
        debugPrint('🔍 Forward Chat Debug: ❌ Stack trace: $stackTrace');
        debugPrint(
          '🔍 Forward Chat Debug: ❌ Chat data: peerUserData=${chat.peerUserData}, records=${chat.records?.length}',
        );
      }
    }

    debugPrint('🔍 Forward Chat Debug: =====================================');
    debugPrint('🔍 Forward Chat Debug: FINAL RESULTS:');
    debugPrint('🔍 Forward Chat Debug: - Provider chats: $totalChats');
    debugPrint(
      '🔍 Forward Chat Debug: - Successfully processed: $successfullyProcessed',
    );
    debugPrint('🔍 Forward Chat Debug: - Failed to process: $failedToProcess');
    debugPrint(
      '🔍 Forward Chat Debug: - Forward list count: ${recentChats.length}',
    );
    debugPrint(
      '🔍 Forward Chat Debug: - Chats with records: $chatsWithRecords',
    );
    debugPrint(
      '🔍 Forward Chat Debug: - Chats without records: $chatsWithoutRecords',
    );
    debugPrint('🔍 Forward Chat Debug: - All chats included (no filtering)');
    debugPrint('🔍 Forward Chat Debug: =====================================');

    setState(() {
      _allRecentChats = recentChats;
      // Restore selections after rebuilding the list
      _selectedItems.clear();
      _selectedItems.addAll(currentSelections);
    });

    // Update filtered items after setState completes
    _filterItems();
  }

  void _buildContactsList(ContactListProvider contactProvider) {
    // Store current selections to preserve them after rebuild
    final currentSelections = Set<String>.from(_selectedItems);

    List<ForwardItem> contacts = [];

    debugPrint(
      '🔍 Forward Contact Debug: Building contacts list with ${contactProvider.chatContacts.length} contacts',
    );
    debugPrint(
      '🔍 Forward Contact Debug: Current selections: ${currentSelections.length}',
    );

    // Include all registered contacts (users who can receive messages)
    for (final contact in contactProvider.chatContacts) {
      if (contact.isChatLock == true) continue;
      if (contact.userId != null) {
        final userId = int.tryParse(contact.userId!);
        if (userId != null) {
          final forwardItem = ForwardItem.fromContact(contact, false);
          contacts.add(forwardItem);

          // Track user ID mapping for duplicate detection across tabs
          _userIdToItemIds[userId] ??= {};
          _userIdToItemIds[userId]!.add(forwardItem.id);
        }
      }
    }

    debugPrint(
      '🔍 Forward Contact Debug: Final contacts count: ${contacts.length}',
    );
    debugPrint(
      '🔍 Forward Contact Debug: All registered contacts included (no filtering)',
    );

    // REMOVED: Invite contacts are not included since they can't receive forwarded messages

    setState(() {
      _allContacts = contacts;
      // Preserve selections after rebuilding the list
      _selectedItems.clear();
      _selectedItems.addAll(currentSelections);
    });

    // Update filtered items after setState completes
    _filterItems();
  }

  void _filterItems() {
    debugPrint('🔍 Forward Filter Debug: Starting filtering...');
    debugPrint(
      '🔍 Forward Filter Debug: _allRecentChats count: ${_allRecentChats.length}',
    );
    debugPrint(
      '🔍 Forward Filter Debug: _allContacts count: ${_allContacts.length}',
    );
    debugPrint('🔍 Forward Filter Debug: Search query: "$_searchQuery"');

    // Filter recent chats
    List<ForwardItem> filteredChats = _allRecentChats;
    if (_searchQuery.isNotEmpty) {
      final beforeFilter = filteredChats.length;
      filteredChats =
          filteredChats
              .where((item) => item.name.toLowerCase().contains(_searchQuery))
              .toList();
      debugPrint(
        '🔍 Forward Filter Debug: Chats filtered from $beforeFilter to ${filteredChats.length}',
      );
    }

    // Filter contacts
    List<ForwardItem> filteredContacts = _allContacts;
    if (_searchQuery.isNotEmpty) {
      final beforeFilter = filteredContacts.length;
      filteredContacts =
          filteredContacts
              .where((item) => item.name.toLowerCase().contains(_searchQuery))
              .toList();
      debugPrint(
        '🔍 Forward Filter Debug: Contacts filtered from $beforeFilter to ${filteredContacts.length}',
      );
    }

    debugPrint(
      '🔍 Forward Filter Debug: Final filtered chats: ${filteredChats.length}',
    );
    debugPrint(
      '🔍 Forward Filter Debug: Final filtered contacts: ${filteredContacts.length}',
    );

    setState(() {
      _filteredRecentChats =
          filteredChats
              .map((item) => item.copyWith(isSelected: _isItemSelected(item)))
              .toList();

      _filteredContacts =
          filteredContacts
              .map((item) => item.copyWith(isSelected: _isItemSelected(item)))
              .toList();
    });

    debugPrint(
      '🔍 Forward Filter Debug: After setState - _filteredRecentChats: ${_filteredRecentChats.length}',
    );
    debugPrint(
      '🔍 Forward Filter Debug: After setState - _filteredContacts: ${_filteredContacts.length}',
    );
  }

  bool _isItemSelected(ForwardItem item) {
    // Check if this specific item is selected
    if (_selectedItems.contains(item.id)) {
      debugPrint(
        '🔍 Selection Check Debug: ${item.name} - SELECTED (direct match)',
      );
      return true;
    }

    // For private chats/contacts, check if any other item with the same userId is selected
    // But only for private chats, NOT for groups
    if (item.chatType?.toLowerCase() != 'group' &&
        item.userId != null &&
        _userIdToItemIds[item.userId] != null) {
      for (final itemId in _userIdToItemIds[item.userId]!) {
        if (_selectedItems.contains(itemId)) {
          // Also check that the selected item is not a group chat
          ForwardItem? selectedItem = _findItemById(itemId);
          if (selectedItem != null &&
              selectedItem.chatType?.toLowerCase() != 'group') {
            debugPrint(
              '🔍 Selection Check Debug: ${item.name} - SELECTED (duplicate user ${item.userId})',
            );
            return true;
          }
        }
      }
    }

    // Groups are only selected if specifically selected, not based on userId
    if (item.chatType?.toLowerCase() == 'group') {
      debugPrint(
        '🔍 Selection Check Debug: ${item.name} - Group not selected (groups need direct selection)',
      );
    }

    return false;
  }

  ForwardItem? _findItemById(String itemId) {
    // Find item in recent chats
    for (final chat in _allRecentChats) {
      if (chat.id == itemId) {
        return chat;
      }
    }

    // Find item in contacts
    for (final contact in _allContacts) {
      if (contact.id == itemId) {
        return contact;
      }
    }

    return null;
  }

  void _toggleSelection(ForwardItem item) {
    debugPrint(
      '🔍 Toggle Selection Debug: ${item.name} (ID: ${item.id}, UserID: ${item.userId})',
    );
    debugPrint(
      '🔍 Toggle Selection Debug: Currently selected items: ${_selectedItems.length}',
    );

    setState(() {
      if (_isItemSelected(item)) {
        debugPrint('🔍 Toggle Selection Debug: Removing selection');
        // Remove selection - remove all items with same userId
        _removeSelection(item);
      } else {
        debugPrint('🔍 Toggle Selection Debug: Adding selection');
        // Add selection - remove any existing selections with same userId, then add this one
        _addSelection(item);
      }
      _filterItems();
      _notifySelectionChanged();
    });

    debugPrint(
      '🔍 Toggle Selection Debug: After toggle, selected items: ${_selectedItems.length}',
    );
  }

  void _addSelection(ForwardItem item) {
    // Only remove duplicates for private chats, not for group chats
    // Group chats are unique by chatId and should be selectable independently
    if (item.chatType?.toLowerCase() != 'group' &&
        item.userId != null &&
        _userIdToItemIds[item.userId] != null) {
      final removedIds = <String>[];
      for (final id in _userIdToItemIds[item.userId]!) {
        if (_selectedItems.contains(id)) {
          // Only remove if the existing selected item is also NOT a group chat
          final existingItem = _findItemById(id);
          if (existingItem != null &&
              existingItem.chatType?.toLowerCase() != 'group') {
            removedIds.add(id);
            _selectedItems.remove(id);
          }
        }
      }
      if (removedIds.isNotEmpty) {
        debugPrint(
          '🔍 Duplicate Selection Debug: Removed ${removedIds.length} duplicate private chat items for userId ${item.userId}',
        );
        debugPrint('🔍 Duplicate Selection Debug: Group chats remain selected');
      }
    }

    // Add the selected item
    _selectedItems.add(item.id);
    debugPrint(
      '🔍 Selection Debug: Added ${item.name} (userId: ${item.userId}, chatType: ${item.chatType})',
    );
  }

  void _removeSelection(ForwardItem item) {
    // Remove this item
    _selectedItems.remove(item.id);

    // Only remove other items with the same userId if this is NOT a group chat
    // Group chats should be removed individually
    if (item.chatType?.toLowerCase() != 'group' &&
        item.userId != null &&
        _userIdToItemIds[item.userId] != null) {
      for (final id in _userIdToItemIds[item.userId]!) {
        // Only remove if the other item is also NOT a group chat
        final otherItem = _findItemById(id);
        if (otherItem != null && otherItem.chatType?.toLowerCase() != 'group') {
          _selectedItems.remove(id);
        }
      }
    }
  }

  void _notifySelectionChanged() {
    List<int> chatIds = [];
    List<int> userIds = [];
    Set<int> processedUserIds = {};

    for (final itemId in _selectedItems) {
      ForwardItem? item;

      // Find item in all lists
      for (final chat in _allRecentChats) {
        if (chat.id == itemId) {
          item = chat;
          break;
        }
      }

      if (item == null) {
        for (final contact in _allContacts) {
          if (contact.id == itemId) {
            item = contact;
            break;
          }
        }
      }

      if (item != null) {
        if (item.chatId != null) {
          chatIds.add(item.chatId!);
        } else if (item.userId != null &&
            !processedUserIds.contains(item.userId!)) {
          userIds.add(item.userId!);
          processedUserIds.add(item.userId!);
        }
      }
    }

    widget.onSelectionChanged(chatIds, userIds);
  }

  int _getUniqueSelectionCount() {
    Set<String> uniqueSelections = {};

    for (final itemId in _selectedItems) {
      ForwardItem? item;

      // Find item in all lists
      for (final chat in _allRecentChats) {
        if (chat.id == itemId) {
          item = chat;
          break;
        }
      }

      if (item == null) {
        for (final contact in _allContacts) {
          if (contact.id == itemId) {
            item = contact;
            break;
          }
        }
      }

      if (item != null) {
        // Use userId for users and chatId for groups to avoid duplicates
        if (item.chatType?.toLowerCase() == 'group' && item.chatId != null) {
          uniqueSelections.add('group_${item.chatId}');
        } else if (item.userId != null) {
          uniqueSelections.add('user_${item.userId}');
        } else {
          uniqueSelections.add(item.id);
        }
      }
    }

    return uniqueSelections.length;
  }

  String _getTabLabel(int tabIndex) {
    if (tabIndex == 0) {
      // Recent Chats tab
      if (_isLoadingChats && !_hasLoadedChats) {
        return '${AppString.recentChats} (...)';
      }
      return '${AppString.recentChats} (${_filteredRecentChats.length})';
    } else {
      // Contacts tab
      if (_isLoadingContacts && !_hasLoadedContacts) {
        return '${AppString.allContacts} (...)';
      }
      return '${AppString.allContacts} (${_filteredContacts.length})';
    }
  }

  // /// Build search bar widget - Same design as home screen
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 45, // Fixed compact height
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.strokBorder,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppThemeManage.appTheme.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        style: AppTypography.text12(
          context,
        ).copyWith(fontSize: SizeConfig.getFontSize(13)),
        autofocus: false,
        // focusNode: searchFocusNode,
        // onChanged: (value) {
        //   // Cancel previous timer
        //   _searchDebounceTimer?.cancel();

        //   if (value.trim().isEmpty) {
        //     // Clear search immediately if empty
        //     // Add search functionality to CallHistoryProvider
        //     return;
        //   }

        //   // Debounced search - wait 500ms after user stops typing
        //   _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        //     if (value.trim().isNotEmpty) {
        //       // Add search functionality to CallHistoryProvider
        //       // provider.searchCallHistory(value.trim());
        //     }
        //   });
        // },
        decoration: InputDecoration(
          hintText: '${AppString.searchChatsAndContacts}...',
          hintStyle: AppTypography.text12(context).copyWith(
            fontSize: SizeConfig.getFontSize(13),
            color: Colors.grey[600],
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(
              vertical: MediaQuery.of(context).size.height * 0.018,
              horizontal: MediaQuery.of(context).size.width * 0.025,
            ),
            child: SvgPicture.asset(
              AppAssets.homeIcons.search,
              height: MediaQuery.of(context).size.height * 0.03,
              colorFilter: ColorFilter.mode(
                AppColors.textColor.textDarkGray,
                BlendMode.srcIn,
              ),
            ),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 10, minHeight: 10),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: AppColors.textColor.textDarkGray,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      // Clear search in CallHistoryProvider
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: SizeConfig.getPaddingSymmetric(
            horizontal: 12,
            vertical: 8,
          ),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ChatProvider, SocketEventController, ContactListProvider>(
      builder: (
        context,
        chatProvider,
        socketEventController,
        contactProvider,
        _,
      ) {
        // Check for data changes without PostFrameCallback to prevent infinite loops
        final currentChatCount = chatProvider.chatListData.chats.length;
        final currentContactCount = contactProvider.chatContacts.length;

        // Only update if data actually changed (and we're not in the middle of loading)
        if (_currentTabIndex == 0 &&
            _hasLoadedChats &&
            !_isLoadingChats &&
            !_isLoadingMoreChats) {
          if (_lastChatCount != currentChatCount) {
            debugPrint(
              '🔍 Forward Consumer Debug: Chat count changed from $_lastChatCount to $currentChatCount',
            );
            _lastChatCount = currentChatCount;

            // Schedule the update for next frame to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _buildRecentChatsData(chatProvider);
              }
            });
          }
        }

        if (_currentTabIndex == 1 &&
            _hasLoadedContacts &&
            !_isLoadingContacts) {
          if (_lastContactCount != currentContactCount) {
            debugPrint(
              '🔍 Forward Consumer Debug: Contact count changed from $_lastContactCount to $currentContactCount',
            );
            _lastContactCount = currentContactCount;

            // Schedule the update for next frame to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _buildContactsList(contactProvider);
              }
            });
          }
        }

        return Column(
          children: [
            // Search Bar
            _buildSearchBar(),
            // Container(
            //   margin: const EdgeInsets.all(16),
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //     borderRadius: BorderRadius.circular(12),
            //     boxShadow: [
            //       BoxShadow(
            //         color: Colors.black.withValues(alpha: 0.05),
            //         blurRadius: 8,
            //         offset: const Offset(0, 2),
            //       ),
            //     ],
            //   ),
            //   child: TextField(
            //     controller: _searchController,
            //     style: AppTypography.mediumText(context),
            //     decoration: InputDecoration(
            //       hintText: 'Search chats and contacts...',
            //       hintStyle: AppTypography.mediumText(
            //         context,
            //       ).copyWith(color: AppColors.textColor.textGreyColor),
            //       prefixIcon: Icon(
            //         Icons.search_rounded,
            //         color: AppColors.appPriSecColor.primaryColor,
            //         size: 20,
            //       ),
            //       border: InputBorder.none,
            //       contentPadding: const EdgeInsets.symmetric(
            //         horizontal: 16,
            //         vertical: 12,
            //       ),
            //     ),
            //   ),
            // ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.appPriSecColor.primaryColor,
              indicatorWeight: 1,
              padding: SizeConfig.getPaddingSymmetric(horizontal: 10),
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(
                  width: 1.3,
                  color: AppColors.appPriSecColor.primaryColor,
                ),
              ),
              dividerColor: AppThemeManage.appTheme.borderColor,
              labelColor: AppThemeManage.appTheme.textColor,
              unselectedLabelColor: AppColors.textColor.textGreyColor,
              // controller: _tabController,
              // indicator: BoxDecoration(
              //   color: AppColors.appPriSecColor.primaryColor,
              //   borderRadius: BorderRadius.circular(10),
              // ),
              // indicatorSize: TabBarIndicatorSize.tab,
              // labelColor: Colors.white,
              // unselectedLabelColor: AppColors.textColor.textGreyColor,
              // labelStyle: AppTypography.mediumText(
              //   context,
              // ).copyWith(fontWeight: FontWeight.w600),
              // unselectedLabelStyle: AppTypography.mediumText(context),
              tabs: [Tab(text: _getTabLabel(0)), Tab(text: _getTabLabel(1))],
            ),

            const SizedBox(height: 16),

            // Selection Counter
            if (_getUniqueSelectionCount() > 0)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.appPriSecColor.primaryColor.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.appPriSecColor.primaryColor.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.appPriSecColor.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_getUniqueSelectionCount()} ${AppString.settingStrigs.selected}',
                      style: AppTypography.smallText(context).copyWith(
                        color: AppColors.appPriSecColor.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedItems.clear();
                          _filterItems();
                          _notifySelectionChanged();
                        });
                      },
                      child: Text(
                        AppString.clearAll,
                        style: AppTypography.smallText(context).copyWith(
                          color: AppColors.appPriSecColor.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Chat List
            Expanded(
              child:
                  _currentTabIndex == 0
                      ? _buildRecentChatsList(chatProvider)
                      : _buildContactsListView(contactProvider),
            ),

            // Forward Button
            if (widget.showForwardButton && _getUniqueSelectionCount() > 0)
              _buildForwardButton(),
          ],
        );
      },
    );
  }

  /// Build recent chats list with pagination support
  Widget _buildRecentChatsList(ChatProvider chatProvider) {
    final chats = _filteredRecentChats;
    final isPaginationLoading =
        chatProvider.isChatListPaginationLoading || _isLoadingMoreChats;

    // Handle custom loading state
    if (_isLoadingChats && !_hasLoadedChats) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            commonLoading(),
            SizedBox(height: 16),
            Text("${AppString.loadingChats}..."),
          ],
        ),
      );
    }

    // Handle provider loading state (for refresh)
    final isLoading = chatProvider.isChatListLoading;
    final error = chatProvider.error;
    if (isLoading && chats.isEmpty && _hasLoadedChats) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            commonLoading(),
            SizedBox(height: 16),
            Text("${AppString.loadingChats}..."),
          ],
        ),
      );
    }

    // Handle error state
    if (error != null && chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.smallText(
                context,
              ).copyWith(color: Colors.red),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => chatProvider.refreshChatList(),
              child: Text("Retry"),
            ),
          ],
        ),
      );
    }

    // Handle empty state - check if there are more pages
    if (chats.isEmpty) {
      // If pagination shows more records but current page is empty, show loading
      if (chatProvider.chatListTotalPages > 1 &&
          chatProvider.chatListCurrentPage == 1) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              commonLoading(),
              SizedBox(height: 16),
              Text("${AppString.loadingChats}..."),
            ],
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              AppString.noChatsAvailable,
              style: AppTypography.h4(context).copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Show chat list with pagination
    return Column(
      children: [
        // Pagination info (for debugging, similar to ChatList)
        if (chatProvider.chatListTotalPages > 1)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${chatProvider.chatListCurrentPage} of ${chatProvider.chatListTotalPages} | Provider: ${chatProvider.chatListData.chats.length}',
                  style: AppTypography.smallText(
                    context,
                  ).copyWith(color: Colors.grey),
                ),
                Text(
                  'Forward: ${chats.length} chats',
                  style: AppTypography.smallText(
                    context,
                  ).copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),

        // Chat list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await chatProvider.refreshChatList();
              _buildRecentChatsData(chatProvider);
            },
            color: AppColors.appPriSecColor.primaryColor,
            child: ListView.separated(
              controller: _chatScrollController,
              itemCount: chats.length + (isPaginationLoading ? 1 : 0),
              physics: const AlwaysScrollableScrollPhysics(),
              // Add bottom padding to ensure list is always scrollable
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).size.height *
                    0.2, // 20% of screen height
              ),
              separatorBuilder: (context, index) {
                if (index >= chats.length) return SizedBox.shrink();
                return SizedBox.shrink();
                // return Divider(color: AppColors.shadowColor.cE9E9E9);
              },
              itemBuilder: (context, index) {
                // Show loading indicator at the bottom while paginating
                if (index >= chats.length) {
                  return _buildPaginationLoader();
                }

                final item = chats[index];
                return _buildChatItem(item);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Build pagination loader widget (matches ChatList implementation)
  Widget _buildPaginationLoader() {
    return Container(
      padding: EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 20, height: 20, child: commonLoading()),
          SizedBox(width: 12),
          Text(
            "${AppString.loadingMoreChats}...",
            style: AppTypography.smallText(
              context,
            ).copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsListView(ContactListProvider contactProvider) {
    final contacts = _filteredContacts;

    // Handle custom loading state
    if (_isLoadingContacts && !_hasLoadedContacts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            commonLoading(),
            SizedBox(height: 16),
            Text("${AppString.loadingContacts}..."),
          ],
        ),
      );
    }

    // Handle provider loading state (for refresh)
    final isLoading = contactProvider.isLoading;
    final error = contactProvider.errorMessage;
    if (isLoading && contacts.isEmpty && _hasLoadedContacts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            commonLoading(),
            SizedBox(height: 16),
            Text("${AppString.loadingContacts}..."),
          ],
        ),
      );
    }

    // Handle error state
    if (error != null && contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.smallText(
                context,
              ).copyWith(color: Colors.red),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => contactProvider.refreshContacts(),
              child: Text("Retry"),
            ),
          ],
        ),
      );
    }

    // Handle empty state
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              AppString.noContactsAvailable,
              style: AppTypography.h4(context).copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _contactScrollController,
      itemCount: contacts.length,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = contacts[index];
        return _buildContactItem(item);
      },
    );
  }

  /// The line under a recent chat's name. The backend's public profile
  /// (`users/batch`) carries no phone number, so: the profile's number if
  /// there is one, else the number from the user's own contacts, else the
  /// `@username`, else nothing (no empty line).
  String _chatSubtitle(ForwardItem item) {
    if (item.phoneNumber.trim().isNotEmpty) return item.phoneNumber;

    final userId = item.userId;
    if (userId != null) {
      final contacts =
          Provider.of<ContactListProvider>(context, listen: false).chatContacts;
      for (final contact in contacts) {
        if (contact.userId == userId.toString() &&
            contact.phoneNumber.trim().isNotEmpty) {
          return contact.phoneNumber;
        }
      }
    }

    final handle = (item.userName ?? '').trim();
    return handle.isEmpty ? '' : '@$handle';
  }

  Widget _buildChatItem(ForwardItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(12),
        border:
            item.isSelected
                ? Border.all(
                  color: AppColors.appPriSecColor.primaryColor.withValues(
                    alpha: 0.5,
                  ),
                  width: 1.3,
                )
                : Border.all(color: Colors.transparent, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Stack(
          children: [
            // Same avatar (with name initials fallback) as the chat list /
            // contact list, driven by the resolved saved-contact name.
            CommonProfileAvatar(
              imageUrl: item.profilePic,
              name: item.name,
              radius: 24,
              isGroup: item.chatType?.toLowerCase() == 'group',
            ),
            if (item.chatType?.toLowerCase() == 'group')
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.appPriSecColor.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Icon(Icons.group, color: Colors.white, size: 10),
                ),
              ),
            // if (item.isSelected)
            //   Positioned(
            //     top: 0,
            //     right: 0,
            //     child: Container(
            //       padding: const EdgeInsets.all(2),
            //       decoration: BoxDecoration(
            //         color: AppColors.appPriSecColor.primaryColor,
            //         shape: BoxShape.circle,
            //         border: Border.all(color: Colors.white, width: 2),
            //       ),
            //       child: const Icon(Icons.check, color: Colors.white, size: 12),
            //     ),
            //   ),
          ],
        ),
        title: UserNameWithBadge(
          // Groups are not a user: no blue tick.
          userId: item.chatType?.toLowerCase() == 'group' ? null : item.userId,
          name: item.name,
          style: AppTypography.h5(context).copyWith(
            fontWeight: item.isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Consumer<ChatProvider>(
          builder: (context, chatProvider, _) {
            if (item.chatType?.toLowerCase() == 'group') {
              return SizedBox.shrink();
            }
            final subtitle = _chatSubtitle(item);
            if (subtitle.isEmpty) return SizedBox.shrink();
            return Text(
              subtitle,
              style: AppTypography.smallText(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        trailing: CustomCheckCircle(isSelected: item.isSelected),
        // item.unseenCount > 0
        //     ? Container(
        //       padding: const EdgeInsets.all(6),
        //       decoration: BoxDecoration(
        //         color: AppColors.appPriSecColor.primaryColor,
        //         shape: BoxShape.circle,
        //       ),
        //       child: Text(
        //         item.unseenCount > 99 ? '99+' : item.unseenCount.toString(),
        //         style: AppTypography.smallText(context).copyWith(
        //           color: Colors.white,
        //           fontWeight: FontWeight.w600,
        //           fontSize: 10,
        //         ),
        //       ),
        //     )
        //     : null,
        onTap: () {
          _toggleSelection(item);
          widget.onItemTap(item);
        },
      ),
    );
  }

  Widget _buildContactItem(ForwardItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(12),
        border:
            item.isSelected
                ? Border.all(
                  color: AppColors.appPriSecColor.primaryColor,
                  width: 2,
                )
                : Border.all(color: Colors.transparent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Stack(
          children: [
            CommonProfileAvatar(
              imageUrl: item.profilePic,
              name: item.name,
              radius: 24,
            ),
            // if (item.isSelected)
            //   Positioned(
            //     top: 0,
            //     right: 0,
            //     child: Container(
            //       padding: const EdgeInsets.all(2),
            //       decoration: BoxDecoration(
            //         color: AppColors.appPriSecColor.primaryColor,
            //         shape: BoxShape.circle,
            //         border: Border.all(color: Colors.white, width: 2),
            //       ),
            //       child: const Icon(Icons.check, color: Colors.white, size: 12),
            //     ),
            //   ),
          ],
        ),
        title: UserNameWithBadge(
          userId: item.userId,
          name: item.name,
          style: AppTypography.h5(context).copyWith(
            fontWeight: item.isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Text(
          item.phoneNumber,
          // item.userId != null ? 'Registered user' : 'Invite to chat',
          style: AppTypography.smallText(
            context,
          ).copyWith(color: AppColors.textColor.textGreyColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // style: AppTypography.smallText(
          //   context,
          // ).copyWith(color: item.userId != null ? Colors.green : Colors.orange),
        ),
        trailing: CustomCheckCircle(isSelected: item.isSelected),
        onTap: () {
          _toggleSelection(item);
          widget.onItemTap(item);
        },
      ),
    );
  }

  Widget _buildForwardButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.borderColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selection summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.appPriSecColor.primaryColor.withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.appPriSecColor.primaryColor.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.appPriSecColor.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ready to forward ${widget.selectedMessageIds?.length ?? 0} message${(widget.selectedMessageIds?.length ?? 0) != 1 ? 's' : ''} to ${_selectedItems.length} recipient${_selectedItems.length != 1 ? 's' : ''}',
                      style: AppTypography.smallText(context).copyWith(
                        color: AppColors.appPriSecColor.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Forward Button
            ElevatedButton(
              onPressed: () {
                if (widget.onForwardPressed != null) {
                  List<int> chatIds = [];
                  List<int> userIds = [];

                  for (final itemId in _selectedItems) {
                    ForwardItem? item;

                    // Find the item
                    for (final chat in _filteredRecentChats) {
                      if (chat.id == itemId) {
                        item = chat;
                        break;
                      }
                    }

                    if (item == null) {
                      for (final contact in _filteredContacts) {
                        if (contact.id == itemId) {
                          item = contact;
                          break;
                        }
                      }
                    }

                    if (item != null) {
                      if (item.type == ForwardItemType.recentChat &&
                          item.chatId != null) {
                        chatIds.add(item.chatId!);
                      } else if (item.type == ForwardItemType.contact &&
                          item.userId != null) {
                        userIds.add(item.userId!);
                      }
                    }
                  }

                  widget.onForwardPressed!(chatIds, userIds);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appPriSecColor.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // const Icon(Icons.send, size: 20),
                  // const SizedBox(width: 8),
                  Text(
                    '${AppString.forwardTo} ${_selectedItems.length} ${AppString.recipient}',
                    style: AppTypography.buttonText(context).copyWith(
                      color: AppThemeManage.appTheme.scaffoldBackColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
