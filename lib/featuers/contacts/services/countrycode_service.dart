import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CountryCodeService {
  static Map<String, dynamic>? _countryCodesData;
  static bool _isInitialized = false;

  // Reverse lookup map: ISO country code -> dial code
  // Built lazily from countryCodesData during initialization
  static Map<String, String>? _isoToDialCodeMap;

  // Initialize the service by loading the JSON file
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/country_codes.json',
      );
      _countryCodesData = json.decode(jsonString);
      _isInitialized = true;
      // Build the reverse lookup map
      _buildIsoToDialCodeMap();
    } catch (e) {
      debugPrint('Error loading country codes: $e');
      _countryCodesData = {};
      _isoToDialCodeMap = {};
      _isInitialized = true;
    }
  }

  // Build reverse lookup map from ISO code to dial code
  static void _buildIsoToDialCodeMap() {
    _isoToDialCodeMap = {};
    final countryCodes = _countryCodesData?['country_codes'] as Map<String, dynamic>?;

    if (countryCodes == null) return;

    // Sort by dial code length (shorter first) so that for countries with
    // multiple dial codes (like Dominican Republic with 1809, 1829, 1849),
    // we prefer the primary/shorter one
    final sortedEntries = countryCodes.entries.toList()
      ..sort((a, b) => a.key.length.compareTo(b.key.length));

    for (final entry in sortedEntries) {
      final dialCode = entry.key;
      final countryInfo = entry.value as Map<String, dynamic>;
      final countries = countryInfo['countries'] as List<dynamic>?;

      if (countries != null) {
        for (final isoCode in countries) {
          // Only set if not already set (prefer shorter/primary dial codes)
          if (!_isoToDialCodeMap!.containsKey(isoCode)) {
            _isoToDialCodeMap![isoCode.toString().toUpperCase()] = dialCode;
          }
        }
      }
    }

    debugPrint('CountryCodeService: Built ISO-to-dial map with ${_isoToDialCodeMap!.length} entries');
  }

  // Get country codes data
  static Map<String, dynamic> get countryCodesData {
    if (!_isInitialized) {
      throw Exception(
        'CountryCodeService not initialized. Call initialize() first.',
      );
    }
    return _countryCodesData?['country_codes'] ?? {};
  }

  // Check if a country code exists
  static bool isValidCountryCode(String code) {
    return countryCodesData.containsKey(code);
  }

  // Get country info by code
  static Map<String, dynamic>? getCountryInfo(String code) {
    return countryCodesData[code];
  }

  // Get primary country code for a country code
  static String? getPrimaryCountry(String code) {
    final info = getCountryInfo(code);
    if (info != null &&
        info['countries'] is List &&
        (info['countries'] as List).isNotEmpty) {
      return (info['countries'] as List).first;
    }
    return null;
  }

  // Get all possible country codes sorted by length (longest first for better matching)
  static List<String> getAllCountryCodesSorted() {
    final codes = countryCodesData.keys.toList();
    codes.sort((a, b) => b.length.compareTo(a.length));
    return codes;
  }

  // Find the best matching country code for a phone number
  static String? findBestMatchingCountryCode(String phoneNumber) {
    if (!phoneNumber.startsWith('+')) return null;

    final numberWithoutPlus = phoneNumber.substring(1);
    final sortedCodes = getAllCountryCodesSorted();

    for (String code in sortedCodes) {
      if (numberWithoutPlus.startsWith(code)) {
        return code;
      }
    }

    return null;
  }

  /// Get dial code from ISO country code (e.g., 'US' -> '1', 'IN' -> '91')
  /// Returns null if ISO code is not found
  static String? getDialCodeFromISO(String isoCode) {
    if (!_isInitialized) {
      debugPrint('CountryCodeService not initialized. Call initialize() first.');
      return null;
    }

    if (_isoToDialCodeMap == null) {
      _buildIsoToDialCodeMap();
    }

    final result = _isoToDialCodeMap?[isoCode.toUpperCase()];
    debugPrint('CountryCodeService.getDialCodeFromISO($isoCode) -> $result');
    return result;
  }

  /// Get ISO to dial code map (for debugging)
  static Map<String, String> get isoToDialCodeMap {
    if (!_isInitialized) {
      throw Exception(
        'CountryCodeService not initialized. Call initialize() first.',
      );
    }
    return _isoToDialCodeMap ?? {};
  }
}
