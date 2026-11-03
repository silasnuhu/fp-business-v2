import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';
import 'package:whoxa/featuers/profile/screens/catalog_detail_screen.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

/// A business's catalog, listed on the Flickpitch design system.
///
/// The stock AppBar + tinted cards are replaced by an Fp canvas, a floating
/// header and surface cards; the image, price and tap-through to the detail
/// screen behave exactly as before.
class CatalogListScreen extends StatelessWidget {
  final List<Catalog> catalogs;
  final String businessName;

  const CatalogListScreen({
    super.key,
    required this.catalogs,
    required this.businessName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Fp.s20, Fp.s12, Fp.s20, Fp.s40),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Fp.text,
                ),
                const SizedBox(width: Fp.s4),
                Expanded(
                  child: Text('$businessName ${AppString.catalog}',
                      style: Fp.display),
                ),
              ],
            ),
            const SizedBox(height: Fp.s8),
            if (catalogs.isEmpty)
              _emptyState()
            else ...[
              Text(
                '${catalogs.length} product${catalogs.length == 1 ? '' : 's'}',
                style: Fp.caption.copyWith(color: Fp.textMuted),
              ),
              const SizedBox(height: Fp.s16),
              for (final catalog in catalogs)
                Padding(
                  padding: const EdgeInsets.only(bottom: Fp.s12),
                  child: _catalogCard(context, catalog),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: Fp.s40),
      child: FpEmptyState(
        icon: Icons.inventory_2_outlined,
        title: AppString.noCatalogItemAvailable,
        message: AppString.thisBusinessHasnt,
      ),
    );
  }

  Widget _catalogCard(BuildContext context, Catalog catalog) {
    final hasPrice = catalog.price != null && catalog.price! > 0;
    return FpSurface(
      padding: EdgeInsets.zero,
      onTap: () => _navigateToCatalogDetail(context, catalog),
      child: Padding(
        padding: const EdgeInsets.all(Fp.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardImage(catalog),
            const SizedBox(width: Fp.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          catalog.title ?? 'No title',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Fp.bodyStrong,
                        ),
                      ),
                      if (hasPrice) ...[
                        const SizedBox(width: Fp.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Fp.s8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Fp.violet.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(Fp.rPill),
                          ),
                          child: Text(
                            '\$${catalog.price!.toStringAsFixed(catalog.price! % 1 == 0 ? 0 : 2)}',
                            style: Fp.caption.copyWith(
                              color: Fp.violet,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (catalog.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      catalog.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Fp.caption.copyWith(
                        color: Fp.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Fp.s8),
            Icon(Icons.chevron_right_rounded, color: Fp.textFaint, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _cardImage(Catalog catalog) {
    final images = catalog.catalogImages ?? [];
    final imageUrl = images.isNotEmpty ? images.first.image : null;
    const side = 68.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Fp.rSm),
      child: SizedBox(
        width: side,
        height: side,
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Fp.inkSoft,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Fp.violet),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Fp.inkSoft,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Fp.textFaint,
                    size: 22,
                  ),
                ),
              )
            : Container(
                color: Fp.inkSoft,
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: Fp.textFaint,
                  size: 22,
                ),
              ),
      ),
    );
  }

  void _navigateToCatalogDetail(BuildContext context, Catalog catalog) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CatalogDetailScreen(catalog: catalog),
      ),
    );
  }
}
