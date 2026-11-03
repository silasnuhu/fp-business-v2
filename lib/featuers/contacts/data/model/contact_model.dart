// import 'dart:typed_data';
// import 'package:flutter/material.dart';

// class ContactModel {
//   final String name;
//   final String phoneNumber;
//   final String? userId;
//   final Uint8List? photo;
//   final String _formattedNumber;

//   ContactModel({
//     required this.name,
//     required this.phoneNumber,
//     this.userId,
//     this.photo,
//   }) : _formattedNumber = _formatPhoneNumber(phoneNumber);

//   // Factory constructor with null safety
//   factory ContactModel.fromJson(Map<String, dynamic> json) {
//     return ContactModel(
//       name:
//           json['name']?.toString() ??
//           json['full_name']?.toString() ??
//           'Unknown',
//       phoneNumber:
//           json['phone_number']?.toString() ??
//           json['mobile_num']?.toString() ??
//           json['phoneNumber']?.toString() ??
//           '',
//       userId: json['user_id']?.toString() ?? json['id']?.toString(),
//       photo: null, // Handle photo parsing if needed
//     );
//   }

//   // Convert to JSON
//   Map<String, dynamic> toJson() {
//     return {
//       'name': name,
//       'phone_number': phoneNumber,
//       'user_id': userId,
//       // Add other fields as needed
//     };
//   }

//   // Get initials for avatar
//   String get initials {
//     if (name.isEmpty) return '';

//     final nameParts = name.split(' ');
//     if (nameParts.length > 1) {
//       return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
//     } else if (name.isNotEmpty) {
//       return name[0].toUpperCase();
//     }
//     return '';
//   }

//   // Get the formatted phone number
//   String get formattedPhoneNumber => _formattedNumber;

//   // Static method to format phone numbers
//   static String _formatPhoneNumber(String phoneNumber) {
//     // Clean the number to only have digits and possibly a '+' at the start
//     String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

//     if (cleanNumber.isEmpty) return phoneNumber;

//     // Check if it already has a country code with '+'
//     if (cleanNumber.startsWith('+')) {
//       return _formatNumberWithPlus(cleanNumber);
//     }

