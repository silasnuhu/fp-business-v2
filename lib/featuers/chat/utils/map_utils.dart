import 'dart:math' as math;

import 'package:whoxa/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

/// Utility class for map-related functionality
class MapUtils {
  static final ConsoleAppLogger _logger = ConsoleAppLogger();

  /// Open the location in a map application.
  /// Works for both iOS and Android.
  static Future<void> openMap(double latitude, double longitude) async {
    String url = '';

    try {
      if (Platform.isIOS) {
        // For iOS, use Apple Maps
        url = 'https://maps.apple.com/?q=$latitude,$longitude';
      } else {
        // For Android, use Google Maps
        url =
            'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      }

      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to Google Maps web if app cannot be launched
        final webUrl =
            'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
        final webUri = Uri.parse(webUrl);
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch map';
        }
      }
    } catch (e) {
      _logger.e('Error opening map: $e');
      throw 'Error opening map: $e';
    }
  }

  /// Get a static map image URL for a specific location.
  /// Useful for thumbnails or preview images.
  static String getStaticMapUrl(
    double latitude,
    double longitude, {
    int zoom = 15,
    int width = 600,
    int height = 300,
    String mapType = 'roadmap',
    String apiKey = '', // Add your own Google Maps API key
  }) {
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$latitude,$longitude'
        '&zoom=$zoom'
        '&size=${width}x$height'
        '&maptype=$mapType'
        '&markers=color:red%7C$latitude,$longitude'
        '&key=$apiKey';
  }

  /// Calculate the distance between two geographical coordinates
  /// Returns distance in kilometers
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const int earthRadius = 6371; // Earth's radius in kilometers

    // Convert degrees to radians
    final double startLatRad = _degreesToRadians(startLatitude);
    final double startLongRad = _degreesToRadians(startLongitude);
    final double endLatRad = _degreesToRadians(endLatitude);
    final double endLongRad = _degreesToRadians(endLongitude);

    // Calculate differences
    final double latDiff = endLatRad - startLatRad;
    final double longDiff = endLongRad - startLongRad;

    // Haversine formula
    final double a =
        _square(math.sin(latDiff / 2)) +
        math.cos(startLatRad) *
            math.cos(endLatRad) *
            _square(math.sin(longDiff / 2));
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Square a number
  static double _square(double value) {
    return value * value;
  }
}
