import 'package:whoxa/core/api/id_codec.dart';

class VerifyOTPModel {
  bool? status;
  Data? data;
  String? message;
  bool? toast;

  VerifyOTPModel({this.status, this.data, this.message, this.toast});

  VerifyOTPModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
    message = json['message'];
    toast = json['toast'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['message'] = message;
    data['toast'] = toast;
    return data;
  }
}

class Data {
  String? token;
  User? user;

  Data({this.token, this.user});

  Data.fromJson(Map<String, dynamic> json) {
    token = json['token'];
    user = json['user'] != null ? User.fromJson(json['user']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['token'] = token;
    if (user != null) {
      data['user'] = user!.toJson();
    }
    return data;
  }
}

// Verified directly against actual backend source
// (UsersService.toUserData(), src/users/users.service.ts) rather than the
// migration guide's guess. NEW's verify-OTP and `updateUser` share the
// exact same 15-field `toUserData()` shape — see user_profile_model.dart's
// Data class for the identical mapping. Confirmed dropped from the raw
// User row: platforms, is_admin, is_private, dob, state, city,
// device_token, socket_ids, ip_address, login_type,
// profile_verification_status, login_verification_status, password, otp.
// Fields the guide guessed were present but actually AREN'T in this
// response at all: `selfie`, `gender`, `countryShortName`, `isDemo`,
// `createdAt`, `updatedAt` — kept below as always-null for compile
// compatibility with existing readers. Real fields previously unread, now
// added: `themeColor`, `blockedByAdmin` (backend key is misspelled
// `bloked_by_admin`), `deletedAt`, `avatarPath`.
class User {
  String? userName;
  // Backend key is `email`, not `email_id` — `email_id` only appears on
  // request DTOs, never in this response. Kept as a defensive fallback.
  String? email;
  String? mobileNum;
  String? profilePic;
  // Not present in toUserData() — always null.
  String? selfie;
  // `user_id` is actually `Number(user.userId)` server-side (a plain int,
  // not a BigInt-safe string) — verify-OTP IS on the legacy-numeric-id
  // list alongside `updateUser`/`find-user`, contrary to the guide's claim.
  // IdCodec still works correctly here (stringifies either way).
  String? userId;
  String? fullName;
  String? firstName;
  String? lastName;
  String? countryCode;
  // Not present in toUserData() — always null.
  String? gender;
  String? country;
  // Not present in toUserData() — always null.
  String? countryShortName;
  String? bio;
  // Not present in toUserData() — always null; NEW has no demo-account
  // flag in this response.
  bool? isDemo;
  // Not present in toUserData() — always null.
  String? createdAt;
  String? updatedAt;
  String? themeColor;
  bool? blockedByAdmin;
  String? deletedAt;
  String? avatarPath;

  User({
    this.userName,
    this.email,
    this.mobileNum,
    this.profilePic,
    this.selfie,
    this.userId,
    this.fullName,
    this.firstName,
    this.lastName,
    this.countryCode,
    this.gender,
    this.country,
    this.countryShortName,
    this.bio,
    this.isDemo,
    this.createdAt,
    this.updatedAt,
    this.themeColor,
    this.blockedByAdmin,
    this.deletedAt,
    this.avatarPath,
  });

  User.fromJson(Map<String, dynamic> json) {
    userName = json['user_name'];
    email = json['email_id'] ?? json['email'];
    mobileNum = json['mobile_num'];
    profilePic = json['profile_pic'];
    selfie = json['selfie'];
    userId = IdCodec.toIdOrNull(json['user_id']);
    fullName = json['full_name'];
    firstName = json['first_name'];
    lastName = json['last_name'];
    countryCode = json['country_code'];
    gender = json['gender'];
    country = json['country'];
    countryShortName = json['country_short_name'];
    bio = json['bio'];
    isDemo = json['is_demo'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    themeColor = json['theme_color'];
    blockedByAdmin = json['bloked_by_admin'];
    deletedAt = json['deleted_at']?.toString();
    avatarPath = json['avatar_path'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_name'] = userName;
    data['email_id'] = email;
    data['mobile_num'] = mobileNum;
    data['profile_pic'] = profilePic;
    data['selfie'] = selfie;
    data['user_id'] = userId;
    data['full_name'] = fullName;
    data['first_name'] = firstName;
    data['last_name'] = lastName;
    data['country_code'] = countryCode;
    data['gender'] = gender;
    data['country'] = country;
    data['country_short_name'] = countryShortName;
    data['bio'] = bio;
    data['is_demo'] = isDemo;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['theme_color'] = themeColor;
    data['bloked_by_admin'] = blockedByAdmin;
    data['deleted_at'] = deletedAt;
    data['avatar_path'] = avatarPath;
    return data;
  }
}