//     // Check for standard country code patterns
//     // These are definitive country codes we can be confident about
//     Map<String, List<RegExp>> definiteCountryCodes = {
//       '1': [RegExp(r'^1[2-9]\d{9}$')], // US/Canada
//       '7': [RegExp(r'^7[0-9]{10}$')], // Russia
//       '20': [RegExp(r'^20[1-9][0-9]{8}$')], // Egypt
//       '27': [RegExp(r'^27[0-9]{9}$')], // South Africa
//       '30': [RegExp(r'^30[0-9]{9}$')], // Greece
//       '31': [RegExp(r'^31[0-9]{9}$')], // Netherlands
//       '32': [RegExp(r'^32[0-9]{9}$')], // Belgium
//       '33': [RegExp(r'^33[1-9][0-9]{8}$')], // France
//       '34': [RegExp(r'^34[0-9]{9}$')], // Spain
//       '36': [RegExp(r'^36[0-9]{9}$')], // Hungary
//       '39': [RegExp(r'^39[0-9]{9,10}$')], // Italy
//       '40': [RegExp(r'^40[0-9]{9}$')], // Romania
//       '41': [RegExp(r'^41[0-9]{9}$')], // Switzerland
//       '43': [RegExp(r'^43[0-9]{10,11}$')], // Austria
//       '44': [RegExp(r'^44[0-9]{10}$')], // UK
//       '45': [RegExp(r'^45[0-9]{8}$')], // Denmark
//       '46': [RegExp(r'^46[0-9]{9}$')], // Sweden
//       '47': [RegExp(r'^47[0-9]{8}$')], // Norway
//       '48': [RegExp(r'^48[0-9]{9}$')], // Poland
//       '49': [RegExp(r'^49[0-9]{10,11}$')], // Germany
//       '51': [RegExp(r'^51[0-9]{9}$')], // Peru
//       '52': [RegExp(r'^52[0-9]{10}$')], // Mexico
//       '53': [RegExp(r'^53[0-9]{8}$')], // Cuba
//       '54': [RegExp(r'^54[0-9]{10}$')], // Argentina
//       '55': [RegExp(r'^55[0-9]{10,11}$')], // Brazil
//       '56': [RegExp(r'^56[0-9]{9}$')], // Chile
//       '57': [RegExp(r'^57[0-9]{10}$')], // Colombia
//       '58': [RegExp(r'^58[0-9]{10}$')], // Venezuela
//       '60': [RegExp(r'^60[0-9]{9,10}$')], // Malaysia
//       '61': [RegExp(r'^61[0-9]{9}$')], // Australia
//       '62': [RegExp(r'^62[0-9]{10,12}$')], // Indonesia
//       '63': [RegExp(r'^63[0-9]{10}$')], // Philippines
//       '64': [RegExp(r'^64[0-9]{9,10}$')], // New Zealand
//       '65': [RegExp(r'^65[0-9]{8}$')], // Singapore
//       '66': [RegExp(r'^66[0-9]{9}$')], // Thailand
//       '81': [RegExp(r'^81[0-9]{9,10}$')], // Japan
//       '82': [RegExp(r'^82[0-9]{9,10}$')], // South Korea
//       '84': [RegExp(r'^84[0-9]{9,10}$')], // Vietnam
//       '86': [RegExp(r'^86[0-9]{10,11}$')], // China
//       '90': [RegExp(r'^90[0-9]{10}$')], // Turkey
//       '91': [RegExp(r'^91[6-9][0-9]{9}$')], // India with country code
//       '92': [RegExp(r'^92[0-9]{10}$')], // Pakistan
//       '93': [RegExp(r'^93[0-9]{9}$')], // Afghanistan
//       '94': [RegExp(r'^94[0-9]{9}$')], // Sri Lanka
//       '95': [RegExp(r'^95[0-9]{9,10}$')], // Myanmar
//       '98': [RegExp(r'^98[0-9]{10}$')], // Iran
//       '212': [RegExp(r'^212[0-9]{9}$')], // Morocco
//       '213': [RegExp(r'^213[0-9]{9}$')], // Algeria
//       '216': [RegExp(r'^216[0-9]{8}$')], // Tunisia
//       '218': [RegExp(r'^218[0-9]{9}$')], // Libya
//       '220': [RegExp(r'^220[0-9]{7}$')], // Gambia
//       '221': [RegExp(r'^221[0-9]{9}$')], // Senegal
//       '222': [RegExp(r'^222[0-9]{8}$')], // Mauritania
//       '223': [RegExp(r'^223[0-9]{8}$')], // Mali
//       '224': [RegExp(r'^224[0-9]{9}$')], // Guinea
//       '225': [RegExp(r'^225[0-9]{8}$')], // Ivory Coast
//       '226': [RegExp(r'^226[0-9]{8}$')], // Burkina Faso
//       '227': [RegExp(r'^227[0-9]{8}$')], // Niger
//       '228': [RegExp(r'^228[0-9]{8}$')], // Togo
//       '229': [RegExp(r'^229[0-9]{8}$')], // Benin
//       '234': [RegExp(r'^234[0-9]{10}$')], // Nigeria
//       '237': [RegExp(r'^237[0-9]{9}$')], // Cameroon
//       '254': [RegExp(r'^254[0-9]{9}$')], // Kenya
//       '255': [RegExp(r'^255[0-9]{9}$')], // Tanzania
//       '256': [RegExp(r'^256[0-9]{9}$')], // Uganda
//       '260': [RegExp(r'^260[0-9]{9}$')], // Zambia
//       '263': [RegExp(r'^263[0-9]{9}$')], // Zimbabwe
//       '351': [RegExp(r'^351[0-9]{9}$')], // Portugal
//       '352': [RegExp(r'^352[0-9]{9}$')], // Luxembourg
//       '353': [RegExp(r'^353[0-9]{9}$')], // Ireland
//       '358': [RegExp(r'^358[0-9]{9}$')], // Finland
//       '370': [RegExp(r'^370[0-9]{8}$')], // Lithuania
//       '371': [RegExp(r'^371[0-9]{8}$')], // Latvia
//       '372': [RegExp(r'^372[0-9]{7,8}$')], // Estonia
//       '380': [RegExp(r'^380[0-9]{9}$')], // Ukraine
//       '420': [RegExp(r'^420[0-9]{9}$')], // Czech Republic
//       '421': [RegExp(r'^421[0-9]{9}$')], // Slovakia
//       '886': [RegExp(r'^886[0-9]{9}$')], // Taiwan
//       '961': [RegExp(r'^961[0-9]{8}$')], // Lebanon
//       '962': [RegExp(r'^962[0-9]{9}$')], // Jordan
//       '963': [RegExp(r'^963[0-9]{9}$')], // Syria
//       '964': [RegExp(r'^964[0-9]{10}$')], // Iraq
//       '965': [RegExp(r'^965[0-9]{8}$')], // Kuwait
//       '966': [RegExp(r'^966[0-9]{9}$')], // Saudi Arabia
//       '967': [RegExp(r'^967[0-9]{9}$')], // Yemen
//       '968': [RegExp(r'^968[0-9]{8}$')], // Oman
//       '970': [RegExp(r'^970[0-9]{9}$')], // Palestine
//       '971': [RegExp(r'^971[0-9]{9}$')], // UAE
//       '972': [RegExp(r'^972[0-9]{9}$')], // Israel
//       '973': [RegExp(r'^973[0-9]{8}$')], // Bahrain
//       '974': [RegExp(r'^974[0-9]{8}$')], // Qatar
//       '975': [RegExp(r'^975[0-9]{8}$')], // Bhutan
//       '976': [RegExp(r'^976[0-9]{8}$')], // Mongolia
//       '977': [RegExp(r'^977[0-9]{10}$')], // Nepal
//       '994': [RegExp(r'^994[0-9]{9}$')], // Azerbaijan
//       '995': [RegExp(r'^995[0-9]{9}$')], // Georgia
//       '998': [RegExp(r'^998[0-9]{9}$')], // Uzbekistan
//     };

