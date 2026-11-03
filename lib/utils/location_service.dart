// import 'dart:convert';
// import 'dart:developer';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;

// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'dart:ui' as ui;

// class LocationService {
//   double latitude = 0.0;
//   double longitude = 0.0;
//   GoogleMapController? mapController;
//   List<dynamic> mapResult = [];

//   static const String kPlaceApiKey = googleMapKey;

//   /// **Check and Request Location Permission**
//   Future<void> checkLocationPermission() async {
//     LocationPermission permission = await Geolocator.checkPermission();

//     if (permission == LocationPermission.deniedForever) {
//       debugPrint(
//         "This app needs location permission. Please allow location access.",
//       );
//     } else if (permission == LocationPermission.denied) {
//       LocationPermission newPermission = await Geolocator.requestPermission();
//       if (newPermission == LocationPermission.denied) {
//         debugPrint("Please allow location access.");
//       } else {
//         await getCurrentLocation();
//       }
//     } else {
//       await getCurrentLocation();
//     }
//   }

//   /// **Get Current Location**
//   Future<void> getCurrentLocation() async {
//     try {
//       Position position = await Geolocator.getCurrentPosition(
//         locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
//       );

//       latitude = position.latitude;
//       longitude = position.longitude;

//       log("LAT: $latitude");
//       log("LONG: $longitude");
//     } catch (e) {
//       debugPrint("Error getting location: ${e.toString()}");
//     }
//   }

//   /// **Get Location Suggestions**
//   Future<void> getSuggestions(String input) async {
//     String baseURL =
//         "https://maps.googleapis.com/maps/api/place/autocomplete/json";
//     String request =
//         '$baseURL?input=$input&key=$kPlaceApiKey&sessiontoken=$kPlaceApiKey';

//     var response = await http.get(Uri.parse(request));
//     if (response.statusCode == 200) {
//       mapResult = jsonDecode(response.body)['predictions'];
//     } else {
//       debugPrint("Problem getting location suggestions.");
//     }
//   }

//   /// **Get Latitude & Longitude from Address**
//   Future<void> getLatLngFromAddress(String input) async {
//     String baseURL =
//         'https://maps.googleapis.com/maps/api/geocode/json?address=$input&key=$kPlaceApiKey';

//     var response = await http.get(Uri.parse(baseURL));
//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       final location = data['results'][0]['geometry']['location'];

//       latitude = location['lat'];
//       longitude = location['lng'];

//       mapController?.animateCamera(
//         CameraUpdate.newLatLng(LatLng(latitude, longitude)),
//       );

//       debugPrint('Latitude: $latitude');
//       debugPrint('Longitude: $longitude');
//     } else {
//       debugPrint('Error getting location data.');
//     }
//   }

//   /// **Convert Asset Image to Bytes for Custom Marker**
//   Future<Uint8List> getBytesFromAsset(
//     String path,
//     int width,
//     int height,
//   ) async {
//     final byteData = await rootBundle.load(path);
//     final codec = await ui.instantiateImageCodec(
//       byteData.buffer.asUint8List(),
//       targetWidth: width,
//       targetHeight: height,
//     );
//     final frame = await codec.getNextFrame();
//     return (await frame.image.toByteData(
//       format: ui.ImageByteFormat.png,
//     ))!.buffer.asUint8List();
//   }
// }

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';

import 'dart:ui' as ui;

import 'package:whoxa/widgets/global.dart';

class LocationService {
  double latitude = 0.0;
  double longitude = 0.0;
  GoogleMapController? mapController;
  List<dynamic> mapResult = [];
  String? locationAddress;

  static final String kPlaceApiKey = googleMapKey;

  final Dio _dio = Dio();

  /// **Check and Request Location Permission**
  Future<void> checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
        "This app needs location permission. Please allow location access.",
      );
    } else if (permission == LocationPermission.denied) {
      LocationPermission newPermission = await Geolocator.requestPermission();
      if (newPermission == LocationPermission.denied) {
        debugPrint("Please allow location access.");
      } else {
        await getCurrentLocation();
      }
    } else {
      await getCurrentLocation();
    }
  }

  /// **Get Current Location**
  Future<void> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      );

      latitude = position.latitude;
      longitude = position.longitude;

      log("LAT: $latitude");
      log("LONG: $longitude");
      await getUserLocation(latitude, longitude);
    } catch (e) {
      debugPrint("Error getting location: ${e.toString()}");
    }
  }

  Future<void> getUserLocation(double lat, double lon) async {
    List<Placemark> placemarks;
    try {
      placemarks = await Geocoding().placemarkFromCoordinates(lat, lon);
    } catch (e) {
      // Reverse geocoding can fail (no Geocoder service, no network, etc.)
      debugPrint("Reverse geocoding failed: $e");
      return;
    }
    if (placemarks.isEmpty) return;

    Placemark place = placemarks[0];
    log("$place PLACE");

    locationAddress =
        "${place.name}, ${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
  }

  /// **Get Location Suggestions using Dio**
  Future<void> getSuggestions(String input) async {
    String baseURL =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json";
    String request =
        '$baseURL?input=$input&key=$kPlaceApiKey&sessiontoken=$kPlaceApiKey';

    try {
      final response = await _dio.get(request);
      if (response.statusCode == 200) {
        mapResult = response.data['predictions'];
      } else {
        debugPrint("Problem getting location suggestions.");
      }
    } catch (e) {
      debugPrint("Dio error in getSuggestions: $e");
    }
  }

  /// **Get Latitude & Longitude from Address using Dio**
  Future<void> getLatLngFromAddress(String input) async {
    String baseURL =
        'https://maps.googleapis.com/maps/api/geocode/json?address=$input&key=$kPlaceApiKey';

    try {
      final response = await _dio.get(baseURL);
      if (response.statusCode == 200) {
        final data = response.data;
        final location = data['results'][0]['geometry']['location'];

        latitude = location['lat'];
        longitude = location['lng'];

        mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(latitude, longitude)),
        );

        debugPrint('Latitude: $latitude');
        debugPrint('Longitude: $longitude');
      } else {
        debugPrint('Error getting location data.');
      }
    } catch (e) {
      debugPrint("Dio error in getLatLngFromAddress: $e");
    }
  }

  /// **Convert Asset Image to Bytes for Custom Marker**
  Future<Uint8List> getBytesFromAsset(
    String path,
    int width,
    int height,
  ) async {
    final byteData = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      byteData.buffer.asUint8List(),
      targetWidth: width,
      targetHeight: height,
    );
    final frame = await codec.getNextFrame();
    return (await frame.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }
}
