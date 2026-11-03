// // forward_list_manager.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
// import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
// import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
// import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
// import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
// import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
// import 'package:whoxa/utils/app_size_config.dart';

// // Forward item model to unify different data types
// class ForwardItem {
//   final String id;
//   final String name;
//   final String? profilePic;
//   final ForwardItemType type;
//   final int? chatId;
//   final int? userId;
//   final String? lastMessage;
//   final String? lastMessageTime;
//   final bool isOnline;
//   final int unseenCount;
//   final String? chatType;

//   ForwardItem({
//     required this.id,
//     required this.name,
//     this.profilePic,
//     required this.type,
//     this.chatId,
//     this.userId,
//     this.lastMessage,
//     this.lastMessageTime,
//     this.isOnline = false,
//     this.unseenCount = 0,
//     this.chatType,
//   });

//   // Create from chat list item (existing chats)
//   factory ForwardItem.fromChatList(Chats chat) {
//     final record =
//         chat.records?.isNotEmpty == true ? chat.records!.first : null;
//     final peerUserData = chat.peerUserData;

//     String displayName = '';
//     String? profilePic;

//     if (record?.chatType == 'Group') {
//       displayName = record?.groupName ?? 'Group Chat';
//       profilePic = record?.groupIcon;
//     } else {
//       displayName =
//           peerUserData?.fullName ?? peerUserData?.userName ?? 'Unknown';
//       profilePic = peerUserData?.profilePic;
//     }

//     return ForwardItem(
//       id: 'chat_${record?.chatId ?? 0}',
//       name: displayName,
//       profilePic: profilePic,
//       type:
//           record?.chatType == 'Group'
//               ? ForwardItemType.group
//               : ForwardItemType.recentChat,
//       chatId: record?.chatId,
//       userId: peerUserData?.userId,
//       lastMessage:
//           chat.records?.isNotEmpty == true
//               ? chat.records!.first.messages?.isNotEmpty == true
//                   ? chat.records!.first.messages!.first.messageContent
//                   : null
//               : null,
//       lastMessageTime:
//           chat.records?.isNotEmpty == true
//               ? chat.records!.first.messages?.isNotEmpty == true
//                   ? chat.records!.first.messages!.first.createdAt
//                   : null
//               : null,
//       unseenCount: record?.unseenCount ?? 0,
//       chatType: record?.chatType,
//     );
//   }

//   // Create from contact item (contacts without existing chats)
//   factory ForwardItem.fromContact(ContactDetail contact, bool isOnline) {
//     return ForwardItem(
//       id: 'contact_${contact.userId ?? 0}',
//       name: contact.name ?? 'Unknown Contact',
//       profilePic: null, // Contact list doesn't have profile pics
//       type: ForwardItemType.contact,
//       chatId: null,
//       userId: contact.userId,
//       lastMessage: null,
//       lastMessageTime: null,
//       isOnline: isOnline,
//       unseenCount: 0,
//     );
//   }
// }

// enum ForwardItemType { recentChat, group, contact }

// class ForwardListManager extends StatefulWidget {
//   final Function(List<int> chatIds, List<int> userIds) onSelectionChanged;
//   final Function(ForwardItem item) onItemTap;
//   final Function(List<int> chatIds, List<int> userIds)? onForwardPressed;
//   final bool showForwardButton;
//   final List<int>? selectedMessageIds; // NEW: Add this parameter
//   final int? fromChatId; // NEW: Add this parameter

//   const ForwardListManager({
//     Key? key,
//     required this.onSelectionChanged,
//     required this.onItemTap,
//     this.onForwardPressed,
//     this.showForwardButton = true,
//     this.selectedMessageIds, // NEW
//     this.fromChatId, // NEW
//   }) : super(key: key);

//   @override
//   State<ForwardListManager> createState() => _ForwardListManagerState();
// }

// class _ForwardListManagerState extends State<ForwardListManager>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   final TextEditingController _searchController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();

//   List<ForwardItem> _allItems = [];
//   List<ForwardItem> _filteredItems = [];
//   Set<String> _selectedItems = {};
//   String _searchQuery = '';

//   // Track current tab
//   int _currentTabIndex = 0;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//     _searchController.addListener(_onSearchChanged);
//     _scrollController.addListener(_onScroll);

//     _tabController.addListener(() {
//       if (_tabController.indexIsChanging) {
//         setState(() {
//           _currentTabIndex = _tabController.index;
//           _filterItems();
//         });
//       }
//     });

//     // Load initial data
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _loadData();
//     });
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     _searchController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   void _onSearchChanged() {
//     setState(() {
//       _searchQuery = _searchController.text.toLowerCase();
//       _filterItems();
//     });
//   }

//   void _onScroll() {
//     // Handle pagination for chat list when scrolling near the bottom
//     if (_scrollController.position.pixels >=
//         _scrollController.position.maxScrollExtent - 200) {
//       _loadMoreChats();
//     }
//   }

//   Future<void> _loadData() async {
//     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
//     final contactProvider = Provider.of<ContactListProvider>(
//       context,
//       listen: false,
//     );

//     // Load chat list if not already loaded
//     if (chatProvider.chatListData.chats.isEmpty) {
//       await chatProvider.emitChatList();
//     }

//     // Load contacts if not already loaded
//     if (contactProvider.chatContacts.isEmpty) {
//       await contactProvider.refreshContacts();
//     }

//     _buildCombinedList();
//   }

//   Future<void> _loadMoreChats() async {
//     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
//     if (chatProvider.hasChatListMoreData &&
//         !chatProvider.isChatListPaginationLoading) {
//       await chatProvider.loadMoreChatList();
//       _buildCombinedList();
//     }
//   }

//   void _buildCombinedList() {
//     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
//     final contactProvider = Provider.of<ContactListProvider>(
//       context,
//       listen: false,
//     );

//     List<ForwardItem> items = [];
//     Set<int> existingChatUserIds = {};
//     Set<String> processedNumbers = {}; // Track processed phone numbers

//     // 1. Add existing chats (both groups and private chats)
//     for (final chat in chatProvider.chatListData.chats) {
//       if (chat.records?.isNotEmpty == true) {
//         final record = chat.records!.first;

//         // Add to existing user IDs if it's a private chat
//         if (record.chatType == 'Private' && chat.peerUserData?.userId != null) {
//           existingChatUserIds.add(chat.peerUserData!.userId!);
//         }

//         items.add(ForwardItem.fromChatList(chat));
//       }
//     }

//     // 2. Add contacts - removing duplicates by phone number and existing chats
//     for (final contact in contactProvider.chatContacts) {
//       final userId = int.tryParse(contact.userId ?? '');

//       // Skip if user already has a chat
//       if (userId != null && existingChatUserIds.contains(userId)) {
//         continue;
//       }

//       // Get phone number for deduplication
//       String? phoneNumber;
//       if (contact.phoneNumber.isNotEmpty == true) {
//         phoneNumber = contact.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
//       }

//       // Skip if we've already processed this phone number
//       if (phoneNumber != null && processedNumbers.contains(phoneNumber)) {
//         continue;
//       }

//       // Add contact if it has a valid userId and unique phone number
//       if (userId != null && phoneNumber != null) {
//         processedNumbers.add(phoneNumber);
//         final isOnline = chatProvider.isUserOnline(userId);
//         items.add(
//           ForwardItem.fromContact(
//             ContactDetail(
//               name: contact.name,
//               number: phoneNumber,
//               userId: userId,
//             ),
//             isOnline,
//           ),
//         );
//       }
//     }

//     setState(() {
//       _allItems = items;
//       _filterItems();
//     });
//   }

//   void _filterItems() {
//     List<ForwardItem> filtered = [];

//     // Filter by tab
//     switch (_currentTabIndex) {
//       case 0: // All
//         filtered = _allItems;
//         break;
//       case 1: // Recent Chats (Groups + Private chats)
//         filtered =
//             _allItems
//                 .where(
//                   (item) =>
//                       item.type == ForwardItemType.recentChat ||
//                       item.type == ForwardItemType.group,
//                 )
//                 .toList();
//         break;
//       case 2: // Contacts (only contacts without existing chats)
//         filtered =
//             _allItems
//                 .where((item) => item.type == ForwardItemType.contact)
//                 .toList();
//         break;
//     }

//     // Filter by search query
//     if (_searchQuery.isNotEmpty) {
//       filtered =
//           filtered
//               .where((item) => item.name.toLowerCase().contains(_searchQuery))
//               .toList();
//     }

//     setState(() {
//       _filteredItems = filtered;
//     });
//   }

//   void _toggleSelection(ForwardItem item) {
//     setState(() {
//       if (_selectedItems.contains(item.id)) {
//         _selectedItems.remove(item.id);
//       } else {
//         _selectedItems.add(item.id);
//       }
//       _notifySelectionChanged();
//     });
//   }

//   void _notifySelectionChanged() {
//     List<int> chatIds = [];
//     List<int> userIds = [];

//     for (final itemId in _selectedItems) {
//       final item = _allItems.firstWhere((item) => item.id == itemId);

//       if (item.chatId != null) {
//         // Existing chat
//         chatIds.add(item.chatId!);
//       } else if (item.userId != null) {
//         // Contact without existing chat
//         userIds.add(item.userId!);
//       }
//     }

//     widget.onSelectionChanged(chatIds, userIds);
//   }

//   void _handleForwardPressed() {
//     // Validate that we have messages to forward
//     if (widget.selectedMessageIds == null ||
//         widget.selectedMessageIds!.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('No messages selected for forwarding'),
//           backgroundColor: Colors.red,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }

//     // Validate that we have recipients selected
//     if (_selectedItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Please select at least one chat or contact'),
//           backgroundColor: Colors.orange,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }

//     List<int> chatIds = [];
//     List<int> userIds = [];

//     for (final itemId in _selectedItems) {
//       final item = _allItems.firstWhere((item) => item.id == itemId);

//       if (item.chatId != null) {
//         // Existing chat
//         chatIds.add(item.chatId!);
//       } else if (item.userId != null) {
//         // Contact without existing chat
//         userIds.add(item.userId!);
//       }
//     }

//     // Call the provided forward callback
//     if (widget.onForwardPressed != null) {
//       widget.onForwardPressed!(chatIds, userIds);
//     } else {
//       // Fallback to selection changed callback
//       widget.onSelectionChanged(chatIds, userIds);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Consumer2<ChatProvider, ContactListProvider>(
//       builder: (context, chatProvider, contactProvider, child) {
//         // Rebuild list when data changes
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           _buildCombinedList();
//         });

//         return Column(
//           children: [
//             // Search Bar
//             Container(
//               margin: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withValues(alpha: 0.05),
//                     blurRadius: 8,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: TextField(
//                 controller: _searchController,
//                 style: AppTypography.mediumText(context),
//                 decoration: InputDecoration(
//                   hintText: 'Search chats and contacts...',
//                   hintStyle: AppTypography.mediumText(
//                     context,
//                   ).copyWith(color: AppColors.textColor.textGreyColor),
//                   prefixIcon: Icon(
//                     Icons.search_rounded,
//                     color: AppColors.appPriSecColor.primaryColor,
//                     size: 20,
//                   ),
//                   border: InputBorder.none,
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 12,
//                   ),
//                 ),
//               ),
//             ),

//             // Tab Bar
//             Container(
//               margin: const EdgeInsets.symmetric(horizontal: 16),
//               decoration: BoxDecoration(
//                 color: AppColors.bgColor.bg1Color,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: TabBar(
//                 controller: _tabController,
//                 indicator: BoxDecoration(
//                   color: AppColors.appPriSecColor.primaryColor,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 indicatorSize: TabBarIndicatorSize.tab,
//                 labelColor: Colors.white,
//                 unselectedLabelColor: AppColors.textColor.textGreyColor,
//                 labelStyle: AppTypography.mediumText(
//                   context,
//                 ).copyWith(fontWeight: FontWeight.w600),
//                 unselectedLabelStyle: AppTypography.mediumText(context),
//                 tabs: const [
//                   Tab(text: 'All'),
//                   Tab(text: 'Recent'),
//                   Tab(text: 'Contacts'),
//                 ],
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Selection Counter
//             if (_selectedItems.isNotEmpty)
//               Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 16),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 8,
//                 ),
//                 decoration: BoxDecoration(
//                   color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 
//                       0.3,
//                     ),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(
//                       Icons.check_circle,
//                       color: AppColors.appPriSecColor.primaryColor,
//                       size: 16,
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       '${_selectedItems.length} selected',
//                       style: AppTypography.smallText(context).copyWith(
//                         color: AppColors.appPriSecColor.primaryColor,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     const Spacer(),
//                     GestureDetector(
//                       onTap: () {
//                         setState(() {
//                           _selectedItems.clear();
//                           _notifySelectionChanged();
//                         });
//                       },
//                       child: Text(
//                         'Clear All',
//                         style: AppTypography.smallText(context).copyWith(
//                           color: AppColors.appPriSecColor.primaryColor,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//             const SizedBox(height: 8),

//             // List
//             Expanded(child: _buildList(chatProvider, contactProvider)),

//             // Forward Button (show at bottom when items are selected)
//             if (widget.showForwardButton && _selectedItems.isNotEmpty)
//               _buildForwardButton(),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildForwardButton() {
//     final hasSelection = _selectedItems.isNotEmpty;
//     final totalSelected = _selectedItems.length;

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(24),
//           topRight: Radius.circular(24),
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.1),
//             blurRadius: 20,
//             offset: const Offset(0, -4),
//           ),
//         ],
//       ),
//       child: SafeArea(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Selection summary
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(12),
//               margin: const EdgeInsets.only(bottom: 12),
//               decoration: BoxDecoration(
//                 color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(
//                   color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.3),
//                 ),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Icon(
//                         Icons.info_outline,
//                         color: AppColors.appPriSecColor.primaryColor,
//                         size: 18,
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           'Ready to forward to $totalSelected chat${totalSelected != 1 ? 's' : ''}',
//                           style: AppTypography.smallText(context).copyWith(
//                             color: AppColors.appPriSecColor.primaryColor,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   if (widget.selectedMessageIds != null &&
//                       widget.selectedMessageIds!.isNotEmpty) ...[
//                     const SizedBox(height: 4),
//                     Text(
//                       'Forwarding ${widget.selectedMessageIds!.length} message${widget.selectedMessageIds!.length != 1 ? 's' : ''}',
//                       style: AppTypography.smallText(context).copyWith(
//                         color: AppColors.appPriSecColor.primaryColor
//                             .withValues(alpha: 0.8),
//                         fontSize: 11,
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),

