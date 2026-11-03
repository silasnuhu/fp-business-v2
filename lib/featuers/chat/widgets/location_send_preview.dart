import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';

/// Shows the picked location for a final check before it is sent. Resolves
/// `true` when the user taps send; cancel (or dismissing) resolves `false`.
Future<bool> showLocationSendPreview(
  BuildContext context, {
  required double latitude,
  required double longitude,
  required String address,
}) async {
  final confirmed = await bottomSheetGobalWithoutTitle<bool>(
    context,
    isCrossIconHide: true,
    shrinkWrap: true,
    bottomsheetHeight: 420,
    child: LocationSendPreview(
      latitude: latitude,
      longitude: longitude,
      address: address,
    ),
  );
  return confirmed == true;
}

class LocationSendPreview extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String address;

  const LocationSendPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  @override
  State<LocationSendPreview> createState() => _LocationSendPreviewState();
}

class _LocationSendPreviewState extends State<LocationSendPreview> {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};

  LatLng get _position => LatLng(widget.latitude, widget.longitude);

  @override
  void initState() {
    super.initState();
    _loadMarker();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadMarker() async {
    // Same pin as the location picker.
    final icon = await BitmapDescriptor.asset(
      const ImageConfiguration(),
      "assets/images/location_red.png",
      height: 20,
    );
    if (!mounted) return;
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('location_send_preview'),
          position: _position,
          icon: icon,
        ),
      };
    });
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;
    final style = await rootBundle.loadString(
      isLightModeGlobal ? AppAssets.lightMap : AppAssets.darkMap,
    );
    // ignore: deprecated_member_use
    _controller?.setMapStyle(style);
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.appPriSecColor.primaryColor;
    final onPrimary = ThemeColorPalette.getTextColor(primary);
    final address =
        widget.address.trim().isNotEmpty
            ? widget.address.trim()
            : '${widget.latitude}, ${widget.longitude}';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppString.locationStrings.sendLocation,
            style: AppTypography.innerText16(context),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _position,
                  zoom: 15,
                ),
                markers: _markers,
                onMapCreated: _onMapCreated,
                // Static preview: the location is chosen on the picker.
                liteModeEnabled: true,
                zoomGesturesEnabled: false,
                scrollGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                AppAssets.chatMsgTypeIcon.locationRed,
                height: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  address,
                  style: AppTypography.innerText12Mediu(
                    context,
                  ).copyWith(color: AppThemeManage.appTheme.textColor),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close, color: Colors.red, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        AppString.cancel,
                        style: AppTypography.captionText(context).copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send, color: onPrimary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        AppString.send,
                        style: AppTypography.captionText(context).copyWith(
                          color: onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
