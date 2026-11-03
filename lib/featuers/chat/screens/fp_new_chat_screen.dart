import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/dependency_injection.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/core/navigation_helper.dart';

/// Global "new chat" directory search.
///
/// Until now the app could only reach people already in your chat list: the
/// compose button pointed at the device address book, which matches nothing for
/// accounts that registered with an email address. This screen uses the
/// account directory (`GET /users/search`) so a Flickpitch user can be found by
/// display name or @username without either side sharing a phone number.
class FpNewChatScreen extends StatefulWidget {
  const FpNewChatScreen({super.key});

  @override
  State<FpNewChatScreen> createState() => _FpNewChatScreenState();
}

class _FpNewChatScreenState extends State<FpNewChatScreen> {
  final ApiClient _api = getIt<ApiClient>();
  final TextEditingController _query = TextEditingController();

  Timer? _debounce;
  bool _loading = false;
  bool _searched = false;
  String? _error;
  List<_Person> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _searched = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.request(
        '/users/search?q=${Uri.encodeQueryComponent(q)}&limit=25',
      );
      final items = _itemsOf(res);
      if (!mounted) return;
      setState(() {
        _results = items.map(_Person.fromJson).where((p) => p.id > 0).toList();
        _loading = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _searched = true;
        _error = 'Could not search right now. Check your connection.';
      });
    }
  }

  /// Tolerates both `{items:[...]}` and a bare list, snake_case or camelCase.
  List<Map> _itemsOf(dynamic res) {
    dynamic node = res;
    if (node is Map && node['data'] != null) node = node['data'];
    if (node is Map && node['items'] is List) node = node['items'];
    if (node is List) return node.whereType<Map>().toList();
    return const [];
  }

  /// Open (or start) the chat with this person.
  ///
  /// chatId is deliberately 0: ChatProvider.sendMessage treats 0 as "new chat",
  /// creates the direct conversation on the first send and registers the
  /// peer->conversation mapping via cacheDirectChatId(). Pre-creating the
  /// conversation here skipped that cache, which is why messages appeared to go
  /// nowhere. This is the same contract the contacts screen uses.
  void _open(_Person person) {
    Navigator.pop(context);
    NavigationHelper.navigateToIndividualChat(
      context,
      userId: person.id,
      userName: person.displayName,
      profilePic: person.photo,
      chatId: 0,
      unseenCount: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Fp.s24,
                  Fp.s16,
                  Fp.s16,
                  Fp.s8,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('New chat', style: Fp.h2)),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: Fp.textMuted,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Fp.s24),
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  style: Fp.bodyStrong,
                  decoration: InputDecoration(
                    hintText: 'Search by name or @username',
                    hintStyle: Fp.body.copyWith(color: Fp.textFaint),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Fp.textFaint,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Fp.inkSoft,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Fp.rPill),
                      borderSide: BorderSide(color: Fp.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Fp.rPill),
                      borderSide: BorderSide(color: Fp.hairline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Fp.rPill),
                      borderSide: BorderSide(color: Fp.violetGlow),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Fp.s12),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    if (_error != null) {
      return _hint(Icons.wifi_off_rounded, 'Something went wrong', _error!);
    }
    if (!_searched) {
      return Column(
        children: [
          Expanded(
            child: _hint(
              Icons.person_search_outlined,
              'Find someone on Flickpitch',
              'Type at least two characters. You can search a display name or an @username — no phone number needed.',
            ),
          ),
          _shareCard(),
        ],
      );
    }
    if (_results.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: _hint(
              Icons.search_off_rounded,
              'No one found',
              'Ask them to share their Flickpitch link so you can connect directly.',
            ),
          ),
          _shareCard(),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Fp.s16, Fp.s4, Fp.s16, Fp.s24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => Divider(color: Fp.hairline, height: 1),
      itemBuilder: (context, i) {
        final p = _results[i];
        return ListTile(
          onTap: () => _open(p),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Fp.s8,
            vertical: 4,
          ),
          leading: _Avatar(person: p),
          title: Text(
            p.displayName,
            style: Fp.bodyStrong.copyWith(fontSize: 15),
          ),
          subtitle: p.username.isEmpty
              ? null
              : Text(
                  '@${p.username}',
                  style: Fp.body.copyWith(color: Fp.textMuted, fontSize: 13),
                ),
          trailing: Icon(Icons.chevron_right, color: Fp.textFaint),
        );
      },
    );
  }

  Widget _hint(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.all(Fp.s32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: Fp.textFaint),
          const SizedBox(height: Fp.s16),
          Text(title, style: Fp.h2, textAlign: TextAlign.center),
          const SizedBox(height: Fp.s8),
          Text(
            body,
            style: Fp.body.copyWith(color: Fp.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Lets the account holder hand out a direct link instead of spelling out
  /// a username.
  Widget _shareCard() {
    final me = context.watch<AuthProvider>().currentUserName;
    if (me.isEmpty) return const SizedBox.shrink();
    final link =
        'Find me on Flickpitch — @$me\nhttps://web.flickpitch.com/download/';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Fp.s24, 0, Fp.s24, Fp.s24),
      child: Container(
        padding: const EdgeInsets.all(Fp.s16),
        decoration: BoxDecoration(
          color: Fp.inkSoft,
          borderRadius: BorderRadius.circular(Fp.rLg),
          border: Border.all(color: Fp.hairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Flickpitch link',
                    style: Fp.bodyStrong.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@$me',
                    style: Fp.body.copyWith(color: Fp.textMuted, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(text: link, subject: 'Find me on Flickpitch'),
              ),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Person {
  const _Person({
    required this.id,
    required this.fullName,
    required this.username,
    required this.photo,
  });

  final int id;
  final String fullName;
  final String username;
  final String photo;

  String get displayName => fullName.isNotEmpty
      ? fullName
      : (username.isNotEmpty ? '@$username' : 'Flickpitch user');

  static _Person fromJson(Map m) => _Person(
    id: _int(m['user_id'] ?? m['userId'] ?? m['id']),
    fullName: '${m['full_name'] ?? m['fullName'] ?? ''}'.trim(),
    username: '${m['user_name'] ?? m['userName'] ?? ''}'.trim(),
    photo: '${m['profile_pic'] ?? m['profilePic'] ?? m['avatar'] ?? ''}'.trim(),
  );

  static int _int(dynamic v) => int.tryParse('${v ?? ''}') ?? 0;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.person});
  final _Person person;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = person.photo.isNotEmpty;
    final initial = person.displayName.replaceAll('@', '').trim();
    return CircleAvatar(
      radius: 22,
      backgroundColor: Fp.violetGlow.withValues(alpha: 0.16),
      backgroundImage: hasPhoto ? NetworkImage(person.photo) : null,
      child: hasPhoto
          ? null
          : Text(
              initial.isEmpty ? '?' : initial[0].toUpperCase(),
              style: Fp.bodyStrong.copyWith(color: Fp.violetGlow),
            ),
    );
  }
}
