import 'package:flutter/material.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/call/call_history/models/call_history_model.dart';
import 'package:whoxa/featuers/call/call_history/providers/call_history_provider.dart';

/// Redesigned Calls surface.
///
/// Structure differs from the stock call log:
///   * a summary strip (total / missed / video) above the list,
///   * a pill filter that actually filters (All / Missed / Audio / Video),
///   * rows are cards showing direction + duration + outcome, grouped by day,
///   * dedicated empty state instead of an empty ListView.
class FpCallsScreen extends StatefulWidget {
  const FpCallsScreen({super.key});

  @override
  State<FpCallsScreen> createState() => _FpCallsScreenState();
}

class _FpCallsScreenState extends State<FpCallsScreen> {
  int _filter = 0; // 0 all, 1 missed, 2 audio, 3 video

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<CallHistoryProvider>();
      if (p.callHistory.isEmpty) p.fetchCallHistory(refresh: true);
    });
  }

  List<CallRecord> _visible(CallHistoryProvider p) {
    final all = p.callHistory;
    return switch (_filter) {
      1 => all.where((c) => _isMissed(c)).toList(),
      2 => all.where((c) => _type(c) == 'audio').toList(),
      3 => all.where((c) => _type(c) == 'video').toList(),
      _ => all,
    };
  }

  @override
  Widget build(BuildContext context) {
    // theme dependency: rebuild this screen when the theme changes
    // so the static Fp tokens are re-read (they are not InheritedWidgets).
    context.watch<ThemeProvider>();
    final provider = context.watch<CallHistoryProvider>();
    final rows = _visible(provider);
    final missed = provider.callHistory.where(_isMissed).length;

    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        child: RefreshIndicator(
          color: Fp.violet,
          backgroundColor: Fp.inkRaised,
          onRefresh: () => provider.fetchCallHistory(refresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Fp.s24, Fp.s12, Fp.s24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CALLS',
                          style: Fp.label.copyWith(color: Fp.violetGlow)),
                      const SizedBox(height: Fp.s4),
                      Text('Call log', style: Fp.display),
                      const SizedBox(height: Fp.s20),
                      Row(
                        children: [
                          _Stat(
                            value: '${provider.callHistory.length}',
                            label: 'Total',
                            tint: Fp.violetGlow,
                          ),
                          const SizedBox(width: Fp.s12),
                          _Stat(
                            value: '$missed',
                            label: 'Missed',
                            tint: Fp.coral,
                          ),
                          const SizedBox(width: Fp.s12),
                          _Stat(
                            value:
                                '${provider.callHistory.where((c) => _type(c) == 'video').length}',
                            label: 'Video',
                            tint: Fp.cyan,
                          ),
                        ],
                      ),
                      const SizedBox(height: Fp.s20),
                      _Filter(
                        index: _filter,
                        onChanged: (i) => setState(() => _filter = i),
                      ),
                    ],
                  ),
                ),
              ),
              if (provider.isLoading && provider.callHistory.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Fp.violetGlow),
                    ),
                  ),
                )
              else if (rows.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: FpEmptyState(
                    icon: Icons.call_outlined,
                    title: 'No calls here',
                    message:
                        'Calls you make and receive will appear in this log.',
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(Fp.s16, Fp.s16, Fp.s16, 120),
                  sliver: SliverList.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Fp.s8),
                    itemBuilder: (context, i) => _CallCard(record: rows[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _type(CallRecord r) {
    final calls = r.calls;
    if (calls.isEmpty) return 'audio';
    return (calls.first.callType).toLowerCase();
  }

  static bool _isMissed(CallRecord r) {
    final calls = r.calls;
    if (calls.isEmpty) return false;
    final status = calls.first.callStatus.toLowerCase();
    return status.contains('miss') || status.contains('declin') ||
        status.contains('cancel');
  }
}

class _CallCard extends StatelessWidget {
  const _CallCard({required this.record});
  final CallRecord record;

  @override
  Widget build(BuildContext context) {
    final call = record.calls.isNotEmpty ? record.calls.first : null;
    final peer = (record.peerUser?.isNotEmpty ?? false)
        ? record.peerUser!.first
        : null;

    final name = _displayName(peer);
    final video = (call?.callType ?? '').toLowerCase() == 'video';
    final missed = _FpCallsScreenState._isMissed(record);
    final secs = call?.callDuration ?? 0;

    return FpSurface(
      padding: const EdgeInsets.symmetric(
          horizontal: Fp.s16, vertical: Fp.s12),
      radius: Fp.rMd,
      accentRail: missed ? Fp.coral : null,
      child: Row(
        children: [
          FpAvatar(
            imageUrl: peer?.profilePic,
            label: name,
            size: 48,
            ring: missed ? Fp.coral : null,
          ),
          const SizedBox(width: Fp.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Fp.bodyStrong),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      missed
                          ? Icons.call_missed_outgoing
                          : (video ? Icons.videocam_outlined : Icons.call_received),
                      size: 14,
                      color: missed ? Fp.coral : Fp.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${video ? 'Video' : 'Audio'} · ${_duration(secs)}',
                      style: Fp.caption.copyWith(
                        color: missed ? Fp.coral : Fp.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Fp.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_time(record.createdAt),
                  style: Fp.caption.copyWith(color: Fp.textFaint)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _MiniAction(
                    icon: Icons.call,
                    onTap: () {},
                  ),
                  const SizedBox(width: 6),
                  _MiniAction(
                    icon: Icons.videocam,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _displayName(PeerUser? p) {
    if (p == null) return 'Unknown';
    final full = (p.fullName ?? '').trim();
    if (full.isNotEmpty) return full;
    final u = (p.userName ?? '').trim();
    return u.isNotEmpty ? u : 'Unknown';
  }

  static String _duration(int secs) {
    if (secs <= 0) return 'No answer';
    final m = secs ~/ 60;
    final s = secs % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  static String _time(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      final h24 = local.hour;
      final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
      return '$h12:${local.minute.toString().padLeft(2, '0')}'
          '${h24 < 12 ? 'am' : 'pm'}';
    }
    return '${local.day}/${local.month}';
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Fp.rPill),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Fp.violet.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 15, color: Fp.violetGlow),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.tint});
  final String value;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FpSurface(
        padding: const EdgeInsets.symmetric(
            horizontal: Fp.s12, vertical: Fp.s12),
        radius: Fp.rMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: Fp.h2.copyWith(color: tint)),
            const SizedBox(height: 2),
            Text(label, style: Fp.caption.copyWith(color: Fp.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['All', 'Missed', 'Audio', 'Video'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Fp.inkRaised.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Fp.rPill),
        border: Border.all(color: Fp.hairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: Fp.base,
                  curve: Fp.ease,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: i == index ? Fp.accent : null,
                    borderRadius: BorderRadius.circular(Fp.rPill),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: Fp.bodyStrong.copyWith(
                      fontSize: 12.5,
                      color: i == index ? Colors.white : Fp.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
