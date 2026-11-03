import 'dart:convert';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:whoxa/featuers/chat/widgets/location_send_preview.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:geocoding/geocoding.dart';

// ignore: must_be_immutable
class LocationScreen extends StatefulWidget {
  double latitude;
  double longitude;
  final String userLocation;
  LocationScreen({
    super.key,
    this.latitude = 0,
    this.longitude = 0,
    required this.userLocation,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String placeApiKey = googleMapKey;
  Set<Marker> markers = {};
  String locName = '';
  String locality = '';
  TextEditingController searchController = TextEditingController();
  GoogleMapController? _controller;
  String selectedAddress = "";
  bool isHide = true;

  // The marker icon is loaded once, not on every tap.
  BitmapDescriptor? _markerIcon;

  Future<void> _loadMarkerIcon() async {
    if (_markerIcon != null) return;
    try {
      _markerIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(),
        "assets/images/location_red.png",
        height: 30,
      );
    } catch (e) {
      // Still show a marker if the asset fails to load.
      debugPrint("Marker icon load failed: $e");
      _markerIcon = BitmapDescriptor.defaultMarker;
    }
  }

  Future<void> setImageAsMarker(
    double latitude,
    double longitude,
    dynamic markerID,
  ) async {
    await _loadMarkerIcon();
    if (!mounted) return;

    final marker = Marker(
      markerId: MarkerId(markerID.toString()),
      position: LatLng(latitude, longitude), //position of marker
      infoWindow: const InfoWindow(
        //popup info
        title: ' You are here ',
        snippet: '',
      ),
      icon: _markerIcon!, //Icon for Marker
      draggable: true,
      onDragStart: (value) async {
        _mapresult.clear();
        FocusScope.of(context).unfocus();
      },
      onDragEnd: (value) {
        log('$value LAtLNG Value');
        setState(() {
          _latitude = value.latitude;
          _longitude = value.longitude;
        });
        getUserLocation(_latitude, _longitude);
      },
    );

    setState(() {
      // Assign a new Set (do not mutate the old one) so GoogleMap reliably
      // detects the change. There is always exactly one marker on screen.
      markers = {marker};
    });
  }

  Future<void> _onMapTapped(LatLng point) async {
    debugPrint('MAP TAPPED: ${point.latitude}, ${point.longitude}');
    FocusScope.of(context).unfocus();
    _mapresult.clear();
    searchController.clear();
    setState(() {
      _latitude = point.latitude;
      _longitude = point.longitude;
      isHide = true;
    });
    await setImageAsMarker(point.latitude, point.longitude, "Selected Location");
    _controller?.animateCamera(CameraUpdate.newLatLng(point));
    await getUserLocation(point.latitude, point.longitude);
  }

  var _latitude = 0.0;
  var _longitude = 0.0;
  var uuid = const Uuid();
  final String _sessionToken = "";
  List<dynamic> _mapresult = [];

  void onChange() {
    getsuggestion(searchController.text);
  }

  Future<void> getUserLocation(double lat, double lon) async {
    List<Placemark> placemarks;
    try {
      placemarks = await Geocoding().placemarkFromCoordinates(lat, lon);
    } catch (e) {
      debugPrint("Reverse geocoding failed: $e");
      return;
    }
    if (placemarks.isEmpty || !mounted) return;
    Placemark place = placemarks[0];
    log("$place PLACE");
    setState(() {
      locality = place.locality ?? '';
      locName = place.name ?? '';
      selectedAddress =
          "${place.name}, ${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
    });
    setState(() {});
  }

  void getsuggestion(String input) async {
    final request = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {'input': input, 'key': placeApiKey, 'sessiontoken': _sessionToken},
    );

    var response = await http.get(request);

    debugPrint(response.body.toString());
    if (response.statusCode == 200) {
      setState(() {
        _mapresult = jsonDecode(response.body)['predictions'];
      });
      log("Map Result $_mapresult");
    } else {
      if (!mounted) return;
      snackbarNew(context, msg: "Problem while getting Location");
    }
  }

