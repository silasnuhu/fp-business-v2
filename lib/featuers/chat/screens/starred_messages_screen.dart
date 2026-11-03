// ignore_for_file: deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/poll%20message/screens/poll_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/voice_message_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/data/starred_messages_model.dart'
    as starred;
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/repository/chat_repository.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/contact_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/delete_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/document_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/gif_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/image_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/link_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/location_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/text_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/video_message_widget.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/home/widgets/chat_lock_pin.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';

class StarredMessagesScreen extends StatefulWidget {
  final int? chatId;
  final String? chatName;
  final bool fromProfileOrGroupInfo;

  const StarredMessagesScreen({
    super.key,
    this.chatId,
    this.chatName,
    this.fromProfileOrGroupInfo = false,
  });

  @override
  State<StarredMessagesScreen> createState() => _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends State<StarredMessagesScreen> {
  final ChatRepository _chatRepository = GetIt.instance<ChatRepository>();
  starred.StarredMessagesResponse? _starredMessages;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMorePages = false;
  bool _isLoadingMore = false;
  bool _isSelectionMode = false;
  final List<int> _selectedMessageIds = [];
  bool _isBottomPanelVisible = false; // Track if bottom panel is visible

  // Chat-specific parameters
  int? _chatId;
  String? _chatName;

  bool _hasInitialized = false;

  // 🎯 FIXED: Anti-flickering display name method using stable API names only
  String _getDisplayName(chats.User? user, starred.PeerUser? peerUser) {
    final configProvider = Provider.of<ProjectConfigProvider>(
      context,
      listen: false,
    );

    // For peer user (in direct messages) — saved contact name always wins,
    // even for business users.
    if (peerUser != null) {
      return ContactNameService.instance.getDisplayNameStable(
        userId: peerUser.userId,
        configProvider: configProvider,
        contextFullName: peerUser.fullName,
        firstName: peerUser.firstName,
        lastName: peerUser.lastName,
      );
    }

    // For regular user (message sender)
    if (user != null) {
      return ContactNameService.instance.getDisplayNameStable(
        userId: user.userId,
        configProvider: configProvider,
        contextFullName: user.fullName,
      );
    }

    return AppString.unknownUser;
  }

  /// A name in the "sender ▸ chat" header, followed by the blue tick when
  /// that user is premium. [isOwn] marks the logged-in user ("You"); [userId]
  /// is the other user, or null for a group name.
  Widget _nameWithBadge(String name, {int? userId, bool isOwn = false}) {
    final style = AppTypography.innerText11(context);
    if (isOwn) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              style: style,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const OwnVerifiedBadge(size: 13, leading: 3),
        ],
      );
    }
    return UserNameWithBadge(
      userId: userId,
      name: name,
      style: style,
      badgeSize: 13,
    );
  }

  /// `GET /messages/starred` carries no avatar for the conversation, so fall
  /// back to the already-loaded chat list before opening the chat — group
  /// icon for groups, the peer's picture for direct chats.
  String _resolveChatAvatar(int? chatId, {String? fallback}) {
    if (fallback != null && fallback.isNotEmpty) return fallback;
    if (chatId == null) return '';

    final loadedChats =
        Provider.of<ChatProvider>(context, listen: false).chatListData.chats;
    for (final chat in loadedChats) {
      final record =
          chat.records?.isNotEmpty == true ? chat.records!.first : null;
      if (record?.chatId != chatId) continue;
      final groupIcon = record?.groupIcon;
      if (groupIcon != null && groupIcon.isNotEmpty) return groupIcon;
      return chat.peerUserData?.profilePic ?? '';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _extractRouteArguments();
      _hasInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadStarredMessages();
      });
    }
  }

  void _extractRouteArguments() {
    if (widget.chatId != null) {
      _chatId = widget.chatId;
      _chatName = widget.chatName;
      debugPrint(
        'DEBUG: Using widget parameters - chatId: $_chatId, chatName: $_chatName',
      );
      return;
    }

    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      _chatId = arguments['chatId'] as int?;
      _chatName = arguments['chatName'] as String?;
      debugPrint(
        'DEBUG: Extracted from route args - chatId: $_chatId, chatName: $_chatName',
      );
    } else {
      debugPrint(
        'DEBUG: No chat-specific arguments found, showing all starred messages',
      );
    }
  }

  Future<void> _loadStarredMessages({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    }

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      debugPrint(
        'DEBUG: About to call getStarredMessages with page: $page, chatId: $_chatId',
      );
      final response = await _chatRepository.getStarredMessages(
        page: page,
        chatId: _chatId,
      );

      if (response != null && response.status == true) {
        setState(() {
          if (loadMore) {
            _starredMessages?.data?.records?.addAll(
              response.data?.records ?? [],
            );
            _currentPage = page;
          } else {
            _starredMessages = response;
            _currentPage = 1;
          }

          final pagination = response.data?.pagination;
          _hasMorePages =
              pagination != null &&
              pagination.currentPage != null &&
              pagination.totalPages != null &&
              pagination.currentPage! < pagination.totalPages!;

          _isLoading = false;
          _isLoadingMore = false;
          _hasError = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage =
              response?.message ??
              AppString.failedToLoadStarredMessages;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  // ✅ Helper method to format time
  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();

      if (dateTime.day == now.day &&
          dateTime.month == now.month &&
          dateTime.year == now.year) {
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  bool _isChatLocked(int chatId) {
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final chats = chatProvider.chatListData.chats;

      for (final chat in chats) {
        final record =
            chat.records?.isNotEmpty == true ? chat.records!.first : null;
        if (record?.chatId == chatId) {
          return record?.participants?.first.isLocked == true;
        }
      }
      // chatId not found in list — treat as unlocked
      return false;
    } catch (e) {
      debugPrint('Error checking lock status for chatId $chatId: $e');
      return false;
    }
  }

  void _onMessageTap(starred.StarredMessageRecord message) {
    // In edit/selection mode a tap only selects or unselects — never navigates.
    if (_isSelectionMode) {
      if (message.messageId != null) {
        _toggleMessageSelection(message.messageId!);
      }
      return;
    }

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (message.chatId == null) return;

    if (_isChatLocked(message.chatId!)) {
      _showPinDialog(
        context: context,
        mode: PinDialogMode.unlock,
        chatName: message.peerUser?.userName ?? "",
        // correctPin: _globalPin ?? record!.participants!.first.lockPin,
        onValidatePin: (enteredPin) async {
          return await _callUnLockChatApi(
            chatId: message.chatId.toString(),
            pin: enteredPin,
          );
        },
        onSuccess: () {
          chatProvider.markSessionUnlocked(message.chatId!);
          if (message.chat?.chatType == 'group') {
            Navigator.pushNamed(
              context,
              AppRoutes.universalChat,
              arguments: {
                'chatId': message.chatId ?? 0,
                'chatName': message.chat?.groupName ?? 'Group Chat',
                'profilePic': _resolveChatAvatar(
                  message.chatId,
                  fallback: message.chat?.groupIcon,
                ),
                'isGroupChat': true,
                'highlightMessageId': message.messageId,
                'navigationSource': 'starred_messages',
                'fromStarredMessages': true,
                'fromProfileOrGroupInfo': widget.fromProfileOrGroupInfo,
                'isAdminChat': false,
                'userType': message.peerUser?.userType ?? 'ragular',
              },
            );
          } else {
            Navigator.pushNamed(
              context,
              AppRoutes.universalChat,
              arguments: {
                'userId': message.peerUser?.userId ?? 0,
                'chatName': _getDisplayName(null, message.peerUser),
                'profilePic': _resolveChatAvatar(
                  message.chatId,
                  fallback: message.peerUser?.profilePic,
                ),
                'chatId': message.chatId,
                'updatedAt': message.updatedAt,
                'isGroupChat': false,
                'highlightMessageId': message.messageId,
                'navigationSource': 'starred_messages',
                'fromStarredMessages': true,
                'fromProfileOrGroupInfo': widget.fromProfileOrGroupInfo,
                'isAdminChat': false,
                'userType': message.peerUser?.userType ?? 'ragular',
              },
            );
          }
        },
      );
      return; // ← stop here, do not navigate
    }

    debugPrint("message.chatId ${message.chatId}");
    debugPrint(
      "message.chatName ${message.chat?.groupName ?? _getDisplayName(message.user, null)}",
    );
    debugPrint("message.isGroupChat ${message.chat?.chatType == 'group'}");
    debugPrint(
      "message.profilePic ${message.chat?.groupIcon ?? message.user?.profilePic}",
    );
    debugPrint(
      "message.userId ${message.chat?.chatType == 'group' ? null : message.user?.userId}",
    );

    // Navigate to universal chat with proper back navigation handling
    if (message.chat?.chatType == 'group') {
      Navigator.pushNamed(
        context,
        AppRoutes.universalChat,
        arguments: {
          'chatId': message.chatId ?? 0,
          'chatName': message.chat?.groupName ?? 'Group Chat',
          'profilePic': _resolveChatAvatar(
            message.chatId,
            fallback: message.chat?.groupIcon,
          ),
          'isGroupChat': true,
          'highlightMessageId': message.messageId,
          'navigationSource': 'starred_messages',
          'fromStarredMessages': true,
          'fromProfileOrGroupInfo': widget.fromProfileOrGroupInfo,
          'isAdminChat': false,
          'userType': message.peerUser?.userType ?? 'ragular',
        },
      );
    } else {
      Navigator.pushNamed(
        context,
        AppRoutes.universalChat,
        arguments: {
          'userId': message.peerUser?.userId ?? 0,
          'chatName': _getDisplayName(null, message.peerUser),
          'profilePic': _resolveChatAvatar(
            message.chatId,
            fallback: message.peerUser?.profilePic,
          ),
          'chatId': message.chatId,
          'updatedAt': message.updatedAt,
          'isGroupChat': false,
          'highlightMessageId': message.messageId,
          'navigationSource': 'starred_messages',
          'fromStarredMessages': true,
          'fromProfileOrGroupInfo': widget.fromProfileOrGroupInfo,
          'isAdminChat': false,
          'userType': message.peerUser?.userType ?? 'ragular',
        },
      );
    }
  }

  Future<bool> _callUnLockChatApi({
    required String chatId,
    required String pin,
  }) async {
    final provider = context.read<ChatProvider>();
    return await provider.unLockChat(chatId, pin);
  }

  void _showPinDialog({
    required BuildContext context,
    required PinDialogMode mode,
    required String chatName,
    String? correctPin, // kept for legacy callers
    Future<bool> Function(String pin)?
    onValidatePin, // NEW: async API validator
    VoidCallback? onSuccess,
    void Function(String pin)? onPinSet,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => PinDialog(
            mode: mode,
            chatName: chatName,
            correctPin: correctPin,
            onValidatePin: onValidatePin,
            onSuccess: onSuccess,
            onPinSet: onPinSet,
          ),
    );
  }

  void _toggleMessageSelection(int messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }

      // Update bottom panel visibility. Unselecting everything leaves edit
      // mode, same as closing it from the app bar.
      _isBottomPanelVisible = _selectedMessageIds.isNotEmpty;
      _isSelectionMode = _selectedMessageIds.isNotEmpty;
    });
  }

  Future<bool> _showGlobalBottomSheet({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String confirmButtonText,
    String? cancelButtonText,
    bool isLoading = false,
  }) async {
    final result = await bottomSheetGobalWithoutTitle(
      context,
      bottomsheetHeight: SizeConfig.height(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.height(3)),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
            child: Text(
              title,
              style: AppTypography.captionText(context).copyWith(
                fontSize: SizeConfig.getFontSize(15),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: SizeConfig.height(2)),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
            child: Text(
              subtitle,
              style: AppTypography.captionText(context).copyWith(
                color: AppColors.textColor.textGreyColor,
                fontSize: SizeConfig.getFontSize(13),
              ),
            ),
          ),
          SizedBox(height: SizeConfig.height(4)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: customBorderBtn(
                  context,
                  onTap: () => Navigator.pop(context, false), // return false
                  title: cancelButtonText!,
                ),
              ),
              isLoading
                  ? SizedBox(
                    height: SizeConfig.sizedBoxHeight(35),
                    width: SizeConfig.sizedBoxWidth(35),
                    child: commonLoading(),
                  )
                  : SizedBox(
                    height: SizeConfig.height(5),
                    width: SizeConfig.width(35),
                    child: customBtn2(
                      context,
                      onTap: () => Navigator.pop(context, true), // return true
                      child: Text(
                        confirmButtonText,
                        style: AppTypography.h5(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: ThemeColorPalette.getTextColor(
                            AppColors.appPriSecColor.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );

    return result ?? false; // default to false if closed without action
  }

  bool _isUnstarLoad = false;

  Future<void> _unstarMessage(int messageId) async {
    final shouldUnstar = await _showGlobalBottomSheet(
      context: context,
      title: AppString.settingStrigs.unstarMessage,
      subtitle: AppString.settingStrigs.areYouSureYouWantToUnstarThisMessage,
      confirmButtonText: AppString.settingStrigs.unstar,
      cancelButtonText: AppString.cancel,
    );
    //  await showDialog<bool>(
    //   context: context,
    //   builder: (BuildContext context) {
    //     return AlertDialog(
    //       title: Text('Unstar Message', style: AppTypography.h4(context)),
    //       content: Text(
    //         'Are you sure you want to unstar this message?',
    //         style: AppTypography.captionText(context),
    //       ),
    //       actions: [
    //         TextButton(
    //           onPressed: () => Navigator.of(context).pop(false),
    //           child: Text(
    //             'Cancel',
    //             style: AppTypography.captionText(
    //               context,
    //             ).copyWith(color: AppColors.textColor.textGreyColor),
    //           ),
    //         ),
    //         TextButton(
    //           onPressed: () => Navigator.of(context).pop(true),
    //           child: Text(
    //             'Unstar',
    //             style: AppTypography.captionText(
    //               context,
    //             ).copyWith(color: AppColors.black, fontWeight: FontWeight.w600),
    //           ),
    //         ),
    //       ],
    //     );
    //   },
    // );

    if (shouldUnstar == true) {
      try {
        setState(() {
          _isUnstarLoad = true;
        });
        final success = await _chatRepository.starUnStarMessage(
          messageId: messageId,
        );
        if (!mounted) return;
        Provider.of<ChatProvider>(context, listen: false).countApi();

        if (success) {
          setState(() {
            _isUnstarLoad = false;
            _starredMessages?.data?.records?.removeWhere(
              (record) => record.messageId == messageId,
            );
            _selectedMessageIds.remove(messageId);
            _isBottomPanelVisible = _selectedMessageIds.isNotEmpty;
            _isSelectionMode = _selectedMessageIds.isNotEmpty;
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppString.messageUnstarredSuccessfully),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppString.failedToUnstarMessage),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppString.error}: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      } finally {
        setState(() {
          _isUnstarLoad = false;
        });
      }
    }
  }

  chats.Records mapStarredToRecords(starred.StarredMessageRecord message) {
    return chats.Records(
      messageContent: message.messageContent,
      replyTo: message.replyTo,
      socialId: message.socialId,
      messageId: message.messageId,
      messageType: message.messageType,
      messageThumbnail: message.messageThumbnail,
      messageLength: message.messageLength,
      messageSize: message.messageSize,
      createdAt: message.createdAt,
      updatedAt: message.updatedAt,
      chatId: message.chatId,
      senderId: message.senderId,
      messageSeenStatus: message.messageSeenStatus,
      pinned: message.pinned,
      pinLifetime: message.pinLifetime,
      pinnedTill: message.pinnedTill,
      deletedForEveryone: message.deletedForEveryone,
      deletedFor: message.deletedFor,
      starredFor: message.starredFor,
      user: message.user,
      peerUserData: null, // starred.StarredMessageRecord doesn’t have this
      isFollowing: true,
      voiceDuration: message.voiceDuration,
      pollData: _convertPollData(message.pollData),
    );
  }

  chats.PollData? _convertPollData(starred.PollData? starredPoll) {
    if (starredPoll == null) return null;
    // ✅ Serialize to JSON then deserialize as chats.PollData
    return chats.PollData.fromJson(starredPoll.toJson());
  }

  Future<void> _unstarSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    final shouldUnstar = await _showGlobalBottomSheet(
      context: context,
      title: AppString.settingStrigs.unstarMessage,
      subtitle: AppString.settingStrigs.areYouSureYouWantToUnstarThisMessage,
      confirmButtonText: AppString.settingStrigs.unstar,
      cancelButtonText: AppString.cancel,
    );
    // await showDialog<bool>(
    //   context: context,
    //   builder: (BuildContext context) {
    //     return AlertDialog(
    //       title: Text('Unstar Messages', style: AppTypography.h4(context)),
    //       content: Text(
    //         'Are you sure you want to unstar ${_selectedMessageIds.length} message${_selectedMessageIds.length > 1 ? 's' : ''}?',
    //         style: AppTypography.captionText(context),
    //       ),
    //       actions: [
    //         TextButton(
    //           onPressed: () => Navigator.of(context).pop(false),
    //           child: Text(
    //             'Cancel',
    //             style: AppTypography.captionText(
    //               context,
    //             ).copyWith(color: AppColors.textColor.textGreyColor),
    //           ),
    //         ),
    //         TextButton(
    //           onPressed: () => Navigator.of(context).pop(true),
    //           child: Text(
    //             'Unstar',
    //             style: AppTypography.captionText(
    //               context,
    //             ).copyWith(color: AppColors.black, fontWeight: FontWeight.w600),
    //           ),
    //         ),
    //       ],
    //     );
    //   },
    // );

    if (shouldUnstar == true) {
      try {
        setState(() {
          _isUnstarLoad = true;
        });
        bool allSuccess = true;
        for (var messageId in _selectedMessageIds) {
          final success = await _chatRepository.starUnStarMessage(
            messageId: messageId,
          );
          if (!success) {
            allSuccess = false;
          }

          if (!mounted) return;
          Provider.of<ChatProvider>(context, listen: false).countApi();
        }

        setState(() {
          for (var messageId in _selectedMessageIds) {
            _starredMessages?.data?.records?.removeWhere(
              (record) => record.messageId == messageId,
            );
          }
          _isUnstarLoad = false;
          _selectedMessageIds.clear();
          _isSelectionMode = false;
          _isBottomPanelVisible = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              allSuccess
                  ? 'Messages unstarred successfully'
                  : 'Some messages failed to unstar',
            ),
            backgroundColor: allSuccess ? Colors.green : Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppString.error}: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      } finally {
        setState(() {
          _isUnstarLoad = false;
        });
      }
    }
  }

  Widget _buildBottomPanel() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      height:
          _isBottomPanelVisible
              ? SizeConfig.sizedBoxHeight(190) + bottomInset
              : 0,
      decoration: BoxDecoration(
        gradient: AppThemeManage.appTheme.starredGradient,
      ),
      child:
          _isBottomPanelVisible
              ? Padding(
                padding: SizeConfig.getPaddingSymmetric(
                  horizontal: 16,
                  vertical: 20,
                ).copyWith(bottom: 20 + bottomInset),
                child: Center(
                  child: InkWell(
                    onTap: () {
                      if (_selectedMessageIds.length == 1) {
                        _unstarMessage(_selectedMessageIds.first);
                      } else {
                        _unstarSelectedMessages();
                      }
                    },
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: SizeConfig.sizedBoxHeight(48),
                            width: SizeConfig.sizedBoxWidth(48),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.appPriSecColor.primaryColor,
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                AppAssets.starredMessageIcon.starslash,
                                height: SizeConfig.sizedBoxHeight(22),
                                color: ThemeColorPalette.getTextColor(
                                  AppColors.appPriSecColor.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: SizeConfig.sizedBoxHeight(6)),
                          Text(
                            AppString.settingStrigs.unstar,
                            style: AppTypography.innerText11(
                              context,
                            ).copyWith(fontWeight: FontWeight.w500),
                          ),
                          // SvgPicture.asset(
                          //   AppAssets.groupProfielIcons.trash1,
                          //   color: AppColors.black,
                          //   height: SizeConfig.sizedBoxHeight(24),
                          // ),
                          // SvgPicture.asset(
                          //   AppAssets.starredMessageIcon.shareIcon,
                          //   color: AppColors.black,
                          //   height: SizeConfig.sizedBoxHeight(24),
                          // ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              : null,
    );
  }

  String formatUtcToTime(String utcString) {
    final utcDate = DateTime.tryParse(utcString);
    if (utcDate == null) return '';
    return DateFormat('hh:mm a').format(utcDate.toUtc().toLocal());
  }

  String formatUtcToDdMmYyyy(String utcString) {
    final utcDate = DateTime.tryParse(utcString);
    if (utcDate == null) return '';
    return DateFormat('dd/MM/yyyy').format(utcDate.toUtc().toLocal());
  }

  // ignore: unused_element
  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildStarredMessageTile(starred.StarredMessageRecord message) {
    final hasChat = message.chat != null;
    final isGroupChat = message.chat?.chatType == 'group';
    final isSelected =
        message.messageId != null &&
        _selectedMessageIds.contains(message.messageId);
    final bool isSentByMe = (message.senderId ?? -1) == int.parse(userID);

    String firstName;
    String secondName;

    if (isGroupChat) {
      if (isSentByMe) {
        // My message in group
        firstName = 'You';
        secondName = message.chat?.groupName ?? 'Unknown Chat';
      } else {
        // Someone else's message in group
        firstName = _getDisplayName(message.user, null); // Sender's name
        secondName = message.chat?.groupName ?? 'Unknown Chat';
      }
    } else {
      if (isSentByMe) {
        // My direct message
        firstName = 'You';
        secondName = _getDisplayName(null, message.peerUser); // Receiver
      } else {
        // Someone else's direct message
        firstName = _getDisplayName(message.user, null); // Sender
        secondName = 'You';
      }
    }
    return Container(
      margin: SizeConfig.getPaddingSymmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color:
            isSelected
                ? AppColors.appPriSecColor.secondaryColor.withValues(
                  alpha: 0.11,
                )
                : AppThemeManage.appTheme.scaffoldBackColor,
        border: Border(
          top: BorderSide(
            color: AppColors.strokeColor.greyColor.withValues(alpha: 0.1),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.06),
            blurRadius: 5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _onMessageTap(message),
        onLongPress: () {
          if (!_isSelectionMode && message.messageId != null) {
            setState(() {
              _isSelectionMode = true;
              _selectedMessageIds.add(message.messageId!);
              _isBottomPanelVisible = true;
            });
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasChat) ...[
                Row(
                  children: [
                    if (message.user != null) ...[
                      Container(
                        width: 31,
                        height: 31,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.strokeColor.greyColor.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: ClipOval(
                          child:
                              message.user!.profilePic != null
                                  ? CachedNetworkImage(
                                    imageUrl: message.user!.profilePic!,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) {
                                      return Container(
                                        color: AppColors.bgColor.bg2Color,
                                        child: Icon(
                                          Icons.person,
                                          size: 12,
                                          color:
                                              AppColors.textColor.textGreyColor,
                                        ),
                                      );
                                    },
                                  )
                                  : Container(
                                    color: AppColors.bgColor.bg2Color,
                                    child: Icon(
                                      Icons.person,
                                      size: 12,
                                      color: AppColors.textColor.textGreyColor,
                                    ),
                                  ),
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: _nameWithBadge(
                                  firstName,
                                  isOwn: isSentByMe,
                                  userId:
                                      isSentByMe
                                          ? null
                                          : (message.senderId ??
                                              message.user?.userId),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 15,
                                  color: AppThemeManage.appTheme.darkWhiteColor,
                                ),
                              ),
                              Flexible(
                                child: _nameWithBadge(
                                  secondName,
                                  // Direct chat: the other side is either the
                                  // peer (I sent it) or me (they sent it).
                                  isOwn: !isGroupChat && !isSentByMe,
                                  userId:
                                      (!isGroupChat && isSentByMe)
                                          ? message.peerUser?.userId
                                          : null,
                                ),
                              ),
                              Spacer(),
                              Text(
                                formatUtcToDdMmYyyy(message.createdAt ?? ''),
                                style: AppTypography.innerText10(
                                  context,
                                ).copyWith(
                                  color: AppColors.textColor.text808080,
                                ),
                              ),
                            ],
                          ),
                          // Row(
                          //   children: [
                          //     if (isGroupChat) ...[
                          //       Text(
                          //         message.chat?.groupName ?? 'Unknown Chat',
                          //         style: AppTypography.innerText11(
                          //           context,
                          //         ).copyWith(
                          //           color: AppColors.textColor.textBlackColor,
                          //         ),
                          //       ),
                          //       Padding(
                          //         padding: const EdgeInsets.symmetric(
                          //           horizontal: 3,
                          //         ),
                          //         child: Icon(
                          //           Icons.play_arrow_rounded,
                          //           size: 15,
                          //         ),
                          //       ),
                          //     ],
                          //     Text(
                          //       (isGroupChat &&
                          //               (message.senderId ?? -1) ==
                          //                   int.parse(userID))
                          //           ? 'You'
                          //           : message.user?.fullName ?? 'Unknown User',
                          //       style: AppTypography.innerText11(
                          //         context,
                          //       ).copyWith(
                          //         color: AppColors.textColor.textBlackColor,
                          //       ),
                          //     ),
                          //     Spacer(),
                          //     Text(
                          //       formatUtcToDdMmYyyy(message.createdAt ?? ''),
                          //       style: AppTypography.innerText10(
                          //         context,
                          //       ).copyWith(
                          //         color: AppColors.textColor.text808080,
                          //       ),
                          //     ),
                          //   ],
                          // ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: _buildMessageContent(context, message)),
                        _isSelectionMode
                            ? SizedBox(
                              height: 24,
                              width: 24,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? AppColors
                                                .appPriSecColor
                                                .secondaryColor
                                            : AppThemeManage
                                                .appTheme
                                                .darkGreyColor,
                                    border: Border.all(
                                      width: 2,
                                      color:
                                          AppColors
                                              .appPriSecColor
                                              .secondaryColor,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child:
                                      isSelected
                                          ? Icon(
                                            Icons.check_rounded,
                                            size: 15,
                                            color:
                                                ThemeColorPalette.getTextColor(
                                                  AppColors
                                                      .appPriSecColor
                                                      .primaryColor,
                                                ), //AppColors.black,
                                            // size: 18,
                                          )
                                          : null,
                                ),
                              ),
                            )
                            : Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textColor.text808080,
                            ),
                      ],
                    ),
                  ),
                  if (message.forwardedFrom != null &&
                      message.forwardedFrom! > 0) ...[
                    SizedBox(width: 8),
                    Icon(
                      Icons.forward,
                      size: 14,
                      color: AppColors.textColor.textGreyColor,
                    ),
                  ],
                ],
              ),
              SizedBox(height: SizeConfig.sizedBoxHeight(8)),
              Row(
                children: [
                  Text(
                    formatUtcToTime(message.createdAt ?? ''),
                    style: AppTypography.innerText10(
                      context,
                    ).copyWith(color: AppColors.textColor.text808080),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: SvgPicture.asset(
                      AppAssets.chatImage.start,
                      colorFilter: ColorFilter.mode(
                        AppColors.appPriSecColor.primaryColor,
                        BlendMode.srcIn,
                      ),
                      height: SizeConfig.sizedBoxHeight(10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // // ✅ IMPROVED: Use passed star status for real-time updates
  // Widget _buildMessageContent(
  //   BuildContext context,
  //   starred.StarredMessageRecord message,
  // ) {
  //   // ✅ Check if the message is deleted first, regardless of message type
  //   // Check multiple conditions to ensure deleted messages are properly handled
  //   if (message.messageType == 'This message was deleted.' ||
  //       message.messageType == 'This message was deleted' ||
  //       message.deletedForEveryone == true) {
  //     return DeletedMessageWidget(
  //       chat: message,
  //       currentUserId: message.senderId.toString(),
  //     );
  //   }

  //   switch (message.messageType?.toLowerCase()) {
  //     case 'text':
  //       return TextMessageWidget(
  //         chat: message,
  //         currentUserId: message.senderId.toString(),
  //         isStarred: true, // ✅ Pass real-time star status
  //         onReplyTap: onReplyTap, // ✅ NEW: Pass reply tap callback
  //       );

  //     case 'image':
  //       return ImageMessageWidget(
  //         chat: chat,
  //         currentUserId: currentUserId,
  //         onTap: () => onImageTap?.call(chat.messageContent ?? ''),
  //         isStarred: isStarred, // ✅ Pass real-time star status
  //         onReplyTap: onReplyTap, // ✅ NEW: Pass reply tap callback
  //         isForPinned: false,
  //       );

  //     case 'gif':
  //       return GifMessageWidget(
  //         chat: chat,
  //         currentUserId: currentUserId,
  //         onTap: () => onImageTap?.call(chat.messageContent ?? ''),
  //         isStarred: isStarred,
  //         onReplyTap: onReplyTap,
  //         isForPinned: false,
  //       );

  //     case 'document':
  //     case 'doc':
  //     case 'pdf':
  //       return DocumentMessageWidget(
  //         chat: chat,
  //         currentUserId: currentUserId,
  //         onTap: () => onDocumentTap?.call(chat),
  //         chatProvider: chatProvider!,
  //         isStarred: isStarred, // ✅ Pass real-time star status
  //         onReplyTap: onReplyTap,
  //         isForPinned: false,
  //       );

  //     case 'video':
  //       return VideoMessageWidget(
  //         chat: chat,
  //         currentUserId: currentUserId,
  //         onTap: () => onVideoTap?.call(chat.messageContent ?? ''),
  //         thumbnailUrl: chat.messageThumbnail,
  //         isStarred: isStarred, // ✅ Pass real-time star status
  //         onReplyTap: onReplyTap,
  //         isForPinned: false,
  //       );

  //     case 'location':
  //       return LocationMessageWidget(
  //         chat: chat,
  //         currentUserId: currentUserId,
  //         onTap: () {
  //           if (chat.messageContent != null) {
  //             final coordinates = chat.messageContent!.split(',');
  //             if (coordinates.length >= 2) {
  //               final lat = double.tryParse(coordinates[0].trim());
  //               final lng = double.tryParse(coordinates[1].trim());
  //               if (lat != null && lng != null) {
  //                 onLocationTap?.call(lat, lng);
  //               }
  //             }
  //           }
  //         },
  //         latitude: _getLatitude(),
  //         longitude: _getLongitude(),
  //         isStarred: isStarred, // ✅ Pass real-time star status
  //         onReplyTap: onReplyTap,
  //         isForPinned: false,
  //       );

  //     case 'call':
  //       return CallMessageWidget(
  //         key: ValueKey('call_${chat.messageId}_${chat.messageContent}'),
  //         chat: chat,
  //         currentUserId: currentUserId,
  //         isStarred: isStarred,
  //         onReplyTap: onReplyTap,
  //         peerUserId: peerUserId,
  //       );

  //     case 'contact':
  //       return ContactMessageWidget(
  //         chat: chat,
  //         currentUserId: currentUserId,
  //         isStarred: isStarred,
  //         onReplyTap: onReplyTap,
  //         isForPinned: false,
  //       );

  //     case 'block':
  //     case 'unblock':
  //       return BlockUnblockMessageWidget(
  //         chat: chat,
  //         currentUserId: currentUserId,
  //         isStarred: isStarred,
  //         onReplyTap: onReplyTap,
  //       );

  //     default:
  //       return _buildUnsupportedMessage(context);
  //   }
  // }

  double? _getLatitude(starred.StarredMessageRecord message) {
    if (message.messageContent == null) return null;
    final coordinates = message.messageContent!.split(',');
    if (coordinates.isNotEmpty) {
      return double.tryParse(coordinates[0].trim());
    }
    return null;
  }

  double? _getLongitude(starred.StarredMessageRecord message) {
    if (message.messageContent == null) return null;
    final coordinates = message.messageContent!.split(',');
    if (coordinates.length >= 2) {
      return double.tryParse(coordinates[1].trim());
    }
    return null;
  }

  Widget _buildMessageContent(
    BuildContext context,
    starred.StarredMessageRecord message,
  ) {
    final chatRecord = mapStarredToRecords(message); // ✅ Convert here

    if (message.messageType == 'This message was deleted.' ||
        message.messageType == 'This message was deleted' ||
        message.deletedForEveryone == true) {
      return DeletedMessageWidget(
        chat: chatRecord, // ✅ Now passes correct type
        currentUserId: message.senderId.toString(),
      );
    }

    // final currentUserId = message.user?.userId.toString() ?? '';
    final currentUserId = userID;
    final isStarred = true; // Or set logic from your starredFor

    switch (message.messageType?.toLowerCase()) {
      case 'poll':
        return IgnorePointer(
          child: PollMessageWidget(
            chat: chatRecord,
            currentUserId: currentUserId,
            isStarred: isStarred,
            onVote: (updatedPoll) {},
            openedFromStarred: true,
            onReplyTap: (p0) {},
            isForPinned: false,
          ),
        );

      case 'text':
        return TextMessageWidget(
          chat: chatRecord,
          currentUserId: currentUserId,
          isStarred: isStarred,
          openedFromStarred: true,
        );

      case 'link':
        return IgnorePointer(
          child: LinkMessageWidget(
            isForPinned: false,
            chat: chatRecord,
            currentUserId: currentUserId,
            isStarred: isStarred,
            openedFromStarred: true,
          ),
        );

      case 'voice':
        return VoiceMessageWidget(
          chat: chatRecord,
          currentUserId: currentUserId,
          onTap: () {
            _onMessageTap(message);
          },
          isStarred: isStarred,
          openedFromStarred: true,
          onReplyTap: (p0) {},
          isForPinned: false,
        );

      case 'image':
        return ImageMessageWidget(
          chat: chatRecord,
          currentUserId: currentUserId,
          onTap: () {
            _onMessageTap(message);
          },
          isStarred: isStarred,
          openedFromStarred: true,
          onReplyTap: (p0) {},
          isForPinned: false,
        );

      case 'gif':
        return GifMessageWidget(
          chat: chatRecord,
          currentUserId: currentUserId,
          onTap: () {
            _onMessageTap(message);
          },
          isStarred: isStarred,
          openedFromStarred: true,
          isForPinned: false,
        );

      case 'document':
      case 'doc':
      case 'pdf':
        return DocumentMessageWidget(
          chat: chatRecord,
          currentUserId: currentUserId,
          onTap: () {
            _onMessageTap(message);
          },
          chatProvider: Provider.of<ChatProvider>(context, listen: false),
          isStarred: isStarred,
          isForPinned: false,
          openedFromStarred: true,
        );

      case 'video':
        return VideoMessageWidget(
          chat: chatRecord,
          currentUserId: currentUserId,
          onTap: () {
            _onMessageTap(message);
          },
          thumbnailUrl: message.messageThumbnail,
          isStarred: isStarred,
          isForPinned: false,
        );

      case 'location':
        return LocationMessageWidget(
          chat: chatRecord,
          currentUserId: currentUserId,
          onTap: () {
            _onMessageTap(message);
          },
          latitude: _getLatitude(message),
          longitude: _getLongitude(message),
          isStarred: isStarred,
          openedFromStarred: true,
          isForPinned: false,
        );

      case 'contact':
        return ContactMessageWidget(
          chat: chatRecord,
          onTap: () {
            _onMessageTap(message);
          },
          currentUserId: currentUserId,
          isStarred: isStarred,
          openedFromStarred: true,
          isForPinned: false,
        );

      default:
        return _buildUnsupportedMessage(context, message, isStarred);
    }
  }

  // ✅ IMPROVED: Unsupported message with real-time star support
  Widget _buildUnsupportedMessage(
    BuildContext context,
    starred.StarredMessageRecord message,
    bool isStarred,
  ) {
    return Container(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.grey,
        borderRadius: BorderRadius.circular(8),
        // ✅ Add border for starred unsupported messages using real-time status
        border:
            isStarred
                ? Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                  width: 1,
                )
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppString.unsupportedMessageType(message.messageType ?? ''),
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textGreyColor),
          ),

          // ✅ Show star and metadata for unsupported messages using real-time status
          if (isStarred) ...[
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ✅ Simple star indicator for unsupported messages
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      AppString.starred,
                      style: AppTypography.captionText(context).copyWith(
                        color: Colors.amber[700],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatTime(message.createdAt),
                  style: AppTypography.captionText(context).copyWith(
                    color: AppColors.textColor.textGreyColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Widget _buildMessageContent(starred.StarredMessageRecord message) {
  //   switch (message.messageType) {
  //     case 'text':
  //       return Text(
  //         message.messageContent ?? '',
  //         style: AppTypography.captionText(
  //           context,
  //         ).copyWith(fontSize: SizeConfig.getFontSize(14)),
  //         maxLines: 3,
  //         overflow: TextOverflow.ellipsis,
  //       );
  //     case 'image':
  //       return Row(
  //         children: [
  //           messageContentIcon(context, messageType: message.messageType ?? ''),
  //           SizedBox(width: 4),
  //           Text(
  //             'Photo',
  //             style: AppTypography.captionText(context).copyWith(
  //               fontSize: SizeConfig.getFontSize(14),
  //               fontStyle: FontStyle.italic,
  //             ),
  //           ),
  //         ],
  //       );
  //     case 'video':
  //       return Row(
  //         children: [
  //           messageContentIcon(context, messageType: message.messageType ?? ''),

  //           SizedBox(width: 4),
  //           Text(
  //             'Video',
  //             style: AppTypography.captionText(context).copyWith(
  //               fontSize: SizeConfig.getFontSize(14),
  //               fontStyle: FontStyle.italic,
  //             ),
  //           ),
  //         ],
  //       );
  //     case 'document':
  //       return Row(
  //         children: [
  //           messageContentIcon(context, messageType: message.messageType ?? ''),
  //           SizedBox(width: 4),
  //           Text(
  //             'Document',
  //             style: AppTypography.captionText(context).copyWith(
  //               fontSize: SizeConfig.getFontSize(14),
  //               fontStyle: FontStyle.italic,
  //             ),
  //           ),
  //         ],
  //       );
  //     case 'audio':
  //       return Row(
  //         children: [
  //           messageContentIcon(context, messageType: message.messageType ?? ''),
  //           SizedBox(width: 4),
  //           Text(
  //             'Audio',
  //             style: AppTypography.captionText(context).copyWith(
  //               fontSize: SizeConfig.getFontSize(14),
  //               fontStyle: FontStyle.italic,
  //             ),
  //           ),
  //         ],
  //       );
  //     default:
  //       return Text(
  //         message.messageContent ?? 'Unsupported message type',
  //         style: AppTypography.captionText(context).copyWith(
  //           fontSize: SizeConfig.getFontSize(14),
  //           fontStyle: FontStyle.italic,
  //           color: AppColors.textColor.textGreyColor,
  //         ),
  //       );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _isSelectionMode = false;
          _selectedMessageIds.clear();
          _isBottomPanelVisible = false;
        });
      },
      child: Scaffold(
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
              child:
                  _isSelectionMode
                      ? InkWell(
                        onTap: () {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedMessageIds.clear();
                            _isBottomPanelVisible = false;
                          });
                        },
                        child: Icon(
                          Icons.close,
                          color: AppThemeManage.appTheme.darkWhiteColor,
                        ),
                      )
                      : customeBackArrowBalck(context),
            ),
            title:
                _isSelectionMode
                    ? Text(
                      '${_selectedMessageIds.length} ${AppString.settingStrigs.selected}',
                      style: AppTypography.h220(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    )
                    : Text(
                      _chatName != null
                          ? '$_chatName - Starred Messages'
                          : AppString.settingStrigs.starredMessages,
                      style: AppTypography.h220(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
            actions: [
              Padding(
                padding: AppDirectionality.appDirectionPadding.paddingEnd(10),
                child:
                    (_isUnstarLoad ||
                            _isLoading ||
                            _hasError ||
                            (_starredMessages?.data?.records?.isEmpty ?? true))
                        ? SizedBox.shrink()
                        : _isSelectionMode
                        ? null
                        : InkWell(
                          onTap: () {
                            setState(() {
                              _isSelectionMode = true;
                            });
                          },
                          child: Container(
                            height: SizeConfig.sizedBoxHeight(28),
                            // width: SizeConfig.sizedBoxWidth(63),
                            padding: SizeConfig.getPaddingSymmetric(
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              color: AppColors.appPriSecColor.secondaryColor,
                            ),
                            child: Center(
                              child: Text(
                                AppString.settingStrigs.edit,
                                style: AppTypography.innerText12Mediu(context)
                                    .copyWith(fontWeight: FontWeight.w600)
                                    .copyWith(
                                      color: ThemeColorPalette.getTextColor(
                                        AppColors.appPriSecColor.primaryColor,
                                      ),
                                      // AppColors
                                      //     .textColor
                                      //     .textBlackColor,
                                    ),
                              ),
                            ),
                          ),
                        ),
              ),
            ],
          ),
        ),
        // appBar: PreferredSize(
        //   preferredSize: Size.fromHeight(70),
        //   child: AppBar(
        //     elevation: 0,
        //     scrolledUnderElevation: 0,
        //     automaticallyImplyLeading: false,
        //     shape: Border(
        //       bottom: BorderSide(color: AppColors.shadowColor.cE9E9E9),
        //     ),
        //     backgroundColor: AppColors.transparent,
        //     systemOverlayStyle: systemUI(),
        //     flexibleSpace: flexibleSpace(),
        //     leading: Padding(
        //       padding: SizeConfig.getPadding(16),
        //       child:
        //           _isSelectionMode
        //               ? InkWell(
        //                 onTap: () {
        //                   setState(() {
        //                     _isSelectionMode = false;
        //                     _selectedMessageIds.clear();
        //                     _isBottomPanelVisible = false;
        //                   });
        //                 },
        //                 child: Icon(Icons.close),
        //               )
        //               : customeBackArrowBalck(context),
        //     ),
        //     titleSpacing: 1,
        //     title:
        //         _isSelectionMode
        //             ? Text(
        //               '${_selectedMessageIds.length} selected',
        //               style: AppTypography.h3(context),
        //             )
        //             : Text(
        //               _chatName != null
        //                   ? '$_chatName - Starred Messages'
        //                   : AppString.settingStrigs.starredMessages,
        //               style: AppTypography.h3(context),
        //             ),
        //     actions: [
        //       Padding(
        //         padding: SizeConfig.getPaddingOnly(right: 10),
        //         child:
        //             (_isUnstarLoad ||
        //                     _isLoading ||
        //                     _hasError ||
        //                     (_starredMessages?.data?.records?.isEmpty ?? true))
        //                 ? SizedBox.shrink()
        //                 : _isSelectionMode
        //                 ? null
        //                 // IconButton(
        //                 //   icon: Icon(Icons.star_border),
        //                 //   onPressed: () {
        //                 //     if (_selectedMessageIds.length == 1) {
        //                 //       _unstarMessage(_selectedMessageIds.first);
        //                 //     } else {
        //                 //       _unstarSelectedMessages();
        //                 //     }
        //                 //   },
        //                 // )
        //                 : InkWell(
        //                   onTap: () {
        //                     setState(() {
        //                       _isSelectionMode = true;
        //                     });
        //                   },
        //                   child: Container(
        //                     height: SizeConfig.sizedBoxHeight(28),
        //                     width: SizeConfig.sizedBoxWidth(63),
        //                     decoration: BoxDecoration(
        //                       borderRadius: BorderRadius.circular(13),
        //                       color: AppColors.appPriSecColor.secondaryColor,
        //                     ),
        //                     child: Center(
        //                       child: Text(
        //                         AppString.settingStrigs.edit,
        //                         style: AppTypography.text12(context).copyWith(
        //                           fontWeight: FontWeight.w600,
        //                           fontSize: SizeConfig.getFontSize(10),
        //                         ),
        //                       ),
        //                     ),
        //                   ),
        //                 ),
        //       ),
        //     ],
        //   ),
        // ),
        body: Stack(
          children: [
            _isLoading
                ? Center(child: commonLoading())
                : _hasError
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        AppAssets.svgIcons.internet,
                        height: 100,
                        colorFilter: ColorFilter.mode(
                          AppColors.appPriSecColor.primaryColor,
                          BlendMode.srcIn,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        AppString.failedToLoadStarredMessages,
                        style: AppTypography.h4(context),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _errorMessage ?? 'Unknown error occurred',
                        style: AppTypography.captionText(
                          context,
                        ).copyWith(color: AppColors.textColor.textGreyColor),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStarredMessages,
                        child: Text(AppString.retry),
                      ),
                    ],
                  ),
                )
                : _starredMessages?.data?.records?.isEmpty ?? true
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        AppAssets.emptyDataIcons.noStarList,
                        color: AppColors.appPriSecColor.secondaryColor,
                      ),
                      SizedBox(height: 16),
                      Text(
                        AppString.emptyDataString.noStarMessage,
                        style: AppTypography.h3(context),
                      ),
                      SizedBox(height: 8),
                      Text(
                        AppString.emptyDataString.youdonthaveStarMessage,
                        style: AppTypography.innerText12Ragu(
                          context,
                        ).copyWith(color: AppColors.textColor.textGreyColor),
                      ),
                    ],
                  ),
                )
                : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount:
                            (_starredMessages?.data?.records?.length ?? 0) +
                            (_isLoadingMore ? 1 : 0),
                        padding: EdgeInsets.only(
                          top: SizeConfig.getPadding(8).top,
                          bottom:
                              _isBottomPanelVisible
                                  ? SizeConfig.sizedBoxHeight(150) +
                                      MediaQuery.of(context).padding.bottom
                                  : SizeConfig.getPadding(8).bottom +
                                      MediaQuery.of(context).padding.bottom,
                        ),
                        itemBuilder: (context, index) {
                          final messages =
                              _starredMessages?.data?.records ?? [];

                          if (index == messages.length) {
                            return Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: commonLoading()),
                            );
                          }

                          final message = messages[index];

                          if (index == messages.length - 1 &&
                              _hasMorePages &&
                              !_isLoadingMore) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _loadStarredMessages(loadMore: true);
                            });
                          }

                          return _buildStarredMessageTile(message);
                        },
                      ),
                    ),
                  ],
                ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomPanel(),
            ),

            _isUnstarLoad
                ? ModalBarrier(
                  dismissible: false,
                  color: Colors.black.withValues(alpha: 0.5),
                )
                : SizedBox.shrink(),
            _isUnstarLoad ? _buildUnstarLoader(context) : SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

