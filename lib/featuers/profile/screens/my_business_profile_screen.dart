import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart'
    as usernamecheck;
import 'package:whoxa/featuers/auth/provider/business_profile_provider.dart';
import 'package:whoxa/featuers/auth/screens/business_profile_stepper.dart';
import 'package:whoxa/featuers/profile/screens/edit_business_profile_screen.dart';
import 'package:whoxa/featuers/profile/screens/manage_catalog_screen.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';

/// The business's own profile, rebuilt on the Flickpitch design system.
///
/// This is the customer-facing card (name, category, hours, contact, links,
/// catalog) plus the owner's actions. Data still comes from
/// `BusinessProfileProvider.loadOwnBusinessRecord()`, which merges
/// `GET /business/profile` with the owner's catalog.
class MyBusinessProfileScreen extends StatefulWidget {
  const MyBusinessProfileScreen({super.key});

  @override
  State<MyBusinessProfileScreen> createState() =>
      _MyBusinessProfileScreenState();
}

class _MyBusinessProfileScreenState extends State<MyBusinessProfileScreen> {
  usernamecheck.UserNameCheckModel? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await context
          .read<BusinessProfileProvider>()
          .loadOwnBusinessRecord();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
        if (profile == null) _error = 'Business profile is not set up yet.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your business profile.';
        _loading = false;
      });
    }
  }

  usernamecheck.Records? get _record {
    final records = _profile?.data?.records;
    if (records == null || records.isEmpty) return null;
    return records.first;
  }

  /// First-run: no business profile exists yet (`GET /business/profile`
  /// returns data:null), so send the owner through the setup wizard.
  Future<void> _openSetup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BusinessProfileStepper()),
    );
    await _load();
  }

  Future<void> _openEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditBusinessProfileScreen(userProfile: _profile),
      ),
    );
    await _load();
  }

  Future<void> _share(usernamecheck.Records record) async {
    final buffer = StringBuffer()
      ..writeln(record.companyName ?? record.fullName ?? 'My business');
    if ((record.description ?? '').trim().isNotEmpty) {
      buffer.writeln(record.description!.trim());
    }
    final phone = '${record.countryCode ?? ''}${record.mobileNum ?? ''}'.trim();
    if (phone.isNotEmpty) buffer.writeln('Phone: $phone');
    final site = (record.website ?? '').trim();
    if (site.isNotEmpty) buffer.writeln('Website: $site');
    final address = (record.location ?? '').trim();
    if (address.isNotEmpty) buffer.writeln('Address: $address');
    buffer.writeln('\nChat with us on Flickpitch Business.');
    await Share.share(buffer.toString(), subject: 'My business on Flickpitch');
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final normalized = url.startsWith('http') ? url : 'https://$url';
    await launchUrl(Uri.parse(normalized), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;

    return Scaffold(
      body: FpCanvas(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null || record == null
            ? (_profile == null
                ? _SetupPrompt(onStart: _openSetup, onRetry: _load)
                : _ErrorView(
                    message: _error ?? 'Nothing to show yet',
                    onRetry: _load,
                  ))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Fp.s20,
                    Fp.s12,
                    Fp.s20,
                    Fp.s40,
                  ),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: Fp.s4),
                        Expanded(
                          child: Text('Business profile', style: Fp.display),
                        ),
                        IconButton(
                          tooltip: 'Share business',
                          onPressed: () => _share(record),
                          icon: const Icon(Icons.share_outlined),
                        ),
                        IconButton(
                          tooltip: 'Edit profile',
                          onPressed: _openEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: Fp.s12),
                    _HeaderCard(record: record),
                    const SizedBox(height: Fp.s16),
                    FpPrimaryButton(
                      label: 'Edit business profile',
                      icon: Icons.edit_outlined,
                      onPressed: _openEdit,
                    ),
                    const SizedBox(height: Fp.s24),
                    const FpSectionLabel('About'),
                    const SizedBox(height: Fp.s12),
                    _InfoCard(
                      rows: [
                        if ((record.companyName ?? '').trim().isNotEmpty)
                          _InfoRow('Business name', record.companyName!),
                        if (_categoryName(record) != null)
                          _InfoRow('Category', _categoryName(record)!),
                        if ((record.description ?? '').trim().isNotEmpty)
                          _InfoRow('Description', record.description!),
                        if ((record.website ?? '').trim().isNotEmpty)
                          _InfoRow(
                            'Website',
                            record.website!,
                            onTap: () => _openUrl(record.website),
                          ),
                      ],
                    ),
                    const SizedBox(height: Fp.s24),
                    const FpSectionLabel('Opening hours'),
                    const SizedBox(height: Fp.s12),
                    _InfoCard(rows: _hoursRows(record)),
                    const SizedBox(height: Fp.s24),
                    const FpSectionLabel('Contact'),
                    const SizedBox(height: Fp.s12),
                    _InfoCard(
                      rows: [
                        if ((record.email ?? '').trim().isNotEmpty)
                          _InfoRow('Email', record.email!),
                        if ((record.mobileNum ?? '').trim().isNotEmpty)
                          _InfoRow(
                            'Phone',
                            '${record.countryCode ?? ''}${record.mobileNum}',
                          ),
                      ],
                    ),
                    const SizedBox(height: Fp.s24),
                    const FpSectionLabel('Location'),
                    const SizedBox(height: Fp.s12),
                    _InfoCard(
                      rows: [
                        _InfoRow(
                          'Address',
                          (record.location ?? '').trim().isEmpty
                              ? 'Not set'
                              : record.location!,
                        ),
                      ],
                    ),
                    if (record.latitude != null && record.longitude != null) ...[
                      const SizedBox(height: Fp.s12),
                      _MapCard(
                        latitude: record.latitude!,
                        longitude: record.longitude!,
                        title: record.companyName ?? 'Business location',
                        address: record.location,
                      ),
                    ],
                    const SizedBox(height: Fp.s24),
                    const FpSectionLabel('Social links'),
                    const SizedBox(height: Fp.s12),
                    _InfoCard(
                      rows: [
                        _socialRow('Facebook', record.facebookLink),
                        _socialRow('Instagram', record.instagramLink),
                        _socialRow('LinkedIn', record.linkedinLink),
                        _socialRow('YouTube', record.youtubeLink),
                        _socialRow('VK', record.vkLink),
                      ].whereType<_InfoRow>().toList(),
                    ),
                    const SizedBox(height: Fp.s24),
                    FpSectionLabel(
                      'Catalog',
                      trailing: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageCatalogScreen(),
                          ),
                        ),
                        child: Text(
                          'Manage',
                          style: Fp.caption.copyWith(
                            color: Fp.violet,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Fp.s12),
                    _CatalogStrip(record: record),
                  ],
                ),
              ),
      ),
    );
  }

  String? _categoryName(usernamecheck.Records record) {
    final categories = record.categories;
    if (categories == null) return null;
    final name = categories['name'] ?? categories['category_name'];
    final value = name?.toString().trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  List<_InfoRow> _hoursRows(usernamecheck.Records record) {
    if (record.alwaysOpen == true) {
      return const [_InfoRow('Hours', 'Open 24 hours')];
    }
    if (record.byAppointmentsOnly == true ||
        record.appointmentsOnly == true) {
      return const [_InfoRow('Hours', 'By appointment only')];
    }
    final open = (record.openTime ?? '').trim();
    final close = (record.closeTime ?? '').trim();
    if (open.isEmpty && close.isEmpty) {
      return const [_InfoRow('Hours', 'Not set')];
    }
    return [
      _InfoRow('Opens', open.isEmpty ? '—' : open),
      _InfoRow('Closes', close.isEmpty ? '—' : close),
    ];
  }

  _InfoRow? _socialRow(String label, String? url) {
    if (url == null || url.trim().isEmpty) return null;
    return _InfoRow(label, url.trim(), onTap: () => _openUrl(url));
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value, {this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.record});

  final usernamecheck.Records record;

  @override
  Widget build(BuildContext context) {
    final banner = record.bannerImage;
    final logo = record.profilePic;

    return FpSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Fp.rLg),
            ),
            child: SizedBox(
              height: 116,
              width: double.infinity,
              child: banner != null && banner.trim().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: banner,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const _BannerFallback(),
                    )
                  : const _BannerFallback(),
            ),
          ),
          Transform.translate(
            offset: const Offset(Fp.s20, -26),
            child: Padding(
              padding: const EdgeInsets.only(left: Fp.s20, right: Fp.s20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Fp.inkRaised, width: 3),
                    ),
                    child: FpAvatar(
                      imageUrl: logo,
                      label: record.companyName ?? record.fullName,
                      size: 72,
                    ),
                  ),
                  const SizedBox(width: Fp.s16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  record.companyName ??
                                      record.fullName ??
                                      'Your business',
                                  style: Fp.h2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const OwnVerifiedBadge(size: 18, leading: 6),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (record.description ?? '').trim().isEmpty
                                ? 'Business account'
                                : record.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Fp.caption.copyWith(color: Fp.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Fp.s4),
        ],
      ),
    );
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Fp.violet.withValues(alpha: 0.85),
            Fp.violetDeep.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.storefront_rounded, color: Colors.white24, size: 42),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return FpSurface(
        child: Text(
          'Nothing added yet.',
          style: Fp.body.copyWith(color: Fp.textMuted),
        ),
      );
    }
    return FpSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: Fp.s20,
        vertical: Fp.s8,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Column(
              children: [
                InkWell(
                  onTap: rows[i].onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Fp.s12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text(
                            rows[i].label,
                            style: Fp.caption.copyWith(color: Fp.textFaint),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            rows[i].value,
                            style: Fp.body.copyWith(
                              color: rows[i].onTap == null
                                  ? Fp.text
                                  : Fp.violet,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i != rows.length - 1)
                  Container(height: 1, color: Fp.hairline),
              ],
            ),
        ],
      ),
    );
  }
}

