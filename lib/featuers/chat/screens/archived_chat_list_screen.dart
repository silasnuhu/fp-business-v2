import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/services/socket/socket_event_controller.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
import 'package:whoxa/featuers/chat/provider/archive_chat_provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/services/call_display_service.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';

class ArchivedChatListScreen extends StatefulWidget {
  final Function(
    int chatId,
    PeerUserData peerUser, {
    String? chatType,
    String? groupName,
    String? groupIcon,
    String? groupDescription,
  })
  onChatTap;

  const ArchivedChatListScreen({super.key, required this.onChatTap});

  @override
  State<ArchivedChatListScreen> createState() => _ArchivedChatListScreenState();
}

class _ArchivedChatListScreenState extends State<ArchivedChatListScreen> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final archiveChatProvider = Provider.of<ArchiveChatProvider>(
      context,
      listen: false,
    );
    archiveChatProvider.fetchArchivedChats();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingMore) {
      _loadMoreArchivedChats();
    }
  }

  Future<void> _loadMoreArchivedChats() async {
    final archiveChatProvider = Provider.of<ArchiveChatProvider>(
      context,
      listen: false,
    );

    if (!archiveChatProvider.hasMoreData ||
        archiveChatProvider.isLoading ||
        _isLoadingMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await archiveChatProvider.loadMoreArchivedChats();
    } catch (e) {
      debugPrint('Error loading more archived chats: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          shape: Border(
            bottom: BorderSide(color: AppThemeManage.appTheme.borderColor),
          ),
          backgroundColor: AppColors.transparent,
          systemOverlayStyle: systemUI(),
          flexibleSpace: flexibleSpace(),
          titleSpacing: 0,
          leading: Padding(
            padding: SizeConfig.getPadding(12),
            child: customeBackArrowBalck(context),
          ),
          title: Text(
            AppString.homeScreenString.archivelist,
            style: AppTypography.h220(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: Consumer3<ArchiveChatProvider, SocketEventController, ChatProvider>(
        builder: (
          context,
          archiveChatProvider,
          socketEventController,
          chatProvider,
          _,
        ) {
          final archivedChats = archiveChatProvider.archivedChats;
          final isLoading = archiveChatProvider.isLoading;
          final hasMoreData = archiveChatProvider.hasMoreData;

          if (isLoading && archivedChats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  commonLoading(),
                  SizedBox(height: 16),
                  Text(AppString.loadingArchivedChats),
                ],
              ),
            );
          }

          if (archivedChats.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    AppAssets.emptyDataIcons.emptyarchive,
                    height: SizeConfig.sizedBoxHeight(187),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppString.emptyDataString.noarchivedchats,
                    style: AppTypography.innerText16(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppString
                        .emptyDataString
                        .whenYouArchiveChatsTheyllAppearHere,
                    style: AppTypography.smallText(
                      context,
                    ).copyWith(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Pagination info
              // if (archiveChatProvider.pagination != null)
              //   Container(
              //     padding: const EdgeInsets.symmetric(
              //       horizontal: 16,
              //       vertical: 8,
              //     ),
              //     color: Colors.grey[50],
              //     child: Row(
              //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //       children: [
              //         Text(
              //           'Page ${archiveChatProvider.pagination!.currentPage} of ${archiveChatProvider.pagination!.totalPages}',
              //           style: AppTypography.smallText(
              //             context,
              //           ).copyWith(color: Colors.grey[600]),
              //         ),
              //         Text(
              //           '${archivedChats.length} archived chats',
              //           style: AppTypography.smallText(
              //             context,
              //           ).copyWith(color: Colors.grey[600]),
              //         ),
              //       ],
              //     ),
              //   ),
              SizedBox(height: SizeConfig.height(1)),

              // Archived chats list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    archiveChatProvider.clearArchivedChats();
                    await archiveChatProvider.fetchArchivedChats();
                  },
                  color: AppColors.appPriSecColor.primaryColor,
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount:
                        archivedChats.length +
                        (isLoading && hasMoreData ? 1 : 0),
                    physics: const AlwaysScrollableScrollPhysics(),
                    separatorBuilder: (context, index) {
                      if (index >= archivedChats.length) {
                        return const SizedBox.shrink();
                      }
                      return Divider(color: AppColors.shadowColor.cE9E9E9);
                    },
                    itemBuilder: (context, index) {
                      if (index >= archivedChats.length) {
                        return _buildPaginationLoader();
                      }

                      final chat = archivedChats[index];
                      return _buildArchivedChatItem(
                        chat,
                        archiveChatProvider,
                        socketEventController,
                        chatProvider,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaginationLoader() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 20, height: 20, child: commonLoading()),
          const SizedBox(width: 12),
          Text(
            AppString.loadingMoreArchivedChats,
            style: AppTypography.smallText(
              context,
            ).copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedChatItem(
    Chats chat,
    ArchiveChatProvider archiveChatProvider,
    SocketEventController socketEventController,
    ChatProvider chatProvider,
  ) {
    final peer = chat.peerUserData ?? PeerUserData();
    final record =
        chat.records?.isNotEmpty == true ? chat.records!.first : null;
    final lastMessage =
        record?.messages?.isNotEmpty == true ? record!.messages!.first : null;
    final unseenCount = record?.unseenCount ?? 0;
    final chatType = record?.chatType ?? 'Private';
    final isGroupChat = chatType.toLowerCase() == 'group';

    final String displayName = _getDisplayName(chatType, record, peer);
    final String profilePic = _getProfilePic(isGroupChat, record, peer);

    int userId = peer.userId ?? 0;
    int chatId = record?.chatId ?? 0;
    // Check if user is online (only for individual chats)
    final isOnline = !isGroupChat && socketEventController.isUserOnline(userId);

    return InkWell(
      onTap: () {
        if (record?.chatId != null) {
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
      onLongPress: () {
        _showArchivedChatOptions(
          context,
          chatId,
          displayName,
          archiveChatProvider,
        );
      },
      child: Container(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 17, vertical: 8),
        child: Row(
          children: [
            // Container(
            //   height: SizeConfig.sizedBoxHeight(50),
            //   width: SizeConfig.sizedBoxWidth(50),
            //   decoration: BoxDecoration(
            //     borderRadius: BorderRadius.circular(55),
            //     border: Border.all(color: AppColors.strokeColor.greyColor),
            //   ),
            //   child: ClipRRect(
            //     borderRadius: BorderRadius.circular(55),
            //     child: _buildAvatar(profilePic, isGroupChat),
            //   ),
            // ),
            Stack(
              children: [
                // User/Group avatar — shared widget so a missing / invalid /
                // "not-found" profile pic falls back to the same name initials
                // the rest of the app shows, instead of a blank grey icon.
                CommonProfileAvatar(
                  imageUrl: profilePic,
                  name: displayName,
                  radius: SizeConfig.sizedBoxHeight(25),
                  isGroup: isGroupChat,
                ),

                // Group indicator or online status
                if (isGroupChat)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.appPriSecColor.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemeManage.appTheme.borderColor,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.group,
                        color: AppThemeManage.appTheme.scaffoldBackColor,
                        size: 12,
                      ),
                    ),
                  )
                else if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemeManage.appTheme.borderColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(width: SizeConfig.width(3)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: UserNameWithBadge(
                          // A group is not a user: no blue tick.
                          userId: isGroupChat ? null : peer.userId,
                          name: displayName,
                          style: AppTypography.innerText14(
                            context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        formatTime(lastMessage?.createdAt),
                        style: AppTypography.innerText12Mediu(
                          context,
                        ).copyWith(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMessagePreview(
                          context,
                          lastMessage,
                          record,
                          chatProvider,
                        ),
                      ),
                      if (unseenCount > 0)
                        chatCountContainer(context, count: unseenCount),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDisplayName(String? chatType, Records? record, PeerUserData peer) {
    if (chatType?.toLowerCase() == 'group') {
      return record?.groupName ?? 'Group Chat';
    } else {
      // 🎯 FIXED: Use ContactNameService to match regular chat list behavior
      final configProvider = Provider.of<ProjectConfigProvider>(
        context,
        listen: false,
      );
      return ContactNameService.instance.getDisplayNameStable(
        userId: peer.userId,
        configProvider: configProvider,
        contextFullName: peer.fullName, // Pass the full name from peer data
        firstName: peer.firstName,
        lastName: peer.lastName,
      );
    }
  }

  String _getProfilePic(bool isGroupChat, Records? record, PeerUserData peer) {
    if (isGroupChat) {
      return record?.groupIcon ?? '';
    } else {
      return peer.profilePic ?? '';
    }
  }

  String formatTime(String? time) {
    if (time == null) return "";

    try {
      final dateTime = DateTime.parse(time);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return DateFormat('MMM d, yyyy').format(dateTime);
      } else if (difference.inDays > 0) {
        return AppString.trParams(
          difference.inDays == 1 ? '{n} day ago' : '{n} days ago',
          {'n': '${difference.inDays}'},
        );
      } else if (difference.inHours > 0) {
        return AppString.trParams(
          difference.inHours == 1 ? '{n} hr ago' : '{n} hrs ago',
          {'n': '${difference.inHours}'},
        );
      } else if (difference.inMinutes > 0) {
        return AppString.nMinAgo('${difference.inMinutes}');
      } else {
        return AppString.justNow;
      }
    } catch (e) {
      log('Error formatting time: $e');
      return "";
    }
  }

  void _showArchivedChatOptions(
    BuildContext context,
    int chatId,
    String displayName,
    ArchiveChatProvider archiveChatProvider,
  ) {
    bottomSheetGobalWithoutTitle(
      context,
      bottomsheetHeight: SizeConfig.sizedBoxHeight(60),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.archive_outlined),
            title: Text(
              AppString.homeScreenString.unarchiveChat,
              style: AppTypography.innerText14(context),
            ),
            onTap: () {
              Navigator.pop(context);
              // ✅ NEW: Show loading and immediate UI update
              _performUnarchiveAction(
                context,
                chatId,
                displayName,
                archiveChatProvider,
              );
            },
          ),
        ],
      ),
    );
  }

  /// ✅ NEW: Perform unarchive action with live reflection
  Future<void> _performUnarchiveAction(
    BuildContext context,
    int chatId,
    String displayName,
    ArchiveChatProvider archiveChatProvider,
  ) async {
    // Store a reference to check if widget is still mounted
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Show loading indicator - only if widget is still mounted
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(width: 20, height: 20, child: commonLoading()),
                const SizedBox(width: 16),
                Text('${AppString.unarchiving} "$displayName"...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Call unarchive function (NEW: explicit intent, no more toggle)
      await archiveChatProvider.archiveUnarchiveChat(chatId, false);

      // ✅ CRITICAL: Wait a moment for the socket event to be processed
      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ NEW: Force refresh of archived chats to update the list
      await archiveChatProvider.fetchArchivedChats();

      // Show success message - only if widget is still mounted
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '${AppString.chat} "$displayName" ${AppString.unarchivedSuccessfully}',
            ),
            backgroundColor: Colors.green,
            // action: SnackBarAction(
            //   label: 'Back to Chats',
            //   onPressed: () {
            //     if (mounted && context.mounted) {
            //       Navigator.of(context, rootNavigator: true).pop();
            //     }
            //   },
            // ),
          ),
        );
      }
    } catch (e) {
      // Show error message - only if widget is still mounted
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '${AppString.failedToUnarchiveChat}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build message preview with call status handling
  Widget _buildMessagePreview(
    BuildContext context,
    Messages? lastMessage,
    Records? record,
    ChatProvider chatProvider,
  ) {
    final currentUserId = chatProvider.currentUserId;

    // Handle empty messages case
    if (lastMessage == null) {
      return Text(
        AppString.nomessagesyet,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.smallText(context).copyWith(
          color: AppColors.textColor.textGreyColor,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Get call info using specialized chatlist method
    final callInfo = CallDisplayService().getChatListCallDisplayInfo(
      calls: lastMessage.calls, // Calls are at message level
      messageContent: lastMessage.messageContent,
      messageType: lastMessage.messageType,
      currentUserId: int.tryParse(currentUserId?.toString() ?? ''),
      messageSenderId: int.tryParse(
        lastMessage.senderId?.toString() ?? '',
      ), // Pass message sender ID for correct direction
    );

    // If we have call display info, show the call widget
    if (callInfo != null) {
      return RichText(
        text: TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              baseline: TextBaseline.alphabetic,
              child: SizedBox(height: 15, child: callInfo.svgIcon),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              baseline: TextBaseline.alphabetic,
              child: SizedBox(width: 4),
            ),
            TextSpan(
              text: callInfo.chatListCallStatus,
              style: AppTypography.innerText12Mediu(context).copyWith(
                color:
                    callInfo.type == CallDisplayType.missedCall
                        ? AppColors.appPriSecColor.secondaryRed
                        : callInfo.type == CallDisplayType.incomingCall
                        ? AppColors.verifiedColor.c00C32B
                        : callInfo.type == CallDisplayType.outgoingCall
                        ? AppColors.appPriSecColor.primaryColor
                        : AppColors.textColor.textDarkGray,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Default message content for non-call messages
    return (lastMessage.messageType == 'text' ||
            lastMessage.messageType == 'group-created' ||
            lastMessage.messageType == 'member-removed' ||
            lastMessage.messageType == 'member-added' ||
            lastMessage.messageType == 'member-left' ||
            lastMessage.messageType == 'promoted-as-admin' ||
            lastMessage.messageType == 'removed-as-admin' ||
            lastMessage.messageContent == 'unblocked' ||
            lastMessage.messageContent == 'blocked')
        ? Text(
          _getMessagePreviewText(
            lastMessage.messageType,
            lastMessage.messageContent,
            actionedUser: lastMessage.actionedUser,
            currentUserId: int.tryParse(currentUserId?.toString() ?? ''),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.innerText12Mediu(
            context,
          ).copyWith(color: AppColors.textColor.textGreyColor),
        )
        : Row(
          children: [
            messageContentIcon(
              context,
              messageType: lastMessage.messageType ?? 'text',
            ),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                _getMessagePreviewText(
                  lastMessage.messageType,
                  lastMessage.messageContent,
                  actionedUser: lastMessage.actionedUser,
                  currentUserId: int.tryParse(currentUserId?.toString() ?? ''),
                ),
                style: AppTypography.innerText12Mediu(
                  context,
                ).copyWith(color: AppColors.textColor.textDarkGray),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
  }

  /// Get message preview text
  String _getMessagePreviewText(
    String? messageType,
    String? messageContent, {
    dynamic actionedUser,
    int? currentUserId,
  }) {
    switch (messageType?.toLowerCase()) {
      case 'group-created':
        return AppString.groupWasCreated;
      case 'image':
        return AppString.photo;
      case 'video':
        return AppString.video;
      case 'document':
      case 'file':
      case 'doc':
      case 'pdf':
        return AppString.document;
      case 'location':
        return AppString.location;
      case 'audio':
        return AppString.audio;
      case 'gif':
        return AppString.gif;
      case 'contact':
        return AppString.contact;
      case 'member-removed':
        // Handle member-removed with proper user name
        if (actionedUser != null && currentUserId != null) {
          int? actionedUserId;
          String? actionedUserName;

          if (actionedUser is Map) {
            actionedUserId = actionedUser['user_id'] as int? ?? actionedUser['userId'] as int?;
            actionedUserName = actionedUser['full_name'] as String? ??
                              actionedUser['fullName'] as String? ??
                              actionedUser['user_name'] as String? ??
                              actionedUser['userName'] as String?;
          } else {
            try {
              actionedUserId = (actionedUser as dynamic).userId as int?;
              actionedUserName = (actionedUser as dynamic).fullName as String? ??
                                (actionedUser as dynamic).userName as String?;
            } catch (e) {
              debugPrint('Error parsing actionedUser in archived member-removed: $e');
            }
          }

          if (actionedUserId != null && actionedUserId == currentUserId) {
            return AppString.youWereRemoved;
          } else if (actionedUserName != null && actionedUserName.isNotEmpty) {
            return AppString.nameWasRemoved(actionedUserName);
          }
        }
        return messageContent ?? AppString.memberRemoved;
      case 'member-added':
        // Handle member-added with proper user name
        if (actionedUser != null && currentUserId != null) {
          int? actionedUserId;
          String? actionedUserName;

          if (actionedUser is Map) {
            actionedUserId = actionedUser['user_id'] as int? ?? actionedUser['userId'] as int?;
            actionedUserName = actionedUser['full_name'] as String? ??
                              actionedUser['fullName'] as String? ??
                              actionedUser['user_name'] as String? ??
                              actionedUser['userName'] as String?;
          } else {
            try {
              actionedUserId = (actionedUser as dynamic).userId as int?;
              actionedUserName = (actionedUser as dynamic).fullName as String? ??
                                (actionedUser as dynamic).userName as String?;
            } catch (e) {
              debugPrint('Error parsing actionedUser in archived member-added: $e');
            }
          }

          if (actionedUserId != null && actionedUserId == currentUserId) {
            return AppString.youWereAdded;
          } else if (actionedUserName != null && actionedUserName.isNotEmpty) {
            return AppString.nameWasAdded(actionedUserName);
          }
        }
        return messageContent ?? AppString.memberAdded;
      case 'promoted-as-admin':
        // Handle promoted-as-admin with proper user name
        if (actionedUser != null && currentUserId != null) {
          int? actionedUserId;
          String? actionedUserName;

          if (actionedUser is Map) {
            actionedUserId = actionedUser['user_id'] as int? ?? actionedUser['userId'] as int?;
            actionedUserName = actionedUser['full_name'] as String? ??
                              actionedUser['fullName'] as String? ??
                              actionedUser['user_name'] as String? ??
                              actionedUser['userName'] as String?;
          } else {
            try {
              actionedUserId = (actionedUser as dynamic).userId as int?;
              actionedUserName = (actionedUser as dynamic).fullName as String? ??
                                (actionedUser as dynamic).userName as String?;
            } catch (e) {
              debugPrint('Error parsing actionedUser in archived promoted-as-admin: $e');
            }
          }

          if (actionedUserId != null && actionedUserId == currentUserId) {
            return '👑 ${AppString.youWerePromotedToAdmin}';
          } else if (actionedUserName != null && actionedUserName.isNotEmpty) {
            return '👑 ${AppString.nameWasPromotedToAdmin(actionedUserName)}';
          }
        }
        return '👑 ${AppString.adminPromoted}';
      case 'removed-as-admin':
        // Handle removed-as-admin with proper user name
        if (actionedUser != null && currentUserId != null) {
          int? actionedUserId;
          String? actionedUserName;

          if (actionedUser is Map) {
            actionedUserId = actionedUser['user_id'] as int? ?? actionedUser['userId'] as int?;
            actionedUserName = actionedUser['full_name'] as String? ??
                              actionedUser['fullName'] as String? ??
                              actionedUser['user_name'] as String? ??
                              actionedUser['userName'] as String?;
          } else {
            try {
              actionedUserId = (actionedUser as dynamic).userId as int?;
              actionedUserName = (actionedUser as dynamic).fullName as String? ??
                                (actionedUser as dynamic).userName as String?;
            } catch (e) {
              debugPrint('Error parsing actionedUser in archived removed-as-admin: $e');
            }
          }

          if (actionedUserId != null && actionedUserId == currentUserId) {
            return '👑 ${AppString.youWereRemovedAsAdmin}';
          } else if (actionedUserName != null && actionedUserName.isNotEmpty) {
            return '👑 ${AppString.nameWasRemovedAsAdmin(actionedUserName)}';
          }
        }
        return '👑 ${AppString.adminRemoved}';
      case 'member-left':
        // Handle member-left with proper user name
        if (actionedUser != null && currentUserId != null) {
          // Extract user ID and name from actionedUser
          int? actionedUserId;
          String? actionedUserName;

          // Handle different data types safely
          if (actionedUser is Map) {
            actionedUserId = actionedUser['user_id'] as int? ?? actionedUser['userId'] as int?;
            actionedUserName = actionedUser['full_name'] as String? ??
                              actionedUser['fullName'] as String? ??
                              actionedUser['user_name'] as String? ??
                              actionedUser['userName'] as String?;
          } else {
            // Assume it's a User object
            try {
              actionedUserId = (actionedUser as dynamic).userId as int?;
              actionedUserName = (actionedUser as dynamic).fullName as String? ??
                                (actionedUser as dynamic).userName as String?;
            } catch (e) {
              debugPrint('Error parsing actionedUser in archived member-left: $e');
            }
          }

          // Debug logging to trace the issue
          debugPrint('=== archived member-left message debug ===');
          debugPrint('actionedUserId: $actionedUserId');
          debugPrint('currentUserId: $currentUserId');
          debugPrint('actionedUserName: $actionedUserName');
          debugPrint('Match: ${actionedUserId == currentUserId}');
          debugPrint('==========================================');

          // Compare user IDs - ensure both are valid before comparison
          if (actionedUserId != null && actionedUserId == currentUserId) {
            return AppString.youLeftTheGroup;
          } else if (actionedUserName != null && actionedUserName.isNotEmpty) {
            return AppString.nameLeftTheGroup(actionedUserName);
          }
        }
        // Fallback to message content if actionedUser info not available
        return messageContent ?? AppString.someoneLeftTheGroup;
      default:
        return messageContent ?? '';
    }
  }
}