//             // Forward Button
//             AnimatedContainer(
//               duration: const Duration(milliseconds: 200),
//               width: double.infinity,
//               height: 52,
//               child: ElevatedButton(
//                 onPressed: hasSelection ? _handleForwardPressed : null,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor:
//                       hasSelection
//                           ? AppColors.appPriSecColor.primaryColor
//                           : AppColors.strokeColor.greyColor,
//                   foregroundColor: Colors.white,
//                   elevation: hasSelection ? 4 : 0,
//                   shadowColor: AppColors.appPriSecColor.primaryColor
//                       .withValues(alpha: 0.3),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.send_rounded, color: Colors.white, size: 20),
//                     const SizedBox(width: 8),
//                     Text(
//                       'Forward Messages',
//                       style: AppTypography.buttonText(context).copyWith(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildList(
//     ChatProvider chatProvider,
//     ContactListProvider contactProvider,
//   ) {
//     if (chatProvider.isChatListLoading && _allItems.isEmpty) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     if (contactProvider.isLoading && _allItems.isEmpty) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     if (_filteredItems.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               _searchQuery.isNotEmpty
//                   ? Icons.search_off
//                   : Icons.chat_bubble_outline,
//               size: 64,
//               color: AppColors.textColor.textGreyColor,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               _searchQuery.isNotEmpty
//                   ? 'No results found for "$_searchQuery"'
//                   : 'No chats or contacts available',
//               style: AppTypography.h5(context).copyWith(
//                 color: AppColors.textColor.textGreyColor,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             if (_searchQuery.isNotEmpty) ...[
//               const SizedBox(height: 8),
//               Text(
//                 'Try searching with different keywords',
//                 style: AppTypography.mediumText(
//                   context,
//                 ).copyWith(color: AppColors.textColor.textGreyColor),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ],
//         ),
//       );
//     }

//     return ListView.builder(
//       controller: _scrollController,
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       itemCount:
//           _filteredItems.length +
//           (chatProvider.isChatListPaginationLoading ? 1 : 0),
//       itemBuilder: (context, index) {
//         // Show loading indicator at the end
//         if (index >= _filteredItems.length) {
//           return Container(
//             padding: const EdgeInsets.all(16),
//             alignment: Alignment.center,
//             child: SizedBox(
//               height: 20,
//               width: 20,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 valueColor: AlwaysStoppedAnimation<Color>(
//                   AppColors.appPriSecColor.primaryColor,
//                 ),
//               ),
//             ),
//           );
//         }

//         final item = _filteredItems[index];
//         final isSelected = _selectedItems.contains(item.id);

//         return _buildListItem(item, isSelected);
//       },
//     );
//   }

//   Widget _buildListItem(ForwardItem item, bool isSelected) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border:
//             isSelected
//                 ? Border.all(
//                   color: AppColors.appPriSecColor.primaryColor,
//                   width: 2,
//                 )
//                 : null,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(12),
//           onTap: () => _toggleSelection(item),
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Row(
//               children: [
//                 // Profile Picture / Icon
//                 Stack(
//                   children: [
//                     Container(
//                       width: 48,
//                       height: 48,
//                       decoration: BoxDecoration(
//                         color: AppColors.appPriSecColor.primaryColor
//                             .withValues(alpha: 0.1),
//                         borderRadius: BorderRadius.circular(24),
//                         image:
//                             item.profilePic?.isNotEmpty == true
//                                 ? DecorationImage(
//                                   image: NetworkImage(item.profilePic!),
//                                   fit: BoxFit.cover,
//                                 )
//                                 : null,
//                       ),
//                       child:
//                           item.profilePic?.isNotEmpty != true
//                               ? Icon(
//                                 _getIconForItemType(item.type),
//                                 color: AppColors.appPriSecColor.primaryColor,
//                                 size: 24,
//                               )
//                               : null,
//                     ),
//                     // Online indicator
//                     if (item.isOnline)
//                       Positioned(
//                         right: 0,
//                         bottom: 0,
//                         child: Container(
//                           width: 14,
//                           height: 14,
//                           decoration: BoxDecoration(
//                             color: Colors.green,
//                             border: Border.all(color: Colors.white, width: 2),
//                             borderRadius: BorderRadius.circular(7),
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),

//                 const SizedBox(width: 12),

//                 // Content
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               item.name,
//                               style: AppTypography.h5(
//                                 context,
//                               ).copyWith(fontWeight: FontWeight.w600),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                           // Type indicator
//                           _buildTypeIndicator(item.type),
//                         ],
//                       ),
//                       if (item.lastMessage?.isNotEmpty == true) ...[
//                         const SizedBox(height: 4),
//                         Text(
//                           item.lastMessage!,
//                           style: AppTypography.smallText(
//                             context,
//                           ).copyWith(color: AppColors.textColor.textGreyColor),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),

//                 const SizedBox(width: 8),

//                 // Selection indicator and unseen count
//                 Column(
//                   children: [
//                     // Selection checkbox
//                     Container(
//                       width: 24,
//                       height: 24,
//                       decoration: BoxDecoration(
//                         color:
//                             isSelected
//                                 ? AppColors.appPriSecColor.primaryColor
//                                 : Colors.transparent,
//                         border: Border.all(
//                           color:
//                               isSelected
//                                   ? AppColors.appPriSecColor.primaryColor
//                                   : AppColors.strokeColor.greyColor,
//                           width: 2,
//                         ),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child:
//                           isSelected
//                               ? const Icon(
//                                 Icons.check,
//                                 color: Colors.white,
//                                 size: 16,
//                               )
//                               : null,
//                     ),

