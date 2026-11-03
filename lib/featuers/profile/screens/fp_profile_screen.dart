import 'package:flutter/material.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';

/// Redesigned profile surface.
///
/// Structure differs from the stock profile:
///   * a gradient cover band with the avatar overlapping it, instead of a
///     centred avatar above a form,
///   * read-only identity summary (name / email / phone) with explicit
///     "edit" entry points, rather than editable fields mixed into the page,
///   * quick-action tiles for photo, info, status, subscription and theme,
///   * first-class loading / error / offline states.
///
/// Edits still flow through the existing, working routes (avatar picker,
/// add-info, bio, subscription, theme) so behaviour is unchanged.
class FpProfileScreen extends StatefulWidget {
  const FpProfileScreen({super.key});

  @override
  State<FpProfileScreen> createState() => _FpProfileScreenState();
}

class _FpProfileScreenState extends State<FpProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.hasLoadedOnce) auth.userProfileApiGet(context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // theme dependency: rebuild this screen when the theme changes
    // so the static Fp tokens are re-read (they are not InheritedWidgets).
    context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final first = auth.fNameController.text.trim();
    final last = auth.lNameController.text.trim();
    final fullName = '$first $last'.trim();
    final display = fullName.isEmpty ? 'Your profile' : fullName;
    final email = auth.emailcontroller.text.trim();
    final phone = auth.mobilecontroller.text.trim();

    final loading = auth.isGetProfile && !auth.hasLoadedOnce;

    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        child: loading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Fp.violetGlow),
                ),
              )
            : RefreshIndicator(
                color: Fp.violet,
                backgroundColor: Fp.inkRaised,
                onRefresh: () => auth.userProfileApiGet(context: context),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Fp.s16, Fp.s8, Fp.s16, 120),
                  children: [
                    _HeaderBar(),
                    const SizedBox(height: Fp.s12),
                    _IdentityCard(
                      display: display,
                      email: email,
                      phone: phone,
                      imageUrl: auth.profileImageUrl,
                    ),
                    if (auth.errorMessage != null &&
                        auth.errorMessage!.trim().isNotEmpty) ...[
                      const SizedBox(height: Fp.s16),
                      _ErrorNote(
                        message: auth.isInternetIssue
                            ? 'You appear to be offline — showing saved details.'
                            : auth.errorMessage!,
                        onRetry: () => auth.userProfileApiGet(context: context),
                      ),
                    ],
                    const SizedBox(height: Fp.s24),
                    _QuickActions(),
                    const SizedBox(height: Fp.s24),
                    _Section(
                      label: 'Account',
                      children: [
                        FpListRow(
                          title: 'Email',
                          subtitle: email.isEmpty ? 'Not set' : email,
                          icon: Icons.alternate_email,
                          iconTint: Fp.cyan,
                          divider: true,
                          onTap: () => Navigator.pushNamed(
                              context, AppRoutes.addinfo),
                        ),
                        FpListRow(
                          title: 'Phone',
                          subtitle: phone.isEmpty ? 'Not set' : phone,
                          icon: Icons.smartphone_outlined,
                          iconTint: Fp.mint,
                          divider: false,
                          onTap: () => Navigator.pushNamed(
                              context, AppRoutes.addinfo),
                        ),
                      ],
                    ),
                    const SizedBox(height: Fp.s24),
                    _Section(
                      label: 'Membership',
                      children: [
                        FpListRow(
                          title: 'Subscription',
                          subtitle: 'Plans, billing and history',
                          icon: Icons.workspace_premium_outlined,
                          iconTint: Fp.amber,
                          divider: false,
                          onTap: () => Navigator.pushNamed(
                              context, AppRoutes.subscription),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FpIconTile(
          icon: Icons.arrow_back,
          size: 40,
          onTap: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: Fp.s12),
        Text('Profile', style: Fp.h2),
        const Spacer(),
        FpIconTile(
          icon: Icons.settings_outlined,
          size: 40,
          onTap: () => Navigator.maybePop(context),
        ),
      ],
    );
  }
}

/// Gradient cover + overlapping avatar + identity lines.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.display,
    required this.email,
    required this.phone,
    required this.imageUrl,
  });

  final String display;
  final String email;
  final String phone;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 132,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A1157), Color(0xFF4B1E9E), Color(0xFF0A1F2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(Fp.rLg),
            border: Border.all(color: Fp.hairline),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -42),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Fp.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Fp.violet.withValues(alpha: 0.5)),
                  boxShadow: Fp.glow(Fp.violetDeep),
                ),
                child: FpAvatar(
                  imageUrl: imageUrl,
                  label: display,
                  size: 92,
                ),
              ),
              const SizedBox(height: Fp.s12),
              Text(display, style: Fp.h1, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                email.isNotEmpty ? email : (phone.isNotEmpty ? phone : 'Add your details'),
                style: Fp.caption.copyWith(color: Fp.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Photo / info / status shortcuts.
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = <(String, IconData, Color, String)>[
      ('Photo', Icons.photo_camera_outlined, Fp.violet, AppRoutes.avatarProfile),
      ('Info', Icons.badge_outlined, Fp.cyan, AppRoutes.addinfo),
      ('Status', Icons.bolt_outlined, Fp.amber, AppRoutes.bio),
      ('Theme', Icons.palette_outlined, Fp.mint, AppRoutes.themeColorPicker),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: Fp.s8),
          Expanded(
            child: FpSurface(
              padding: const EdgeInsets.symmetric(vertical: Fp.s16),
              radius: Fp.rMd,
              onTap: () =>
                  Navigator.pushNamed(context, items[i].$4),
              child: Column(
                children: [
                  Icon(items[i].$2, size: 20, color: items[i].$3),
                  const SizedBox(height: 6),
                  Text(items[i].$1,
                      style: Fp.caption.copyWith(color: Fp.text)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Fp.s8, bottom: Fp.s8),
          child: Text(label.toUpperCase(),
              style: Fp.label.copyWith(color: Fp.textFaint)),
        ),
        FpSurface(
          padding: EdgeInsets.zero,
          radius: Fp.rMd,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Fp.s16),
      decoration: BoxDecoration(
        color: Fp.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Fp.rMd),
        border: Border.all(color: Fp.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Fp.amber),
          const SizedBox(width: Fp.s12),
          Expanded(
            child: Text(message,
                style: Fp.caption.copyWith(color: Fp.text)),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry',
                style: Fp.caption.copyWith(color: Fp.violetGlow)),
          ),
        ],
      ),
    );
  }
}
