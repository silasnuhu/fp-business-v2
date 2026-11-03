import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:whoxa/featuers/subscription/data/subscription_config.dart';

/// One purchasable plan as returned by Google Play / the App Store. Prices
/// are never hard-coded: [formattedPrice] is the localized store string.
class SubscriptionPlanOption {
  const SubscriptionPlanOption({
    required this.plan,
    required this.productDetails,
    required this.formattedPrice,
    required this.rawPrice,
    required this.currencyCode,
    this.offerToken,
  });

  final SubscriptionPlan plan;
  final ProductDetails productDetails;

  /// Localized recurring price (from the store).
  final String formattedPrice;
  final double rawPrice;
  final String currencyCode;

  /// Google Play offer token required to start a subscription purchase
  /// (always null on iOS).
  final String? offerToken;

  String get productId => productDetails.id;
}
