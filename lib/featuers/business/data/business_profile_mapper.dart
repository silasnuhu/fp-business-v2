import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart'
    as usernamecheck;
import 'package:whoxa/featuers/business/data/models/business_profile_model.dart';

/// Bridges the setup/edit/profile screens (which speak the legacy
/// profile-record vocabulary: `full_name`, `description`, `website`, …) and
/// the business API (§2: `business_name`, `about`, `other_url`, …).
///
/// Keeping the translation in one place means the screens don't each need to
/// know the wire format.
///
/// **Business hours shape** (fixed by the backend, shared with the web apps):
/// `{ "mode": "selected_hours"|"always_open"|"appointment_only",
///    "days": { "monday": {"is_open": true, "open_time": "09:00",
///                         "close_time": "18:00"}, … } }`
/// (`days` only for `selected_hours`; full lowercase day names; 24 h
/// `HH:mm`). The legacy screens use `"9:00 to 18:00"` / `"closed"` per day;
/// both directions are converted here.
class BusinessProfileMapper {
  BusinessProfileMapper._();

  static const List<String> _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  /// "9:0" / "09:00" -> "09:00".
  static String _hhmm(String t) {
    final p = t.trim().split(':');
    final h = (int.tryParse(p[0]) ?? 0).toString().padLeft(2, '0');
    final m = (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Legacy screen fields → API body. Only keys present in [legacy] are
  /// emitted (the API upserts, so omitted keys stay unchanged). Fields the API
  /// has no home for (coordinates, setup step, open/close day lists, …) are
  /// dropped.
  static Map<String, dynamic> toApiFields(
    Map<String, dynamic> legacy, {
    String? coverImageUrl,
  }) {
    final out = <String, dynamic>{};

    void copy(String from, String to) {
      if (!legacy.containsKey(from)) return;
      final value = legacy[from];
      if (value == null) return;
      out[to] = value is String ? value.trim() : value;
    }

    copy('full_name', 'business_name');
    copy('description', 'about');
    copy('website', 'other_url');
    copy('location', 'business_address');
    copy('mobile_num', 'business_phone');
    copy('business_email', 'business_email');
    copy('facebook_link', 'facebook_url');
    copy('instagram_link', 'instagram_url');
    copy('linkedin_link', 'linkedin_url');
    copy('youtube_link', 'youtube_url');
    copy('vk_link', 'vk_url');

    if (legacy.containsKey('category_id') && legacy['category_id'] != null) {
      out['category_id'] = legacy['category_id'];
    }
    if (coverImageUrl != null) out['cover_image_url'] = coverImageUrl;
    // Removing the cover = send an empty string (`""` clears the field).
    if (legacy['remove_cover'] == true) out['cover_image_url'] = '';

    // Coordinates are stored as a pair — send both or neither.
    final lat = double.tryParse('${legacy['latitude'] ?? ''}');
    final lng = double.tryParse('${legacy['longitude'] ?? ''}');
    if (lat != null && lng != null) {
      out['latitude'] = lat;
      out['longitude'] = lng;
    }

    final hours = _hoursToApi(legacy);
    if (hours != null) out['business_hours'] = hours;

    return out;
  }

  static Map<String, dynamic>? _hoursToApi(Map<String, dynamic> legacy) {
    final hasHours =
        legacy.containsKey('business_hours') ||
        legacy.containsKey('always_open') ||
        legacy.containsKey('appointments_only');
    if (!hasHours) return null;

    if (legacy['always_open'] == true) return {'mode': 'always_open'};
    if (legacy['appointments_only'] == true) {
      return {'mode': 'appointment_only'};
    }

    final legacyDays = legacy['business_hours'];
    if (legacyDays is! Map) return null;

    final days = <String, dynamic>{};
    for (final day in _days) {
      final v = legacyDays[day]?.toString();
      if (v == null) continue;
      if (v == 'closed') {
        days[day] = {
          'is_open': false,
          'open_time': '09:00',
          'close_time': '18:00',
        };
        continue;
      }
      final range = v.split(' to ');
      days[day] = {
        'is_open': true,
        'open_time': _hhmm(range[0]),
        'close_time': _hhmm(range.length > 1 ? range[1] : '18:00'),
      };
    }
    return {'mode': 'selected_hours', 'days': days};
  }

  /// API profile → the merged user+business record the profile screens read.
  static usernamecheck.UserNameCheckModel toUserNameCheckModel(
    BusinessProfile profile, {
    required Map<String, dynamic> account,
  }) {
    final legacyHours = _hoursToLegacy(profile.businessHours);
    final mode = profile.businessHours['mode']?.toString();

    final record = usernamecheck.Records(
      userId: int.tryParse('${account['user_id'] ?? profile.userId}'),
      userName: account['user_name']?.toString(),
      fullName: profile.businessName,
      companyName: profile.businessName,
      profilePic:
          profile.logoUrl.isNotEmpty
              ? profile.logoUrl
              : account['profile_pic']?.toString(),
      latitude: profile.latitude,
      longitude: profile.longitude,
      mobileNum: profile.businessPhone,
      countryCode: '',
      email: profile.businessEmail,
      userType: 'business',
      bannerImage: profile.coverImageUrl,
      description: profile.about,
      website: profile.otherUrl,
      location: profile.businessAddress,
      facebookLink: profile.facebookUrl,
      instagramLink: profile.instagramUrl,
      youtubeLink: profile.youtubeUrl,
      linkedinLink: profile.linkedinUrl,
      vkLink: profile.vkUrl,
      businessHours: legacyHours,
      alwaysOpen: mode == 'always_open',
      appointmentsOnly: mode == 'appointment_only',
      byAppointmentsOnly: mode == 'appointment_only',
      categories:
          profile.categoryId > 0
              ? {
                'category_id': profile.categoryId,
                'name': profile.categoryName,
              }
              : null,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
    );

    return usernamecheck.UserNameCheckModel(
      status: true,
      data: usernamecheck.Data(records: [record]),
    );
  }

  /// API hours -> legacy per-day map (`"09:00 to 18:00"` / `"closed"`).
  static Map<String, dynamic> _hoursToLegacy(Map<String, dynamic> hours) {
    final legacy = <String, dynamic>{};
    if (hours['mode']?.toString() == 'always_open') {
      for (final day in _days) {
        legacy[day] = '00:00 to 00:00';
      }
    } else if (hours['days'] is Map) {
      final days = hours['days'] as Map;
      for (final day in _days) {
        final d = days[day];
        if (d is! Map) continue;
        legacy[day] =
            d['is_open'] == true
                ? '${d['open_time']} to ${d['close_time']}'
                : 'closed';
      }
    }
    return legacy;
  }

  /// Overlays another user's business data (`GET /business/:userId`) onto the
  /// regular peer record the contact-info screen already shows.
  static void applyPublicBusiness(
    usernamecheck.Records record,
    PublicBusiness business,
  ) {
    final p = business.profile;
    record.userType = 'business';
    record.catalogs = business.catalog;
    if (p == null) return;

    final mode = p.businessHours['mode']?.toString();
    record
      ..companyName = p.businessName
      ..bannerImage = p.coverImageUrl
      ..latitude = p.latitude
      ..longitude = p.longitude
      ..description = p.about
      ..website = p.otherUrl
      ..location = p.businessAddress
      ..facebookLink = p.facebookUrl
      ..instagramLink = p.instagramUrl
      ..youtubeLink = p.youtubeUrl
      ..linkedinLink = p.linkedinUrl
      ..vkLink = p.vkUrl
      ..businessHours = _hoursToLegacy(p.businessHours)
      ..alwaysOpen = mode == 'always_open'
      ..appointmentsOnly = mode == 'appointment_only'
      ..byAppointmentsOnly = mode == 'appointment_only'
      ..categories =
          p.categoryName.isNotEmpty
              ? {'category_id': p.categoryId, 'name': p.categoryName}
              : null;
    if (p.businessName.isNotEmpty) record.fullName = p.businessName;
    if (p.logoUrl.isNotEmpty) record.profilePic = p.logoUrl;
    if (p.businessEmail.isNotEmpty) record.email = p.businessEmail;
    if (p.businessPhone.isNotEmpty) {
      record
        ..mobileNum = p.businessPhone
        ..countryCode = '';
    }
  }
}
