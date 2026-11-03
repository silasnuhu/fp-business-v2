import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';

// Enhanced Forward item model to unify different data types
class ForwardItem {
  final String id;
  final String name;
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

  ForwardItem({
    required this.id,
    required this.name,
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
  });

  // Create from chat list item (existing chats)
  factory ForwardItem.fromChatList(Chats chat) {
    final record =
        chat.records?.isNotEmpty == true ? chat.records!.first : null;
    final peerUserData = chat.peerUserData;

    String displayName = '';
    String? profilePic;

    if (record?.chatType?.toLowerCase() == 'group') {
      displayName = record?.groupName ?? 'Group Chat';
      profilePic = record?.groupIcon;
    } else {
      // Show fullName if available, otherwise userName, otherwise 'Unknown'
      displayName =
          peerUserData?.fullName?.isNotEmpty == true
              ? peerUserData!.fullName!
              : peerUserData?.userName?.isNotEmpty == true
              ? peerUserData!.userName!
              : 'Unknown User';
      profilePic = peerUserData?.profilePic;
    }

    return ForwardItem(
      id: 'chat_${record?.chatId ?? 0}',
      name: displayName,
      profilePic: profilePic,
      type: ForwardItemType.recentChat,
      chatId: record?.chatId,
      userId: peerUserData?.userId,
      lastMessage:
          record?.messages?.isNotEmpty == true
              ? record!.messages!.first.messageContent
              : null,
      lastMessageTime:
          record?.messages?.isNotEmpty == true
              ? record!.messages!.first.createdAt
              : null,
      unseenCount: record?.unseenCount ?? 0,
      chatType: record?.chatType,
    );
  }

  // Create from contact item (contacts without existing chats)
  factory ForwardItem.fromContact(ContactModel contact, bool isOnline) {
    return ForwardItem(
      id: 'contact_${contact.userId ?? 0}',
      name: contact.name,
      profilePic: null,
      type: ForwardItemType.contact,
      chatId: null,
      userId: contact.userId != null ? int.tryParse(contact.userId!) : null,
      lastMessage: null,
      lastMessageTime: null,
      isOnline: isOnline,
      unseenCount: 0,
    );
  }

  // Copy with method to update selection state
  ForwardItem copyWith({bool? isSelected}) {
    return ForwardItem(
      id: id,
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
    );
  }
}

enum ForwardItemType { recentChat, contact }

class ImprovedForwardManager extends StatefulWidget {
  final Function(List<int> chatIds, List<int> userIds) onSelectionChanged;
  final Function(ForwardItem item) onItemTap;
  final Function(List<int> chatIds, List<int> userIds)? onForwardPressed;
  final bool showForwardButton;
  final List<int>? selectedMessageIds;
  final int? fromChatId;

  const ImprovedForwardManager({
    super.key,
    required this.onSelectionChanged,
    required this.onItemTap,
    this.onForwardPressed,
    this.showForwardButton = true,
    this.selectedMessageIds,
    this.fromChatId,
  });

  @override
  State<ImprovedForwardManager> createState() => _ImprovedForwardManagerState();
}