//                     // Unseen count
//                     if (item.unseenCount > 0) ...[
//                       const SizedBox(height: 4),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 6,
//                           vertical: 2,
//                         ),
//                         decoration: BoxDecoration(
//                           color: AppColors.appPriSecColor.primaryColor,
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: Text(
//                           item.unseenCount.toString(),
//                           style: AppTypography.smallText(context).copyWith(
//                             color: Colors.white,
//                             fontWeight: FontWeight.w600,
//                             fontSize: 10,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   IconData _getIconForItemType(ForwardItemType type) {
//     switch (type) {
//       case ForwardItemType.group:
//         return Icons.group;
//       case ForwardItemType.recentChat:
//         return Icons.person;
//       case ForwardItemType.contact:
//         return Icons.person_outline;
//     }
//   }

//   Widget _buildTypeIndicator(ForwardItemType type) {
//     String text;
//     Color color;

//     switch (type) {
//       case ForwardItemType.group:
//         text = 'Group';
//         color = Colors.blue;
//         break;
//       case ForwardItemType.recentChat:
//         text = 'Recent';
//         color = Colors.green;
//         break;
//       case ForwardItemType.contact:
//         text = 'Contact';
//         color = Colors.orange;
//         break;
//     }

//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(4),
//       ),
//       child: Text(
//         text,
//         style: AppTypography.smallText(
//           context,
//         ).copyWith(color: color, fontWeight: FontWeight.w500, fontSize: 10),
//       ),
//     );
//   }
// }

// // Contact detail model for type safety
// class ContactDetail {
//   final String? name;
//   final String? number;
//   final int? userId;

//   ContactDetail({this.name, this.number, this.userId});
// }

// /*
// USAGE EXAMPLE:

// // 1. Basic Usage in your ContactListScreen
// Widget _buildForwardMode() {
//   return Scaffold(
//     appBar: AppBar(title: Text('Forward Messages')),
//     body: ForwardListManager(
//       showForwardButton: true,
//       selectedMessageIds: widget.selectedMessageIds, // IMPORTANT: Pass message IDs
//       fromChatId: widget.fromChatId, // IMPORTANT: Pass from chat ID
//       onSelectionChanged: (chatIds, userIds) {
//         debugPrint('Selection: chats=$chatIds, users=$userIds');
//       },
//       onForwardPressed: (chatIds, userIds) {
//         // Handle forward action
//         _performForward(chatIds, userIds);
//       },
//       onItemTap: (item) {
//         debugPrint('Tapped: ${item.name}');
//       },
//     ),
//   );
// }

// // 2. Navigation example
// Navigator.push(
//   context,
//   MaterialPageRoute(
//     builder: (context) => ContactListScreen(
//       isForwardMode: true,
//       selectedMessageIds: [123, 456, 789], // MUST provide message IDs
//       fromChatId: currentChatId, // MUST provide from chat ID
//     ),
//   ),
// );

// // 3. Debug example - Check your navigation call
// void _navigateToForward() {
//   final selectedMessages = [123, 456, 789]; // Your selected message IDs
//   final currentChat = 100; // Your current chat ID

//   debugPrint('🔍 Navigating with selectedMessages: $selectedMessages');
//   debugPrint('🔍 Navigating with currentChat: $currentChat');

//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => ContactListScreenV2(
//         isForwardMode: true,
//         selectedMessageIds: selectedMessages, // This MUST not be null/empty
//         fromChatId: currentChat, // This MUST not be null
//       ),
//     ),
//   );
// }
// */

// // forward_list_manager.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
// import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
// import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
// import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
// import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
// import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
// import 'package:whoxa/utils/app_size_config.dart';

// class ForwardItem {
//   final String id;
//   final String name;
//   final String? profilePic;
//   final ForwardItemType type;
//   final int? chatId;
//   final int? userId;
//   final String? lastMessage;
//   final String? lastMessageTime;
//   final bool isOnline;
//   final int unseenCount;
//   final String? chatType;
//   final bool isSelected; // Add this to track selection across tabs

//   ForwardItem({
//     required this.id,
//     required this.name,
//     this.profilePic,
//     required this.type,
//     this.chatId,
//     this.userId,
//     this.lastMessage,
//     this.lastMessageTime,
//     this.isOnline = false,
//     this.unseenCount = 0,
//     this.chatType,
//     this.isSelected = false,
//   });

//   // Create from chat list item (existing chats)
//   factory ForwardItem.fromChatList(Chats chat) {
//     final record =
//         chat.records?.isNotEmpty == true ? chat.records!.first : null;
//     final peerUserData = chat.peerUserData;

//     String displayName = '';
//     String? profilePic;

//     if (record?.chatType?.toLowerCase() == 'group') {
//       displayName = record?.groupName ?? 'Group Chat';
//       profilePic = record?.groupIcon;
//     } else {
//       // Show fullName if available, otherwise userName, otherwise 'Unknown'
//       displayName =
//           peerUserData?.fullName?.isNotEmpty == true
//               ? peerUserData!.fullName!
//               : peerUserData?.userName?.isNotEmpty == true
//               ? peerUserData!.userName!
//               : 'Unknown User';
//       profilePic = peerUserData?.profilePic;
//     }

//     return ForwardItem(
//       id: 'chat_${record?.chatId ?? 0}',
//       name: displayName,
//       profilePic: profilePic,
//       type: ForwardItemType.recentChat,
//       chatId: record?.chatId,
//       userId: peerUserData?.userId, // Always use PeerUserData.userId
//       lastMessage:
//           chat.records?.isNotEmpty == true
//               ? chat.records!.first.messages?.isNotEmpty == true
//                   ? chat.records!.first.messages!.first.messageContent
//                   : null
//               : null,
//       lastMessageTime:
//           chat.records?.isNotEmpty == true
//               ? chat.records!.first.messages?.isNotEmpty == true
//                   ? chat.records!.first.messages!.first.createdAt
//                   : null
//               : null,
//       unseenCount: record?.unseenCount ?? 0,
//       chatType: record?.chatType,
//     );
//   }

//   // Create from contact item (contacts without existing chats)
//   factory ForwardItem.fromContact(ContactDetail contact, bool isOnline) {
//     return ForwardItem(
//       id: 'contact_${contact.userId ?? 0}',
//       name: contact.name ?? 'Unknown Contact',
//       profilePic: null, // Contact list doesn't have profile pics
//       type: ForwardItemType.contact,
//       chatId: null,
//       userId: contact.userId,
//       lastMessage: null,
//       lastMessageTime: null,
//       isOnline: isOnline,
//       unseenCount: 0,
//     );
//   }

//   // Copy with method to update selection state
//   ForwardItem copyWith({bool? isSelected}) {
//     return ForwardItem(
//       id: id,
//       name: name,
//       profilePic: profilePic,
//       type: type,
//       chatId: chatId,
//       userId: userId,
//       lastMessage: lastMessage,
//       lastMessageTime: lastMessageTime,
//       isOnline: isOnline,
//       unseenCount: unseenCount,
//       chatType: chatType,
//       isSelected: isSelected ?? this.isSelected,
//     );
//   }
// }

// enum ForwardItemType { recentChat, contact }

// class ForwardListManager extends StatefulWidget {
//   final Function(List<int> chatIds, List<int> userIds) onSelectionChanged;
//   final Function(ForwardItem item) onItemTap;
//   final Function(List<int> chatIds, List<int> userIds)? onForwardPressed;
//   final bool showForwardButton;
//   final List<int>? selectedMessageIds;
//   final int? fromChatId;

//   const ForwardListManager({
//     Key? key,
//     required this.onSelectionChanged,
//     required this.onItemTap,
//     this.onForwardPressed,
//     this.showForwardButton = true,
//     this.selectedMessageIds,
//     this.fromChatId,
//   }) : super(key: key);

//   @override
//   State<ForwardListManager> createState() => _ForwardListManagerState();
// }

// class _ForwardListManagerState extends State<ForwardListManager>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   final TextEditingController _searchController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();

//   List<ForwardItem> _allRecentChats = [];
//   List<ForwardItem> _allContacts = [];
//   List<ForwardItem> _filteredItems = [];
//   Set<String> _selectedItems = {}; // Global selection across tabs
//   String _searchQuery = '';

//   // Track current tab
//   int _currentTabIndex = 0;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _searchController.addListener(_onSearchChanged);
//     _scrollController.addListener(_onScroll);

//     _tabController.addListener(() {
//       if (_tabController.indexIsChanging) {
//         setState(() {
//           _currentTabIndex = _tabController.index;
//           _filterItems();
//         });
//       }
//     });

//     // Load initial data
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _loadData();
//     });
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     _searchController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   void _onSearchChanged() {
//     setState(() {
//       _searchQuery = _searchController.text.toLowerCase();
//       _filterItems();
//     });
//   }

//   void _onScroll() {
//     // Handle pagination for chat list when scrolling near the bottom
//     // Only paginate when on recent chats tab
//     if (_currentTabIndex == 0 &&
//         _scrollController.position.pixels >=
//             _scrollController.position.maxScrollExtent - 200) {
//       _loadMoreChats();
//     }
//   }

//   Future<void> _loadData() async {
//     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
//     final contactProvider = Provider.of<ContactListProvider>(
//       context,
//       listen: false,
//     );

//     // Load chat list if not already loaded
//     if (chatProvider.chatListData.chats.isEmpty) {
//       await chatProvider.emitChatList();
//     }

//     // Load contacts if not already loaded
//     if (contactProvider.chatContacts.isEmpty) {
//       await contactProvider.refreshContacts();
//     }

//     _buildSeparatedLists();
//   }

//   Future<void> _loadMoreChats() async {
//     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
//     if (chatProvider.hasChatListMoreData &&
//         !chatProvider.isChatListPaginationLoading) {
//       await chatProvider.loadMoreChatList();
//       _buildSeparatedLists();
//     }
//   }

//   void _buildSeparatedLists() {
//     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
//     final contactProvider = Provider.of<ContactListProvider>(
//       context,
//       listen: false,
//     );

//     List<ForwardItem> recentChats = [];
//     List<ForwardItem> contacts = [];
//     Set<int> existingChatUserIds = {};

//     // 1. Build recent chats list
//     for (final chat in chatProvider.chatListData.chats) {
//       if (chat.records?.isNotEmpty == true) {
//         final record = chat.records!.first;

//         // Skip the current chat (can't forward to yourself)
//         if (widget.fromChatId != null && record.chatId == widget.fromChatId) {
//           continue;
//         }

//         // Track existing chat user IDs for private chats only
//         if ((record.chatType?.toLowerCase() == 'private') &&
//             chat.peerUserData?.userId != null) {
//           existingChatUserIds.add(chat.peerUserData!.userId!);
//         }

//         recentChats.add(ForwardItem.fromChatList(chat));
//       }
//     }

//     // 2. Build contacts list (include all contacts, don't exclude existing chat users)
//     Set<String> processedNumbers = {};
//     for (final contact in contactProvider.chatContacts) {
//       final userId = int.tryParse(contact.userId ?? '');

//       // Get phone number for deduplication
//       String? phoneNumber;
//       if (contact.phoneNumber.isNotEmpty == true) {
//         phoneNumber = contact.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
//       }

//       // Skip if we've already processed this phone number
//       if (phoneNumber != null && processedNumbers.contains(phoneNumber)) {
//         continue;
//       }

//       // Add contact if it has a valid userId and unique phone number
//       if (userId != null && phoneNumber != null) {
//         processedNumbers.add(phoneNumber);
//         final isOnline = chatProvider.isUserOnline(userId);
//         contacts.add(
//           ForwardItem.fromContact(
//             ContactDetail(
//               name: contact.name,
//               number: phoneNumber,
//               userId: userId,
//             ),
//             isOnline,
//           ),
//         );
//       }
//     }

//     setState(() {
//       _allRecentChats = recentChats;
//       _allContacts = contacts;
//       _filterItems();
//     });
//   }

//   void _filterItems() {
//     List<ForwardItem> sourceList = [];

//     // Get source list based on current tab
//     switch (_currentTabIndex) {
//       case 0: // Recent Chats
//         sourceList = _allRecentChats;
//         break;
//       case 1: // Contacts
//         sourceList = _allContacts;
//         break;
//     }

//     // Apply search filter
//     List<ForwardItem> filtered = sourceList;
//     if (_searchQuery.isNotEmpty) {
//       filtered =
//           sourceList
//               .where((item) => item.name.toLowerCase().contains(_searchQuery))
//               .toList();
//     }

//     // Apply selection state to filtered items
//     filtered =
//         filtered.map((item) {
//           return item.copyWith(isSelected: _selectedItems.contains(item.id));
//         }).toList();

//     setState(() {
//       _filteredItems = filtered;
//     });
//   }

//   void _toggleSelection(ForwardItem item) {
//     setState(() {
//       bool isCurrentlySelected = _selectedItems.contains(item.id);

//       if (isCurrentlySelected) {
//         // Remove this item
//         _selectedItems.remove(item.id);

//         // Also remove the corresponding user from the other tab if it exists
//         _removeCorrespondingUserSelection(item);
//       } else {
//         // Add this item
//         _selectedItems.add(item.id);

//         // Also add the corresponding user from the other tab if it exists
//         _addCorrespondingUserSelection(item);
//       }

//       _filterItems(); // Refresh to update selection state
//       _notifySelectionChanged();
//     });
//   }

//   void _removeCorrespondingUserSelection(ForwardItem selectedItem) {
//     if (selectedItem.userId == null) return;

//     // Find corresponding items in the other list
//     if (selectedItem.type == ForwardItemType.recentChat) {
//       // Look for same user in contacts
//       final correspondingContact = _allContacts.where(
//         (contact) => contact.userId == selectedItem.userId,
//       );
//       for (final contact in correspondingContact) {
//         _selectedItems.remove(contact.id);
//       }
//     } else if (selectedItem.type == ForwardItemType.contact) {
//       // Look for same user in recent chats (private chats only)
//       final correspondingChats = _allRecentChats.where(
//         (chat) =>
//             chat.userId == selectedItem.userId &&
//             chat.chatType?.toLowerCase() == 'private',
//       );
//       for (final chat in correspondingChats) {
//         _selectedItems.remove(chat.id);
//       }
//     }
//   }

//   void _addCorrespondingUserSelection(ForwardItem selectedItem) {
//     if (selectedItem.userId == null) return;

//     // Find corresponding items in the other list
//     if (selectedItem.type == ForwardItemType.recentChat) {
//       // Look for same user in contacts
//       final correspondingContact = _allContacts.where(
//         (contact) => contact.userId == selectedItem.userId,
//       );
//       for (final contact in correspondingContact) {
//         _selectedItems.add(contact.id);
//       }
//     } else if (selectedItem.type == ForwardItemType.contact) {
//       // Look for same user in recent chats (private chats only)
//       final correspondingChats = _allRecentChats.where(
//         (chat) =>
//             chat.userId == selectedItem.userId &&
//             chat.chatType?.toLowerCase() == 'private',
//       );
//       for (final chat in correspondingChats) {
//         _selectedItems.add(chat.id);
//       }
//     }
//   }

//   void _notifySelectionChanged() {
//     List<int> chatIds = [];
//     List<int> userIds = [];

//     for (final itemId in _selectedItems) {
//       // Find item in either recent chats or contacts
//       ForwardItem? item;

//       try {
//         item = _allRecentChats.firstWhere((item) => item.id == itemId);
//       } catch (e) {
//         try {
//           item = _allContacts.firstWhere((item) => item.id == itemId);
//         } catch (e) {
//           continue; // Item not found, skip
//         }
//       }

//       if (item != null) {
//         if (item.chatId != null) {
//           // Existing chat
//           chatIds.add(item.chatId!);
//         } else if (item.userId != null) {
//           // Contact without existing chat
//           userIds.add(item.userId!);
//         }
//       }
//     }

//     widget.onSelectionChanged(chatIds, userIds);
//   }

//   void _handleForwardPressed() {
//     // Validate that we have messages to forward
//     if (widget.selectedMessageIds == null ||
//         widget.selectedMessageIds!.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('No messages selected for forwarding'),
//           backgroundColor: Colors.red,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }

//     // Validate that we have recipients selected
//     if (_selectedItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Please select at least one chat or contact'),
//           backgroundColor: Colors.orange,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }

//     List<int> chatIds = [];
//     List<int> userIds = [];

//     for (final itemId in _selectedItems) {
//       // Find item in either recent chats or contacts
//       ForwardItem? item;

//       try {
//         item = _allRecentChats.firstWhere((item) => item.id == itemId);
//       } catch (e) {
//         try {
//           item = _allContacts.firstWhere((item) => item.id == itemId);
//         } catch (e) {
//           continue; // Item not found, skip
//         }
//       }

//       if (item != null) {
//         if (item.chatId != null) {
//           // Existing chat
//           chatIds.add(item.chatId!);
//         } else if (item.userId != null) {
//           // Contact without existing chat
//           userIds.add(item.userId!);
//         }
//       }
//     }

//     // Call the provided forward callback
//     if (widget.onForwardPressed != null) {
//       widget.onForwardPressed!(chatIds, userIds);
//     } else {
//       // Fallback to selection changed callback
//       widget.onSelectionChanged(chatIds, userIds);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Consumer2<ChatProvider, ContactListProvider>(
//       builder: (context, chatProvider, contactProvider, child) {
//         // Rebuild lists when data changes
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           _buildSeparatedLists();
//         });

//         return Column(
//           children: [
//             // Search Bar
//             Container(
//               margin: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withValues(alpha: 0.05),
//                     blurRadius: 8,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: TextField(
//                 controller: _searchController,
//                 style: AppTypography.mediumText(context),
//                 decoration: InputDecoration(
//                   hintText:
//                       _currentTabIndex == 0
//                           ? 'Search recent chats...'
//                           : 'Search contacts...',
//                   hintStyle: AppTypography.mediumText(
//                     context,
//                   ).copyWith(color: AppColors.textColor.textGreyColor),
//                   prefixIcon: Icon(
//                     Icons.search_rounded,
//                     color: AppColors.appPriSecColor.primaryColor,
//                     size: 20,
//                   ),
//                   border: InputBorder.none,
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 12,
//                   ),
//                 ),
//               ),
//             ),

//             // Tab Bar
//             Container(
//               margin: const EdgeInsets.symmetric(horizontal: 16),
//               decoration: BoxDecoration(
//                 color: AppColors.bgColor.bg1Color,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: TabBar(
//                 controller: _tabController,
//                 indicator: BoxDecoration(
//                   color: AppColors.appPriSecColor.primaryColor,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 indicatorSize: TabBarIndicatorSize.tab,
//                 labelColor: Colors.white,
//                 unselectedLabelColor: AppColors.textColor.textGreyColor,
//                 labelStyle: AppTypography.mediumText(
//                   context,
//                 ).copyWith(fontWeight: FontWeight.w600),
//                 unselectedLabelStyle: AppTypography.mediumText(context),
//                 tabs: [
//                   Tab(text: 'Recent Chats (${_allRecentChats.length})'),
//                   Tab(text: 'Contacts (${_allContacts.length})'),
//                 ],
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Selection Counter
//             if (_selectedItems.isNotEmpty)
//               Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 16),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 8,
//                 ),
//                 decoration: BoxDecoration(
//                   color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 
//                       0.3,
//                     ),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(
//                       Icons.check_circle,
//                       color: AppColors.appPriSecColor.primaryColor,
//                       size: 16,
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       '${_selectedItems.length} selected',
//                       style: AppTypography.smallText(context).copyWith(
//                         color: AppColors.appPriSecColor.primaryColor,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     const Spacer(),
//                     GestureDetector(
//                       onTap: () {
//                         setState(() {
//                           _selectedItems.clear();
//                           _filterItems();
//                           _notifySelectionChanged();
//                         });
//                       },
//                       child: Text(
//                         'Clear All',
//                         style: AppTypography.smallText(context).copyWith(
//                           color: AppColors.appPriSecColor.primaryColor,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//             const SizedBox(height: 8),

//             // List
//             Expanded(child: _buildList(chatProvider, contactProvider)),

//             // Forward Button (show at bottom when items are selected)
//             if (widget.showForwardButton && _selectedItems.isNotEmpty)
//               _buildForwardButton(),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildForwardButton() {
//     final hasSelection = _selectedItems.isNotEmpty;
//     final totalSelected = _selectedItems.length;

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(24),
//           topRight: Radius.circular(24),
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.1),
//             blurRadius: 20,
//             offset: const Offset(0, -4),
//           ),
//         ],
//       ),
//       child: SafeArea(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Selection summary
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(12),
//               margin: const EdgeInsets.only(bottom: 12),
//               decoration: BoxDecoration(
//                 color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(
//                   color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.3),
//                 ),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Icon(
//                         Icons.info_outline,
//                         color: AppColors.appPriSecColor.primaryColor,
//                         size: 18,
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           'Ready to forward to $totalSelected recipient${totalSelected != 1 ? 's' : ''}',
//                           style: AppTypography.smallText(context).copyWith(
//                             color: AppColors.appPriSecColor.primaryColor,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   if (widget.selectedMessageIds != null &&
//                       widget.selectedMessageIds!.isNotEmpty) ...[
//                     const SizedBox(height: 4),
//                     Text(
//                       'Forwarding ${widget.selectedMessageIds!.length} message${widget.selectedMessageIds!.length != 1 ? 's' : ''}',
//                       style: AppTypography.smallText(context).copyWith(
//                         color: AppColors.appPriSecColor.primaryColor
//                             .withValues(alpha: 0.8),
//                         fontSize: 11,
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),

