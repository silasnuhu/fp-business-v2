// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';

import 'package:whoxa/ads/banner_ad_widget.dart';
import 'package:whoxa/featuers/ai_assistant/widgets/ai_assistant_fab.dart';
import 'package:whoxa/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/core/services/socket/socket_event_controller.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/provider/archive_chat_provider.dart';
import 'package:whoxa/featuers/chat/screens/archived_chat_list_screen.dart';
import 'package:whoxa/featuers/home/provider/home_provider.dart';
import 'package:whoxa/featuers/home/screens/chat_list.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/widgets/global_textfield.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  bool isBtnShow = true;
  bool _initializing = false;
  String? _error;
  final ConsoleAppLogger _logger = ConsoleAppLogger();
  bool _hasInitialized = false;

  // ✅ NEW: Track if this is the first login (fresh navigation from OTP)
  bool _isFirstLoginAttempt = true;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  FocusNode searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      searchFocusNode = FocusNode();
      if (!_hasInitialized) {
        await _initializeSocket();
      }
    });
  }

  Future<void> _initializeSocket() async {
    if (kDebugMode) {
      _logger.i('Initializing socket on HomeScreen');
    }
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final socketEventController = Provider.of<SocketEventController>(
      context,
      listen: false,
    );
    final archiveChatProvider = Provider.of<ArchiveChatProvider>(
      context,
      listen: false,
    );

    // Check if already connected and has data - skip reloading
    if (socketEventController.isConnected &&
        chatProvider.chatListData.chats.isNotEmpty &&
        _hasInitialized) {
      if (kDebugMode) {
        _logger.i('Socket already connected and data loaded, skipping reload');
      }
      return;
    }

    // ✅ OFFLINE-FIRST: If we already have local/cached chat data, never block
    // the whole screen behind the "Connecting to chat service..." spinner —
    // render the cached chats immediately and let the socket connect and
    // refresh silently in the background. Only show the blocking spinner
    // when there is genuinely nothing cached to show yet (true first run).
    //
    // ✅ FIX: The cache restore (ChatProvider's constructor-time
    // _loadCachedChatListIfEmpty()) is an async disk read kicked off
    // fire-and-forget — it wasn't guaranteed to have finished by the time
    // this runs (right after HomeScreen's first frame), so this check could
    // read an empty list a few milliseconds before the cache landed and
    // show the blocking spinner unnecessarily on a cold start that actually
    // had cached chats to show instantly. Give it a short, bounded chance
    // to finish first — this never waits long: either it resolves almost
    // immediately (the common case) or the timeout fires and behavior falls
    // back to exactly what it was before this fix.
    await chatProvider.waitForCachedChatListRestore().timeout(
      const Duration(milliseconds: 400),
      onTimeout: () {},
    );

    final hasCachedChats = chatProvider.chatListData.chats.isNotEmpty;

    if (!mounted) return;
    setState(() {
      _initializing = !hasCachedChats;
      _hasInitialized = _hasInitialized || hasCachedChats;
      _error = null;
    });

    try {
      // ✅ UPDATED: Archive chat provider is already set up in provider_list.dart at app startup
      // But we still set up the callback for archive status changes here
      archiveChatProvider.setOnArchiveStatusChanged((chatId, isArchived) {
        if (isArchived) {
          chatProvider.addArchivedChatId(chatId);
        } else {
          chatProvider.removeArchivedChatId(chatId);
        }
      });

      // ✅ CRITICAL UX FIX: Wait for background socket initialization with extended timeout
      // This handles the case when user just logged in and background init is still running
      if (!socketEventController.isConnected) {
        if (kDebugMode) {
          _logger.i(
            'Socket not connected, waiting for background initialization...',
          );
        }

        bool connected = false;

        // ✅ PHASE 1: Wait for background initialization (up to 8 seconds)
        // After login, socket init runs in background - give it time to complete
        if (_isFirstLoginAttempt) {
          if (kDebugMode) {
            _logger.i(
              'First login attempt - waiting for background socket init...',
            );
          }

          const maxWaitMs = 8000; // 8 seconds max wait
          const checkIntervalMs = 200; // Check every 200ms
          int elapsedMs = 0;

          while (elapsedMs < maxWaitMs && !connected) {
            // Check if background init completed
            if (socketEventController.isConnected) {
              connected = true;
              if (kDebugMode) {
                _logger.i(
                  'Background socket init completed after ${elapsedMs}ms',
                );
              }
              break;
            }

            await Future.delayed(const Duration(milliseconds: checkIntervalMs));
            elapsedMs += checkIntervalMs;

            // Log progress in debug mode
            if (kDebugMode && elapsedMs % 1000 == 0) {
              _logger.i('Still waiting for socket... ${elapsedMs}ms elapsed');
            }
          }

          _isFirstLoginAttempt = false;
        }

        // ✅ PHASE 2: If still not connected, try active connection with retries
        if (!connected && !socketEventController.isConnected) {
          if (kDebugMode) {
            _logger.i(
              'Background init not completed, trying active connection...',
            );
          }

          const maxRetries = 3;
          const retryDelays = [500, 1000, 2000]; // Increasing delays

          for (int i = 0; i < maxRetries; i++) {
            // Check if already connected
            if (socketEventController.isConnected) {
              connected = true;
              if (kDebugMode) {
                _logger.i('Socket connected after waiting (attempt ${i + 1})');
              }
              break;
            }

            // Try to connect
            try {
              connected = await chatProvider.connect();
              if (connected) {
                if (kDebugMode) {
                  _logger.i('Socket connected on active attempt ${i + 1}');
                }
                break;
              }
            } catch (e) {
              if (kDebugMode) {
                _logger.w('Connection attempt ${i + 1} error: $e');
              }
            }

            // Wait before retry (if not last attempt)
            if (i < maxRetries - 1) {
              final delayMs = retryDelays[i];
              if (kDebugMode) {
                _logger.i(
                  'Connection attempt ${i + 1} failed, retrying in ${delayMs}ms...',
                );
              }
              await Future.delayed(Duration(milliseconds: delayMs));
            }
          }
        }

        // ✅ PHASE 3: Final check - if still not connected, show error but continue gracefully
        if (!connected && !socketEventController.isConnected) {
          if (kDebugMode) {
            _logger.w('Socket connection failed after all attempts');
          }

          // ✅ UX IMPROVEMENT: Show content with connection banner instead of blocking error
          // This allows user to see their chat list (if cached) while connection retries in background
          if (!mounted) return;
          setState(() {
            _error = null; // Don't block the UI with error
            _initializing = false;
            _hasInitialized =
                true; // Mark as initialized to prevent re-init loop
          });

          // ✅ Schedule silent background retry
          _scheduleBackgroundReconnect(chatProvider, socketEventController);

          // Continue to load cached chat data if available
          if (chatProvider.chatListData.chats.isNotEmpty) {
            if (kDebugMode) {
              _logger.i(
                'Showing cached chat data while reconnecting in background',
              );
            }
            return;
          }

          // If no cached data, show a gentle error that allows retry
          if (!mounted) return;
          setState(() {
            _error = "Could not connect to chat server";
            _initializing = false;
          });
          return;
        }
      }

      // Block list, fetched on every home entry (cold start included).
      // Nothing else loaded it at startup: it was only fetched when the
      // block-list screen, a profile screen or the chat long-press sheet
      // opened. The chat rows derive their `blockedBy` from it, so without
      // this a restart left every row looking unblocked — the long-press
      // menu offered "Block User" for users who were already blocked.
      // Unawaited so it never delays the chat list; loadBlockedUsers
      // re-stamps the rows when it lands, whichever order they finish in.
      unawaited(chatProvider.loadBlockedUsers());

      // Only fetch chat list if not already loaded
      if (chatProvider.chatListData.chats.isEmpty) {
        if (kDebugMode) {
          _logger.i('Chat list empty, fetching data...');
        }
        await chatProvider.refreshChatList();
      } else {
        if (kDebugMode) {
          _logger.i('Chat list already loaded, skipping API call');
        }
      }

      // ✅ NEW: Initialize archived chats (completely optional and non-blocking)
      // Only fetch if not already loaded and the backend might support it
      if (archiveChatProvider.archivedChats.isEmpty) {
        try {
          if (kDebugMode) {
            _logger.i('Fetching archived chats...');
          }
          await archiveChatProvider.fetchArchivedChats();
        } catch (e) {
          if (kDebugMode) {
            _logger.w('Archived chats feature not available: $e');
          }
        }
      } else {
        // List already warm from cache/earlier fetch — still make sure the
        // badge count is reconciled with the server on every home entry.
        unawaited(archiveChatProvider.refreshArchivedCount());
      }

      if (!mounted) return;
      setState(() {
        _initializing = false;
        _hasInitialized = true;
      });
    } catch (e) {
      if (kDebugMode) {
        _logger.e('Error during socket initialization', e);
      }
      if (!mounted) return;
      setState(() {
        // ✅ Don't replace already-visible cached chats with a blocking error screen
        _error = chatProvider.chatListData.chats.isNotEmpty
            ? null
            : "Error connecting: ${e.toString()}";
        _initializing = false;
      });
    }
  }

  /// ✅ NEW: Schedule silent background reconnection attempts
  void _scheduleBackgroundReconnect(
    ChatProvider chatProvider,
    SocketEventController socketEventController,
  ) {
    // Run reconnection in background without blocking UI
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;

      // Check if already connected
      if (socketEventController.isConnected) {
        if (kDebugMode) {
          _logger.i('Background reconnect: Already connected');
        }
        // Clear any error and refresh data
        if (_error != null) {
          setState(() {
            _error = null;
          });
          await chatProvider.refreshChatList();
        }
        return;
      }

      // Try to reconnect silently
      if (kDebugMode) {
        _logger.i('Background reconnect: Attempting to reconnect...');
      }

      try {
        final connected = await chatProvider.connect();
        if (connected && mounted) {
          if (kDebugMode) {
            _logger.i('Background reconnect: Successfully connected');
          }
          setState(() {
            _error = null;
          });
          await chatProvider.refreshChatList();
        } else if (mounted) {
          // Schedule another retry in 10 seconds
          _scheduleBackgroundReconnect(chatProvider, socketEventController);
        }
      } catch (e) {
        if (kDebugMode) {
          _logger.w('Background reconnect failed: $e');
        }
        // Schedule another retry
        if (mounted) {
          _scheduleBackgroundReconnect(chatProvider, socketEventController);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    setState(() {
      isBtnShow = bottomInset == 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    SizeConfig().init(context);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          elevation: 0,
          backgroundColor: AppColors.transparent,
          systemOverlayStyle: systemUI(),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  AppColors.appPriSecColor.secondaryColor.withValues(
                    alpha: 0.08,
                  ),
                  AppColors.transparent,
                ],
              ),
            ),
          ),
          title: AppThemeManage.appTheme.appHomelogo,
          toolbarHeight: kToolbarHeight,
          actions: [
            Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                return InkWell(
                  onTap: () {
                    Provider.of<ProjectConfigProvider>(
                      context,
                      listen: false,
                    ).fetchNotificationList();
                    Navigator.pushNamed(context, AppRoutes.notification).then((
                      _,
                    ) async {
                      await chatProvider.countApi();
                    });
                  },
                  child: Container(
                    height: SizeConfig.sizedBoxHeight(36),
                    width: SizeConfig.sizedBoxWidth(36),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppThemeManage.appTheme.borderColor,
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: SizeConfig.getPadding(8),
                          child: SvgPicture.asset(
                            AppAssets.homeIcons.notification,
                            colorFilter: ColorFilter.mode(
                              AppThemeManage.appTheme.darkWhiteColor,
                              BlendMode.srcIn,
                            ),
                            height: SizeConfig.sizedBoxHeight(20),
                          ),
                        ),
                        Positioned(
                          right: 5.5,
                          top: 2,
                          child: chatProvider.notificationCount == 0
                              ? SizedBox.shrink()
                              : Container(
                                  height: SizeConfig.sizedBoxHeight(14),
                                  width: SizeConfig.sizedBoxWidth(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    color:
                                        AppColors.appPriSecColor.primaryColor,
                                  ),
                                  child: Center(
                                    child: Text(
                                      chatProvider.notificationCount.toString(),
                                      style: AppTypography.innerText10(context)
                                          .copyWith(
                                            fontSize: 9,
                                            color:
                                                ThemeColorPalette.getTextColor(
                                                  AppColors
                                                      .appPriSecColor
                                                      .primaryColor,
                                                ),
                                          ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(width: SizeConfig.width(5)),
          ],
        ),
        body: Consumer<HomeProvider>(
          builder: (context, homeProvider, child) {
            if (_initializing) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    commonLoading(),
                    SizedBox(height: 20),
                    Text("${AppString.connectingToChatService}..."),
                  ],
                ),
              );
            }

            if (_error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ✅ UX IMPROVEMENT: Show wifi icon instead of error icon
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 64,
                      color: AppColors.appPriSecColor.primaryColor.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      AppString.connectingToChatService,
                      style: AppTypography.h4(context)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: SizeConfig.getPaddingSymmetric(horizontal: 40),
                      child: Text(
                        "Please check your internet connection",
                        textAlign: TextAlign.center,
                        style: AppTypography.innerText11(context)
                            .copyWith(color: AppColors.textColor.textGreyColor),
                      ),
                    ),
                    SizedBox(height: 24),
                    // ✅ Retry button with better styling
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _isFirstLoginAttempt = true;
                        });
                        _initializeSocket();
                      },
                      icon: Icon(Icons.refresh, size: 18),
                      label: Text(AppString.retry),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.appPriSecColor.primaryColor,
                        foregroundColor: Colors.white,
                        padding: SizeConfig.getPaddingSymmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    // ✅ Show auto-retry message
                    Text(
                      "Auto-retrying in background...",
                      style: AppTypography.smallText(context).copyWith(
                        color: AppColors.textColor.textGreyColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Stack(
              children: [
                Column(
                  children: [
                    SizedBox(height: SizeConfig.height(2)),
                    Padding(
                      padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppString.homeScreenString.chats,
                            style: AppTypography.h2(context).copyWith(
                              fontWeight: FontWeight.w600,
                              fontFamily: AppTypography.fontFamily.poppinsBold,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.contactListScreen,
                                arguments: {
                                  'isAddMemberMode': true,
                                  // 'createGroupMode': true,
                                },
                              );
                            },
                            child: Container(
                              height: SizeConfig.sizedBoxHeight(30),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: AppColors.appPriSecColor.secondaryColor,
                              ),
                              child: Padding(
                                padding: SizeConfig.getPaddingSymmetric(
                                  horizontal: 10,
                                ),
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      AppAssets.homeIcons.newgp,
                                      colorFilter: ColorFilter.mode(
                                        ThemeColorPalette.getTextColor(
                                          AppColors.appPriSecColor.primaryColor,
                                        ),
                                        BlendMode.srcIn,
                                      ),
                                      height: SizeConfig.sizedBoxHeight(15),
                                    ),
                                    SizedBox(width: SizeConfig.width(1)),
                                    Text(
                                      AppString.homeScreenString.newGroup,
                                      style: AppTypography.text12(context)
                                          .copyWith(
                                            fontWeight: FontWeight.w600,
                                            color:
                                                ThemeColorPalette.getTextColor(
                                                  AppColors
                                                      .appPriSecColor
                                                      .primaryColor,
                                                ),
                                            //AppThemeManage.appTheme.darkWhiteColor,
                                            fontSize: SizeConfig.getFontSize(
                                              10,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // SizedBox(height: SizeConfig.height(1)),

                    // Add search bar only for chat tab
                    if (homeProvider.selectedIndex == 0) _buildSearchBar(),
                    SizedBox(height: SizeConfig.height(1.5)),
                    Expanded(child: _buildChatTab()),
                  ],
                ),
                // AI Assistant entry point — sits above the bottom nav bar,
                // which the body extends behind (extendBody on the tabbar).
                ValueListenableBuilder<double>(
                  valueListenable: BannerAdWidget.heightNotifier,
                  builder: (context, adHeight, child) {
                    return Positioned(
                      bottom:
                          MediaQuery.of(context).viewInsets.bottom +
                          kBottomNavigationBarHeight +
                          45 +
                          adHeight,
                      right: 16,
                      child: child!,
                    );
                  },
                  child: const AiAssistantFab(),
                ),
              ],
            );
          },
        ),
        // floatingActionButton: FloatingActionButton(
        //   backgroundColor: AppColors.appPriSecColor.primaryColor,
        //   child: Icon(Icons.add, color: Colors.black, size: 50),
        //   onPressed: () => bottomSheetDesigin(),
        // ),
      ),
    );
  }

  Widget _buildChatTab() {
    return Consumer2<ChatProvider, SocketEventController>(
      builder: (context, chatProvider, socketEventController, _) {
        // Get socket connection status from the SocketEventController
        final isConnected = socketEventController.isConnected;

        if (kDebugMode) {
          debugPrint(
            '🔌 _buildChatTab: isConnected = $isConnected (from SocketEventController)',
          );
        }

        return Column(
          children: [
            // ✅ UX IMPROVEMENT: Show subtle connection banner when not connected
            // Only show after initial load is complete (has data)
            if (!isConnected && chatProvider.chatListData.chats.isNotEmpty)
              _buildConnectionBanner(chatProvider),
            // Old connection status indicator (commented out)
            // AnimatedSwitcher(
            //   duration: Duration(milliseconds: 300),
            //   child:
            //       !isConnected
            //           ? Container(
            //             key: ValueKey('disconnected'),
            //             width: double.infinity,
            //             color: Colors.orange.withValues(alpha: 0.7),
            //             padding: EdgeInsets.symmetric(
            //               vertical: 4,
            //               horizontal: 16,
            //             ),
            //             child: Row(
            //               children: [
            //                 Icon(Icons.wifi_off, size: 16, color: Colors.white),
            //                 SizedBox(width: 8),
            //                 Expanded(
            //                   child: Text(
            //                     "${AppString.connectionTochatServerlostReconnecting}...",
            //                     style: TextStyle(
            //                       color: Colors.white,
            //                       fontSize: 12,
            //                     ),
            //                   ),
            //                 ),
            //                 InkWell(
            //                   onTap: () => chatProvider.connect(),
            //                   child: Icon(
            //                     Icons.refresh,
            //                     size: 16,
            //                     color: Colors.white,
            //                   ),
            //                 ),
            //               ],
            //             ),
            //           )
            //           : SizedBox(
            //             key: ValueKey('connected'),
            //             width: double.infinity,
            //             height: 0, // Hide when connected
            //           ),
            // ),

            // ✅ UPDATED: Chat list (with pagination support)
            // Expanded(
            //   child: RefreshIndicator(
            //     onRefresh: () => chatProvider.refreshChatList(),
            //     child: Padding(
            //       padding: const EdgeInsets.only(bottom: 20),
            //       child: ChatList(
            //         onTap: (
            //           chatId,
            //           peerUser, {
            //           chatType,
            //           groupName,
            //           groupIcon,
            //         }) {
            //           if (chatType?.toLowerCase() == 'group') {
            //             NavigationHelper.navigateToGroupChat(
            //               context,
            //               chatId: chatId,
            //               groupName: groupName ?? 'Group Chat',
            //               groupProfilePic:
            //                   groupIcon ??
            //                   peerUser.profilePic ??
            //                   '', // Use groupIcon first, fallback to peerUser profilePic
            //             );
            //           } else {
            //             NavigationHelper.navigateToChat(
            //               context,
            //               chatId: chatId,
            //               userId: peerUser.userId!,
            //               fullName: peerUser.fullName ?? 'unknown',
            //               profilePic: peerUser.profilePic ?? '',
            //             );
            //           }
            //         },
            //       ),
            //     ),
            //   ),
            // ),
            Expanded(
              child: Column(
                children: [
                  // ✅ NEW: Archived Chats Section
                  Consumer<ArchiveChatProvider>(
                    builder: (context, archiveChatProvider, _) {
                      // if (archiveChatProvider.hasArchivedChats) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppThemeManage.appTheme.borderColor,
                            ),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: SizeConfig.getPaddingOnly(
                            left: 30,
                            right: 20,
                          ),
                          leading: Icon(
                            Icons.archive_outlined,
                            color: AppColors.appPriSecColor.primaryColor,
                            size: SizeConfig.sizedBoxHeight(30),
                          ),
                          title: Text(
                            AppString.homeScreenString.archived,
                            style: AppTypography.innerText14(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppThemeManage.appTheme.textGreyWhite,
                            ),
                          ),

                          trailing: archiveChatProvider.archivedTotal > 0
                              ? chatCountContainer(
                                  context,
                                  count: archiveChatProvider.archivedTotal,
                                )
                              : null,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ArchivedChatListScreen(
                                  onChatTap:
                                      (
                                        chatId,
                                        peerUser, {
                                        chatType,
                                        groupName,
                                        groupIcon,
                                        groupDescription,
                                      }) {
                                        // Navigate to the chat from archived screen
                                        // Note: We don't pop the archived screen so back navigation works correctly
                                        if (chatType?.toLowerCase() ==
                                            'group') {
                                          NavigationHelper.navigateToGroupChat(
                                            context,
                                            chatId: chatId,
                                            groupName:
                                                groupName ?? 'Group Chat',
                                            groupProfilePic: groupIcon ?? '',
                                            groupDescription: groupDescription,
                                            fromArchive:
                                                true, // Mark as from archive
                                          );
                                        } else {
                                          NavigationHelper.navigateToChat(
                                            context,
                                            chatId: chatId,
                                            userId: peerUser.userId!,
                                            fullName: ContactNameService
                                                .instance
                                                .resolveName(
                                                  userId: peerUser.userId,
                                                  firstName: peerUser.firstName,
                                                  lastName: peerUser.lastName,
                                                  fullName: peerUser.fullName,
                                                  userName: peerUser.userName,
                                                  email: peerUser.email,
                                                  fallback: 'unknown',
                                                ),
                                            profilePic:
                                                peerUser.profilePic ?? '',
                                            fromArchive:
                                                true, // Mark as from archive
                                          );
                                        }
                                      },
                                ),
                              ),
                            );
                          },
                        ),
                      );
                      // } else {
                      //   return const SizedBox.shrink();
                      // }
                    },
                  ),

                  // ✅ Chat List with Search Integration
                  Expanded(
                    child: Consumer<ChatProvider>(
                      builder: (context, chatProvider, _) {
                        // Show search results if searching, otherwise show regular chat list
                        if (chatProvider.isSearching) {
                          return _buildSearchResults(context, chatProvider);
                        } else {
                          return _buildRegularChatList(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ✅ NEW: Global pagination loading indicator at bottom
            if (kDebugMode && chatProvider.isChatListPaginationLoading)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8),
                color: AppColors.appPriSecColor.primaryColor.withValues(
                  alpha: 0.05,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: commonLoading()),
                    SizedBox(width: 8),
                    Text(
                      "${AppString.loadingMoreChats}...",
                      style: AppTypography.smallText(context).copyWith(
                        color: AppColors.appPriSecColor.primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// ✅ NEW: Build subtle connection banner for disconnected state
  Widget _buildConnectionBanner(ChatProvider chatProvider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.appPriSecColor.primaryColor,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "${AppString.connectingToChatService}...",
              style: AppTypography.smallText(context).copyWith(
                color: AppColors.appPriSecColor.primaryColor,
                fontSize: 12,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _isFirstLoginAttempt = true;
              });
              _initializeSocket();
            },
            child: Icon(
              Icons.refresh,
              size: 18,
              color: AppColors.appPriSecColor.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Build search bar widget
  Widget _buildSearchBar() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 0),
          child: GlobalTextField1(
            controller: _searchController,
            onEditingComplete: () {},
            hintText: AppString.homeScreenString.searchUser,
            context: context,
            preffixIcon: Padding(
              padding: SizeConfig.getPadding(15),
              child: SvgPicture.asset(
                AppAssets.homeIcons.search,
                colorFilter: ColorFilter.mode(
                  AppColors.textColor.textDarkGray,
                  BlendMode.srcIn,
                ),
                height: SizeConfig.safeHeight(2),
              ),
            ),
            suffixIcon:
                chatProvider.isSearching || _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: AppColors.textColor.textDarkGray,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      chatProvider.clearSearch();
                    },
                  )
                : null,
            keyboardType: TextInputType.name,
            onChanged: (value) {
              // Cancel previous timer
              _searchDebounceTimer?.cancel();

              if (value.trim().isEmpty) {
                // Clear search immediately if empty
                chatProvider.clearSearch();
                return;
              }

              // Debounced search - wait 500ms after user stops typing
              _searchDebounceTimer = Timer(
                const Duration(milliseconds: 500),
                () {
                  if (value.trim().isNotEmpty) {
                    chatProvider.searchChats(value.trim());
                  }
                },
              );
            },
          ),
        );
        // Container(
        //   margin: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 2),
        //   height: 45, // Fixed compact height
        //   decoration: BoxDecoration(
        //     color: AppColors.strokeColor.cF9F9F9,
        //     borderRadius: BorderRadius.circular(10),
        //     border: Border.all(
        //       color: AppColors.strokeColor.cECECEC,
        //       // chatProvider.isSearching
        //       //     ? AppColors.appPriSecColor.primaryColor
        //       //     : Colors.grey[300]!,
        //       width: 1,
        //     ),
        //     boxShadow: [
        //       BoxShadow(
        //         color: Colors.black.withValues(alpha: 0.05),
        //         blurRadius: 4,
        //         offset: Offset(0, 2),
        //       ),
        //     ],
        //   ),
        //   child: TextFormField(
        //     controller: _searchController,
        //     textAlignVertical: TextAlignVertical.center,
        //     style: AppTypography.text12(
        //       context,
        //     ).copyWith(fontSize: SizeConfig.getFontSize(13)),
        //     autofocus: false,
        //     focusNode: searchFocusNode,
        //     onChanged: (value) {
        //       // Cancel previous timer
        //       _searchDebounceTimer?.cancel();

        //       if (value.trim().isEmpty) {
        //         // Clear search immediately if empty
        //         chatProvider.clearSearch();
        //         return;
        //       }

        //       // Debounced search - wait 500ms after user stops typing
        //       _searchDebounceTimer = Timer(
        //         const Duration(milliseconds: 500),
        //         () {
        //           if (value.trim().isNotEmpty) {
        //             chatProvider.searchChats(value.trim());
        //           }
        //         },
        //       );
        //     },
        //     decoration: InputDecoration(
        //       hintText: AppString.homeScreenString.searchUser,
        //       hintStyle: AppTypography.text12(context).copyWith(
        //         fontSize: SizeConfig.getFontSize(13),
        //         color: Colors.grey[600],
        //       ),
        //       prefixIcon: Padding(
        //         padding: SizeConfig.getPadding(15),
        //         child: SvgPicture.asset(
        //           AppAssets.homeIcons.search,
        //           colorFilter: ColorFilter.mode(
        //             AppColors.textColor.textDarkGray,
        //             BlendMode.srcIn,
        //           ),
        //           height: SizeConfig.safeHeight(2),
        //         ),
        //       ),
        //       suffixIcon:
        //           chatProvider.isSearching || _searchController.text.isNotEmpty
        //               ? IconButton(
        //                 icon: Icon(
        //                   Icons.clear,
        //                   color: AppColors.textColor.textDarkGray,
        //                   size: 18,
        //                 ),
        //                 onPressed: () {
        //                   _searchController.clear();
        //                   chatProvider.clearSearch();
        //                 },
        //               )
        //               : null,
        //       border: InputBorder.none,
        //       contentPadding: SizeConfig.getPaddingSymmetric(
        //         horizontal: 12,
        //         vertical: 8,
        //       ),
        //       isDense: true,
        //     ),
        //   ),
        // );
      },
    );
  }

  /// Build search results view
  Widget _buildSearchResults(BuildContext context, ChatProvider chatProvider) {
    final searchResults = chatProvider.searchResults.chats;

    // Loading state. Results are filtered live out of the chat list, and a
    // chat-list refresh (e.g. returning from group info after updating the
    // group icon) empties it for the length of the round-trip — show the
    // spinner rather than flashing the "no results" empty state.
    if (chatProvider.isSearchLoading ||
        (searchResults.isEmpty && chatProvider.isChatListLoading)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            commonLoading(),
            SizedBox(height: 16),
            Text("Searching chats..."),
          ],
        ),
      );
    }

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
              style: AppTypography.h4(context)
                  .copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: AppTypography.smallText(context)
                  .copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Search Results List
    return Column(
      children: [
        // Results header
        // Container(
        //   padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 8),
        //   child: Row(
        //     children: [
        //       Icon(
        //         Icons.search,
        //         size: 16,
        //         color: AppColors.appPriSecColor.primaryColor,
        //       ),
        //       SizedBox(width: 8),
        //       Text(
        //         '${searchResults.length} result(s) found',
        //         style: AppTypography.smallText(context).copyWith(
        //           color: AppColors.appPriSecColor.primaryColor,
        //           fontWeight: FontWeight.w500,
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        SizedBox(height: SizeConfig.height(1)),

        // Results list using the same ChatList widget for consistency
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              bottom:
                  // 20 +
                  // SizeConfig.sizedBoxHeight(75) +
                  // 25 +
                  MediaQuery.of(context).padding.bottom,
            ),
            child: ListView.separated(
              itemCount: searchResults.length,
              separatorBuilder: (context, index) {
                return Divider(color: AppThemeManage.appTheme.borderColor);
              },
              itemBuilder: (context, index) {
                final chat = searchResults[index];
                return _buildSearchResultItem(chat);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Build individual search result item
  Widget _buildSearchResultItem(dynamic chat) {
    return Consumer2<ProjectConfigProvider, ChatProvider>(
      builder: (context, configProvider, chatProvider, _) {
        // Handle potential null values safely
        final peer = chat.peerUserData ?? PeerUserData();
        final record = chat.records?.isNotEmpty == true
            ? chat.records!.first
            : null;
        final lastMessage = record?.messages?.isNotEmpty == true
            ? record!.messages!.first
            : null;
        final chatType = record?.chatType ?? 'Private';
        final isGroupChat = chatType.toLowerCase() == 'group';

        // Get display name using the same logic as regular chat list
        final String displayName = isGroupChat
            ? _getGroupDisplayName(record, peer)
            : ContactNameService.instance.getDisplayName(
                userId: peer.userId,
                userFullName: peer.fullName,
                userName: peer.userName,
                userEmail: peer.email,
                configProvider: configProvider,
                firstName: peer.firstName,
                lastName: peer.lastName,
              );

        final String profilePic = _getProfilePic(isGroupChat, record, peer);

        return InkWell(
          onTap: () {
            FocusScope.of(context).unfocus();
            searchFocusNode.unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
            if (record?.chatId != null) {
              if (chatType.toLowerCase() == 'group') {
                NavigationHelper.navigateToGroupChat(
                  context,
                  chatId: record!.chatId!,
                  groupName: displayName,
                  groupProfilePic: profilePic,
                  groupDescription: record.groupDescription,
                );
              } else {
                if (kDebugMode) {
                  debugPrint(
                    'HomeScreen: Navigating to individual chat from search with peerUser.userId: ${peer.userId}',
                  );
                }
                NavigationHelper.navigateToChat(
                  context,
                  chatId: record!.chatId!,
                  userId: peer.userId!,
                  fullName: ContactNameService.instance.resolveName(
                    userId: peer.userId,
                    firstName: peer.firstName,
                    lastName: peer.lastName,
                    fullName: peer.fullName,
                    userName: peer.userName,
                    email: peer.email,
                    fallback: 'unknown',
                  ),
                  profilePic: peer.profilePic ?? '',
                );
              }
            }
          },
          child: Container(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: 17,
              vertical: 5,
            ),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CommonProfileAvatar(
                      imageUrl: profilePic,
                      name: displayName,
                      radius: SizeConfig.sizedBoxHeight(25),
                      isGroup: isGroupChat,
                    ),
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
                            color: ThemeColorPalette.getTextColor(
                              AppColors.appPriSecColor.primaryColor,
                            ), //AppThemeManage.appTheme.whiteBlck,
                            size: 12,
                          ),
                        ),
                      ),
                    // else if (isOnline)
                    //   Positioned(
                    //     right: 0,
                    //     bottom: 0,
                    //     child: Container(
                    //       width: 12,
                    //       height: 12,
                    //       decoration: BoxDecoration(
                    //         color: Colors.green,
                    //         shape: BoxShape.circle,
                    //         border: Border.all(
                    //           color: AppThemeManage.appTheme.borderColor,
                    //           width: 2,
                    //         ),
                    //       ),
                    //     ),
                    //   ),
                  ],
                ),

                // Container(
                //   height: SizeConfig.sizedBoxHeight(50),
                //   width: SizeConfig.sizedBoxWidth(50),
                //   decoration: BoxDecoration(
                //     borderRadius: BorderRadius.circular(55),
                //     color: AppColors.white,
                //     border: Border.all(
                //       color: AppThemeManage.appTheme.borderColor,
                //     ),
                //   ),
                //   child: ClipRRect(
                //     borderRadius: BorderRadius.circular(55),
                //     child: _buildAvatar(profilePic, isGroupChat),
                //   ),
                // ),
                SizedBox(width: SizeConfig.width(3)),

                // Chat Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chat name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: UserNameWithBadge(
                                userId: isGroupChat ? null : peer.userId,
                                name: displayName,
                                style: AppTypography.innerText14(context)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          // Chat type indicator
                          if (isGroupChat) ...[
                            Icon(
                              Icons.group,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ],
                          Text(
                            "  ${chatProvider.formatTime(_getChatTimestamp(record))}",
                            style: AppTypography.innerText10(context).copyWith(
                              color: AppColors.textColor.textGreyColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 4),

                      // Last message preview — rendered by the exact same
                      // widget the chat list row uses, so call logs and group
                      // lifecycle events (whose text is derived, not stored in
                      // messageContent) don't come out blank here.
                      ChatLastMessagePreview(
                        lastMessage: lastMessage,
                        isGroupChat: isGroupChat,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _getChatTimestamp(Records? record) {
    if (record == null) return null;

    // Priority: updatedAt -> createdAt -> null
    if (record.updatedAt != null && record.updatedAt!.trim().isNotEmpty) {
      return record.updatedAt;
    }

    if (record.createdAt != null && record.createdAt!.trim().isNotEmpty) {
      return record.createdAt;
    }

    return null;
  }

  /// Group display name logic - same as main chat list
  String _getGroupDisplayName(Records? record, PeerUserData? peer) {
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

  /// Build regular chat list view
  Widget _buildRegularChatList(BuildContext context) {
    return ChatList(
      // padding: EdgeInsets.only(bottom: 20 + SizeConfig.sizedBoxHeight(75) + MediaQuery.of(context).padding.bottom),
      onTap: (chatId, peerUser, {chatType, groupName, groupIcon, groupDescription}) {
        FocusScope.of(context).unfocus();
        searchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
        if (chatType?.toLowerCase() == 'group') {
          NavigationHelper.navigateToGroupChat(
            context,
            chatId: chatId,
            groupName: groupName ?? 'Group Chat',
            groupProfilePic: groupIcon ?? '',
            groupDescription: groupDescription,
          );
        } else if (chatType?.toLowerCase() == 'admin_broadcast') {
          toUserProfileCall = peerUser.profilePic ?? '';
          logger.v("peerUser.userId!:${peerUser.userId!}");
          NavigationHelper.navigateToChat(
            context,
            chatId: chatId,
            userId: peerUser.userId!,
            fullName: ContactNameService.instance.resolveName(
              userId: peerUser.userId,
              firstName: peerUser.firstName,
              lastName: peerUser.lastName,
              fullName: peerUser.fullName,
              userName: peerUser.userName,
              email: peerUser.email,
              fallback: 'unknown',
            ),
            profilePic: peerUser.profilePic ?? '',
            isAdminChat: true,
          );
        } else {
          if (kDebugMode) {
            debugPrint(
              'HomeScreen: Navigating to individual chat with peerUser.userId: ${peerUser.userId}',
            );
          }
          toUserProfileCall = peerUser.profilePic ?? '';
          NavigationHelper.navigateToChat(
            context,
            chatId: chatId,
            userId: peerUser.userId!,
            fullName: ContactNameService.instance.resolveName(
              userId: peerUser.userId,
              firstName: peerUser.firstName,
              lastName: peerUser.lastName,
              fullName: peerUser.fullName,
              userName: peerUser.userName,
              email: peerUser.email,
              fallback: 'unknown',
            ),
            profilePic: peerUser.profilePic ?? '',
          );
        }
      },
    );
  }

  Future<void> bottomSheetDesigin() {
    return bottomSheetGobal(
      context,
      bottomsheetHeight: SizeConfig.height(23),
      title: "Create Group",
      child: Container(), // customize as needed
    );
  }
}
