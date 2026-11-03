import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';
import 'package:whoxa/utils/logger.dart';

/// Owner-scoped product catalog (`/catalog`, BUSINESS_CATALOG_LABELS_API §4).
///
/// Every endpoint only serves the business's own products. There is no
/// customer-facing "browse someone else's catalog" endpoint yet (§4 "Known
/// gap"), and the list is not paginated.
class CatalogRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'CatalogRepository',
  );

  CatalogRepository(this._apiClient);

  Map<String, dynamic>? _data(dynamic response) {
    final data = response is Map ? response['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// `GET /catalog` — non-deleted only, newest first, full list.
  Future<List<Catalog>> getCatalogs() async {
    final response = await _apiClient.request(
      ApiEndpoints.catalog,
      method: 'GET',
    );
    final records = _data(response)?['Records'];
    if (records is! List) return [];
    return records
        .whereType<Map>()
        .map((e) => Catalog.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Catalog> getCatalog(int catalogId) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.catalog}/$catalogId',
      method: 'GET',
    );
    return Catalog.fromJson(_data(response) ?? {});
  }

  /// `POST /catalog`. [price] is a whole number (§4.1); [images] are URLs
  /// already returned by the media upload API.
  Future<Catalog> createCatalog({
    required String title,
    int price = 0,
    String? description,
    String? countryOfOrigin,
    int? categoryId,
    List<String> images = const [],
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'price': price,
      if (description != null) 'description': description,
      if (countryOfOrigin != null) 'country_of_origin': countryOfOrigin,
      if (categoryId != null) 'category_id': categoryId,
      if (images.isNotEmpty) 'images': images,
    };
    _logger.i('Creating catalog: $title');
    final response = await _apiClient.request(
      ApiEndpoints.catalog,
      method: 'POST',
      body: body,
    );
    return Catalog.fromJson(_data(response) ?? {});
  }

  /// `PATCH /catalog/:id` — any subset of the create fields. `images`
  /// REPLACES the whole set when present (send `[]` to remove all, omit to
  /// keep the current ones).
  Future<Catalog> updateCatalog(
    int catalogId, {
    String? title,
    int? price,
    String? description,
    String? countryOfOrigin,
    int? categoryId,
    List<String>? images,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (price != null) 'price': price,
      if (description != null) 'description': description,
      if (countryOfOrigin != null) 'country_of_origin': countryOfOrigin,
      if (categoryId != null) 'category_id': categoryId,
      if (images != null) 'images': images,
    };
    _logger.i('Updating catalog $catalogId: ${body.keys.toList()}');
    final response = await _apiClient.request(
      '${ApiEndpoints.catalog}/$catalogId',
      method: 'PATCH',
      body: body,
    );
    return Catalog.fromJson(_data(response) ?? {});
  }

  /// `POST /catalog/:id/view` — counts one view of the item. The server
  /// dedupes (one viewer, one item, once a day) and ignores the owner's own
  /// opens and blocked viewers, so it is safe to call on every open. 404 if
  /// the item is gone.
  Future<void> trackView(int catalogId) async {
    await _apiClient.request(
      '${ApiEndpoints.catalog}/$catalogId/view',
      method: 'POST',
    );
  }

  /// `DELETE /catalog/:id` — soft delete.
  Future<void> deleteCatalog(int catalogId) async {
    _logger.i('Deleting catalog $catalogId');
    await _apiClient.request(
      '${ApiEndpoints.catalog}/$catalogId',
      method: 'DELETE',
    );
  }
}
