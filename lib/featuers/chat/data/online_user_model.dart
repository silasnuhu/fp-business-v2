class OnlineUsersModel {
  List<OnlineUsers>? onlineUsers;

  OnlineUsersModel({this.onlineUsers});

  OnlineUsersModel.fromJson(Map<String, dynamic> json) {
    onlineUsers = json["onlineUsers"] == null
        ? null
        : (json["onlineUsers"] as List)
            .map((e) => OnlineUsers.fromJson(e))
            .toList();
  }

  static List<OnlineUsersModel> fromList(List<Map<String, dynamic>> list) {
    return list.map(OnlineUsersModel.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (onlineUsers != null) {
      data["onlineUsers"] = onlineUsers?.map((e) => e.toJson()).toList();
    }
    return data;
  }
}

class OnlineUsers {
  String? mobileNum;
  String? profilePic;
  String? dob;
  int? userId;
  String? fullName;
  String? userName;
  String? email;
  String? countryCode;
  String? socketId;
  String? loginType;
  int? socialId;
  String? gender;
  String? country;
  String? state;
  String? city;
  String? bio;
  bool? profileVerificationStatus;
  bool? loginVerificationStatus;
  bool? isPrivate;
  bool? isAdmin;
  String? createdAt;
  String? updatedAt;
  bool? isOnline;

  OnlineUsers({
    this.mobileNum,
    this.profilePic,
    this.dob,
    this.userId,
    this.fullName,
    this.userName,
    this.email,
    this.countryCode,
    this.socketId,
    this.loginType,
    this.socialId,
    this.gender,
    this.country,
    this.state,
    this.city,
    this.bio,
    this.profileVerificationStatus,
    this.loginVerificationStatus,
    this.isPrivate,
    this.isAdmin,
    this.createdAt,
    this.updatedAt,
    this.isOnline,
  });

  OnlineUsers.fromJson(Map<String, dynamic> json) {
    mobileNum = json["mobile_num"];
    profilePic = json["profile_pic"];
    dob = json["dob"];
    userId = json["user_id"];
    fullName = json["full_name"];
    userName = json["user_name"];
    email = json["email"];
    countryCode = json["country_code"];
    socketId = json["socket_id"];
    loginType = json["login_type"];
    socialId = json["social_id"];
    gender = json["gender"];
    country = json["country"];
    state = json["state"];
    city = json["city"];
    bio = json["bio"];
    profileVerificationStatus = json["profile_verification_status"];
    loginVerificationStatus = json["login_verification_status"];
    isPrivate = json["is_private"];
    isAdmin = json["is_admin"];
    createdAt = json["createdAt"];
    updatedAt = json["updatedAt"];
    isOnline = json["isOnline"];
  }

  static List<OnlineUsers> fromList(List<Map<String, dynamic>> list) {
    return list.map(OnlineUsers.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["mobile_num"] = mobileNum;
    data["profile_pic"] = profilePic;
    data["dob"] = dob;
    data["user_id"] = userId;
    data["full_name"] = fullName;
    data["user_name"] = userName;
    data["email"] = email;
    data["country_code"] = countryCode;
    data["socket_id"] = socketId;
    data["login_type"] = loginType;
    data["social_id"] = socialId;
    data["gender"] = gender;
    data["country"] = country;
    data["state"] = state;
    data["city"] = city;
    data["bio"] = bio;
    data["profile_verification_status"] = profileVerificationStatus;
    data["login_verification_status"] = loginVerificationStatus;
    data["is_private"] = isPrivate;
    data["is_admin"] = isAdmin;
    data["createdAt"] = createdAt;
    data["updatedAt"] = updatedAt;
    data["isOnline"] = isOnline;
    return data;
  }
}
