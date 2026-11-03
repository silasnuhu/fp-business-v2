import 'package:flutter/foundation.dart';

/// Whether the current user has a premium subscription and so should see no
/// ads. Updated by `SubscriptionProvider` (from the backend `premium_user`
/// flag); read by the ad widgets/services, which live outside the widget tree
/// scope of that provider.
class AdFreeState {
  AdFreeState._();

  static final ValueNotifier<bool> isAdFree = ValueNotifier<bool>(false);
}
