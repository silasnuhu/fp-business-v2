import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

class BusinessLocationPicker extends StatefulWidget {
  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;
  final Function(String address, double latitude, double longitude)
  onLocationSelected;

  const BusinessLocationPicker({
    super.key,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
    required this.onLocationSelected,
  });

  @override
  State<BusinessLocationPicker> createState() => _BusinessLocationPickerState();
}

class _BusinessLocationPickerState extends State<BusinessLocationPicker>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  LatLng _selectedLocation = const LatLng(
    23.0225,
    72.5714,
  ); // Default to Ahmedabad, India
  String _selectedAddress = '';
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Google Maps API Key - same as in AndroidManifest.xml
  static const String _googleApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _initializeLocation();
    _animationController.forward();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
      _selectedAddress = widget.initialAddress ?? '';
      _searchController.text = _selectedAddress;
      setState(() {});
    } else {
      await _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      final status = await Permission.locationWhenInUse.status;

      if (status.isDenied) {
        final permission = await Permission.locationWhenInUse.request();

        if (permission.isDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppString.profileStrings.locationPermissionNeeded,
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        if (permission.isPermanentlyDenied) {
          if (mounted) {
            _showPermissionDeniedDialog();
          }
          setState(() => _isLoading = false);
          return;
        }
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          _showPermissionDeniedDialog();
        }
        setState(() => _isLoading = false);
        return;
      }

      if (status.isGranted || status.isLimited) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

        _selectedLocation = LatLng(position.latitude, position.longitude);
        await _getAddressFromLatLng(_selectedLocation);

        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _selectedLocation, zoom: 16),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(AppString.profileStrings.locationPermissionRequired),
            content: Text(AppString.profileStrings.locationAccessNeeded),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppString.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: Text(AppString.openSettings),
              ),
            ],
          ),
    );
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final addressParts = <String>[];

        if (place.name != null && place.name!.isNotEmpty) {
          addressParts.add(place.name!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        _selectedAddress = addressParts.join(', ');
        _searchController.text = _selectedAddress;
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  Future<void> _onPlaceSelected(Prediction prediction) async {
    setState(() => _isLoading = true);

    try {
      // Get place details to extract latitude and longitude
      final locations = await Geocoding().locationFromAddress(
        prediction.description ?? '',
      );

      if (locations.isNotEmpty) {
        final location = locations.first;
        _selectedLocation = LatLng(location.latitude, location.longitude);
        _selectedAddress = prediction.description ?? '';
        _searchController.text = _selectedAddress;

        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _selectedLocation, zoom: 16),
            ),
          );
        }

        setState(() {});
      }
    } catch (e) {
      debugPrint('Error selecting place: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with search
            Container(
              padding: SizeConfig.getPaddingSymmetric(
                horizontal: 16,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: AppThemeManage.appTheme.scaffoldBackColor,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.1),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top bar with back and current location buttons
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: customeBackArrowBalck(
                          context,
                          color: AppThemeManage.appTheme.textColor,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppThemeManage.appTheme.bg4BlackGrey,
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                      ),
                      SizedBox(width: SizeConfig.width(4)),
                      Expanded(
                        child: Text(
                          AppString.profileStrings.selectBusinessLocation,
                          style: AppTypography.h4(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppThemeManage.appTheme.textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _getCurrentLocation,
                        icon: Icon(
                          Icons.my_location,
                          color: AppColors.appPriSecColor.primaryColor,
                          size: SizeConfig.getFontSize(20),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.appPriSecColor.primaryColor
                              .withValues(alpha: 0.1),
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: SizeConfig.height(2)),

                  // Google Places Autocomplete Search Bar
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppThemeManage.appTheme.bg4BlackGrey,
                      border: Border.all(
                        color: AppThemeManage.appTheme.borderColor,
                      ),
                    ),
                    child: GooglePlaceAutoCompleteTextField(
                      textEditingController: _searchController,
                      googleAPIKey: _googleApiKey,
                      inputDecoration: InputDecoration(
                        hintText:
                            AppString
                                .profileStrings
                                .searchForYourBusinessAddress,
                        hintStyle: AppTypography.captionText(context).copyWith(
                          color: AppThemeManage.appTheme.textGreyWhite,
                          fontSize: SizeConfig.getFontSize(14),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppThemeManage.appTheme.textGreyWhite,
                          size: SizeConfig.getFontSize(20),
                        ),
                        suffixIcon:
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: Icon(
                                    Icons.clear,
                                    color:
                                        AppThemeManage.appTheme.textGreyWhite,
                                    size: SizeConfig.getFontSize(18),
                                  ),
                                )
                                : null,
                        border: InputBorder.none,
                        contentPadding: SizeConfig.getPaddingSymmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      textStyle: AppTypography.captionText(context).copyWith(
                        color: AppThemeManage.appTheme.textColor,
                        fontSize: SizeConfig.getFontSize(14),
                      ),
                      debounceTime: 600,
                      isLatLngRequired: true,
                      getPlaceDetailWithLatLng: (prediction) {
                        _onPlaceSelected(prediction);
                      },
                      itemClick: (prediction) {
                        _searchController.text = prediction.description ?? '';
                        _searchController
                            .selection = TextSelection.fromPosition(
                          TextPosition(
                            offset: prediction.description?.length ?? 0,
                          ),
                        );
                        // Immediately update selected address for UI feedback
                        setState(() {
                          _selectedAddress = prediction.description ?? '';
                        });
                        // Trigger the place selection to get coordinates
                        _onPlaceSelected(prediction);
                      },
                      seperatedBuilder: Divider(
                        height: 1,
                        color: AppThemeManage.appTheme.borderColor,
                      ),
                      containerHorizontalPadding: 0,
                      itemBuilder: (context, index, prediction) {
                        return Container(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: AppColors.appPriSecColor.primaryColor,
                                size: SizeConfig.getFontSize(20),
                              ),
                              SizedBox(width: SizeConfig.width(3)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Main text (place name)
                                    Text(
                                      prediction
                                              .structuredFormatting
                                              ?.mainText ??
                                          '',
                                      style: AppTypography.captionText(
                                        context,
                                      ).copyWith(
                                        color:
                                            AppThemeManage.appTheme.textColor,
                                        fontSize: SizeConfig.getFontSize(15),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (prediction
                                            .structuredFormatting
                                            ?.secondaryText !=
                                        null)
                                      SizedBox(height: SizeConfig.height(0.3)),
                                    // Secondary text (address details)
                                    if (prediction
                                            .structuredFormatting
                                            ?.secondaryText !=
                                        null)
                                      Text(
                                        prediction
                                                .structuredFormatting
                                                ?.secondaryText ??
                                            '',
                                        style: AppTypography.captionText(
                                          context,
                                        ).copyWith(
                                          color:
                                              AppThemeManage
                                                  .appTheme
                                                  .textGreyWhite,
                                          fontSize: SizeConfig.getFontSize(13),
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      isCrossBtnShown: false,
                      boxDecoration: BoxDecoration(
                        color: AppThemeManage.appTheme.scaffoldBackColor,
                        border: Border(
                          bottom: BorderSide(
                            color: AppThemeManage.appTheme.borderColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Map
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation,
                      zoom: 16,
                    ),
                    onTap: (LatLng position) async {
                      _selectedLocation = position;
                      await _getAddressFromLatLng(position);
                    },
                    onCameraMove: (CameraPosition position) {
                      _selectedLocation = position.target;
                    },
                    onCameraIdle: () async {
                      await _getAddressFromLatLng(_selectedLocation);
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('selected-location'),
                        position: _selectedLocation,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue,
                        ),
                      ),
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),

                  // Center crosshair
                  Center(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: SizeConfig.sizedBoxWidth(40),
                        height: SizeConfig.sizedBoxHeight(40),
                        decoration: BoxDecoration(
                          color: AppColors.appPriSecColor.primaryColor
                              .withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: SizeConfig.getFontSize(24),
                        ),
                      ),
                    ),
                  ),

                  // Loading overlay
                  if (_isLoading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom action bar
      bottomNavigationBar: Container(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppThemeManage.appTheme.scaffoldBackColor,
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.1),
              offset: const Offset(0, -2),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selected address preview
              if (_selectedAddress.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: SizeConfig.getPaddingSymmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  margin: SizeConfig.getPaddingOnly(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.appPriSecColor.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    border: Border.all(
                      color: AppColors.appPriSecColor.primaryColor.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppString.profileStrings.selectedLocation,
                        style: AppTypography.innerText08(context).copyWith(
                          color: AppColors.appPriSecColor.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: SizeConfig.getFontSize(12),
                        ),
                      ),
                      SizedBox(height: SizeConfig.height(0.5)),
                      Text(
                        _selectedAddress,
                        style: AppTypography.captionText(context).copyWith(
                          color: AppThemeManage.appTheme.textColor,
                          fontSize: SizeConfig.getFontSize(13),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

              // Confirm button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _selectedAddress.isNotEmpty
                          ? () {
                            widget.onLocationSelected(
                              _selectedAddress,
                              _selectedLocation.latitude,
                              _selectedLocation.longitude,
                            );
                            Navigator.pop(context);
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.appPriSecColor.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: SizeConfig.getPaddingSymmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppString.profileStrings.confirmLocation,
                    style: AppTypography.h5(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: SizeConfig.getFontSize(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