Widget _buildUnstarLoader(BuildContext context) {
  return Center(
    child: Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.starredOppa,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Text(
              AppString.unstarringMessages,
              style: AppTypography.innerText14(context),
            ),
          ),

          SizedBox(height: 25, width: 25, child: commonLoading()),
        ],
      ),
    ),
  );
}
// // ignore_for_file: deprecated_member_use

// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:get_it/get_it.dart';
// import 'package:intl/intl.dart';
// import 'package:whoxa/featuers/chat/data/starred_messages_model.dart';
// import 'package:whoxa/featuers/chat/repository/chat_repository.dart';
// import 'package:whoxa/utils/app_size_config.dart';
// import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
// import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
// import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
// import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
// import 'package:whoxa/utils/preference_key/constant/strings.dart';
// import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
// import 'package:whoxa/widgets/global.dart';

// class StarredMessagesScreen extends StatefulWidget {
//   final int? chatId;
//   final String? chatName;

//   const StarredMessagesScreen({super.key, this.chatId, this.chatName});

//   @override
//   State<StarredMessagesScreen> createState() => _StarredMessagesScreenState();
// }

// class _StarredMessagesScreenState extends State<StarredMessagesScreen> {
//   final ChatRepository _chatRepository = GetIt.instance<ChatRepository>();
//   starred.StarredMessagesResponse? _starredMessages;
//   bool _isLoading = true;
//   bool _hasError = false;
//   String? _errorMessage;
//   int _currentPage = 1;
//   bool _hasMorePages = false;
//   bool _isLoadingMore = false;