//     // Check for country codes with definitive patterns
//     for (String code in definiteCountryCodes.keys) {
//       for (RegExp pattern in definiteCountryCodes[code]!) {
//         if (pattern.hasMatch(cleanNumber)) {
//           // Found a definite match for a country code
//           return _formatWithCountryCode(
//             code,
//             cleanNumber.substring(code.length),
//           );
//         }
//       }
//     }

//     // Special case for Indian mobile numbers - 10 digits starting with 6-9
//     if (cleanNumber.length == 10 &&
//         RegExp(r'^[6-9]\d{9}$').hasMatch(cleanNumber)) {
//       return _formatWithCountryCode('91', cleanNumber);
//     }

//     // Special case for US/Canada - 10 digits starting with 2-9
//     if (cleanNumber.length == 10 &&
//         RegExp(r'^[2-9]\d{9}$').hasMatch(cleanNumber)) {
//       return _formatWithCountryCode('1', cleanNumber);
//     }

//     // Special case for UK - 11 digits starting with 07
//     if (cleanNumber.length == 11 && cleanNumber.startsWith('07')) {
//       return _formatWithCountryCode('44', cleanNumber.substring(1));
//     }

//     // For most other cases, we'll format based on length and common patterns
//     if (cleanNumber.length == 10) {
//       // Most 10-digit numbers without a country code are either India or US/Canada
//       // In your app's context (India), we'll format as Indian numbers
//       return _formatWithCountryCode('91', cleanNumber);
//     }

//     // For any other pattern
//     return _formatSimple(cleanNumber);
//   }

//   // Format numbers that start with '+'
//   static String _formatNumberWithPlus(String number) {
//     // Remove the plus sign for processing
//     String withoutPlus = number.substring(1);

//     // Try to determine the country code length
//     int countryCodeLength = 1; // Default to 1 digit

//     // Check for common 2-digit country codes
//     if (withoutPlus.startsWith(
//       RegExp(
//         r'(20|27|30|31|32|33|34|36|39|40|41|43|44|45|46|47|48|49|51|52|53|54|55|56|57|58|60|61|62|63|64|65|66|81|82|84|86|90|91|92|93|94|95|98)',
//       ),
//     )) {
//       countryCodeLength = 2;
//     }
//     // Check for common 3-digit country codes
//     else if (withoutPlus.startsWith(
//       RegExp(
//         r'(212|213|216|218|220|221|222|223|224|225|226|227|228|229|234|237|254|255|256|260|263|351|352|353|358|370|371|372|380|420|421|886|961|962|963|964|965|966|967|968|970|971|972|973|974|975|976|977|994|995|998)',
//       ),
//     )) {
//       countryCodeLength = 3;
//     }

//     String countryCode = withoutPlus.substring(0, countryCodeLength);
//     String nationalNumber = withoutPlus.substring(countryCodeLength);

//     return _formatWithCountryCode(countryCode, nationalNumber);
//   }

//   // Format numbers with a detected country code
//   static String _formatWithCountryCode(String countryCode, String number) {
//     // Format based on country code
//     switch (countryCode) {
//       case '1': // US/Canada: +1 XXX XXX XXXX
//         if (number.length == 10) {
//           return '+1 ${number.substring(0, 3)} ${number.substring(3, 6)} ${number.substring(6)}';
//         }
//         break;

//       case '91': // India: +91 XXXXX XXXXX
//         if (number.length == 10) {
//           return '+91 ${number.substring(0, 5)} ${number.substring(5)}';
//         }
//         break;

