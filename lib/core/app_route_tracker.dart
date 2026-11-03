import 'package:flutter/widgets.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';

/// Mirrors the root navigator's route stack so code outside the widget tree
/// (notification taps, FCM handlers) can ask "what is the user looking at?"
/// without popping anything to find out.
///
/// Registered once on MaterialApp.navigatorObservers — see main.dart.
class AppRouteTracker extends NavigatorObserver {
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];

  /// Bottom-to-top snapshot of the current stack.
  List<Route<dynamic>> get stack => List.unmodifiable(_stack);

  /// Topmost full-screen route. Dialogs and bottom sheets are skipped so a
  /// sheet opened over a chat still counts as "in that chat".
  Route<dynamic>? get topPageRoute {
    for (var i = _stack.length - 1; i >= 0; i--) {
      if (_stack[i] is PageRoute) return _stack[i];
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) {
      _stack[index] = newRoute;
    } else {
      if (oldRoute != null) _stack.remove(oldRoute);
      if (newRoute != null) _stack.add(newRoute);
    }
  }

  /// The chatId a UniversalChatScreen route was opened with, or null when
  /// [route] isn't a chat screen. Relies on AppRoutes.generateRoute passing
  /// `settings` through for universalChat, which it does.
  static int? chatIdOf(Route<dynamic> route) {
    if (route.settings.name != AppRoutes.universalChat) return null;
    final args = route.settings.arguments;
    if (args is! Map) return null;
    final raw = args['chatId'];
    if (raw is int) return raw;
    return int.tryParse('${raw ?? ''}');
  }

  static bool isChatRoute(Route<dynamic> route) =>
      route.settings.name == AppRoutes.universalChat;
}