//   // Chat-specific parameters
//   int? _chatId;
//   String? _chatName;

//   bool _hasInitialized = false;

//   @override
//   void initState() {
//     super.initState();
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     if (!_hasInitialized) {
//       _extractRouteArguments();
//       _hasInitialized = true;
//       // Delay the API call to ensure arguments are extracted
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         _loadStarredMessages();
//       });
//     }
//   }

//   void _extractRouteArguments() {
//     // First check widget parameters (constructor)
//     if (widget.chatId != null) {
//       _chatId = widget.chatId;
//       _chatName = widget.chatName;
//       debugPrint(
//         'DEBUG: Using widget parameters - chatId: $_chatId, chatName: $_chatName',
//       );
//       return;
//     }

//     // Fallback to route arguments (for backward compatibility)
//     final arguments =
//         ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
//     if (arguments != null) {
//       _chatId = arguments['chatId'] as int?;
//       _chatName = arguments['chatName'] as String?;
//       debugPrint(
//         'DEBUG: Extracted from route args - chatId: $_chatId, chatName: $_chatName',
//       );
//     } else {
//       debugPrint(
//         'DEBUG: No chat-specific arguments found, showing all starred messages',
//       );
//     }
//   }

//   Future<void> _loadStarredMessages({bool loadMore = false}) async {
//     if (loadMore) {
//       setState(() => _isLoadingMore = true);
//     } else {
//       setState(() {
//         _isLoading = true;
//         _hasError = false;
//         _errorMessage = null;
//       });
//     }

//     try {
//       final page = loadMore ? _currentPage + 1 : 1;
//       debugPrint(
//         'DEBUG: About to call getStarredMessages with page: $page, chatId: $_chatId',
//       );
//       final response = await _chatRepository.getStarredMessages(
//         page: page,
//         chatId: _chatId,
//       );

//       if (response != null && response.status == true) {
//         setState(() {
//           if (loadMore) {
//             // Append new messages to existing list
//             _starredMessages?.data?.records?.addAll(
//               response.data?.records ?? [],
//             );
//             _currentPage = page;
//           } else {
//             // Replace with new data
//             _starredMessages = response;
//             _currentPage = 1;
//           }

//           // Check if there are more pages
//           final pagination = response.data?.pagination;
//           _hasMorePages =
//               pagination != null &&
//               pagination.currentPage != null &&
//               pagination.totalPages != null &&
//               pagination.currentPage! < pagination.totalPages!;

//           _isLoading = false;
//           _isLoadingMore = false;
//           _hasError = false;
//         });
//       } else {
//         setState(() {
//           _hasError = true;
//           _errorMessage =
//               response?.message ?? AppString.failedToLoadStarredMessages;
//           _isLoading = false;
//           _isLoadingMore = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _hasError = true;
//         _errorMessage = e.toString();
//         _isLoading = false;
//         _isLoadingMore = false;
//       });
//     }
//   }

//   void _onMessageTap(starred.StarredMessageRecord message) {
//     // Navigate to the chat where this message belongs
//     if (message.chatId != null) {
//       Navigator.pushNamed(
//         context,
//         AppRoutes.universalChat,
//         arguments: {
//           'chatId': message.chatId,
//           'chatName':
//               message.chat?.groupName ?? message.user?.fullName ?? 'Chat',
//           'isGroupChat': message.chat?.chatType == 'group',
//           'profilePic': message.chat?.groupIcon ?? message.user?.profilePic,
//           'userId':
//               message.chat?.chatType == 'group' ? null : message.user?.userId,
//         },
//       );
//     }
//   }

//   Future<void> _unstarMessage(starred.StarredMessageRecord message) async {
//     if (message.messageId == null) return;

//     // Show confirmation dialog
//     final shouldUnstar = await showDialog<bool>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Unstar Message', style: AppTypography.h4(context)),
//           content: Text(
//             'Are you sure you want to unstar this message?',
//             style: AppTypography.captionText(context),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: Text(
//                 'Cancel',
//                 style: AppTypography.captionText(
//                   context,
//                 ).copyWith(color: AppColors.textColor.textGreyColor),
//               ),
//             ),
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(true),
//               child: Text(
//                 'Unstar',
//                 style: AppTypography.captionText(
//                   context,
//                 ).copyWith(color: AppColors.black, fontWeight: FontWeight.w600),
//               ),
//             ),
//           ],
//         );
//       },
//     );

//     if (shouldUnstar == true) {
//       try {
//         final success = await _chatRepository.starUnStarMessage(
//           messageId: message.messageId!,
//         );

//         if (success) {
//           // Remove message from the list
//           setState(() {
//             _starredMessages?.data?.records?.removeWhere(
//               (record) => record.messageId == message.messageId,
//             );
//           });

//           // Show success message
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Message unstarred successfully'),
//               backgroundColor: Colors.green,
//               duration: Duration(seconds: 2),
//             ),
//           );
//         } else {
//           // Show error message
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Failed to unstar message'),
//               backgroundColor: Colors.red,
//               duration: Duration(seconds: 2),
//             ),
//           );
//         }
//       } catch (e) {
//         // Show error message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error: ${e.toString()}'),
//             backgroundColor: Colors.red,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//     }
//   }

//   void _showMessageOptions(starred.StarredMessageRecord message) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: AppColors.transparent,
//       barrierColor: AppColors.transparent,
//       builder: (BuildContext context) {
//         return Container(
//           height: SizeConfig.sizedBoxHeight(150),
//           padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 20),
//           decoration: BoxDecoration(
//             gradient: AppColors.gradientColor.starredColor,
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.end,
//             children: [
//               // ListTile(
//               //   leading: Icon(
//               //     Icons.chat,
//               //     color: AppColors.textColor.textGreyColor,
//               //   ),
//               //   title: Text(
//               //     'Go to Chat',
//               //     style: AppTypography.captionText(
//               //       context,
//               //     ).copyWith(fontSize: SizeConfig.getFontSize(16)),
//               //   ),
//               //   onTap: () {
//               //     Navigator.pop(context);
//               //     _onMessageTap(message);
//               //   },
//               // ),
//               Padding(
//                 padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     GestureDetector(
//                       onTap: () {
//                         Navigator.pop(context);
//                         _unstarMessage(message);
//                       },
//                       child: SvgPicture.asset(
//                         AppAssets.starredMessageIcon.starslash,
//                         height: SizeConfig.sizedBoxHeight(24),
//                       ),
//                     ),
//                     SvgPicture.asset(
//                       AppAssets.groupProfielIcons.trash1,
//                       color: AppColors.black,
//                       height: SizeConfig.sizedBoxHeight(24),
//                     ),
//                     SvgPicture.asset(
//                       AppAssets.starredMessageIcon.shareIcon,
//                       color: AppColors.black,
//                       height: SizeConfig.sizedBoxHeight(24),
//                     ),
//                   ],
//                 ),
//               ),
//               SizedBox(height: 15),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   String formatUtcToTime(String utcString) {
//     DateTime utcDate = DateTime.parse(utcString).toUtc();
//     DateTime localDate = utcDate.toLocal();
//     return DateFormat('hh:mm a').format(localDate);
//   }

//   String formatUtcToDdMmYyyy(String utcString) {
//     // Parse UTC string
//     DateTime utcDate = DateTime.parse(utcString).toUtc();

//     // Convert to local time
//     DateTime localDate = utcDate.toLocal();

//     // Format to DD/MM/YYYY
//     return DateFormat('dd/MM/yyyy').format(localDate);
//   }

//   String _formatTimestamp(String? timestamp) {
//     if (timestamp == null) return '';

//     try {
//       final dateTime = DateTime.parse(timestamp);
//       final now = DateTime.now();
//       final difference = now.difference(dateTime);

//       if (difference.inDays > 0) {
//         return '${difference.inDays}d ago';
//       } else if (difference.inHours > 0) {
//         return '${difference.inHours}h ago';
//       } else if (difference.inMinutes > 0) {
//         return '${difference.inMinutes}m ago';
//       } else {
//         return 'Just now';
//       }
//     } catch (e) {
//       return '';
//     }
//   }

//   Widget _buildStarredMessageTile(starred.StarredMessageRecord message) {
//     final hasChat = message.chat != null;
//     final isGroupChat = message.chat?.chatType == 'group';

//     return Container(
//       margin: SizeConfig.getPaddingSymmetric(horizontal: 0, vertical: 8),
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         border: Border(
//           top: BorderSide(
//             color: AppColors.strokeColor.greyColor.withValues(alpha: 0.1),
//           ),
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: AppColors.black.withValues(alpha: 0.06),
//             blurRadius: 5,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: InkWell(
//         onTap: () => _onMessageTap(message),
//         onLongPress: () => _showMessageOptions(message),
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Chat info header
//               if (hasChat) ...[
//                 Row(
//                   children: [
//                     if (message.user != null) ...[
//                       Container(
//                         width: 31,
//                         height: 31,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           border: Border.all(
//                             color: AppColors.strokeColor.greyColor.withValues(alpha:
//                               0.3,
//                             ),
//                           ),
//                         ),
//                         child: ClipOval(
//                           child:
//                               message.user!.profilePic != null
//                                   ? CachedNetworkImage(
//                                     imageUrl: message.user!.profilePic!,
//                                     fit: BoxFit.cover,
//                                     errorWidget: (context, url, error) {
//                                       return Container(
//                                         color: AppColors.bgColor.bg2Color,
//                                         child: Icon(
//                                           Icons.person,
//                                           size: 12,
//                                           color:
//                                               AppColors.textColor.textGreyColor,
//                                         ),
//                                       );
//                                     },
//                                   )
//                                   : Container(
//                                     color: AppColors.bgColor.bg2Color,
//                                     child: Icon(
//                                       Icons.person,
//                                       size: 12,
//                                       color: AppColors.textColor.textGreyColor,
//                                     ),
//                                   ),
//                         ),
//                       ),
//                       SizedBox(width: 8),
//                     ],
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // Sender name and timestamp
//                           Row(
//                             children: [
//                               isGroupChat
//                                   ? Text(
//                                     message.chat?.groupName ?? 'Unknown Chat',
//                                     style: AppTypography.innerText11(
//                                       context,
//                                     ).copyWith(
//                                       color: AppColors.textColor.textBlackColor,
//                                     ),
//                                   )
//                                   : SizedBox.shrink(),
//                               isGroupChat
//                                   ? Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 3,
//                                     ),
//                                     child: Icon(
//                                       Icons.play_arrow_rounded,
//                                       size: 15,
//                                     ),
//                                   )
//                                   : SizedBox.shrink(),
//                               Text(
//                                 message.user?.fullName ?? 'Unknown User',
//                                 style: AppTypography.innerText11(
//                                   context,
//                                 ).copyWith(
//                                   color: AppColors.textColor.textBlackColor,
//                                 ),
//                               ),
//                               Spacer(),
//                               Text(
//                                 formatUtcToDdMmYyyy(message.createdAt ?? ''),
//                                 style: AppTypography.innerText10(
//                                   context,
//                                 ).copyWith(
//                                   color: AppColors.textColor.text808080,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),

//                 SizedBox(height: 16),
//               ],

//               // Message content
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Message content
//                   Expanded(
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Flexible(child: _buildMessageContent(message)),
//                         Icon(
//                           Icons.chevron_right_rounded,
//                           color: AppColors.textColor.text808080,
//                         ),
//                       ],
//                     ),
//                   ),

//                   // Forward indicator
//                   if (message.forwardedFrom != null &&
//                       message.forwardedFrom! > 0) ...[
//                     SizedBox(width: 8),
//                     Icon(
//                       Icons.forward,
//                       size: 14,
//                       color: AppColors.textColor.textGreyColor,
//                     ),
//                   ],
//                 ],
//               ),

//               SizedBox(height: SizeConfig.sizedBoxHeight(8)),
//               // Time HH:MM
//               Row(
//                 children: [
//                   Text(
//                     formatUtcToTime(message.createdAt ?? ''),
//                     style: AppTypography.innerText10(
//                       context,
//                     ).copyWith(color: AppColors.textColor.text808080),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.only(left: 3),
//                     child: SvgPicture.asset(
//                       AppAssets.chatImage.start,
//                       colorFilter: ColorFilter.mode(
//                         AppColors.appPriSecColor.primaryColor,
//                         BlendMode.srcIn,
//                       ),
//                       height: SizeConfig.sizedBoxHeight(10),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildMessageContent(starred.StarredMessageRecord message) {
//     switch (message.messageType) {
//       case 'text':
//         return Text(
//           message.messageContent ?? '',
//           style: AppTypography.captionText(
//             context,
//           ).copyWith(fontSize: SizeConfig.getFontSize(14)),
//           maxLines: 3,
//           overflow: TextOverflow.ellipsis,
//         );
//       case 'image':
//         return Row(
//           children: [
//             Icon(
//               Icons.image,
//               size: 16,
//               color: AppColors.textColor.textGreyColor,
//             ),
//             SizedBox(width: 4),
//             Text(
//               'Photo',
//               style: AppTypography.captionText(context).copyWith(
//                 fontSize: SizeConfig.getFontSize(14),
//                 fontStyle: FontStyle.italic,
//               ),
//             ),
//           ],
//         );
//       case 'video':
//         return Row(
//           children: [
//             Icon(
//               Icons.videocam,
//               size: 16,
//               color: AppColors.textColor.textGreyColor,
//             ),
//             SizedBox(width: 4),
//             Text(
//               'Video',
//               style: AppTypography.captionText(context).copyWith(
//                 fontSize: SizeConfig.getFontSize(14),
//                 fontStyle: FontStyle.italic,
//               ),
//             ),
//           ],
//         );
//       case 'document':
//         return Row(
//           children: [
//             Icon(
//               Icons.insert_drive_file,
//               size: 16,
//               color: AppColors.textColor.textGreyColor,
//             ),
//             SizedBox(width: 4),
//             Text(
//               'Document',
//               style: AppTypography.captionText(context).copyWith(
//                 fontSize: SizeConfig.getFontSize(14),
//                 fontStyle: FontStyle.italic,
//               ),
//             ),
//           ],
//         );
//       case 'audio':
//         return Row(
//           children: [
//             Icon(
//               Icons.audiotrack,
//               size: 16,
//               color: AppColors.textColor.textGreyColor,
//             ),
//             SizedBox(width: 4),
//             Text(
//               'Audio',
//               style: AppTypography.captionText(context).copyWith(
//                 fontSize: SizeConfig.getFontSize(14),
//                 fontStyle: FontStyle.italic,
//               ),
//             ),
//           ],
//         );
//       default:
//         return Text(
//           message.messageContent ?? 'Unsupported message type',
//           style: AppTypography.captionText(context).copyWith(
//             fontSize: SizeConfig.getFontSize(14),
//             fontStyle: FontStyle.italic,
//             color: AppColors.textColor.textGreyColor,
//           ),
//         );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.bgColor.bg4Color,
//       appBar: PreferredSize(
//         preferredSize: Size.fromHeight(70),
//         child: AppBar(
//           elevation: 0,
//           scrolledUnderElevation: 0,
//           automaticallyImplyLeading: false,
//           shape: Border(
//             bottom: BorderSide(color: AppColors.shadowColor.cE9E9E9),
//           ),
//           backgroundColor: AppColors.transparent,
//           systemOverlayStyle: systemUI(),
//           flexibleSpace: flexibleSpace(),
//           leading: Padding(
//             padding: SizeConfig.getPadding(16),
//             child: customeBackArrowBalck(context),
//           ),
//           titleSpacing: 1,
//           title: Text(
//             _chatName != null
//                 ? '$_chatName - Starred Messages'
//                 : AppString.settingStrigs.starredMessages,
//             style: AppTypography.h3(context),
//           ),
//           actions: [
//             Padding(
//               padding: SizeConfig.getPaddingOnly(right: 10),
//               child: InkWell(
//                 onTap: () {},
//                 child: Container(
//                   height: SizeConfig.sizedBoxHeight(28),
//                   width: SizeConfig.sizedBoxWidth(63),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(13),
//                     color: AppColors.appPriSecColor.secondaryColor,
//                   ),
//                   child: Center(
//                     child: Text(
//                       AppString.settingStrigs.edit,
//                       style: AppTypography.text12(context).copyWith(
//                         fontWeight: FontWeight.w600,
//                         fontSize: SizeConfig.getFontSize(10),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//       body:
//           _isLoading
//               ? const Center(child: CircularProgressIndicator())
//               : _hasError
//               ? Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     SvgPicture.asset(AppAssets.svgIcons.internet, height: 100),
//                     SizedBox(height: 16),
//                     Text(
//                       AppString.failedToLoadStarredMessages,
//                       style: AppTypography.h4(context),
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       _errorMessage ?? 'Unknown error occurred',
//                       style: AppTypography.captionText(
//                         context,
//                       ).copyWith(color: AppColors.textColor.textGreyColor),
//                       textAlign: TextAlign.center,
//                     ),
//                     SizedBox(height: 16),
//                     ElevatedButton(
//                       onPressed: _loadStarredMessages,
//                       child: Text('Retry'),
//                     ),
//                   ],
//                 ),
//               )
//               : _starredMessages?.data?.records?.isEmpty ?? true
//               ? Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     SvgPicture.asset(AppAssets.emptyDataIcons.noStarList),
//                     SizedBox(height: 16),
//                     Text(
//                       AppString.emptyDataString.noStarMessage,
//                       style: AppTypography.h3(context),
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       AppString.emptyDataString.youdonthaveStarMessage,
//                       style: AppTypography.innerText12Ragu(
//                         context,
//                       ).copyWith(color: AppColors.textColor.textGreyColor),
//                     ),
//                   ],
//                 ),
//               )
//               : Column(
//                 children: [
//                   Expanded(
//                     child: ListView.builder(
//                       itemCount:
//                           (_starredMessages?.data?.records?.length ?? 0) +
//                           (_isLoadingMore ? 1 : 0),
//                       padding: SizeConfig.getPaddingSymmetric(vertical: 8),
//                       itemBuilder: (context, index) {
//                         final messages = _starredMessages?.data?.records ?? [];

//                         // Show loading indicator at the end
//                         if (index == messages.length) {
//                           return const Padding(
//                             padding: EdgeInsets.all(16.0),
//                             child: Center(child: CircularProgressIndicator()),
//                           );
//                         }

//                         final message = messages[index];

//                         // Load more when reaching the end
//                         if (index == messages.length - 1 &&
//                             _hasMorePages &&
//                             !_isLoadingMore) {
//                           WidgetsBinding.instance.addPostFrameCallback((_) {
//                             _loadStarredMessages(loadMore: true);
//                           });
//                         }

//                         return _buildStarredMessageTile(message);
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//     );
//   }
// }
