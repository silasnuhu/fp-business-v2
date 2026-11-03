class UserProfileModel {
  bool? status;
  Data? data;
  String? message;
  bool? toast;

  UserProfileModel({this.status, this.data, this.message, this.toast});

  UserProfileModel.fromJson(Map<String, dynamic> json) {
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

// Verified directly against actual backend source
// (UsersService.toUserData(), src/users/users.service.ts) rather than the
// migration guide, which guessed several field names/presence wrong for
// this endpoint. `updateUser` bypasses NEW's global DTO/ValidationPipe
// entirely (reads @Req() directly) and returns exactly the same 15-field
// `toUserData()` shape as verify-OTP — see otp_model.dart's User class for
// the identical mapping. Fields the OLD/guessed model expected that do NOT
// actually exist anywhere in this response: `selfie`, `gender`,
// `country_short_name`, `createdAt`, `updatedAt` — kept below as always-null
// for compile compatibility with existing readers, not because the backend
// sends them. Real fields previously unread, now added: `themeColor`,
// `blockedByAdmin` (backend key is misspelled `bloked_by_admin`),
// `deletedAt`, `avatarPath`. `userId` stays `int?` — `updateUser` is one of
// the two legacy-compatibility endpoints that still returns a numeric ID
// (confirmed: `user_id: Number(user.userId)` server-side).
class Data {
  String? userName;
  // Backend key is `email`, not `email_id` — `email_id` only appears on
  // request DTOs, never in this response. Kept as a defensive fallback.
  String? email;
  String? mobileNum;
  String? profilePic;
  // Not present in toUserData() — always null. Superseded by `avatarPath`
  // below if a distinct selfie concept is ever needed again.
  String? selfie;
  int? userId;
  String? fullName;
  String? firstName;
  String? lastName;
  String? countryCode;
  // Not present in toUserData() — always null; NEW has no gender field on
  // User at all as far as this endpoint is concerned.
  String? gender;
  String? country;
  // Not present in toUserData() — always null (it IS a writable field on
  // update, just never echoed back by this endpoint).
  String? countryShortName;
  String? bio;
  // Not present in toUserData() — always null.
  String? createdAt;
  String? updatedAt;
  String? themeColor;
  bool? blockedByAdmin;
  String? deletedAt;
  String? avatarPath;
  // Subscription state echoed by the backend (`premium_user`,
  // `premium_expires_at`). Null when the backend does not send them.
  bool? premiumUser;
  String? premiumExpiresAt;

  Data({
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
    this.createdAt,
    this.updatedAt,
    this.themeColor,
    this.blockedByAdmin,
    this.deletedAt,
    this.avatarPath,
    this.premiumUser,
    this.premiumExpiresAt,
  });

  Data.fromJson(Map<String, dynamic> json) {
    userName = json['user_name'];
    email = json['email_id'] ?? json['email'];
    mobileNum = json['mobile_num'];
    profilePic = json['profile_pic'];
    selfie = json['selfie'];
    userId = json['user_id'];
    fullName = json['full_name'];
    firstName = json['first_name'];
    lastName = json['last_name'];
    countryCode = json['country_code'];
    gender = json['gender'];
    country = json['country'];
    countryShortName = json['country_short_name'];
    bio = json['bio'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    themeColor = json['theme_color'];
    blockedByAdmin = json['bloked_by_admin'];
    deletedAt = json['deleted_at']?.toString();
    avatarPath = json['avatar_path'];
    final premium = json['premium_user'];
    premiumUser = premium is bool ? premium : (premium is num ? premium != 0 : null);
    premiumExpiresAt = json['premium_expires_at']?.toString();
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
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['theme_color'] = themeColor;
    data['bloked_by_admin'] = blockedByAdmin;
    data['deleted_at'] = deletedAt;
    data['avatar_path'] = avatarPath;
    data['premium_user'] = premiumUser;
    data['premium_expires_at'] = premiumExpiresAt;
    return data;
  }
}
