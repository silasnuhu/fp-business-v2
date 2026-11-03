import 'package:flutter_test/flutter_test.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/subscription/data/subscription_repository.dart';

class _FakeClient extends Fake implements ApiClient {
  _FakeClient(this._respond);
  final dynamic Function() _respond;

  @override
  Future<dynamic> request(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    dynamic data,
    bool isSecure = true,
  }) async => _respond();
}

const _proof = SubscriptionPurchaseProof(
  platform: 'android',
  productId: 'pro_subscription_monthly',
  purchaseId: 'GPA.1',
  serverVerificationData: 'token',
  localVerificationData: '{}',
  transactionDate: null,
);

Future<SubscriptionVerificationOutcome> _verify(dynamic Function() respond) =>
    ApiSubscriptionRepository(_FakeClient(respond)).verifySubscription(_proof);

void main() {
  test('verify: success', () async {
    expect(
      await _verify(() => {'status': true}),
      SubscriptionVerificationOutcome.verified,
    );
  });

  test('verify: 409 means linked to another account', () async {
    expect(
      await _verify(() => throw AppError('Conflict', statusCode: 409)),
      SubscriptionVerificationOutcome.linkedToOtherAccount,
    );
  });

  test('verify: LINKED_TO_ANOTHER_ACCOUNT code in a 200 body', () async {
    expect(
      await _verify(
        () => {
          'status': false,
          'code': 'LINKED_TO_ANOTHER_ACCOUNT',
          'message': 'x',
        },
      ),
      SubscriptionVerificationOutcome.linkedToOtherAccount,
    );
  });

  test('verify: plain rejection and temporary failure stay as before', () async {
    expect(
      await _verify(() => throw AppError('Bad', statusCode: 400)),
      SubscriptionVerificationOutcome.rejected,
    );
    expect(
      await _verify(() => throw AppError('Down', statusCode: 503)),
      SubscriptionVerificationOutcome.failed,
    );
  });
}
