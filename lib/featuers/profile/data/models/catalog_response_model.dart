/// One row of `GET /catalog/categories` (§3). Admin-managed and shared by the
/// business profile (`category_id`) and products (`category_id`), so it is
/// always fetched, never hard-coded.
class CatalogCategory {
  final int categoryId;
  final String name;

  const CatalogCategory({required this.categoryId, required this.name});

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    return CatalogCategory(
      categoryId: int.tryParse('${json['category_id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
    );
  }

  /// Shape the existing setup/edit widgets read (`category['category_id']`,
  /// `category['name']`).
  Map<String, dynamic> toMap() => {'category_id': categoryId, 'name': name};
}
