import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

class ChatSearchWidget extends StatefulWidget {
  final Function(
    int chatId,
    PeerUserData peerUser, {
    String? chatType,
    String? groupName,
    String? groupIcon,
    String? groupDescription,
  })
  onChatTap;

  const ChatSearchWidget({super.key, required this.onChatTap});

  @override
  State<ChatSearchWidget> createState() => _ChatSearchWidgetState();
}

class _ChatSearchWidgetState extends State<ChatSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Set new timer for debouncing
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      if (query.isNotEmpty) {
        chatProvider.searchChats(query);
      } else {
        chatProvider.clearSearch();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.clearSearch();
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, ProjectConfigProvider>(
      builder: (context, chatProvider, configProvider, _) {
        return Column(
          children: [
            // Search Bar
            Container(
              margin: SizeConfig.getPaddingSymmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color:
                      chatProvider.isSearching
                          ? AppColors.appPriSecColor.primaryColor
                          : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: AppString.searchChats,
                  hintStyle: AppTypography.smallText(
                    context,
                  ).copyWith(color: Colors.grey[600]),
                  prefixIcon: Icon(
                    Icons.search,
                    color:
                        chatProvider.isSearching
                            ? AppColors.appPriSecColor.primaryColor
                            : Colors.grey[600],
                  ),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600]),
                            onPressed: _clearSearch,
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: SizeConfig.getPaddingSymmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    chatProvider.searchChats(value.trim());
                  }
                },
              ),
            ),

            // Search Results or Regular Chat List
            Expanded(
              child:
                  chatProvider.isSearching
                      ? _buildSearchResults(chatProvider, configProvider)
                      : Container(), // Return empty container when not searching
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(
    ChatProvider chatProvider,
    ProjectConfigProvider configProvider,
  ) {
    // Loading state
    if (chatProvider.isSearchLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            commonLoading(),
            SizedBox(height: 16),
            Text(AppString.searchingChats),
          ],
        ),
      );
    }

    final searchResults = chatProvider.searchResults.chats;

    // Empty results
    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              chatProvider.currentSearchQuery.isNotEmpty
                  ? 'No chats found for "${chatProvider.currentSearchQuery}"'
                  : 'No search results',
              textAlign: TextAlign.center,
              style: AppTypography.h4(
                context,
              ).copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              AppString.trySearchingWithDifferentKeywords,
              style: AppTypography.smallText(
                context,
              ).copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Search Results List
    return Column(
      children: [
        // Results header
        Container(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 16,
                color: AppColors.appPriSecColor.primaryColor,
              ),
              SizedBox(width: 8),
              Text(
                AppString.nResultsFoundPlural('${searchResults.length}'),
                style: AppTypography.smallText(context).copyWith(
                  color: AppColors.appPriSecColor.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Results list
        Expanded(
          child: ListView.separated(
            itemCount: searchResults.length,
            separatorBuilder: (context, index) {
              return Divider(color: AppColors.shadowColor.cE9E9E9);
            },
            itemBuilder: (context, index) {
              final chat = searchResults[index];
              return _buildSearchResultItem(chat, configProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultItem(
    dynamic chat,
    ProjectConfigProvider configProvider,
  ) {
    // Handle potential null values safely
    final peer = chat.peerUserData ?? PeerUserData();
    final record =
        chat.records?.isNotEmpty == true ? chat.records!.first : null;
    final lastMessage =
        record?.messages?.isNotEmpty == true ? record!.messages!.first : null;
    final chatType = record?.chatType ?? 'Private';
    final isGroupChat = chatType.toLowerCase() == 'group';

    // Get display name using the same logic as regular chat list
    final String displayName =
        isGroupChat
            ? _getGroupDisplayName(record, peer)
            : ContactNameService.instance.getDisplayName(
              userId: peer.userId,
              userFullName: peer.fullName,
              userName: peer.userName,
              userEmail: peer.email,
              configProvider: configProvider,
            );

    final String profilePic = _getProfilePic(isGroupChat, record, peer);

    return InkWell(
      onTap: () {
        if (record?.chatId != null) {
          // Close search and navigate to chat
          _clearSearch();

          widget.onChatTap(
            record!.chatId!,
            peer,
            chatType: chatType,
            groupName: isGroupChat ? displayName : null,
            groupIcon: isGroupChat ? record.groupIcon : null,
            groupDescription: isGroupChat ? record.groupDescription : null,
          );
        }
      },
      child: Container(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 17, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              height: SizeConfig.sizedBoxHeight(50),
              width: SizeConfig.sizedBoxWidth(50),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(55),
                border: Border.all(color: AppColors.strokeColor.greyColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(55),
                child: _buildAvatar(profilePic, isGroupChat),
              ),
            ),

            SizedBox(width: SizeConfig.width(3)),

            // Chat Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chat name with search highlight
                  Row(
                    children: [
                      Expanded(
                        child: _buildHighlightedText(
                          displayName,
                          Provider.of<ChatProvider>(
                            context,
                            listen: false,
                          ).currentSearchQuery,
                          style: AppTypography.h4(
                            context,
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      // Chat type indicator
                      if (isGroupChat)
                        Icon(Icons.group, size: 16, color: Colors.grey[600]),
                    ],
                  ),

                  SizedBox(height: 4),

                  // Last message preview
                  if (lastMessage != null)
                    Text(
                      _getMessagePreview(lastMessage),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.smallText(
                        context,
                      ).copyWith(color: AppColors.textColor.textGreyColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build highlighted text for search results
  Widget _buildHighlightedText(
    String text,
    String searchQuery, {
    required TextStyle style,
  }) {
    if (searchQuery.isEmpty) {
      return Text(text, style: style);
    }

    final queryLower = searchQuery.toLowerCase();
    final textLower = text.toLowerCase();
    final index = textLower.indexOf(queryLower);

    if (index == -1) {
      return Text(text, style: style);
    }

    // Split text into highlighted and non-highlighted parts
    final beforeMatch = text.substring(0, index);
    final match = text.substring(index, index + searchQuery.length);
    final afterMatch = text.substring(index + searchQuery.length);

    return RichText(
      text: TextSpan(
        children: [
          if (beforeMatch.isNotEmpty) TextSpan(text: beforeMatch, style: style),
          TextSpan(
            text: match,
            style: style.copyWith(
              backgroundColor: AppColors.appPriSecColor.primaryColor.withValues(
                alpha: 0.3,
              ),
              fontWeight: FontWeight.bold,
            ),
          ),
          if (afterMatch.isNotEmpty) TextSpan(text: afterMatch, style: style),
        ],
      ),
    );
  }

  /// Group display name logic - same as main chat list
  String _getGroupDisplayName(Records? record, PeerUserData? peer) {
    if (record?.groupName != null && record!.groupName!.trim().isNotEmpty) {
      return record.groupName!;
    }
    if (peer?.fullName != null && peer!.fullName!.trim().isNotEmpty) {
      return AppString.nameWithGroupSuffix(peer.fullName!);
    }
    if (peer?.userName != null && peer!.userName!.trim().isNotEmpty) {
      return AppString.nameWithGroupSuffix(peer.userName!);
    }
    return AppString.groupChat;
  }

  /// Get profile picture URL - same as main chat list
  String _getProfilePic(bool isGroupChat, Records? record, PeerUserData? peer) {
    if (isGroupChat) {
      if (record?.groupIcon != null && record!.groupIcon!.isNotEmpty) {
        return record.groupIcon!;
      }
      return peer?.profilePic ?? '';
    } else {
      return peer?.profilePic ?? '';
    }
  }

  /// Build avatar widget - same as main chat list
  Widget _buildAvatar(String profilePic, bool isGroupChat) {
    if (profilePic.isNotEmpty) {
      return Image.network(
        profilePic,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(AppAssets.defaultUser, fit: BoxFit.cover);
        },
      );
    } else {
      return Image.asset(AppAssets.defaultUser, fit: BoxFit.cover);
    }
  }

  /// Get message preview text
  String _getMessagePreview(Messages message) {
    switch (message.messageType?.toLowerCase()) {
      case 'image':
        return AppString.photoEmoji;
      case 'video':
        return AppString.videoEmoji;
      case 'document':
      case 'file':
        return AppString.documentEmoji;
      case 'location':
        return AppString.locationEmoji;
      case 'audio':
        return AppString.audioEmoji;
      case 'gif':
        return AppString.gifFilmEmoji;
      default:
        return message.messageContent ?? '';
    }
  }
}
