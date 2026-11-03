import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';
import 'package:whoxa/featuers/profile/screens/catalog_detail_screen.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

/// Product card for a `text` message carrying `metadata.catalog` (a business
/// sharing a catalog product in chat).
///
/// The payload is a snapshot — `{catalog_id, title, price, description,
/// category_name, country_of_origin, images: [url, …]}` — so later edits or
/// deletes of the product don't change messages already sent.
class CatalogProductCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isSentByMe;

  const CatalogProductCard({
    super.key,
    required this.data,
    required this.isSentByMe,
  });

  String? get _firstImage {
    final images = data['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      // Snapshot images are plain URLs; tolerate `{image: url}` objects too.
      if (first is String) return first;
      if (first is Map) return first['image']?.toString();
    }
    return null;
  }

  Catalog _toCatalog() {
    final images = data['images'];
    return Catalog(
      catalogId: int.tryParse('${data['catalog_id']}'),
      title: data['title']?.toString(),
      price: num.tryParse('${data['price']}'),
      description: data['description']?.toString(),
      countryOfOrigin: data['country_of_origin']?.toString(),
      categoryName: data['category_name']?.toString(),
      catalogImages:
          images is List
              ? images
                  .map(
                    (i) => CatalogImage(
                      image: i is Map ? i['image']?.toString() : i?.toString(),
                    ),
                  )
                  .toList()
              : [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        isSentByMe
            ? ThemeColorPalette.getTextColor(
              AppColors.appPriSecColor.primaryColor,
            )
            : AppThemeManage.appTheme.textColor;
    final subColor = textColor.withValues(alpha: 0.75);
    final title = (data['title'] ?? '').toString();
    final description = (data['description'] ?? '').toString();
    final price = data['price'];
    final image = _firstImage;

    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => CatalogDetailScreen(
                    catalog: _toCatalog(),
                    isViewOnly: true,
                  ),
            ),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (image != null && image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: image,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget:
                    (_, _, _) => Container(
                      height: 150,
                      color: Colors.black12,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTypography.innerText14(
              context,
            ).copyWith(color: textColor, fontWeight: FontWeight.w600),
          ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.innerText12Ragu(
                  context,
                ).copyWith(color: subColor),
              ),
            ),
          if (price != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '\$$price',
                style: AppTypography.innerText12Ragu(context).copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