//             // Forward Button
//             AnimatedContainer(
//               duration: const Duration(milliseconds: 200),
//               width: double.infinity,
//               height: 52,
//               child: ElevatedButton(
//                 onPressed: hasSelection ? _handleForwardPressed : null,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor:
//                       hasSelection
//                           ? AppColors.appPriSecColor.primaryColor
//                           : AppColors.strokeColor.greyColor,
//                   foregroundColor: Colors.white,
//                   elevation: hasSelection ? 4 : 0,
//                   shadowColor: AppColors.appPriSecColor.primaryColor
//                       .withValues(alpha: 0.3),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.send_rounded, color: Colors.white, size: 20),
//                     const SizedBox(width: 8),
//                     Text(
//                       'Forward Messages',
//                       style: AppTypography.buttonText(context).copyWith(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildList(
//     ChatProvider chatProvider,
//     ContactListProvider contactProvider,
//   ) {
//     // Show loading for the appropriate provider
//     bool isLoading = false;
//     if (_currentTabIndex == 0 &&
//         chatProvider.isChatListLoading &&
//         _allRecentChats.isEmpty) {
//       isLoading = true;
//     } else if (_currentTabIndex == 1 &&
//         contactProvider.isLoading &&
//         _allContacts.isEmpty) {
//       isLoading = true;
//     }

//     if (isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     if (_filteredItems.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               _searchQuery.isNotEmpty
//                   ? Icons.search_off
//                   : _currentTabIndex == 0
//                   ? Icons.chat_bubble_outline
//                   : Icons.contacts_outlined,
//               size: 64,
//               color: AppColors.textColor.textGreyColor,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               _searchQuery.isNotEmpty
//                   ? 'No results found for "$_searchQuery"'
//                   : _currentTabIndex == 0
//                   ? 'No recent chats available'
//                   : 'No contacts available',
//               style: AppTypography.h5(context).copyWith(
//                 color: AppColors.textColor.textGreyColor,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             if (_searchQuery.isNotEmpty) ...[
//               const SizedBox(height: 8),
//               Text(
//                 'Try searching with different keywords',
//                 style: AppTypography.mediumText(
//                   context,
//                 ).copyWith(color: AppColors.textColor.textGreyColor),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ],
//         ),
//       );
//     }

//     return ListView.builder(
//       controller: _scrollController,
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       itemCount:
//           _filteredItems.length +
//           ((_currentTabIndex == 0 && chatProvider.isChatListPaginationLoading)
//               ? 1
//               : 0),
//       itemBuilder: (context, index) {
//         // Show loading indicator at the end for recent chats pagination
//         if (index >= _filteredItems.length) {
//           return Container(
//             padding: const EdgeInsets.all(16),
//             alignment: Alignment.center,
//             child: SizedBox(
//               height: 20,
//               width: 20,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 valueColor: AlwaysStoppedAnimation<Color>(
//                   AppColors.appPriSecColor.primaryColor,
//                 ),
//               ),
//             ),
//           );
//         }

//         final item = _filteredItems[index];
//         return _buildListItem(item);
//       },
//     );
//   }

//   Widget _buildListItem(ForwardItem item) {
//     final isSelected = _selectedItems.contains(item.id);

//     return Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border:
//             isSelected
//                 ? Border.all(
//                   color: AppColors.appPriSecColor.primaryColor,
//                   width: 2,
//                 )
//                 : null,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(12),
//           onTap: () => _toggleSelection(item),
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Row(
//               children: [
//                 // Profile Picture / Icon
//                 Stack(
//                   children: [
//                     Container(
//                       width: 48,
//                       height: 48,
//                       decoration: BoxDecoration(
//                         color: AppColors.appPriSecColor.primaryColor
//                             .withValues(alpha: 0.1),
//                         borderRadius: BorderRadius.circular(24),
//                         image:
//                             item.profilePic?.isNotEmpty == true
//                                 ? DecorationImage(
//                                   image: NetworkImage(item.profilePic!),
//                                   fit: BoxFit.cover,
//                                 )
//                                 : null,
//                       ),
//                       child:
//                           item.profilePic?.isNotEmpty != true
//                               ? Icon(
//                                 _getIconForItemType(item.type),
//                                 color: AppColors.appPriSecColor.primaryColor,
//                                 size: 24,
//                               )
//                               : null,
//                     ),
//                     // Online indicator
//                     if (item.isOnline)
//                       Positioned(
//                         right: 0,
//                         bottom: 0,
//                         child: Container(
//                           width: 14,
//                           height: 14,
//                           decoration: BoxDecoration(
//                             color: Colors.green,
//                             border: Border.all(color: Colors.white, width: 2),
//                             borderRadius: BorderRadius.circular(7),
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),

//                 const SizedBox(width: 12),

//                 // Content
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               item.name,
//                               style: AppTypography.h5(
//                                 context,
//                               ).copyWith(fontWeight: FontWeight.w600),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                           // Type indicator
//                           _buildTypeIndicator(item.type),
//                         ],
//                       ),
//                       if (item.lastMessage?.isNotEmpty == true) ...[
//                         const SizedBox(height: 4),
//                         Text(
//                           item.lastMessage!,
//                           style: AppTypography.smallText(
//                             context,
//                           ).copyWith(color: AppColors.textColor.textGreyColor),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),

//                 const SizedBox(width: 8),

//                 // Selection indicator and unseen count
//                 Column(
//                   children: [
//                     // Selection checkbox
//                     Container(
//                       width: 24,
//                       height: 24,
//                       decoration: BoxDecoration(
//                         color:
//                             isSelected
//                                 ? AppColors.appPriSecColor.primaryColor
//                                 : Colors.transparent,
//                         border: Border.all(
//                           color:
//                               isSelected
//                                   ? AppColors.appPriSecColor.primaryColor
//                                   : AppColors.strokeColor.greyColor,
//                           width: 2,
//                         ),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child:
//                           isSelected
//                               ? const Icon(
//                                 Icons.check,
//                                 color: Colors.white,
//                                 size: 16,
//                               )
//                               : null,
//                     ),