//       case '44': // UK: +44 XXXX XXX XXX
//         if (number.length >= 10) {
//           return '+44 ${number.substring(0, 4)} ${number.substring(4, 7)} ${number.substring(7)}';
//         }
//         break;

//       case '86': // China: +86 XXX XXXX XXXX
//         if (number.length >= 10) {
//           return '+86 ${number.substring(0, 3)} ${number.substring(3, 7)} ${number.substring(7)}';
//         }
//         break;

//       // Add more formatting rules for specific countries
//     }

//     // Generic formatting for other country codes
//     return '+$countryCode ${_formatSimple(number)}';
//   }

//   // Simple formatting for numbers without clear patterns
//   static String _formatSimple(String number) {
//     if (number.length <= 4) {
//       return number;
//     }

//     // Format in balanced groups
//     if (number.length <= 8) {
//       // Split into two even groups
//       int half = (number.length / 2).ceil();
//       return '${number.substring(0, half)} ${number.substring(half)}';
//     }

//     // For longer numbers, try to create balanced groups of 3-4 digits
//     List<String> groups = [];
//     int i = 0;

//     while (i < number.length) {
//       int remaining = number.length - i;
//       int groupSize;

//       if (remaining > 10) {
//         groupSize = 3; // Use groups of 3 for very long numbers
//       } else if (remaining > 7) {
//         groupSize = 3; // Use groups of 3 for medium length
//       } else if (remaining > 4) {
//         groupSize = 2; // Use groups of 2 for shorter remaining portions
//       } else {
//         groupSize = remaining; // Use whatever's left
//       }

//       groups.add(number.substring(i, i + groupSize));
//       i += groupSize;
//     }

//     return groups.join(' ');
//   }
// }

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:whoxa/core/services/device_country_code_service.dart';
import 'package:whoxa/utils/avatar_initials.dart';

class ContactModel {
  final String name;
  final String phoneNumber;
  final String? userId;
  final Uint8List? photo; // Keep for device photos (if needed)
  final String? profilePicUrl; // Add backend photo URL
  final String _formattedNumber;
  final bool? isChatLock;
  final int? chatId;

  ContactModel({
    required this.name,
    required this.phoneNumber,
    this.userId,
    this.photo,
    this.profilePicUrl, // Add backend photo URL parameter
    this.isChatLock,
    this.chatId,
  }) : _formattedNumber = _formatPhoneNumber(phoneNumber);

  // Enhanced factory constructor with comprehensive null safety
  factory ContactModel.fromJson(Map<String, dynamic> json) {
    // Safely extract name with multiple fallbacks
    String safeName = _extractSafeName(json);

    // Safely extract phone number with multiple fallbacks
    String safePhoneNumber = _extractSafePhoneNumber(json);

    // Safely extract user ID
    String? safeUserId = _extractSafeUserId(json);

    // Safely extract profile picture URL
    String? safeProfilePicUrl = _extractSafeProfilePicUrl(json);

    bool? isChatLock = _extractSafeChatLock(json);

    int? chatId = _extractSafeChatId(json);

    return ContactModel(
      name: safeName,
      phoneNumber: safePhoneNumber,
      userId: safeUserId,
      photo: null, // Keep null for device photos
      profilePicUrl: safeProfilePicUrl, // Use backend photo URL
      isChatLock: isChatLock,
      chatId: chatId,
    );
  }

  // Safe name extraction with multiple fallbacks
  static String _extractSafeName(Map<String, dynamic> json) {
    // Try different name fields
    final nameFields = ['name', 'full_name', 'user_name', 'first_name'];

    for (String field in nameFields) {
      final value = json[field];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    // Try to construct name from first_name and last_name
    final firstName = json['first_name']?.toString().trim() ?? '';
    final lastName = json['last_name']?.toString().trim() ?? '';

    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }

    // Final fallback
    return 'Unknown Contact';
  }

  // Safe phone number extraction with multiple fallbacks
  static String _extractSafePhoneNumber(Map<String, dynamic> json) {
    // Try different phone number fields
    final phoneFields = [
      'phone_number',
      'mobile_num',
      'phoneNumber',
      'number',
      'mobile',
      'phone',
    ];

    for (String field in phoneFields) {
      final value = json[field];
      if (value != null) {
        String phoneStr = value.toString().trim();
        if (phoneStr.isNotEmpty && phoneStr != 'null') {
          return phoneStr;
        }
      }
    }

    // Check for country code + mobile combination
    final countryCode =
        json['country_code']?.toString().replaceAll('+', '') ?? '';
    final mobile =
        json['mobile_num']?.toString() ?? json['mobile']?.toString() ?? '';

    if (countryCode.isNotEmpty && mobile.isNotEmpty && mobile != 'null') {
      return '+$countryCode$mobile';
    }

    return ''; // Return empty string if no valid phone number found
  }

