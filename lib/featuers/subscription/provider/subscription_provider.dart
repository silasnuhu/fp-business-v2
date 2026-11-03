// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:whoxa/ads/ad_free_state.dart';
import 'package:whoxa/featuers/subscription/data/subscription_config.dart';
import 'package:whoxa/featuers/subscription/data/subscription_models.dart';
import 'package:whoxa/featuers/subscription/data/subscription_plan_option.dart';
import 'package:whoxa/featuers/subscription/data/subscription_repository.dart';
import 'package:whoxa/featuers/subscription/services/store_subscription_service.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart' show isDemo, userID;

enum SubscriptionUiState {
  initial,
  loadingProducts,
  productsLoaded,
  noProducts,
  productError,
  purchaseProcessing,
  purchasePending,
  purchaseSuccessful,
  purchaseCancelled,
  purchaseFailed,
  restoreProcessing,
  restoreSuccessful,
  nothingToRestore,
  restoreFailed,
}

/// Owns the store (Google Play / App Store) purchase stream and the
/// subscription screen state.
///
/// Registered app-wide (lazy) so the single `purchaseStream` subscription
/// outlives the screen and late purchase updates are never dropped.
class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider({
    StoreSubscriptionService? service,
    required SubscriptionRepository repository,
  })  : _service = service ?? StoreSubscriptionService(),
        _repository = repository;

  final StoreSubscriptionService _service;
  final SubscriptionRepository _repository;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Timer? _restoreTimeout;
  // A purchase seen during the current restore belongs to another account.
  bool _blockedByOtherAccount = false;
  bool _initialized = false;
  bool _disposed = false;

  SubscriptionUiState _state = SubscriptionUiState.initial;
  Map<SubscriptionPlan, SubscriptionPlanOption> _plans = {};
  SubscriptionPlan _selectedPlan = SubscriptionPlan.yearly;
  // Entitlement from the backend (`GET /subscriptions/me`).
  SubscriptionStatus _status = SubscriptionStatus.free;
  String? _statusUserId;

  // One-shot message for the UI (snackbar). `eventSeq` changes per message.
  int _eventSeq = 0;
  String? _eventMessage;
  bool _eventIsError = false;

  SubscriptionUiState get state => _state;
  Map<SubscriptionPlan, SubscriptionPlanOption> get plans => _plans;
  SubscriptionPlan get selectedPlan => _selectedPlan;
  SubscriptionStatus get status => _status;
  bool get premiumUser => _status.premiumUser;
  bool get hasActiveSubscription => _status.premiumUser;
  SubscriptionPlan? get activePlan => _status.activePlan;
  String? get activeProductId => _status.activeProductId;
  DateTime? get premiumExpiresAt => _status.premiumExpiresAt;

  int get eventSeq => _eventSeq;
  String? get eventMessage => _eventMessage;
  bool get eventIsError => _eventIsError;

  bool get isLoadingProducts => _state == SubscriptionUiState.loadingProducts;
  bool get isPurchasing =>
      _state == SubscriptionUiState.purchaseProcessing ||
      _state == SubscriptionUiState.purchasePending;
  bool get isRestoring => _state == SubscriptionUiState.restoreProcessing;
  bool get isBusy => isPurchasing || isRestoring;

  SubscriptionPlanOption? get selectedOption => _plans[_selectedPlan];

  /// A monthly subscriber can move up to the yearly plan in the app.
  bool get canUpgrade =>
      hasActiveSubscription &&
      activePlan == SubscriptionPlan.monthly &&
      _plans.containsKey(SubscriptionPlan.yearly);

  /// The selected plan is the one the user already has.
  bool get selectedIsCurrent =>
      hasActiveSubscription && _selectedPlan == activePlan;

  /// Active subscribers can only stay on their plan or move up.
  bool canSelect(SubscriptionPlan plan) =>
      !hasActiveSubscription ||
      plan == activePlan ||
      (canUpgrade && plan == SubscriptionPlan.yearly);

  bool get isUpgrade => canUpgrade && _selectedPlan == SubscriptionPlan.yearly;

  /// Subscribes to the purchase stream (once) and loads the plans.
  Future<void> initialize() async {
    if (!_initialized) {
      _initialized = true;
      _purchaseSub = _service.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object e) {
          debugPrint('Subscription: purchase stream error: $e');
          _setState(SubscriptionUiState.purchaseFailed);
          _emit(AppString.subscriptionStrings.purchaseFailed, isError: true);
        },
      );
    }
    unawaited(refreshStatus());
    // Product IDs come from the backend when it answers; defaults otherwise.
    await _applyBackendPlans();
    await loadProducts();
  }

  Future<void> loadProducts() async {
    if (isBusy) return;
    _setState(SubscriptionUiState.loadingProducts);

    final result = await _service.queryPlans();
    if (_disposed) return;

    if (result.billingUnavailable || result.hasError) {
      _plans = {};
      _setState(SubscriptionUiState.productError);
      return;
    }
    _plans = result.plans;
    if (_plans.isEmpty) {
      _setState(SubscriptionUiState.noProducts);
      return;
    }
    if (!_plans.containsKey(_selectedPlan)) {
      _selectedPlan = _plans.keys.first;
    }
    _setState(SubscriptionUiState.productsLoaded);
  }

  void selectPlan(SubscriptionPlan plan) {
    if (isBusy || !_plans.containsKey(plan) || _selectedPlan == plan) return;
    if (!canSelect(plan)) return;
    _selectedPlan = plan;
    notifyListeners();
  }

  Future<void> purchase() async {
    final option = selectedOption;
    if (option == null || isBusy) return;
    // Demo accounts cannot buy (the screen also tells the user why).
    if (isDemo) return;
    // An active subscriber may only buy the upgrade.
    final upgrade = isUpgrade;
    if (hasActiveSubscription && !upgrade) return;

    // Android: the backend binds the purchase to this user through the
    // obfuscated account id, so it is mandatory there.
    final accountId =
        defaultTargetPlatform == TargetPlatform.android ? userID : null;
    if (accountId != null && accountId.isEmpty) {
      _setState(SubscriptionUiState.purchaseFailed);
      _emit(AppString.subscriptionStrings.purchaseFailed, isError: true);
      return;
    }

    _setState(SubscriptionUiState.purchaseProcessing);
    // The store account may already own this subscription (another app
    // account on this device bought it): resolve that instead of opening
    // a sheet that can only answer "already owned".
    if (!upgrade && accountId != null && await _resolveOwnedPurchases()) {
      return;
    }
    try {
      final launched = await _service.buy(
        option,
        accountId: accountId,
        // iOS replaces the plan inside the subscription group by itself.
        replaceProductId:
            upgrade && defaultTargetPlatform == TargetPlatform.android
                ? (activeProductId ??
                    SubscriptionConfig.productIdFor(SubscriptionPlan.monthly))
                : null,
      );
      if (!launched) {
        _setState(SubscriptionUiState.purchaseFailed);
        _emit(AppString.subscriptionStrings.purchaseFailed, isError: true);
      }
      // Otherwise the outcome arrives on the purchase stream.
    } catch (e) {
      debugPrint('Subscription: buy failed: $e');
      _setState(SubscriptionUiState.purchaseFailed);
      _emit(AppString.subscriptionStrings.purchaseFailed, isError: true);
    }
  }

  Future<void> restorePurchases() async {
    if (isBusy) return;
    // Demo accounts cannot restore either (the screen tells the user why).
    if (isDemo) return;
    _blockedByOtherAccount = false;
    _setState(SubscriptionUiState.restoreProcessing);

    // Safety net: restore should answer on the stream almost immediately.
    _restoreTimeout?.cancel();
    _restoreTimeout = Timer(const Duration(seconds: 15), () {
      if (isRestoring) _finishRestore(restored: false, failed: true);
    });

    try {
      await _service.restore();
    } catch (e) {
      debugPrint('Subscription: restore failed: $e');
      _finishRestore(restored: false, failed: true);
    }
  }

  // ── purchase stream ────────────────────────────────────────────────────

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> updates) async {
    // When the Play sheet is dismissed or fails before any purchase exists
    // (user cancel, item unavailable, developer/console error, ...), the
    // plugin reports it with an EMPTY productID. Without handling it the
    // purchase loader would never stop.
    for (final result in updates.where((p) => p.productID.isEmpty)) {
      _handleFlowResult(result);
    }

    final ours = updates
        .where((p) => SubscriptionConfig.productIds.contains(p.productID))
        .toList();

    if (ours.isEmpty) {
      // `restorePurchases()` answers with an empty list when nothing exists.
      if (isRestoring) _finishRestore(restored: false);
      return;
    }

    var restoredSomething = false;
    for (final purchase in ours) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _setState(SubscriptionUiState.purchasePending);
          _emit(AppString.subscriptionStrings.paymentPending);
          break;
        case PurchaseStatus.canceled:
          _setState(SubscriptionUiState.purchaseCancelled);
          _emit(AppString.subscriptionStrings.purchaseCanceled);
          break;
        case PurchaseStatus.error:
          debugPrint('Subscription: purchase error: ${purchase.error}');
          if (purchase.pendingCompletePurchase) {
            await _completeSafely(purchase);
          }
          if (isRestoring) {
            _finishRestore(restored: false, failed: true);
          } else {
            _setState(SubscriptionUiState.purchaseFailed);
            _emit(AppString.subscriptionStrings.purchaseFailed, isError: true);
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final ok = await _handleSuccessfulPurchase(purchase);
          if (ok && purchase.status == PurchaseStatus.restored) {
            restoredSomething = true;
          }
          break;
      }
    }

    if (isRestoring) {
      _finishRestore(restored: restoredSomething);
    }
  }

  /// Outcome of a purchase flow that ended without a purchase object.
  void _handleFlowResult(PurchaseDetails result) {
    if (result.status == PurchaseStatus.canceled) {
      if (isPurchasing) {
        _setState(SubscriptionUiState.purchaseCancelled);
        _emit(AppString.subscriptionStrings.purchaseCanceled);
      }
    } else if (result.status == PurchaseStatus.error) {
      debugPrint(
        'Subscription: purchase flow failed: '
        '${result.error?.message} ${result.error?.details}',
      );
      if (isPurchasing) {
        if (_looksAlreadyOwned(result.error)) {
          unawaited(_handleAlreadyOwned());
          return;
        }
        _setState(SubscriptionUiState.purchaseFailed);
        _emit(
          AppString.subscriptionStrings.purchaseFailed,
          isError: true,
        );
      } else if (isRestoring) {
        _finishRestore(restored: false, failed: true);
      }
    }
  }

  /// Verifies (via the backend abstraction), completes and records one
  /// purchase. Returns whether the subscription is now considered active.
  Future<bool> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    final outcome = await _repository.verifySubscription(
      SubscriptionPurchaseProof(
        platform:
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        productId: purchase.productID,
        purchaseId: purchase.purchaseID,
        serverVerificationData:
            purchase.verificationData.serverVerificationData,
        localVerificationData: purchase.verificationData.localVerificationData,
        transactionDate: purchase.transactionDate,
      ),
    );

    switch (outcome) {
      case SubscriptionVerificationOutcome.rejected:
        if (purchase.pendingCompletePurchase) {
          await _completeSafely(purchase);
        }
        _setState(SubscriptionUiState.purchaseFailed);
        _emit(AppString.subscriptionStrings.purchaseFailed, isError: true);
        return false;
      case SubscriptionVerificationOutcome.linkedToOtherAccount:
        // The subscription is real but belongs to another app account.
        // Acknowledge it so the store stops re-delivering it, and tell
        // the user why they cannot use it here.
        if (purchase.pendingCompletePurchase) {
          await _completeSafely(purchase);
        }
        _blockedByOtherAccount = true;
        _setState(SubscriptionUiState.purchaseFailed);
        _emit(_linkedElsewhereMessage(), isError: true);
        return false;
      case SubscriptionVerificationOutcome.failed:
        // Not completed on purpose: the store re-delivers it next launch so
        // verification can be retried.
        _setState(SubscriptionUiState.purchaseFailed);
        _emit(AppString.subscriptionStrings.purchaseFailed, isError: true);
        return false;
      case SubscriptionVerificationOutcome.verified:
        break;
    }

    if (purchase.pendingCompletePurchase) {
      await _completeSafely(purchase);
    }
    await _markVerifiedAndRefresh();

    if (purchase.status == PurchaseStatus.restored) {
      // Final restore state/message is decided in _finishRestore.
      if (!isRestoring) {
        _setState(SubscriptionUiState.restoreSuccessful);
      }
    } else {
      _setState(SubscriptionUiState.purchaseSuccessful);
      _emit(AppString.subscriptionStrings.subscriptionActivated);
    }
    return true;
  }

  Future<void> _completeSafely(PurchaseDetails purchase) async {
    try {
      // StoreKit 2's finish never answers if the transaction can't be found;
      // don't let that leave the screen stuck in a loading state.
      await _service.complete(purchase).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Subscription: completePurchase failed: $e');
    }
  }

  void _finishRestore({required bool restored, bool failed = false}) {
    _restoreTimeout?.cancel();
    if (!isRestoring) return;
    if (failed) {
      _setState(SubscriptionUiState.restoreFailed);
      _emit(AppString.subscriptionStrings.restoreFailed, isError: true);
    } else if (restored) {
      _setState(SubscriptionUiState.restoreSuccessful);
      _emit(AppString.subscriptionStrings.restoreSuccess);
    } else if (_blockedByOtherAccount) {
      // The "linked to another account" message was already shown.
      _setState(SubscriptionUiState.nothingToRestore);
    } else {
      _setState(SubscriptionUiState.nothingToRestore);
      _emit(AppString.subscriptionStrings.nothingToRestore);
    }
  }

  // ── store account already owns the subscription ─────────────────────────

  String _linkedElsewhereMessage() => AppString.subscriptionStrings
      .linkedElsewhere(
        defaultTargetPlatform == TargetPlatform.iOS
            ? 'Apple ID'
            : 'Google Play',
      );

  /// The plugin reports Play's ITEM_ALREADY_OWNED / StoreKit's "already
  /// subscribed" only inside the error text.
  static bool _looksAlreadyOwned(IAPError? error) {
    final text = '${error?.code} ${error?.message} ${error?.details}'
        .toUpperCase();
    return text.contains('ALREADY_OWNED') ||
        text.contains('ALREADYOWNED') ||
        text.contains('ALREADY OWN') ||
        text.contains('ALREADY SUBSCRIBED');
  }

  /// Sends the owned purchase(s) to the backend as if restoring them:
  /// verified -> this account owns it; linked elsewhere -> blocked with a
  /// message. Returns true when it handled the purchase attempt.
  Future<bool> _resolveOwnedPurchases() async {
    final owned = await _service.findOwnedPurchases();
    if (_disposed || owned.isEmpty) return false;
    var verified = false;
    for (final purchase in owned) {
      if (await _handleSuccessfulPurchase(purchase)) verified = true;
    }
    if (!verified && _state == SubscriptionUiState.purchaseProcessing) {
      _setState(SubscriptionUiState.purchaseFailed);
      _emit(_linkedElsewhereMessage(), isError: true);
    }
    return true;
  }

  Future<void> _handleAlreadyOwned() async {
    if (await _resolveOwnedPurchases()) return;
    // Nothing found to verify: still explain it rather than "failed".
    _setState(SubscriptionUiState.purchaseFailed);
    _emit(_linkedElsewhereMessage(), isError: true);
  }

  // ── backend entitlement (premium_user) ─────────────────────────────────

  static const String _cacheBox = 'subscription_cache';

  /// `GET /subscriptions/me`: loads `premium_user` for the logged-in user. Safe
  /// to call often (app start, after a purchase). A failed request keeps the
  /// last known value.
  Future<void> refreshStatus() async {
    if (userID.isEmpty) {
      _applyStatus(SubscriptionStatus.free, null);
      return;
    }
    final uid = userID;
    if (_statusUserId != uid) {
      // A different user than last time: never show the previous one's state.
      _applyStatus(await _readCache(uid) ?? SubscriptionStatus.free, uid);
    }
    final fresh = await _repository.fetchStatus();
    if (_disposed || fresh == null || uid != userID) return;
    _applyStatus(fresh, uid);
    await _writeCache(uid, fresh);
  }

  /// Forget the entitlement (logout / account deletion).
  void reset() => _applyStatus(SubscriptionStatus.free, null);

  void _applyStatus(SubscriptionStatus status, String? forUser) {
    if (_disposed) return;
    _status = status;
    _statusUserId = forUser;
    AdFreeState.isAdFree.value = status.premiumUser;
    notifyListeners();
  }

  /// The backend just confirmed the purchase, so trust that even if
  /// `/subscriptions/me` has not caught up yet, then refresh.
  Future<void> _markVerifiedAndRefresh() async {
    if (!_status.premiumUser) {
      _applyStatus(
        _status.copyWith(premiumUser: true),
        userID.isEmpty ? _statusUserId : userID,
      );
    }
    await refreshStatus();
  }

  /// Uses the product IDs the backend returns for this platform.
  Future<void> _applyBackendPlans() async {
    final plans = await _repository.fetchPlans();
    if (plans.isEmpty) return;
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final ids = <SubscriptionPlan, String>{};
    for (final p in plans) {
      final plan = p.plan;
      final id = isIos ? p.appleProductId : p.googleProductId;
      if (plan != null && id != null) ids[plan] = id;
    }
    SubscriptionConfig.applyBackendProductIds(ids);
  }

  Future<SubscriptionStatus?> _readCache(String uid) async {
    try {
      final box = await Hive.openBox<String>(_cacheBox);
      final raw = box.get('status_$uid');
      if (raw == null) return null;
      final status = SubscriptionStatus.fromResponse(jsonDecode(raw));
      final expires = status.premiumExpiresAt;
      if (status.premiumUser &&
          expires != null &&
          expires.isBefore(DateTime.now())) {
        return SubscriptionStatus.free;
      }
      return status;
    } catch (e) {
      debugPrint('Subscription: cache read failed: $e');
      return null;
    }
  }

  Future<void> _writeCache(String uid, SubscriptionStatus status) async {
    try {
      final box = await Hive.openBox<String>(_cacheBox);
      await box.put('status_$uid', jsonEncode(status.toJson()));
    } catch (e) {
      debugPrint('Subscription: cache write failed: $e');
    }
  }

  /// Applies `premium_user` / `premium_expires_at` from a profile response
  /// (`/users/updateUser`). Ignored when the backend did not send the flag.
  void applyProfilePremium({bool? premiumUser, String? premiumExpiresAt}) {
    if (premiumUser == null || _disposed || userID.isEmpty) return;
    final expires =
        premiumExpiresAt == null ? null : DateTime.tryParse(premiumExpiresAt);
    final unchanged = _status.premiumUser == premiumUser &&
        (!premiumUser || _status.premiumExpiresAt == expires);
    if (unchanged) return;

    final next = SubscriptionStatus(
      planType: premiumUser ? 'premium' : 'free',
      premiumUser: premiumUser,
      premiumExpiresAt:
          premiumUser ? (expires ?? _status.premiumExpiresAt) : null,
      // The plan details only come from /subscriptions/me.
      activeSubscription: premiumUser ? _status.activeSubscription : null,
    );
    _applyStatus(next, userID);
    unawaited(_writeCache(userID, next));
  }

  /// One page of `GET /subscriptions/history`.
  Future<SubscriptionHistoryPage?> fetchHistory({
    int page = 1,
    int limit = 20,
  }) =>
      _repository.fetchHistory(page: page, limit: limit);

  // ── helpers ────────────────────────────────────────────────────────────

  void _setState(SubscriptionUiState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  void _emit(String message, {bool isError = false}) {
    if (_disposed) return;
    _eventSeq++;
    _eventMessage = message;
    _eventIsError = isError;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _restoreTimeout?.cancel();
    _purchaseSub?.cancel();
    super.dispose();
  }
}