class _CatalogStrip extends StatelessWidget {
  const _CatalogStrip({required this.record});

  final usernamecheck.Records record;

  @override
  Widget build(BuildContext context) {
    final items = record.catalogs ?? const [];
    if (items.isEmpty) {
      return FpEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No products yet',
        message: 'Add products so customers can see prices in the chat.',
        action: FpPrimaryButton(
          label: 'Open catalog',
          expand: false,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageCatalogScreen()),
          ),
        ),
      );
    }

    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: Fp.s12),
        itemBuilder: (context, index) {
          final item = items[index];
          final images = item.catalogImages ?? const [];
          final image = images.isNotEmpty ? images.first.image : null;
          return SizedBox(
            width: 132,
            child: FpSurface(
              padding: EdgeInsets.zero,
              radius: Fp.rMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(Fp.rMd),
                    ),
                    child: SizedBox(
                      height: 92,
                      width: double.infinity,
                      child: image != null && image.trim().isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: image,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  const _ProductFallback(),
                            )
                          : const _ProductFallback(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title ?? 'Product',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Fp.caption.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.price == null ? '' : '₦${item.price}',
                          style: Fp.caption.copyWith(
                            color: Fp.violet,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductFallback extends StatelessWidget {
  const _ProductFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Fp.violet.withValues(alpha: 0.12),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white24, size: 26),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Fp.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FpEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Business profile unavailable',
              message: message,
            ),
            const SizedBox(height: Fp.s16),
            FpPrimaryButton(
              label: 'Try again',
              expand: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Location map: keeps the embedded Google map the profile historically had,
/// restyled as a rounded card under the address row.
class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.latitude,
    required this.longitude,
    required this.title,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String title;
  final String? address;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Fp.rLg),
      child: SizedBox(
        height: 178,
        width: double.infinity,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: point, zoom: 15),
          markers: {
            Marker(
              markerId: const MarkerId('business_location'),
              position: point,
              infoWindow: InfoWindow(
                title: title,
                snippet: (address ?? '').trim().isEmpty ? null : address,
              ),
            ),
          },
          mapType: MapType.normal,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          tiltGesturesEnabled: false,
          rotateGesturesEnabled: false,
        ),
      ),
    );
  }
}

/// Shown when the account has no business profile yet. This is the normal
/// first-run state, not an error: it offers the setup wizard.
class _SetupPrompt extends StatelessWidget {
  const _SetupPrompt({required this.onStart, required this.onRetry});

  final VoidCallback onStart;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Fp.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Fp.violet.withValues(alpha: 0.9),
                    Fp.violetDeep.withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: Fp.s20),
            Text('Set up your business profile', style: Fp.h2, textAlign: TextAlign.center),
            const SizedBox(height: Fp.s8),
            Text(
              'Add your business name, hours, location and links once — customers '
              'see it before they message you.',
              textAlign: TextAlign.center,
              style: Fp.body.copyWith(color: Fp.textMuted),
            ),
            const SizedBox(height: Fp.s24),
            FpPrimaryButton(
              label: 'Start setup',
              icon: Icons.arrow_forward_rounded,
              onPressed: onStart,
            ),
            const SizedBox(height: Fp.s8),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Refresh',
                style: Fp.caption.copyWith(color: Fp.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