//                     // Unseen count (only for recent chats)
//                     if (item.unseenCount > 0 &&
//                         item.type == ForwardItemType.recentChat) ...[
//                       const SizedBox(height: 4),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 6,
//                           vertical: 2,
//                         ),
//                         decoration: BoxDecoration(
//                           color: AppColors.appPriSecColor.primaryColor,
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: Text(
//                           item.unseenCount.toString(),
//                           style: AppTypography.smallText(context).copyWith(
//                             color: Colors.white,
//                             fontWeight: FontWeight.w600,
//                             fontSize: 10,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   IconData _getIconForItemType(ForwardItemType type) {
//     switch (type) {
//       case ForwardItemType.recentChat:
//         return Icons.chat_bubble_outline;
//       case ForwardItemType.contact:
//         return Icons.person_outline;
//     }
//   }

//   Widget _buildTypeIndicator(ForwardItemType type) {
//     String text;
//     Color color;

//     switch (type) {
//       case ForwardItemType.recentChat:
//         text = 'Recent';
//         color = Colors.blue;
//         break;
//       case ForwardItemType.contact:
//         text = 'Contact';
//         color = Colors.green;
//         break;
//     }

//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(4),
//       ),
//       child: Text(
//         text,
//         style: AppTypography.smallText(
//           context,
//         ).copyWith(color: color, fontWeight: FontWeight.w500, fontSize: 10),
//       ),
//     );
//   }
// }

// // Contact detail model for type safety
// class ContactDetail {
//   final String? name;
//   final String? number;
//   final int? userId;

//   ContactDetail({this.name, this.number, this.userId});
// }

// /*
// USAGE EXAMPLE:

// // 1. Basic Usage in your ContactListScreen
// Widget _buildForwardMode() {
//   return Scaffold(
//     appBar: AppBar(title: Text('Forward Messages')),
//     body: ForwardListManager(
//       showForwardButton: true,
//       selectedMessageIds: widget.selectedMessageIds,
//       fromChatId: widget.fromChatId,
//       onSelectionChanged: (chatIds, userIds) {
//         debugPrint('Selection: chats=$chatIds, users=$userIds');
//       },
//       onForwardPressed: (chatIds, userIds) {
//         // Handle forward action
//         _performForward(chatIds, userIds);
//       },
//       onItemTap: (item) {
//         debugPrint('Tapped: ${item.name}');
//       },
//     ),
//   );
// }

// // 2. Navigation example
// Navigator.push(
//   context,
//   MaterialPageRoute(
//     builder: (context) => ContactListScreen(
//       isForwardMode: true,
//       selectedMessageIds: [123, 456, 789],
//       fromChatId: currentChatId,
//     ),
//   ),
// );

// // 3. Key Features:
// // ✅ Recent Chats Tab - Shows all existing chats with pagination
// // ✅ Contacts Tab - Shows contacts without existing chats
// // ✅ Global Selection - Selected items persist across tab switches
// // ✅ Smart Name Display - fullName → userName → "Unknown User"
// // ✅ Proper Filtering - Excludes current chat and existing chat users from contacts
// // ✅ Online Status - Shows for both recent chats and contacts
// // ✅ Pagination - Works only on Recent Chats tab
// // ✅ Tab Counters - Shows count of items in each tab
// // ✅ Search - Different placeholders for each tab
// */

// // // forward_list_manager.dart
// // import 'package:flutter/material.dart';
// // import 'package:provider/provider.dart';
// // import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
// // import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
// // import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
// // import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
// // import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
// // import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
// // import 'package:whoxa/utils/app_size_config.dart';

// // // Forward item model to unify different data types
// // class ForwardItem {
// //   final String id;
// //   final String name;
// //   final String? profilePic;
// //   final ForwardItemType type;
// //   final int? chatId;
// //   final int? userId;
// //   final String? lastMessage;
// //   final String? lastMessageTime;
// //   final bool isOnline;
// //   final int unseenCount;
// //   final String? chatType;
// //   final bool isSelected; // Add this to track selection across tabs

// //   ForwardItem({
// //     required this.id,
// //     required this.name,
// //     this.profilePic,
// //     required this.type,
// //     this.chatId,
// //     this.userId,
// //     this.lastMessage,
// //     this.lastMessageTime,
// //     this.isOnline = false,
// //     this.unseenCount = 0,
// //     this.chatType,
// //     this.isSelected = false,
// //   });

// //   // Create from chat list item (existing chats)
// //   factory ForwardItem.fromChatList(Chats chat) {
// //     final record =
// //         chat.records?.isNotEmpty == true ? chat.records!.first : null;
// //     final peerUserData = chat.peerUserData;

// //     String displayName = '';
// //     String? profilePic;

// //     if (record?.chatType?.toLowerCase() == 'group') {
// //       displayName = record?.groupName ?? 'Group Chat';
// //       profilePic = record?.groupIcon;
// //     } else {
// //       // Show fullName if available, otherwise userName, otherwise 'Unknown'
// //       displayName =
// //           peerUserData?.fullName?.isNotEmpty == true
// //               ? peerUserData!.fullName!
// //               : peerUserData?.userName?.isNotEmpty == true
// //               ? peerUserData!.userName!
// //               : 'Unknown User';
// //       profilePic = peerUserData?.profilePic;
// //     }

// //     return ForwardItem(
// //       id: 'chat_${record?.chatId ?? 0}',
// //       name: displayName,
// //       profilePic: profilePic,
// //       type: ForwardItemType.recentChat,
// //       chatId: record?.chatId,
// //       userId: peerUserData?.userId, // Always use PeerUserData.userId
// //       lastMessage:
// //           chat.records?.isNotEmpty == true
// //               ? chat.records!.first.messages?.isNotEmpty == true
// //                   ? chat.records!.first.messages!.first.messageContent
// //                   : null
// //               : null,
// //       lastMessageTime:
// //           chat.records?.isNotEmpty == true
// //               ? chat.records!.first.messages?.isNotEmpty == true
// //                   ? chat.records!.first.messages!.first.createdAt
// //                   : null
// //               : null,
// //       unseenCount: record?.unseenCount ?? 0,
// //       chatType: record?.chatType,
// //     );
// //   }

// //   // Create from contact item (contacts without existing chats)
// //   factory ForwardItem.fromContact(ContactDetail contact, bool isOnline) {
// //     return ForwardItem(
// //       id: 'contact_${contact.userId ?? 0}',
// //       name: contact.name ?? 'Unknown Contact',
// //       profilePic: null, // Contact list doesn't have profile pics
// //       type: ForwardItemType.contact,
// //       chatId: null,
// //       userId: contact.userId,
// //       lastMessage: null,
// //       lastMessageTime: null,
// //       isOnline: isOnline,
// //       unseenCount: 0,
// //     );
// //   }

// //   // Copy with method to update selection state
// //   ForwardItem copyWith({bool? isSelected}) {
// //     return ForwardItem(
// //       id: id,
// //       name: name,
// //       profilePic: profilePic,
// //       type: type,
// //       chatId: chatId,
// //       userId: userId,
// //       lastMessage: lastMessage,
// //       lastMessageTime: lastMessageTime,
// //       isOnline: isOnline,
// //       unseenCount: unseenCount,
// //       chatType: chatType,
// //       isSelected: isSelected ?? this.isSelected,
// //     );
// //   }
// // }

// // enum ForwardItemType { recentChat, contact }

// // class ForwardListManager extends StatefulWidget {
// //   final Function(List<int> chatIds, List<int> userIds) onSelectionChanged;
// //   final Function(ForwardItem item) onItemTap;
// //   final Function(List<int> chatIds, List<int> userIds)? onForwardPressed;
// //   final bool showForwardButton;
// //   final List<int>? selectedMessageIds;
// //   final int? fromChatId;

// //   const ForwardListManager({
// //     Key? key,
// //     required this.onSelectionChanged,
// //     required this.onItemTap,
// //     this.onForwardPressed,
// //     this.showForwardButton = true,
// //     this.selectedMessageIds,
// //     this.fromChatId,
// //   }) : super(key: key);

// //   @override
// //   State<ForwardListManager> createState() => _ForwardListManagerState();
// // }

// // class _ForwardListManagerState extends State<ForwardListManager>
// //     with SingleTickerProviderStateMixin {
// //   late TabController _tabController;
// //   final TextEditingController _searchController = TextEditingController();
// //   final ScrollController _scrollController = ScrollController();

// //   List<ForwardItem> _allRecentChats = [];
// //   List<ForwardItem> _allContacts = [];
// //   List<ForwardItem> _filteredItems = [];

// //   // Track unique selections by user/chat
// //   Set<String> _selectedItems = {}; // Keep for UI state
// //   Set<int> _selectedUserIds = {}; // Track unique users
// //   Set<int> _selectedChatIds = {}; // Track unique chats

// //   String _searchQuery = '';

// //   // Track current tab
// //   int _currentTabIndex = 0;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _tabController = TabController(length: 2, vsync: this);
// //     _searchController.addListener(_onSearchChanged);
// //     _scrollController.addListener(_onScroll);

// //     _tabController.addListener(() {
// //       if (_tabController.indexIsChanging) {
// //         setState(() {
// //           _currentTabIndex = _tabController.index;
// //           _filterItems();
// //         });
// //       }
// //     });

// //     // Load initial data
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       _loadData();
// //     });
// //   }

// //   @override
// //   void dispose() {
// //     _tabController.dispose();
// //     _searchController.dispose();
// //     _scrollController.dispose();
// //     super.dispose();
// //   }

// //   void _onSearchChanged() {
// //     setState(() {
// //       _searchQuery = _searchController.text.toLowerCase();
// //       _filterItems();
// //     });
// //   }

// //   void _onScroll() {
// //     // Handle pagination for chat list when scrolling near the bottom
// //     // Only paginate when on recent chats tab
// //     if (_currentTabIndex == 0 &&
// //         _scrollController.position.pixels >=
// //             _scrollController.position.maxScrollExtent - 200) {
// //       _loadMoreChats();
// //     }
// //   }

// //   Future<void> _loadData() async {
// //     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
// //     final contactProvider = Provider.of<ContactListProvider>(
// //       context,
// //       listen: false,
// //     );

// //     // Load chat list if not already loaded
// //     if (chatProvider.chatListData.chats.isEmpty) {
// //       await chatProvider.emitChatList();
// //     }

// //     // Load contacts if not already loaded
// //     if (contactProvider.chatContacts.isEmpty) {
// //       await contactProvider.refreshContacts();
// //     }

// //     _buildSeparatedLists();
// //   }

// //   Future<void> _loadMoreChats() async {
// //     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
// //     if (chatProvider.hasChatListMoreData &&
// //         !chatProvider.isChatListPaginationLoading) {
// //       await chatProvider.loadMoreChatList();
// //       _buildSeparatedLists();
// //     }
// //   }

// //   void _buildSeparatedLists() {
// //     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
// //     final contactProvider = Provider.of<ContactListProvider>(
// //       context,
// //       listen: false,
// //     );

// //     List<ForwardItem> recentChats = [];
// //     List<ForwardItem> contacts = [];
// //     Set<int> existingChatUserIds = {};

// //     // 1. Build recent chats list
// //     for (final chat in chatProvider.chatListData.chats) {
// //       if (chat.records?.isNotEmpty == true) {
// //         final record = chat.records!.first;

// //         // Skip the current chat (can't forward to yourself)
// //         if (widget.fromChatId != null && record.chatId == widget.fromChatId) {
// //           continue;
// //         }

// //         // Track existing chat user IDs for private chats only
// //         if ((record.chatType?.toLowerCase() == 'private') &&
// //             chat.peerUserData?.userId != null) {
// //           existingChatUserIds.add(chat.peerUserData!.userId!);
// //         }

// //         recentChats.add(ForwardItem.fromChatList(chat));
// //       }
// //     }

// //     // 2. Build contacts list (include all contacts, don't exclude existing chat users)
// //     Set<String> processedNumbers = {};
// //     for (final contact in contactProvider.chatContacts) {
// //       final userId = int.tryParse(contact.userId ?? '');

// //       // Get phone number for deduplication
// //       String? phoneNumber;
// //       if (contact.phoneNumber.isNotEmpty == true) {
// //         phoneNumber = contact.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
// //       }

// //       // Skip if we've already processed this phone number
// //       if (phoneNumber != null && processedNumbers.contains(phoneNumber)) {
// //         continue;
// //       }

// //       // Add contact if it has a valid userId and unique phone number
// //       if (userId != null && phoneNumber != null) {
// //         processedNumbers.add(phoneNumber);
// //         final isOnline = chatProvider.isUserOnline(userId);
// //         contacts.add(
// //           ForwardItem.fromContact(
// //             ContactDetail(
// //               name: contact.name,
// //               number: phoneNumber,
// //               userId: userId,
// //             ),
// //             isOnline,
// //           ),
// //         );
// //       }
// //     }

// //     setState(() {
// //       _allRecentChats = recentChats;
// //       _allContacts = contacts;
// //       _filterItems();
// //     });
// //   }

// //   void _filterItems() {
// //     List<ForwardItem> sourceList = [];

// //     // Get source list based on current tab
// //     switch (_currentTabIndex) {
// //       case 0: // Recent Chats
// //         sourceList = _allRecentChats;
// //         break;
// //       case 1: // Contacts
// //         sourceList = _allContacts;
// //         break;
// //     }

// //     // Apply search filter
// //     List<ForwardItem> filtered = sourceList;
// //     if (_searchQuery.isNotEmpty) {
// //       filtered =
// //           sourceList
// //               .where((item) => item.name.toLowerCase().contains(_searchQuery))
// //               .toList();
// //     }

// //     // Apply selection state to filtered items
// //     filtered =
// //         filtered.map((item) {
// //           return item.copyWith(isSelected: _selectedItems.contains(item.id));
// //         }).toList();

// //     setState(() {
// //       _filteredItems = filtered;
// //     });
// //   }

// //   void _toggleSelection(ForwardItem item) {
// //     setState(() {
// //       bool isCurrentlySelected = _selectedItems.contains(item.id);

// //       if (isCurrentlySelected) {
// //         // Remove this item
// //         _selectedItems.remove(item.id);

// //         // Also remove the corresponding user from the other tab if it exists
// //         _removeCorrespondingUserSelection(item);
// //       } else {
// //         // Add this item
// //         _selectedItems.add(item.id);

// //         // Also add the corresponding user from the other tab if it exists
// //         _addCorrespondingUserSelection(item);
// //       }

// //       _filterItems(); // Refresh to update selection state
// //       _notifySelectionChanged();
// //     });
// //   }

// //   void _removeCorrespondingUserSelection(ForwardItem selectedItem) {
// //     if (selectedItem.userId == null) return;

// //     // Find corresponding items in the other list
// //     if (selectedItem.type == ForwardItemType.recentChat) {
// //       // Look for same user in contacts
// //       final correspondingContact = _allContacts.where(
// //         (contact) => contact.userId == selectedItem.userId,
// //       );
// //       for (final contact in correspondingContact) {
// //         _selectedItems.remove(contact.id);
// //       }
// //     } else if (selectedItem.type == ForwardItemType.contact) {
// //       // Look for same user in recent chats (private chats only)
// //       final correspondingChats = _allRecentChats.where(
// //         (chat) =>
// //             chat.userId == selectedItem.userId &&
// //             chat.chatType?.toLowerCase() == 'private',
// //       );
// //       for (final chat in correspondingChats) {
// //         _selectedItems.remove(chat.id);
// //       }
// //     }
// //   }

// //   void _addCorrespondingUserSelection(ForwardItem selectedItem) {
// //     if (selectedItem.userId == null) return;

// //     // Find corresponding items in the other list
// //     if (selectedItem.type == ForwardItemType.recentChat) {
// //       // Look for same user in contacts
// //       final correspondingContact = _allContacts.where(
// //         (contact) => contact.userId == selectedItem.userId,
// //       );
// //       for (final contact in correspondingContact) {
// //         _selectedItems.add(contact.id);
// //       }
// //     } else if (selectedItem.type == ForwardItemType.contact) {
// //       // Look for same user in recent chats (private chats only)
// //       final correspondingChats = _allRecentChats.where(
// //         (chat) =>
// //             chat.userId == selectedItem.userId &&
// //             chat.chatType?.toLowerCase() == 'private',
// //       );
// //       for (final chat in correspondingChats) {
// //         _selectedItems.add(chat.id);
// //       }
// //     }
// //   }

// //   void _notifySelectionChanged() {
// //     List<int> chatIds = [];
// //     List<int> userIds = [];

// //     // 1. Add all selected chats (these have priority)
// //     chatIds.addAll(_selectedChatIds);

// //     // 2. Add user IDs only if they don't have existing chats
// //     for (final userId in _selectedUserIds) {
// //       // Check if this user has an existing chat that's already selected
// //       bool hasSelectedChat = _allRecentChats.any(
// //         (chat) =>
// //             chat.userId == userId &&
// //             chat.chatType?.toLowerCase() == 'private' &&
// //             chat.chatId != null &&
// //             _selectedChatIds.contains(chat.chatId!),
// //       );

// //       if (!hasSelectedChat) {
// //         userIds.add(userId);
// //       }
// //     }

// //     widget.onSelectionChanged(chatIds, userIds);
// //   }

// //   void _handleForwardPressed() {
// //     // Validate that we have messages to forward
// //     if (widget.selectedMessageIds == null ||
// //         widget.selectedMessageIds!.isEmpty) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text('No messages selected for forwarding'),
// //           backgroundColor: Colors.red,
// //           behavior: SnackBarBehavior.floating,
// //         ),
// //       );
// //       return;
// //     }

// //     // Validate that we have recipients selected
// //     if (_getUniqueSelectionCount() == 0) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text('Please select at least one chat or contact'),
// //           backgroundColor: Colors.orange,
// //           behavior: SnackBarBehavior.floating,
// //         ),
// //       );
// //       return;
// //     }

// //     List<int> chatIds = [];
// //     List<int> userIds = [];

// //     // 1. Add all selected chats (these have priority)
// //     chatIds.addAll(_selectedChatIds);

// //     // 2. Add user IDs only if they don't have existing chats
// //     for (final userId in _selectedUserIds) {
// //       // Check if this user has an existing chat that's already selected
// //       bool hasSelectedChat = _allRecentChats.any(
// //         (chat) =>
// //             chat.userId == userId &&
// //             chat.chatType?.toLowerCase() == 'private' &&
// //             chat.chatId != null &&
// //             _selectedChatIds.contains(chat.chatId!),
// //       );

// //       if (!hasSelectedChat) {
// //         userIds.add(userId);
// //       }
// //     }

// //     // Call the provided forward callback
// //     if (widget.onForwardPressed != null) {
// //       widget.onForwardPressed!(chatIds, userIds);
// //     } else {
// //       // Fallback to selection changed callback
// //       widget.onSelectionChanged(chatIds, userIds);
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Consumer2<ChatProvider, ContactListProvider>(
// //       builder: (context, chatProvider, contactProvider, child) {
// //         // Rebuild lists when data changes
// //         WidgetsBinding.instance.addPostFrameCallback((_) {
// //           _buildSeparatedLists();
// //         });

// //         return Column(
// //           children: [
// //             // Search Bar
// //             Container(
// //               margin: const EdgeInsets.all(16),
// //               decoration: BoxDecoration(
// //                 color: Colors.white,
// //                 borderRadius: BorderRadius.circular(12),
// //                 boxShadow: [
// //                   BoxShadow(
// //                     color: Colors.black.withValues(alpha: 0.05),
// //                     blurRadius: 8,
// //                     offset: const Offset(0, 2),
// //                   ),
// //                 ],
// //               ),
// //               child: TextField(
// //                 controller: _searchController,
// //                 style: AppTypography.mediumText(context),
// //                 decoration: InputDecoration(
// //                   hintText:
// //                       _currentTabIndex == 0
// //                           ? 'Search recent chats...'
// //                           : 'Search contacts...',
// //                   hintStyle: AppTypography.mediumText(
// //                     context,
// //                   ).copyWith(color: AppColors.textColor.textGreyColor),
// //                   prefixIcon: Icon(
// //                     Icons.search_rounded,
// //                     color: AppColors.appPriSecColor.primaryColor,
// //                     size: 20,
// //                   ),
// //                   border: InputBorder.none,
// //                   contentPadding: const EdgeInsets.symmetric(
// //                     horizontal: 16,
// //                     vertical: 12,
// //                   ),
// //                 ),
// //               ),
// //             ),

// //             // Tab Bar
// //             Container(
// //               margin: const EdgeInsets.symmetric(horizontal: 16),
// //               decoration: BoxDecoration(
// //                 color: AppColors.bgColor.bg1Color,
// //                 borderRadius: BorderRadius.circular(12),
// //               ),
// //               child: TabBar(
// //                 controller: _tabController,
// //                 indicator: BoxDecoration(
// //                   color: AppColors.appPriSecColor.primaryColor,
// //                   borderRadius: BorderRadius.circular(10),
// //                 ),
// //                 indicatorSize: TabBarIndicatorSize.tab,
// //                 labelColor: Colors.white,
// //                 unselectedLabelColor: AppColors.textColor.textGreyColor,
// //                 labelStyle: AppTypography.mediumText(
// //                   context,
// //                 ).copyWith(fontWeight: FontWeight.w600),
// //                 unselectedLabelStyle: AppTypography.mediumText(context),
// //                 tabs: [
// //                   Tab(text: 'Recent Chats (${_allRecentChats.length})'),
// //                   Tab(text: 'Contacts (${_allContacts.length})'),
// //                 ],
// //               ),
// //             ),

// //             const SizedBox(height: 16),

// //             // Selection Counter
// //             if (_getUniqueSelectionCount() > 0)
// //               Container(
// //                 margin: const EdgeInsets.symmetric(horizontal: 16),
// //                 padding: const EdgeInsets.symmetric(
// //                   horizontal: 12,
// //                   vertical: 8,
// //                 ),
// //                 decoration: BoxDecoration(
// //                   color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
// //                   borderRadius: BorderRadius.circular(8),
// //                   border: Border.all(
// //                     color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 
// //                       0.3,
// //                     ),
// //                   ),
// //                 ),
// //                 child: Row(
// //                   children: [
// //                     Icon(
// //                       Icons.check_circle,
// //                       color: AppColors.appPriSecColor.primaryColor,
// //                       size: 16,
// //                     ),
// //                     const SizedBox(width: 8),
// //                     Text(
// //                       '${_getUniqueSelectionCount()} selected',
// //                       style: AppTypography.smallText(context).copyWith(
// //                         color: AppColors.appPriSecColor.primaryColor,
// //                         fontWeight: FontWeight.w600,
// //                       ),
// //                     ),
// //                     const Spacer(),
// //                     GestureDetector(
// //                       onTap: () {
// //                         setState(() {
// //                           _selectedItems.clear();
// //                           _selectedUserIds.clear();
// //                           _selectedChatIds.clear();
// //                           _filterItems();
// //                           _notifySelectionChanged();
// //                         });
// //                       },
// //                       child: Text(
// //                         'Clear All',
// //                         style: AppTypography.smallText(context).copyWith(
// //                           color: AppColors.appPriSecColor.primaryColor,
// //                           fontWeight: FontWeight.w500,
// //                         ),
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),

// //             const SizedBox(height: 8),

// //             // List
// //             Expanded(child: _buildList(chatProvider, contactProvider)),

// //             // Forward Button (show at bottom when items are selected)
// //             if (widget.showForwardButton && _getUniqueSelectionCount() > 0)
// //               _buildForwardButton(),
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   int _getUniqueSelectionCount() {
// //     // Count unique users and groups
// //     Set<int> uniqueSelections = {};

// //     // Add all selected chat IDs (these are unique)
// //     uniqueSelections.addAll(_selectedChatIds);

// //     // Add user IDs that don't have existing chats
// //     for (final userId in _selectedUserIds) {
// //       // Check if this user has an existing chat
// //       bool hasExistingChat = _allRecentChats.any(
// //         (chat) =>
// //             chat.userId == userId && chat.chatType?.toLowerCase() == 'private',
// //       );

// //       if (!hasExistingChat) {
// //         uniqueSelections.add(userId);
// //       }
// //     }

// //     return uniqueSelections.length;
// //   }

// //   Widget _buildForwardButton() {
// //     final hasSelection = _getUniqueSelectionCount() > 0;
// //     final totalSelected = _getUniqueSelectionCount();

// //     return Container(
// //       padding: const EdgeInsets.all(16),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: const BorderRadius.only(
// //           topLeft: Radius.circular(24),
// //           topRight: Radius.circular(24),
// //         ),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.black.withValues(alpha: 0.1),
// //             blurRadius: 20,
// //             offset: const Offset(0, -4),
// //           ),
// //         ],
// //       ),
// //       child: SafeArea(
// //         child: Column(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             // Selection summary
// //             Container(
// //               width: double.infinity,
// //               padding: const EdgeInsets.all(12),
// //               margin: const EdgeInsets.only(bottom: 12),
// //               decoration: BoxDecoration(
// //                 color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
// //                 borderRadius: BorderRadius.circular(8),
// //                 border: Border.all(
// //                   color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.3),
// //                 ),
// //               ),
// //               child: Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Row(
// //                     children: [
// //                       Icon(
// //                         Icons.info_outline,
// //                         color: AppColors.appPriSecColor.primaryColor,
// //                         size: 18,
// //                       ),
// //                       const SizedBox(width: 8),
// //                       Expanded(
// //                         child: Text(
// //                           'Ready to forward to $totalSelected recipient${totalSelected != 1 ? 's' : ''}',
// //                           style: AppTypography.smallText(context).copyWith(
// //                             color: AppColors.appPriSecColor.primaryColor,
// //                             fontWeight: FontWeight.w500,
// //                           ),
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                   if (widget.selectedMessageIds != null &&
// //                       widget.selectedMessageIds!.isNotEmpty) ...[
// //                     const SizedBox(height: 4),
// //                     Text(
// //                       'Forwarding ${widget.selectedMessageIds!.length} message${widget.selectedMessageIds!.length != 1 ? 's' : ''}',
// //                       style: AppTypography.smallText(context).copyWith(
// //                         color: AppColors.appPriSecColor.primaryColor
// //                             .withValues(alpha: 0.8),
// //                         fontSize: 11,
// //                       ),
// //                     ),
// //                   ],
// //                 ],
// //               ),
// //             ),

// //             // Forward Button
// //             AnimatedContainer(
// //               duration: const Duration(milliseconds: 200),
// //               width: double.infinity,
// //               height: 52,
// //               child: ElevatedButton(
// //                 onPressed: hasSelection ? _handleForwardPressed : null,
// //                 style: ElevatedButton.styleFrom(
// //                   backgroundColor:
// //                       hasSelection
// //                           ? AppColors.appPriSecColor.primaryColor
// //                           : AppColors.strokeColor.greyColor,
// //                   foregroundColor: Colors.white,
// //                   elevation: hasSelection ? 4 : 0,
// //                   shadowColor: AppColors.appPriSecColor.primaryColor
// //                       .withValues(alpha: 0.3),
// //                   shape: RoundedRectangleBorder(
// //                     borderRadius: BorderRadius.circular(16),
// //                   ),
// //                 ),
// //                 child: Row(
// //                   mainAxisAlignment: MainAxisAlignment.center,
// //                   children: [
// //                     Icon(Icons.send_rounded, color: Colors.white, size: 20),
// //                     const SizedBox(width: 8),
// //                     Text(
// //                       'Forward Messages',
// //                       style: AppTypography.buttonText(context).copyWith(
// //                         color: Colors.white,
// //                         fontWeight: FontWeight.w600,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildList(
// //     ChatProvider chatProvider,
// //     ContactListProvider contactProvider,
// //   ) {
// //     // Show loading for the appropriate provider
// //     bool isLoading = false;
// //     if (_currentTabIndex == 0 &&
// //         chatProvider.isChatListLoading &&
// //         _allRecentChats.isEmpty) {
// //       isLoading = true;
// //     } else if (_currentTabIndex == 1 &&
// //         contactProvider.isLoading &&
// //         _allContacts.isEmpty) {
// //       isLoading = true;
// //     }

// //     if (isLoading) {
// //       return const Center(child: CircularProgressIndicator());
// //     }

// //     if (_filteredItems.isEmpty) {
// //       return Center(
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             Icon(
// //               _searchQuery.isNotEmpty
// //                   ? Icons.search_off
// //                   : _currentTabIndex == 0
// //                   ? Icons.chat_bubble_outline
// //                   : Icons.contacts_outlined,
// //               size: 64,
// //               color: AppColors.textColor.textGreyColor,
// //             ),
// //             const SizedBox(height: 16),
// //             Text(
// //               _searchQuery.isNotEmpty
// //                   ? 'No results found for "$_searchQuery"'
// //                   : _currentTabIndex == 0
// //                   ? 'No recent chats available'
// //                   : 'No contacts available',
// //               style: AppTypography.h5(context).copyWith(
// //                 color: AppColors.textColor.textGreyColor,
// //                 fontWeight: FontWeight.w500,
// //               ),
// //             ),
// //             if (_searchQuery.isNotEmpty) ...[
// //               const SizedBox(height: 8),
// //               Text(
// //                 'Try searching with different keywords',
// //                 style: AppTypography.mediumText(
// //                   context,
// //                 ).copyWith(color: AppColors.textColor.textGreyColor),
// //                 textAlign: TextAlign.center,
// //               ),
// //             ],
// //           ],
// //         ),
// //       );
// //     }

// //     return ListView.builder(
// //       controller: _scrollController,
// //       padding: const EdgeInsets.symmetric(horizontal: 16),
// //       itemCount:
// //           _filteredItems.length +
// //           ((_currentTabIndex == 0 && chatProvider.isChatListPaginationLoading)
// //               ? 1
// //               : 0),
// //       itemBuilder: (context, index) {
// //         // Show loading indicator at the end for recent chats pagination
// //         if (index >= _filteredItems.length) {
// //           return Container(
// //             padding: const EdgeInsets.all(16),
// //             alignment: Alignment.center,
// //             child: SizedBox(
// //               height: 20,
// //               width: 20,
// //               child: CircularProgressIndicator(
// //                 strokeWidth: 2,
// //                 valueColor: AlwaysStoppedAnimation<Color>(
// //                   AppColors.appPriSecColor.primaryColor,
// //                 ),
// //               ),
// //             ),
// //           );
// //         }

// //         final item = _filteredItems[index];
// //         return _buildListItem(item);
// //       },
// //     );
// //   }

// //   Widget _buildListItem(ForwardItem item) {
// //     final isSelected = _selectedItems.contains(item.id);

// //     return Container(
// //       margin: const EdgeInsets.only(bottom: 8),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(12),
// //         border:
// //             isSelected
// //                 ? Border.all(
// //                   color: AppColors.appPriSecColor.primaryColor,
// //                   width: 2,
// //                 )
// //                 : null,
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.black.withValues(alpha: 0.05),
// //             blurRadius: 8,
// //             offset: const Offset(0, 2),
// //           ),
// //         ],
// //       ),
// //       child: Material(
// //         color: Colors.transparent,
// //         child: InkWell(
// //           borderRadius: BorderRadius.circular(12),
// //           onTap: () => _toggleSelection(item),
// //           child: Padding(
// //             padding: const EdgeInsets.all(12),
// //             child: Row(
// //               children: [
// //                 // Profile Picture / Icon
// //                 Stack(
// //                   children: [
// //                     Container(
// //                       width: 48,
// //                       height: 48,
// //                       decoration: BoxDecoration(
// //                         color: AppColors.appPriSecColor.primaryColor
// //                             .withValues(alpha: 0.1),
// //                         borderRadius: BorderRadius.circular(24),
// //                         image:
// //                             item.profilePic?.isNotEmpty == true
// //                                 ? DecorationImage(
// //                                   image: NetworkImage(item.profilePic!),
// //                                   fit: BoxFit.cover,
// //                                 )
// //                                 : null,
// //                       ),
// //                       child:
// //                           item.profilePic?.isNotEmpty != true
// //                               ? Icon(
// //                                 _getIconForItemType(item.type),
// //                                 color: AppColors.appPriSecColor.primaryColor,
// //                                 size: 24,
// //                               )
// //                               : null,
// //                     ),
// //                     // Online indicator
// //                     if (item.isOnline)
// //                       Positioned(
// //                         right: 0,
// //                         bottom: 0,
// //                         child: Container(
// //                           width: 14,
// //                           height: 14,
// //                           decoration: BoxDecoration(
// //                             color: Colors.green,
// //                             border: Border.all(color: Colors.white, width: 2),
// //                             borderRadius: BorderRadius.circular(7),
// //                           ),
// //                         ),
// //                       ),
// //                   ],
// //                 ),

// //                 const SizedBox(width: 12),

// //                 // Content
// //                 Expanded(
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       Row(
// //                         children: [
// //                           Expanded(
// //                             child: Text(
// //                               item.name,
// //                               style: AppTypography.h5(
// //                                 context,
// //                               ).copyWith(fontWeight: FontWeight.w600),
// //                               overflow: TextOverflow.ellipsis,
// //                             ),
// //                           ),
// //                           // Type indicator
// //                           _buildTypeIndicator(item.type),
// //                         ],
// //                       ),
// //                       if (item.lastMessage?.isNotEmpty == true) ...[
// //                         const SizedBox(height: 4),
// //                         Text(
// //                           item.lastMessage!,
// //                           style: AppTypography.smallText(
// //                             context,
// //                           ).copyWith(color: AppColors.textColor.textGreyColor),
// //                           maxLines: 1,
// //                           overflow: TextOverflow.ellipsis,
// //                         ),
// //                       ],
// //                     ],
// //                   ),
// //                 ),

// //                 const SizedBox(width: 8),

// //                 // Selection indicator and unseen count
// //                 Column(
// //                   children: [
// //                     // Selection checkbox
// //                     Container(
// //                       width: 24,
// //                       height: 24,
// //                       decoration: BoxDecoration(
// //                         color:
// //                             isSelected
// //                                 ? AppColors.appPriSecColor.primaryColor
// //                                 : Colors.transparent,
// //                         border: Border.all(
// //                           color:
// //                               isSelected
// //                                   ? AppColors.appPriSecColor.primaryColor
// //                                   : AppColors.strokeColor.greyColor,
// //                           width: 2,
// //                         ),
// //                         borderRadius: BorderRadius.circular(12),
// //                       ),
// //                       child:
// //                           isSelected
// //                               ? const Icon(
// //                                 Icons.check,
// //                                 color: Colors.white,
// //                                 size: 16,
// //                               )
// //                               : null,
// //                     ),

// //                     // Unseen count (only for recent chats)
// //                     if (item.unseenCount > 0 &&
// //                         item.type == ForwardItemType.recentChat) ...[
// //                       const SizedBox(height: 4),
// //                       Container(
// //                         padding: const EdgeInsets.symmetric(
// //                           horizontal: 6,
// //                           vertical: 2,
// //                         ),
// //                         decoration: BoxDecoration(
// //                           color: AppColors.appPriSecColor.primaryColor,
// //                           borderRadius: BorderRadius.circular(10),
// //                         ),
// //                         child: Text(
// //                           item.unseenCount.toString(),
// //                           style: AppTypography.smallText(context).copyWith(
// //                             color: Colors.white,
// //                             fontWeight: FontWeight.w600,
// //                             fontSize: 10,
// //                           ),
// //                         ),
// //                       ),
// //                     ],
// //                   ],
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   IconData _getIconForItemType(ForwardItemType type) {
// //     switch (type) {
// //       case ForwardItemType.recentChat:
// //         return Icons.chat_bubble_outline;
// //       case ForwardItemType.contact:
// //         return Icons.person_outline;
// //     }
// //   }

// //   Widget _buildTypeIndicator(ForwardItemType type) {
// //     String text;
// //     Color color;

// //     switch (type) {
// //       case ForwardItemType.recentChat:
// //         text = 'Recent';
// //         color = Colors.blue;
// //         break;
// //       case ForwardItemType.contact:
// //         text = 'Contact';
// //         color = Colors.green;
// //         break;
// //     }

// //     return Container(
// //       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
// //       decoration: BoxDecoration(
// //         color: color.withValues(alpha: 0.1),
// //         borderRadius: BorderRadius.circular(4),
// //       ),
// //       child: Text(
// //         text,
// //         style: AppTypography.smallText(
// //           context,
// //         ).copyWith(color: color, fontWeight: FontWeight.w500, fontSize: 10),
// //       ),
// //     );
// //   }
// // }

// // // Contact detail model for type safety
// // class ContactDetail {
// //   final String? name;
// //   final String? number;
// //   final int? userId;

// //   ContactDetail({this.name, this.number, this.userId});
// // }

// // /*
// // USAGE EXAMPLE:

// // // 1. Basic Usage in your ContactListScreen
// // Widget _buildForwardMode() {
// //   return Scaffold(
// //     appBar: AppBar(title: Text('Forward Messages')),
// //     body: ForwardListManager(
// //       showForwardButton: true,
// //       selectedMessageIds: widget.selectedMessageIds,
// //       fromChatId: widget.fromChatId,
// //       onSelectionChanged: (chatIds, userIds) {
// //         debugPrint('Selection: chats=$chatIds, users=$userIds');
// //       },
// //       onForwardPressed: (chatIds, userIds) {
// //         // Handle forward action
// //         _performForward(chatIds, userIds);
// //       },
// //       onItemTap: (item) {
// //         debugPrint('Tapped: ${item.name}');
// //       },
// //     ),
// //   );
// // }

// // // 2. Navigation example
// // Navigator.push(
// //   context,
// //   MaterialPageRoute(
// //     builder: (context) => ContactListScreen(
// //       isForwardMode: true,
// //       selectedMessageIds: [123, 456, 789],
// //       fromChatId: currentChatId,
// //     ),
// //   ),
// // );

// // // 3. Key Features:
// // // ✅ Recent Chats Tab - Shows all existing chats with pagination
// // // ✅ Contacts Tab - Shows contacts without existing chats
// // // ✅ Global Selection - Selected items persist across tab switches
// // // ✅ Smart Name Display - fullName → userName → "Unknown User"
// // // ✅ Proper Filtering - Excludes current chat and existing chat users from contacts
// // // ✅ Online Status - Shows for both recent chats and contacts
// // // ✅ Pagination - Works only on Recent Chats tab
// // // ✅ Tab Counters - Shows count of items in each tab
// // // ✅ Search - Different placeholders for each tab
// // */

// forward_list_manager.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

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
          chat.records?.isNotEmpty == true
              ? chat.records!.first.messages?.isNotEmpty == true
                  ? chat.records!.first.messages!.first.messageContent
                  : null
              : null,
      lastMessageTime:
          chat.records?.isNotEmpty == true
              ? chat.records!.first.messages?.isNotEmpty == true
                  ? chat.records!.first.messages!.first.createdAt
                  : null
              : null,
      unseenCount: record?.unseenCount ?? 0,
      chatType: record?.chatType,
    );
  }

  factory ForwardItem.fromContact(ContactDetail contact, bool isOnline) {
    return ForwardItem(
      id: 'contact_${contact.userId ?? 0}',
      name: contact.name ?? 'Unknown Contact',
      profilePic: null,
      type: ForwardItemType.contact,
      chatId: null,
      userId: contact.userId,
      lastMessage: null,
      lastMessageTime: null,
      isOnline: isOnline,
      unseenCount: 0,
    );
  }

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

class ForwardListManager extends StatefulWidget {
  final Function(List<int> chatIds, List<int> userIds) onSelectionChanged;
  final Function(ForwardItem item) onItemTap;
  final Function(List<int> chatIds, List<int> userIds)? onForwardPressed;
  final bool showForwardButton;
  final List<int>? selectedMessageIds;
  final int? fromChatId;

  const ForwardListManager({
    super.key,
    required this.onSelectionChanged,
    required this.onItemTap,
    this.onForwardPressed,
    this.showForwardButton = true,
    this.selectedMessageIds,
    this.fromChatId,
  });

  @override
  State<ForwardListManager> createState() => _ForwardListManagerState();
}

class _ForwardListManagerState extends State<ForwardListManager>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ForwardItem> _allRecentChats = [];
  List<ForwardItem> _allContacts = [];
  List<ForwardItem> _filteredItems = [];
  final Set<String> _selectedItems = {}; // Global selection across tabs
  String _searchQuery = '';

  // Track current tab
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

    if (chatProvider.chatListData.chats.isEmpty) {
      await chatProvider.emitChatList();
    }

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

    // 1. Build recent chats list
    for (final chat in chatProvider.chatListData.chats) {
      if (chat.records?.isNotEmpty == true) {
        final record = chat.records!.first;

        if (widget.fromChatId != null && record.chatId == widget.fromChatId) {
          continue;
        }

        if ((record.chatType?.toLowerCase() == 'private') &&
            chat.peerUserData?.userId != null) {
          existingChatUserIds.add(chat.peerUserData!.userId!);
        }

        recentChats.add(ForwardItem.fromChatList(chat));
      }
    }

    // 2. Build contacts list
    Set<String> processedNumbers = {};
    for (final contact in contactProvider.chatContacts) {
      final userId = int.tryParse(contact.userId ?? '');

      String? phoneNumber;
      if (contact.phoneNumber.isNotEmpty == true) {
        phoneNumber = contact.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      }

      if (phoneNumber != null && processedNumbers.contains(phoneNumber)) {
        continue;
      }

      if (userId != null && phoneNumber != null) {
        processedNumbers.add(phoneNumber);
        final isOnline = chatProvider.isUserOnline(userId);
        contacts.add(
          ForwardItem.fromContact(
            ContactDetail(
              name: contact.name,
              number: phoneNumber,
              userId: userId,
            ),
            isOnline,
          ),
        );
      }
    }

    setState(() {
      _allRecentChats = recentChats;
      _allContacts = contacts;
      _filterItems();
    });
  }

  void _filterItems() {
    List<ForwardItem> sourceList = [];

    switch (_currentTabIndex) {
      case 0: // Recent Chats
        sourceList = _allRecentChats;
        break;
      case 1: // Contacts
        sourceList = _allContacts;
        break;
    }

    List<ForwardItem> filtered = sourceList;
    if (_searchQuery.isNotEmpty) {
      filtered =
          sourceList
              .where((item) => item.name.toLowerCase().contains(_searchQuery))
              .toList();
    }

    filtered =
        filtered.map((item) {
          return item.copyWith(isSelected: _selectedItems.contains(item.id));
        }).toList();

    setState(() {
      _filteredItems = filtered;
    });
  }

  void _toggleSelection(ForwardItem item) {
    setState(() {
      bool isCurrentlySelected = _selectedItems.contains(item.id);

      if (isCurrentlySelected) {
        _selectedItems.remove(item.id);
        _removeCorrespondingUserSelection(item);
      } else {
        _selectedItems.add(item.id);
        _addCorrespondingUserSelection(item);
      }

      _filterItems();
      _notifySelectionChanged();
    });
  }

  void _removeCorrespondingUserSelection(ForwardItem selectedItem) {
    if (selectedItem.userId == null) return;

    if (selectedItem.type == ForwardItemType.recentChat) {
      final correspondingContact = _allContacts.where(
        (contact) => contact.userId == selectedItem.userId,
      );
      for (final contact in correspondingContact) {
        _selectedItems.remove(contact.id);
      }
    } else if (selectedItem.type == ForwardItemType.contact) {
      final correspondingChats = _allRecentChats.where(
        (chat) =>
            chat.userId == selectedItem.userId &&
            chat.chatType?.toLowerCase() == 'private',
      );
      for (final chat in correspondingChats) {
        _selectedItems.remove(chat.id);
      }
    }
  }

  void _addCorrespondingUserSelection(ForwardItem selectedItem) {
    if (selectedItem.userId == null) return;

    if (selectedItem.type == ForwardItemType.recentChat) {
      final correspondingContact = _allContacts.where(
        (contact) => contact.userId == selectedItem.userId,
      );
      for (final contact in correspondingContact) {
        _selectedItems.add(contact.id);
      }
    } else if (selectedItem.type == ForwardItemType.contact) {
      final correspondingChats = _allRecentChats.where(
        (chat) =>
            chat.userId == selectedItem.userId &&
            chat.chatType?.toLowerCase() == 'private',
      );
      for (final chat in correspondingChats) {
        _selectedItems.add(chat.id);
      }
    }
  }

  // ✅ FIXED: Get unique selection count without duplicates
  int _getUniqueSelectionCount() {
    Set<String> uniqueSelections = {};

    for (final itemId in _selectedItems) {
      ForwardItem? item;

      // Find the item in either list
      try {
        item = _allRecentChats.firstWhere((item) => item.id == itemId);
      } catch (e) {
        try {
          item = _allContacts.firstWhere((item) => item.id == itemId);
        } catch (e) {
          continue;
        }
      }

      // For groups, use chatId as unique identifier
      if (item.chatType?.toLowerCase() == 'group' && item.chatId != null) {
        uniqueSelections.add('group_${item.chatId}');
      }
      // For users (both recent chats and contacts), use userId as unique identifier
      else if (item.userId != null) {
        uniqueSelections.add('user_${item.userId}');
      }
      // Fallback for items without userId or chatId
      else {
        uniqueSelections.add(item.id);
      }
    }

    return uniqueSelections.length;
  }

  void _notifySelectionChanged() {
    List<int> chatIds = [];
    List<int> userIds = [];

    // Use a set to track processed users to avoid duplicates
    Set<int> processedUserIds = {};

    for (final itemId in _selectedItems) {
      ForwardItem? item;

      try {
        item = _allRecentChats.firstWhere((item) => item.id == itemId);
      } catch (e) {
        try {
          item = _allContacts.firstWhere((item) => item.id == itemId);
        } catch (e) {
          continue;
        }
      }

      // For groups or existing chats, add chatId
      if (item.chatId != null) {
        chatIds.add(item.chatId!);
      }
      // For contacts without existing chats, add userId (but only once)
      else if (item.userId != null &&
          !processedUserIds.contains(item.userId!)) {
        userIds.add(item.userId!);
        processedUserIds.add(item.userId!);
      }
    }

    widget.onSelectionChanged(chatIds, userIds);
  }

  void _handleForwardPressed() {
    if (widget.selectedMessageIds == null ||
        widget.selectedMessageIds!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppString.noMessagesSelectedForForwarding),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_getUniqueSelectionCount() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppString.pleaseSelectAtLeastOneChatOrContact),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    List<int> chatIds = [];
    List<int> userIds = [];
    Set<int> processedUserIds = {};

    for (final itemId in _selectedItems) {
      ForwardItem? item;

      try {
        item = _allRecentChats.firstWhere((item) => item.id == itemId);
      } catch (e) {
        try {
          item = _allContacts.firstWhere((item) => item.id == itemId);
        } catch (e) {
          continue;
        }
      }

      if (item.chatId != null) {
        chatIds.add(item.chatId!);
      } else if (item.userId != null &&
          !processedUserIds.contains(item.userId!)) {
        userIds.add(item.userId!);
        processedUserIds.add(item.userId!);
      }
    }

    if (widget.onForwardPressed != null) {
      widget.onForwardPressed!(chatIds, userIds);
    } else {
      widget.onSelectionChanged(chatIds, userIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, ContactListProvider>(
      builder: (context, chatProvider, contactProvider, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _buildSeparatedLists();
        });

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
                  hintText:
                      _currentTabIndex == 0
                          ? 'Search recent chats...'
                          : 'Search contacts...',
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
                  Tab(text: 'Contacts (${_allContacts.length})'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Selection Counter - ✅ Now uses unique count
            if (_getUniqueSelectionCount() > 0)
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
                      '${_getUniqueSelectionCount()} selected',
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
            Expanded(child: _buildList(chatProvider, contactProvider)),

            // Forward Button - ✅ Now uses unique count
            if (widget.showForwardButton && _getUniqueSelectionCount() > 0)
              _buildForwardButton(),
          ],
        );
      },
    );
  }

  Widget _buildForwardButton() {
    final hasSelection = _getUniqueSelectionCount() > 0;
    final totalSelected =
        _getUniqueSelectionCount(); // ✅ Now shows unique count

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.appPriSecColor.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ready to forward to $totalSelected recipient${totalSelected != 1 ? 's' : ''}',
                          style: AppTypography.smallText(context).copyWith(
                            color: AppColors.appPriSecColor.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.selectedMessageIds != null &&
                      widget.selectedMessageIds!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Forwarding ${widget.selectedMessageIds!.length} message${widget.selectedMessageIds!.length != 1 ? 's' : ''}',
                      style: AppTypography.smallText(context).copyWith(
                        color: AppColors.appPriSecColor.primaryColor
                            .withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Forward Button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: hasSelection ? _handleForwardPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasSelection
                          ? AppColors.appPriSecColor.primaryColor
                          : AppColors.strokeColor.greyColor,
                  foregroundColor: Colors.white,
                  elevation: hasSelection ? 4 : 0,
                  shadowColor: AppColors.appPriSecColor.primaryColor
                      .withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Forward Messages',
                      style: AppTypography.buttonText(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    ChatProvider chatProvider,
    ContactListProvider contactProvider,
  ) {
    bool isLoading = false;
    if (_currentTabIndex == 0 &&
        chatProvider.isChatListLoading &&
        _allRecentChats.isEmpty) {
      isLoading = true;
    } else if (_currentTabIndex == 1 &&
        contactProvider.isLoading &&
        _allContacts.isEmpty) {
      isLoading = true;
    }

    if (isLoading) {
      return Center(child: commonLoading());
    }

    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : _currentTabIndex == 0
                  ? Icons.chat_bubble_outline
                  : Icons.contacts_outlined,
              size: 64,
              color: AppColors.textColor.textGreyColor,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results found for "$_searchQuery"'
                  : _currentTabIndex == 0
                  ? 'No recent chats available'
                  : 'No contacts available',
              style: AppTypography.h5(context).copyWith(
                color: AppColors.textColor.textGreyColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                style: AppTypography.mediumText(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount:
          _filteredItems.length +
          ((_currentTabIndex == 0 && chatProvider.isChatListPaginationLoading)
              ? 1
              : 0),
      itemBuilder: (context, index) {
        if (index >= _filteredItems.length) {
          return Container(
            padding: EdgeInsets.all(16),
            alignment: Alignment.center,
            child: SizedBox(height: 20, width: 20, child: commonLoading()),
          );
        }

        final item = _filteredItems[index];
        return _buildListItem(item);
      },
    );
  }

  Widget _buildListItem(ForwardItem item) {
    final isSelected = _selectedItems.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _toggleSelection(item),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Profile Picture / Icon
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.appPriSecColor.primaryColor
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        image:
                            item.profilePic?.isNotEmpty == true
                                ? DecorationImage(
                                  image: NetworkImage(item.profilePic!),
                                  fit: BoxFit.cover,
                                )
                                : null,
                      ),
                      child:
                          item.profilePic?.isNotEmpty != true
                              ? Icon(
                                _getIconForItemType(item.type),
                                color: AppColors.appPriSecColor.primaryColor,
                                size: 24,
                              )
                              : null,
                    ),
                    // Online indicator
                    if (item.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: AppTypography.h5(
                                context,
                              ).copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Type indicator
                          _buildTypeIndicator(item.type),
                        ],
                      ),
                      if (item.lastMessage?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.lastMessage!,
                          style: AppTypography.smallText(
                            context,
                          ).copyWith(color: AppColors.textColor.textGreyColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Selection indicator and unseen count
                Column(
                  children: [
                    // Selection checkbox
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.appPriSecColor.primaryColor
                                : Colors.transparent,
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.appPriSecColor.primaryColor
                                  : AppColors.strokeColor.greyColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          isSelected
                              ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                              : null,
                    ),

                    // Unseen count (only for recent chats)
                    if (item.unseenCount > 0 &&
                        item.type == ForwardItemType.recentChat) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.appPriSecColor.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.unseenCount.toString(),
                          style: AppTypography.smallText(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForItemType(ForwardItemType type) {
    switch (type) {
      case ForwardItemType.recentChat:
        return Icons.chat_bubble_outline;
      case ForwardItemType.contact:
        return Icons.person_outline;
    }
  }

  Widget _buildTypeIndicator(ForwardItemType type) {
    String text;
    Color color;

    switch (type) {
      case ForwardItemType.recentChat:
        text = 'Recent';
        color = Colors.blue;
        break;
      case ForwardItemType.contact:
        text = 'Contact';
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTypography.smallText(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w500, fontSize: 10),
      ),
    );
  }
}

// Contact detail model for type safety
class ContactDetail {
  final String? name;
  final String? number;
  final int? userId;

  ContactDetail({this.name, this.number, this.userId});
}