  // Safe user ID extraction
  static String? _extractSafeUserId(Map<String, dynamic> json) {
    final idFields = ['user_id', 'id', 'userId'];

    for (String field in idFields) {
      final value = json[field];
      if (value != null &&
          value.toString().trim().isNotEmpty &&
          value.toString() != 'null') {
        return value.toString().trim();
      }
    }

    return null;
  }

  static bool? _extractSafeChatLock(Map<String, dynamic> json) {
    const fields = ['is_chat_lock', 'isChatLock', 'chat_lock'];

    for (final field in fields) {
      final value = json[field];
      if (value == null || value.toString() == 'null') continue;

      // Already a bool → return directly
      if (value is bool) return value;

      // Numeric: 1 = true, 0 = false
      if (value is int) return value == 1;

      // String: "true" / "1" = true, everything else = false
      final str = value.toString().trim().toLowerCase();
      if (str == 'true' || str == '1') return true;
      if (str == 'false' || str == '0') return false;
    }

    return null; // field not present in JSON
  }

  static int? _extractSafeChatId(Map<String, dynamic> json) {
    const fields = ['chat_id', 'chatId'];

    for (final field in fields) {
      final value = json[field];
      if (value == null || value.toString() == 'null') continue;

      if (value is int) return value;

      // Server sometimes sends int as String e.g. "42"
      final parsed = int.tryParse(value.toString().trim());
      if (parsed != null) return parsed;
    }

    return null;
  }

  // Safe profile picture URL extraction
  static String? _extractSafeProfilePicUrl(Map<String, dynamic> json) {
    final picFields = [
      'profile_pic',
      'profilePic',
      'avatar',
      'image_url',
      'photo_url',
    ];

    for (String field in picFields) {
      final value = json[field];
      if (value != null &&
          value.toString().trim().isNotEmpty &&
          value.toString() != 'null' &&
          value.toString() != '') {
        return value.toString().trim();
      }
    }

    return null;
  }

