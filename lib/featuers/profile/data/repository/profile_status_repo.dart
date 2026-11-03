import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/auth/data/models/user_profile_model.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/utils/logger.dart';

class ProfileStatusRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  ProfileStatusRepository(this._apiClient);

  UserProfileModel userProfileModel = UserProfileModel();
  Future<UserProfileModel> profileStatusRepo({
    required bool isGetData,
    required String status,
  }) async {
    _logger.i('Adding new status: $status');

    try {
      final dynamic response;
      if (isGetData) {
        response = await _apiClient.request(
          ApiEndpoints.userCreateProfile,
          method: 'POST',
          body: {},
        );
      } else {
        response = await _apiClient.request(
          ApiEndpoints.userCreateProfile,
          method: "POST",
          body: {'bio': status},
        );
      }
      return userProfileModel = UserProfileModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding status:', e.toString());
      rethrow;
    }
  }

  /// Peer user profile.
  ///
  /// NEW dropped OLD's `POST /find-user {user_id}` (the `user_id` field now
  /// 400s) — the replacement is `GET /users/:id` (`users.service.getById` ->
  /// `toPublicUser`), a camelCase curated user object. This maps it onto the
  /// OLD `UserNameCheckModel` shape (snake_case, single `data.records`
  /// entry) the profile screens read. Business accounts are then overlaid
  /// from `GET /business/:userId` (see [_overlayBusinessProfile]) and come
  /// back with `user_type: business`; everyone else stays `personal`.
  Future<UserNameCheckModel> getPeerUserProfileRepo(int userId) async {
    _logger.i('Getting peer user profile for user_id: $userId');
    try {
      final response = await _apiClient.request(
        '${ApiEndpoints.userById}/$userId',
        method: 'GET',
      );

      // Response may or may not be enveloped in {status, data, ...}.
      Map<String, dynamic>? user;
      if (response is Map<String, dynamic>) {
        final inner = response['data'];
        user = inner is Map<String, dynamic> ? inner : response;
      }
      if (user == null || user.isEmpty || user['userId'] == null) {
        throw Exception('Profile not found');
      }
      ContactNameService.instance.noteUserProfile(user);

      final profile = user['profile'] as Map<String, dynamic>?;
      final fullName =
          (user['fullName'] as String?)?.trim().isNotEmpty == true
              ? user['fullName'] as String
              : [
                user['firstName'],
                user['lastName'],
              ].where((e) => e is String && e.trim().isNotEmpty).join(' ').trim();

      final record = <String, dynamic>{
        'user_id': int.tryParse(user['userId'].toString()),
        'user_name': user['userName'],
        'full_name': fullName,
        'first_name': user['firstName'],
        'last_name': user['lastName'],
        'email': user['email'],
        'mobile_num': user['mobileNum'],
        'country_code': user['countryCode'],
        // `avatarMediaId` is a bare id, not a URL — no usable fallback, let
        // the screen show its default avatar when profilePic is null.
        'profile_pic': user['profilePic'],
        'bio': user['bio'] ?? profile?['about'],
        'description': user['description'] ?? profile?['about'],
        'location': user['location'],
        'latitude': user['latitude'],
        'longitude': user['longitude'],
        'createdAt': user['createdAt'],
        'updatedAt': user['updatedAt'],
        'user_type': 'personal',
        'profile_verification_status': false,
        'login_verification_status': false,
      };

      await _overlayBusinessProfile(userId, record);

      return UserNameCheckModel.fromJson({
        'status': true,
        'message': 'Success',
        'toast': false,
        'data': {
          'Records': [record],
        },
      });
    } catch (e) {
      _logger.e('Error getting peer user profile:', e.toString());
      rethrow;
    }
  }

  /// Overlays the peer's business profile + catalog onto [record] when the
  /// peer is a business account (`is_business: true`). Best-effort: any
  /// failure leaves the personal record untouched.
  Future<void> _overlayBusinessProfile(
    int userId,
    Map<String, dynamic> record,
  ) async {
    try {
      final response = await _apiClient.request(
        '${ApiEndpoints.businessById}/$userId',
        method: 'GET',
      );
      final data = response is Map<String, dynamic> ? response['data'] : null;
      if (data is! Map<String, dynamic> || data['is_business'] != true) return;

      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      String? text(String key) {
        final v = profile[key];
        return v is String && v.trim().isNotEmpty ? v : null;
      }

      final hours = profile['business_hours'];
      final logo = data['logo_url'];

      record['user_type'] = 'business';
      record['full_name'] = text('business_name') ?? record['full_name'];
      if (logo is String && logo.isNotEmpty) record['profile_pic'] = logo;
      record['banner_image'] = text('cover_image_url');
      record['description'] = text('about') ?? record['description'];
      record['bio'] = text('about') ?? record['bio'];
      record['website'] = text('other_url');
      record['facebook_link'] = text('facebook_url');
      record['linkedin_link'] = text('linkedin_url');
      record['youtube_link'] = text('youtube_url');
      record['vk_link'] = text('vk_url');
      record['location'] = text('business_address') ?? record['location'];
      record['latitude'] = profile['latitude'] ?? record['latitude'];
      record['longitude'] = profile['longitude'] ?? record['longitude'];
      record['business_hours'] =
          hours is Map
              ? hours.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
              : <String, dynamic>{};
      if (text('category_name') != null) {
        record['categories'] = {
          'category_id': profile['category_id'],
          'name': text('category_name'),
        };
      }
      record['catalogs'] = [
        for (final c in (data['catalog'] as List? ?? const []))
          if (c is Map<String, dynamic>)
            {
              'catalog_id': c['catalog_id'],
              'user_id': c['user_id'],
              'title': c['title'],
              'price': c['price'],
              'description': c['description'],
              'country_of_origin': c['country_of_origin'],
              'createdAt': c['created_at'],
              'updatedAt': c['updated_at'],
              'Catalog_images': [
                for (final i in (c['images'] as List? ?? const []))
                  if (i is Map<String, dynamic>)
                    {
                      'catalog_image_id': i['catalog_image_id'],
                      'catalog_id': c['catalog_id'],
                      'image': i['image'],
                    },
              ],
            },
      ];
    } catch (e) {
      _logger.w('Business profile overlay skipped for $userId: $e');
    }
  }
}
