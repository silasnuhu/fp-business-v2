class GetAllStoriesModel {
  bool? status;
  Data? data;
  String? message;
  bool? toast;

  GetAllStoriesModel({this.status, this.data, this.message, this.toast});

  GetAllStoriesModel.fromJson(Map<String, dynamic> json) {
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
  List<RecentStories>? recentStories;
  List<ViewedStories>? viewedStories;
  List<MyStories>? myStories;

  Data({this.recentStories, this.viewedStories, this.myStories});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['recent_stories'] != null) {
      recentStories = <RecentStories>[];
      json['recent_stories'].forEach((v) {
        recentStories!.add(RecentStories.fromJson(v));
      });
    }
    if (json['viewed_stories'] != null) {
      viewedStories = <ViewedStories>[];
      json['viewed_stories'].forEach((v) {
        viewedStories!.add(ViewedStories.fromJson(v));
      });
    }
    if (json['my_stories'] != null) {
      myStories = <MyStories>[];
      json['my_stories'].forEach((v) {
        myStories!.add(MyStories.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (recentStories != null) {
      data['recent_stories'] = recentStories!.map((v) => v.toJson()).toList();
    }
    if (viewedStories != null) {
      data['viewed_stories'] = viewedStories!.map((v) => v.toJson()).toList();
    }
    if (myStories != null) {
      data['my_stories'] = myStories!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class MyStories {
  String? media;
  String? thumbnail;
  int? storyId;
  String? caption;
  String? storyType;
  String? expiresAt;
  List<String>? tagged;
  List<String>? views;
  String? createdAt;
  String? updatedAt;
  int? userId;

  MyStories({
    this.media,
    this.thumbnail,
    this.storyId,
    this.caption,
    this.storyType,
    this.expiresAt,
    this.tagged,
    this.views,
    this.createdAt,
    this.updatedAt,
    this.userId,
  });

  MyStories.fromJson(Map<String, dynamic> json) {
    media = json['media'];
    thumbnail = json['thumbnail'];
    storyId = json['story_id'];
    caption = json['caption'];
    storyType = json['story_type'];
    expiresAt = json['expiresAt'];
    tagged = json['views'].cast<String>();
    views = json['views'].cast<String>();
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    userId = json['user_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['media'] = media;
    data['thumbnail'] = thumbnail;
    data['story_id'] = storyId;
    data['caption'] = caption;
    data['story_type'] = storyType;
    data['expiresAt'] = expiresAt;
    data['tagged'] = tagged;
    data['views'] = views;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['user_id'] = userId;
    return data;
  }
}

class RecentStories {
  int? userId;
  String? fullName;
  String? firstName;
  String? lastName;
  String? userName;
  String? email;
  String? countryCode;
  String? mobileNum;
  String? loginType;
  String? profilePic;
  String? gender;
  String? country;
  String? countryShortName;
  String? state;
  String? city;
  String? bio;
  bool? profileVerificationStatus;
  bool? loginVerificationStatus;
  bool? isPrivate;
  bool? isAdmin;
  List<String>? platforms;
  bool? blokedByAdmin;
  String? createdAt;
  String? updatedAt;
  List<Stories>? stories;
  int? storyCount;
  int? viewedCount;
  String? userType;

  RecentStories({
    this.userId,
    this.fullName,
    this.firstName,
    this.lastName,
    this.userName,
    this.email,
    this.countryCode,
    this.mobileNum,
    this.loginType,
    this.profilePic,
    this.gender,
    this.country,
    this.countryShortName,
    this.state,
    this.city,
    this.bio,
    this.profileVerificationStatus,
    this.loginVerificationStatus,
    this.isPrivate,
    this.isAdmin,
    this.platforms,
    this.blokedByAdmin,
    this.createdAt,
    this.updatedAt,
    this.stories,
    this.storyCount,
    this.viewedCount,
    this.userType,
  });

  RecentStories.fromJson(Map<String, dynamic> json) {
    userId = json['user_id'];
    fullName = json['full_name'];
    firstName = json['first_name'];
    lastName = json['last_name'];
    userName = json['user_name'];
    email = json['email'];
    countryCode = json['country_code'];
    mobileNum = json['mobile_num'];
    loginType = json['login_type'];
    profilePic = json['profile_pic'];
    gender = json['gender'];
    country = json['country'];
    countryShortName = json['country_short_name'];
    state = json['state'];
    city = json['city'];
    bio = json['bio'];
    profileVerificationStatus = json['profile_verification_status'];
    loginVerificationStatus = json['login_verification_status'];
    isPrivate = json['is_private'];
    isAdmin = json['is_admin'];
    platforms = json['platforms'].cast<String>();
    blokedByAdmin = json['bloked_by_admin'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    if (json['stories'] != null) {
      stories = <Stories>[];
      json['stories'].forEach((v) {
        stories!.add(Stories.fromJson(v));
      });
    }
    storyCount = json['storyCount'];
    viewedCount = json['viewedCount'];
    userType = json['userType'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_id'] = userId;
    data['full_name'] = fullName;
    data['first_name'] = firstName;
    data['last_name'] = lastName;
    data['user_name'] = userName;
    data['email'] = email;
    data['country_code'] = countryCode;
    data['mobile_num'] = mobileNum;
    data['login_type'] = loginType;
    data['profile_pic'] = profilePic;
    data['gender'] = gender;
    data['country'] = country;
    data['country_short_name'] = countryShortName;
    data['state'] = state;
    data['city'] = city;
    data['bio'] = bio;
    data['profile_verification_status'] = profileVerificationStatus;
    data['login_verification_status'] = loginVerificationStatus;
    data['is_private'] = isPrivate;
    data['is_admin'] = isAdmin;
    data['platforms'] = platforms;
    data['bloked_by_admin'] = blokedByAdmin;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    if (stories != null) {
      data['stories'] = stories!.map((v) => v.toJson()).toList();
    }
    data['storyCount'] = storyCount;
    data['viewedCount'] = viewedCount;
    data['userType'] = userType;
    return data;
  }
}

class Stories {
  String? media;
  String? thumbnail;
  int? storyId;
  int? userId;
  String? caption;
  String? createdAt;
  String? updatedAt;
  String? storyType;

  Stories({
    this.media,
    this.thumbnail,
    this.storyId,
    this.userId,
    this.caption,
    this.createdAt,
    this.updatedAt,
    this.storyType,
  });

  Stories.fromJson(Map<String, dynamic> json) {
    media = json['media'];
    thumbnail = json['thumbnail'];
    storyId = json['story_id'];
    userId = json['user_id'];
    caption = json['caption'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    storyType = json['story_type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['media'] = media;
    data['thumbnail'] = thumbnail;
    data['story_id'] = storyId;
    data['user_id'] = userId;
    data['caption'] = caption;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['story_type'] = storyType;
    return data;
  }
}

class ViewedStories {
  int? userId;
  String? fullName;
  String? firstName;
  String? lastName;
  String? userName;
  String? email;
  String? countryCode;
  String? mobileNum;
  String? loginType;
  String? profilePic;
  String? gender;
  String? country;
  String? countryShortName;
  String? state;
  String? city;
  String? bio;
  bool? profileVerificationStatus;
  bool? loginVerificationStatus;
  bool? isPrivate;
  bool? isAdmin;
  List<String>? platforms;
  bool? blokedByAdmin;
  String? createdAt;
  String? updatedAt;
  List<Stories>? stories;
  int? storyCount;
  int? viewedCount;
  String? userType;

  ViewedStories({
    this.userId,
    this.fullName,
    this.firstName,
    this.lastName,
    this.userName,
    this.email,
    this.countryCode,
    this.mobileNum,
    this.loginType,
    this.profilePic,
    this.gender,
    this.country,
    this.countryShortName,
    this.state,
    this.city,
    this.bio,
    this.profileVerificationStatus,
    this.loginVerificationStatus,
    this.isPrivate,
    this.isAdmin,
    this.platforms,
    this.blokedByAdmin,
    this.createdAt,
    this.updatedAt,
    this.stories,
    this.storyCount,
    this.viewedCount,
    this.userType,
  });

  ViewedStories.fromJson(Map<String, dynamic> json) {
    userId = json['user_id'];
    fullName = json['full_name'];
    firstName = json['first_name'];
    lastName = json['last_name'];
    userName = json['user_name'];
    email = json['email'];
    countryCode = json['country_code'];
    mobileNum = json['mobile_num'];
    loginType = json['login_type'];
    profilePic = json['profile_pic'];
    gender = json['gender'];
    country = json['country'];
    countryShortName = json['country_short_name'];
    state = json['state'];
    city = json['city'];
    bio = json['bio'];
    profileVerificationStatus = json['profile_verification_status'];
    loginVerificationStatus = json['login_verification_status'];
    isPrivate = json['is_private'];
    isAdmin = json['is_admin'];
    platforms = json['platforms']?.cast<String>();
    blokedByAdmin = json['bloked_by_admin'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    if (json['stories'] != null) {
      stories = <Stories>[];
      json['stories'].forEach((v) {
        stories!.add(Stories.fromJson(v));
      });
    }
    storyCount = json['storyCount'];
    viewedCount = json['viewedCount'];
    userType = json['userType'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_id'] = userId;
    data['full_name'] = fullName;
    data['first_name'] = firstName;
    data['last_name'] = lastName;
    data['user_name'] = userName;
    data['email'] = email;
    data['country_code'] = countryCode;
    data['mobile_num'] = mobileNum;
    data['login_type'] = loginType;
    data['profile_pic'] = profilePic;
    data['gender'] = gender;
    data['country'] = country;
    data['country_short_name'] = countryShortName;
    data['state'] = state;
    data['city'] = city;
    data['bio'] = bio;
    data['profile_verification_status'] = profileVerificationStatus;
    data['login_verification_status'] = loginVerificationStatus;
    data['is_private'] = isPrivate;
    data['is_admin'] = isAdmin;
    data['platforms'] = platforms;
    data['bloked_by_admin'] = blokedByAdmin;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    if (stories != null) {
      data['stories'] = stories!.map((v) => v.toJson()).toList();
    }
    data['storyCount'] = storyCount;
    data['viewedCount'] = viewedCount;
    data['userType'] = userType;
    return data;
  }
}
