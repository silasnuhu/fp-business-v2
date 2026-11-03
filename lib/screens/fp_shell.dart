import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/core/services/chat_shortcut_service.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/call/call_history/screens/fp_calls_screen.dart';
import 'package:whoxa/featuers/communities/screens/communities_screen.dart';
import 'package:whoxa/featuers/contacts/screen/fp_contacts_screen.dart';
import 'package:whoxa/featuers/home/screens/fp_chat_list_screen.dart';
import 'package:whoxa/screens/settings/fp_settings_screen.dart';

/// Flickpitch app shell.
///
/// Replaces the stock `BottomNavigationBar` layout with a floating glass rail:
///   * the bar sits inset above the safe area instead of docked full-width,
///   * the active destination gets a gradient pill that slides between items,
///   * tabs live in an `IndexedStack`, so scroll position and state survive
///     switching (the old tabbar rebuilt the page on every tap).
///
/// The existing feature screens are hosted unchanged for now; each is being
/// replaced by its own redesigned screen in the following slices.
class FpShell extends StatefulWidget {
  const FpShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<FpShell> createState() => _FpShellState();
}

class _FpShellState extends State<FpShell> {
  late int _index = widget.initialIndex;

  static const _destinations = <_Destination>[
    _Destination('Chats', Icons.forum_outlined, Icons.forum),
    _Destination('Communities', Icons.groups_outlined, Icons.groups),
    _Destination('Calls', Icons.call_outlined, Icons.call),
    _Destination('People', Icons.people_alt_outlined, Icons.people_alt),
    _Destination('You', Icons.person_outline, Icons.person),
  ];

  @override
  void initState() {
    super.initState();
    // Launched from a pinned home-screen shortcut? Open that chat.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pending = await ChatShortcutService.consumePending();
      if (!mounted || pending == null) return;
      final chatId = (pending['chatId'] as num?)?.toInt() ?? 0;
      final userId = (pending['userId'] as num?)?.toInt() ?? 0;
      if (chatId <= 0 && userId <= 0) return;
      NavigationHelper.navigateToIndividualChat(
        context,
        userId: userId,
        userName: '${pending['chatName'] ?? 'Chat'}',
        profilePic: '',
        chatId: chatId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // theme dependency: rebuild this screen when the theme changes
    // so the static Fp tokens are re-read (they are not InheritedWidgets).
    context.watch<ThemeProvider>();
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        backgroundColor: Fp.ink,
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(
              index: _index,
              children: const [
                FpChatListScreen(),
                CommunitiesScreen(),
                FpCallsScreen(),
                FpContactsScreen(),
                FpSettingsScreen(),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _NavRail(
                destinations: _destinations,
                index: _index,
                onSelect: (i) => setState(() => _index = i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.destinations,
    required this.index,
    required this.onSelect,
  });

  final List<_Destination> destinations;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Fp.inkSoft,
        border: Border(top: BorderSide(color: Fp.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Fp.violet : Fp.textMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? destination.activeIcon : destination.icon,
              size: 23,
              color: color,
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: TextStyle(
                fontFamily: selected ? 'PoppinsBold' : 'PoppinsMedium',
                fontSize: 10.5,
                height: 1.2,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
