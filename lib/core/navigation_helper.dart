import 'package:flutter/material.dart';
import 'package:whoxa/core/app_route_tracker.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/services/local_notification_service.dart';
import 'package:whoxa/featuers/call/call_provider.dart';
import 'package:whoxa/featuers/call/call_ui.dart';
import 'package:whoxa/featuers/call/call_model.dart';
import 'package:whoxa/screens/splash_screen.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';

class NavigationHelper {
  // Add global navigator key for call notifications
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Tracks the root navigator's stack; registered on MaterialApp in main.dart.
  static final AppRouteTracker routeTracker = AppRouteTracker();

  /// Tells a subscribed screen (RouteAware) when a full-screen route above it
  /// closes. Dialogs/sheets don't count. Registered on MaterialApp.
  static final RouteObserver<PageRoute<dynamic>> pageRouteObserver =
      RouteObserver<PageRoute<dynamic>>();

  static NavigatorState? get navigator => navigatorKey.currentState;
  static BuildContext? get context => navigator?.context;

  static BuildContext? _currentCallScreenContext;

  // ✅ CRITICAL: Add navigation state tracking to prevent duplicates
  static bool _isNavigatingToCall = false;
  static String? _lastNavigatedCallId;
  static DateTime? _lastNavigationTime;
  static const int _navigationCooldownMs = 2000; // 2 seconds cooldown

  static bool get getIsNavigatingCall => _isNavigatingToCall;

  // Check if call screen is active
  static bool get isCallScreenActive => _currentCallScreenContext != null;

  static BuildContext? getCurrentContext() {
    return navigatorKey.currentContext;
  }

