import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/communities/data/models/community_model.dart';
import 'package:whoxa/featuers/communities/data/repositories/communities_repository.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/widgets/global.dart';

/// Communities: the WhatsApp-Communities equivalent.
///
/// Lists the communities the signed-in account belongs to, then opens a
/// community to show its linked groups with member counts and a join action.
/// Opening a joined group hands the conversation id to the normal chat screen,
/// so all messaging behaviour stays in one place.
class CommunitiesScreen extends StatefulWidget {
  /// Set when the screen is opened from an invite link: the community is
  /// joined immediately, mirroring WhatsApp's "tap the link, you're in".
  final String? initialCode;

  const CommunitiesScreen({super.key, this.initialCode});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final CommunitiesRepository _repo = GetIt.I<CommunitiesRepository>();
  final _logger = ConsoleAppLogger.forModule('CommunitiesScreen');

  bool _loading = true;
  String? _error;
  List<CommunitySummary> _communities = const [];

  @override
  void initState() {
    super.initState();
    _load();
    final code = widget.initialCode;
    if (code != null && code.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoJoin(code));
    }
  }

  /// Join straight from a deep link (no dialog). Same path as _joinByCode.
  Future<void> _autoJoin(String code) async {
    try {
      final detail = await _repo.joinFromLinkOrCode(code.trim());
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityDetailScreen(
            communityId: detail.communityId,
            initial: detail,
          ),
        ),
      );
      await _load();
    } catch (e) {
      _logger.e('Deep-link join failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That invite link is not valid.')),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listMine();
      if (!mounted) return;
      setState(() {
        _communities = list;
        _loading = false;
      });
    } catch (e) {
      _logger.e('Could not load communities: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your communities. Pull down to try again.';
        _loading = false;
      });
    }
  }

  /// Create-community sheet: name + optional description, then the server
  /// returns an invite link that is shown immediately (it is the only way to
  /// bring members in).
  Future<void> _createCommunity() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final membersCtrl = TextEditingController();
    var step = 0; // 0 = name + description, 1 = add members
    var busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Fp.inkSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Fp.rLg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final messenger = ScaffoldMessenger.of(context);

            Future<void> submit() async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty || busy) return;
              setSheet(() => busy = true);
              try {
                final created = await _repo.createCommunity(
                  name: name,
                  description: descCtrl.text,
                );
                final communityId = (created['communityId'] ?? '').toString();
                final names = membersCtrl.text
                    .split(RegExp(r'[,\n]'))
                    .map((e) => e.trim().replaceFirst('@', ''))
                    .where((e) => e.isNotEmpty)
                    .toSet()
                    .toList();
                var added = 0;
                if (communityId.isNotEmpty && names.isNotEmpty) {
                  final res = await _repo.addMembers(
                    communityId,
                    userNames: names,
                  );
                  added = (res['addedCount'] as num?)?.toInt() ?? 0;
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                final link = created['inviteLink'] as String?;
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      [
                        'Community created',
                        if (added > 0) '$added member${added == 1 ? '' : 's'} added',
                        if (link != null) 'invite link: $link',
                      ].join(' · '),
                    ),
                  ),
                );
                await _load();
              } catch (e) {
                _logger.e('Could not create community: $e');
                if (!ctx.mounted) return;
                setSheet(() => busy = false);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Could not create the community.'),
                  ),
                );
              }
            }

            InputDecoration deco(String label) => InputDecoration(
              labelText: label,
              labelStyle: Fp.caption.copyWith(color: Fp.textMuted),
              filled: true,
              fillColor: Fp.inkRaised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Fp.rSm),
                borderSide: BorderSide(color: Fp.hairlineStrong),
              ),
            );

            return Padding(
              padding: EdgeInsets.fromLTRB(
                Fp.s20,
                Fp.s20,
                Fp.s20,
                MediaQuery.of(ctx).viewInsets.bottom + Fp.s20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step == 0 ? 'New community' : 'Add members',
                    style: Fp.h1,
                  ),
                  const SizedBox(height: Fp.s4),
                  Text(
                    step == 0
                        ? 'Name it, then pick who joins. Announcement and General groups are created automatically.'
                        : 'Optional. Usernames separated by commas - everyone joins Announcement and General.',
                    style: Fp.caption.copyWith(color: Fp.textMuted),
                  ),
                  const SizedBox(height: Fp.s16),
                  if (step == 0) ...[
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      maxLength: 80,
                      style: Fp.body,
                      decoration: deco('Community name'),
                    ),
                    const SizedBox(height: Fp.s8),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      maxLength: 200,
                      style: Fp.body,
                      decoration: deco('Description (optional)'),
                    ),
                  ] else ...[
                    TextField(
                      controller: membersCtrl,
                      autofocus: true,
                      maxLines: 3,
                      style: Fp.body,
                      decoration: deco('Usernames (optional)'),
                    ),
                    const SizedBox(height: Fp.s8),
                  ],
                  if (busy)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Fp.s12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Fp.violet),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: FpPrimaryButton(
                            label: step == 0 ? 'Cancel' : 'Back',
                            expand: true,
                            onPressed: () {
                              if (step == 0) {
                                Navigator.pop(ctx);
                              } else {
                                setSheet(() => step = 0);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: Fp.s12),
                        Expanded(
                          child: FpPrimaryButton(
                            label: step == 0 ? 'Next' : 'Create community',
                            icon: step == 0
                                ? Icons.arrow_forward_rounded
                                : Icons.done_rounded,
                            expand: true,
                            onPressed: () {
                              if (step == 0) {
                                if (nameCtrl.text.trim().isEmpty) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Give the community a name first.'),
                                    ),
                                  );
                                  return;
                                }
                                setSheet(() => step = 1);
                              } else {
                                submit();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _joinByCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join a community'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(
            hintText: 'Paste an invite link or code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;

    try {
      final detail = await _repo.joinFromLinkOrCode(code);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityDetailScreen(
            communityId: detail.communityId,
            initial: detail,
          ),
        ),
      );
      await _load();
    } catch (e) {
      _logger.e('Join failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That invite link is not valid.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FpCanvas(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Fp.s20,
                Fp.s12,
                Fp.s20,
                Fp.s40,
              ),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: Fp.s4),
                    Text('Communities', style: Fp.display),
                    const Spacer(),
                    IconButton(
                      tooltip: 'New community',
                      onPressed: _createCommunity,
                      icon: const Icon(Icons.add_rounded),
                    ),
                    IconButton(
                      tooltip: 'Join with a link',
                      onPressed: _joinByCode,
                      icon: const Icon(Icons.add_link_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: Fp.s8),
                Text(
                  'One place for your groups — join once, then follow the '
                  'groups that matter to you.',
                  style: Fp.body.copyWith(color: Fp.textMuted),
                ),
                const SizedBox(height: Fp.s20),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: Fp.s40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  FpEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Something went wrong',
                    message: _error!,
                  )
                else if (_communities.isEmpty)
                  FpEmptyState(
                    icon: Icons.groups_2_outlined,
                    title: 'No communities yet',
                    message:
                        'Create one, or join with an invite link to see your '
                        'groups here.',
                    action: FpPrimaryButton(
                      label: 'Create community',
                      icon: Icons.add_rounded,
                      expand: false,
                      onPressed: _createCommunity,
                    ),
                  )
                else
                  ..._communities.map(
                    (community) => Padding(
                      padding: const EdgeInsets.only(bottom: Fp.s12),
                      child: _CommunityCard(
                        community: community,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommunityDetailScreen(
                                communityId: community.communityId,
                                initialName: community.name,
                              ),
                            ),
                          );
                          await _load();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final CommunitySummary community;
  final VoidCallback onTap;

  const _CommunityCard({required this.community, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FpSurface(
      onTap: onTap,
      child: Row(
        children: [
          FpAvatar(
            label: community.name,
            imageUrl: community.avatarUrl,
            size: 52,
          ),
          const SizedBox(width: Fp.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(community.name, style: Fp.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  '${community.memberCount} members · '
                  '${community.groupCount} groups',
                  style: Fp.caption.copyWith(color: Fp.textMuted),
                ),
              ],
            ),
          ),
          if (community.canManage)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Fp.brandViolet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                community.role == 'owner' ? 'Owner' : 'Admin',
                style: Fp.caption.copyWith(
                  color: Fp.brandViolet,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: Fp.s8),
          Icon(Icons.chevron_right_rounded, color: Fp.textFaint),
        ],
      ),
    );
  }
}

