import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/provider/tabbar_provider.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

/// Redesigned one-time-code screen.
///
/// Structure differs from the stock OTP page (which used pin widgets inside a
/// card): a full-height aurora page, the destination shown as a pill you can go
/// back and edit, a single large code field, and resend treated as a secondary
/// action with a live countdown.
///
/// Behaviour matches the stock screen exactly:
///   * verification calls `otpVerifyApi(context, ...)` with the same arguments,
///   * resend re-runs the same login call that issued the code,
///   * on success: no first name on file → `/addinfo`, otherwise `/tabbar`
///     with the tab bar reset to index 0.
class FpOtpScreen extends StatefulWidget {
  const FpOtpScreen({super.key});

  @override
  State<FpOtpScreen> createState() => _FpOtpScreenState();
}

class _FpOtpScreenState extends State<FpOtpScreen> {
  final TextEditingController _otp = TextEditingController();
  Timer? _timer;
  int _seconds = 60;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    // Reuse the provider's controller so anything the stock flow wrote survives.
    _otp.text = auth.otpController.text;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _seconds = _seconds > 0 ? _seconds - 1 : 0);
      if (_seconds == 0) t.cancel();
    });
  }

  bool get _isPhone =>
      context.read<AuthProvider>().isSelectLoginType == AppString.phone;

  String _destination(AuthProvider auth) => _isPhone
      ? '${auth.selectedCountrycode} ${auth.mobilecontroller.text}'
      : auth.emailcontroller.text;

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    setState(() => _error = null);
    if (_isPhone) {
      await auth.loginMobileApi(
        context,
        countryCode: auth.selectedCountrycode,
        phoneNumber: auth.mobilecontroller.text,
        countryFullName: auth.defaultSelectedCountry,
        selectedCountrySortName: auth.defaultCountrySortName,
      );
    } else {
      await auth.loginApi(context, auth.emailcontroller.text);
    }
    if (!mounted) return;
    _startTimer();
  }

  Future<void> _verify() async {
    if (_busy) return;
    final code = _otp.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the full code from your message.');
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.otpController.text = code;
    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await auth.otpVerifyApi(
      context,
      countryCode: auth.selectedCountrycode,
      phoneNumber: auth.mobilecontroller.text,
      isEmail: !_isPhone,
      email: auth.emailcontroller.text,
      otp: code,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      setState(
        () => _error = auth.errorMessage?.trim().isNotEmpty == true
            ? auth.errorMessage
            : 'That code did not work. Try again.',
      );
      return;
    }

    final firstName =
        await SecurePrefs.getString(SecureStorageKeys.FIRST_NAME) ?? '';
    if (!mounted) return;

    if (firstName.trim().isEmpty) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.addinfo,
        (route) => false,
      );
      return;
    }

    context.read<TabbarProvider>().navigateToIndex(0);
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.tabbar,
      (route) => false,
    );
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
            const SizedBox(height: Fp.s16),
            Align(
              alignment: Alignment.centerLeft,
              child: FpIconTile(
                icon: Icons.arrow_back,
                size: 40,
                onTap: () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(height: Fp.s32),
            Text('Almost in', style: Fp.display),
            const SizedBox(height: Fp.s12),
            Text(
              'We sent a one-time code to',
              style: Fp.body.copyWith(color: Fp.textMuted),
            ),
            const SizedBox(height: Fp.s12),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Fp.s16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Fp.violet.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Fp.rPill),
                  border: Border.all(color: Fp.violet.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPhone
                          ? Icons.smartphone_outlined
                          : Icons.alternate_email,
                      size: 16,
                      color: Fp.violetGlow,
                    ),
                    const SizedBox(width: Fp.s8),
                    Text(
                      _destination(auth),
                      style: Fp.bodyStrong.copyWith(color: Fp.text),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Fp.s32),

            Text('CODE', style: Fp.label.copyWith(color: Fp.textFaint)),
            const SizedBox(height: Fp.s8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Fp.s16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Fp.hairlineStrong),
              ),
              child: TextField(
                controller: _otp,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: Fp.h1.copyWith(letterSpacing: 14),
                cursorColor: Fp.violet,
                onChanged: (v) {
                  if (v.length >= 4) setState(() => _error = null);
                },
                onSubmitted: (_) => _verify(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: '········',
                  hintStyle: Fp.h1.copyWith(
                    letterSpacing: 12,
                    color: Fp.textFaint,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
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
              label: 'Verify',
              icon: Icons.verified_outlined,
              loading: _busy,
              onPressed: _verify,
            ),
            const SizedBox(height: Fp.s16),
            Center(
              child: _seconds > 0
                  ? Text(
                      'Resend code in ${_seconds}s',
                      style: Fp.caption.copyWith(color: Fp.textFaint),
                    )
                  : TextButton(
                      onPressed: _resend,
                      child: Text(
                        'Resend code',
                        style: Fp.bodyStrong.copyWith(color: Fp.violetGlow),
                      ),
                    ),
            ),
            const SizedBox(height: Fp.s32),
          ],
        ),
      ),
    );
  }
}
