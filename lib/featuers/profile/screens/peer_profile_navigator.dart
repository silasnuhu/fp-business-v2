import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:whoxa/featuers/business/data/repositories/business_repository.dart';
import 'package:whoxa/featuers/profile/screens/user_profile_view.dart';
import 'package:whoxa/featuers/profile/screens/user_profile_view_business.dart';

/// Picks the right contact-info screen for a peer: the business profile view
/// when `GET /business/:userId` says `is_business`, the regular one otherwise.
/// The endpoint never 404s, so any failure just falls back to the regular view.
class PeerProfileNavigator {
  PeerProfileNavigator._();

  static Future<Widget> buildScreen({
    required int userId,
    int? chatId,
    bool blockFlag = false,
    String? chatName,
    bool isAdminChat = false,
  }) async {
    var isBusiness = false;
    if (userId > 0 && !isAdminChat) {
      try {
        isBusiness =
            (await GetIt.instance<BusinessRepository>().getBusinessByUserId(
              userId,
            )).isBusiness;
      } catch (_) {}
    }

    if (isBusiness) {
      return UserProfileViewBusiness(
        userId: userId,
        chatId: chatId,
        blockFlag: blockFlag,
        chatName: chatName,
      );
    }
    return UserProfileView(
      userId: userId,
      chatId: chatId,
      blockFlag: blockFlag,
      chatName: chatName,
      isAdminChat: isAdminChat,
    );
  }
}
