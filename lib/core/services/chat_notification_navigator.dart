import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/app_route_tracker.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/featuers/call/call_manager.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
import 'package:whoxa/featuers/chat/provider/archive_chat_provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/widgets/global.dart';

/// Opens the right chat when a new-message notification is tapped.
///
/// Every tap source funnels into [openChat]:
///  * app in foreground — our own local notification (CallNotificationService)
///  * app in background — FirebaseMessaging.onMessageOpenedApp
///  * app terminated    — getInitialMessage(), or the local-notification
///                        plugin's launch details
///
/// What a tap does depends on where the user is:
///  * already looking at that chat     -> nothing
///  * anywhere else, whatever screen   -> the chat opens right on top of it;
///    (chat list, any tab or inner        nothing underneath is popped, so
///    screen, another chat, even this     Back returns to exactly that screen
///    chat's own group info)
///  * app still starting up            -> held until the tabbar is on screen
///  * in a call                        -> ignored; leaving the call screen
///                                        would drop the call
///
/// Opening chat B over chat A is safe even though every chat screen shares
/// the one ChatProvider: B takes the provider over, and when B closes, A
/// takes it back and reloads its own messages (UniversalChatScreen
/// didPopNext + ChatProvider.claimChatScreen).
class ChatNotificationNavigator {
  ChatNotificationNavigator._();
  static final ChatNotificationNavigator instance =
      ChatNotificationNavigator._();

  static const String _payloadPrefix = 'chat_message';

  /// A tap that is still waiting for the tabbar after this long is dropped
  /// rather than yanking the user into a chat out of nowhere.
  static const Duration _pendingMaxAge = Duration(minutes: 1);

  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'ChatNotificationNavigator',
  );

  // A count, not a bool: a tabbar replaced by a new one (pushAndRemoveUntil)
  // is disposed only after its replacement has already mounted.
  int _mountedHomeCount = 0;
  bool _isOpening = false;
  int? _requestedChatId;
  DateTime? _requestedAt;

  bool get _isHomeReady => _mountedHomeCount > 0;

  /// Local-notification payload for a message in [chatId].
  static String buildPayload(int chatId, {String? messageId}) =>
      '$_payloadPrefix|$chatId|${messageId ?? ''}';

  /// The chatId in a payload built by [buildPayload], or null for any other
  /// payload (call notifications use their own prefixes).
  static int? chatIdFromPayload(String? payload) {
    if (payload == null) return null;
    final parts = payload.split('|');
    if (parts.length < 2 || parts[0] != _payloadPrefix) return null;
    return int.tryParse(parts[1]);
  }

  /// Whether [chatId]'s chat screen is the screen currently on top.
  bool isViewingChat(int chatId) {
    final top = NavigationHelper.routeTracker.topPageRoute;
    return top != null && AppRouteTracker.chatIdOf(top) == chatId;
  }

  /// Called by NewTabbarScreen once it is on screen.
  void onHomeReady() {
    _mountedHomeCount++;
    unawaited(_drain());
  }

  /// Called by NewTabbarScreen.dispose().
  void onHomeDisposed() {
    if (_mountedHomeCount > 0) _mountedHomeCount--;
  }

  void openChat(int chatId, {required String source}) {
    if (chatId <= 0) return;
    _logger.i('Message notification tapped ($source) -> chat $chatId');

    // Latest tap wins: two quick taps on different chats open the second.
    _requestedChatId = chatId;
    _requestedAt = DateTime.now();

    if (!_isHomeReady) {
      _logger.i('Tabbar not up yet - chat $chatId will open once it is');
      return;
    }
    unawaited(_drain());
  }

  Future<void> _drain() async {
    // An open already in flight picks up the newest request when it finishes.
    if (_isOpening) return;
    _isOpening = true;
    try {
      while (_requestedChatId != null && _isHomeReady) {
        final chatId = _requestedChatId!;
        final requestedAt = _requestedAt;
        _requestedChatId = null;
        _requestedAt = null;

        if (requestedAt != null &&
            DateTime.now().difference(requestedAt) > _pendingMaxAge) {
          _logger.w('Dropping stale tap for chat $chatId');
          continue;
        }
        await _open(chatId);
      }
    } catch (e) {
      _logger.e('Error opening chat from notification: $e');
    } finally {
      _isOpening = false;
    }
  }

  Future<void> _open(int chatId) async {
    if (authToken.isEmpty) {
      _logger.w('Not logged in - ignoring tap for chat $chatId');
      return;
    }
    if (_isInCall()) return;

    final context = NavigationHelper.context;
    if (context == null) return;

    if (isViewingChat(chatId)) {
      _logger.i('Already in chat $chatId - nothing to do');
      return;
    }

    // Never pop anything, even when this chat is open further down (e.g. the
    // user is in its group info): Back must return to the exact screen the
    // user was on. The copy underneath reloads itself when it is shown again.
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final chat = await _findChat(context, chatProvider, chatId);
    if (chat == null) {
      _logger.w('Could not load chat $chatId - staying on the current screen');
      return;
    }

    // The lookup may have hit the network; re-check what changed meanwhile.
    if (isViewingChat(chatId) || _isInCall()) return;

    final freshContext = NavigationHelper.context;
    if (freshContext == null || !freshContext.mounted) return;
    _pushChat(freshContext, chatId, chat);
  }

  bool _isInCall() {
    if (!CallManager.instance.isInCall) return false;
    _logger.i('In a call - not leaving the call screen for a message tap');
    return true;
  }

  Future<Chats?> _findChat(
    BuildContext context,
    ChatProvider chatProvider,
    int chatId,
  ) async {
    try {
      final archived = Provider.of<ArchiveChatProvider>(
        context,
        listen: false,
      ).archivedChats;
      for (final chat in archived) {
        if (chat.records?.firstOrNull?.chatId == chatId) return chat;
      }
    } catch (e) {
      _logger.w('Archived chat lookup failed: $e');
    }
    return chatProvider.resolveChatForNotification(chatId);
  }

  /// Same calls the chat list makes on a row tap (HomeScreen
  /// _buildRegularChatList), so the chat opens exactly as it would from there.
  void _pushChat(BuildContext context, int chatId, Chats chat) {
    final record = chat.records?.firstOrNull;
    final chatType = record?.chatType?.toLowerCase();

    if (chatType == 'group') {
      NavigationHelper.navigateToGroupChat(
        context,
        chatId: chatId,
        groupName: record?.groupName ?? 'Group Chat',
        groupProfilePic: record?.groupIcon ?? '',
        groupDescription: record?.groupDescription,
      );
      return;
    }

    final peer = chat.peerUserData;
    final peerId = peer?.userId ?? _peerIdFromParticipants(record);
    if (peerId == null) {
      _logger.w('No peer user for chat $chatId - cannot open it');
      return;
    }

    toUserProfileCall = peer?.profilePic ?? '';
    NavigationHelper.navigateToChat(
      context,
      chatId: chatId,
      userId: peerId,
      fullName: ContactNameService.instance.resolveName(
        userId: peerId,
        firstName: peer?.firstName,
        lastName: peer?.lastName,
        fullName: peer?.fullName,
        userName: peer?.userName,
        email: peer?.email,
        fallback: 'unknown',
      ),
      profilePic: peer?.profilePic ?? '',
      isAdminChat: chatType == 'admin_broadcast',
    );
  }

  /// Fallback when the peer's profile lookup failed: the other participant.
  int? _peerIdFromParticipants(Records? record) {
    for (final participant in record?.participants ?? const <Participants>[]) {
      final id = participant.userId;
      if (id != null && id.toString() != userID) return id;
    }
    return null;
  }
}
