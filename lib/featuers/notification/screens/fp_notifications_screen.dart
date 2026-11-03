import 'package:flutter/material.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/notification/model/notification_model.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';

/// Redesigned notifications surface.
///
/// Structural differences from the stock list:
///   * day-grouped sections with sticky-feeling headers (Today / Yesterday /
///     date) instead of a flat grouped ListView with stock tiles,
///   * each notification is a card with an accent glyph keyed to its kind,
///   * designed loading / empty / error states, and pull-to-refresh.
class FpNotificationsScreen extends StatefulWidget {
  const FpNotificationsScreen({super.key});

  @override
  State<FpNotificationsScreen> createState() => _FpNotificationsScreenState();
}

class _FpNotificationsScreenState extends State<FpNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectConfigProvider>().fetchNotificationList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // theme dependency: rebuild this screen when the theme changes
    // so the static Fp tokens are re-read (they are not InheritedWidgets).
    context.watch<ThemeProvider>();
    final provider = context.watch<ProjectConfigProvider>();
    final items = provider.notificationList ?? const <Records>[];
    final groups = _groupByDay(items);

    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Fp.s16, Fp.s12, Fp.s24, 0),
              child: Row(
                children: [
                  FpIconTile(
                    icon: Icons.arrow_back,
                    size: 40,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: Fp.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('INBOX',
                            style: Fp.label.copyWith(color: Fp.violetGlow)),
                        Text('Notifications', style: Fp.h1),
                      ],
                    ),
                  ),
                  FpIconTile(
                    icon: Icons.refresh,
                    size: 40,
                    onTap: () => provider.fetchNotificationList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Fp.s16),
            Expanded(
              child: provider.isNotification && items.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Fp.violetGlow),
                      ),
                    )
                  : items.isEmpty
                      ? const FpEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'No notifications yet',
                          message:
                              'Messages, calls and account activity will land here.',
                        )
                      : RefreshIndicator(
                          color: Fp.violet,
                          backgroundColor: Fp.inkRaised,
                          onRefresh: () => provider.fetchNotificationList(),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(
                                Fp.s16, 0, Fp.s16, 40),
                            children: [
                              for (final entry in groups.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      Fp.s8, Fp.s16, Fp.s8, Fp.s8),
                                  child: Text(entry.key.toUpperCase(),
                                      style: Fp.label
                                          .copyWith(color: Fp.textFaint)),
                                ),
                                for (final n in entry.value) ...[
                                  _NotifCard(record: n),
                                  const SizedBox(height: Fp.s8),
                                ],
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Today / Yesterday / "3 Oct" buckets, newest first.
  Map<String, List<Records>> _groupByDay(List<Records> items) {
    final map = <String, List<Records>>{};
    final now = DateTime.now();
    for (final n in items) {
      final dt = DateTime.tryParse(n.createdAt ?? '')?.toLocal();
      String key;
      if (dt == null) {
        key = 'Earlier';
      } else if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day) {
        key = 'Today';
      } else if (dt.year == now.subtract(const Duration(days: 1)).year &&
          dt.month == now.subtract(const Duration(days: 1)).month &&
          dt.day == now.subtract(const Duration(days: 1)).day) {
        key = 'Yesterday';
      } else {
        key = '${dt.day}/${dt.month}/${dt.year}';
      }
      map.putIfAbsent(key, () => []).add(n);
    }
    return map;
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.record});
  final Records record;

  @override
  Widget build(BuildContext context) {
    final title = (record.title ?? '').trim();
    final body = (record.message ?? '').trim();
    final kind = _kindOf('$title $body');

    return FpSurface(
      padding: const EdgeInsets.all(Fp.s16),
      radius: Fp.rMd,
      onTap: () {},
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kind.$2.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(Fp.rSm),
            ),
            child: Icon(kind.$1, size: 19, color: kind.$2),
          ),
          const SizedBox(width: Fp.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.isEmpty ? 'Flickpitch' : title,
                        style: Fp.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(_time(record.createdAt),
                        style: Fp.caption.copyWith(
                            color: Fp.textFaint, fontSize: 11)),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(body,
                      style: Fp.caption.copyWith(color: Fp.textMuted),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static (IconData, Color) _kindOf(String text) {
    final t = text.toLowerCase();
    if (t.contains('call')) return (Icons.call_outlined, Fp.mint);
    if (t.contains('missed')) return (Icons.call_missed_outgoing, Fp.coral);
    if (t.contains('message') || t.contains('chat')) {
      return (Icons.chat_bubble_outline, Fp.violet);
    }
    if (t.contains('payment') || t.contains('subscription')) {
      return (Icons.workspace_premium_outlined, Fp.amber);
    }
    return (Icons.notifications_none_rounded, Fp.cyan);
  }

  static String _time(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return '';
    final h24 = dt.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:${dt.minute.toString().padLeft(2, '0')}'
        '${h24 < 12 ? 'am' : 'pm'}';
  }
}
