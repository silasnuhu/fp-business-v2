import 'package:flutter/material.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

/// Redesigned sign-in surface.
///
/// Structure differs from the stock login:
///   * a single focused column (brand, headline, one field, one action) rather
///     than a scrollable form with decorative dividers,
///   * email vs phone is a segmented switch whose field morphs in place,
///   * country data comes from `AuthProvider` itself (the same
///     `selectedCountrycode` / `defaultSelectedCountry` /
///     `defaultCountrySortName` the stock screen sends), so the mobile-login
///     API validates exactly as before,
///   * inline error banner with the provider's message, no snackbar-only errors.
class FpLoginScreen extends StatefulWidget {
  const FpLoginScreen({super.key});

  @override
  State<FpLoginScreen> createState() => _FpLoginScreenState();
}

class _FpLoginScreenState extends State<FpLoginScreen> {
  int _mode = 0; // 0 email, 1 phone
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    final auth = context.read<AuthProvider>();
    FocusScope.of(context).unfocus();

    final email = auth.emailcontroller.text.trim();
    final phone = auth.mobilecontroller.text.trim();

    if (_mode == 0 && email.isEmpty) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    if (_mode == 1 && phone.isEmpty) {
      setState(() => _error = 'Enter your phone number.');
      return;
    }
    if (_mode == 0 && !email.contains('@')) {
      setState(() => _error = 'That does not look like an email address.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    auth.isSelectLoginType = _mode == 0 ? AppString.email : AppString.phone;

    bool ok;
    if (_mode == 0) {
      ok = await auth.loginApi(context, email);
    } else {
      ok = await auth.loginMobileApi(
        context,
        countryCode: auth.selectedCountrycode,
        phoneNumber: phone,
        countryFullName: auth.defaultSelectedCountry,
        selectedCountrySortName: auth.defaultCountrySortName,
      );
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      Navigator.pushNamed(context, AppRoutes.otp);
    } else {
      setState(
        () => _error = auth.errorMessage?.trim().isNotEmpty == true
            ? auth.errorMessage
            : 'We could not reach Flickpitch. Check your connection and try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // theme dependency: rebuild this screen when the theme changes
    // so the static Fp tokens are re-read (they are not InheritedWidgets).
    context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        padding: const EdgeInsets.symmetric(horizontal: Fp.s24),
        child: ListView(
          children: [
            const SizedBox(height: Fp.s32),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: Fp.accent,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: Fp.glow(Fp.violet),
                  ),
                  child: const Center(
                    child: Text(
                      'FP',
                      style: TextStyle(
                        fontFamily: 'PoppinsBold',
                        fontSize: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Fp.s12),
                Text(
                  'FLICKPITCH',
                  style: Fp.label.copyWith(
                    color: Fp.textMuted,
                    letterSpacing: 2.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Fp.s40),
            Text('Welcome\nback.', style: Fp.display),
            const SizedBox(height: Fp.s12),
            Text(
              'Sign in to pick up where you left off. We will send a one-time code to confirm it is you.',
              style: Fp.body.copyWith(color: Fp.textMuted),
            ),
            const SizedBox(height: Fp.s32),

            _ModeSwitch(
              index: _mode,
              onChanged: (i) {
                // The OTP screen decides email-vs-phone verification from this
                // flag, so it must track the tab the user actually signs in with.
                context.read<AuthProvider>().isSelectLoginType = i == 0
                    ? AppString.email
                    : AppString.phone;
                setState(() {
                  _mode = i;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: Fp.s20),

            AnimatedSwitcher(
              duration: Fp.base,
              child: _mode == 0
                  ? _Field(
                      key: const ValueKey('email'),
                      label: 'Email address',
                      hint: 'you@example.com',
                      icon: Icons.alternate_email,
                      controller: auth.emailcontroller,
                      keyboard: TextInputType.emailAddress,
                      onSubmitted: _submit,
                    )
                  : _Field(
                      key: const ValueKey('phone'),
                      label: 'Phone number',
                      hint: '801 234 5678',
                      icon: Icons.smartphone_outlined,
                      controller: auth.mobilecontroller,
                      prefix: auth.selectedCountrycode,
                      keyboard: TextInputType.phone,
                      onSubmitted: _submit,
                    ),
            ),

            if (_error != null) ...[
              const SizedBox(height: Fp.s16),
              Container(
                padding: const EdgeInsets.all(Fp.s16),
                decoration: BoxDecoration(
                  color: Fp.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Fp.rMd),
                  border: Border.all(color: Fp.coral.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: Fp.coral),
                    const SizedBox(width: Fp.s12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: Fp.caption.copyWith(color: Fp.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: Fp.s24),
            FpPrimaryButton(
              label: 'Continue',
              icon: Icons.arrow_forward,
              loading: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: Fp.s16),
            Center(
              child: Text(
                'By continuing you agree to our Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: Fp.caption.copyWith(color: Fp.textFaint),
              ),
            ),
            const SizedBox(height: Fp.s32),
          ],
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Email', 'Phone'];
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
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: i == index ? Fp.accent : null,
                    borderRadius: BorderRadius.circular(Fp.rPill),
                  ),
                  child: Text(
                    labels[i],
                    style: Fp.bodyStrong.copyWith(
                      fontSize: 13.5,
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

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.keyboard,
    this.prefix,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboard;
  final String? prefix;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Fp.label.copyWith(color: Fp.textFaint),
        ),
        const SizedBox(height: Fp.s8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Fp.s16),
          decoration: BoxDecoration(
            // Flat: no grey pill fill, gentler radius, hairline outline.
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Fp.hairlineStrong),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: Fp.violetGlow),
              const SizedBox(width: Fp.s12),
              if (prefix != null && prefix!.isNotEmpty) ...[
                Text(prefix!, style: Fp.bodyStrong.copyWith(color: Fp.text)),
                const SizedBox(width: Fp.s8),
                Container(width: 1, height: 22, color: Fp.hairline),
                const SizedBox(width: Fp.s8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboard,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmitted?.call(),
                  style: Fp.body.copyWith(color: Fp.text),
                  cursorColor: Fp.violet,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    hintText: hint,
                    hintStyle: Fp.body.copyWith(color: Fp.textFaint),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
