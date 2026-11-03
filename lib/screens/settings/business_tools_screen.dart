import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart'
    as usernamecheck;
import 'package:whoxa/featuers/auth/provider/business_profile_provider.dart';
import 'package:whoxa/featuers/chat/screens/label_management_screen.dart';
import 'package:whoxa/featuers/profile/screens/auto_replies_screen.dart';
import 'package:whoxa/featuers/profile/screens/business_dashboard_screen.dart';
import 'package:whoxa/featuers/profile/screens/edit_business_profile_screen.dart';
import 'package:whoxa/featuers/profile/screens/manage_catalog_screen.dart';
import 'package:whoxa/featuers/profile/screens/my_business_profile_screen.dart';

/// Hub for the business-only features, rebuilt on the Flickpitch design
/// system: business profile, catalog, labels, auto-replies, dashboard and
/// social links.
class BusinessToolsScreen extends StatelessWidget {
  const BusinessToolsScreen({super.key});

  Future<void> _openSocialLinks(BuildContext context) async {
    usernamecheck.UserNameCheckModel? record;
    try {
      record = await context
          .read<BusinessProfileProvider>()
          .loadOwnBusinessRecord();
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditBusinessProfileScreen(
          scrollToSection: 'socialMedia',
          userProfile: record,
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FpCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Fp.s20, Fp.s12, Fp.s20, Fp.s40),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: Fp.s4),
                Expanded(child: Text('Business tools', style: Fp.display)),
              ],
            ),
            const SizedBox(height: Fp.s8),
            Text(
              'Everything customers see, and everything that answers them '
              'while you are busy.',
              style: Fp.body.copyWith(color: Fp.textMuted),
            ),
            const SizedBox(height: Fp.s20),

            // Hero: business profile
            FpSurface(
              accentRail: Fp.violet,
              onTap: () => _push(context, const MyBusinessProfileScreen()),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Fp.rSm),
                      gradient: LinearGradient(
                        colors: [
                          Fp.violet.withValues(alpha: 0.9),
                          Fp.violetDeep.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset(
                        AppAssets.businessAssets.businessTool,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                        // A missing asset must never take the whole hub down.
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Fp.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your business profile', style: Fp.bodyStrong),
                        const SizedBox(height: 3),
                        Text(
                          'Name, hours, location, links and logo',
                          style: Fp.caption.copyWith(color: Fp.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Fp.textFaint),
                ],
              ),
            ),

            const SizedBox(height: Fp.s24),
            const FpSectionLabel('Manage'),
            const SizedBox(height: Fp.s12),

            FpSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ToolRow(
                    title: 'Catalog',
                    subtitle: 'Products, photos and prices',
                    asset: 'assets/images/business-tools/catalouge_tile.svg',
                    tint: Fp.cyan,
                    onTap: () => _push(context, const ManageCatalogScreen()),
                  ),
                  _ToolRow(
                    title: 'Labels',
                    subtitle: 'Organise chats into New order, Paid, Follow-up',
                    asset: 'assets/images/business-tools/labletile.svg',
                    tint: Fp.amber,
                    onTap: () => _push(context, const LabelManagementScreen()),
                  ),
                  _ToolRow(
                    title: 'Greeting & away messages',
                    subtitle: 'Automatic replies sent for you',
                    asset: 'assets/images/business-tools/greetingtile.svg',
                    tint: Fp.mint,
                    onTap: () => _push(context, const AutoRepliesScreen()),
                  ),
                  _ToolRow(
                    title: 'Dashboard',
                    subtitle: 'Chats, messages and top labels',
                    asset:
                        'assets/images/business-tools/tool_performance_status.svg',
                    tint: Fp.violet,
                    onTap: () => _push(context, const BusinessDashboardScreen()),
                  ),
                  _ToolRow(
                    title: 'Social media links',
                    subtitle: 'Facebook, Instagram, LinkedIn, YouTube, VK',
                    asset: 'assets/images/business-tools/sociallinks.svg',
                    tint: Fp.coral,
                    divider: false,
                    onTap: () => _openSocialLinks(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Fp.s20),
            Text(
              'Tip: a complete profile with a catalog gets replies faster — '
              'customers stop asking for prices.',
              style: Fp.caption.copyWith(color: Fp.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tool row that keeps the original business SVG artwork, restyled with the
/// Flickpitch tokens (accent tile, hairline divider, chevron).
class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.tint,
    this.onTap,
    this.divider = true,
  });

  final String title;
  final String subtitle;
  final String asset;
  final Color tint;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Fp.s16,
                vertical: Fp.s12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(Fp.rSm),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: SvgPicture.asset(
                        asset,
                        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.circle_outlined, color: tint, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: Fp.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Fp.bodyStrong),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: Fp.caption.copyWith(color: Fp.textMuted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Fp.textFaint),
                ],
              ),
            ),
            if (divider)
              Padding(
                padding: const EdgeInsets.only(left: 72),
                child: Container(height: 1, color: Fp.hairline),
              ),
          ],
        ),
      ),
    );
  }
}