  // Convert to JSON with null safety
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone_number': phoneNumber.isNotEmpty ? phoneNumber : null,
      'user_id': userId,
      'profile_pic': profilePicUrl,
      'is_chat_lock': isChatLock,
      'chat_id': chatId,
      // Add other fields as needed
    };
  }

  // Get initials for avatar — delegates to the app-wide helper so a contact
  // renders the same initials here as it does in every other user list.
  String get initials => avatarInitials(name);

  // Get the formatted phone number with safety check
  String get formattedPhoneNumber {
    if (phoneNumber.isEmpty) return 'No phone number';
    return _formattedNumber;
  }

  // Enhanced phone number validation
  bool get hasValidPhoneNumber {
    return phoneNumber.isNotEmpty &&
        phoneNumber != 'null' &&
        RegExp(r'^[\+\d\s\-\(\)]+$').hasMatch(phoneNumber);
  }

  // Check if contact is valid
  bool get isValid {
    return name.isNotEmpty && name != 'Unknown Contact' && hasValidPhoneNumber;
  }

  // Static method to format phone numbers (keeping your existing logic)
  static String _formatPhoneNumber(String phoneNumber) {
    // Return empty if input is invalid
    if (phoneNumber.isEmpty || phoneNumber == 'null') {
      return '';
    }

    // Clean the number to only have digits and possibly a '+' at the start
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

    if (cleanNumber.isEmpty) return phoneNumber;

    // Check if it already has a country code with '+'
    if (cleanNumber.startsWith('+')) {
      return _formatNumberWithPlus(cleanNumber);
    }

    // Check for standard country code patterns
    // These are definitive country codes we can be confident about
    Map<String, List<RegExp>> definiteCountryCodes = {
      '1': [RegExp(r'^1[2-9]\d{9}$')], // US/Canada
      '7': [RegExp(r'^7[0-9]{10}$')], // Russia
      '20': [RegExp(r'^20[1-9][0-9]{8}$')], // Egypt
      '27': [RegExp(r'^27[0-9]{9}$')], // South Africa
      '30': [RegExp(r'^30[0-9]{9}$')], // Greece
      '31': [RegExp(r'^31[0-9]{9}$')], // Netherlands
      '32': [RegExp(r'^32[0-9]{9}$')], // Belgium
      '33': [RegExp(r'^33[1-9][0-9]{8}$')], // France
      '34': [RegExp(r'^34[0-9]{9}$')], // Spain
      '36': [RegExp(r'^36[0-9]{9}$')], // Hungary
      '39': [RegExp(r'^39[0-9]{9,10}$')], // Italy
      '40': [RegExp(r'^40[0-9]{9}$')], // Romania
      '41': [RegExp(r'^41[0-9]{9}$')], // Switzerland
      '43': [RegExp(r'^43[0-9]{10,11}$')], // Austria
      '44': [RegExp(r'^44[0-9]{10}$')], // UK
      '45': [RegExp(r'^45[0-9]{8}$')], // Denmark
      '46': [RegExp(r'^46[0-9]{9}$')], // Sweden
      '47': [RegExp(r'^47[0-9]{8}$')], // Norway
      '48': [RegExp(r'^48[0-9]{9}$')], // Poland
      '49': [RegExp(r'^49[0-9]{10,11}$')], // Germany
      '51': [RegExp(r'^51[0-9]{9}$')], // Peru
      '52': [RegExp(r'^52[0-9]{10}$')], // Mexico
      '53': [RegExp(r'^53[0-9]{8}$')], // Cuba
      '54': [RegExp(r'^54[0-9]{10}$')], // Argentina
      '55': [RegExp(r'^55[0-9]{10,11}$')], // Brazil
      '56': [RegExp(r'^56[0-9]{9}$')], // Chile
      '57': [RegExp(r'^57[0-9]{10}$')], // Colombia
      '58': [RegExp(r'^58[0-9]{10}$')], // Venezuela
      '60': [RegExp(r'^60[0-9]{9,10}$')], // Malaysia
      '61': [RegExp(r'^61[0-9]{9}$')], // Australia
      '62': [RegExp(r'^62[0-9]{10,12}$')], // Indonesia
      '63': [RegExp(r'^63[0-9]{10}$')], // Philippines
      '64': [RegExp(r'^64[0-9]{9,10}$')], // New Zealand
      '65': [RegExp(r'^65[0-9]{8}$')], // Singapore
      '66': [RegExp(r'^66[0-9]{9}$')], // Thailand
      '81': [RegExp(r'^81[0-9]{9,10}$')], // Japan
      '82': [RegExp(r'^82[0-9]{9,10}$')], // South Korea
      '84': [RegExp(r'^84[0-9]{9,10}$')], // Vietnam
      '86': [RegExp(r'^86[0-9]{10,11}$')], // China
      '90': [RegExp(r'^90[0-9]{10}$')], // Turkey
      '91': [RegExp(r'^91[6-9][0-9]{9}$')], // India with country code
      '92': [RegExp(r'^92[0-9]{10}$')], // Pakistan
      '93': [RegExp(r'^93[0-9]{9}$')], // Afghanistan
      '94': [RegExp(r'^94[0-9]{9}$')], // Sri Lanka
      '95': [RegExp(r'^95[0-9]{9,10}$')], // Myanmar
      '98': [RegExp(r'^98[0-9]{10}$')], // Iran
      '212': [RegExp(r'^212[0-9]{9}$')], // Morocco
      '213': [RegExp(r'^213[0-9]{9}$')], // Algeria
      '216': [RegExp(r'^216[0-9]{8}$')], // Tunisia
      '218': [RegExp(r'^218[0-9]{9}$')], // Libya
      '220': [RegExp(r'^220[0-9]{7}$')], // Gambia
      '221': [RegExp(r'^221[0-9]{9}$')], // Senegal
      '222': [RegExp(r'^222[0-9]{8}$')], // Mauritania
      '223': [RegExp(r'^223[0-9]{8}$')], // Mali
      '224': [RegExp(r'^224[0-9]{9}$')], // Guinea
      '225': [RegExp(r'^225[0-9]{8}$')], // Ivory Coast
      '226': [RegExp(r'^226[0-9]{8}$')], // Burkina Faso
      '227': [RegExp(r'^227[0-9]{8}$')], // Niger
      '228': [RegExp(r'^228[0-9]{8}$')], // Togo
      '229': [RegExp(r'^229[0-9]{8}$')], // Benin
      '234': [RegExp(r'^234[0-9]{10}$')], // Nigeria
      '237': [RegExp(r'^237[0-9]{9}$')], // Cameroon
      '254': [RegExp(r'^254[0-9]{9}$')], // Kenya
      '255': [RegExp(r'^255[0-9]{9}$')], // Tanzania
      '256': [RegExp(r'^256[0-9]{9}$')], // Uganda
      '260': [RegExp(r'^260[0-9]{9}$')], // Zambia
      '263': [RegExp(r'^263[0-9]{9}$')], // Zimbabwe
      '351': [RegExp(r'^351[0-9]{9}$')], // Portugal
      '352': [RegExp(r'^352[0-9]{9}$')], // Luxembourg
      '353': [RegExp(r'^353[0-9]{9}$')], // Ireland
      '358': [RegExp(r'^358[0-9]{9}$')], // Finland
      '370': [RegExp(r'^370[0-9]{8}$')], // Lithuania
      '371': [RegExp(r'^371[0-9]{8}$')], // Latvia
      '372': [RegExp(r'^372[0-9]{7,8}$')], // Estonia
      '380': [RegExp(r'^380[0-9]{9}$')], // Ukraine
      '420': [RegExp(r'^420[0-9]{9}$')], // Czech Republic
      '421': [RegExp(r'^421[0-9]{9}$')], // Slovakia
      '886': [RegExp(r'^886[0-9]{9}$')], // Taiwan
      '961': [RegExp(r'^961[0-9]{8}$')], // Lebanon
      '962': [RegExp(r'^962[0-9]{9}$')], // Jordan
      '963': [RegExp(r'^963[0-9]{9}$')], // Syria
      '964': [RegExp(r'^964[0-9]{10}$')], // Iraq
      '965': [RegExp(r'^965[0-9]{8}$')], // Kuwait
      '966': [RegExp(r'^966[0-9]{9}$')], // Saudi Arabia
      '967': [RegExp(r'^967[0-9]{9}$')], // Yemen
      '968': [RegExp(r'^968[0-9]{8}$')], // Oman
      '970': [RegExp(r'^970[0-9]{9}$')], // Palestine
      '971': [RegExp(r'^971[0-9]{9}$')], // UAE
      '972': [RegExp(r'^972[0-9]{9}$')], // Israel
      '973': [RegExp(r'^973[0-9]{8}$')], // Bahrain
      '974': [RegExp(r'^974[0-9]{8}$')], // Qatar
      '975': [RegExp(r'^975[0-9]{8}$')], // Bhutan
      '976': [RegExp(r'^976[0-9]{8}$')], // Mongolia
      '977': [RegExp(r'^977[0-9]{10}$')], // Nepal
      '994': [RegExp(r'^994[0-9]{9}$')], // Azerbaijan
      '995': [RegExp(r'^995[0-9]{9}$')], // Georgia
      '998': [RegExp(r'^998[0-9]{9}$')], // Uzbekistan
    };

    // Check for country codes with definitive patterns
    for (String code in definiteCountryCodes.keys) {
      for (RegExp pattern in definiteCountryCodes[code]!) {
        if (pattern.hasMatch(cleanNumber)) {
          // Found a definite match for a country code
          return _formatWithCountryCode(
            code,
            cleanNumber.substring(code.length),
          );
        }
      }
    }

    // For numbers without country code, use device-detected country code
    // Priority: Device location/locale → Fallback (+1 US)
    // NO hardcoded country codes - always use device detection
    final defaultDialCode =
        DeviceCountryCodeService.instance.getDefaultDialCode();

    // Special case for UK - 11 digits starting with 07 (local UK format)
    if (cleanNumber.length == 11 && cleanNumber.startsWith('07')) {
      // Only apply UK code if device is in UK, otherwise use device-detected
      if (defaultDialCode == '44') {
        return _formatWithCountryCode('44', cleanNumber.substring(1));
      }
    }

    // For any number without country code, use device-detected country code
    if (cleanNumber.length >= 7 && cleanNumber.length <= 15) {
      return _formatWithCountryCode(defaultDialCode, cleanNumber);
    }

    // For any other pattern (too short or too long)
    return _formatSimple(cleanNumber);
  }

  // Format numbers that start with '+'
  static String _formatNumberWithPlus(String number) {
    try {
      // Remove the plus sign for processing
      String withoutPlus = number.substring(1);

      if (withoutPlus.isEmpty) return number;

      // Try to determine the country code length
      int countryCodeLength = 1; // Default to 1 digit

      // Check for common 2-digit country codes
      if (withoutPlus.startsWith(
        RegExp(
          r'(20|27|30|31|32|33|34|36|39|40|41|43|44|45|46|47|48|49|51|52|53|54|55|56|57|58|60|61|62|63|64|65|66|81|82|84|86|90|91|92|93|94|95|98)',
        ),
      )) {
        countryCodeLength = 2;
      }
      // Check for common 3-digit country codes
      else if (withoutPlus.startsWith(
        RegExp(
          r'(212|213|216|218|220|221|222|223|224|225|226|227|228|229|234|237|254|255|256|260|263|351|352|353|358|370|371|372|380|420|421|886|961|962|963|964|965|966|967|968|970|971|972|973|974|975|976|977|994|995|998)',
        ),
      )) {
        countryCodeLength = 3;
      }

      if (withoutPlus.length < countryCodeLength) return number;

      String countryCode = withoutPlus.substring(0, countryCodeLength);
      String nationalNumber = withoutPlus.substring(countryCodeLength);

      return _formatWithCountryCode(countryCode, nationalNumber);
    } catch (e) {
      debugPrint('Error formatting number with plus: $number, Error: $e');
      return number; // Return original if formatting fails
    }
  }

  // Format numbers with a detected country code
  static String _formatWithCountryCode(String countryCode, String number) {
    try {
      // Format based on country code
      switch (countryCode) {
        case '1': // US/Canada: +1 XXX XXX XXXX
          if (number.length == 10) {
            return '+1 ${number.substring(0, 3)} ${number.substring(3, 6)} ${number.substring(6)}';
          }
          break;

        case '91': // India: +91 XXXXX XXXXX
          if (number.length == 10) {
            return '+91 ${number.substring(0, 5)} ${number.substring(5)}';
          }
          break;

        case '44': // UK: +44 XXXX XXX XXX
          if (number.length >= 10) {
            return '+44 ${number.substring(0, 4)} ${number.substring(4, 7)} ${number.substring(7)}';
          }
          break;

        case '86': // China: +86 XXX XXXX XXXX
          if (number.length >= 10) {
            return '+86 ${number.substring(0, 3)} ${number.substring(3, 7)} ${number.substring(7)}';
          }
          break;

        case '60': // Malaysia
          if (number.length >= 9) {
            return '+60 ${number.substring(0, 2)} '
                '${number.substring(2, 6)} '
                '${number.substring(6)}';
          }
          break;

        // Add more formatting rules for specific countries as needed
      }

      // Generic formatting for other country codes
      return '+$countryCode ${_formatSimple(number)}';
    } catch (e) {
      debugPrint(
        'Error formatting with country code $countryCode: $number, Error: $e',
      );
      return '+$countryCode $number'; // Fallback formatting
    }
  }

  // Simple formatting for numbers without clear patterns
  static String _formatSimple(String number) {
    try {
      if (number.length <= 4) {
        return number;
      }

      // Format in balanced groups
      if (number.length <= 8) {
        // Split into two even groups
        int half = (number.length / 2).ceil();
        return '${number.substring(0, half)} ${number.substring(half)}';
      }

      // For longer numbers, try to create balanced groups of 3-4 digits
      List<String> groups = [];
      int i = 0;

      while (i < number.length) {
        int remaining = number.length - i;
        int groupSize;

        if (remaining > 10) {
          groupSize = 3; // Use groups of 3 for very long numbers
        } else if (remaining > 7) {
          groupSize = 3; // Use groups of 3 for medium length
        } else if (remaining > 4) {
          groupSize = 2; // Use groups of 2 for shorter remaining portions
        } else {
          groupSize = remaining; // Use whatever's left
        }

        groups.add(number.substring(i, i + groupSize));
        i += groupSize;
      }

      return groups.join(' ');
    } catch (e) {
      debugPrint('Error in simple formatting: $number, Error: $e');
      return number; // Return original if formatting fails
    }
  }

  // Safely create contact from contact_details array item
  static ContactModel? fromContactDetail(dynamic contactDetail) {
    if (contactDetail == null) return null;

    try {
      if (contactDetail is Map<String, dynamic>) {
        return ContactModel.fromJson(contactDetail);
      }
    } catch (e) {
      debugPrint('Error creating ContactModel from contact detail: $e');
    }

    return null;
  }

  // Safely parse contact_details array
  static List<ContactModel> fromContactDetailsList(
    List<dynamic>? contactDetailsList,
  ) {
    if (contactDetailsList == null) return [];

    List<ContactModel> contacts = [];

    for (dynamic item in contactDetailsList) {
      final contact = fromContactDetail(item);
      if (contact != null && contact.isValid) {
        contacts.add(contact);
      }
    }

    return contacts;
  }

  @override
  String toString() {
    return 'ContactModel(name: $name, phoneNumber: $phoneNumber, userId: $userId, profilePicUrl: $profilePicUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactModel &&
        other.name == name &&
        other.phoneNumber == phoneNumber &&
        other.userId == userId &&
        other.profilePicUrl == profilePicUrl &&
        other.isChatLock == isChatLock &&
        other.chatId == chatId;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        phoneNumber.hashCode ^
        userId.hashCode ^
        profilePicUrl.hashCode ^
        isChatLock.hashCode ^
        chatId.hashCode;
  }
}