/// Community detail: the linked groups, each with a join / open action.
class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  final CommunityDetail? initial;
  final String? initialName;

  const CommunityDetailScreen({
    super.key,
    required this.communityId,
    this.initial,
    this.initialName,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final CommunitiesRepository _repo = GetIt.I<CommunitiesRepository>();
  final _logger = ConsoleAppLogger.forModule('CommunityDetailScreen');

  CommunityDetail? _detail;
  bool _loading = true;
  String? _busyGroupId;
  bool _muted = false;
  bool _pinned = false;

  /// WhatsApp-style links: the community has its own link (below), and every
  /// group row exposes its own link through the group info sheet.
  String? _inviteUrl;
  bool _inviteCanReset = false;

  @override
  void initState() {
    super.initState();
    _detail = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await _repo.getDetail(widget.communityId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      if (detail.isMember) {
        try {
          final link = await _repo.inviteLink(widget.communityId);
          if (!mounted) return;
          setState(() {
            _inviteUrl = link['url']?.toString();
            _inviteCanReset = link['canReset'] == true;
          });
        } catch (e) {
          _logger.e('Could not load the community invite link: $e');
        }
      }
    } catch (e) {
      _logger.e('Could not load community: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ------------------------------------------------------- invite links
  Future<void> _copyInvite() async {
    final url = _inviteUrl;
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) snackbarNew(context, msg: 'Community invite link copied');
  }

  Future<void> _shareInvite() async {
    final url = _inviteUrl;
    if (url == null || url.isEmpty) return;
    final name = _detail?.name ?? 'this community';
    await SharePlus.instance.share(
      ShareParams(text: 'Join $name on Flickpitch: $url', subject: name),
    );
  }

  Future<void> _resetInvite() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset invite link?'),
        content: const Text(
          'The current community link stops working immediately. Groups keep their own links.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final link = await _repo.resetInviteLink(widget.communityId);
      if (!mounted) return;
      setState(() {
        _inviteUrl = link['url']?.toString();
        _inviteCanReset = link['canReset'] == true;
      });
      if (mounted) snackbarNew(context, msg: 'New community link created');
    } catch (e) {
      _logger.e('Could not reset the invite link: $e');
      if (mounted) snackbarNew(context, msg: 'Could not reset the link');
    }
  }

  Future<void> _openGroup(CommunityGroup group) async {
    if (!group.joined) {
      setState(() => _busyGroupId = group.conversationId);
      try {
        await _repo.joinGroup(widget.communityId, group.conversationId);
      } on AppError catch (e) {
        _logger.e('Could not join group: $e');
        if (mounted &&
            ((e.code?.startsWith('STATE_') ?? false) ||
                e.message.toLowerCase().contains('state group'))) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Stay in your state group'),
              content: Text(e.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not join this group.')),
          );
        }
      } catch (e) {
        _logger.e('Could not join group: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not join this group.')),
          );
        }
        if (mounted) setState(() => _busyGroupId = null);
        return;
      }
      if (mounted) setState(() => _busyGroupId = null);
    }

    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.universalChat,
      arguments: {
        'userId': 0,
        'chatId': int.tryParse(group.conversationId) ?? 0,
        'chatName': group.title,
        'profilePic': '',
        'isGroupChat': true,
        'blockFlag': false,
        'unseenCount': 0,
        'fromArchive': false,
      },
    );
  }

  // ------------------------------------------------------------ admin ops
  /// Group profile sheet: member count, the group's OWN invite link (copy,
  /// share, reset) and the join action. This is the per-group link WhatsApp
  /// keeps separate from the community link.
  Future<void> _openGroupInfo(CommunityGroup group) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Fp.inkSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Fp.rLg)),
      ),
      builder: (_) => CommunityGroupInfoSheet(
        communityId: widget.communityId,
        group: group,
        onJoin: () => _openGroup(group),
      ),
    );
  }

  Future<void> _openMenu() async {
    final detail = _detail;
    final canManage = detail?.canManage ?? false;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(Fp.s12),
        padding: const EdgeInsets.symmetric(vertical: Fp.s8),
        decoration: BoxDecoration(
          color: Fp.inkSoft,
          borderRadius: BorderRadius.circular(Fp.rLg),
          border: Border.all(color: Fp.hairlineStrong),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _menuTile(ctx, _muted ? 'Unmute community' : 'Mute community',
                  _muted ? Icons.notifications_active : Icons.notifications_off,
                  'mute'),
              _menuTile(ctx, _pinned ? 'Unpin community' : 'Pin community',
                  _pinned ? Icons.push_pin : Icons.push_pin_outlined, 'pin'),
              if (canManage) ...[
                _menuTile(ctx, 'Edit community', Icons.edit_outlined, 'edit'),
                _menuTile(ctx, 'Add member', Icons.person_add_alt_1, 'add'),
                _menuTile(ctx, 'New group', Icons.group_add_outlined, 'group'),
              ],
              _menuTile(ctx, 'Leave community', Icons.logout, 'leave',
                  danger: true),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'mute':
        await _togglePrefs(muted: !_muted);
      case 'pin':
        await _togglePrefs(pinned: !_pinned);
      case 'edit':
        await _editCommunity();
      case 'add':
        await _addMember();
      case 'group':
        await _createGroup();
      case 'leave':
        await _leave();
    }
  }

  Widget _menuTile(
    BuildContext ctx,
    String label,
    IconData icon,
    String value, {
    bool danger = false,
  }) {
    final color = danger ? Fp.danger : Fp.text;
    return ListTile(
      leading: Icon(icon, size: 20, color: color),
      title: Text(label, style: Fp.body.copyWith(color: color)),
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  Future<void> _togglePrefs({bool? muted, bool? pinned}) async {
    try {
      final res = await _repo.setPreferences(
        widget.communityId,
        muted: muted,
        pinned: pinned,
      );
      if (!mounted) return;
      setState(() {
        _muted = res['muted'] == true;
        _pinned = res['pinned'] == true;
      });
    } catch (e) {
      _logger.e('Could not update preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this community.')),
        );
      }
    }
  }

  Future<void> _editCommunity() async {
    final nameCtl = TextEditingController(text: _detail?.name ?? '');
    final descCtl = TextEditingController(text: _detail?.description ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit community'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await _repo.updateCommunity(
        widget.communityId,
        name: nameCtl.text.trim(),
        description: descCtl.text.trim(),
      );
      await _load();
    } catch (e) {
      _logger.e('Could not edit community: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save changes.')),
        );
      }
    }
  }

  Future<void> _addMember() async {
    final ctl = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add member'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: '@username',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    final value = ctl.text.trim();
    if (added != true || value.isEmpty) return;
    try {
      final res = await _repo.addMembers(
        widget.communityId,
        userNames: [value],
      );
      final count = res['addedCount'] ?? 0;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count == 0 ? 'No account matches “$value”.' : 'Member added.'),
          ),
        );
      }
    } catch (e) {
      _logger.e('Could not add member: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add this member.')),
        );
      }
    }
  }

  Future<void> _createGroup() async {
    final ctl = TextEditingController();
    final adminsOnly = ValueNotifier<bool>(false);
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctl,
              decoration: const InputDecoration(labelText: 'Group name'),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: adminsOnly,
              builder: (_, v, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Only admins can post'),
                value: v,
                onChanged: (nv) => adminsOnly.value = nv,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    final title = ctl.text.trim();
    if (created != true || title.isEmpty) return;
    try {
      await _repo.createGroup(
        widget.communityId,
        title: title,
        onlyAdminsCanPost: adminsOnly.value,
      );
      await _load();
    } catch (e) {
      _logger.e('Could not create group: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the group.')),
        );
      }
    }
  }

  Future<void> _removeGroup(CommunityGroup group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${group.displayName}?'),
        content: const Text(
          'The group is unlinked from this community. Its members and messages stay intact.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.removeGroup(widget.communityId, group.conversationId);
      await _load();
    } catch (e) {
      _logger.e('Could not remove group: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove this group.')),
        );
      }
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave community?'),
        content: const Text('You will stop receiving its groups and announcements.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.leave(widget.communityId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _logger.e('Could not leave community: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not leave this community.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      body: FpCanvas(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Fp.s20, Fp.s12, Fp.s20, Fp.s40),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: Fp.s4),
                  Expanded(
                    child: Text(
                      detail?.name ?? widget.initialName ?? 'Community',
                      style: Fp.bodyStrong,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_pinned)
                    Icon(Icons.push_pin, size: 16, color: Fp.violet),
                  if (_muted) ...[
                    const SizedBox(width: Fp.s4),
                    Icon(Icons.notifications_off, size: 16, color: Fp.textFaint),
                  ],
                  IconButton(
                    tooltip: 'Community options',
                    onPressed: _openMenu,
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
              const SizedBox(height: Fp.s8),
              if (_loading && detail == null)
                const Padding(
                  padding: EdgeInsets.only(top: Fp.s40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if ((detail?.description ?? '').trim().isNotEmpty) ...[
                  Text(
                    detail!.description!,
                    style: Fp.body.copyWith(color: Fp.textMuted),
                  ),
                  const SizedBox(height: Fp.s12),
                ],
                Text(
                  '${detail?.memberCount ?? 0} members · '
                  '${detail?.groups.length ?? 0} groups',
                  style: Fp.caption.copyWith(color: Fp.textFaint),
                ),
                if ((_inviteUrl ?? '').isNotEmpty) ...[
                  const SizedBox(height: Fp.s16),
                  FpSurface(
                    padding: const EdgeInsets.all(Fp.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.link_rounded,
                              size: 16,
                              color: Fp.brandViolet,
                            ),
                            const SizedBox(width: Fp.s8),
                            Text(
                              'Community invite link',
                              style: Fp.bodyStrong,
                            ),
                          ],
                        ),
                        const SizedBox(height: Fp.s8),
                        Text(
                          _inviteUrl!,
                          style: Fp.caption.copyWith(color: Fp.textMuted),
                        ),
                        const SizedBox(height: Fp.s12),
                        Row(
                          children: [
                            Expanded(
                              child: FpGhostButton(
                                label: 'Copy',
                                icon: Icons.copy_rounded,
                                onPressed: _copyInvite,
                              ),
                            ),
                            const SizedBox(width: Fp.s8),
                            Expanded(
                              child: FpGhostButton(
                                label: 'Share',
                                icon: Icons.ios_share_rounded,
                                onPressed: _shareInvite,
                              ),
                            ),
                            if (_inviteCanReset) ...[
                              const SizedBox(width: Fp.s8),
                              Expanded(
                                child: FpGhostButton(
                                  label: 'Reset',
                                  icon: Icons.refresh_rounded,
                                  onPressed: _resetInvite,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: Fp.s8),
                        Text(
                          'Joins this community with Announcement and General. Every group below has its own separate link.',
                          style: Fp.caption.copyWith(color: Fp.textFaint),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: Fp.s20),
                ...((detail?.groups ?? const <CommunityGroup>[]).map(
                  (group) => Padding(
                    padding: const EdgeInsets.only(bottom: Fp.s8),
                    child: FpSurface(
                      onTap: () => _openGroup(group),
                      child: Row(
                        children: [
                          FpAvatar(label: group.displayName, size: 42),
                          const SizedBox(width: Fp.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(group.displayName, style: Fp.bodyStrong),
                                const SizedBox(height: 2),
                                Text(
                                  '${group.memberCount}'
                                  '${group.maxMembers != null ? ' / ${group.maxMembers}' : ''}'
                                  ' members',
                                  style: Fp.caption.copyWith(
                                    color: Fp.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_busyGroupId == group.conversationId)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (group.joined)
                            Text(
                              'Open',
                              style: Fp.caption.copyWith(
                                color: Fp.brandViolet,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else
                            Text(
                              'Join',
                              style: Fp.caption.copyWith(
                                color: Fp.cyan,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          IconButton(
                            tooltip: 'Group info and invite link',
                            onPressed: () => _openGroupInfo(group),
                            icon: Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: Fp.textFaint,
                            ),
                          ),
                          if ((detail?.canManage ?? false) &&
                              !const ['announcement', 'general'].contains(
                                (group.label ?? group.title).toLowerCase(),
                              ))
                            IconButton(
                              tooltip: 'Remove group',
                              onPressed: () => _removeGroup(group),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Group profile for one community group: member count, the group's OWN
/// invite link and the join action. WhatsApp keeps a separate link per group
/// (separate from the community link), and so does Flickpitch.
class CommunityGroupInfoSheet extends StatefulWidget {
  final String communityId;
  final CommunityGroup group;
  final Future<void> Function()? onJoin;

  const CommunityGroupInfoSheet({
    super.key,
    required this.communityId,
    required this.group,
    this.onJoin,
  });

  @override
  State<CommunityGroupInfoSheet> createState() =>
      _CommunityGroupInfoSheetState();
}

class _CommunityGroupInfoSheetState extends State<CommunityGroupInfoSheet> {
  final CommunitiesRepository _repo = GetIt.I<CommunitiesRepository>();
  final _logger = ConsoleAppLogger.forModule('CommunityGroupInfoSheet');

  String? _url;
  bool _canReset = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final link = await _repo.groupInviteLink(
        widget.communityId,
        widget.group.conversationId,
      );
      if (!mounted) return;
      setState(() {
        _url = link['url']?.toString();
        _canReset = link['canReset'] == true;
        _loading = false;
      });
    } catch (e) {
      _logger.e('Could not load the group invite link: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _copy() async {
    final url = _url;
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) snackbarNew(context, msg: 'Group invite link copied');
  }

  Future<void> _share() async {
    final url = _url;
    if (url == null || url.isEmpty) return;
    final name = widget.group.displayName;
    await SharePlus.instance.share(
      ShareParams(text: 'Join $name on Flickpitch: $url', subject: name),
    );
  }

  Future<void> _reset() async {
    setState(() => _loading = true);
    try {
      final link = await _repo.resetGroupInviteLink(
        widget.communityId,
        widget.group.conversationId,
      );
      if (!mounted) return;
      setState(() {
        _url = link['url']?.toString();
        _canReset = link['canReset'] == true;
        _loading = false;
      });
      if (mounted) snackbarNew(context, msg: 'New group link created');
    } catch (e) {
      _logger.e('Could not reset the group invite link: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      snackbarNew(context, msg: 'Could not reset this link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Fp.s20, Fp.s20, Fp.s20, Fp.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FpAvatar(label: group.displayName, size: 44),
                const SizedBox(width: Fp.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.displayName, style: Fp.bodyStrong),
                      const SizedBox(height: 2),
                      Text(
                        '${group.memberCount}'
                        '${group.maxMembers != null ? ' / ${group.maxMembers}' : ''}'
                        ' members'
                        '${group.onlyAdminsCanPost ? ' · only admins can post' : ''}',
                        style: Fp.caption.copyWith(color: Fp.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((group.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: Fp.s12),
              Text(
                group.description!,
                style: Fp.caption.copyWith(color: Fp.textMuted),
              ),
            ],
            const SizedBox(height: Fp.s16),
            Text('Group invite link', style: Fp.bodyStrong),
            const SizedBox(height: Fp.s8),
            FpSurface(
              padding: const EdgeInsets.all(Fp.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loading ? 'Loading…' : (_url ?? 'Link unavailable'),
                    style: Fp.caption.copyWith(color: Fp.textMuted),
                  ),
                  const SizedBox(height: Fp.s12),
                  Row(
                    children: [
                      Expanded(
                        child: FpGhostButton(
                          label: 'Copy',
                          icon: Icons.copy_rounded,
                          onPressed: _url == null ? null : _copy,
                        ),
                      ),
                      const SizedBox(width: Fp.s8),
                      Expanded(
                        child: FpGhostButton(
                          label: 'Share',
                          icon: Icons.ios_share_rounded,
                          onPressed: _url == null ? null : _share,
                        ),
                      ),
                      if (_canReset) ...[
                        const SizedBox(width: Fp.s8),
                        Expanded(
                          child: FpGhostButton(
                            label: 'Reset',
                            icon: Icons.refresh_rounded,
                            onPressed: _loading ? null : _reset,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: Fp.s8),
                  Text(
                    'Anyone with this link joins the community and this group.',
                    style: Fp.caption.copyWith(color: Fp.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Fp.s16),
            FpPrimaryButton(
              label: group.joined ? 'Open group' : 'Join group',
              icon: group.joined ? Icons.chat_bubble_outline : Icons.login,
              onPressed: () async {
                Navigator.pop(context);
                final join = widget.onJoin;
                if (join != null) await join();
              },
            ),
            if (group.joined) ...[
              const SizedBox(height: Fp.s8),
              FpGhostButton(
                label: 'Exit group',
                icon: Icons.logout,
                onPressed: _leaveGroup,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave ${widget.group.displayName}?'),
        content: const Text(
          'You stay in the community, but this group disappears from your chat list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.leaveGroupConversation(widget.group.conversationId);
      if (!mounted) return;
      Navigator.pop(context);
      snackbarNew(context, msg: 'You left the group');
    } catch (e) {
      _logger.e('Could not leave the group: $e');
      if (mounted) snackbarNew(context, msg: 'Could not leave this group');
    }
  }
}