  // Dismiss call screen
  static void dismissCurrentCallScreen([String? reason]) {
    debugPrint('📞 Dismissing call screen${reason != null ? ': $reason' : ''}');

    try {
      // Method 1: If we have tracked context, use it
      if (_currentCallScreenContext != null &&
          _currentCallScreenContext!.mounted) {
        Navigator.of(_currentCallScreenContext!).pop();
        _currentCallScreenContext = null;
        debugPrint('✅ Call screen dismissed successfully');
        return;
      }

      // Method 2: Use main navigator context
      final context = NavigationHelper.context;
      if (context != null) {
        // Try to pop the topmost route if it looks like a call screen
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          debugPrint('✅ Popped topmost screen (assumed call screen)');
        }
      }
    } catch (e) {
      debugPrint('❌ Error dismissing call screen: $e');
    }
  }

  /// Navigate to individual chat (backward compatible)
  static void navigateToChat(
    BuildContext context, {
    required int userId,
    int? chatId,
    String? fullName,
    String? profilePic,
    String? updatedAt,
    int unseenCount = 0, // ✅ NEW: Add unseenCount parameter
    bool fromArchive = false, // ✅ NEW: Add fromArchive parameter
    bool isAdminChat = false,
    String? userType,
  }) {
    debugPrint(
      'NavigationHelper: navigateToChat called with userId: $userId, chatId: $chatId, fullName: $fullName, unseenCount: $unseenCount',
    );

    // Get instant block status from chat provider
    bool isBlocked = false;
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.resetAll();

      // ✅ NEW: Use enhanced onChatItemTap if unseenCount > 0
      if (chatId != null && chatId > 0 && unseenCount > 0) {
        debugPrint(
          'Using enhanced onChatItemTap for chat with $unseenCount unseen messages',
        );

        // Call the new enhanced method
        chatProvider.onChatItemTap(
          chatId: chatId,
          unseenCount: unseenCount,
          fromArchive: fromArchive,
          userId: userId,
          chatName: fullName,
          profilePic: profilePic,
          isGroupChat: false,
          isAdminChat: isAdminChat,
        );
      }

      if (chatId != null && chatId > 0) {
        isBlocked = chatProvider.getInstantBlockStatus(chatId);
      } else {
        isBlocked = chatProvider.getInstantBlockStatusByUserId(userId);
      }
    } catch (e) {
      debugPrint(
        'NavigationHelper: Error in enhanced navigation or getting block status: $e',
      );
    }

    Navigator.pushNamed(
      context,
      AppRoutes.universalChat, // Use universal route
      arguments: {
        'userId': userId,
        'chatId': chatId ?? 0,
        'chatName': fullName ?? '',
        'profilePic': profilePic ?? '',
        'updatedAt': updatedAt,
        'isGroupChat': false,
        'blockFlag': isBlocked, // Pass instant block status
        'unseenCount': unseenCount, // ✅ Pass unseenCount to UniversalScreen
        'fromArchive': fromArchive, // ✅ Pass fromArchive flag
        'isAdminChat': isAdminChat,
      },
    ).then((_) {
      if (!context.mounted) return;
      FocusScope.of(context).unfocus();
    });
  }

  /// Navigate to individual chat (enhanced version)
  static void navigateToIndividualChat(
    BuildContext context, {
    required int userId,
    required String userName,
    required String profilePic,
    int? chatId,
    String? updatedAt,
    int? highlightMessageId, // Add parameter for message highlighting
    int unseenCount = 0, // ✅ NEW: Add unseenCount parameter
    bool fromArchive = false, // ✅ NEW: Add fromArchive parameter
    bool isAdminChat = true,
  }) {
    // Get instant block status from chat provider
    bool isBlocked = false;
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.resetAll();

      // ✅ NEW: Use enhanced onChatItemTap if unseenCount > 0
      if (chatId != null && chatId > 0 && unseenCount > 0) {
        debugPrint(
          'Using enhanced onChatItemTap for individual chat with $unseenCount unseen messages',
        );

        // Call the new enhanced method
        chatProvider.onChatItemTap(
          chatId: chatId,
          unseenCount: unseenCount,
          fromArchive: fromArchive,
          userId: userId,
          chatName: userName,
          profilePic: profilePic,
          isGroupChat: false,
          isAdminChat: isAdminChat,
        );
      }

      if (chatId != null && chatId > 0) {
        isBlocked = chatProvider.getInstantBlockStatus(chatId);
      } else {
        isBlocked = chatProvider.getInstantBlockStatusByUserId(userId);
      }
    } catch (e) {
      debugPrint('NavigationHelper: Error getting block status: $e');
    }

    Navigator.pushNamed(
      context,
      AppRoutes.universalChat,
      arguments: {
        'userId': userId,
        'chatId': chatId,
        'chatName': userName,
        'profilePic': profilePic,
        'updatedAt': updatedAt,
        'isGroupChat': false,
        'blockFlag': isBlocked, // Pass instant block status
        'highlightMessageId': highlightMessageId, // Pass highlight parameter
        'unseenCount': unseenCount, // ✅ Pass unseenCount to UniversalScreen
        'fromArchive': fromArchive, // ✅ Pass fromArchive flag
        'isAdminChat': isAdminChat,
      },
    );
  }

  /// Navigate to group chat
  static void navigateToGroupChat(
    BuildContext context, {
    required int chatId,
    required String groupName,
    required String groupProfilePic,
    String? groupDescription,
    String? updatedAt,
    int? highlightMessageId, // Add parameter for message highlighting
    int unseenCount = 0, // ✅ NEW: Add unseenCount parameter
    bool fromArchive = false, // ✅ NEW: Add fromArchive parameter
    bool isAdminChat = false,
  }) {
    // Get instant block status from chat provider
    bool isBlocked = false;
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.resetAll();

      // ✅ NEW: Use enhanced onChatItemTap if unseenCount > 0
      if (unseenCount > 0) {
        debugPrint(
          'Using enhanced onChatItemTap for group chat with $unseenCount unseen messages',
        );

        // Call the new enhanced method
        chatProvider.onChatItemTap(
          chatId: chatId,
          unseenCount: unseenCount,
          fromArchive: fromArchive,
          userId: null, // Group chats don't have a specific userId
          chatName: groupName,
          profilePic: groupProfilePic,
          isGroupChat: true,
          isAdminChat: isAdminChat,
        );
      }

      isBlocked = chatProvider.getInstantBlockStatus(chatId);
    } catch (e) {
      debugPrint('NavigationHelper: Error getting block status for group: $e');
    }
    Navigator.pushNamed(
      context,
      AppRoutes.universalChat,
      arguments: {
        'chatId': chatId,
        'chatName': groupName,
        'profilePic': groupProfilePic,
        'updatedAt': updatedAt,
        'isGroupChat': true,
        'groupDescription': groupDescription,
        'blockFlag': isBlocked, // Pass instant block status
        'highlightMessageId': highlightMessageId, // Pass highlight parameter
        'unseenCount': unseenCount, // ✅ Pass unseenCount to UniversalScreen
        'fromArchive': fromArchive, // ✅ Pass fromArchive flag
        'isAdminChat': isAdminChat,
      },
    ).then((_) {
      if (!context.mounted) return;
      FocusScope.of(context).unfocus();
    });
  }

  /// Navigate from chat list item with automatic detection
  static void navigateFromChatRecord(
    BuildContext context,
    chats.Records chatRecord, {
    bool fromArchive = false, // ✅ NEW: Add fromArchive parameter
    bool isAdminChat = false,
  }) {
    // Determine if it's a group chat
    final isGroupChat = _isGroupChatRecord(chatRecord);

    // ✅ NEW: Get unseenCount from the chat record
    final unseenCount = chatRecord.unseenCount ?? 0;

    if (isGroupChat) {
      navigateToGroupChat(
        context,
        chatId: chatRecord.chatId ?? 0,
        groupName: _getGroupName(chatRecord),
        groupProfilePic: _getGroupProfilePic(chatRecord),
        groupDescription: _getGroupDescription(chatRecord),
        updatedAt: chatRecord.updatedAt,
        unseenCount: unseenCount, // ✅ Pass unseenCount
        fromArchive: fromArchive, // ✅ Pass fromArchive\
        isAdminChat: isAdminChat,
      );
    } else {
      final peerUser = chatRecord.peerUserData;
      if (peerUser != null) {
        navigateToIndividualChat(
          context,
          userId: peerUser.userId ?? 0,
          userName: ContactNameService.instance.resolveName(
            userId: peerUser.userId,
            firstName: peerUser.firstName,
            lastName: peerUser.lastName,
            fullName: peerUser.fullName,
            userName: peerUser.userName,
            email: peerUser.email,
            fallback: 'Unknown User',
          ),
          profilePic: peerUser.profilePic ?? '',
          chatId: chatRecord.chatId,
          updatedAt: chatRecord.updatedAt,
          unseenCount: unseenCount, // ✅ Pass unseenCount
          fromArchive: fromArchive, // ✅ Pass fromArchive
          isAdminChat: isAdminChat,
        );
      }
    }
  }

  // ✅ NEW: Enhanced helper method for ChatList and ArchiveList widgets
  /// Navigate to chat with comprehensive unseenCount and archive support
  /// This is the recommended method to use from ChatList and ArchiveList widgets
  static void navigateToUniversalChat(
    BuildContext context, {
    required int chatId,
    required int unseenCount,
    required bool fromArchive,
    required bool isAdminChat,
    int? userId,
    String? chatName,
    String? profilePic,
    String? updatedAt,
    bool isGroupChat = false,
    String? groupDescription,
    int? highlightMessageId,
  }) {
    debugPrint(
      'NavigationHelper: navigateToUniversalChat - chatId: $chatId, unseenCount: $unseenCount, fromArchive: $fromArchive',
    );

    if (isGroupChat) {
      navigateToGroupChat(
        context,
        chatId: chatId,
        groupName: chatName ?? 'Group Chat',
        groupProfilePic: profilePic ?? '',
        groupDescription: groupDescription,
        updatedAt: updatedAt,
        highlightMessageId: highlightMessageId,
        unseenCount: unseenCount,
        fromArchive: fromArchive,
        isAdminChat: isAdminChat,
      );
    } else {
      navigateToIndividualChat(
        context,
        userId: userId ?? 0,
        userName: chatName ?? 'Unknown User',
        profilePic: profilePic ?? '',
        chatId: chatId,
        updatedAt: updatedAt,
        highlightMessageId: highlightMessageId,
        unseenCount: unseenCount,
        fromArchive: fromArchive,
        isAdminChat: isAdminChat,
      );
    }
  }

  /// Navigate to contact list for group creation
  static void navigateToCreateGroup(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.contactListScreen,
      arguments: {'createGroupMode': true},
    );
  }

  static void navigateToActiveCall({
    required BuildContext context,
    required Map<String, dynamic> callData,
  }) {
    Navigator.pushNamed(
      context,
      '/active-call', // Add this route to your AppRoutes
      arguments: callData,
    );
  }

  /// Navigate to chat screen from call
  static void navigateToChatFromCall({
    required BuildContext context,
    required int chatId,
    required int userId,
    required String userName,
    String? profilePic,
  }) {
    // First, pop any existing call screens
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Then navigate to chat
    navigateToIndividualChat(
      context,
      userId: userId,
      userName: userName,
      profilePic: profilePic ?? '',
      chatId: chatId,
    );
  }

  // Helper methods for chat type detection
  static bool _isGroupChatRecord(chats.Records chatRecord) {
    // Method 1: Check message type
    if (chatRecord.messageType?.toLowerCase() == 'group') {
      return true;
    }
    return false; // Default to individual chat
  }

  static String _getGroupName(chats.Records chatRecord) {
    // Try to extract group name from various sources
    if (chatRecord.peerUserData?.fullName != null) {
      return chatRecord.peerUserData!.fullName!;
    }

    final content = chatRecord.messageContent ?? '';
    if (content.contains('group') &&
        chatRecord.messageType == 'group-created') {
      final parts = content.split(' ');
      if (parts.length > 3) {
        final nameIndex = parts.indexWhere(
          (part) => part.toLowerCase() == 'group',
        );
        if (nameIndex > 0) {
          return parts.take(nameIndex).join(' ');
        }
      }
    }

    return 'Group Chat';
  }

  static String _getGroupProfilePic(chats.Records chatRecord) {
    return chatRecord.peerUserData?.profilePic ?? '';
  }

  static String? _getGroupDescription(chats.Records chatRecord) {
    return null;
  }

  // =============================================================================
  // ✅ FIXED: ENHANCED CALL NAVIGATION WITH DUPLICATE PREVENTION
  // =============================================================================

  /// ✅ CRITICAL FIX: Generate unique call identifier for deduplication
  static String _generateCallIdentifier(Map<String, dynamic> callData) {
    final chatId = callData['chatId']?.toString() ?? '0';
    final callId = callData['callId']?.toString() ?? '0';
    final callerName = callData['callerName']?.toString() ?? 'unknown';
    final callType = callData['callType']?.toString() ?? 'audio';

    return '${chatId}_${callId}_${callerName}_$callType';
  }

  /// ✅ CRITICAL FIX: Check if navigation is allowed
  static bool _canNavigateToCall(String callIdentifier) {
    final now = DateTime.now();

    // Check if already navigating
    if (_isNavigatingToCall) {
      debugPrint('🚫 Already navigating to call, skipping duplicate');
      return false;
    }

    // Check cooldown period
    if (_lastNavigationTime != null) {
      final timeSinceLastNavigation =
          now.difference(_lastNavigationTime!).inMilliseconds;
      if (timeSinceLastNavigation < _navigationCooldownMs) {
        debugPrint(
          '🚫 Navigation cooldown active (${timeSinceLastNavigation}ms < ${_navigationCooldownMs}ms)',
        );
        return false;
      }
    }

    // Check if same call ID
    if (_lastNavigatedCallId == callIdentifier) {
      debugPrint('🚫 Same call already navigated: $callIdentifier');
      return false;
    }

    return true;
  }

  /// ✅ FIXED: Navigate to full-screen outgoing call with duplicate prevention
  static void navigateToOutgoingCall({
    required BuildContext context,
    required int chatId,
    required String chatName,
    required String profilePic,
    required CallType callType,
  }) {
    final callIdentifier = _generateCallIdentifier({
      'chatId': chatId,
      'callId': 0, // Outgoing calls don't have call ID yet
      'callerName': chatName,
      'callType': callType.name,
    });

    if (!_canNavigateToCall(callIdentifier)) {
      return;
    }

    debugPrint('📞 Navigating to outgoing call: $chatName (${callType.name})');

    _isNavigatingToCall = true;
    _lastNavigatedCallId = callIdentifier;
    _lastNavigationTime = DateTime.now();

    try {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) {
                _currentCallScreenContext = context;
                return CallScreen(
                  chatId: chatId,
                  chatName: chatName,
                  callType: callType,
                  isIncoming: false,
                );
              },
              fullscreenDialog: true,
              settings: RouteSettings(name: '/outgoing-call'),
            ),
          )
          .then((_) {
            // Reset state when navigation completes
            _isNavigatingToCall = false;
            _currentCallScreenContext = null;
          });

      debugPrint('✅ Navigation successful navigateToOutgoingCall');
    } catch (e) {
      debugPrint('❌ Error navigating to outgoing call: $e');
      _isNavigatingToCall = false;
    }
  }

  /// ✅ FIXED: Navigate to full-screen incoming call with duplicate prevention
  static void navigateToIncomingCall({
    required BuildContext context,
    required int chatId,
    required String chatName,
    required String profilePic,
    required CallType callType,
  }) {
    final callIdentifier = _generateCallIdentifier({
      'chatId': chatId,
      'callId': 0, // Use 0 if call ID not available
      'callerName': chatName,
      'callType': callType.name,
    });

    if (!_canNavigateToCall(callIdentifier)) {
      return;
    }

    debugPrint('📞 Navigating to incoming call: $chatName (${callType.name})');

    _isNavigatingToCall = true;
    _lastNavigatedCallId = callIdentifier;
    _lastNavigationTime = DateTime.now();

    try {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) {
                _currentCallScreenContext = context;
                return CallScreen(
                  chatId: chatId,
                  chatName: chatName,
                  callType: callType,
                  isIncoming: true,
                );
              },
              fullscreenDialog: true,
              settings: RouteSettings(name: '/incoming-call'),
            ),
          )
          .then((_) {
            // Reset state when navigation completes
            _isNavigatingToCall = false;
            _currentCallScreenContext = null;
          });

      debugPrint('✅ Navigation successful navigateToIncomingCall');
    } catch (e) {
      debugPrint('❌ Error navigating to incoming call: $e');
      _isNavigatingToCall = false;
    }
  }

  /// ✅ FIXED: Navigate to full-screen incoming call using call data with enhanced deduplication
  static void navigateToIncomingCallFromData(Map<String, dynamic> callData) {
    final context = getCurrentContext();
    if (context == null) {
      debugPrint('❌ No context available for incoming call navigation');
      return;
    }

    final callIdentifier = _generateCallIdentifier(callData);

    if (!_canNavigateToCall(callIdentifier)) {
      return;
    }

    final callType =
        (callData['callType'] == 'video') ? CallType.video : CallType.audio;

    debugPrint('📞 Navigating to incoming call from data: $callData');

    // ✅ Mark that user came from notification tap
    SplashNavigationTracker.markCameFromNotification();
    debugPrint(
      '🔔 Marked as came from notification tap: ${SplashNavigationTracker.cameFromNotificationTap}',
    );

    _isNavigatingToCall = true;
    _lastNavigatedCallId = callIdentifier;
    _lastNavigationTime = DateTime.now();

    try {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) {
                _currentCallScreenContext = context;
                return CallScreen(
                  chatId: _callDataInt(callData['chatId']),
                  chatName:
                      _callDataString(callData['callerName']) ??
                      'Unknown Caller',
                  callType: callType,
                  isIncoming: true,
                );
              },
              fullscreenDialog: true,
              settings: RouteSettings(name: '/incoming-call-from-data'),
            ),
          )
          .then((_) {
            // Reset call navigation state when navigation completes
            _isNavigatingToCall = false;
            _currentCallScreenContext = null;
          });

      debugPrint('✅ Navigation successful navigateToIncomingCallFromData');
    } catch (e) {
      debugPrint('❌ Error navigating from call data: $e');
      _isNavigatingToCall = false;
    }
  }

  /// ✅ IMPROVED: Dismiss call screen with state cleanup
  static void dismissCallScreen({String? reason}) {
    final context = getCurrentContext();
    if (context == null) {
      debugPrint('❌ No context available to dismiss call screen');
      return;
    }

    try {
      // Check if we're on a call screen
      final currentRoute = ModalRoute.of(context);
      final routeName = currentRoute?.settings.name;

      if (routeName?.contains('call') == true) {
        Navigator.of(context).pop();
        debugPrint(
          '✅ Dismissed call screen${reason != null ? ': $reason' : ''}',
        );

        // ✅ Reset navigation state
        _isNavigatingToCall = false;
        _currentCallScreenContext = null;

        // Optional: Reset call identifier after some time to allow re-calls
        Future.delayed(Duration(seconds: 5), () {
          _lastNavigatedCallId = null;
        });
      } else {
        debugPrint('⚠️ Not currently on a call screen');
      }
    } catch (e) {
      debugPrint('❌ Error dismissing call screen: $e');
    }
  }

  /// Check if currently on call screen
  static bool isOnCallScreen() {
    final context = getCurrentContext();
    if (context != null) {
      final currentRoute = ModalRoute.of(context);
      final routeName = currentRoute?.settings.name;
      return routeName?.contains('call') == true;
    }
    return false;
  }

  /// ✅ FORCE RESET: Reset navigation state (use in emergencies)
  static void forceResetNavigationState() {
    debugPrint('🔄 Force resetting navigation state');
    _isNavigatingToCall = false;
    _lastNavigatedCallId = null;
    _lastNavigationTime = null;
    _currentCallScreenContext = null;
  }

  // =============================================================================
  // ✅ FIXED: ENHANCED INCOMING CALL HANDLER
  // =============================================================================

  /// ✅ FIXED: Handle incoming call notification with proper deduplication
  static void handleIncomingCall(Map<String, dynamic> callData) {
    final context = getCurrentContext();
    if (context == null) {
      debugPrint('❌ No navigation context available for incoming call');
      _fallbackToNotification(callData);
      return;
    }

    debugPrint('📞 Handling incoming call with full-screen UI: $callData');

    // ✅ CRITICAL: Check if we can navigate before proceeding
    final callIdentifier = _generateCallIdentifier(callData);
    if (!_canNavigateToCall(callIdentifier)) {
      debugPrint(
        '🚫 Cannot navigate to call (duplicate/cooldown): $callIdentifier',
      );
      return;
    }

    // Check if app is in foreground and context is available
    if (_isAppInForeground()) {
      // Use full-screen incoming call UI
      navigateToIncomingCallFromData(callData);
    } else {
      // Fallback to notification for background state
      _fallbackToNotification(callData);
    }
  }

  // A `callData` map reaches these methods from three sources that disagree
  // on the type of every id in it:
  //   * CallManager's CallInfo — `callId`/`peerId` are Strings, because
  //     IdCodec renders every backend id as a String for BigInt safety;
  //   * FcmService._extractCallData — `chatId`/`callId` are ints;
  //   * raw socket payloads — whatever the backend serialized.
  // Reading them with a bare `?? 0` and handing the result to an `int`
  // parameter therefore threw "type 'String' is not a subtype of type 'int'"
  // and aborted the whole call, so a backgrounded user got no incoming-call
  // notification at all. Coerce rather than assume.
  static int _callDataInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static String? _callDataString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Fallback to notification when full-screen navigation isn't available
  static void _fallbackToNotification(Map<String, dynamic> callData) {
    debugPrint('📱 Using notification fallback for incoming call');

    try {
      final callNotificationService = CallNotificationService();
      callNotificationService.showIncomingCallNotification(
        callerName: _callDataString(callData['callerName']) ?? 'Unknown Caller',
        callType: _callDataString(callData['callType']) ?? 'audio',
        chatId: _callDataInt(callData['chatId']),
        callId: _callDataInt(callData['callId']),
        peerId: _callDataString(callData['peerId']),
        callerAvatar: _callDataString(callData['callerAvatar']),
        autoDismissSeconds: 30,
      );

      // showIncomingCallNotification() owns the expiry timer only when it
      // actually posts something, and it currently does not — the banner in
      // the shade is the OS-rendered FCM one. Arm the fallback here instead,
      // from the app process, where the timer survives.
      callNotificationService.scheduleIncomingCallExpiry(
        reason: 'incoming call ringing (socket)',
      );
    } catch (e) {
      debugPrint('❌ Error showing notification fallback: $e');
    }
  }

  /// Check if app is in foreground
  static bool _isAppInForeground() {
    final context = getCurrentContext();
    if (context == null) {
      debugPrint(
        '🔍 _isAppInForeground: No context available - using notification fallback',
      );
      return false;
    }

    // CRITICAL FIX: Proper app lifecycle state detection
    // - resumed: App is in foreground and active ✅ Show incoming call screen
    // - inactive: App is in foreground but not receiving events (e.g., during calls) ✅ Show incoming call screen
    // - paused: App is backgrounded but may still be visible ❌ Use notifications
    // - detached: App is backgrounded and not visible ❌ Use notifications
    // - hidden: App is hidden by the system ❌ Use notifications
    final lifecycleState = WidgetsBinding.instance.lifecycleState;

    debugPrint(
      '🔍 _isAppInForeground: Current lifecycle state: $lifecycleState',
    );

    final isInForeground =
        lifecycleState == AppLifecycleState.resumed ||
        lifecycleState == AppLifecycleState.inactive;

    debugPrint(
      '🔍 _isAppInForeground: Result: $isInForeground (will ${isInForeground ? 'show incoming call screen' : 'use notification fallback'})',
    );

    return isInForeground;
  }

  // =============================================================================
  // CALL ACTION HANDLERS (Updated for full-screen)
  // =============================================================================

  /// Handle call acceptance from full-screen UI
  static void handleCallAcceptFromFullScreen({
    required BuildContext context,
    required int chatId,
    required int? callId,
    required String? peerId,
    required CallType callType,
  }) {
    debugPrint('✅ Accepting call from full-screen UI');

    try {
      // Use your existing call provider or service
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      callProvider.acceptCall();

      // The screen will automatically transition to connected state
      // due to the Consumer<CallProvider> in FullScreenCallScreen
    } catch (e) {
      debugPrint('❌ Error accepting call: $e');
      _showCallError(context, 'Failed to accept call');
    }
  }

  /// Handle call decline from full-screen UI
  static void handleCallDeclineFromFullScreen({
    required BuildContext context,
    required int chatId,
    required int? callId,
    required String? peerId,
  }) {
    debugPrint('❌ Declining call from full-screen UI');

    try {
      // Use your existing call provider or service
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      callProvider.declineCall();

      // Navigate back to previous screen
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('❌ Error declining call: $e');
      Navigator.of(context).pop(); // Still go back on error
    }
  }

  /// Handle call end from full-screen UI
  static void handleCallEndFromFullScreen({
    required BuildContext context,
    required int chatId,
    required int? callId,
    required String? peerId,
  }) {
    debugPrint('🔚 Ending call from full-screen UI');

    try {
      // Use your existing call provider or service
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      // leaveCall(), not endCall(): a group call stays alive for everyone else
      // (backend emits `call_session_left` for this user only); it collapses to
      // `call_session_ended` on its own when ≤1 participant is left.
      callProvider.leaveCall();

      // Navigate back to previous screen
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('❌ Error ending call: $e');
      Navigator.of(context).pop(); // Still go back on error
    }
  }

  /// Show call error message
  static void _showCallError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