class _ImprovedForwardManagerState extends State<ImprovedForwardManager>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ForwardItem> _allRecentChats = [];
  List<ForwardItem> _allContacts = [];
  List<ForwardItem> _filteredItems = [];
  final Set<String> _selectedItems = {};
  String _searchQuery = '';
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
          _filterItems();
        });
      }
    });

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterItems();
    });
  }

  void _onScroll() {
    // Handle pagination for chat list when scrolling near the bottom
    if (_currentTabIndex == 0 &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _loadMoreChats();
    }
  }

  Future<void> _loadData() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final contactProvider = Provider.of<ContactListProvider>(
      context,
      listen: false,
    );

    // Load chat list if not already loaded
    if (chatProvider.chatListData.chats.isEmpty) {
      await chatProvider.refreshChatList();
    }

    // 🔍 DEBUG: Check pagination status
    debugPrint('🔍 DEBUG - Chat pagination status:');
    debugPrint('   - Current page: ${chatProvider.chatListCurrentPage}');
    debugPrint('   - Total pages: ${chatProvider.chatListTotalPages}');
    debugPrint('   - Has more data: ${chatProvider.hasChatListMoreData}');
    debugPrint('   - Is loading: ${chatProvider.isChatListPaginationLoading}');

    // Load all pages if there are more chats
    while (chatProvider.hasChatListMoreData &&
        !chatProvider.isChatListPaginationLoading) {
      debugPrint(
        '🔍 DEBUG - Loading more chats... Current count: ${chatProvider.chatListData.chats.length}',
      );
      await chatProvider.loadMoreChatList();
      await Future.delayed(
        Duration(milliseconds: 100),
      ); // Small delay to prevent rapid calls
    }

    debugPrint(
      '🔍 DEBUG - Final chat count after loading all pages: ${chatProvider.chatListData.chats.length}',
    );

    // Load contacts if not already loaded
    if (contactProvider.chatContacts.isEmpty) {
      await contactProvider.refreshContacts();
    }

    _buildSeparatedLists();
  }

  Future<void> _loadMoreChats() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (chatProvider.hasChatListMoreData &&
        !chatProvider.isChatListPaginationLoading) {
      await chatProvider.loadMoreChatList();
      _buildSeparatedLists();
    }
  }

  void _buildSeparatedLists() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final contactProvider = Provider.of<ContactListProvider>(
      context,
      listen: false,
    );

    List<ForwardItem> recentChats = [];
    List<ForwardItem> contacts = [];
    Set<int> existingChatUserIds = {};

    // 🔍 DEBUG: Print total chats available
    debugPrint(
      '🔍 DEBUG - Total chats in chatProvider: ${chatProvider.chatListData.chats.length}',
    );
    debugPrint('🔍 DEBUG - Current fromChatId: ${widget.fromChatId}');

    int emptyRecordsCount = 0;
    int currentChatSkipped = 0;

    // 1. Build recent chats list - ALL CHATS INCLUDING EMPTY RECORDS
    for (int i = 0; i < chatProvider.chatListData.chats.length; i++) {
      final chat = chatProvider.chatListData.chats[i];

      // Get record (even if empty)
      final record =
          chat.records?.isNotEmpty == true ? chat.records!.first : null;

      // 🔍 DEBUG: Print each chat info
      debugPrint(
        '🔍 DEBUG - Chat $i: chatId=${record?.chatId}, hasRecords=${chat.records?.isNotEmpty}, recordsCount=${chat.records?.length}',
      );

      // Create a dummy record for chats with no records but valid peerUserData
      final effectiveRecord = record ?? _createDummyRecord(chat);

      if (effectiveRecord != null) {
        // Skip the current chat (can't forward to yourself)
        if (widget.fromChatId != null &&
            effectiveRecord.chatId == widget.fromChatId) {
          currentChatSkipped++;
          debugPrint('🔍 DEBUG - Skipping current chat: ${effectiveRecord.chatId}');
          continue;
        }

        // Track existing chat user IDs for private chats only
        if ((effectiveRecord.chatType?.toLowerCase() == 'private') &&
            chat.peerUserData?.userId != null) {
          existingChatUserIds.add(chat.peerUserData!.userId!);
        }

        // Create ForwardItem with effective record
        recentChats.add(_createForwardItemFromChat(chat, effectiveRecord));
      } else {
        emptyRecordsCount++;
        debugPrint('🔍 DEBUG - Skipping chat with no valid data: Chat index $i');
      }
    }

    debugPrint('🔍 DEBUG - Final counts:');
    debugPrint('   - Total chats: ${chatProvider.chatListData.chats.length}');
    debugPrint('   - Recent chats shown: ${recentChats.length}');
    debugPrint('   - Current chat skipped: $currentChatSkipped');
    debugPrint('   - Empty records skipped: $emptyRecordsCount');
    debugPrint(
      '   - Missing: ${chatProvider.chatListData.chats.length - recentChats.length - currentChatSkipped - emptyRecordsCount}',
    );

    // 2. Build contacts list - only contacts that don't have existing chats
    for (final contact in contactProvider.chatContacts) {
      if (contact.userId != null) {
        final userId = int.tryParse(contact.userId!);
        if (userId != null && !existingChatUserIds.contains(userId)) {
          contacts.add(ForwardItem.fromContact(contact, false));
        }
      }
    }

    // 3. Add invite contacts (unregistered contacts)
    for (final contact in contactProvider.inviteContacts) {
      contacts.add(ForwardItem.fromContact(contact, false));
    }

    // Update state
    setState(() {
      _allRecentChats = recentChats;
      _allContacts = contacts;
      _filterItems();
    });
  }

  void _filterItems() {
    List<ForwardItem> sourceList =
        _currentTabIndex == 0 ? _allRecentChats : _allContacts;

    if (_searchQuery.isEmpty) {
      _filteredItems =
          sourceList
              .map(
                (item) =>
                    item.copyWith(isSelected: _selectedItems.contains(item.id)),
              )
              .toList();
    } else {
      _filteredItems =
          sourceList
              .where((item) => item.name.toLowerCase().contains(_searchQuery))
              .map(
                (item) =>
                    item.copyWith(isSelected: _selectedItems.contains(item.id)),
              )
              .toList();
    }
  }

  void _toggleSelection(ForwardItem item) {
    setState(() {
      if (_selectedItems.contains(item.id)) {
        _selectedItems.remove(item.id);
      } else {
        _selectedItems.add(item.id);
      }
      _filterItems();
      _notifySelectionChanged();
    });
  }

  void _notifySelectionChanged() {
    List<int> chatIds = [];
    List<int> userIds = [];

    for (final itemId in _selectedItems) {
      // Find the item in both lists
      ForwardItem? item;

      // Check recent chats first
      for (final chat in _allRecentChats) {
        if (chat.id == itemId) {
          item = chat;
          break;
        }
      }

      // If not found in recent chats, check contacts
      if (item == null) {
        for (final contact in _allContacts) {
          if (contact.id == itemId) {
            item = contact;
            break;
          }
        }
      }

      if (item != null) {
        if (item.type == ForwardItemType.recentChat && item.chatId != null) {
          chatIds.add(item.chatId!);
        } else if (item.type == ForwardItemType.contact &&
            item.userId != null) {
          userIds.add(item.userId!);
        }
      }
    }

    widget.onSelectionChanged(chatIds, userIds);
  }

  // Helper method to create dummy record for chats with no records
  dynamic _createDummyRecord(dynamic chat) {
    if (chat.peerUserData?.userId != null) {
      // Create a basic record structure for chats with no messages
      return DummyRecord(
        chatId:
            chat.peerUserData!.userId!, // Use userId as chatId for new chats
        chatType: 'private',
        messages: [],
        unseenCount: 0,
        groupName: null,
        groupIcon: null,
      );
    }
    return null;
  }

  // Helper method to create ForwardItem from chat with effective record
  ForwardItem _createForwardItemFromChat(dynamic chat, dynamic record) {
    final peerUserData = chat.peerUserData;

    String displayName = '';
    String? profilePic;

    if (record.chatType?.toLowerCase() == 'group') {
      displayName = record.groupName ?? 'Group Chat';
      profilePic = record.groupIcon;
    } else {
      displayName =
          peerUserData?.fullName?.isNotEmpty == true
              ? peerUserData!.fullName!
              : peerUserData?.userName?.isNotEmpty == true
              ? peerUserData!.userName!
              : 'Unknown User';
      profilePic = peerUserData?.profilePic;
    }

    return ForwardItem(
      id: 'chat_${record.chatId ?? 0}',
      name: displayName,
      profilePic: profilePic,
      type: ForwardItemType.recentChat,
      chatId: record.chatId,
      userId: peerUserData?.userId,
      lastMessage:
          record.messages?.isNotEmpty == true
              ? record.messages!.first.messageContent
              : 'No messages yet',
      lastMessageTime:
          record.messages?.isNotEmpty == true
              ? record.messages!.first.createdAt
              : null,
      unseenCount: record.unseenCount ?? 0,
      chatType: record.chatType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, ContactListProvider>(
      builder: (context, chatProvider, contactProvider, child) {
        return Column(
          children: [
            // Search Bar
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: AppTypography.mediumText(context),
                decoration: InputDecoration(
                  hintText: 'Search chats and contacts...',
                  hintStyle: AppTypography.mediumText(
                    context,
                  ).copyWith(color: AppColors.textColor.textGreyColor),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.appPriSecColor.primaryColor,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.bgColor.bg1Color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.appPriSecColor.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textColor.textGreyColor,
                labelStyle: AppTypography.mediumText(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
                unselectedLabelStyle: AppTypography.mediumText(context),
                tabs: [
                  Tab(text: 'Recent Chats (${_allRecentChats.length})'),
                  Tab(text: 'All Contacts (${_allContacts.length})'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Selection Counter
            if (_selectedItems.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 
                      0.3,
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
                      '${_selectedItems.length} selected',
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
                        'Clear All',
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

            // List
            Expanded(child: _buildList()),

            // Forward Button
            if (widget.showForwardButton && _selectedItems.isNotEmpty)
              _buildForwardButton(),
          ],
        );
      },
    );
  }

  Widget _buildList() {
    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _currentTabIndex == 0
                  ? Icons.chat_bubble_outline
                  : Icons.contacts,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _currentTabIndex == 0
                  ? 'No recent chats'
                  : 'No contacts available',
              style: AppTypography.h4(context).copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        return _buildListItem(item);
      },
    );
  }

  Widget _buildListItem(ForwardItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            item.isSelected
                ? Border.all(
                  color: AppColors.appPriSecColor.primaryColor,
                  width: 2,
                )
                : null,
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
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.strokeColor.greyColor,
              backgroundImage:
                  item.profilePic?.isNotEmpty == true
                      ? NetworkImage(item.profilePic!)
                      : null,
              child:
                  item.profilePic?.isEmpty ?? true
                      ? Icon(
                        item.type == ForwardItemType.recentChat
                            ? (item.chatType?.toLowerCase() == 'group'
                                ? Icons.group
                                : Icons.person)
                            : Icons.person,
                        color: Colors.grey[600],
                      )
                      : null,
            ),
            if (item.type == ForwardItemType.recentChat &&
                item.chatType?.toLowerCase() == 'group')
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
            if (item.isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.appPriSecColor.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
              ),
          ],
        ),
        title: Text(
          item.name,
          style: AppTypography.h5(context).copyWith(
            fontWeight: item.isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle:
            item.type == ForwardItemType.recentChat
                ? Text(
                  item.lastMessage ?? 'No recent messages',
                  style: AppTypography.smallText(
                    context,
                  ).copyWith(color: AppColors.textColor.textGreyColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
                : Text(
                  item.userId != null ? 'Registered user' : 'Invite to chat',
                  style: AppTypography.smallText(context).copyWith(
                    color: item.userId != null ? Colors.green : Colors.orange,
                  ),
                ),
        trailing:
            item.type == ForwardItemType.recentChat && item.unseenCount > 0
                ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.appPriSecColor.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    item.unseenCount > 99 ? '99+' : item.unseenCount.toString(),
                    style: AppTypography.smallText(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                )
                : null,
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
        color: Colors.white,
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
                color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.3),
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
                  const Icon(Icons.send, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Forward to ${_selectedItems.length} recipient${_selectedItems.length != 1 ? 's' : ''}',
                    style: AppTypography.buttonText(context).copyWith(
                      color: Colors.white,
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

// Helper class for dummy record
class DummyRecord {
  final int chatId;
  final String chatType;
  final List<dynamic> messages;
  final int unseenCount;
  final String? groupName;
  final String? groupIcon;

  DummyRecord({
    required this.chatId,
    required this.chatType,
    required this.messages,
    required this.unseenCount,
    this.groupName,
    this.groupIcon,
  });
}
