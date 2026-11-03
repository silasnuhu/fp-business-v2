import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactService {
  static const MethodChannel _channel = MethodChannel('com.primocys.chat/contacts');

  /// Add contact to device using native platform methods
  static Future<bool> addContact(String name, String phoneNumber) async {
    try {
      if (Platform.isAndroid) {
        // Use native Android method channel
        await _channel.invokeMethod('addContact', {
          'name': name,
          'phone': phoneNumber,
        });
        return true;
      } else if (Platform.isIOS) {
        // For iOS, use URL launcher to open contacts app
        return await _openContactsAppIOS(name, phoneNumber);
      }
      return false;
    } on PlatformException catch (e) {
      debugPrint('Failed to add contact: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected error: $e');
      return false;
    }
  }

  /// iOS specific method to open contacts app
  static Future<bool> _openContactsAppIOS(String name, String phoneNumber) async {
    try {
      // Try multiple iOS contact URL schemes
      final List<String> contactUrls = [
        'contacts://',
        'x-apple-contacts://',
      ];

      for (String url in contactUrls) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Failed to open iOS contacts app: $e');
      return false;
    }
  }
}