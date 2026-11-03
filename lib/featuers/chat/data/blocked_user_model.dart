import 'package:whoxa/core/api/id_codec.dart';

// NEW's block-list endpoint (`GET /users/blocked`) returns a bare,
// unpaginated array of the blocked users' public profiles — a completely
// different shape from OLD's `{Records, Pagination}` of raw `Block` join
// rows, each wrapping a raw `blocked` User row (§4.5 of the migration
// guide: "Different shape entirely"). Verified directly against actual
// backend source (UsersService.toPublicUser(), src/users/users.service.ts)
// rather than the guide's guess: this is a DIFFERENT, camelCase-keyed
// mapper from the snake_case `toUserData()` used by verify-OTP/updateUser —
// `userId`/`userName`/`firstName`/etc, not `user_id`/`user_name`/etc.
//
// Records are still wrapped in BlockedUserRecord (with blockId/approved/
// createdAt left null — NEW's response carries no join-row metadata at all
// anymore) purely so chat_provider.dart's existing blockedId/blocked-keyed
// cache logic doesn't need to change.
class BlockedUserModel {
  List<BlockedUserRecord>? records;

  BlockedUserModel({this.records});

  factory BlockedUserModel.fromJson(dynamic json) {
    final List<dynamic> items = json is List ? json : const [];
    return BlockedUserModel(
      records:
          items.map((item) {
            final profile = BlockedUserData.fromJson(
              item as Map<String, dynamic>,
            );
            return BlockedUserRecord(blockedId: profile.userId, blocked: profile);
          }).toList(),
    );
  }
}

// blockId/approved/userId(blocker)/createdAt/updatedAt are unavailable in
// NEW's response (no join-row metadata comes back at all) and are always
// null now — kept only so existing chat_provider.dart code compiles
// unchanged.
class BlockedUserRecord {
  int? blockId;
  bool? approved;
  String? createdAt;
  String? updatedAt;
  int? userId;
  int? blockedId;
  BlockedUserData? blocked;

  BlockedUserRecord({
    this.blockId,
    this.approved,
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.blockedId,
    this.blocked,
  });
}

// Field set trimmed to what's actually consumed (block_list.dart) plus the
// same curated fields confirmed for verify-OTP (§3.5) — NOT a confirmed
// contract for this specific endpoint, see file-level comment above.
class BlockedUserData {
  String? userName;
  String? email;
  String? mobileNum;
  String? profilePic;
  // NEW returns a BigInt-safe string id; coerced back to int here so
  // call sites (blockUnblockUser(int, int), still int-typed pending a
  // broader ID-type migration in a later phase) don't need to change yet.
  int? userId;
  String? firstName;
  String? lastName;
  String? fullName;
  String? countryCode;
  // `premiumUser` from the block-list payload (blue tick); null if absent.
  bool? premiumUser;

  BlockedUserData({
    this.userName,
    this.email,
    this.mobileNum,
    this.profilePic,
    this.userId,
    this.firstName,
    this.lastName,
    this.fullName,
    this.countryCode,
    this.premiumUser,
  });

  factory BlockedUserData.fromJson(Map<String, dynamic> json) {
    return BlockedUserData(
      userName: json['userName'],
      email: json['email'],
      mobileNum: json['mobileNum']?.toString(),
      profilePic: json['profilePic'],
      userId: int.tryParse(IdCodec.toId(json['userId'])),
      firstName: json['firstName'],
      lastName: json['lastName'],
      fullName: json['fullName'],
      countryCode: json['countryCode'],
      premiumUser: json['premiumUser'] is bool ? json['premiumUser'] as bool : null,
    );
  }
}