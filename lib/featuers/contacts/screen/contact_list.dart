// ignore_for_file: use_build_context_synchronously, duplicate_ignore

import 'dart:io';
import 'package:whoxa/featuers/contacts/screen/save_contact.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/featuers/chat/forward/chat_list_forward_manager.dart';
import 'package:whoxa/featuers/chat/group/provider/group_provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
import 'package:whoxa/featuers/contacts/widgets/contact_list_item.dart';
import 'package:whoxa/featuers/home/widgets/chat_lock_pin.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/main.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_constant.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/widgets/global_textfield.dart';

class ContactListScreen extends StatefulWidget {
  final bool createGroupMode;
  final bool isAddMemberMode;
  final bool isForwardMode;
  final bool isForAddMoreMember;
  final int? groupId;
  final List<int>? existingMemberIds;
  final Function(int chatId, String chatName)? onChatSelected;

  // NEW: Forward mode specific parameters
  final List<int>? selectedMessageIds;
  final int? fromChatId;
  final String? forwardTitle; // Optional custom title
  final VoidCallback?
  onForwardCompleted; // Callback to disable multi-select mode

  const ContactListScreen({
    super.key,
    this.createGroupMode = false,
    this.isAddMemberMode = false,
    this.isForwardMode = false,
    this.isForAddMoreMember = false,
    this.groupId,
    this.existingMemberIds,
    this.onChatSelected,
    this.selectedMessageIds,
    this.fromChatId,
    this.forwardTitle,
    this.onForwardCompleted,
  });

  @override
  State<ContactListScreen> createState() => _ContactListScreenV2State();
}

