// *****************************************************************************************
// * Filename: fcm_service.dart                                                            *
// * Description: Firebase Cloud Messaging service - replaces OneSignalService             *
// *****************************************************************************************

import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/core/services/chat_notification_navigator.dart';
import 'package:whoxa/core/services/local_notification_service.dart';
import 'package:whoxa/core/services/cold_start_handler.dart';
import 'package:whoxa/featuers/call/call_manager.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

/// Registered via FirebaseMessaging.onBackgroundMessage in main.dart. Runs in
/// its own isolate with no access to the running app's state/UI, so this can
/// only do isolate-safe work (Firebase.initializeApp is required before any
/// other Firebase call here since the background isolate hasn't run main()).
/// Must be a top-level function, not a method.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Logged here too (not just in handleBackgroundMessage) so the payload is on
  // record even if the handler below throws before reaching its own dump.
  FcmService.logRemoteMessage('backgroundHandler(entry)', message);
  // FcmService() here is a fresh singleton local to THIS isolate, not the
  // one the running app uses — its CallNotificationService needs its own
  // independent initialize() before it can show anything.
  await FcmService().handleBackgroundMessage(message);
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule('FcmService');
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final CallNotificationService _callNotificationService =
      CallNotificationService();

  String? _token;
  bool _isInitialized = false;
  bool _isAppInForeground = true;
  bool _checkedColdStartMessage = false;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  /// How recently a cold-start push must have been sent for the app to still
  /// act on it. Longer than the 30s ring timeout so a slow tap still works,
  /// short enough that a replayed launch Intent never gets through.
  static const Duration _coldStartMaxAge = Duration(seconds: 60);

  final Set<String> _processedNotifications = <String>{};
  final Map<String, DateTime> _notificationTimestamps = <String, DateTime>{};
  static const Duration _deduplicationWindow = Duration(seconds: 5);

  String? get token => _token;
  bool get isInitialized => _isInitialized;

  /// Reads the notification that launched the app from a terminated state,
  /// as early as possible — call this before `runApp()`, well before
  /// `initialize()` (which only runs from `MyApp.initState()`'s post-frame
  /// callback, gated behind the slower permission-request and `getToken()`
  /// network round-trip). Without this, an incoming-call cold start races
  /// SplashScreen's own post-frame callback: whichever finishes first (FCM
  /// setup vs. the splash's project-config fetch) decides whether
  /// `ColdStartHandler` has the pending call yet, so the app would sometimes
  /// flash through the splash screen (or even the tabbar) before the call
  /// screen showed up. Calling this up front removes the race entirely — the
  /// pending call data is already stored before the widget tree is built.
  Future<void> checkColdStartNotification() async {
    if (_checkedColdStartMessage) return;
    _checkedColdStartMessage = true;
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage == null) {
        _logger.i('No cold-start notification - app opened normally');
        return;
      }

      _logger.i(
        'App opened from terminated state via notification (cold-start check)',
      );
      logRemoteMessage('getInitialMessage (cold start)', initialMessage);

      // The freshness window exists for ringing calls; a chat message is
      // still worth opening however long it sat in the tray.
      if (await _isStaleColdStartMessage(
        initialMessage,
        enforceMaxAge: !_isChatMessagePush(initialMessage),
      )) {
        return;
      }

      _handleMessageOpenedApp(initialMessage);
    } catch (e) {
      _logger.e('Error checking cold start notification', e);
    }
  }

  /// A cold-start push is only worth acting on once, and only while it is
  /// still fresh. Two separate things go wrong otherwise:
  ///
  /// * Android hands the *launch Intent* to every new process started from
  ///   the same task — a relaunch from the launcher, from recents, or from
  ///   `flutter run` — so `getInitialMessage()` keeps returning the very same
  ///   push long after it was tapped. Without this guard, every restart
  ///   re-opens the ringing call screen for a call that ended ages ago. The
  ///   replayed message is recognisable (`sentTime` comes back as epoch 0 and
  ///   the `notification` block is gone), but the reliable signal is its
  ///   `messageId`, which is why the last handled one is persisted.
  /// * Even a genuine tap can land after the caller has already hung up —
  ///   the age check, skipped via [enforceMaxAge] for pushes that never go
  ///   stale (chat messages).
  ///
  /// Returns true when the message should be ignored.
  Future<bool> _isStaleColdStartMessage(
    RemoteMessage message, {
    bool enforceMaxAge = true,
  }) async {
    final sentTime = message.sentTime;
    if (enforceMaxAge && sentTime != null) {
      final age = DateTime.now().difference(sentTime);
      // A negative age means the device clock is behind the server's - treat
      // that as fresh rather than guessing.
      if (!age.isNegative && age > _coldStartMaxAge) {
        _logger.w(
          'Ignoring cold-start notification ${message.messageId}: sent '
          '${age.inSeconds}s ago (sentTime: $sentTime), older than the '
          '${_coldStartMaxAge.inSeconds}s freshness window',
        );
        return true;
      }
    }

    final messageId = message.messageId;
    if (messageId == null || messageId.isEmpty) {
      return false;
    }

    try {
      final lastHandledId = await SecurePrefs.getString(
        SecureStorageKeys.LAST_COLD_START_MESSAGE_ID,
      );
      if (lastHandledId == messageId) {
        _logger.w(
          'Ignoring cold-start notification $messageId: already handled on an '
          'earlier launch (Android replayed the launch Intent)',
        );
        return true;
      }

      await SecurePrefs.setString(
        SecureStorageKeys.LAST_COLD_START_MESSAGE_ID,
        messageId,
      );
    } catch (e) {
      // Storage failure must not stop a legitimate incoming call.
      _logger.e('Error reading/writing the last cold-start message id', e);
    }

    return false;
  }

  Future<bool> initialize() async {
    if (_isInitialized) {
      _logger.i('FCM already initialized');
      return true;
    }

    try {
      // Must happen before anything tries to show a local notification —
      // showMessageNotification/showIncomingCallNotification both no-op
      // silently while this is uninitialized.
      await _callNotificationService.initialize();

      // A tap on one of our foreground message notifications that relaunched
      // a killed app arrives only as launch details, not as a tap callback.
      final launchChatId = ChatNotificationNavigator.chatIdFromPayload(
        await _callNotificationService.getLaunchPayload(),
      );
      if (launchChatId != null) {
        ChatNotificationNavigator.instance.openChat(
          launchChatId,
          source: 'local notification (cold start)',
        );
      }

      await _requestPermission();

      _token = await _messaging.getToken();
      _logger.i('FCM token obtained: $_token');

      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
        _token = newToken;
        _logger.i('FCM token refreshed: $newToken');
      });

      _onMessageSubscription?.cancel();
      _onMessageSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );

      _onMessageOpenedAppSubscription?.cancel();
      _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp
          .listen(_handleMessageOpenedApp);

      // Cold-start notification handling normally already happened via
      // checkColdStartNotification() before runApp() — this only covers the
      // case where initialize() somehow runs first.
      await checkColdStartNotification();

      _isInitialized = true;
      return true;
    } catch (e) {
      _logger.e('Error initializing FCM service', e);
      return false;
    }
  }

  /// Dumps everything an incoming FCM message carries — envelope fields, the
  /// notification payload and every `data` key with its runtime type — as a
  /// single log entry, so a notification can be diagnosed from the console
  /// alone. Static so the background isolate's top-level handler can call it
  /// before any instance work happens.
  static void logRemoteMessage(String source, RemoteMessage message) {
    final buffer = StringBuffer();
    buffer.writeln('===== FCM NOTIFICATION [$source] =====');
    buffer.writeln('messageId        : ${message.messageId}');
    buffer.writeln('senderId         : ${message.senderId}');
    buffer.writeln('from             : ${message.from}');
    buffer.writeln('category         : ${message.category}');
    buffer.writeln('collapseKey      : ${message.collapseKey}');
    buffer.writeln('messageType      : ${message.messageType}');
    buffer.writeln('threadId         : ${message.threadId}');
    buffer.writeln('sentTime         : ${message.sentTime}');
    buffer.writeln('ttl              : ${message.ttl}');
    buffer.writeln('contentAvailable : ${message.contentAvailable}');
    buffer.writeln('mutableContent   : ${message.mutableContent}');

    final notification = message.notification;
    if (notification == null) {
      buffer.writeln('notification     : <none> (data-only message)');
    } else {
      buffer.writeln('notification.title       : ${notification.title}');
      buffer.writeln('notification.body        : ${notification.body}');
      buffer.writeln('notification.titleLocKey : ${notification.titleLocKey}');
      buffer.writeln('notification.bodyLocKey  : ${notification.bodyLocKey}');

      final android = notification.android;
      if (android != null) {
        buffer.writeln('android.channelId    : ${android.channelId}');
        buffer.writeln('android.priority     : ${android.priority}');
        buffer.writeln('android.sound        : ${android.sound}');
        buffer.writeln('android.smallIcon    : ${android.smallIcon}');
        buffer.writeln('android.imageUrl     : ${android.imageUrl}');
        buffer.writeln('android.tag          : ${android.tag}');
        buffer.writeln('android.clickAction  : ${android.clickAction}');
        buffer.writeln('android.link         : ${android.link}');
        buffer.writeln('android.count        : ${android.count}');
        buffer.writeln('android.visibility   : ${android.visibility}');
      }

      final apple = notification.apple;
      if (apple != null) {
        buffer.writeln('apple.subtitle       : ${apple.subtitle}');
        buffer.writeln('apple.badge          : ${apple.badge}');
        buffer.writeln('apple.sound          : ${apple.sound?.name}');
        buffer.writeln('apple.imageUrl       : ${apple.imageUrl}');
      }
    }

    if (message.data.isEmpty) {
      buffer.writeln('data             : <empty>');
    } else {
      buffer.writeln('data (${message.data.length} keys):');
      message.data.forEach((key, value) {
        buffer.writeln('  $key = $value  <${value.runtimeType}>');
      });
      buffer.writeln('data (raw)       : ${message.data}');
    }
    buffer.write('===== END FCM NOTIFICATION [$source] =====');

    ConsoleAppLogger.forModule('FcmService').i(buffer.toString());
  }

  Future<bool> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      _logger.i(
        'Notification permission status: ${settings.authorizationStatus}',
      );
      return granted;
    } catch (e) {
      _logger.e('Error requesting notification permission', e);
      return false;
    }
  }

  /// Mirrors the old OneSignalService.getPlayerIdAsync() contract: retries
  /// briefly if the token isn't ready yet instead of failing immediately.
  Future<String?> getTokenAsync() async {
    if (_token != null && _token!.isNotEmpty) {
      return _token;
    }

    int attempts = 0;
    const maxAttempts = 15;

    while ((_token == null || _token!.isEmpty) && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        _token = await _messaging.getToken();
      } catch (e) {
        _logger.w('Error fetching FCM token (attempt ${attempts + 1}): $e');
      }
      attempts++;
    }

    return _token;
  }

  void setAppForegroundState(bool isInForeground) {
    _isAppInForeground = isInForeground;
    _callNotificationService.setAppForegroundState(isInForeground);
    _logger.d('App foreground state: $_isAppInForeground');
  }

  bool _isNotificationAlreadyProcessed(String notificationId) {
    final now = DateTime.now();
    _notificationTimestamps.removeWhere((_, timestamp) {
      final expired = now.difference(timestamp) > _deduplicationWindow;
      return expired;
    });
    _processedNotifications.removeWhere(
      (id) => !_notificationTimestamps.containsKey(id),
    );

    if (_processedNotifications.contains(notificationId)) {
      return true;
    }
    _processedNotifications.add(notificationId);
    _notificationTimestamps[notificationId] = now;
    return false;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    logRemoteMessage('onMessage (foreground)', message);

    final notificationId =
        message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    if (_isNotificationAlreadyProcessed(notificationId)) {
      _logger.w('Skipping duplicate notification: $notificationId');
      return;
    }

    _logger.i('Foreground message received: $notificationId');

    try {
      final isMissedCall = _isMissedCallNotification(message);
      final isCall = !isMissedCall && _isCallNotification(message);
      _logger.i(
        'Is call notification: $isCall | Is missed call: $isMissedCall',
      );

      if (isMissedCall) {
        // The call stopped ringing — take "<name> is calling..." out of the
        // tray. The missed-call notification itself is still posted below by
        // the normal message path (FCM never renders anything itself while
        // the app is in the foreground).
        unawaited(
          _callNotificationService.dismissIncomingCallNotifications(
            reason: 'missed-call push (foreground)',
          ),
        );
      }

      if (isCall) {
        final callData = _extractCallData(message);
        if (callData != null) {
          // CallManager._handleIncomingCall() (triggered from this) already
          // decides full-screen-vs-notification via NavigationHelper and
          // navigates itself once ringing state is set — calling
          // _navigateToCallScreen()/showIncomingCallNotification() here too
          // duplicated that and could show the incoming-call screen twice.
          _initializeIncomingCallState(callData);
        }
        return;
      }

      if (_isAppInForeground && _isNotificationForCurrentChat(message)) {
        _logger.i('Hiding notification - user is already in this chat');
        return;
      }

      // FCM never auto-displays anything while the app is in the
      // foreground (unlike backgrounded/terminated, where the OS shows a
      // `notification`-payload message on its own) — always render this
      // ourselves via the local-notifications plugin. A data-only message
      // (no `notification` payload) falls back to title/body carried in
      // `data`, since the backend may choose to send either shape.
      final String? title =
          message.notification?.title ?? message.data['title']?.toString();
      final String? body =
          message.notification?.body ?? message.data['body']?.toString();
      _logger.i(
        'Foreground message notification -> title: "$title" | body: "$body" '
        '(source: ${message.notification != null ? 'notification payload' : 'data payload'})',
      );
      if (title != null || body != null) {
        _callNotificationService.showMessageNotification(
          title: title ?? '',
          body: body ?? '',
          payload: _chatMessagePayload(message),
        );
      } else {
        _logger.w(
          'No title/body found in message $notificationId - nothing displayed. '
          'Raw data: ${message.data}',
        );
      }
    } catch (e) {
      _logger.e('Error handling foreground message: $e');
    }
  }

  /// Called from the top-level background handler, which runs in its own
  /// isolate with a fresh singleton state (no access to the running app's
  /// `_isAppInForeground` tracking) — so it initializes its own
  /// CallNotificationService and treats itself as always-backgrounded.
  /// The OS auto-displays a `notification`-payload message while
  /// backgrounded/terminated on its own; this only needs to cover calls
  /// (which want the custom call UI, not the default banner) and
  /// data-only messages (which the OS never renders by itself).
  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    try {
      logRemoteMessage('onBackgroundMessage', message);
      await _callNotificationService.initialize();
      _callNotificationService.setAppForegroundState(false);

      final isMissedCall = _isMissedCallNotification(message);
      if (isMissedCall) {
        // Android has just posted the "Missed call from X" banner; clear the
        // "<name> is calling..." one it posted when the call started ringing,
        // so only the missed-call entry is left in the shade.
        _logger.i('Missed-call push - clearing the incoming-call notification');
        await _callNotificationService.dismissIncomingCallNotifications(
          reason: 'missed-call push (background)',
        );
      }

      final isCall = !isMissedCall && _isCallNotification(message);
      if (isCall) {
        // iOS has no full-screen-intent equivalent, and the backend call
        // push already carries an alert payload (with the custom ringtone
        // sound) that the OS renders on its own while backgrounded/killed —
        // posting a second local notification here just double-banners.
        // Android is the one that needs the manual category=call /
        // fullScreenIntent notification to ring over the lock screen.
        if (Platform.isIOS) {
          return;
        }
        final callData = _extractCallData(message);
        if (callData != null) {
          await _callNotificationService.showIncomingCallNotification(
            callerName: callData['callerName'] ?? 'Unknown Caller',
            callType: callData['callType'] ?? 'audio',
            chatId: callData['chatId'] ?? 0,
            callId: callData['callId'] ?? 0,
            peerId: callData['peerId'],
            callerAvatar: callData['callerAvatar'],
            autoDismissSeconds: 30,
          );

          // Best-effort: this runs in the FCM background isolate, which is
          // torn down once the handler returns, so the timer only fires if
          // the isolate happens to outlive the ring window. The missed-call
          // push is still the primary path.
          _callNotificationService.scheduleIncomingCallExpiry(
            reason: 'incoming call push (background isolate)',
          );
        }
        return;
      }

      if (message.notification == null) {
        final title = message.data['title']?.toString();
        final body = message.data['body']?.toString();
        _logger.i(
          'Background data-only message -> title: "$title" | body: "$body"',
        );
        if (title != null || body != null) {
          await _callNotificationService.showMessageNotification(
            title: title ?? '',
            body: body ?? '',
            payload: _chatMessagePayload(message),
          );
        } else {
          _logger.w(
            'Background data-only message has no title/body - nothing shown. '
            'Raw data: ${message.data}',
          );
        }
      } else {
        _logger.i(
          'Background message carries a notification payload - the OS displays '
          'it: title: "${message.notification?.title}" | '
          'body: "${message.notification?.body}"',
        );
      }
    } catch (e) {
      _logger.e('Error handling background message: $e');
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    logRemoteMessage('onMessageOpenedApp (notification tapped)', message);

    if (_isChatMessagePush(message)) {
      ChatNotificationNavigator.instance.openChat(
        _chatIdFromData(message.data)!,
        source: 'push notification',
      );
      return;
    }

    final isMissedCall = _isMissedCallNotification(message);
    final isCall = !isMissedCall && _isCallNotification(message);
    _logger.i(
      'Is call (message opened app): $isCall | Is missed call: $isMissedCall',
    );

    try {
      if (isMissedCall) {
        // Tapping a missed-call notification must not try to join the call.
        unawaited(
          _callNotificationService.dismissIncomingCallNotifications(
            reason: 'missed-call notification tapped',
          ),
        );
        return;
      }

      if (isCall) {
        // A banner that outlived its call - the missed-call push never came,
        // or nothing was running to clear it - must not open a call screen
        // for a call that stopped ringing long ago.
        final sentTime = message.sentTime;
        if (sentTime != null) {
          final age = DateTime.now().difference(sentTime);
          if (!age.isNegative && age > _coldStartMaxAge) {
            _logger.w(
              'Ignoring tap on a stale incoming-call notification: sent '
              '${age.inSeconds}s ago, older than the '
              '${_coldStartMaxAge.inSeconds}s freshness window',
            );
            unawaited(
              _callNotificationService.dismissIncomingCallNotifications(
                reason: 'stale incoming-call notification tapped',
              ),
            );
            return;
          }
        }

        _callNotificationService.dismissCallNotification();

        final callData = _extractCallData(message);
        if (callData != null) {
          if (NavigationHelper.context == null) {
            _logger.i('Cold start detected - storing pending call data');
            ColdStartHandler().storePendingCallData(callData);
            _scheduleNavigationRetry(callData, 0);
          } else {
            _navigateToCallScreen(callData);
          }
        }
      }
    } catch (e) {
      _logger.e('Error handling message opened app: $e');
      try {
        final callData = _extractCallData(message);
        if (callData != null) {
          ColdStartHandler().storePendingCallData(callData);
        }
      } catch (storageError) {
        _logger.e('Error storing call data as fallback: $storageError');
      }
    }
  }

  void _scheduleNavigationRetry(Map<String, dynamic> callData, int attempt) {
    if (attempt >= 5) {
      _logger.e('Navigation retry failed after 5 attempts');
      return;
    }

    final delayMs = [500, 1000, 2000, 3000, 5000][attempt];
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (NavigationHelper.context != null) {
        _navigateToCallScreen(callData);
      } else {
        _scheduleNavigationRetry(callData, attempt + 1);
      }
    });
  }

  /// A missed/ended-call push ("Missed call from X" / "You missed a call
  /// from X") also matches every 'call' keyword _isCallNotification() looks
  /// for, so it has to be recognised *first*. Otherwise each missed call is
  /// handled as a brand-new incoming one: it re-rings, re-opens the call
  /// screen and posts a second "Incoming call" notification for a call that
  /// has already ended.
  bool _isMissedCallNotification(RemoteMessage message) {
    try {
      final type = message.data['type']?.toString().toLowerCase() ?? '';
      if (type == 'call_missed' ||
          type == 'call_ended' ||
          type == 'call_declined') {
        return true;
      }

      // The text match below would otherwise catch a chat message that
      // merely says "missed".
      if (_isChatMessagePush(message)) return false;

      final text = [
        message.notification?.title ?? '',
        message.notification?.body ?? '',
        message.data['title']?.toString() ?? '',
        message.data['body']?.toString() ?? '',
      ].join(' ');

      return RegExp(r'missed', caseSensitive: false).hasMatch(text);
    } catch (e) {
      _logger.e('Error detecting missed call: $e');
      return false;
    }
  }

  bool _isCallNotification(RemoteMessage message) {
    try {
      final data = message.data;

      // NEW backend's actual push payload for a ringing call
      // (CallsService.notifyIncomingCall) is a flat
      // {type:'call_incoming', callId, conversationId, callType, fromUserId,
      // fromUserName} map — 'call_incoming' is the one reliable signal,
      // distinct from a message push's type:'new_message'.
      if (data['type'] == 'call_incoming') {
        return true;
      }

      // A chat message whose text says "calling"/"incoming call" is still a
      // chat message — the title/body heuristics below can't tell.
      if (_isChatMessagePush(message)) return false;

      final title = message.notification?.title?.toLowerCase() ?? '';
      final body = message.notification?.body?.toLowerCase() ?? '';

      if (title.contains('calling') ||
          title.contains('call') ||
          body.contains('ringing') ||
          body.contains('calling') ||
          body.contains('incoming') && body.contains('call')) {
        return true;
      }

      // OLD-shape data fields, kept for backward compatibility.
      if (data['call'] != null ||
          data['caller_name'] != null ||
          data['call_type'] != null ||
          data['call_id'] != null ||
          (data['callId'] != null && data['callType'] != null)) {
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error detecting call: $e');
      return false;
    }
  }

  /// Decided from the route stack, not SocketEventController.currentChatId:
  /// that one keeps the last chat's id after the chat is closed (its
  /// setCurrentChat(0, 0) reset is rejected as an invalid context), which
  /// would hide notifications for a chat the user already left.
  bool _isNotificationForCurrentChat(RemoteMessage message) {
    final chatId = _chatIdFromData(message.data);
    return chatId != null &&
        ChatNotificationNavigator.instance.isViewingChat(chatId);
  }

  /// The chat a push belongs to. NEW backend sends `conversationId`; the
  /// older `chat_id`/`chatId` keys are kept for backward compatibility.
  static int? _chatIdFromData(Map<String, dynamic> data) {
    final raw = data['conversationId'] ?? data['chatId'] ?? data['chat_id'];
    final chatId = int.tryParse('${raw ?? ''}');
    return chatId != null && chatId > 0 ? chatId : null;
  }

  /// A new-message push: `{conversationId, messageId}`, with `type` either
  /// absent (what the backend sends today) or 'new_message'. Call pushes
  /// always carry a `call_*` type and no messageId.
  static bool _isChatMessagePush(RemoteMessage message) {
    final data = message.data;
    final type = data['type']?.toString().toLowerCase() ?? '';
    if (type.isNotEmpty && type != 'new_message') return false;
    final messageId = data['messageId'] ?? data['message_id'];
    return messageId != null && _chatIdFromData(data) != null;
  }

  /// Local-notification payload that routes a tap to the message's chat, or
  /// null for anything that isn't a chat message.
  static String? _chatMessagePayload(RemoteMessage message) {
    if (!_isChatMessagePush(message)) return null;
    return ChatNotificationNavigator.buildPayload(
      _chatIdFromData(message.data)!,
      messageId: (message.data['messageId'] ?? message.data['message_id'])
          ?.toString(),
    );
  }

  Map<String, dynamic>? _extractCallData(RemoteMessage message) {
    try {
      final data = message.data;

      String callType = 'audio';
      String? roomId;
      int chatId = 0;
      int callId = 0;
      String callerName = 'Unknown Caller';
      String? peerId;
      String? callerAvatar;

      final title = message.notification?.title;
      if (title != null) {
        final match = RegExp(
          r'^(.*?)\s+is\s+(calling|ringing)',
        ).firstMatch(title);
        if (match != null) {
          callerName = match.group(1)!.trim();
        }
      }

      // NEW backend's flat call_incoming payload
      // (CallsService.notifyIncomingCall): {type, callId, conversationId,
      // callType, fromUserId, fromUserName}. No roomId is sent — the call
      // screen resolves that itself via the PeerJS join flow once CallManager
      // processes this data.
      if (data['callId'] != null || data['conversationId'] != null) {
        callType = data['callType']?.toString() ?? callType;
        chatId =
            int.tryParse(data['conversationId']?.toString() ?? '') ?? chatId;
        callId = int.tryParse(data['callId']?.toString() ?? '') ?? callId;
        peerId = data['fromUserId']?.toString() ?? peerId;
        if (data['fromUserName'] != null) {
          callerName = data['fromUserName'].toString();
        }
      }

      // OLD nested shape, kept for backward compatibility.
      if (data['call'] != null) {
        final callData = data['call'];
        if (callData is Map) {
          callType = callData['call_type']?.toString() ?? callType;
          roomId = callData['room_id']?.toString() ?? roomId;
          final oldChatId = int.tryParse(callData['chat_id']?.toString() ?? '');
          if (oldChatId != null) chatId = oldChatId;
          final oldCallId = int.tryParse(callData['call_id']?.toString() ?? '');
          if (oldCallId != null) callId = oldCallId;
          peerId = callData['peer_id']?.toString() ?? peerId;
        }
      }

      if (data['caller_name'] != null) {
        callerName = data['caller_name'].toString();
      }

      if (data['user'] != null) {
        final userData = data['user'];
        if (userData is Map) {
          callerName = userData['full_name']?.toString() ?? callerName;
          callerAvatar = userData['profile_pic']?.toString();
        }
      }

      if (chatId == 0 || callId == 0) {
        chatId = chatId == 0 ? 999 : chatId;
        callId = callId == 0 ? DateTime.now().millisecondsSinceEpoch : callId;
      }

      final extracted = {
        'roomId': roomId,
        'callType': callType,
        'chatId': chatId,
        'callId': callId,
        'callerName': callerName,
        'peerId': peerId,
        'callerAvatar': callerAvatar,
      };
      _logger.i('Extracted call data: $extracted');
      return extracted;
    } catch (e) {
      _logger.e('Error extracting call data: $e');
      return null;
    }
  }

  void _initializeIncomingCallState(Map<String, dynamic> callData) {
    try {
      final callManager = CallManager.instance;
      final socketEventData = {
        'call': {
          'chat_id': callData['chatId'],
          'call_id': callData['callId'],
          'room_id': callData['roomId'],
          'call_type': callData['callType'],
          'peer_id': callData['peerId'],
          'call_status': 'ringing',
        },
        'user': {
          'full_name': callData['callerName'],
          'user_id': callData['chatId'],
        },
      };
      callManager.handleIncomingCallFromNotification(socketEventData);
    } catch (e) {
      _logger.e('Error initializing incoming call state: $e');
    }
  }

  /// Only called from the "user tapped the incoming-call notification" path
  /// (_handleMessageOpenedApp + its retry). The user explicitly asked to
  /// answer, so this must ALWAYS land on the full-screen incoming-call
  /// screen — never fall back to showing another notification.
  ///
  /// NavigationHelper.handleIncomingCall() is wrong here: it gates on
  /// WidgetsBinding.lifecycleState, which on iOS is still `paused`/`hidden`
  /// for a beat while the app resumes from the tap, so it would route to
  /// _fallbackToNotification() and no screen would appear. Go straight to
  /// navigateToIncomingCallFromData() (context + dedupe guard only, no
  /// lifecycle gate), after seeding CallManager so Accept/Decline work.
  void _navigateToCallScreen(Map<String, dynamic> callData, [int attempt = 0]) {
    try {
      if (NavigationHelper.context == null) {
        if (attempt >= 10) {
          _logger.e('Navigation context never became ready for call tap');
          return;
        }
        Future.delayed(const Duration(milliseconds: 400), () {
          _navigateToCallScreen(callData, attempt + 1);
        });
        return;
      }

      _initializeIncomingCallState(callData);
      NavigationHelper.navigateToIncomingCallFromData(callData);
      _logger.i('Navigated to incoming-call screen from notification tap');
    } catch (e) {
      _logger.e('Navigation error: $e');
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _onMessageSubscription = null;
    _onMessageOpenedAppSubscription = null;
    _processedNotifications.clear();
    _notificationTimestamps.clear();
    _isInitialized = false;
    _logger.i('FCM service disposed');
  }
}
