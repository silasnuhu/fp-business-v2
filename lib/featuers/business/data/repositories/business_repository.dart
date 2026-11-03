import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/business/data/models/auto_replies_model.dart';
import 'package:whoxa/featuers/business/data/models/business_dashboard_model.dart';
import 'package:whoxa/featuers/business/data/models/business_profile_model.dart';
import 'package:whoxa/featuers/profile/data/models/catalog_response_model.dart';
import 'package:whoxa/utils/logger.dart';

/// `/business/profile` + `/catalog/categories` (BUSINESS_CATALOG_LABELS_API §2, §3).
class BusinessRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'BusinessRepository',
  );

  BusinessRepository(this._apiClient);

  /// `data` is `null` until the business has saved a profile — callers show
  /// the empty setup form in that case.
  Future<BusinessProfile?> getProfile() async {
    final response = await _apiClient.request(
      ApiEndpoints.businessProfile,
      method: 'GET',
    );
    final data = response is Map ? response['data'] : null;
    if (data is! Map) return null;
    return BusinessProfile.fromJson(Map<String, dynamic>.from(data));
  }

  /// Upsert. Only the keys in [fields] are written; omit a key to keep it,
  /// send `""` (text) / `0` (`category_id`) to clear it. Unknown keys are
  /// rejected with 400 by the server, so callers must stick to the §2.2 names.
  Future<BusinessProfile> saveProfile(Map<String, dynamic> fields) async {
    _logger.i('Saving business profile keys: ${fields.keys.toList()}');
    final response = await _apiClient.request(
      ApiEndpoints.businessProfile,
      method: 'POST',
      body: fields,
    );
    final data = response is Map ? response['data'] : null;
    return data is Map
        ? BusinessProfile.fromJson(Map<String, dynamic>.from(data))
        : const BusinessProfile();
  }

  Future<List<CatalogCategory>> getCategories() async {
    final response = await _apiClient.request(
      ApiEndpoints.catalogCategories,
      method: 'GET',
    );
    final data = response is Map ? response['data'] : null;
    final records = data is Map ? data['Records'] : null;
    if (records is! List) return [];
    return records
        .whereType<Map>()
        .map((e) => CatalogCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `GET /business/:userId` — safe to call for every peer (never 404s).
  Future<PublicBusiness> getBusinessByUserId(int userId) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.business}/$userId',
      method: 'GET',
    );
    final data = response is Map ? response['data'] : null;
    if (data is! Map) return const PublicBusiness();
    return PublicBusiness.fromJson(Map<String, dynamic>.from(data));
  }

  Map<String, dynamic> _data(dynamic response) {
    final data = response is Map ? response['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// `GET /business/auto-replies` (defaults if never saved). Business only.
  Future<AutoReplies> getAutoReplies() async {
    final response = await _apiClient.request(
      ApiEndpoints.businessAutoReplies,
      method: 'GET',
    );
    return AutoReplies.fromJson(_data(response));
  }

  /// `POST /business/auto-replies` — only the keys sent are written. A reply
  /// can't be enabled with an empty stored message (400).
  Future<AutoReplies> saveAutoReplies(Map<String, dynamic> fields) async {
    final response = await _apiClient.request(
      ApiEndpoints.businessAutoReplies,
      method: 'POST',
      body: fields,
    );
    return AutoReplies.fromJson(_data(response));
  }

  /// `GET /business/dashboard?days=` — [days] must be 7, 30 or 90.
  Future<BusinessDashboard> getDashboard({int days = 7}) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.businessDashboard}?days=$days',
      method: 'GET',
    );
    return BusinessDashboard.fromJson(_data(response));
  }
}
