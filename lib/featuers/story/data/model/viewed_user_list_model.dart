class ViewedUserListModel {
  final bool? status;
  final Data? data;
  final String? message;
  final bool? toast;

  ViewedUserListModel({this.status, this.data, this.message, this.toast});

  factory ViewedUserListModel.fromJson(Map<String, dynamic> json) {
    return ViewedUserListModel(
      status: json['status'] ?? false,
      data:
          json['data'] != null
              ? Data.fromJson(json['data'] as Map<String, dynamic>)
              : null,
      message: json['message'] ?? "",
      toast: json['toast'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'data': data?.toJson(),
    'message': message,
    'toast': toast,
  };
}

class Data {
  final int? storyId;
  final String? caption;
  final String? media;
  final String? storyType;
  final String? expiresAt;
  final List<Views>? views;
  final String? createdAt;
  final String? updatedAt;
  final int? userId;

  Data({
    this.storyId,
    this.caption,
    this.media,
    this.storyType,
    this.expiresAt,
    this.views,
    this.createdAt,
    this.updatedAt,
    this.userId,
  });

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      storyId: json['story_id'] ?? 0,
      caption: json['caption'] ?? "",
      media: json['media'] ?? "",
      storyType: json['story_type'] ?? "",
      expiresAt: json['expiresAt'] ?? "",
      views:
          (json['views'] as List<dynamic>?)
              ?.map((v) => Views.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] ?? "",
      updatedAt: json['updatedAt'] ?? "",
      userId: json['user_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'story_id': storyId,
    'caption': caption,
    'media': media,
    'story_type': storyType,
    'expiresAt': expiresAt,
    'views': views?.map((v) => v.toJson()).toList(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'user_id': userId,
  };
}

class Views {
  final int? userId;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? userName;
  final String? email;
  final String? countryCode;
  final List<String>? socketIds;
  final String? mobileNum;
  final int? otp;
  final String? password;
  final String? loginType;
  final String? profilePic;
  final String? selfie;
  final String? gender;
  final String? country;
  final String? countryShortName;
  final String? state;
  final String? city;
  final String? bio;
  final String? deviceToken;
  final bool? profileVerificationStatus;
  final bool? loginVerificationStatus;
  final bool? isPrivate;
  final bool? isAdmin;
  final List<String>? platforms;
  final bool? blokedByAdmin;
  final String? createdAt;
  final String? updatedAt;
  final String? viewedAt;

  Views({
    this.userId,
    this.fullName,
    this.firstName,
    this.lastName,
    this.userName,
    this.email,
    this.countryCode,
    this.socketIds,
    this.mobileNum,
    this.otp,
    this.password,
    this.loginType,
    this.profilePic,
    this.selfie,
    this.gender,
    this.country,
    this.countryShortName,
    this.state,
    this.city,
    this.bio,
    this.deviceToken,
    this.profileVerificationStatus,
    this.loginVerificationStatus,
    this.isPrivate,
    this.isAdmin,
    this.platforms,
    this.blokedByAdmin,
    this.createdAt,
    this.updatedAt,
    this.viewedAt,
  });

  factory Views.fromJson(Map<String, dynamic> json) {
    return Views(
      userId: json['user_id'] ?? 0,
      fullName: json['full_name'] ?? "",
      firstName: json['first_name'] ?? "",
      lastName: json['last_name'] ?? "",
      userName: json['user_name'] ?? "",
      email: json['email'] ?? "",
      countryCode: json['country_code'] ?? "",
      socketIds:
          (json['socket_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mobileNum: json['mobile_num'] ?? "",
      otp: json['otp'] ?? 0,
      password: json['password'] ?? "",
      loginType: json['login_type'] ?? "",
      profilePic: json['profile_pic'] ?? "",
      selfie: json['selfie'] ?? "",
      gender: json['gender'] ?? "",
      country: json['country'] ?? "",
      countryShortName: json['country_short_name'] ?? "",
      state: json['state'] ?? "",
      city: json['city'] ?? "",
      bio: json['bio'] ?? "",
      deviceToken: json['device_token'] ?? "",
      profileVerificationStatus: json['profile_verification_status'] ?? false,
      loginVerificationStatus: json['login_verification_status'] ?? false,
      isPrivate: json['is_private'] ?? false,
      isAdmin: json['is_admin'] ?? false,
      platforms:
          (json['platforms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      blokedByAdmin: json['bloked_by_admin'] ?? false,
      createdAt: json['createdAt'] ?? "",
      updatedAt: json['updatedAt'] ?? "",
      viewedAt: json['viewed_at'] ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'full_name': fullName,
    'first_name': firstName,
    'last_name': lastName,
    'user_name': userName,
    'email': email,
    'country_code': countryCode,
    'socket_ids': socketIds,
    'mobile_num': mobileNum,
    'otp': otp,
    'password': password,
    'login_type': loginType,
    'profile_pic': profilePic,
    'selfie': selfie,
    'gender': gender,
    'country': country,
    'country_short_name': countryShortName,
    'state': state,
    'city': city,
    'bio': bio,
    'device_token': deviceToken,
    'profile_verification_status': profileVerificationStatus,
    'login_verification_status': loginVerificationStatus,
    'is_private': isPrivate,
    'is_admin': isAdmin,
    'platforms': platforms,
    'bloked_by_admin': blokedByAdmin,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'viewed_at': viewedAt,
  };
}
