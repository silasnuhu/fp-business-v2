import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/subscription/data/subscription_models.dart';
import 'package:whoxa/utils/logger.dart';

enum SubscriptionVerificationOutcome {
  /// The backend confirmed the purchase.
  verified,

  /// The backend explicitly rejected the purchase.
  rejected,

  /// The store purchase is already bound to a different app account
  /// (HTTP 409 / `LINKED_TO_ANOTHER_ACCOUNT`). One store subscription
  /// belongs to one app account, so this account must not get it.
  linkedToOtherAccount,

  /// Verification could not be completed (network/server error); retry later.
  failed,
}

/// Everything the backend needs to verify a subscription with the store:
/// the Google Play Developer API on Android, the App Store Server API on iOS.
class SubscriptionPurchaseProof {
  const SubscriptionPurchaseProof({
    required this.platform,
    required this.productId,
    required this.purchaseId,
    required this.serverVerificationData,
    required this.localVerificationData,
    required this.transactionDate,
  });

  /// `android` or `ios`.
  final String platform;
  final String productId;

  /// Google Play order ID / App Store transaction ID.
  final String? purchaseId;

  /// Google Play purchase token on Android; the signed transaction (JWS) on
  /// iOS (StoreKit 2).
  final String serverVerificationData;
  final String localVerificationData;
  final String? transactionDate;
}

/// Backend boundary. The Flutter side only forwards purchase data; the
/// entitlement (`premium_user`) is granted by the server after it verifies the
/// purchase with Google / Apple (no secrets live in the app).
abstract class SubscriptionRepository {
  Future<SubscriptionVerificationOutcome> verifySubscription(
    SubscriptionPurchaseProof proof,
  );

  /// `GET /subscriptions/me`; null when it could not be fetched.
  Future<SubscriptionStatus?> fetchStatus();

  /// `GET /subscriptions/plans`; empty when it could not be fetched.
  Future<List<BackendPlan>> fetchPlans();

  /// `GET /subscriptions/history`; null when it could not be fetched.
  Future<SubscriptionHistoryPage?> fetchHistory({int page = 1, int limit = 20});
}

class ApiSubscriptionRepository implements SubscriptionRepository {
  ApiSubscriptionRepository(this._apiClient);

  final ApiClient _apiClient;
  final _logger = ConsoleAppLogger.forModule('SubscriptionRepository');

  @override
  Future<SubscriptionVerificationOutcome> verifySubscription(
    SubscriptionPurchaseProof proof,
  ) async {
    final isIos = proof.platform == 'ios';
    final body =
        isIos
            ? {'platform': 'apple', 'transaction_id': proof.purchaseId ?? ''}
            : {
              'platform': 'google',
              'purchase_token': proof.serverVerificationData,
            };

    final proofValue = isIos ? proof.purchaseId : proof.serverVerificationData;
    if (proofValue == null || proofValue.isEmpty) {
      _logger.e('Verify skipped: purchase has no token/transaction id');
      return SubscriptionVerificationOutcome.rejected;
    }

    try {
      final response = await _apiClient.request(
        ApiEndpoints.subscriptionVerify,
        method: 'POST',
        body: body,
      );
      if (response is Map &&
          (response['success'] == false || response['status'] == false)) {
        _logger.e('Verify rejected: ${response['message']}');
        return _isLinkedElsewhere(response['code'], response['message'])
            ? SubscriptionVerificationOutcome.linkedToOtherAccount
            : SubscriptionVerificationOutcome.rejected;
      }
      return SubscriptionVerificationOutcome.verified;
    } on AppError catch (e) {
      final code = e.statusCode;
      _logger.e('Verify failed (HTTP $code): ${e.message}');
      if (code == 409 || _isLinkedElsewhere(null, e.message)) {
        return SubscriptionVerificationOutcome.linkedToOtherAccount;
      }
      // Anything that may be temporary must NOT complete the purchase: the
      // store re-delivers it next launch and verification is retried.
      final temporary =
          e.isNetworkError ||
          code == null ||
          code == 401 ||
          code == 408 ||
          code == 429 ||
          code >= 500;
      return temporary
          ? SubscriptionVerificationOutcome.failed
          : SubscriptionVerificationOutcome.rejected;
    } catch (e) {
      _logger.e('Verify error: $e');
      return SubscriptionVerificationOutcome.failed;
    }
  }

  static bool _isLinkedElsewhere(dynamic code, dynamic message) {
    final text = '${code ?? ''} ${message ?? ''}'.toUpperCase();
    return text.contains('LINKED_TO_ANOTHER_ACCOUNT') ||
        text.contains('ANOTHER ACCOUNT');
  }

  @override
  Future<SubscriptionStatus?> fetchStatus() async {
    try {
      final response = await _apiClient.request(ApiEndpoints.subscriptionMe);
      return SubscriptionStatus.fromResponse(response);
    } catch (e) {
      _logger.e('Fetching subscription status failed: $e');
      return null;
    }
  }

  @override
  Future<List<BackendPlan>> fetchPlans() async {
    try {
      final response = await _apiClient.request(ApiEndpoints.subscriptionPlans);
      return BackendPlan.listFromResponse(response);
    } catch (e) {
      _logger.e('Fetching subscription plans failed: $e');
      return const [];
    }
  }

  @override
  Future<SubscriptionHistoryPage?> fetchHistory({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.request(
        '${ApiEndpoints.subscriptionHistory}?page=$page&limit=$limit',
      );
      return SubscriptionHistoryPage.fromResponse(
        response,
        page: page,
        limit: limit,
      );
    } catch (e) {
      _logger.e('Fetching subscription history failed: $e');
      return null;
    }
  }
}
