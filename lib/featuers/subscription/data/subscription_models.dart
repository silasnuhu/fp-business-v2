import 'package:whoxa/featuers/subscription/data/subscription_config.dart';

/// Unwraps the backend envelope `{status, success, message, data, ...}`.
/// Returns the `data` payload when present, otherwise the value itself.
dynamic unwrapEnvelope(dynamic json) {
  if (json is Map && json.containsKey('data')) return json['data'];
  return json;
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
  return false;
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is num) {
    // seconds or milliseconds since epoch
    final ms = v > 100000000000 ? v.toInt() : (v * 1000).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  return DateTime.tryParse(v.toString());
}

/// Maps a free-text cycle/plan label ("monthly", "month", "yearly",
/// "annual", ...) to our plan enum.
SubscriptionPlan? planFromLabel(String? label) {
  final s = (label ?? '').toLowerCase();
  if (s.contains('year') || s.contains('annual')) {
    return SubscriptionPlan.yearly;
  }
  if (s.contains('month')) return SubscriptionPlan.monthly;
  return null;
}

/// One plan from `GET /subscriptions/plans`.
class BackendPlan {
  const BackendPlan({
    required this.planId,
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    required this.billingCycle,
    required this.features,
    required this.appleProductId,
    required this.googleProductId,
  });

  final String planId;
  final String title;
  final String description;

  /// Backend price; only a fallback, the screen shows the store price.
  final String price;
  final String currency;
  final String billingCycle;
  final List<String> features;
  final String? appleProductId;
  final String? googleProductId;

  SubscriptionPlan? get plan =>
      planFromLabel(billingCycle) ?? planFromLabel(planId);