  /// Resolves a search prediction to coordinates. Looks up by place_id when
  /// available (exact place), else by the address text. Returns false if the
  /// place could not be resolved, leaving the current selection untouched.
  Future<bool> getLonLat(String input, {String? placeId}) async {
    final request = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      if (placeId != null && placeId.isNotEmpty)
        'place_id': placeId
      else
        'address': input,
      'key': placeApiKey,
    });

    try {
      var response = await http.get(request);

      debugPrint(response.body.toString());
      if (response.statusCode != 200) {
        debugPrint('Error getting location data: ${response.statusCode}');
        return false;
      }

      final data = jsonDecode(response.body);
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) {
        debugPrint('Geocode returned no results: ${data['status']}');
        return false;
      }
      final location = results[0]['geometry']['location'];

      log("LOCATION--- $location");

      if (!mounted) return false;
      setState(() {
        _latitude = (location['lat'] as num).toDouble();
        _longitude = (location['lng'] as num).toDouble();
      });

      debugPrint('Latitude: $_latitude');
      debugPrint('Longitude: $_longitude');
      return true;
    } catch (e) {
      debugPrint('Error getting location data: $e');
      return false;
    }
  }

  void onMapCreatedLight() async {
    // Load JSON depending on theme
    String style = await rootBundle.loadString(AppAssets.lightMap);
    // ignore: deprecated_member_use
    _controller?.setMapStyle(style);
  }

  void onMapCreatedNight() async {
    // Load JSON depending on theme
    String style = await rootBundle.loadString(AppAssets.darkMap);
    // ignore: deprecated_member_use
    _controller?.setMapStyle(style);
  }

  List<dynamic> _nearbyPlaces = [];

  Future<void> getNearbyPlaces(double lat, double lon) async {
    log("Near_Lat:$lat and long:$lon");
    String apiKey = placeApiKey; // put your key here
    final String url =
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lon&radius=1500&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        _nearbyPlaces = data["results"];
      });
    } else {
      debugPrint("Nearby places fetch failed: ${response.statusCode}");
    }
  }

  final FocusNode searchFocusNode = FocusNode();
  @override
  void initState() {
    selectedAddress = widget.userLocation;
    setState(() {
      _latitude = widget.latitude;
      _longitude = widget.longitude;
      getUserLocation(widget.latitude, widget.longitude);
    });
    setImageAsMarker(widget.latitude, widget.longitude, widget.userLocation);
    log("LATITUDE AND LONGITUDE ${widget.latitude} : ${widget.longitude}");
    getNearbyPlaces(widget.latitude, widget.longitude);
    _controller?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(widget.latitude, widget.longitude),
          zoom: 10.0,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
    searchFocusNode.addListener(() {
      if (!searchFocusNode.hasFocus) {
        // Keyboard closed
        setState(() {
          isHide = true;
        });
      } else {
        // Keyboard open
        setState(() {
          isHide = false;
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _controller?.dispose();
    searchController.dispose();
    searchFocusNode.dispose();
    // addressController.searchAddressController.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          shape: Border(
            bottom: BorderSide(color: AppThemeManage.appTheme.borderColor),
          ),
          backgroundColor: AppColors.transparent,
          systemOverlayStyle: systemUI(),
          flexibleSpace: flexibleSpace(),
          titleSpacing: 0,
          leading: Padding(
            padding: SizeConfig.getPadding(12),
            child: customeBackArrowBalck(context),
          ),
          title: Text(
            AppString.locationStrings.sendLocation,
            style: AppTypography.h220(context)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(widget.latitude, widget.longitude),
                        zoom: 14,
                      ),
                      markers: markers, //markers to show on map
                      zoomGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      indoorViewEnabled: true,
                      // onMapCreated: onMapCreated,
                      onMapCreated: (GoogleMapController mcontroller) {
                        _controller = mcontroller;
                        if (isLightModeGlobal) {
                          onMapCreatedLight();
                        } else {
                          onMapCreatedNight();
                        }
                      },
                      // Tapping anywhere on the map moves the pin there and
                      // sends that point (address is looked up for it).
                      onTap: _onMapTapped,
                      onCameraIdle: () async {
                        await _controller!.getVisibleRegion();
                        setState(() {});
                      },
                    ),
                    searchLocationTextField(),
                  ],
                ),
              ),
              isHide ? addressField() : searchAddressMapResult(),
            ],
          ),
          // _mapresult.isEmptys
          //     ? const SizedBox.shrink()
          //     : Column(
          //       children: [
          //         const SizedBox(height: 60),
          //         Padding(
          //           padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
          //           child: Container(
          //             width: MediaQuery.of(context).size.width,
          //             height: 110,
          //             decoration: BoxDecoration(
          //               color: Colors.white,
          //               borderRadius: BorderRadius.circular(5),
          //               border: Border.all(color: Colors.grey),
          //             ),
          //             child: ListView.builder(
          //               itemCount: _mapresult.length,
          //               itemBuilder: (context, index) {
          //                 return InkWell(
          //                   onTap: () async {
          //                     searchController.text =
          //                         await _mapresult[index]['description'];
          //                     // addressController.searchAddressController.text =
          //                     //     await _mapresult[index]['description'];
          //                     FocusScope.of(context).unfocus();
          //                     // setState(() async {

          //                     _mapresult.clear();
          //                     markers.clear();

          //                     await getLonLat(searchController.text);

          //                     await setImageAsMarker(_latitude, _longitude, "");
          //                     await getUserLocation(_latitude, _longitude);
          //                     if (_controller != null) {
          //                       _controller!.animateCamera(
          //                         CameraUpdate.newLatLng(
          //                           LatLng(_latitude, _longitude),
          //                         ),
          //                       );
          //                       setState(() {});
          //                     } else {
          //                       log("Controller is Null");
          //                     }
          //                     setState(() {});
          //                   },
          //                   child: ListTile(
          //                     title: Text(_mapresult[index]['description']),
          //                     // tileColor: Colors.grey,
          //                     horizontalTitleGap: 1.0,
          //                   ),
          //                 );
          //               },
          //             ),
          //           ),
          //         ),
          //       ],
          //     ),
        ],
      ),
    );
  }

  Widget addressField() {
    return SizedBox(
      height: SizeConfig.height(40),
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SizeConfig.height(5)),
                Text(
                  AppString.locationStrings.nearbyPlaces,
                  style: AppTypography.innerText16(context),
                ),
                SizedBox(height: SizeConfig.height(2)),

                // Nearby Places List
                Expanded(
                  child: _nearbyPlaces.isEmpty
                      ? Center(
                          child: Text(
                            AppString.noNearbyLocationFound,
                            style: AppTypography.innerText14(context),
                          ),
                        )
                      : ListView.builder(
                          itemCount:
                              _nearbyPlaces.length +
                              1, // +1 for current location
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              // Show current location first
                              return Padding(
                                padding: SizeConfig.getPaddingOnly(bottom: 10),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _latitude = widget.latitude;
                                      _longitude = widget.longitude;
                                    });

                                    _controller?.animateCamera(
                                      CameraUpdate.newLatLng(
                                        LatLng(_latitude, _longitude),
                                      ),
                                    );

                                    markers.clear();
                                    setImageAsMarker(
                                      _latitude,
                                      _longitude,
                                      "Current Location",
                                    );

                                    selectedAddress = widget.userLocation;
                                    searchController.clear();
                                    _mapresult.clear();
                                  },
                                  child: Container(
                                    padding: SizeConfig.getPadding(10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color:
                                            AppThemeManage.appTheme.borderColor,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SvgPicture.asset(
                                          AppAssets.chatMsgTypeIcon.locationRed,
                                          height: 16,
                                        ),
                                        SizedBox(width: SizeConfig.width(2)),
                                        Flexible(
                                          child: Text(
                                            widget.userLocation,
                                            style:
                                                AppTypography.innerText12Mediu(
                                                  context,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Other nearby places
                            final place =
                                _nearbyPlaces[index - 1]; // shift by 1
                            return Padding(
                              padding: SizeConfig.getPaddingOnly(bottom: 10),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _latitude =
                                        place["geometry"]["location"]["lat"] *
                                        1.0;
                                    _longitude =
                                        place["geometry"]["location"]["lng"] *
                                        1.0;
                                  });

                                  _controller?.animateCamera(
                                    CameraUpdate.newLatLng(
                                      LatLng(_latitude, _longitude),
                                    ),
                                  );

                                  markers.clear();
                                  setImageAsMarker(
                                    _latitude,
                                    _longitude,
                                    place["name"],
                                  );

                                  selectedAddress =
                                      "${place["name"] ?? ""} ${place["vicinity"] ?? ""}";
                                  searchController.clear();
                                  _mapresult.clear();
                                },
                                child: Container(
                                  padding: SizeConfig.getPadding(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          AppThemeManage.appTheme.borderColor,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      selectedAddress.isNotEmpty &&
                                              selectedAddress ==
                                                  "${place["name"] ?? ""} ${place["vicinity"] ?? ""}"
                                          ? SvgPicture.asset(
                                              AppAssets
                                                  .chatMsgTypeIcon
                                                  .locationRed,
                                              height: 16,
                                            )
                                          : SvgPicture.asset(
                                              AppAssets
                                                  .chatMsgTypeIcon
                                                  .locationMsg,
                                              colorFilter: ColorFilter.mode(
                                                AppThemeManage
                                                    .appTheme
                                                    .darkWhiteColor,
                                                BlendMode.srcIn,
                                              ),
                                              height: 16,
                                            ),
                                      SizedBox(width: SizeConfig.width(2)),
                                      Flexible(
                                        child: Text(
                                          "${place["name"] ?? ""} ${place["vicinity"] ?? ""}",
                                          style: AppTypography.innerText12Mediu(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(top: -30, left: 0, right: 0, child: selectedLocation()),
          ],
        ),
      ),
    );
  }

  Widget searchAddressMapResult() {
    return SizedBox(
      height: SizeConfig.height(40),
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: SizeConfig.height(5)),
            Text(
              AppString.locationStrings.searchPlaces,
              style: AppTypography.innerText16(context),
            ),
            SizedBox(height: SizeConfig.height(2)),

            // Nearby Places List
            Expanded(
              child: _mapresult.isEmpty
                  ? Center(
                      child: Text(
                        AppString.searchLocationNotFound,
                        style: AppTypography.innerText16(context),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _mapresult.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: SizeConfig.getPaddingOnly(bottom: 10),
                          child: GestureDetector(
                            onTap: () async {
                              final String selected =
                                  _mapresult[index]['description'];
                              final String? placeId =
                                  _mapresult[index]['place_id'];

                              // update text
                              searchController.text = selected;
                              FocusScope.of(context).unfocus();

                              final resolved = await getLonLat(
                                selected,
                                placeId: placeId,
                              );
                              if (!mounted) return;
                              if (!resolved) {
                                snackbarNew(
                                  this.context,
                                  msg: "Problem while getting Location",
                                );
                                return;
                              }

                              // Only show the searched address once its
                              // coordinates are the ones that will be sent
                              setState(() {
                                selectedAddress = selected;
                              });

                              markers.clear();
                              await setImageAsMarker(
                                _latitude,
                                _longitude,
                                "Search Location",
                              );

                              // move map
                              _controller?.animateCamera(
                                CameraUpdate.newLatLng(
                                  LatLng(_latitude, _longitude),
                                ),
                              );

                              // 🔑 after everything, clear results
                              setState(() {
                                _mapresult.clear();
                                isHide = true;
                              });
                            },
                            child: Container(
                              padding: SizeConfig.getPadding(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppThemeManage.appTheme.borderColor,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  selectedAddress.isNotEmpty
                                      ? (selectedAddress ==
                                                _mapresult[index]['description'])
                                            ? SvgPicture.asset(
                                                AppAssets
                                                    .chatMsgTypeIcon
                                                    .locationRed,
                                                height: 16,
                                              )
                                            : SvgPicture.asset(
                                                AppAssets
                                                    .chatMsgTypeIcon
                                                    .locationMsg,
                                                colorFilter: ColorFilter.mode(
                                                  AppThemeManage
                                                      .appTheme
                                                      .darkWhiteColor,
                                                  BlendMode.srcIn,
                                                ),
                                                height: 16,
                                              )
                                      : SvgPicture.asset(
                                          AppAssets.chatMsgTypeIcon.locationMsg,
                                          colorFilter: ColorFilter.mode(
                                            AppThemeManage
                                                .appTheme
                                                .darkWhiteColor,
                                            BlendMode.srcIn,
                                          ),
                                          height: 16,
                                        ),
                                  SizedBox(width: SizeConfig.width(2)),
                                  Flexible(
                                    child: Text(
                                      _mapresult[index]['description'],
                                      style: AppTypography.innerText12Mediu(
                                        context,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget selectedLocation() {
    return InkWell(
      onTap: () async {
        // Let the user re-check the pin and address before sending; cancel
        // keeps them on the picker to choose again.
        final send = await showLocationSendPreview(
          context,
          latitude: _latitude,
          longitude: _longitude,
          address: selectedAddress,
        );
        if (!send || !mounted) return;
        Navigator.pop(context, {
          "latitude": _latitude,
          "longitude": _longitude,
          // "address": selectedAddress,
        });
      },
      splashFactory: NoSplash.splashFactory,
      child: Container(
        height: SizeConfig.sizedBoxHeight(62),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.9),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    AppAssets.chatMsgTypeIcon.locationMsg,
                    height: 16,
                  ),
                  SizedBox(width: SizeConfig.width(2)),
                  SizedBox(
                    width: SizeConfig.width(65),
                    child: Text(
                      selectedAddress,
                      style: AppTypography.innerText12Mediu(context)
                          .copyWith(color: AppColors.textColor.textBlackColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Icon(Icons.arrow_forward_ios_sharp, size: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget searchLocationTextField() {
    return Padding(
      padding: SizeConfig.getPaddingOnly(left: 20, right: 20, top: 10),
      child: TextFormField(
        controller: searchController,
        onEditingComplete: () {},
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onSaved: (newValue) {
          FocusScope.of(context).nextFocus();
        },
        // onTap: () {
        //   setState(() {
        //     isHide = false;
        //   });
        // },
        onChanged: (value) {
          if (value.isEmpty) {
            setState(() {
              _mapresult.clear();
            });
          } else {
            onChange(); // your API call to fetch places
          }
        },
        readOnly: false,
        focusNode: searchFocusNode,
        maxLines: 1,
        style: AppTypography.innerText12Ragu(context),
        decoration: InputDecoration(
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          fillColor: AppThemeManage.appTheme.darkGreyColor,
          filled: true,
          hintText: AppString.locationStrings.searchPlace,
          hintStyle: AppTypography.innerText12Ragu(context)
              .copyWith(color: AppColors.textColor.textDarkGray),
          prefixIcon: Padding(
            padding: SizeConfig.getPadding(15),
            child: SvgPicture.asset(
              AppAssets.homeIcons.search,
              colorFilter: ColorFilter.mode(
                AppColors.textColor.textDarkGray,
                BlendMode.srcIn,
              ),
              height: SizeConfig.safeHeight(2),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          return null;
        },
      ),
    );
  }
}

String darkMap = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#242f3e"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#746855"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#242f3e"
      }
    ]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#263c3f"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#6b9a76"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#38414e"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#212a37"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9ca5b3"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#746855"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#1f2835"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#f3d19c"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#2f3948"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#17263c"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#515c6d"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#17263c"
      }
    ]
  }
]
''';

String lightMap = '''
[
    {
        "featureType": "all",
        "elementType": "labels.text.fill",
        "stylers": [
            {
                "color": "#000000"
            }
        ]
    },
    {
        "featureType": "all",
        "elementType": "labels.text.stroke",
        "stylers": [
            {
                "color": "#ffffff"
            }
        ]
    },
    {
        "featureType": "administrative",
        "elementType": "geometry.fill",
        "stylers": [
            {
                "color": "#d6e2e6"
            }
        ]
    },
    {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
            {
                "color": "#f2f2f2"
            }
        ]
    },
    {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
            {
                "color": "#b5d3e7"
            }
        ]
    }
]
''';
