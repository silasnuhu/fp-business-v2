import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/subscription/data/subscription_models.dart';
import 'package:whoxa/featuers/subscription/provider/subscription_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';

/// `GET /subscriptions/history` — the user's past and current subscriptions.
class SubscriptionHistoryScreen extends StatefulWidget {
  const SubscriptionHistoryScreen({super.key});

  @override
  State<SubscriptionHistoryScreen> createState() =>
      _SubscriptionHistoryScreenState();
}

class _SubscriptionHistoryScreenState extends State<SubscriptionHistoryScreen> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<SubscriptionHistoryRecord> _records = [];
  int _page = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 150) _loadNext();
  }

  Future<void> _refresh() async {
    _records.clear();
    _page = 0;
    _hasMore = true;
    _hasError = false;
    await _loadNext();
  }

  Future<void> _loadNext() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final provider = context.read<SubscriptionProvider>();
    final result = await provider.fetchHistory(
      page: _page + 1,
      limit: _pageSize,
    );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result == null) {
        _hasError = _records.isEmpty;
        _hasMore = false;
        return;
      }
      _page += 1;
      _records.addAll(result.records);
      _hasMore = result.hasMore;
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
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
          title: Text(
            AppString.subscriptionStrings.subscriptionHistory,
            style: AppTypography.h220(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_records.isEmpty && _isLoading) {
      return Center(child: commonLoading());
    }
    if (_hasError) {
      return _centered(
        icon: Icons.cloud_off_rounded,
        text: AppString.subscriptionStrings.loadHistoryError,
        action: TextButton(onPressed: _refresh, child: Text(AppString.retry)),
      );
    }
    if (_records.isEmpty) {
      return _centered(
        icon: Icons.receipt_long_outlined,
        text: AppString.subscriptionStrings.noSubscriptionHistory,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.appPriSecColor.primaryColor,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 16),
        itemCount: _records.length + (_isLoading ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _records.length) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Center(child: commonLoading()),
            );
          }
          return _HistoryCard(record: _records[index]);
        },
      ),
    );
  }

  Widget _centered({
    required IconData icon,
    required String text,
    Widget? action,
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
              text,
              textAlign: TextAlign.center,
              style: AppTypography.innerText12Mediu(context).copyWith(
                color: AppColors.textColor.textGreyColor,
                fontSize: SizeConfig.getFontSize(13),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record});

  final SubscriptionHistoryRecord record;

  String _statusLabel() {
    final strings = AppString.subscriptionStrings;
    switch (record.status.toLowerCase()) {
      case 'active':
        return strings.statusActive;
      case 'expired':
        return strings.statusExpired;
      case 'revoked':
        return strings.statusRevoked;
      case 'pending':
        return strings.statusPending;
    }
    return record.status;
  }

  Color _statusColor() {
    switch (record.status.toLowerCase()) {
      case 'active':
        return const Color(0xFF2E9E57);
      case 'pending':
        return const Color(0xFFE08A00);
      case 'revoked':
        return Colors.red;
    }
    return AppColors.textColor.textGreyColor;
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat.yMMMd();
    final statusColor = _statusColor();
    final amount =
        record.amount.isEmpty
            ? null
            : [
              record.currency,
              record.amount,
            ].where((e) => e.isNotEmpty).join(' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppThemeManage.appTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.planTitle,
                  style: AppTypography.innerText14(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (amount != null)
            Text(
              amount,
              style: AppTypography.h5(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 6),
          if (record.purchasedAt != null)
            _line(
              context,
              AppString.subscriptionStrings.purchasedOn(
                format.format(record.purchasedAt!.toLocal()),
              ),
            ),
          if (record.expiresAt != null)
            _line(
              context,
              AppString.subscriptionStrings.endsOn(
                format.format(record.expiresAt!.toLocal()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: AppTypography.innerText12Mediu(context).copyWith(
          color: AppColors.textColor.textGreyColor,
          fontSize: SizeConfig.getFontSize(12),
        ),
      ),
    );
  }
}
