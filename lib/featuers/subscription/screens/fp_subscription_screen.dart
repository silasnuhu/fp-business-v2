import 'package:flutter/material.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/core/services/app_content_service.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/subscription/data/subscription_config.dart';
import 'package:whoxa/featuers/subscription/provider/subscription_provider.dart';

/// Redesigned subscription surface.
///
/// Structure differs from the stock paywall:
///   * an active-membership card that replaces the plan chooser once premium,
///   * plan cards with a computed saving badge rather than plain list tiles,
///   * a single primary CTA plus a secondary restore action,
///   * inline purchase state (busy / error) instead of snackbars only.
class FpSubscriptionScreen extends StatefulWidget {
  const FpSubscriptionScreen({super.key});

  @override
  State<FpSubscriptionScreen> createState() => _FpSubscriptionScreenState();
}

class _FpSubscriptionScreenState extends State<FpSubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().refreshStatus();
    });
    // Admin can pause membership; read the flag before painting plans.
    AppContentService.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // theme dependency: rebuild this screen when the theme changes
    // so the static Fp tokens are re-read (they are not InheritedWidgets).
    context.watch<ThemeProvider>();
    final sub = context.watch<SubscriptionProvider>();
    final options = sub.plans;

    // Membership switched off in admin: no plans, no prices, no upgrade path.
    if (!AppContentService.instance.membershipEnabled) {
      return Scaffold(
        backgroundColor: Fp.ink,
        body: FpCanvas(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Fp.s32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.pause_circle_outline,
                    size: 46,
                    color: Fp.textFaint,
                  ),
                  const SizedBox(height: Fp.s16),
                  Text(
                    'Membership is paused',
                    style: Fp.h2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Fp.s8),
                  Text(
                    'Subscriptions are temporarily unavailable. Your account keeps working exactly as it does today.',
                    style: Fp.body.copyWith(color: Fp.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Fp.s24),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Back',
                      style: Fp.bodyStrong.copyWith(color: Fp.violetGlow),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Fp.s16, Fp.s12, Fp.s16, 40),
          children: [
            Row(
              children: [
                FpIconTile(
                  icon: Icons.arrow_back,
                  size: 40,
                  onTap: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: Fp.s12),
                Text('Membership', style: Fp.h1),
              ],
            ),
            const SizedBox(height: Fp.s24),

            if (sub.premiumUser) ...[
              _ActiveCard(expiry: sub.premiumExpiresAt, plan: sub.activePlan),
              const SizedBox(height: Fp.s24),
            ] else ...[
              Text(
                'GO PREMIUM',
                style: Fp.label.copyWith(color: Fp.violetGlow),
              ),
              const SizedBox(height: Fp.s8),
              Text('More room,\nmore control.', style: Fp.display),
              const SizedBox(height: Fp.s8),
              Text(
                'Unlock the full Flickpitch experience — larger uploads, richer calls and no limits on the conversations that matter.',
                style: Fp.body.copyWith(color: Fp.textMuted),
              ),
              const SizedBox(height: Fp.s24),
            ],

            _Benefits(),
            const SizedBox(height: Fp.s24),

            if (!sub.premiumUser) ...[
              if (sub.isLoadingProducts && options.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: Fp.s32),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Fp.violetGlow),
                    ),
                  ),
                )
              else ...[
                for (final entry in options.entries) ...[
                  _PlanCard(
                    plan: entry.key,
                    price: entry.value.formattedPrice,
                    selected: sub.selectedPlan == entry.key,
                    saving: _saving(options),
                    onTap: () => sub.selectPlan(entry.key),
                  ),
                  const SizedBox(height: Fp.s12),
                ],
                const SizedBox(height: Fp.s8),
                FpPrimaryButton(
                  label: sub.isPurchasing ? 'Processing…' : 'Continue',
                  icon: Icons.lock_open_outlined,
                  loading: sub.isPurchasing,
                  onPressed: sub.isBusy ? null : () => sub.purchase(),
                ),
                const SizedBox(height: Fp.s8),
                FpGhostButton(
                  label: sub.isRestoring ? 'Restoring…' : 'Restore purchases',
                  onPressed: sub.isBusy ? null : () => sub.restorePurchases(),
                ),
              ],
            ] else ...[
              FpGhostButton(
                label: sub.isRestoring ? 'Restoring…' : 'Restore purchases',
                onPressed: sub.isBusy ? null : () => sub.restorePurchases(),
              ),
            ],

            if (sub.eventMessage != null &&
                sub.eventMessage!.trim().isNotEmpty) ...[
              const SizedBox(height: Fp.s16),
              Container(
                padding: const EdgeInsets.all(Fp.s16),
                decoration: BoxDecoration(
                  color: (sub.eventIsError ? Fp.coral : Fp.mint).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(Fp.rMd),
                  border: Border.all(
                    color: (sub.eventIsError ? Fp.coral : Fp.mint).withValues(
                      alpha: 0.35,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      sub.eventIsError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 18,
                      color: sub.eventIsError ? Fp.coral : Fp.mint,
                    ),
                    const SizedBox(width: Fp.s12),
                    Expanded(
                      child: Text(
                        sub.eventMessage!,
                        style: Fp.caption.copyWith(color: Fp.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: Fp.s24),
            Center(
              child: Text(
                'Billing is handled by the store. Cancel any time.',
                style: Fp.caption.copyWith(color: Fp.textFaint),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Percentage saved by yearly vs 12x monthly, when both prices are known.
  String? _saving(Map<SubscriptionPlan, dynamic> plans) {
    final m = plans[SubscriptionPlan.monthly];
    final y = plans[SubscriptionPlan.yearly];
    if (m == null || y == null) return null;
    final monthly = (m.rawPrice as num).toDouble();
    final yearly = (y.rawPrice as num).toDouble();
    if (monthly <= 0 || yearly <= 0) return null;
    final full = monthly * 12;
    if (yearly >= full) return null;
    return '${(((full - yearly) / full) * 100).round()}% off';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.price,
    required this.selected,
    required this.saving,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final String price;
  final bool selected;
  final String? saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final yearly = plan == SubscriptionPlan.yearly;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Fp.base,
        curve: Fp.ease,
        padding: const EdgeInsets.all(Fp.s20),
        decoration: BoxDecoration(
          gradient: selected ? Fp.accent : null,
          color: selected ? null : Fp.inkRaised.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(Fp.rLg),
          border: Border.all(
            color: selected ? Colors.transparent : Fp.hairlineStrong,
          ),
          boxShadow: selected ? Fp.glow(Fp.violet) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.white : Colors.transparent,
                border: Border.all(
                  color: selected ? Colors.white : Fp.hairlineStrong,
                  width: 2,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 14, color: Fp.violetDeep)
                  : null,
            ),
            const SizedBox(width: Fp.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        yearly ? 'Yearly' : 'Monthly',
                        style: Fp.bodyStrong.copyWith(
                          color: selected ? Colors.white : Fp.text,
                        ),
                      ),
                      if (yearly && saving != null) ...[
                        const SizedBox(width: Fp.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.22)
                                : Fp.mint.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(Fp.rPill),
                          ),
                          child: Text(
                            saving!,
                            style: Fp.caption.copyWith(
                              fontSize: 10.5,
                              color: selected ? Colors.white : Fp.mint,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    yearly ? 'Billed once a year' : 'Billed every month',
                    style: Fp.caption.copyWith(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.8)
                          : Fp.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: Fp.h2.copyWith(color: selected ? Colors.white : Fp.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.expiry, required this.plan});

  final DateTime? expiry;
  final SubscriptionPlan? plan;

  @override
  Widget build(BuildContext context) {
    final label = plan == SubscriptionPlan.yearly ? 'Yearly' : 'Monthly';
    final until = expiry == null
        ? 'Active'
        : 'Renews ${expiry!.day}/${expiry!.month}/${expiry!.year}';

    return Container(
      padding: const EdgeInsets.all(Fp.s24),
      decoration: BoxDecoration(
        gradient: Fp.accent,
        borderRadius: BorderRadius.circular(Fp.rLg),
        boxShadow: Fp.glow(Fp.violet),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: Fp.s8),
              Text(
                'Premium member',
                style: Fp.bodyStrong.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: Fp.s12),
          Text('$label plan', style: Fp.h1.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            until,
            style: Fp.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = <(IconData, String, String)>[
      (Icons.bolt_outlined, 'No limits', 'Bigger uploads and longer media.'),
      (Icons.videocam_outlined, 'Richer calls', 'Higher quality group calls.'),
      (Icons.shield_outlined, 'Priority support', 'A human answers faster.'),
    ];

    return FpSurface(
      padding: const EdgeInsets.symmetric(vertical: Fp.s8),
      radius: Fp.rMd,
      child: Column(
        children: [
          for (final (icon, title, body) in items)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Fp.s16,
                vertical: Fp.s12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Fp.violet.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(Fp.rSm),
                    ),
                    child: Icon(icon, size: 18, color: Fp.violetGlow),
                  ),
                  const SizedBox(width: Fp.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Fp.bodyStrong),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: Fp.caption.copyWith(color: Fp.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
