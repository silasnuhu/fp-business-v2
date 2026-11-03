import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

/// Dedicated notification-permission step.
///
/// Previously this decision was buried inside the onboarding carousel (the
/// provider fired a system dialog from a slide button), which meant users hit an
/// OS prompt with no context. This screen gives the decision its own space, one
/// clear primary action, and an explicit decline path that never blocks entry.
class FpPermissionScreen extends StatefulWidget {
  const FpPermissionScreen({super.key});

  @override
  State<FpPermissionScreen> createState() => _FpPermissionScreenState();
}

class _FpPermissionScreenState extends State<FpPermissionScreen>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // Mark onboarding as seen so splash does not loop back here on next launch.
    await SecurePrefs.setBool(SecureStorageKeys.PERMISSION, true);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.sigingMethod,
      (route) => false,
    );
  }

  Future<void> _request() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final status = await Permission.notification.request();
      if (!mounted) return;
      if (status.isPermanentlyDenied) {
        setState(() => _busy = false);
        await _showBlockedSheet();
        return;
      }
    } catch (_) {
      // A denial or platform error must never trap the user here.
    }
    await _finish();
  }

  Future<void> _showBlockedSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(Fp.s12),
        padding: const EdgeInsets.all(Fp.s24),
        decoration: BoxDecoration(
          color: Fp.inkSoft,
          borderRadius: BorderRadius.circular(Fp.rLg),
          border: Border.all(color: Fp.hairlineStrong),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifications are blocked', style: Fp.h2),
            const SizedBox(height: Fp.s8),
            Text(
              'You turned this off at the system level. You can re-enable it in Settings at any time — chats still work without it.',
              style: Fp.body.copyWith(color: Fp.textMuted),
            ),
            const SizedBox(height: Fp.s20),
            FpPrimaryButton(
              label: 'Open settings',
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
            ),
            const SizedBox(height: Fp.s8),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _finish();
                },
                child: Text('Continue without notifications',
                    style: Fp.caption.copyWith(color: Fp.textMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // theme dependency: rebuild this screen when the theme changes
    // so the static Fp tokens are re-read (they are not InheritedWidgets).
    context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        padding: const EdgeInsets.symmetric(horizontal: Fp.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Fp.s16),
            Row(
              children: [
                _StepChip(label: 'STEP 3 OF 3'),
                const Spacer(),
                TextButton(
                  onPressed: _busy ? null : _finish,
                  child: Text('Not now',
                      style: Fp.bodyStrong.copyWith(color: Fp.textMuted)),
                ),
              ],
            ),
            const Spacer(),
            Center(child: _Bell(pulse: _pulse)),
            const Spacer(),
            Text('Never miss\na message', style: Fp.display),
            const SizedBox(height: Fp.s12),
            Text(
              'Flickpitch uses notifications for new messages, incoming calls and voice notes. Nothing promotional — ever.',
              style: Fp.body.copyWith(color: Fp.textMuted),
            ),
            const SizedBox(height: Fp.s24),
            const _Benefit(
              icon: Icons.chat_bubble_outline,
              title: 'Messages the moment they arrive',
              body: 'No refresh, no waiting for the next open.',
            ),
            const _Benefit(
              icon: Icons.phone_in_talk_outlined,
              title: 'Calls that actually ring',
              body: 'Incoming calls reach you even when the app is closed.',
            ),
            const _Benefit(
              icon: Icons.tune,
              title: 'You stay in control',
              body: 'Per-chat mute and quiet hours, any time.',
            ),
            const Spacer(),
            FpPrimaryButton(
              label: 'Turn on notifications',
              icon: Icons.notifications_active_outlined,
              loading: _busy,
              onPressed: _request,
            ),
            const SizedBox(height: Fp.s12),
            FpGhostButton(
              label: 'Maybe later',
              onPressed: _busy ? null : _finish,
            ),
            const SizedBox(height: Fp.s12),
            Center(
              child: Text(
                'You can change this later in Settings › Notifications',
                textAlign: TextAlign.center,
                style: Fp.caption.copyWith(color: Fp.textFaint),
              ),
            ),
            const SizedBox(height: Fp.s16),
          ],
        ),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Fp.s12, vertical: 6),
      decoration: BoxDecoration(
        color: Fp.violet.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(Fp.rPill),
        border: Border.all(color: Fp.violet.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: Fp.label.copyWith(color: Fp.violetGlow)),
    );
  }
}

/// Pulsing bell with concentric rings — the screen's single focal point.
class _Bell extends StatelessWidget {
  const _Bell({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final (base, alpha) in [(240.0, 0.05), (186.0, 0.09), (136.0, 0.14)])
                Container(
                  width: base + (base * 0.04 * t),
                  height: base + (base * 0.04 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Fp.violet.withValues(alpha: alpha),
                    border: Border.all(color: Fp.hairline),
                  ),
                ),
              Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  gradient: Fp.accent,
                  shape: BoxShape.circle,
                  boxShadow: Fp.glow(Fp.violet),
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    size: 40, color: Colors.white),
              ),
              Positioned(
                top: 26,
                right: 58,
                child: Opacity(
                  opacity: 0.5 + (0.5 * t),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Fp.coral,
                      shape: BoxShape.circle,
                      border: Border.all(color: Fp.ink, width: 2.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Fp.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Fp.inkRaised.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(Fp.rSm),
              border: Border.all(color: Fp.hairline),
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
                Text(body, style: Fp.caption.copyWith(color: Fp.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
