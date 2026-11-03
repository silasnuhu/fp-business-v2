import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:whoxa/featuers/subscription/data/subscription_config.dart';
import 'package:whoxa/featuers/subscription/data/subscription_plan_option.dart';

class PlanQueryResult {
  const PlanQueryResult({
    this.plans = const {},
    this.billingUnavailable = false,
    this.hasError = false,
  });

  final Map<SubscriptionPlan, SubscriptionPlanOption> plans;
  final bool billingUnavailable;
  final bool hasError;
}

/// Thin wrapper over `in_app_purchase` (Google Play Billing on Android,
/// StoreKit on iOS). No UI, no state.
class StoreSubscriptionService {
  StoreSubscriptionService({InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<PlanQueryResult> queryPlans() async {
    try {
      if (!await _iap.isAvailable()) {
        return const PlanQueryResult(billingUnavailable: true);
      }

      final response = await _iap.queryProductDetails(
        SubscriptionConfig.productIds,
      );
      if (response.error != null) {
        log('🔥🔥🔥 Subscription: product query error: ${response.error}');
        return const PlanQueryResult(hasError: true);
      }
      if (response.notFoundIDs.isNotEmpty) {
        log('🔥🔥🔥 Subscription: products not found: ${response.notFoundIDs}');
      }
      _logPlanDetails(response.productDetails);

      final plans = <SubscriptionPlan, SubscriptionPlanOption>{};
      for (final plan in SubscriptionPlan.values) {
        final id = SubscriptionConfig.productIdFor(plan);
        final matches =
            response.productDetails.where((d) => d.id == id).toList();
        final option = _toOption(plan, matches);
        if (option != null) plans[plan] = option;
      }
      return PlanQueryResult(plans: plans);
    } catch (e) {
      log('🔥🔥🔥 Subscription: product query failed: $e');
      return const PlanQueryResult(hasError: true);
    }
  }

  /// A subscription can expose several base plans/offers; use the plain base
  /// plan (no promotional offer) and its recurring (last) pricing phase so a
  /// free-trial first phase is never shown as the price.
  SubscriptionPlanOption? _toOption(
    SubscriptionPlan plan,
    List<ProductDetails> matches,
  ) {
    if (matches.isEmpty) return null;

    ProductDetails chosen = matches.first;
    String price = chosen.price;
    double rawPrice = chosen.rawPrice;
    String currency = chosen.currencyCode;
    String? offerToken;

    final googlePlay = matches.whereType<GooglePlayProductDetails>().toList();
    if (googlePlay.isNotEmpty) {
      final pick = googlePlay.firstWhere(
        (d) => _offerOf(d)?.offerId == null,
        orElse: () => googlePlay.first,
      );
      chosen = pick;
      final offer = _offerOf(pick);
      if (offer != null) {
        offerToken = offer.offerIdToken;
        if (offer.pricingPhases.isNotEmpty) {
          final phase = offer.pricingPhases.last;
          price = phase.formattedPrice;
          rawPrice = phase.priceAmountMicros / 1000000.0;
          currency = phase.priceCurrencyCode;
        }
      }
    }

    return SubscriptionPlanOption(
      plan: plan,
      productDetails: chosen,
      formattedPrice: price,
      rawPrice: rawPrice,
      currencyCode: currency,
      offerToken: offerToken,
    );
  }

  /// Debug-only dump of everything the store returned for the plans
  /// (price, title, description; plus base plan, offers and pricing phases
  /// on Google Play).
  void _logPlanDetails(List<ProductDetails> details) {
    if (!kDebugMode) return;
    log('🔥🔥🔥 Subscription: store returned ${details.length} item(s)');
    for (final d in details) {
      log(
        '🔥🔥🔥 Subscription: [Play] id=${d.id} | title="${d.title}" | '
        'description="${d.description}" | price=${d.price} | '
        'rawPrice=${d.rawPrice} | currency=${d.currencyCode} '
        '(${d.currencySymbol})',
      );
      if (d is! GooglePlayProductDetails) continue;
      log(
        '🔥🔥🔥 Subscription: [Play]   productType=${d.productDetails.productType} '
        'name="${d.productDetails.name}" '
        'subscriptionIndex=${d.subscriptionIndex}',
      );
      final offers = d.productDetails.subscriptionOfferDetails ?? [];
      for (final o in offers) {
        log(
          '🔥🔥🔥 Subscription: [Play]   offer: basePlanId=${o.basePlanId} '
          'offerId=${o.offerId} tags=${o.offerTags} '
          'offerToken=${o.offerIdToken}',
        );
        for (final p in o.pricingPhases) {
          log(
            '🔥🔥🔥 Subscription: [Play]     phase: ${p.formattedPrice} '
            '(micros=${p.priceAmountMicros}, ${p.priceCurrencyCode}) '
            'period=${p.billingPeriod} cycles=${p.billingCycleCount} '
            'recurrence=${p.recurrenceMode}',
          );
        }
      }
    }
  }

  SubscriptionOfferDetailsWrapper? _offerOf(GooglePlayProductDetails d) {
    final index = d.subscriptionIndex;
    final offers = d.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) return null;
    return offers[index];
  }

  /// Opens the Google Play / App Store purchase sheet. The result arrives on
  /// [purchaseStream]; `true` only means the flow was launched.
  /// [accountId] is sent to Google Play as the obfuscated account id
  /// (the backend binds the purchase to that user with it). Android only.
  ///
  /// [replaceProductId] upgrades that active Google Play subscription to
  /// [option] (immediately, remaining time credited). StoreKit needs no
  /// such hint: plans of one subscription group replace each other.
  /// Returns false when the subscription to replace cannot be found.
  Future<bool> buy(
    SubscriptionPlanOption option, {
    String? accountId,
    String? replaceProductId,
  }) async {
    final PurchaseParam param;
    if (option.productDetails is GooglePlayProductDetails) {
      ChangeSubscriptionParam? change;
      if (replaceProductId != null) {
        final old = await _findGooglePlayPurchase(replaceProductId);
        if (old == null) {
          log('🔥🔥🔥 Subscription: no active purchase for $replaceProductId');
          return false;
        }
        change = ChangeSubscriptionParam(
          oldPurchaseDetails: old,
          replacementMode: ReplacementMode.withTimeProration,
        );
      }
      param = GooglePlayPurchaseParam(
        productDetails: option.productDetails,
        offerToken: option.offerToken,
        applicationUserName: accountId,
        changeSubscriptionParam: change,
      );
    } else {
      param = PurchaseParam(productDetails: option.productDetails);
    }
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<GooglePlayPurchaseDetails?> _findGooglePlayPurchase(
    String productId,
  ) async {
    try {
      final addition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      for (final p in response.pastPurchases) {
        if (p.productID == productId) return p;
      }
    } catch (e) {
      log('🔥🔥🔥 Subscription: past purchase lookup failed: $e');
    }
    return null;
  }

  /// Active subscriptions this Google Play account already owns for our
  /// products (Android only; empty elsewhere or on error). A second app
  /// account on the same device would otherwise hit ITEM_ALREADY_OWNED.
  Future<List<PurchaseDetails>> findOwnedPurchases() async {
    try {
      final addition = _iap.getPlatformAddition<
        InAppPurchaseAndroidPlatformAddition
      >();
      final response = await addition.queryPastPurchases();
      return [
        for (final p in response.pastPurchases)
          if (SubscriptionConfig.productIds.contains(p.productID) &&
              p.status == PurchaseStatus.purchased)
            p,
      ];
    } catch (e) {
      log('🔥🔥🔥 Subscription: owned purchase lookup failed: $e');
      return const [];
    }
  }

  /// Re-delivers existing purchases on [purchaseStream] (an empty list when
  /// the account has none).
  Future<void> restore() => _iap.restorePurchases();

  Future<void> complete(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);
}
