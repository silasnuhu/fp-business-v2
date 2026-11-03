import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/featuers/communities/screens/communities_screen.dart';
import 'package:whoxa/utils/logger.dart';

/// Deep-link entry point for community invitations.
///
/// Mirrors WhatsApp: tapping an invite link opens the app straight into the
/// community join flow, regardless of whether the account is personal or
/// business. Both apps register a scheme, so the same link works either way.
///
/// Accepted shapes:
///   flickpitchbusiness://community/invite?code=ABC123
///   flickpitch://community/invite?code=ABC123
///   `flickpitch://invite/ABC123`
class InviteLinkHandler {
  InviteLinkHandler._();

  static final InviteLinkHandler instance = InviteLinkHandler._();

  final AppLinks _links = AppLinks();
  final _logger = ConsoleAppLogger.forModule('InviteLinkHandler');

  StreamSubscription<Uri>? _sub;
  bool _started = false;
  String? _lastHandled;

  /// Call once after runApp(). Safe to call more than once.
  void start() {
    if (_started) return;
    _started = true;

    // Cold start: the app was launched by the link itself.
    _links
        .getInitialLink()
        .then((uri) {
          if (uri != null) _handle(uri);
        })
        .catchError((Object e) {
          _logger.e('Could not read initial link: $e');
        });

    // Warm start: the app was already running when the link was tapped.
    _sub = _links.uriLinkStream.listen(
      _handle,
      onError: (Object e) => _logger.e('Link stream error: $e'),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> _handle(Uri uri) async {
    final code = _codeFrom(uri);
    if (code == null || code.isEmpty) return;
    // Guard against the stream re-emitting the same launch link.
    if (_lastHandled == code) return;
    _lastHandled = code;
    await _pushWhenReady(code);
  }

  /// The navigator is not mounted yet on a cold start, so wait for it.
  Future<void> _pushWhenReady(String code) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final navigator = NavigationHelper.navigator;
      if (navigator != null) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => CommunitiesScreen(initialCode: code),
          ),
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    _logger.e('Navigator never became ready for invite $code');
  }

  String? _codeFrom(Uri uri) {
    final fromQuery = uri.queryParameters['code'];
    if (fromQuery != null && fromQuery.trim().isNotEmpty) {
      return fromQuery.trim();
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final last = segments.last;
    if (last == 'invite' || last == 'join' || last == 'c') return null;
    return last;
  }
}
