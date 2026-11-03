/// Single place for the subscription product IDs. The same IDs are used in
/// Google Play Console and App Store Connect.
///
/// These are the defaults. When `GET /subscriptions/plans` answers, the
/// product IDs it returns for the current platform replace them
/// (see [applyBackendProductIds]).
class SubscriptionConfig {
  SubscriptionConfig._();

  static const String monthlyProductId = 'pro_subscription_monthly';
  static const String yearlyProductId = 'pro_subscription_yearly';

  static Map<SubscriptionPlan, String> _ids = {
    SubscriptionPlan.monthly: monthlyProductId,
    SubscriptionPlan.yearly: yearlyProductId,
  };

  static Set<String> get productIds => _ids.values.toSet();

  static SubscriptionPlan? planForProductId(String productId) {
    for (final entry in _ids.entries) {
      if (entry.value == productId) return entry.key;
    }
    return null;
  }

  static String productIdFor(SubscriptionPlan plan) =>
      _ids[plan] ??
      (plan == SubscriptionPlan.monthly ? monthlyProductId : yearlyProductId);

  /// Replaces the product IDs with the ones the backend returned. Ignored when
  /// [ids] is empty so a failed/empty response keeps the defaults.
  static void applyBackendProductIds(Map<SubscriptionPlan, String> ids) {
    if (ids.isEmpty) return;
    _ids = Map.of(ids);
  }
}

enum SubscriptionPlan { monthly, yearly }
