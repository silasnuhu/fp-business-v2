import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

//import your model class

class SecurePrefs {
  static final FlutterSecureStorage storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  SecurePrefs(FlutterSecureStorage storage);

  // Write data
  static Future<void> setString(String key, String value) async {
    await storage.write(key: key, value: value);
  }

  static Future<void> setBool(String key, bool value) async {
    await storage.write(key: key, value: value.toString());
  }

  static Future<void> setInt(String key, int value) async {
    await storage.write(key: key, value: value.toString());
  }

  static Future<void> setDouble(String key, double value) async {
    await storage.write(key: key, value: value.toString());
  }

  // Write json model
  static Future<void> setModel<T>(String key, T model) async {
    final String jsonString = jsonEncode(model);
    await storage.write(key: key, value: jsonString);
  }

  // Read model
  static Future<T?> getModel<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final String? jsonString = await storage.read(key: key);
    if (jsonString != null) {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return fromJson(jsonMap);
    }
    return null;
  }

  // Read data
  static Future<String?> getString(String key) async {
    return await storage.read(key: key);
  }

  static Future<bool> getBool(String key) async {
    final val = await storage.read(key: key);
    return val == 'true';
  }

  static Future<bool> getBoolLighDark(
    String key, {
    bool defaultValue = true,
  }) async {
    final val = await storage.read(key: key);
    if (val == null) {
      await storage.write(key: key, value: defaultValue.toString());
      return defaultValue;
    }
    return val == 'true';
  }

  static Future<int> getInt(String key) async {
    final val = await storage.read(key: key);
    return int.tryParse(val ?? '') ?? 0;
  }

  static Future<double> getDouble(String key) async {
    final val = await storage.read(key: key);
    return double.tryParse(val ?? '') ?? 0.0;
  }

  // Remove
  static Future<void> remove(String key) async {
    await storage.delete(key: key);
  }

  static Future<void> clear() async {
    // ✅ FIX: Clear all data including permission flag and global variables
    debugPrint('🧹 Clearing all secure storage data...');

    // Clear global variables
    contrycode = '';
    authToken = "";
    userID = "";
    userName = "";
    firstName = "";
    lastName = "";
    gender = "";
    mobileNum = "";
    country = "";
    countryShortName = "";
    email = "";
    bio = "";
    loginType = "";
    userProfile = "";
    langID = "";
    // ✅ CRITICAL FIX: Reset permission flag to false
    permission = false;
    isPhoneAuthEnabled = false;
    isEmailAuthEnabled = false;
    isDemo = false;

    // ✅ Use deleteAll() for cleaner approach instead of individual deletes
    // This ensures we don't miss any keys and properly clear everything
    await storage.deleteAll();

    debugPrint('✅ All secure storage data cleared successfully');
  }

  static Future<void> setMultiple(Map<String, dynamic> data) async {
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is String) {
        await setString(key, value);
      } else if (value is int) {
        await setInt(key, value);
      } else if (value is bool) {
        await setBool(key, value);
      } else if (value is double) {
        await setDouble(key, value);
      } else if (value is List<String>) {
        // Join list into comma-separated string or handle with jsonEncode
        await setString(key, jsonEncode(value));
      } else {
        throw UnsupportedError(
          "Unsupported type for SecurePrefs: ${value.runtimeType}",
        );
      }
    }
  }
}
