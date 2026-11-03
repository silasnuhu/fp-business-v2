import 'package:flutter/material.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

/// Redesigned "sign in method" hand-off.
///
/// The stock screen was a centred logo above an outlined box with a long label
/// and a version footer. This version is an aurora screen with a brand lockup,
/// a single decisive action, and the version line treated as quiet metadata.
///
/// Behaviour is deliberately identical: it sets `isSelectLoginType` to the
/// phone/email option and pushes `/login`, which is what the rest of the auth
/// flow (and OTP) already expects.
class FpSigninMethodScreen extends StatelessWidget {
  const FpSigninMethodScreen({super.key});

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
            const Spacer(flex: 2),
            Image.asset(
              Fp.dark
                  ? 'assets/images/fp_lockup_on_dark.png'
                  : 'assets/images/fp_lockup.png',
              width: 232,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: Fp.s24),
            Text('Talk easy.', style: Fp.display),
            const SizedBox(height: Fp.s12),
            Text(
              'Private conversations, calls and voice notes — all in one calm place.',
              style: Fp.body.copyWith(color: Fp.textMuted),
            ),
            const Spacer(flex: 3),
            FpPrimaryButton(
              label: 'Continue',
              icon: Icons.arrow_forward,
              onPressed: () {
                Provider.of<AuthProvider>(context, listen: false)
                    .isSelectLoginType = AppString.phone;
                Navigator.pushNamed(context, AppRoutes.login);
              },
            ),
            const SizedBox(height: Fp.s12),
            Center(
              child: Text(
                'New here? Continuing creates your account.',
                style: Fp.caption.copyWith(color: Fp.textFaint),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Fp.s32),
            Center(
              child: Text(
                'Version $appVersion',
                style: Fp.caption.copyWith(color: Fp.textFaint, fontSize: 11),
              ),
            ),
            const SizedBox(height: Fp.s16),
          ],
        ),
      ),
    );
  }
}
