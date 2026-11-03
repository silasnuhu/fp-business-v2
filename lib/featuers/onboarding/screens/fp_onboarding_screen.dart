import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';

/// Flickpitch onboarding — rebuilt from scratch.
///
/// Structure is intentionally different from the stock template:
///   * a full-bleed art stage on top (no hero image slot, no carousel),
///   * a bottom sheet panel that slides between steps,
///   * a segmented rail instead of dot indicators,
///   * each step has its own layout, not one shared "image + text" page.
///
/// Permission prompting no longer lives inside this flow — it has its own
/// screen (FpPermissionScreen) so users get one decision per screen.
class FpOnboardingScreen extends StatefulWidget {
  const FpOnboardingScreen({super.key});

  @override
  State<FpOnboardingScreen> createState() => _FpOnboardingScreenState();
}

class _FpOnboardingScreenState extends State<FpOnboardingScreen> {
  int _step = 0;
  static const int _count = 3;

  bool get _isLast => _step == _count - 1;

  void _next() {
    if (_isLast) {
      Navigator.pushReplacementNamed(context, AppRoutes.notificationPermission);
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  void _skip() {
    Navigator.pushReplacementNamed(context, AppRoutes.notificationPermission);
  }

  @override
  Widget build(BuildContext context) {
    // theme dependency: rebuild this screen when the theme changes
    // so the static Fp tokens are re-read (they are not InheritedWidgets).
    context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        child: Column(
          children: [
            _topBar(),
            Expanded(flex: 5, child: _Stage(step: _step)),
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Fp.inkSoft.withValues(alpha: 0.94),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Fp.rXl),
                  ),
                  border: Border(
                    top: BorderSide(color: Fp.hairline),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                      Fp.s24, Fp.s24, Fp.s24, Fp.s20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FpStepRail(count: _count, index: _step),
                      const SizedBox(height: Fp.s24),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.32,
                        ),
                        child: AnimatedSwitcher(
                          duration: Fp.base,
                          switchInCurve: Fp.ease,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(_step),
                            child: _Copy(step: _step),
                          ),
                        ),
                      ),
                      const SizedBox(height: Fp.s16),
                      FpPrimaryButton(
                        label: _isLast ? 'Get started' : 'Continue',
                        icon: _isLast ? Icons.arrow_forward : null,
                        onPressed: _next,
                      ),
                      const SizedBox(height: Fp.s12),
                      Row(
                        children: [
                          if (_step > 0)
                            _TextAction(
                              label: 'Back',
                              onTap: _back,
                              muted: true,
                            ),
                          const Spacer(),
                          Text('${_step + 1} of $_count',
                              style: Fp.caption.copyWith(color: Fp.textFaint)),
                        ],
                      ),
                    ],
                  ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Fp.s24, Fp.s8, Fp.s16, 0),
      child: Row(
        children: [
          _BrandMark(),
          const Spacer(),
          _TextAction(label: 'Skip', onTap: _skip),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: Fp.accent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Center(
            child: Text(
              'FP',
              style: TextStyle(
                fontFamily: 'PoppinsBold',
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: Fp.s12),
        Text('FLICKPITCH',
            style: Fp.label.copyWith(color: Fp.textMuted, letterSpacing: 2.4)),
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, this.onTap, this.muted = false});
  final String label;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Fp.rPill),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Fp.s12, vertical: Fp.s8),
        child: Text(
          label,
          style: Fp.bodyStrong.copyWith(
            color: muted ? Fp.textMuted : Fp.violetGlow,
          ),
        ),
      ),
    );
  }
}

/// Art stage: a different composition per step.
class _Stage extends StatelessWidget {
  const _Stage({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Fp.base,
      child: KeyedSubtree(
        key: ValueKey(step),
        child: switch (step) {
          0 => _ChatPreview(),
          1 => _PrivacyShield(),
          _ => _PeopleCluster(),
        },
      ),
    );
  }
}

