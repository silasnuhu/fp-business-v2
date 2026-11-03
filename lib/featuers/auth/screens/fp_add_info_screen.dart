import 'package:flutter/material.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';

/// Redesigned profile-completion step (post-OTP for new accounts).
///
/// Structure differs from the stock form: a single conversational column with
/// three grouped fields, a username row with its own availability affordance,
/// and a sticky bottom action instead of a long scrolling form.
///
/// It writes the same `AuthProvider` controllers (`fNameController`,
/// `lNameController`, `userNameController`) and submits through
/// `userProfileApi(context)`, so persistence and validation are unchanged.
class FpAddInfoScreen extends StatefulWidget {
  const FpAddInfoScreen({super.key});

  @override
  State<FpAddInfoScreen> createState() => _FpAddInfoScreenState();
}

class _FpAddInfoScreenState extends State<FpAddInfoScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final first = auth.fNameController.text.trim();
    final user = auth.userNameController.text.trim();

    if (first.isEmpty) {
      setState(() => _error = 'Your first name is required.');
      return;
    }
    if (user.isEmpty) {
      setState(() => _error = 'Pick a username so people can find you.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await auth.userProfileApi(context);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.tabbar,
        (route) => false,
      );
    } else {
      setState(
        () => _error = auth.errorMessage?.trim().isNotEmpty == true
            ? auth.errorMessage
            : 'We could not save your profile. Please try again.',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Fp.s16),
            Text(
              'ONE LAST THING',
              style: Fp.label.copyWith(color: Fp.violetGlow),
            ),
            const SizedBox(height: Fp.s8),
            Text('Who should\npeople see?', style: Fp.display),
            const SizedBox(height: Fp.s12),
            Text(
              'This is how you appear in chats and calls. You can change it later in Settings.',
              style: Fp.body.copyWith(color: Fp.textMuted),
            ),
            const SizedBox(height: Fp.s32),
            Expanded(
              child: ListView(
                children: [
                  _Field(
                    label: 'First name',
                    hint: 'Ada',
                    controller: auth.fNameController,
                    icon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: Fp.s20),
                  _Field(
                    label: 'Last name',
                    hint: 'Okafor',
                    controller: auth.lNameController,
                    icon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: Fp.s20),
                  _Field(
                    label: 'Username',
                    hint: 'ada',
                    controller: auth.userNameController,
                    icon: Icons.alternate_email,
                    prefix: '@',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Fp.s20),
                    Container(
                      padding: const EdgeInsets.all(Fp.s16),
                      decoration: BoxDecoration(
                        color: Fp.coral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Fp.rMd),
                        border: Border.all(
                          color: Fp.coral.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: Fp.coral,
                          ),
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
                ],
              ),
            ),
            const SizedBox(height: Fp.s16),
            FpPrimaryButton(
              label: 'Start chatting',
              icon: Icons.arrow_forward,
              loading: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: Fp.s16),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.prefix,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final String? prefix;
  final TextCapitalization textCapitalization;

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
              if (prefix != null) ...[
                Text(
                  prefix!,
                  style: Fp.bodyStrong.copyWith(color: Fp.textMuted),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: textCapitalization,
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