  factory BackendPlan.fromJson(Map json) {
    String s(String key) => (json[key] ?? '').toString();
    String? opt(String key) {
      final v = json[key]?.toString().trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    final rawFeatures = json['features'];
    return BackendPlan(
      planId: s('plan_id'),
      title: s('title'),
      description: s('description'),
      price: s('price'),
      currency: s('currency'),
      billingCycle: s('billing_cycle'),
      features: rawFeatures is List
          ? rawFeatures.map((e) => e.toString()).toList()
          : const [],
      appleProductId: opt('apple_product_id'),
      googleProductId: opt('google_product_id'),
    );
  }

  static List<BackendPlan> listFromResponse(dynamic response) {
    var data = unwrapEnvelope(response);
    if (data is Map) {
      data =
          data['Records'] ?? data['records'] ?? data['plans'] ?? data['items'];
    }
    if (data is! List) return const [];
    return data.whereType<Map>().map(BackendPlan.fromJson).toList();
  }
}

/// Response of `GET /subscriptions/me`.
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.planType,
    required this.premiumUser,
    this.premiumExpiresAt,
    this.activeSubscription,
  });

  static const SubscriptionStatus free = SubscriptionStatus(
    planType: 'free',
    premiumUser: false,
  );

  /// `free` or `premium`.
  final String planType;
  final bool premiumUser;
  final DateTime? premiumExpiresAt;

  /// Raw `active_subscription` object (shape not fixed yet); used only to
  /// work out which plan is active.
  final Map<String, dynamic>? activeSubscription;

  /// Which of our plans the active subscription is, when it can be told.
  SubscriptionPlan? get activePlan {
    final sub = activeSubscription;
    if (sub == null) return null;

    // Backend shape: `product_id` plus a nested `plan` object
    // `{plan_id, title, billing_cycle}`. Prefer those exact fields.
    final productId = sub['product_id']?.toString();
    if (productId != null) {
      final byProduct = SubscriptionConfig.planForProductId(productId);
      if (byProduct != null) return byProduct;
    }
    final nested = sub['plan'];
    if (nested is Map) {
      final byCycle = planFromLabel(nested['billing_cycle']?.toString());
      if (byCycle != null) return byCycle;
    }

    for (final key in const [
      'billing_cycle',
      'plan',
      'plan_id',
      'product_id',
      'google_product_id',
      'apple_product_id',
    ]) {
      final value = sub[key]?.toString();
      if (value == null) continue;
      final byProduct = SubscriptionConfig.planForProductId(value);
      if (byProduct != null) return byProduct;
      final byLabel = planFromLabel(value);
      if (byLabel != null) return byLabel;
    }
    return null;
  }

  /// Store product id of the active subscription, when the backend sends it.
  String? get activeProductId {
    final sub = activeSubscription;
    if (sub == null) return null;
    for (final key in const [
      'product_id',
      'google_product_id',
      'apple_product_id'
    ]) {
      final v = sub[key]?.toString();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  SubscriptionStatus copyWith({bool? premiumUser}) => SubscriptionStatus(
        planType: (premiumUser ?? this.premiumUser) ? 'premium' : planType,
        premiumUser: premiumUser ?? this.premiumUser,
        premiumExpiresAt: premiumExpiresAt,
        activeSubscription: activeSubscription,
      );

  factory SubscriptionStatus.fromResponse(dynamic response) {
    final data = unwrapEnvelope(response);
    if (data is! Map) return free;
    final planType = (data['plan_type'] ?? 'free').toString();
    final premium = data.containsKey('premium_user')
        ? _asBool(data['premium_user'])
        : planType.toLowerCase() == 'premium';
    final active = data['active_subscription'];
    return SubscriptionStatus(
      planType: planType,
      premiumUser: premium,
      premiumExpiresAt: _asDate(data['premium_expires_at']),
      activeSubscription:
          active is Map ? Map<String, dynamic>.from(active) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'plan_type': planType,
        'premium_user': premiumUser,
        'premium_expires_at': premiumExpiresAt?.toIso8601String(),
        'active_subscription': activeSubscription,
      };
}

/// One row of `GET /subscriptions/history`.
class SubscriptionHistoryRecord {
  const SubscriptionHistoryRecord({
    required this.planTitle,
    required this.platform,
    required this.status,
    required this.amount,
    required this.currency,
    this.purchasedAt,
    this.expiresAt,
  });

  final String planTitle;
  final String platform;

  /// `active`, `expired`, `revoked` or `pending`.
  final String status;
  final String amount;
  final String currency;
  final DateTime? purchasedAt;
  final DateTime? expiresAt;

  factory SubscriptionHistoryRecord.fromJson(Map json) {
    String s(dynamic v) => v == null ? '' : v.toString();

    // `plan` may be an object `{plan_id, title, billing_cycle}` or a string.
    final plan = json['plan'];
    var title = '';
    if (plan is Map) {
      title = s(plan['title']);
      if (title.isEmpty) title = s(plan['billing_cycle']);
    } else {
      title = s(plan);
    }
    if (title.isEmpty) title = s(json['product_id']);

    return SubscriptionHistoryRecord(
      planTitle: title,
      platform: s(json['platform']),
      status: s(json['status']),
      amount: s(json['amount']),
      currency: s(json['currency']),
      purchasedAt: _asDate(json['purchased_at']),
      expiresAt: _asDate(json['expires_at']),
    );
  }
}

class SubscriptionHistoryPage {
  const SubscriptionHistoryPage({required this.records, required this.hasMore});

  final List<SubscriptionHistoryRecord> records;
  final bool hasMore;

  /// Parses `{data: {Records: [...], Pagination: {...}}}`. When the pagination
  /// block has no total page count, a full page means there may be more.
  factory SubscriptionHistoryPage.fromResponse(
    dynamic response, {
    required int page,
    required int limit,
  }) {
    final data = unwrapEnvelope(response);
    dynamic list;
    dynamic pagination;
    if (data is Map) {
      list = data['Records'] ?? data['records'];
      pagination = data['Pagination'] ?? data['pagination'];
    } else if (data is List) {
      list = data;
    }

    final records = (list is List ? list : const [])
        .whereType<Map>()
        .map(SubscriptionHistoryRecord.fromJson)
        .toList();

    int? totalPages;
    if (pagination is Map) {
      totalPages = int.tryParse(
        '${pagination['total_pages'] ?? pagination['totalPages'] ?? ''}',
      );
    }
    final hasMore =
        totalPages != null ? page < totalPages : records.length >= limit;
    return SubscriptionHistoryPage(records: records, hasMore: hasMore);
  }
}