/// Step 1 — a tilted pair of message bubbles, brand-gradient, floating.
class _ChatPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: -0.06,
          child: Transform.translate(
            offset: const Offset(-34, -18),
            child: _Bubble(
              width: 210,
              alignment: Alignment.centerLeft,
              gradient: false,
              child: Text(
                'Hey! Did the new design land yet? 👀',
                style: Fp.body.copyWith(color: Fp.text),
              ),
            ),
          ),
        ),
        Transform.rotate(
          angle: 0.05,
          child: Transform.translate(
            offset: const Offset(38, 46),
            child: _Bubble(
              width: 200,
              alignment: Alignment.centerLeft,
              gradient: true,
              child: Text(
                'Everything, top to bottom.',
                style: Fp.body.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.width,
    required this.alignment,
    required this.gradient,
    required this.child,
  });

  final double width;
  final Alignment alignment;
  final bool gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
          horizontal: Fp.s16, vertical: Fp.s12),
      decoration: BoxDecoration(
        gradient: gradient ? Fp.accent : null,
        color: gradient ? null : Fp.inkRaised.withValues(alpha: 0.9),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(Fp.rMd),
          topRight: const Radius.circular(Fp.rMd),
          bottomLeft: Radius.circular(gradient ? Fp.rMd : 6),
          bottomRight: Radius.circular(gradient ? 6 : Fp.rMd),
        ),
        border: gradient ? null : Border.all(color: Fp.hairline),
        boxShadow: gradient ? Fp.glow(Fp.violet) : Fp.lift,
      ),
      child: child,
    );
  }
}

/// Step 2 — concentric rings signalling privacy/lock.
class _PrivacyShield extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final (size, alpha) in [(240.0, 0.06), (180.0, 0.10), (124.0, 0.16)])
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Fp.violet.withValues(alpha: alpha),
                  border: Border.all(color: Fp.hairline),
                ),
              ),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: Fp.accent,
                shape: BoxShape.circle,
                boxShadow: Fp.glow(Fp.violet),
              ),
              child: const Icon(Icons.lock_outline,
                  color: Colors.white, size: 36),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 3 — overlapping avatar cluster.
class _PeopleCluster extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rings = [Fp.violet, Fp.cyan, Fp.mint, Fp.amber];
    return Center(
      child: SizedBox(
        width: 250,
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 5; i++)
              Positioned(
                left: 12.0 + i * 46,
                top: i.isEven ? 8 : 44,
                child: FpAvatar(
                  label: ['Ada', 'Bola', 'Chidi', 'Dami', 'Efe'][i],
                  size: i == 2 ? 78 : 62,
                  ring: rings[i % rings.length],
                ),
              ),
            const Positioned(
              bottom: 0,
              child: _Pill(text: '+ 3 more online now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Fp.s16, vertical: Fp.s8),
      decoration: BoxDecoration(
        color: Fp.inkRaised.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(Fp.rPill),
        border: Border.all(color: Fp.hairlineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                const BoxDecoration(color: Fp.mint, shape: BoxShape.circle),
          ),
          const SizedBox(width: Fp.s8),
          Text(text, style: Fp.caption.copyWith(color: Fp.text)),
        ],
      ),
    );
  }
}

/// Copy per step. Each step is allowed a different shape of content.
class _Copy extends StatelessWidget {
  const _Copy({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case 0:
        return _basic(
          eyebrow: 'MESSAGING WITHOUT THE NOISE',
          title: 'Talk easy.\nStay close.',
          body:
              'Fast, calm conversations with the people who matter. No feeds, no ads, no algorithm deciding who you speak to.',
        );
      case 1:
        return _basic(
          eyebrow: 'PRIVATE BY DESIGN',
          title: 'Your chats are\nyours alone.',
          body:
              'Messages are encrypted in transit, media stays yours, and nothing is sold. You decide what is saved and what disappears.',
          points: const [
            ('End-to-end encrypted transport', Icons.shield_outlined),
            ('No ad tracking, ever', Icons.visibility_off_outlined),
            ('Delete for everyone, instantly', Icons.delete_outline),
          ],
        );
      default:
        return _basic(
          eyebrow: 'ONE PLACE FOR YOUR PEOPLE',
          title: 'Calls, chats,\ncircles.',
          body:
              'Group chats, voice notes, stories and calls — built into one clean flow instead of scattered across five apps.',
        );
    }
  }

  Widget _basic({
    required String eyebrow,
    required String title,
    required String body,
    List<(String, IconData)> points = const [],
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: Fp.label.copyWith(color: Fp.violetGlow)),
          const SizedBox(height: Fp.s12),
          Text(title, style: Fp.display),
          const SizedBox(height: Fp.s12),
          Text(body, style: Fp.body.copyWith(color: Fp.textMuted)),
          if (points.isNotEmpty) ...[
            const SizedBox(height: Fp.s20),
            for (final (label, icon) in points)
              Padding(
                padding: const EdgeInsets.only(bottom: Fp.s12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Fp.violet.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(Fp.rSm),
                      ),
                      child: Icon(icon, size: 16, color: Fp.violetGlow),
                    ),
                    const SizedBox(width: Fp.s12),
                    Expanded(
                      child: Text(label,
                          style: Fp.body.copyWith(color: Fp.text)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
