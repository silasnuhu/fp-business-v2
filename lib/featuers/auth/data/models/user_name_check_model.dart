class UserNameCheckModel {
  bool? status;
  Data? data;
  String? message;
  bool? toast;

  UserNameCheckModel({this.status, this.data, this.message, this.toast});

  UserNameCheckModel.fromJson(Map<String, dynamic> json) {
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
  List<Records>? records;
  Pagination? pagination;

  Data({this.records, this.pagination});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['Records'] != null) {
      records = <Records>[];
      json['Records'].forEach((v) {
        records!.add(Records.fromJson(v));
      });
    }
    pagination = json['Pagination'] != null
        ? Pagination.fromJson(json['Pagination'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (records != null) {
      data['Records'] = records!.map((v) => v.toJson()).toList();
    }
    if (pagination != null) {
      data['Pagination'] = pagination!.toJson();
    }
    return data;
  }
}

class Records {
  String? userName;
  String? email;
  String? mobileNum;
  String? profilePic;
  String? updatedAt;
  int? userId;
  String? fullName;
  String? countryCode;
  String? country;
  String? gender;
  String? bio;
  bool? profileVerificationStatus;
  bool? loginVerificationStatus;
  String? firstName;
  String? lastName;
  String? userType;
  bool? isBusiness;
  String? bannerImage;
  String? description;
  String? createdAt;
  String? website;
  String? location;
  double? latitude;
  double? longitude;
  String? companyName;
  String? instagramLink;
  String? facebookLink;
  String? youtubeLink;
  String? linkedinLink;
  String? vkLink;
  Map<String, dynamic>? businessHours;
  String? openTime;
  String? closeTime;
  bool? appointmentsOnly;
  bool? alwaysOpen;
  bool? byAppointmentsOnly;
  int? profileSetupStep;
  Map<String, dynamic>? categories;
  List<Catalog>? catalogs;

  Records({
    this.userName,
    this.email,
    this.mobileNum,
    this.profilePic,
    this.updatedAt,
    this.userId,
    this.fullName,
    this.countryCode,
    this.country,
    this.gender,
    this.bio,
    this.profileVerificationStatus,
    this.loginVerificationStatus,
    this.firstName,
    this.lastName,
    this.userType,
    this.isBusiness,
    this.bannerImage,
    this.description,
    this.createdAt,
    this.website,
    this.location,
    this.latitude,
    this.longitude,
    this.companyName,
    this.instagramLink,
    this.facebookLink,
    this.youtubeLink,
    this.linkedinLink,
    this.vkLink,
    this.businessHours,
    this.openTime,
    this.closeTime,
    this.appointmentsOnly,
    this.alwaysOpen,
    this.byAppointmentsOnly,
    this.profileSetupStep,
    this.categories,
    this.catalogs,
  });

  Records.fromJson(Map<String, dynamic> json) {
    userName = json['user_name'];
    email = json['email'];
    mobileNum = json['mobile_num'];
    profilePic = json['profile_pic'];
    updatedAt = json['updatedAt'];
    userId = json['user_id'];
    fullName = json['full_name'];
    countryCode = json['country_code'];
    country = json['country'];
    gender = json['gender'];
    bio = json['bio'];
    profileVerificationStatus = json['profile_verification_status'];
    loginVerificationStatus = json['login_verification_status'];
    firstName = json['first_name'];
    lastName = json['last_name'];
    userType = json['user_type'];
    isBusiness = json['is_business'] == true || json['user_type'] == 'business';
    bannerImage = json['banner_image'];
    description = json['description'];
    createdAt = json['createdAt'];
    website = json['website'];
    location = json['location'];
    latitude = json['latitude'] != null
        ? (json['latitude'] is String
              ? double.tryParse(json['latitude'])
              : json['latitude']?.toDouble())
        : null;
    longitude = json['longitude'] != null
        ? (json['longitude'] is String
              ? double.tryParse(json['longitude'])
              : json['longitude']?.toDouble())
        : null;
    facebookLink = json['facebook_link'];
    youtubeLink = json['youtube_link'];
    linkedinLink = json['linkedin_link'];
    vkLink = json['vk_link'];

    // Handle business_hours as either Map or List (API inconsistency)
    final businessHoursJson = json['business_hours'];
    if (businessHoursJson is Map<String, dynamic>) {
      businessHours = businessHoursJson;
    } else if (businessHoursJson is List && businessHoursJson.isEmpty) {
      businessHours = <String, dynamic>{}; // Convert empty array to empty map
    } else {
      // businessHours = businessHoursJson as Map<String, dynamic>?;
      businessHours = null;
    }

    openTime = json['open_time'];
    closeTime = json['close_time'];
    appointmentsOnly = json['appointments_only'];
    alwaysOpen = json['always_open'];
    byAppointmentsOnly = json['by_appointments_only'];
    profileSetupStep = json['profile_setup_step'];
    categories = json['categories'] as Map<String, dynamic>?;

    // Parse catalogs array
    if (json['catalogs'] != null) {
      catalogs = <Catalog>[];
      json['catalogs'].forEach((v) {
        catalogs!.add(Catalog.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_name'] = userName;
    data['email'] = email;
    data['mobile_num'] = mobileNum;
    data['profile_pic'] = profilePic;
    data['updatedAt'] = updatedAt;
    data['user_id'] = userId;
    data['full_name'] = fullName;
    data['country_code'] = countryCode;
    data['country'] = country;
    data['gender'] = gender;
    data['bio'] = bio;
    data['profile_verification_status'] = profileVerificationStatus;
    data['login_verification_status'] = loginVerificationStatus;
    data['first_name'] = firstName;
    data['last_name'] = lastName;
    data['user_type'] = userType;
    data['is_business'] = isBusiness;
    data['banner_image'] = bannerImage;
    data['description'] = description;
    data['createdAt'] = createdAt;
    data['website'] = website;
    data['location'] = location;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['facebook_link'] = facebookLink;
    data['youtube_link'] = youtubeLink;
    data['linkedin_link'] = linkedinLink;
    data['vk_link'] = vkLink;
    data['business_hours'] = businessHours;
    data['open_time'] = openTime;
    data['close_time'] = closeTime;
    data['appointments_only'] = appointmentsOnly;
    data['always_open'] = alwaysOpen;
    data['by_appointments_only'] = byAppointmentsOnly;
    data['profile_setup_step'] = profileSetupStep;
    data['categories'] = categories;
    if (catalogs != null) {
      data['catalogs'] = catalogs!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Pagination {
  int? totalPages;
  int? totalRecords;
  int? currentPage;
  int? recordsPerPage;

  Pagination({
    this.totalPages,
    this.totalRecords,
    this.currentPage,
    this.recordsPerPage,
  });

  Pagination.fromJson(Map<String, dynamic> json) {
    totalPages = json['total_pages'];
    totalRecords = json['total_records'];
    currentPage = json['current_page'];
    recordsPerPage = json['records_per_page'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_pages'] = totalPages;
    data['total_records'] = totalRecords;
    data['current_page'] = currentPage;
    data['records_per_page'] = recordsPerPage;
    return data;
  }
}

class Catalog {
  int? catalogId;
  int? categoryId;
  String? categoryName;
  num? price;
  String? title;
  String? description;
  String? countryOfOrigin;
  String? createdAt;
  String? updatedAt;
  int? userId;
  List<CatalogImage>? catalogImages;

  Catalog({
    this.catalogId,
    this.categoryId,
    this.categoryName,
    this.price,
    this.title,
    this.description,
    this.countryOfOrigin,
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.catalogImages,
  });

  Catalog.fromJson(Map<String, dynamic> json) {
    catalogId = json['catalog_id'];
    categoryId = json['category_id'] is int
        ? json['category_id']
        : int.tryParse('${json['category_id'] ?? ''}');
    categoryName = json['category_name'] ?? json['category']?['name'];
    price = json['price'];
    title = json['title'];
    description = json['description'];
    countryOfOrigin = json['country_of_origin'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    userId = json['user_id'];

    // Parse Catalog_images array
    if (json['Catalog_images'] != null) {
      catalogImages = <CatalogImage>[];
      json['Catalog_images'].forEach((v) {
        catalogImages!.add(CatalogImage.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['catalog_id'] = catalogId;
    data['category_id'] = categoryId;
    data['category_name'] = categoryName;
    data['price'] = price;
    data['title'] = title;
    data['description'] = description;
    data['country_of_origin'] = countryOfOrigin;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['user_id'] = userId;
    if (catalogImages != null) {
      data['Catalog_images'] = catalogImages!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class CatalogImage {
  String? image;
  int? catalogImageId;
  String? createdAt;
  String? updatedAt;
  int? catalogId;

  CatalogImage({
    this.image,
    this.catalogImageId,
    this.createdAt,
    this.updatedAt,
    this.catalogId,
  });

  CatalogImage.fromJson(Map<String, dynamic> json) {
    image = json['image'];
    catalogImageId = json['catalog_image_id'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    catalogId = json['catalog_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['image'] = image;
    data['catalog_image_id'] = catalogImageId;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['catalog_id'] = catalogId;
    return data;
  }
}
