import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/business/data/models/business_dashboard_model.dart';
import 'package:whoxa/featuers/business/data/repositories/business_repository.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';

/// Business stats (`GET /business/dashboard?days=7|30|90`).
///
/// Rebuilt on the Flickpitch design system: stat tiles, chart and legends now
/// use Fp surfaces/tokens instead of the stock dashboard chrome.
class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  final BusinessRepository _repository = GetIt.instance<BusinessRepository>();
  static const _periods = [7, 30, 90];

  int _days = 7;
  bool _loading = true;
  String? _error;
  BusinessDashboard? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _data = await _repository.getDashboard(days: _days);
    } catch (e) {
      _error = e is AppError ? e.message : e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Color _parse(String hex) {
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return Fp.violet;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        child: RefreshIndicator(
          color: Fp.violet,
          backgroundColor: Fp.inkRaised,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Fp.s20, Fp.s12, Fp.s20, Fp.s40),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Fp.text,
                  ),
                  const SizedBox(width: Fp.s4),
                  Expanded(child: Text('Dashboard', style: Fp.display)),
                  IconButton(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                    color: Fp.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: Fp.s8),
              Row(
                children: [
                  for (final d in _periods) ...[
                    GestureDetector(
                      onTap: _loading
                          ? null
                          : () {
                              setState(() => _days = d);
                              _load();
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Fp.s16,
                          vertical: Fp.s8,
                        ),
                        margin: const EdgeInsets.only(right: Fp.s8),
                        decoration: BoxDecoration(
                          color: _days == d ? Fp.violet : Fp.inkRaised,
                          borderRadius: BorderRadius.circular(Fp.rPill),
                          border: Border.all(
                            color: _days == d ? Fp.violet : Fp.hairlineStrong,
                          ),
                        ),
                        child: Text(
                          'Last $d days',
                          style: Fp.caption.copyWith(
                            color: _days == d ? Colors.white : Fp.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Fp.s20),
              if (_loading && _data == null)
                Padding(
                  padding: const EdgeInsets.only(top: Fp.s40),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Fp.violet),
                    ),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: Fp.s40),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 34, color: Fp.textFaint),
                      const SizedBox(height: Fp.s12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: Fp.body.copyWith(color: Fp.textMuted),
                      ),
                      const SizedBox(height: Fp.s16),
                      FpPrimaryButton(
                        label: 'Try again',
                        expand: false,
                        onPressed: _load,
                      ),
                    ],
                  ),
                )
              else if (_data != null)
                ..._content(_data!),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BusinessDashboard d) {
    return [
      const FpSectionLabel('Right now'),
      const SizedBox(height: Fp.s12),
      _grid([
        _stat('Chats', d.chats, Fp.violet),
        _stat('Unread chats', d.unreadChats, Fp.coral),
        _stat('Products', d.catalogItems, Fp.cyan),
        _stat('Labels', d.labels, Fp.amber),
      ]),
      const SizedBox(height: Fp.s24),
      FpSectionLabel('Last ${d.periodDays} days'),
      const SizedBox(height: Fp.s12),
      _grid([
        _stat('New chats', d.newChats, Fp.violet),
        _stat('Received', d.messagesReceived, Fp.cyan),
        _stat('Sent', d.messagesSent, Fp.mint),
        _stat('Auto replies', d.greetingsSent + d.awaysSent, Fp.amber),
        _stat('Catalog views', d.catalogViews, Fp.coral),
      ]),
      const SizedBox(height: Fp.s8),
      Text(
        'Auto replies: ${d.greetingsSent} greeting · ${d.awaysSent} away '
        '(included in Sent)',
        style: Fp.caption.copyWith(color: Fp.textFaint),
      ),
      const SizedBox(height: Fp.s24),
      const FpSectionLabel('Messages per day'),
      const SizedBox(height: Fp.s12),
      _chart(d),
      const SizedBox(height: Fp.s24),
      const FpSectionLabel('Most viewed products'),
      const SizedBox(height: Fp.s8),
      if (d.topCatalogItems.isEmpty)
        Text(
          'No product views yet',
          style: Fp.caption.copyWith(color: Fp.textFaint),
        )
      else
        ...d.topCatalogItems.map(
          (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: Fp.s8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    i.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Fp.body,
                  ),
                ),
                Text(
                  '${i.views} view${i.views == 1 ? '' : 's'}',
                  style: Fp.caption.copyWith(color: Fp.textMuted),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: Fp.s24),
      const FpSectionLabel('Top labels'),
      const SizedBox(height: Fp.s8),
      if (d.topLabels.isEmpty)
        Text(
          'No labelled chats yet',
          style: Fp.caption.copyWith(color: Fp.textFaint),
        )
      else
        ...d.topLabels.map(
          (l) => Padding(
            padding: const EdgeInsets.symmetric(vertical: Fp.s8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _parse(l.labelColor),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Fp.s12),
                Expanded(child: Text(l.labelText, style: Fp.body)),
                Text(
                  '${l.chats} chat${l.chats == 1 ? '' : 's'}',
                  style: Fp.caption.copyWith(color: Fp.textMuted),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: Fp.s24),
    ];
  }

  Widget _grid(List<Widget> children) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: Fp.s12,
    crossAxisSpacing: Fp.s12,
    childAspectRatio: 2.05,
    children: children,
  );

  Widget _stat(String label, int value, Color tint) => FpSurface(
    padding: const EdgeInsets.symmetric(horizontal: Fp.s16, vertical: Fp.s12),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: Fp.h1.copyWith(fontSize: 24, color: tint),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Fp.caption.copyWith(color: Fp.textMuted),
        ),
      ],
    ),
  );

  /// Paired bars (received / sent) per day; 30/90-day views drop the labels
  /// to keep them legible.
  Widget _chart(BusinessDashboard d) {
    final days = d.messagesByDay;
    if (days.isEmpty) return const SizedBox.shrink();
    final max = days
        .map((e) => e.received > e.sent ? e.received : e.sent)
        .fold<int>(1, (a, b) => b > a ? b : a);
    final primary = Fp.violet;
    final secondary = Fp.textFaint;
    const height = 120.0;

    return FpSurface(
      padding: const EdgeInsets.all(Fp.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _legend(primary, 'Received'),
              const SizedBox(width: Fp.s16),
              _legend(secondary, 'Sent'),
            ],
          ),
          const SizedBox(height: Fp.s12),
          SizedBox(
            height: height + 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children:
                  days.map((day) {
                    return Expanded(
                      child: Tooltip(
                        message:
                            '${day.date}\nReceived ${day.received} · Sent ${day.sent}',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _bar(day.received / max * height, primary),
                                _bar(day.sent / max * height, secondary),
                              ],
                            ),
                            if (days.length <= 7)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  day.date.length >= 10
                                      ? day.date.substring(8)
                                      : day.date,
                                  style: Fp.caption.copyWith(
                                    fontSize: 9,
                                    color: Fp.textFaint,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double h, Color color) => Container(
    width: 5,
    height: h < 2 ? 2 : h,
    margin: const EdgeInsets.symmetric(horizontal: 0.5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _legend(Color c, String t) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(t, style: Fp.caption.copyWith(color: Fp.textMuted)),
    ],
  );
}
