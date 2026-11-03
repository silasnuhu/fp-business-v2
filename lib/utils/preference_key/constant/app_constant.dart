// *****************************************************************************************
// * Filename: app_constants.dart                                                         *
// * Date: 03 April 2025
// * Developer: Deval Joshi                                                         *
// * Description: This file contains application-wide constants including storage keys,   *
// * default values, and configuration settings that are used throughout the application. *
// *****************************************************************************************

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:get_thumbnail_video/index.dart';

class Constants {
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String userEmailKey = 'user_email';
  static const String userProfileKey = 'user_profile';
  static const String isLoggedInKey = 'is_logged_in';
  static const String fcmTokenKey = 'fcm_token';

  // API related constants
  static const int apiTimeoutDuration = 30000; // milliseconds
  static const int maxRetryAttempts = 3;

  // App settings
  static const String appName = 'Pucho';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // Store links (fallback when project config does not provide platform links)
  static const String playStoreLink =
      'https://play.google.com/store/apps/details?id=com.flickpitch.app&pcampaignid=web_share';
  static const String appStoreLink =
      'https://apps.apple.com/in/app/whoxa-chat/id6502178493';

  // Cache settings
  static const int cacheDuration =
      24 * 60 * 60 * 1000; // 24 hours in milliseconds

  // Image related
  static const String defaultAvatarAsset = 'assets/images/default_avatar.png';
  static const int maxImageUploadSize = 5 * 1024 * 1024; // 5 MB

  // Pagination
  static const int defaultPageSize = 20;
  static const int searchResultLimit = 50;

  // Animation durations
  static const int shortAnimationDuration = 200; // milliseconds
  static const int mediumAnimationDuration = 500; // milliseconds
  static const int longAnimationDuration = 800; // milliseconds

  // Error messages
  static const String networkErrorMessage =
      'Please check your internet connection and try again.';
  static const String genericErrorMessage =
      'Something went wrong. Please try again later.';
  static const String sessionExpiredMessage =
      'Your session has expired. Please login again.';

  // Feature flags
  static const bool enablePushNotifications = true;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;

  //get userid
  static Future<int> getUserId() async {
    final userIdStr = await SecurePrefs.getString(SecureStorageKeys.USERID);
    return int.parse(userIdStr ?? "0");
  }

  static Future<String?> generateThumbnail(String videoPath) async {
    try {
      // Create a temporary file path to store the thumbnail
      final Directory tempDir = await getTemporaryDirectory();
      final String thumbnailPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Generate thumbnail using get_thumbnail_video package
      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        quality: 75,
      );

      return thumbnailFile.path;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  // Do not instantiate this class
  Constants._();
}
