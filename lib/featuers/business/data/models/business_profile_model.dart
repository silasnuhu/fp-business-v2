import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart'
    show Catalog;

/// Own business profile (`GET/POST /business/profile`, §2).
///
/// Unset text fields come back as `""`, unset `category_id` as `0` and unset
/// `business_hours` as `{}`.
class BusinessProfile {
  final int userId;
  final String businessName;
  final int categoryId;
  final String categoryName;
  final String about;
  final String coverImageUrl;

  /// Read-only: the account avatar (the avatar IS the business logo). Set it
  /// through the avatar upload, never through `/business/profile`.
  final String logoUrl;

  /// Map pin. The API stores both or neither, so they are always sent
  /// together.
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> businessHours;
  final String facebookUrl;
  final String instagramUrl;
  final String linkedinUrl;
  final String youtubeUrl;
  final String vkUrl;

  /// The API has no dedicated website field — `other_url` is the business
  /// website (§2.2).
  final String otherUrl;
  final String businessAddress;
  final String businessPhone;
  final String businessEmail;
  final String? createdAt;
  final String? updatedAt;

  const BusinessProfile({
    this.userId = 0,
    this.businessName = '',
    this.categoryId = 0,
    this.categoryName = '',
    this.about = '',
    this.coverImageUrl = '',
    this.logoUrl = '',
    this.latitude,
    this.longitude,
    this.businessHours = const {},
    this.facebookUrl = '',
    this.instagramUrl = '',
    this.linkedinUrl = '',
    this.youtubeUrl = '',
    this.vkUrl = '',
    this.otherUrl = '',
    this.businessAddress = '',
    this.businessPhone = '',
    this.businessEmail = '',
    this.createdAt,
    this.updatedAt,
  });

  /// A profile counts as "set up" once it has a name — the only field the
  /// first setup step requires.
  bool get isSetUp => businessName.trim().isNotEmpty;

  /// A pin counts only when both halves parse and it isn't the 0,0 "unset".
  static double? _coord(dynamic v, dynamic other) {
    final a = double.tryParse('${v ?? ''}');
    final b = double.tryParse('${other ?? ''}');
    if (a == null || b == null || (a == 0 && b == 0)) return null;
    return a;
  }

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    String str(String key) => (json[key] ?? '').toString();
    final hours = json['business_hours'];
    return BusinessProfile(
      userId: int.tryParse('${json['user_id']}') ?? 0,
      businessName: str('business_name'),
      categoryId: int.tryParse('${json['category_id']}') ?? 0,
      categoryName: str('category_name'),
      about: str('about'),
      coverImageUrl: str('cover_image_url'),
      logoUrl: str('logo_url'),
      latitude: _coord(json['latitude'], json['longitude']),
      longitude: _coord(json['longitude'], json['latitude']),
      // Free-form JSON on the server; tolerate the legacy `[]` for "unset".
      businessHours:
          hours is Map ? Map<String, dynamic>.from(hours) : <String, dynamic>{},
      facebookUrl: str('facebook_url'),
      instagramUrl: str('instagram_url'),
      linkedinUrl: str('linkedin_url'),
      youtubeUrl: str('youtube_url'),
      vkUrl: str('vk_url'),
      otherUrl: str('other_url'),
      businessAddress: str('business_address'),
      businessPhone: str('business_phone'),
      businessEmail: str('business_email'),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

/// `GET /business/:userId` (another user's business profile + catalog).
///
/// Always `200`: a regular/deleted/blocked user yields `isBusiness == false`,
/// a null [profile] and an empty [catalog]. [profile] can also be null for a
/// real business that never saved one.
class PublicBusiness {
  final bool isBusiness;
  final BusinessProfile? profile;
  final List<Catalog> catalog;

  const PublicBusiness({
    this.isBusiness = false,
    this.profile,
    this.catalog = const [],
  });

  factory PublicBusiness.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'];
    final catalog = json['catalog'];
    return PublicBusiness(
      isBusiness: json['is_business'] == true,
      profile:
          profile is Map
              ? BusinessProfile.fromJson(Map<String, dynamic>.from(profile))
              : null,
      catalog:
          catalog is List
              ? catalog
                  .whereType<Map>()
                  .map((e) => Catalog.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : const [],
    );
  }
}