class _ContactListScreenV2State extends State<ContactListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ContactListProvider _contactListProvider;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  // final List<int> _selectedIds = [];
  File? _selectedGroupImage;

  @override
  void initState() {
    logger.i("😊USER_MOBILE_NUMBER😊:$mobileNum");
    debugPrint("isForAddMoreMember ${widget.isForAddMoreMember}");
    super.initState();

    if (!widget.createGroupMode) {
      Provider.of<ContactListProvider>(context, listen: false).selectedUserIds =
          [];
    }

    // Initialize tab controller based on mode
    int tabLength = 2; // Default for normal mode
    if (widget.createGroupMode || widget.isAddMemberMode) {
      tabLength = 1; // Only one tab for these modes
    } else if (widget.isForwardMode) {
      tabLength = 1; // Forward mode uses its own UI
    }

    _tabController = TabController(length: tabLength, vsync: this);

    _tabController.addListener(() {
      Provider.of<ContactListProvider>(
        context,
        listen: false,
      ).updateTabIndex(_tabController.index);
    });
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isForwardMode) {
        _contactListProvider = Provider.of<ContactListProvider>(
          context,
          listen: false,
        );
        // ✅ Use initializeContacts() - loads from cache instantly, syncs in background
        // Only runs full sync if not already initialized (prevents redundant API calls)
        _contactListProvider.initializeContacts();
      }
      // Note: In forward mode, ChatListForwardManager handles its own data loading
    });
  }

  void _onSearchChanged() {
    if (!widget.isForwardMode) {
      Provider.of<ContactListProvider>(
        context,
        listen: false,
      ).searchContacts(_searchController.text);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _groupNameCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    // Route to appropriate mode
    if (widget.isForwardMode) {
      return _buildForwardModeV2();
    } else if (widget.createGroupMode) {
      return _buildCreateGroupMode();
    } else if (widget.isAddMemberMode) {
      // return _buildAddMemberMode();
      return _buildAppBarForAddMember();
    } else {
      return _buildNormalMode();
    }
  }

  void unfocusKeyboard() {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus!.unfocus();
  }

  // ==================== FORWARD MODE V2 ====================
  Widget _buildForwardModeV2() {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: _buildForwardAppBar(),
      body: ChatListForwardManager(
        showForwardButton: true,
        selectedMessageIds:
            widget.selectedMessageIds, // NEW: Pass the message IDs
        fromChatId: widget.fromChatId, // NEW: Pass the from chat ID
        onSelectionChanged: (chatIds, userIds) {
          debugPrint('check ids: ${widget.selectedMessageIds}');
          // Handle selection changes for UI updates
          debugPrint(
            '📊 Forward selection - Chats: ${chatIds.length}, Users: ${userIds.length}',
          );
        },
        onForwardPressed: (chatIds, userIds) {
          // Handle the forward button press
          debugPrint('forward clicked');
          _handleForwardMessages(chatIds, userIds);
        },
        onItemTap: (item) {
          // Handle individual item tap (optional for single forward)
          debugPrint('👆 Item tapped: ${item.name} (${item.type})');
        },
      ),
    );
  }

  PreferredSizeWidget _buildForwardAppBar() {
    return AppBar(
      // backgroundColor: AppColors.appPriSecColor.primaryColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      shape: Border(
        bottom: BorderSide(color: AppThemeManage.appTheme.borderColor),
      ),
      backgroundColor: AppColors.transparent,
      systemOverlayStyle: systemUI(),
      leading: Padding(
        padding: SizeConfig.getPadding(12),
        child: customeBackArrowBalck(context),
      ),
      title: Text(
        widget.forwardTitle ?? AppString.forwardMessages1,
        style: AppTypography.h220(
          context,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
      actions: [
        // if (widget.selectedMessageIds?.isNotEmpty == true)
        //   Container(
        //     margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
        //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        //     decoration: BoxDecoration(
        //       color: AppColors.appPriSecColor.secondaryColor,
        //       borderRadius: BorderRadius.circular(20),
        //       border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        //     ),
        //     child: Row(
        //       mainAxisSize: MainAxisSize.min,
        //       children: [
        //         const Icon(Icons.forward, color: Colors.black, size: 16),
        //         const SizedBox(width: 4),
        //         Text(
        //           '${widget.selectedMessageIds!.length}',
        //           style: AppTypography.smallText(
        //             context,
        //           ).copyWith(color: Colors.black, fontWeight: FontWeight.w600),
        //         ),
        //       ],
        //     ),
        //   ),
      ],
    );
  }

  // Handle forward messages with enhanced reliability - FIXED VERSION
  Future<void> _handleForwardMessages(
    List<int> chatIds,
    List<int> userIds,
  ) async {
    if ((chatIds.isEmpty && userIds.isEmpty) ||
        widget.selectedMessageIds?.isEmpty == true) {
      Navigator.of(context).pop();
      return;
    }

    // Show loading dialog
    _showLoadingDialog(
      'Forwarding ${widget.selectedMessageIds!.length} message${widget.selectedMessageIds!.length != 1 ? 's' : ''} to ${chatIds.length + userIds.length} recipient${(chatIds.length + userIds.length) != 1 ? 's' : ''}...',
    );

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      int successCount = 0;
      int totalAttempts = 0;
      List<String> errors = [];

      debugPrint('🚀 Starting reliable forward process');
      debugPrint(
        '📋 Selected: ${chatIds.length} existing chats, ${userIds.length} new contacts',
      );
      debugPrint(
        '📨 Messages to forward: ${widget.selectedMessageIds!.length}',
      );

      // Forward to existing chats - ONE BY ONE
      for (int chatIndex = 0; chatIndex < chatIds.length; chatIndex++) {
        final chatId = chatIds[chatIndex];
        debugPrint(
          '📤 Processing existing chat ${chatIndex + 1}/${chatIds.length} (ID: $chatId)',
        );

        for (
          int msgIndex = 0;
          msgIndex < widget.selectedMessageIds!.length;
          msgIndex++
        ) {
          final messageId = widget.selectedMessageIds![msgIndex];
          totalAttempts++;

          try {
            debugPrint(
              '  📩 Forwarding message $messageId to chat $chatId (${msgIndex + 1}/${widget.selectedMessageIds!.length})',
            );

            final success = await chatProvider.forwardMessage(
              fromChatId: widget.fromChatId ?? 0,
              toChatId: chatId,
              messageId: messageId,
            );

            if (success) {
              successCount++;
              debugPrint('  ✅ Success: Message $messageId → Chat $chatId');
            } else {
              errors.add('Failed to forward message to existing chat $chatId');
              debugPrint('  ❌ Failed: Message $messageId → Chat $chatId');
            }
          } catch (e) {
            errors.add('Error forwarding to chat $chatId: ${e.toString()}');
            debugPrint('  ❌ Exception: Message $messageId → Chat $chatId: $e');
          }

          // Small delay between messages
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // Delay between different chats
        if (chatIndex < chatIds.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // Forward to new chats (contacts) - ONE BY ONE
      for (int userIndex = 0; userIndex < userIds.length; userIndex++) {
        final userId = userIds[userIndex];
        debugPrint(
          '📤 Processing new contact ${userIndex + 1}/${userIds.length} (ID: $userId)',
        );

        for (
          int msgIndex = 0;
          msgIndex < widget.selectedMessageIds!.length;
          msgIndex++
        ) {
          final messageId = widget.selectedMessageIds![msgIndex];
          totalAttempts++;

          try {
            debugPrint(
              '  📩 Forwarding message $messageId to user $userId (${msgIndex + 1}/${widget.selectedMessageIds!.length})',
            );

            final success = await chatProvider.forwardMessageToUser(
              fromChatId: widget.fromChatId ?? 0,
              toUserId: userId,
              messageId: messageId,
            );

            if (success) {
              successCount++;
              debugPrint('  ✅ Success: Message $messageId → User $userId');
            } else {
              errors.add('Failed to forward message to user $userId');
              debugPrint('  ❌ Failed: Message $messageId → User $userId');
            }
          } catch (e) {
            errors.add('Error forwarding to user $userId: ${e.toString()}');
            debugPrint('  ❌ Exception: Message $messageId → User $userId: $e');
          }

          // Small delay between messages
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // Delay between different users
        if (userIndex < userIds.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // Close loading dialog
      _closeLoadingDialog();

      debugPrint(
        '📊 Forward process complete: $successCount/$totalAttempts successful',
      );

      // Refresh chat list if any forwards succeeded
      if (successCount > 0) {
        debugPrint('🔄 Refreshing chat list...');
        await chatProvider.refreshChatList();
        debugPrint('✅ Chat list refreshed');
      }

      // Show result and navigate
      if (successCount == totalAttempts) {
        // All successful
        if (widget.onForwardCompleted != null) widget.onForwardCompleted!();
        if (!context.mounted) return;
        Navigator.of(
          context,
        ).pop(); // Close forward screen // ignore: use_build_context_synchronously
        _navigateToChatListWithRefresh(); // Go to chat list

        // Show success message
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          // ignore: use_build_context_synchronously
          SnackBar(
            content: Text(
              'Successfully forwarded to all ${chatIds.length + userIds.length} recipients!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (successCount > 0) {
        // Partial success
        _showForwardPartialSuccessDialog(successCount, totalAttempts, errors);
      } else {
        // All failed
        _showForwardErrorDialog(AppString.failedToForwardAnyMessages, errors);
      }
    } catch (e) {
      // Close loading dialog on critical error
      _closeLoadingDialog();

      debugPrint('❌ Critical error in forward process: $e');
      _showForwardErrorDialog(AppString.anUnexpectedErrorOccurred, [
        e.toString(),
      ]);
    }
  }

  // ==================== DIALOG HELPERS ====================
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppThemeManage.appTheme.darkGreyColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(width: 24, height: 24, child: commonLoading()),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      message,
                      style: AppTypography.mediumText(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _closeLoadingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // ignore: unused_element
  void _showForwardSuccessDialog(int messageCount, int recipientCount) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppString.success1,
                    style: AppTypography.h4(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppString.successfullyForwarded} ${widget.selectedMessageIds?.length ?? 0} ${AppString.messageto} $recipientCount ${AppString.recipient}.',
                  style: AppTypography.mediumText(context),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppString.allMessagesHaveBeenDeliveredSuccessfully,
                          style: AppTypography.smallText(
                            context,
                          ).copyWith(color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Close forward screen

                  // Disable multiple select mode in the originating chat screen
                  if (widget.onForwardCompleted != null) {
                    widget.onForwardCompleted!();
                  }

                  // Navigate back to chat list and refresh
                  _navigateToChatListWithRefresh();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppString.done,
                  style: AppTypography.buttonText(
                    context,
                  ).copyWith(color: Colors.green, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  void _navigateToChatListWithRefresh() {
    // Navigate back to the main chat list screen and trigger refresh
    // Pop until we get back to the chat list (home screen)
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Optionally, you can also use pushNamedAndRemoveUntil if you need to navigate to a specific route
    // Navigator.of(context).pushNamedAndRemoveUntil(
    //   AppRoutes.home,
    //   (route) => false,
    // );
  }

  void _showForwardPartialSuccessDialog(
    int successCount,
    int totalAttempts,
    List<String> errors,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppString.partialSuccess,
                    style: AppTypography.h4(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppString.successfullyForwarded} $successCount ${AppString.outof} $totalAttempts ${AppString.members}.',
                    style: AppTypography.mediumText(context),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${AppString.someForwardsFailed}:',
                              style: AppTypography.smallText(context).copyWith(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...errors
                            .take(3)
                            .map(
                              (error) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• ${_truncateError(error)}',
                                  style: AppTypography.smallText(
                                    context,
                                  ).copyWith(color: Colors.orange.shade600),
                                ),
                              ),
                            ),
                        if (errors.length > 3)
                          Text(
                            '... ${AppString.add} ${errors.length - 3} ${AppString.moreError}',
                            style: AppTypography.smallText(context).copyWith(
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Close forward screen

                  // Disable multiple select mode in the originating chat screen
                  if (widget.onForwardCompleted != null) {
                    widget.onForwardCompleted!();
                  }

                  // Navigate back to chat list and refresh
                  _navigateToChatListWithRefresh();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppString.done,
                  style: AppTypography.buttonText(
                    context,
                  ).copyWith(color: Colors.orange, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  void _showForwardErrorDialog(String title, List<String> errors) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppThemeManage.appTheme.darkGreyColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.error_rounded, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppString.forwardFailed,
                    style: AppTypography.h4(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600, color: Colors.red),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.mediumText(context)),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${AppString.errorDetails}:',
                                style: AppTypography.smallText(
                                  context,
                                ).copyWith(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...errors
                              .take(3)
                              .map(
                                (error) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• ${_truncateError(error)}',
                                    style: AppTypography.smallText(
                                      context,
                                    ).copyWith(color: Colors.red.shade600),
                                  ),
                                ),
                              ),
                          if (errors.length > 3)
                            Text(
                              '... ${AppString.and} ${errors.length - 3} ${AppString.moreError}',
                              style: AppTypography.smallText(context).copyWith(
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppString.ok,
                  style: AppTypography.buttonText(
                    context,
                  ).copyWith(color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  // ignore: unused_element
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _truncateError(String error) {
    return error.length > 60 ? '${error.substring(0, 60)}...' : error;
  }

  // ==================== EXISTING MODES (Keep your existing implementations) ====================

  Widget _buildCreateGroupMode() {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: _buildNormalAppBar(
        title: AppString.createGroup,
        actions: [
          Consumer<ContactListProvider>(
            builder: (context, prov, _) {
              return prov.selectedUserIds.isNotEmpty
                  ? Container(
                    margin: const EdgeInsets.only(right: 16, top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${prov.selectedUserIds.length}',
                          style: AppTypography.smallText(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                  : SizedBox.shrink();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [_buildGroupDetailsSection(), _buildContactsList()],
        ),
      ),
      //  CustomScrollView(
      //   slivers: [
      //     // _buildCreateGroupAppBar(),
      //     SliverToBoxAdapter(child: _buildGroupDetailsSection()),
      //     SliverToBoxAdapter(child: _buildContactsHeader()),

      //   ],
      // ),
      bottomNavigationBar: _buildCreateGroupBottomBar(),
    );
  }

  // Widget _buildAddMemberMode() {
  //   return Scaffold(
  //     backgroundColor: AppColors.bgColor.bg1Color,
  //     body: CustomScrollView(
  //       slivers: [
  //         _buildAddMemberAppBar(),
  //         SliverToBoxAdapter(child: _buildAddMemberHeader()),
  //         _buildAddMemberContactsList(),
  //       ],
  //     ),
  //     bottomNavigationBar: _buildAddMemberBottomBar(),
  //   );
  // }

  PreferredSize _buildNormalAppBar({
    required String title,
    List<Widget>? actions,
  }) {
    return PreferredSize(
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
          title,
          style: AppTypography.h220(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        actions: actions,
      ),
    );
  }

  Widget _buildAppBarForAddMember() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        unfocusKeyboard();
      },
      child: Scaffold(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        appBar: _buildNormalAppBar(
          title: AppString.addMembers,
          actions: [
            Consumer<ContactListProvider>(
              builder: (context, provider, _) {
                return Consumer<GroupProvider>(
                  builder: (context, groupProv, _) {
                    return provider.selectedUserIds.isNotEmpty
                        ? GestureDetector(
                          onTap: () async {
                            if (widget.isForAddMoreMember) {
                              if (groupProv.isMemberActionLoading) {
                                debugPrint("Loading.........");
                              } else {
                                if (widget.groupId != null) {
                                  final added = await groupProv.addGroupMember(
                                    chatId: widget.groupId!,
                                    userIds: provider.selectedUserIds,
                                  );

                                  if (added) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${provider.selectedUserIds.length} ${AppString.memberAddedSuccessfully}',
                                          style: TextStyle(
                                            color:
                                                ThemeColorPalette.getTextColor(
                                                  AppColors
                                                      .appPriSecColor
                                                      .primaryColor,
                                                ),
                                          ),
                                        ),
                                        backgroundColor:
                                            AppColors
                                                .appPriSecColor
                                                .primaryColor,
                                      ),
                                    );
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                  }
                                }
                              }
                            } else {
                              Navigator.of(context).pushNamed(
                                AppRoutes.contactListScreen,
                                arguments: {'createGroupMode': true},
                              );
                            }
                          },
                          child: Padding(
                            padding: AppDirectionality.appDirectionPadding
                                .paddingEnd(15),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.appPriSecColor.secondaryColor,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 6,
                                ),
                                child: Text(
                                  AppString.add,
                                  style: AppTypography.innerText12Mediu(
                                    context,
                                  ).copyWith(
                                    color: ThemeColorPalette.getTextColor(
                                      AppColors.appPriSecColor.primaryColor,
                                    ), // AppColors.textColor.textBlackColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        : SizedBox.shrink();
                  },
                );
              },
            ),
          ],
        ),
        // PreferredSize(
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
        //     titleSpacing: 0,
        //     leading: Padding(
        //       padding: SizeConfig.getPadding(16),
        //       child: customeBackArrowBalck(context),
        //     ),
        //     title: Text(
        //       AppString.ibadahGroupStrings.addMembers,
        //       style: AppTypography.h220(
        //         context,
        //       ).copyWith(fontWeight: FontWeight.w600),
        //     ),

        //     actions: [
        //       Consumer<ContactListProvider>(
        //         builder: (context, provider, _) {
        //           return provider.selectedUserIds.isNotEmpty
        //               ? GestureDetector(
        //                 onTap: () {
        //                   Navigator.of(context).pushNamed(
        //                     AppRoutes.contactListScreen,
        //                     arguments: {'createGroupMode': true},
        //                   );
        //                 },
        //                 child: Padding(
        //                   padding: const EdgeInsets.only(right: 15),
        //                   child: Container(
        //                     decoration: BoxDecoration(
        //                       color: AppColors.appPriSecColor.secondaryColor,
        //                       borderRadius: BorderRadius.circular(13),
        //                     ),
        //                     child: Padding(
        //                       padding: const EdgeInsets.symmetric(
        //                         horizontal: 15,
        //                         vertical: 6,
        //                       ),
        //                       child: Text(
        //                         AppString.next,
        //                         style: AppTypography.innerText12Mediu(context),
        //                       ),
        //                     ),
        //                   ),
        //                 ),
        //               )
        //               : SizedBox.shrink();
        //         },
        //       ),
        //     ],
        //   ),
        // ),
        body: Stack(
          children: [
            _buildAddMemberContactsList(),
            Consumer<GroupProvider>(
              builder: (context, provider, _) {
                return provider.isMemberActionLoading
                    ? ModalBarrier(
                      dismissible: false,
                      color: AppColors.black.withValues(alpha: 0.2),
                    )
                    : SizedBox.shrink();
              },
            ),
            Consumer<GroupProvider>(
              builder: (context, provider, _) {
                return provider.isMemberActionLoading
                    ? _buildAddMember()
                    : SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMember() {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16),
        padding: EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.white,
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
                "${AppString.addingMembers}.",
                style: AppTypography.innerText14(context),
              ),
            ),

            SizedBox(height: 25, width: 25, child: commonLoading()),
          ],
        ),
      ),
    );
  }

  Widget _buildNormalMode() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        unfocusKeyboard();
      },
      child: Scaffold(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: systemUI(),
          title: Text(
            AppString.contactList,
            style: AppTypography.h2(context).copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: AppTypography.fontFamily.poppinsBold,
            ),
          ),
          toolbarHeight: kToolbarHeight,
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SaveContact()),
                );
              },
              icon: Icon(
                Icons.add,
                color: AppColors.appPriSecColor.primaryColor,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: AppColors.appPriSecColor.primaryColor,
              ),
              onPressed: () {
                _contactListProvider.refreshContacts(force: true);
                _searchController.clear();
              },
            ),
            SizedBox(width: 10),
          ],
        ),
        body: Consumer<ContactListProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return Center(child: commonLoading());
            }

            if (provider.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (provider.isInternetIssue)
                      ElevatedButton(
                        onPressed: () => provider.refreshContacts(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.appPriSecColor.primaryColor,
                        ),
                        child: Text(AppString.retry),
                      ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                SizedBox(height: SizeConfig.height(2)),
                // Search bar
                Padding(
                  padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
                  child: SizedBox(
                    height: SizeConfig.height(6),
                    child: searchBar(
                      context,
                      controller1: _searchController,
                      hintText: AppString.searchContacts,
                      onChanged: (value) {
                        _contactListProvider.searchContacts(value);
                      },
                    ),
                  ),
                ),
                SizedBox(height: SizeConfig.height(1)),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.appPriSecColor.primaryColor,
                  labelColor: AppThemeManage.appTheme.textColor,
                  unselectedLabelColor: AppColors.textColor.textDarkGray,
                  onTap: (value) {
                    provider.updateTabIndex(value);
                  },
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: SvgPicture.asset(
                              AppAssets.contactsCard,
                              height: 18,
                              colorFilter: ColorFilter.mode(
                                provider.tabIndex == 0
                                    ? AppThemeManage.appTheme.darkWhiteColor
                                    : AppColors.textColor.textDarkGray,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          Text(AppString.contacts),
                        ],
                      ),
                      // text: 'Contacts'
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: SvgPicture.asset(
                              AppAssets.invitesCard,
                              height: 18,
                              colorFilter: ColorFilter.mode(
                                provider.tabIndex == 1
                                    ? AppThemeManage.appTheme.darkWhiteColor
                                    : AppColors.textColor.textDarkGray,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          Text(AppString.invite),
                        ],
                      ),
                      // text: 'Invites'
                    ),
                  ],
                ),
                SizedBox(height: SizeConfig.height(2)),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Chats tab - for contacts with userId
                      provider.chatContacts.isEmpty
                          ? _buildEmptyState(
                            AppString.noContactsAvailableforChat,
                          )
                          : _buildContactsListNormal(
                            provider.chatContacts,
                            true,
                          ),

                      // Invites tab - for contacts without userId
                      _buildInvitesTab(provider),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==================== INVITES TAB ====================
  Widget _buildInvitesTab(ContactListProvider provider) {
    return Column(
      children: [
        // Invite link section
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.appPriSecColor.primaryColor.withValues(
                alpha: 0.3,
              ),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.link,
                    color: AppColors.appPriSecColor.primaryColor,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    '${AppString.inviteFriendsTo} ${_getAppName()}',
                    style: AppTypography.mediumText(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                AppString.shareThisLinkWithYourFriendsToInviteThemTojoin,
                style: AppTypography.captionText(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
              ),
              SizedBox(height: 16),
              // Invite link container
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppThemeManage.appTheme.darkGreyColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.grey.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getInviteLink(),
                        style: AppTypography.captionText(
                          context,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _copyInviteLink(),
                      child: Icon(
                        Icons.copy,
                        color: AppColors.appPriSecColor.primaryColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareInviteLink(),
                      icon: Icon(Icons.share, size: 18),
                      label: Text(AppString.shareLink),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.appPriSecColor.primaryColor,
                        foregroundColor: AppThemeManage.appTheme.textWhiteBlack,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyInviteLink(),
                      icon: Icon(Icons.copy, size: 18),
                      label: Text(AppString.copyLink),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.appPriSecColor.primaryColor,
                        side: BorderSide(
                          color: AppColors.appPriSecColor.primaryColor,
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Invites list
        Expanded(
          child:
              provider.inviteContacts.isEmpty
                  ? _buildEmptyInvitesState()
                  : _buildContactsListNormal(
                    provider.inviteContacts,
                    false,
                    isForInvite: true,
                  ),
        ),
      ],
    );
  }

  Widget _buildEmptyInvitesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _emptyContactImage(),
            SizedBox(height: 16),
            Text(
              AppString.noContactstoInvite,
              textAlign: TextAlign.center,
              style: AppTypography.h3(context),
            ),
            SizedBox(height: 8),
            // Text(
            //   'Share the invite link above to invite friends',
            //   // style: AppTypography.smallText(context),
            //   style: AppTypography.innerText12Ragu(
            //     context,
            //   ).copyWith(color: AppColors.textColor.textDarkGray),
            //   textAlign: TextAlign.center,
            // ),
          ],
        ),
      ),
    );
  }

  // Returns the store link for the running platform: App Store on iOS,
  // Play Store on Android. Uses the project-config link when set, otherwise
  // falls back to the hard-coded store URL so the field is never empty.
  String _getInviteLink() {
    final configData =
        Provider.of<ProjectConfigProvider>(context, listen: false).configData;

    final iosLink =
        (configData?.appIosLink.isNotEmpty ?? false)
            ? configData!.appIosLink
            : Constants.appStoreLink;
    final androidLink =
        (configData?.appAndroidLink.isNotEmpty ?? false)
            ? configData!.appAndroidLink
            : Constants.playStoreLink;

    return Platform.isIOS ? iosLink : androidLink;
  }

  // Method to get dynamic app name from config API
  String _getAppName() {
    final configProvider = Provider.of<ProjectConfigProvider>(
      context,
      listen: false,
    );
    return configProvider.appName.isNotEmpty
        ? configProvider.appName
        : 'Flickpitch Chat'; // Fallback app name
  }

  void _copyInviteLink() {
    final inviteLink = _getInviteLink();
    Clipboard.setData(ClipboardData(text: inviteLink));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppString.inviteLinkCopiedToClipboard),
        backgroundColor: AppColors.appPriSecColor.primaryColor,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _shareInviteLink() async {
    final inviteLink = _getInviteLink();
    final appName = _getAppName();
    final configProvider = Provider.of<ProjectConfigProvider>(
      context,
      listen: false,
    );
    final configData = configProvider.configData;

    // Use appTellAFriendText from config if available, otherwise use default message
    String message;
    if (configData != null && configData.appTellAFriendText.isNotEmpty) {
      // Replace any placeholders in the config text with actual values
      message = '${configData.appTellAFriendText}\n\n$inviteLink';
    } else {
      message =
          'Join me on $appName! Download the app and start chatting: $inviteLink';
    }

    // ignore: deprecated_member_use
    await Share.share(message, subject: 'Join $appName');
  }

  // ==================== PLACEHOLDER IMPLEMENTATIONS ====================
  // Replace these with your existing implementations

  // ignore: unused_element
  Widget _buildCreateGroupAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.appPriSecColor.primaryColor,
      elevation: 0,
      leading: IconButton(
        icon: customeBackArrowBalck(context),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Create Group',
          style: AppTypography.h3(
            context,
          ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 72, bottom: 16),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.appPriSecColor.primaryColor,
                AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Consumer<ContactListProvider>(
          builder: (context, prov, _) {
            return prov.selectedUserIds.isNotEmpty
                ? Container(
                  margin: const EdgeInsets.only(right: 16, top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${prov.selectedUserIds.length}',
                        style: AppTypography.smallText(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                : SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildGroupDetailsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.appPriSecColor.primaryColor.withValues(
                    alpha: AppThemeManage.appTheme.appInt,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SvgPicture.asset(
                  AppAssets.addGroupInfo,
                  colorFilter: ColorFilter.mode(
                    AppColors.black,
                    BlendMode.srcIn,
                  ),
                  height: 22,
                  width: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppString.groupInformation,
                style: AppTypography.h4(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Group Image Section
          Center(
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.appPriSecColor.secondaryColor.withValues(
                      alpha: 0.1,
                    ),
                    border: Border.all(
                      color: AppColors.appPriSecColor.primaryColor.withValues(
                        alpha: 0.2,
                      ),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child:
                        _selectedGroupImage != null
                            ? Image.file(
                              _selectedGroupImage!,
                              fit: BoxFit.cover,
                            )
                            : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.appPriSecColor.secondaryColor
                                        .withValues(alpha: 0.8),
                                    AppColors.appPriSecColor.primaryColor
                                        .withValues(alpha: 0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(23),
                                child: SvgPicture.asset(
                                  AppAssets.svgIcons.createGroupImage,
                                  colorFilter: ColorFilter.mode(
                                    AppColors.black.withValues(alpha: 0.36),
                                    BlendMode.srcIn,
                                  ),
                                  height: 36,
                                  width: 36,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // Icon(
                              //   Icons.group,
                              //   size: 36,
                              //   color: Colors.white,
                              // ),
                            ),
                  ),
                ),
                Positioned(
                  bottom: 3,
                  right: 1,
                  child: GestureDetector(
                    onTap: _selectGroupImage,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.appPriSecColor.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemeManage.appTheme.borderColor,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: AppThemeManage.appTheme.whiteBlck,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildEnhancedTextField(
            controller: _groupNameCtrl,
            label: AppString.groupName,
            hint: AppString.enterYourGroupName,
            // icon: Icons.tag_rounded,
            // prefixImagePath: AppAssets.svgIcons.tag,
            isRequired: true,
            maxLength: 30,
            // Group name must contain no whitespace at all - leading, trailing
            // or between words. `deny` also strips spaces out of pasted text.
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          ),
          const SizedBox(height: 16),
          _buildEnhancedTextField(
            controller: _descriptionCtrl,
            label: AppString.description,
            prefixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  AppAssets.createGroupDocument,
                  height: 18,
                  width: 18,
                  colorFilter: ColorFilter.mode(
                    AppColors.appPriSecColor.secondaryColor,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
            hint: AppString.whathisGroupAbout,
            // icon: Icons.description_outlined,
            maxLines: 3,
            maxLength: 120,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildContactsHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people_outline_rounded,
                color: AppColors.appPriSecColor.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Select Contacts',
                style: AppTypography.h5(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Consumer<ContactListProvider>(
                builder: (context, provider, _) {
                  return provider.selectedUserIds.isNotEmpty
                      ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.appPriSecColor.primaryColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${provider.selectedUserIds.length} selected',
                          style: AppTypography.smallText(context).copyWith(
                            color: AppColors.appPriSecColor.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                      : SizedBox.shrink();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgColor.bg1Color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _searchController,
              style: AppTypography.smallText(context),
              decoration: InputDecoration(
                hintText: AppString.searchContacts,
                hintStyle: AppTypography.smallText(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textColor.textGreyColor,
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    // required IconData icon,
    Widget? prefixIcon,
    int maxLines = 1,
    bool isRequired = false,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  text: label,
                  style: AppTypography.mediumText(context).copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppThemeManage.appTheme.textColor,
                  ),
                  children:
                      isRequired
                          ? [
                            TextSpan(
                              text: ' *',
                              style: TextStyle(color: Colors.red),
                            ),
                          ]
                          : [],
                ),
              ),
            ),
            if (maxLength != null)
              Text(
                '${controller.text.length}/$maxLength',
                style: AppTypography.captionText(context).copyWith(
                  color:
                      controller.text.length >= maxLength
                          ? AppColors.textColor.textErrorColor
                          : AppColors.textColor.textGreyColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppThemeManage.appTheme.darkGreyColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  maxLength != null && controller.text.length >= maxLength
                      ? AppColors.textColor.textErrorColor.withValues(
                        alpha: 0.5,
                      )
                      : AppColors.strokeColor.greyColor.withValues(alpha: 0.3),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: AppTypography.mediumText(context),
            onChanged: (_) => setState(() {}), // Trigger rebuild for validation
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.smallText(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
              prefixIcon: prefixIcon,
              border: InputBorder.none,
              counterText: '', // Hide default counter
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactsList() {
    return Consumer<ContactListProvider>(
      builder: (context, prov, _) {
        if (prov.isLoading && !widget.createGroupMode) {
          return Center(
            child: Padding(padding: EdgeInsets.all(32), child: commonLoading()),
          );
        }

        if (prov.errorMessage != null && !widget.createGroupMode) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(prov.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => prov.refreshContacts(),
                    child: Text(AppString.retry),
                  ),
                ],
              ),
            ),
          );
        }

        final contacts = prov.chatContacts;
        if (contacts.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                AppString.noContactsAvailable,
                style: AppTypography.innerText12Mediu(context),
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppThemeManage.appTheme.darkGreyColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${AppString.members}: ${prov.selectedUserIds.length} ${AppString.outof} ${Provider.of<ProjectConfigProvider>(context, listen: false).maxGroupMembers}",
                style: AppTypography.innerText12Mediu(context),
              ),
              horizontalListOfSelectedMember(prov.fullContactList, prov),
            ],
          ),
        );
        // SizedBox(
        //   height: SizeConfig.height(12),
        //   child: Align(
        //     alignment: Alignment.centerLeft,
        //     child: ListView.separated(
        //       shrinkWrap: true,
        //       scrollDirection: Axis.horizontal,
        //       itemBuilder: (BuildContext context, int index) {
        //         final contact = contacts[index];
        //         final id = int.tryParse(contact.userId ?? '') ?? -1;
        //         final isSelected = prov.selectedUserIds.contains(id);
        //         return Container(
        //           // margin: EdgeInsets.fromLTRB(
        //           //   16,
        //           //   index == 0 ? 8 : 4,
        //           //   16,
        //           //   index == contacts.length - 1 ? 100 : 4,
        //           // ),
        //           decoration: BoxDecoration(
        //             borderRadius: BorderRadius.circular(12),
        //             border:
        //                 isSelected
        //                     ? Border.all(
        //                       color: AppColors.appPriSecColor.primaryColor,
        //                       width: 2,
        //                     )
        //                     : null,
        //           ),
        //           child: Material(
        //             color: Colors.transparent,
        //             child: InkWell(
        //               borderRadius: BorderRadius.circular(12),
        //               onTap: () {
        //                 setState(() {
        //                   if (isSelected) {
        //                     prov.selectedUserIds.remove(id);
        //                   } else {
        //                     prov.selectedUserIds.add(id);
        //                   }
        //                 });
        //               },
        //               child: Container(
        //                 padding: const EdgeInsets.all(4),
        //                 child: ContactListItem(
        //                   contact: contact,
        //                   isForHorizontalView: true,
        //                   isChat: true,
        //                   isSelected: isSelected,
        //                   onTap: () {
        //                     setState(() {
        //                       if (isSelected) {
        //                         prov.selectedUserIds.remove(id);
        //                       } else {
        //                         prov.selectedUserIds.add(id);
        //                       }
        //                     });
        //                   },
        //                 ),
        //               ),
        //             ),
        //           ),
        //         );
        //       },
        //       separatorBuilder: (BuildContext context, int index) {
        //         return SizedBox(height: 5);
        //       },
        //       itemCount: contacts.length,
        //     ),
        //   ),
        // );
        // SliverList(
        //   delegate: SliverChildBuilderDelegate((context, index) {
        //     final contact = contacts[index];
        //     final id = int.tryParse(contact.userId ?? '') ?? -1;
        //     final isSelected = prov.selectedUserIds.contains(id);

        //     return
        //     Container(
        //       margin: EdgeInsets.fromLTRB(
        //         16,
        //         index == 0 ? 8 : 4,
        //         16,
        //         index == contacts.length - 1 ? 100 : 4,
        //       ),
        //       decoration: BoxDecoration(
        //         borderRadius: BorderRadius.circular(12),
        //         border:
        //             isSelected
        //                 ? Border.all(
        //                   color: AppColors.appPriSecColor.primaryColor,
        //                   width: 2,
        //                 )
        //                 : null,
        //       ),
        //       child: Material(
        //         color: Colors.transparent,
        //         child: InkWell(
        //           borderRadius: BorderRadius.circular(12),
        //           onTap: () {
        //             setState(() {
        //               if (isSelected) {
        //                 prov.selectedUserIds.remove(id);
        //               } else {
        //                 prov.selectedUserIds.add(id);
        //               }
        //             });
        //           },
        //           child: Container(
        //             padding: const EdgeInsets.all(4),
        //             child: ContactListItem(
        //               contact: contact,
        //               isChat: true,
        //               isSelected: isSelected,
        //               onTap: () {
        //                 setState(() {
        //                   if (isSelected) {
        //                     prov.selectedUserIds.remove(id);
        //                   } else {
        //                     prov.selectedUserIds.add(id);
        //                   }
        //                 });
        //               },
        //             ),
        //           ),
        //         ),
        //       ),
        //     );
        //   }, childCount: contacts.length),
        // );
      },
    );
  }

  // ==================== CREATE GROUP BOTTOM BAR ====================
  Widget _buildCreateGroupBottomBar() {
    return Consumer<ContactListProvider>(
      builder: (context, prov, _) {
        return Consumer<GroupProvider>(
          builder: (context, groupProv, _) {
            final canCreate =
                _groupNameCtrl.text.trim().isNotEmpty &&
                prov.selectedUserIds.isNotEmpty &&
                !groupProv.isLoading;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppThemeManage.appTheme.darkGreyColor,
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
                    // Error message display
                    if (groupProv.error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                groupProv.error!,
                                style: AppTypography.smallText(
                                  context,
                                ).copyWith(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Create Group Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            canCreate
                                ? () async {
                                  if (_groupNameCtrl.text.trim().isEmpty) {
                                    snackbarNew(
                                      context,
                                      msg: AppString.enterGroupNameToContinue,
                                    );
                                  } else if (canCreate) {
                                    debugPrint(
                                      'DEBUG: About to create group - _selectedGroupImage: ${_selectedGroupImage?.path}',
                                    );
                                    if (_selectedGroupImage != null) {
                                      debugPrint(
                                        'DEBUG: Image file exists: ${await _selectedGroupImage!.exists()}',
                                      );
                                    }
                                    await groupProv.createGroup(
                                      participants: prov.selectedUserIds,
                                      groupName: _groupNameCtrl.text.trim(),
                                      description: _descriptionCtrl.text.trim(),
                                      groupIcon: _selectedGroupImage,
                                    );
                                    if (groupProv.response != null) {
                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                    }
                                  }
                                }
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              canCreate
                                  ? AppColors.appPriSecColor.primaryColor
                                  : AppThemeManage.appTheme.strokBorder2,
                          foregroundColor: Colors.white,
                          elevation: canCreate ? 4 : 0,
                          shadowColor: AppColors.appPriSecColor.primaryColor
                              .withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child:
                            groupProv.isLoading
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${AppString.creatingGroup}...',
                                      style: AppTypography.buttonText(
                                        context,
                                      ).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                )
                                : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Icon(
                                    //   Icons.group_add_rounded,
                                    //   color: Colors.white,
                                    //   size: 20,
                                    // ),
                                    SvgPicture.asset(
                                      AppAssets.svgIcons.createGroupImage,
                                      height: 21,
                                      width: 21,
                                      colorFilter: ColorFilter.mode(
                                        AppThemeManage.appTheme.darkWhiteColor,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppString.createGroup,
                                      style: AppTypography.buttonText(
                                        context,
                                      ).copyWith(
                                        color:
                                            canCreate
                                                ? ThemeColorPalette.getTextColor(
                                                  AppColors
                                                      .appPriSecColor
                                                      .primaryColor,
                                                )
                                                : Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),

                    // Validation messages
                    if (!canCreate && prov.selectedUserIds.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          AppString.pleaseSelectAtleastOneContact,
                          style: AppTypography.smallText(
                            context,
                          ).copyWith(color: AppColors.textColor.textGreyColor),
                        ),
                      ),
                    if (!canCreate &&
                        _groupNameCtrl.text.trim().isEmpty &&
                        prov.selectedUserIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          AppString.pleaseEnterAGroupName,
                          style: AppTypography.smallText(
                            context,
                          ).copyWith(color: AppColors.textColor.textGreyColor),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget horizontalListOfSelectedMember(
    List<ContactModel> allContactsToShow,
    ContactListProvider prov,
  ) {
    return Column(
      children: [
        SizedBox(height: 8),
        Container(
          height: SizeConfig.height(10.5),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: prov.selectedUserIds.length,
              shrinkWrap: true,
              separatorBuilder: (_, t) => SizedBox(width: 2),
              itemBuilder: (context, index) {
                final selectedId = prov.selectedUserIds[index];
                final contact = allContactsToShow.firstWhere(
                  (c) => int.tryParse(c.userId ?? '') == selectedId,
                  // orElse:
                  //     () => ContactModel(
                  //       userId: selectedId.toString(),
                  //       name: 'Unknown',
                  //       phoneNumber: '',
                  //     ),
                );

                return ContactListItem(
                  contact: contact,
                  isChat: true,
                  isForHorizontalView: true,
                  isSelected: true,
                  onTap: () {
                    debugPrint("Tap on the Remove");
                    prov.removeUserSelection(prov.selectedUserIds[index]);
                    if (prov.selectedUserIds.isEmpty) {
                      if (widget.createGroupMode) {
                        Navigator.pop(context);
                      }
                    }
                    // setState(() {});
                  },
                  trailing: null,
                );
              },
            ),
          ),
        ),
        widget.createGroupMode
            ? SizedBox.shrink()
            : Divider(color: AppThemeManage.appTheme.borderColor),
      ],
    );
  }

  Widget _buildAddMemberContactsList() {
    return Consumer<ContactListProvider>(
      builder: (context, prov, _) {
        if (prov.isLoading) {
          return Center(
            child: Padding(padding: EdgeInsets.all(32), child: commonLoading()),
          );
        }

        if (prov.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(prov.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => prov.refreshContacts(),
                    child: Text(AppString.retry),
                  ),
                ],
              ),
            ),
          );
        }

        // Separate contacts into available and existing members
        final allContacts = prov.chatContacts;
        final existingIds = widget.existingMemberIds ?? []; // Handle null case

        debugPrint('🔍 Contact List Add Member Mode:');
        debugPrint('  All Contacts Count: ${allContacts.length}');
        debugPrint('  Existing Member IDs: $existingIds');
        debugPrint('  Existing IDs Count: ${existingIds.length}');

        final availableContacts = <ContactModel>[];
        final existingMemberContacts = <ContactModel>[];

        for (final contact in allContacts) {
          final userId = int.tryParse(contact.userId ?? '') ?? -1;
          debugPrint(
            '  Contact: ${contact.name} (ID: ${contact.userId}, Parsed: $userId)',
          );
          if (existingIds.contains(userId)) {
            debugPrint(
              '    ✅ Found in existing members - adding to existing list',
            );
            existingMemberContacts.add(contact);
          } else {
            debugPrint(
              '    ➕ Not in existing members - adding to available list',
            );
            availableContacts.add(contact);
          }
        }

        debugPrint(
          '  Final counts - Available: ${availableContacts.length}, Existing: ${existingMemberContacts.length}',
        );

        // Show both available contacts and existing members
        final allContactsToShow = [
          ...availableContacts,
          ...existingMemberContacts,
        ];

        // if (allContactsToShow.isEmpty) {
        //   return Center(
        //     child: Padding(
        //       padding: const EdgeInsets.all(32),
        //       child: Column(
        //         children: [
        //           Icon(
        //             Icons.people_outline,
        //             size: 64,
        //             color: AppColors.textColor.textGreyColor,
        //           ),
        //           const SizedBox(height: 16),
        //           Text(
        //             'No contacts available',
        //             style: AppTypography.h5(context).copyWith(
        //               color: AppColors.textColor.textGreyColor,
        //               fontWeight: FontWeight.w500,
        //             ),
        //           ),
        //         ],
        //       ),
        //     ),
        //   );
        // }

        return Column(
          children: [
            SizedBox(height: SizeConfig.height(2)),
            Padding(
              padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
              child: SizedBox(
                height: SizeConfig.height(6),
                child: searchBar(
                  context,
                  controller1: _searchController,
                  hintText: AppString.searchNameOrNumber,
                  onChanged: (value) {
                    _contactListProvider.searchContacts(value);
                  },
                ),
              ),
            ),
            if (prov.selectedUserIds.isNotEmpty)
              horizontalListOfSelectedMember(
                prov.fullContactList,
                // allContactsToShow,
                prov,
              ),
            Expanded(
              child:
                  (prov.chatContacts.isEmpty &&
                          _searchController.text.isNotEmpty)
                      ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 35),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon(
                            //   Icons.people_outline,
                            //   size: 64,
                            //   color: AppColors.textColor.textGreyColor,
                            // ),
                            _emptyContactImage(),
                            const SizedBox(height: 16),
                            Text(
                              AppString.noContactsAvailableAsPerYourSearch,
                              textAlign: TextAlign.center,
                              style: AppTypography.h5(context).copyWith(
                                color: AppColors.textColor.textGreyColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                      : allContactsToShow.isNotEmpty
                      ? ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemBuilder: (BuildContext context, int index) {
                          final contact = allContactsToShow[index];
                          final id = int.tryParse(contact.userId ?? '') ?? -1;
                          final isSelected = prov.selectedUserIds.contains(id);
                          final isExistingMember = existingIds.contains(id);
                          return Container(
                            margin: EdgeInsets.fromLTRB(
                              0,
                              index == 0 ? 8 : 0,
                              0,
                              index == allContactsToShow.length - 1 ? 100 : 0,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color:
                                  isExistingMember
                                      ? AppColors.strokeColor.greyColor
                                          .withValues(alpha: 0.1)
                                      : null,
                              border:
                                  isExistingMember
                                      ? Border.all(
                                        color: AppColors.strokeColor.greyColor
                                            .withValues(alpha: 0.3),
                                        width: 1,
                                      )
                                      // :
                                      // isSelected
                                      // ? Border.all(
                                      //   color: AppColors.appPriSecColor.primaryColor,
                                      //   width: 2,
                                      // )
                                      : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap:
                                    isExistingMember
                                        ? null
                                        : () {
                                          setState(() {
                                            if (isSelected) {
                                              prov.removeUserSelection(id);
                                            } else {
                                              prov.addUserSelection(id);
                                            }
                                          });
                                        },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: ContactListItem(
                                    contact: contact,
                                    isChat: true,
                                    isSelected:
                                        isExistingMember ? false : isSelected,
                                    onTap: () {
                                      if (!isExistingMember) {
                                        // setState(() {
                                        if (isSelected) {
                                          prov.removeUserSelection(id);
                                        } else {
                                          prov.addUserSelection(id);
                                        }
                                        // });
                                      }
                                    },
                                    trailing:
                                        isExistingMember
                                            ? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors
                                                    .strokeColor
                                                    .greyColor
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                AppString.alreadyInGroup,
                                                style:
                                                    AppTypography.captionText(
                                                      context,
                                                    ).copyWith(
                                                      color:
                                                          AppColors
                                                              .textColor
                                                              .textGreyColor,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            )
                                            : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (BuildContext context, int index) {
                          return Divider(
                            color: AppThemeManage.appTheme.borderColor,
                          );
                          // SizedBox(height: SizeConfig.height(1));
                        },
                        itemCount: allContactsToShow.length,
                      )
                      : _buildEmptyState(AppString.noContactsAvailableforChat),
            ),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildAddMemberBottomBar() {
    return Consumer<ContactListProvider>(
      builder: (context, prov, _) {
        return Consumer<GroupProvider>(
          builder: (context, groupProv, _) {
            final canAdd =
                prov.selectedUserIds.isNotEmpty &&
                !groupProv.isLoading &&
                widget.groupId != null; // Add null check

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
                    if (groupProv.error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                groupProv.error!,
                                style: AppTypography.smallText(
                                  context,
                                ).copyWith(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            canAdd
                                ? () async {
                                  // Add null check before using widget.groupId
                                  if (widget.groupId != null) {
                                    final added = await groupProv
                                        .addGroupMember(
                                          chatId: widget.groupId!,
                                          userIds: prov.selectedUserIds,
                                        );

                                    if (added) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${prov.selectedUserIds.length} ${AppString.memberAddedSuccessfully}',
                                          ),
                                          backgroundColor:
                                              AppColors
                                                  .appPriSecColor
                                                  .primaryColor,
                                        ),
                                      );
                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                    }
                                  }
                                }
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              canAdd
                                  ? AppColors.appPriSecColor.primaryColor
                                  : AppColors.strokeColor.greyColor,
                          foregroundColor: Colors.white,
                          elevation: canAdd ? 4 : 0,
                          shadowColor: AppColors.appPriSecColor.primaryColor
                              .withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child:
                            groupProv.isLoading
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${AppString.addingMembers}...',
                                      style: AppTypography.buttonText(
                                        context,
                                      ).copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                                : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_add_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${AppString.add} ${prov.selectedUserIds.length} ${AppString.members}}',
                                      style: AppTypography.buttonText(
                                        context,
                                      ).copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                    if (!canAdd && prov.selectedUserIds.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          AppString.pleaseSelectAtLeastOneContactToAdd,
                          style: AppTypography.smallText(
                            context,
                          ).copyWith(color: AppColors.textColor.textGreyColor),
                        ),
                      ),
                    if (!canAdd && widget.groupId == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Group ID is missing',
                          style: AppTypography.smallText(
                            context,
                          ).copyWith(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyContactImage() {
    return SvgPicture.asset(
      AppAssets.emptyContacts,
      height: 85,
      width: 85,
      colorFilter: ColorFilter.mode(
        AppColors.appPriSecColor.secondaryColor,
        BlendMode.srcIn,
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        children: [
          SizedBox(height: SizeConfig.height(30)),
          _emptyContactImage(),
          // Icon(
          //   Icons.person_off_outlined,
          //   size: 64,
          //   color: AppColors.textColor.textGreyColor,
          // ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.innerText12Ragu(context),
            // style: TextStyle(
            //   color: AppColors.textColor.textGreyColor,
            //   fontSize: 16,
            // ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsListNormal(
    List<ContactModel> contacts,
    bool isChat, {
    bool isForInvite = false,
  }) {
    // logger.e("jsonEncode(contacts)>>>>::::: ${jsonEncode(contacts)}");
    return RefreshIndicator(
      onRefresh: () => _contactListProvider.refreshContacts(force: true),
      color: AppColors.appPriSecColor.primaryColor,
      child: ListView.builder(
        itemCount: contacts.length,
        padding: EdgeInsets.only(
          bottom:
              // SizeConfig.sizedBoxHeight(75) +
              25 + MediaQuery.of(context).padding.bottom,
        ),
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return ContactListItem(
            contact: contact,
            isChat: isChat,
            isSelected: false,
            isChatLock: contact.isChatLock,
            trailing:
                contact.isChatLock == true
                    ? Column(
                      children: [
                        Text(
                          isForInvite
                              ? AppString.invite
                              : AppString.bottomNavString.chat,
                          style: AppTypography.smallText(context).copyWith(
                            fontWeight: FontWeight.w500,
                            color:
                                isForInvite
                                    ? AppColors.appPriSecColor.primaryColor
                                    : AppColors.textColor.textDarkGray,
                          ),
                        ),
                        SizedBox(height: 2),
                        Icon(
                          Icons.lock_rounded,
                          color: AppThemeManage.appTheme.textGreyWhite,
                          size: 15,
                        ),
                      ],
                    )
                    : Text(
                      isForInvite
                          ? AppString.invite
                          : AppString.bottomNavString.chat,
                      style: AppTypography.smallText(context).copyWith(
                        fontWeight: FontWeight.w500,
                        color:
                            isForInvite
                                ? AppColors.appPriSecColor.primaryColor
                                : AppColors.textColor.textDarkGray,
                      ),
                    ),
            onTap: () {
              debugPrint("ONTAP");
              if (isChat) {
                debugPrint("contact.isChatLock:${contact.isChatLock}");
                if (contact.isChatLock == true) {
                  _showPinDialog(
                    context: context,
                    mode: PinDialogMode.unlock,
                    chatName: contact.name,
                    // correctPin: _globalPin ?? record!.participants!.first.lockPin,
                    onValidatePin: (enteredPin) async {
                      return await _callUnLockChatApi(
                        chatId: contact.chatId.toString(),
                        pin: enteredPin,
                      );
                    },
                    onSuccess: () {
                      final provider = context.read<ChatProvider>();
                      provider.markSessionUnlocked(contact.chatId!);
                      NavigationHelper.navigateToChat(
                        context,
                        chatId: contact.chatId ?? 0,
                        userId: int.parse(contact.userId!),
                        fullName: contact.name,
                        // profilePic:
                        //     contact.photo != null ? base64Encode(contact.photo!) : '',
                        profilePic: contact.profilePicUrl ?? '',
                      );
                    },
                  );
                } else {
                  NavigationHelper.navigateToChat(
                    context,
                    chatId: contact.chatId ?? 0,
                    userId: int.parse(contact.userId!),
                    fullName: contact.name,
                    // profilePic:
                    //     contact.photo != null ? base64Encode(contact.photo!) : '',
                    profilePic: contact.profilePicUrl ?? '',
                  );
                }
              } else {
                _showInviteDialog(contact);
              }
            },
          );
        },
      ),
    );
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

  Future<bool> _callUnLockChatApi({
    required String chatId,
    required String pin,
  }) async {
    final provider = context.read<ChatProvider>();
    return await provider.unLockChat(chatId, pin);
  }

  void _showInviteDialog(ContactModel contact) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppThemeManage.appTheme.darkGreyColor,
          title: Text(
            AppString.inviteContact,
            style: TextStyle(color: AppThemeManage.appTheme.textColor),
          ),
          content: Text(
            '${AppString.wouldYouLikeToInvite} ${contact.name} ${AppString.tojoin} $appName?',
            style: TextStyle(color: AppThemeManage.appTheme.textColor),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                AppString.cancel,
                style: TextStyle(color: AppColors.textColor.textGreyColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // _contactListProvider.inviteContact(contact);
                _shareInviteLink();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appPriSecColor.primaryColor,
              ),
              child: Text(
                AppString.invite,
                style: TextStyle(color: AppColors.textColor.textWhiteColor),
              ),
            ),
          ],
        );
      },
    );
  }

  void _selectGroupImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: AppThemeManage.appTheme.darkGreyColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: SizeConfig.getPadding(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  AppString.selectGroupImage,
                  style: AppTypography.h4(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      label: AppString.settingStrigs.camera,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromCamera();
                      },
                    ),
                    _buildImageSourceOption(
                      icon: Icons.photo_library,
                      label: AppString.settingStrigs.gellery,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromGallery();
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: SizeConfig.getPadding(20),
        decoration: BoxDecoration(
          color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.appPriSecColor.primaryColor),
            SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.mediumText(context).copyWith(
                color: AppColors.appPriSecColor.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedGroupImage = File(image.path);
        });
        debugPrint('DEBUG: Camera image selected - Path: ${image.path}');
        debugPrint(
          'DEBUG: _selectedGroupImage set to: ${_selectedGroupImage?.path}',
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          // ignore: use_build_context_synchronously
          SnackBar(
            content: Text(AppString.photoCapturedSuccessfully),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        // ignore: use_build_context_synchronously
        SnackBar(
          content: Text('${AppString.errorAccessingCamera}: $e'),
          backgroundColor: AppColors.textColor.textErrorColor,
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedGroupImage = File(image.path);
        });
        debugPrint('DEBUG: Gallery image selected - Path: ${image.path}');
        debugPrint(
          'DEBUG: _selectedGroupImage set to: ${_selectedGroupImage?.path}',
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          // ignore: use_build_context_synchronously
          SnackBar(
            content: Text(AppString.imageSelectedSuccessfully),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        // ignore: use_build_context_synchronously
        SnackBar(
          content: Text('${AppString.errorAccessingGallery}: $e'),
          backgroundColor: AppColors.textColor.textErrorColor,
        ),
      );
    }
  }
}

// ==================== USAGE EXAMPLES ====================

/*
// 1. Navigate to Forward Mode
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ContactListScreenV2(
      isForwardMode: true,
      selectedMessageIds: [123, 456, 789], // Selected message IDs
      fromChatId: currentChatId, // Current chat ID
      forwardTitle: 'Forward to Contacts', // Optional custom title
    ),
  ),
);

// 2. Navigate to Create Group Mode
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ContactListScreenV2(
      createGroupMode: true,
    ),
  ),
);

// 3. Navigate to Add Member Mode
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ContactListScreenV2(
      isAddMemberMode: true,
      groupId: groupId,
      existingMemberIds: [101, 102, 103],
    ),
  ),
);

// 4. Navigate to Normal Contact Mode
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ContactListScreenV2(),
  ),
);

// 5. Navigate with Custom Chat Selection Callback
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ContactListScreenV2(
      isForwardMode: true,
      selectedMessageIds: selectedMessages,
      fromChatId: currentChat,
      onChatSelected: (chatId, chatName) {
        // Handle single chat selection
        debugPrint('Selected chat: $chatId - $chatName');
        Navigator.pop(context);
      },
    ),
  ),
);
*/

// ==================== ADVANCED USAGE WITH CUSTOM FORWARD HANDLING ====================

/*
// Create a custom wrapper for more complex forward scenarios
class ForwardMessageScreen extends StatelessWidget {
  final List<int> messageIds;
  final int fromChatId;
  final String fromChatName;

  const ForwardMessageScreen({
    Key? key,
    required this.messageIds,
    required this.fromChatId,
    required this.fromChatName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ContactListScreenV2(
      isForwardMode: true,
      selectedMessageIds: messageIds,
      fromChatId: fromChatId,
      forwardTitle: 'Forward from $fromChatName',
    );
  }
}

// Usage:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ForwardMessageScreen(
      messageIds: selectedMessageIds,
      fromChatId: currentChatId,
      fromChatName: currentChatName,
    ),
  ),
);
*/

// ==================== INTEGRATION WITH YOUR EXISTING CHAT SCREEN ====================

/*
// In your chat screen, when user selects messages to forward:
class ChatScreen extends StatefulWidget {
  // ... your existing chat screen code
  
  void _showForwardOptions() {
    if (_selectedMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select messages to forward')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactListScreenV2(
          isForwardMode: true,
          selectedMessageIds: _selectedMessages.map((msg) => msg.id).toList(),
          fromChatId: widget.chatId,
          forwardTitle: 'Forward ${_selectedMessages.length} message${_selectedMessages.length != 1 ? 's' : ''}',
        ),
      ),
    ).then((_) {
      // Clear selection after returning from forward screen
      setState(() {
        _selectedMessages.clear();
        _isSelectionMode = false;
      });
    });
  }
}
*/

// ==================== BACKEND INTEGRATION EXAMPLE ====================

/*
// Example of how your backend should handle the forward request:

// API Endpoint: POST /api/messages/forward
// Request Body:
{
  "message_ids": [123, 456, 789],
  "from_chat_id": 100,
  "existing_chat_ids": [201, 202, 203], // Forward to existing chats
  "new_chat_user_ids": [301, 302, 303]  // Create new chats with these users
}

// Response:
{
  "success": true,
  "total_attempted": 9, // 3 messages × 3 recipients
  "success_count": 8,
  "failure_count": 1,
  "details": {
    "existing_chats": {
      "success": 6, // 3 messages × 2 successful chats
      "failed": 3   // 3 messages × 1 failed chat
    },
    "new_chats": {
      "success": 2, // 2 new chats created and messages forwarded
      "failed": 1   // 1 new chat creation failed
    }
  },
  "errors": [
    "Failed to forward to chat 203: Chat not found",
    "Failed to create chat with user 303: User not found"
  ]
}
*/

// ==================== PERFORMANCE OPTIMIZATIONS ====================

/*
// For better performance with large contact lists:

// 1. Lazy loading for contacts
class ContactListScreenV2 extends StatefulWidget {
  final bool enableLazyLoading;
  final int contactsPerPage;
  
  const ContactListScreenV2({
    // ... existing parameters
    this.enableLazyLoading = true,
    this.contactsPerPage = 50,
  });
}

// 2. Debounced search
class _ContactListScreenV2State extends State<ContactListScreenV2> {
  Timer? _searchDebounceTimer;
  
  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(Duration(milliseconds: 300), () {
      if (!widget.isForwardMode) {
        Provider.of<ContactListProvider>(
          context,
          listen: false,
        ).searchContacts(_searchController.text);
      }
    });
  }
}

// 3. Virtualized list for large datasets
// Consider using flutter_staggered_grid_view or similar packages
// for better performance with large lists
*/
