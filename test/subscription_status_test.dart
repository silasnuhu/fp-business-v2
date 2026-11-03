import 'package:flutter_test/flutter_test.dart';
import 'package:whoxa/featuers/auth/data/models/user_profile_model.dart';
import 'package:whoxa/featuers/subscription/data/subscription_config.dart';
import 'package:whoxa/featuers/subscription/data/subscription_models.dart';

void main() {
  // Real `POST /subscriptions/verify` / `GET /subscriptions/me` response of a
  // sandbox monthly purchase.
  final premiumResponse = {
    'status': true,
    'data': {
      'plan_type': 'premium',
      'premium_user': true,
      'premium_expires_at': '2026-10-08T09:12:30.846Z',
      'active_subscription': {
        'subscription_id': 3,
        'plan': {'plan_id': 7, 'title': 'Monthly', 'billing_cycle': 'monthly'},
        'platform': 'google',
        'status': 'active',
        'product_id': 'pro_subscription_monthly',
        'amount': 480,
        'currency': 'INR',
        'purchased_at': '2026-10-08T09:07:31.342Z',
        'expires_at': '2026-10-08T09:12:30.846Z',
        'auto_renew_enabled': true,
        'environment': 'sandbox',
        'revoked_at': null,
        'created_at': '2026-10-08T09:07:36.729Z',
      },
    },
    'message': 'Subscription activated',
    'toast': true,
  };

  test('premium response is parsed', () {
    final status = SubscriptionStatus.fromResponse(premiumResponse);
    expect(status.premiumUser, isTrue);
    expect(status.planType, 'premium');
    expect(
      status.premiumExpiresAt,
      DateTime.parse('2026-10-08T09:12:30.846Z'),
    );
    expect(status.activePlan, SubscriptionPlan.monthly);
    expect(status.activeProductId, 'pro_subscription_monthly');
  });

  test('yearly subscription maps to the yearly plan', () {
    final status = SubscriptionStatus.fromResponse({
      'status': true,
      'data': {
        'plan_type': 'premium',
        'premium_user': true,
        'premium_expires_at': '2027-10-08T09:12:30.846Z',
        'active_subscription': {
          'plan': {'plan_id': 8, 'title': 'Yearly', 'billing_cycle': 'yearly'},
          'product_id': 'pro_subscription_yearly',
          'status': 'active',
        },
      },
    });
    expect(status.activePlan, SubscriptionPlan.yearly);
  });

  test('free response is not premium', () {
    final status = SubscriptionStatus.fromResponse({
      'status': true,
      'data': {
        'plan_type': 'free',
        'premium_user': false,
        'premium_expires_at': null,
        'active_subscription': null,
      },
    });
    expect(status.premiumUser, isFalse);
    expect(status.activePlan, isNull);
    expect(status.premiumExpiresAt, isNull);
  });

  test('history page is parsed (object or string plan, pagination)', () {
    final page = SubscriptionHistoryPage.fromResponse(
      {
        'status': true,
        'data': {
          'Records': [
            {
              'plan': {
                'plan_id': 7,
                'title': 'Monthly',
                'billing_cycle': 'monthly'
              },
              'platform': 'google',
              'status': 'active',
              'amount': 480,
              'currency': 'INR',
              'purchased_at': '2026-10-08T09:07:31.342Z',
              'expires_at': '2026-10-08T09:12:30.846Z',
            },
            {'plan': 'Yearly', 'platform': 'apple', 'status': 'expired'},
          ],
          'Pagination': {'current_page': 1, 'total_pages': 2},
        },
      },
      page: 1,
      limit: 20,
    );
    expect(page.records.length, 2);
    expect(page.records.first.planTitle, 'Monthly');
    expect(page.records.first.status, 'active');
    expect(page.records.first.amount, '480');
    expect(page.records.first.purchasedAt, isNotNull);
    expect(page.records[1].planTitle, 'Yearly');
    expect(page.hasMore, isTrue); // page 1 of 2

    final last = SubscriptionHistoryPage.fromResponse(
      {
        'data': {
          'Records': [],
          'Pagination': {'total_pages': 1}
        }
      },
      page: 1,
      limit: 20,
    );
    expect(last.records, isEmpty);
    expect(last.hasMore, isFalse);
  });

  test('real /subscriptions/history response (sandbox renewals)', () {
    Map<String, dynamic> row(int id, String status, String expires) => {
          'subscription_id': id,
          'plan': {
            'plan_id': 7,
            'title': 'Monthly',
            'billing_cycle': 'monthly'
          },
          'platform': 'google',
          'status': status,
          'product_id': 'pro_subscription_monthly',
          'amount': 480,
          'currency': 'INR',
          'purchased_at': '2026-10-08T09:07:31.342Z',
          'expires_at': expires,
          'auto_renew_enabled': true,
          'environment': 'sandbox',
          'revoked_at': null,
          'created_at': '2026-10-08T09:22:38.455Z',
        };

    final page = SubscriptionHistoryPage.fromResponse(
      {
        'status': true,
        'data': {
          'Records': [
            row(8, 'active', '2026-10-08T09:27:30.846Z'),
            row(3, 'expired', '2026-10-08T09:12:30.846Z'),
          ],
          'Pagination': {
            'total_pages': 1,
            'total_records': 5,
            'current_page': 1,
            'records_per_page': 20,
          },
        },
        'message': 'Success',
        'toast': false,
      },
      page: 1,
      limit: 20,
    );

    expect(page.records.length, 2);
    expect(page.records.first.planTitle, 'Monthly');
    expect(page.records.first.status, 'active');
    expect(page.records.first.currency, 'INR');
    expect(page.records.first.amount, '480');
    expect(page.records[1].status, 'expired');
    expect(page.hasMore, isFalse); // page 1 of 1
  });

  test('updateUser data carries premium_user', () {
    final data = Data.fromJson({
      'user_id': 1,
      'premium_user': true,
      'premium_expires_at': '2026-10-08T09:12:30.846Z',
    });
    expect(data.premiumUser, isTrue);
    expect(data.premiumExpiresAt, '2026-10-08T09:12:30.846Z');
    expect(Data.fromJson({'user_id': 1}).premiumUser, isNull);
  });
}
