import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/subscription/screens/subscription_history_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/featuers/subscription/data/subscription_config.dart';
import 'package:whoxa/featuers/subscription/provider/subscription_provider.dart';
import 'package:whoxa/screens/settings/terms_policy.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';

/// Brand blue used only for the verification tick itself. Every other accent
/// (cards, badge, header, button) comes from the app's primary/secondary
/// theme colors.
const Color _kBlueTick = Color(0xFF1D9BF0);

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late final SubscriptionProvider _provider;
  int _lastEventSeq = 0;

  bool get _isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _provider = context.read<SubscriptionProvider>();
    _lastEventSeq = _provider.eventSeq;
    _provider.addListener(_onProviderChanged);
    if (_isSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _provider.initialize();
      });
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted || _provider.eventSeq == _lastEventSeq) return;
    _lastEventSeq = _provider.eventSeq;
    final message = _provider.eventMessage;
    if (message != null) {
      snackbarNew(
        context,
        msg: message,
        backgroundColor: _provider.eventIsError ? Colors.red : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          shape: Border(
            bottom: BorderSide(color: AppThemeManage.appTheme.borderColor),
          ),
          titleSpacing: 0,
          systemOverlayStyle: systemUI(),
          flexibleSpace: flexibleSpace(),
          leading: Padding(
            padding: SizeConfig.getPadding(12),
            child: customeBackArrowBalck(context),
          ),
          actions: [
            IconButton(
              tooltip: AppString.subscriptionStrings.subscriptionHistory,
              icon: Icon(
                Icons.history_rounded,
                color: AppThemeManage.appTheme.darkWhiteColor,
              ),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionHistoryScreen(),
                    ),
                  ),
            ),
          ],
          title: Text(
            AppString.subscriptionStrings.getVerified,
            style: AppTypography.h220(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: SafeArea(
        child:
            _isSupported
                ? Consumer<SubscriptionProvider>(
                  builder: (context, provider, _) => _buildBody(provider),
                )
                : _buildMessage(
                  icon: Icons.phone_android_rounded,
                  title: AppString.subscriptionStrings.notAvailableYet,
                  subtitle: AppString.subscriptionStrings.mobileOnly,
                ),
      ),
    );
  }

  Widget _buildBody(SubscriptionProvider provider) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(height: SizeConfig.height(0.5)),
                _buildHeader(),
                SizedBox(height: SizeConfig.height(2.5)),
                _buildBenefits(),
                SizedBox(height: SizeConfig.height(2)),
                _buildPlansArea(provider),
                SizedBox(height: SizeConfig.height(2)),
                _buildRenewalInfo(),
                SizedBox(height: SizeConfig.height(1)),
              ],
            ),
          ),
        ),
        _buildBottomBar(provider),
      ],
    );
  }

  // ── header ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          height: 76,
          width: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _kBlueTick.withValues(alpha: 0.28),
                _kBlueTick.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: _kBlueTick.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: _kBlueTick.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.verified_rounded, color: _kBlueTick, size: 46),
          ),
        ),
        SizedBox(height: SizeConfig.height(1.5)),
        Text(
          AppString.subscriptionStrings.becomeVerifiedTitle,
          textAlign: TextAlign.center,
          style: AppTypography.h2(context).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: SizeConfig.getFontSize(22),
            height: 1.25,
          ),
        ),
        SizedBox(height: SizeConfig.height(0.8)),
        Text(
          AppString.subscriptionStrings.becomeVerifiedSubtitle,
          textAlign: TextAlign.center,
          style: AppTypography.innerText12Mediu(context).copyWith(
            color: AppColors.textColor.textGreyColor,
            fontSize: SizeConfig.getFontSize(13),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ── benefits ───────────────────────────────────────────────────────────

  Widget _buildBenefits() {
    final benefits = <(IconData, String, String)>[
      (
        Icons.verified_rounded,
        AppString.subscriptionStrings.blueTick,
        AppString.subscriptionStrings.blueTickDesc,
      ),
      (
        Icons.block_rounded,
        AppString.subscriptionStrings.noAds,
        AppString.subscriptionStrings.noAdsDesc,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppThemeManage.appTheme.borderColor),
      ),
      child: Column(
        children: [
          for (var i = 0; i < benefits.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                color: AppThemeManage.appTheme.borderColor,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: _kBlueTick.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(benefits[i].$1, color: _kBlueTick, size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          benefits[i].$2,
                          style: AppTypography.innerText14(
                            context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          benefits[i].$3,
                          style: AppTypography.inputPlaceholderSmall(
                            context,
                          ).copyWith(
                            fontFamily: AppTypography.fontFamily.poppins,
                            color: AppColors.textColor.textGreyColor,
                            fontSize: SizeConfig.getFontSize(11),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── plans ──────────────────────────────────────────────────────────────

  Widget _buildPlansArea(SubscriptionProvider provider) {
    switch (provider.state) {
      case SubscriptionUiState.initial:
      case SubscriptionUiState.loadingProducts:
        return SizedBox(
          height: SizeConfig.height(18),
          child: Center(child: commonLoading()),
        );
      case SubscriptionUiState.productError:
        return _buildInlineMessage(
          icon: Icons.cloud_off_rounded,
          title: AppString.subscriptionStrings.loadPlansError,
          actionLabel: AppString.retry,
          onAction: provider.loadProducts,
        );
      case SubscriptionUiState.noProducts:
        return _buildInlineMessage(
          icon: Icons.inventory_2_outlined,
          title: AppString.subscriptionStrings.plansUnavailable,
          actionLabel: AppString.retry,
          onAction: provider.loadProducts,
        );
      default:
        break;
    }

    // Plans can be empty after e.g. a restore/purchase event on a failed load.
    if (provider.plans.isEmpty) {
      return _buildInlineMessage(
        icon: Icons.inventory_2_outlined,
        title: AppString.subscriptionStrings.plansUnavailable,
        actionLabel: AppString.retry,
        onAction: provider.loadProducts,
      );
    }

    return _buildPlanCards(provider);
  }

  Widget _buildPlanCards(SubscriptionProvider provider) {
    final savings = _yearlySavingsPercent(provider);
    final perMonth = _yearlyPerMonth(provider);
    // Monthly on the left, yearly (best value) on the right.
    final available =
        SubscriptionPlan.values
            .where((plan) => provider.plans.containsKey(plan))
            .toList();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < available.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: _PlanCard(
                plan: available[i],
                price: provider.plans[available[i]]!.formattedPrice,
                isSelected: provider.selectedPlan == available[i],
                enabled: !provider.isBusy && provider.canSelect(available[i]),
                currentLine:
                    provider.hasActiveSubscription &&
                            provider.activePlan == available[i]
                        ? _currentPlanLine(provider)
                        : null,
                perMonth:
                    available[i] == SubscriptionPlan.yearly ? perMonth : null,

                badge:
                    provider.hasActiveSubscription &&
                            provider.activePlan == available[i]
                        ? AppString.subscriptionStrings.currentPlan
                        : available[i] == SubscriptionPlan.yearly &&
                            savings != null
                        ? '${AppString.subscriptionStrings.bestValue} · ${AppString.subscriptionStrings.savePercent('$savings')}'
                        : null,
                onTap: () => provider.selectPlan(available[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Active • Renews Oct 8, 2026" (just "Active" without an expiry).
  String _currentPlanLine(SubscriptionProvider provider) {
    final expires = provider.premiumExpiresAt;
    if (expires == null) return AppString.subscriptionStrings.statusActive;
    return AppString.subscriptionStrings.activeRenews(
      DateFormat.yMMMd().format(expires.toLocal()),
    );
  }

  /// Savings are only shown when both prices come from the store in the
  /// same currency and the yearly plan really is cheaper per year.
  int? _yearlySavingsPercent(SubscriptionProvider provider) {
    final monthly = provider.plans[SubscriptionPlan.monthly];
    final yearly = provider.plans[SubscriptionPlan.yearly];
    if (monthly == null || yearly == null) return null;
    if (monthly.currencyCode != yearly.currencyCode) return null;
    if (monthly.rawPrice <= 0 || yearly.rawPrice <= 0) return null;

    final yearOfMonthly = monthly.rawPrice * 12;
    final saved = 1 - (yearly.rawPrice / yearOfMonthly);
    final percent = (saved * 100).floor();
    return percent >= 1 ? math.min(percent, 99) : null;
  }

  /// Yearly price divided by 12, formatted with the same currency symbol
  /// the store used for the yearly price (e.g. "₹400").
  String? _yearlyPerMonth(SubscriptionProvider provider) {
    final yearly = provider.plans[SubscriptionPlan.yearly];
    if (yearly == null || yearly.rawPrice <= 0) return null;

    final value = yearly.rawPrice / 12;
    final amount = value.toStringAsFixed(value >= 100 ? 0 : 2);
    final formatted = yearly.formattedPrice.trim();
    final symbol = formatted.replaceAll(RegExp(r'[0-9.,\s ]'), '');
    if (symbol.isEmpty) return amount;
    return formatted.startsWith(RegExp(r'[0-9]'))
        ? '$amount $symbol'
        : '$symbol$amount';
  }

  /// Cancelling is done in the store, never through our API.
  Future<void> _openManageSubscription(SubscriptionProvider provider) async {
    Uri url = Uri.parse('https://apps.apple.com/account/subscriptions');
    if (defaultTargetPlatform == TargetPlatform.android) {
      final package = (await PackageInfo.fromPlatform()).packageName;
      final plan = provider.activePlan ?? provider.selectedPlan;
      final sku =
          provider.activeProductId ?? SubscriptionConfig.productIdFor(plan);
      url = Uri.parse(
        'https://play.google.com/store/account/subscriptions'
        '?sku=$sku&package=$package',
      );
    }
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Subscription: could not open manage page: $e');
    }
  }

  // ── bottom bar (CTA + restore) ─────────────────────────────────────

  Widget _buildBottomBar(SubscriptionProvider provider) {
    final upgrade = provider.isUpgrade;
    final current = provider.selectedIsCurrent;
    final canSubscribe =
        (!provider.hasActiveSubscription || upgrade) &&
        provider.plans.isNotEmpty &&
        !provider.isLoadingProducts &&
        !provider.isBusy;
    final showCta =
        provider.plans.isNotEmpty &&
        (!provider.hasActiveSubscription || provider.activePlan != null);

    final ctaTextColor = ThemeColorPalette.getTextColor(
      AppColors.appPriSecColor.primaryColor,
    );

    // Two lines, e.g. "Unlock All Features" / "Subscribe - Yearly (₹4,800/year)".
    final selected = provider.plans[provider.selectedPlan];
    final isYearly = provider.selectedPlan == SubscriptionPlan.yearly;
    final period =
        isYearly
            ? AppString.subscriptionStrings.year
            : AppString.subscriptionStrings.month;
    final ctaSubtitle =
        selected == null || current
            ? null
            : upgrade
            ? '${selected.formattedPrice}/$period'
            : '${AppString.subscriptionStrings.subscribe} - '
                '${isYearly ? AppString.subscriptionStrings.yearly : AppString.subscriptionStrings.monthly} '
                '(${selected.formattedPrice}/$period)';

    return Container(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.scaffoldBackColor,
        border: Border(
          top: BorderSide(
            color: AppThemeManage.appTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCta)
            Opacity(
              opacity: canSubscribe || provider.isPurchasing ? 1 : 0.6,
              child: customBtn2(
                context,
                height: SizeConfig.sizedBoxHeight(56),
                onTap:
                    canSubscribe
                        ? () {
                          // Demo accounts must not buy a plan.
                          if (_blockDemo()) return;
                          provider.purchase();
                        }
                        : null,
                child:
                    provider.isPurchasing
                        ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ctaTextColor,
                            ),
                          ),
                        )
                        : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              current
                                  ? AppString
                                      .subscriptionStrings
                                      .currentPlanActive
                                  : upgrade
                                  ? AppString
                                      .subscriptionStrings
                                      .upgradeToYearly
                                  : AppString
                                      .subscriptionStrings
                                      .unlockAllFeatures,
                              style: AppTypography.h5(context).copyWith(
                                fontWeight: FontWeight.w700,
                                color: ctaTextColor,
                              ),
                            ),
                            if (ctaSubtitle != null)
                              Text(
                                ctaSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.innerText12Mediu(
                                  context,
                                ).copyWith(
                                  color: ctaTextColor.withValues(alpha: 0.85),
                                  fontSize: SizeConfig.getFontSize(12),
                                ),
                              ),
                          ],
                        ),
              ),
            ),
          SizedBox(height: SizeConfig.height(0.3)),
          _buildFooterActions(provider),
        ],
      ),
    );
  }

  /// Demo accounts cannot buy or restore a subscription: tells the user so
  /// and returns true when the action must stop.
  bool _blockDemo() {
    if (!isDemo) return false;
    snackbarNew(
      context,
      msg: AppString.demoAccountsCannotPurchaseASubscription,
    );
    return true;
  }

  Widget _buildFooterActions(SubscriptionProvider provider) {
    final restore =
        provider.isRestoring
            ? const SizedBox(
              height: 32,
              child: Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
            : TextButton.icon(
              onPressed:
                  provider.isBusy
                      ? null
                      : () {
                        if (_blockDemo()) return;
                        provider.restorePurchases();
                      },
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                Icons.history_rounded,
                size: 16,
                color: AppThemeManage.appTheme.darkWhiteColor,
              ),
              label: Text(
                AppString.subscriptionStrings.restorePurchases,
                style: AppTypography.innerText12Mediu(context).copyWith(
                  color: AppThemeManage.appTheme.darkWhiteColor,
                  fontWeight: FontWeight.w600,
                  fontSize: SizeConfig.getFontSize(12),
                ),
              ),
            );
    if (!provider.hasActiveSubscription) return restore;

    final style = AppTypography.innerText12Mediu(context).copyWith(
      color: AppThemeManage.appTheme.darkWhiteColor,
      fontWeight: FontWeight.w600,
      fontSize: SizeConfig.getFontSize(12),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => _openManageSubscription(provider),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            AppString.subscriptionStrings.manageSubscription,
            style: style.copyWith(color: _kBlueTick),
          ),
        ),
        Text('•', style: style),
        restore,
      ],
    );
  }

  // ── renewal info + legal links (scrolls with the body) ─────────────────

  Widget _buildRenewalInfo() {
    return Column(
      children: [
        Text(
          defaultTargetPlatform == TargetPlatform.iOS
              ? AppString.subscriptionStrings.renewalInfoIos
              : AppString.subscriptionStrings.renewalInfo,
          textAlign: TextAlign.center,
          style: AppTypography.inputPlaceholderSmall(context).copyWith(
            fontFamily: AppTypography.fontFamily.poppins,
            color: AppColors.textColor.textGreyColor,
            fontSize: SizeConfig.getFontSize(9.5),
            height: 1.4,
          ),
        ),
        _buildLegalLinks(),
      ],
    );
  }

  /// Terms of Use and Privacy Policy links, required on the paywall by App
  /// Store Review Guideline 3.1.2.
  Widget _buildLegalLinks() {
    Widget link(String title, String htmlContent) => TextButton(
      onPressed:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => PrivacyWebView(title: title, htmlContent: htmlContent),
            ),
          ),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        title,
        style: AppTypography.innerText12Mediu(context).copyWith(
          color: AppThemeManage.appTheme.darkWhiteColor,
          fontSize: SizeConfig.getFontSize(10),
          decoration: TextDecoration.underline,
        ),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        link(AppString.settingStrigs.termsConditions, termsConditionText),
        Text('·', style: TextStyle(color: AppColors.textColor.textGreyColor)),
        link(AppString.settingStrigs.privacyPolicy, privacyPoicyText),
      ],
    );
  }

  // ── messages ───────────────────────────────────────────────────────────

  Widget _buildInlineMessage({
    required IconData icon,
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppThemeManage.appTheme.borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textColor.textGreyColor),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.innerText12Mediu(context).copyWith(
              color: AppColors.textColor.textGreyColor,
              fontSize: SizeConfig.getFontSize(13),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: TextStyle(
                  color: AppThemeManage.appTheme.darkWhiteColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textColor.textGreyColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.h5(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.innerText12Mediu(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical plan card meant to sit side-by-side with another in a [Row].
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.price,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
    this.badge,
    this.perMonth,
    this.currentLine,
  });

  final SubscriptionPlan plan;
  final String price;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;
  final String? badge;
  final String? perMonth;

  /// Replaces the billing line on the user's current plan.
  final String? currentLine;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.appPriSecColor.primaryColor;
    final secondary = AppColors.appPriSecColor.secondaryColor;
    final isYearly = plan == SubscriptionPlan.yearly;

    final period =
        isYearly
            ? AppString.subscriptionStrings.year
            : AppString.subscriptionStrings.month;
    final subtitle =
        isYearly
            ? (perMonth != null
                ? '${AppString.subscriptionStrings.equivalentTo} $perMonth/${AppString.subscriptionStrings.month}'
                : AppString.subscriptionStrings.billedYearly)
            : AppString.subscriptionStrings.billedMonthly;

    final priceStyle = AppTypography.h5(context).copyWith(
      fontWeight: FontWeight.w700,
      fontSize: SizeConfig.getFontSize(18),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.7,
      // Top padding is on every card so a floating badge never shifts rows.
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: enabled ? onTap : null,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 22, 10, 16),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? secondary.withValues(alpha: 0.35)
                          : AppThemeManage.appTheme.darkGreyColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isSelected
                            ? primary
                            : AppThemeManage.appTheme.borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                          : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kBlueTick.withValues(alpha: 0.14),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: _kBlueTick,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isYearly
                          ? AppString.subscriptionStrings.yearly
                          : AppString.subscriptionStrings.monthly,
                      style: AppTypography.innerText14(context).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: SizeConfig.getFontSize(15),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: price, style: priceStyle),
                            TextSpan(
                              text: '/$period',
                              style: priceStyle.copyWith(
                                fontSize: SizeConfig.getFontSize(12),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentLine ?? subtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.innerText12Mediu(context).copyWith(
                        color: AppColors.textColor.textGreyColor,
                        fontSize: SizeConfig.getFontSize(10.5),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Selected tick in the card's top-right corner.
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: primary,
                  size: 22,
                ),
              ),
            if (badge != null)
              Positioned(
                top: -11,
                left: 6,
                right: 6,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [secondary, primary]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: ThemeColorPalette.getTextColor(primary),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              badge!,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: ThemeColorPalette.getTextColor(primary),
                              ),
                            ),
                          ],
                        ),
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
}
