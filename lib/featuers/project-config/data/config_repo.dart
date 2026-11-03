// *****************************************************************************************
// * Filename: project_config_repository.dart                                              *
// * Developer: Deval Joshi                                             *
// * Date: 25 June 25
// * Description: Repository for handling project configuration API calls                 *
// *****************************************************************************************

import 'dart:ui';

import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/notification/data/notification_repository.dart';
import 'package:whoxa/featuers/notification/model/mark_read_model.dart';
import 'package:whoxa/featuers/notification/model/notification_model.dart';
import 'package:whoxa/featuers/project-config/data/config_model.dart';

import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart';

class ProjectConfigRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  ProjectConfigRepository(this._apiClient);

  /// Fetches project configuration from the API
  /// Returns ProjectConfig object containing all configuration data
  Future<ProjectConfig> getProjectConfiguration() async {
    _logger.i('Fetching project configuration');

    try {
      final response = await _apiClient.request(
        ApiEndpoints.projectConfig,
        method: 'GET',
      );

      _logger.d('Project configuration fetched successfully');
      _logger.d('Response: $response');

      // NEW's /settings is bare JSON (no {status,data,...} envelope) and
      // only covers 4 of OLD's ~35 fields: privacy_policy,
      // terms_and_conditions, phone_authentication, email_authentication.
      // Merge those real fields onto the local defaults so branding/theme
      // (app name, logos, colors, Twilio creds, demo credential — none of
      // which exist on the NEW backend) keep working instead of going
      // blank.
      final merged = <String, dynamic>{
        ...getDefaultConfiguration().data.toJson(),
        if (response is Map<String, dynamic>) ...response,
      };

      final projectConfig = ProjectConfig(
        status: true,
        message: 'Success',
        toast: false,
        data: ProjectConfigData.fromJson(merged),
      );

      _logger.i('Project configuration parsed successfully');
      _logger.d('App Name: ${projectConfig.data.appName}');
      _logger.d('Config ID: ${projectConfig.data.configId}');
      _logger.d('Phone Auth: ${projectConfig.data.phoneAuthentication}');
      _logger.d('Email Auth: ${projectConfig.data.emailAuthentication}');
      _logger.d('APP LOGO:${projectConfig.data.appLogoLight}');
      _logger.d('APP LOGO DARK:${projectConfig.data.appLogoDark}');

      await SecurePrefs.setMultiple({
        SecureStorageKeys.IS_PHONE_AUTH: projectConfig.data.phoneAuthentication,
        SecureStorageKeys.IS_EMAIL_AUTH: projectConfig.data.emailAuthentication,
        SecureStorageKeys.APP_LOGO: projectConfig.data.appLogoLight,
        SecureStorageKeys.APP_LOGO_DARK: projectConfig.data.appLogoDark,
        SecureStorageKeys.APP_NAME: projectConfig.data.appName,
        SecureStorageKeys.DEMO_CREDENTIAL: projectConfig.data.demoCredential,
      });
      await SecureStorageKeys().loadeBoolValuePrefes();
      appLogo = (await SecurePrefs.getString(SecureStorageKeys.APP_LOGO))!;
      appLogoDarkMode =
          (await SecurePrefs.getString(SecureStorageKeys.APP_LOGO_DARK))!;
      appName = (await SecurePrefs.getString(SecureStorageKeys.APP_NAME))!;
      termsConditionText = projectConfig.data.termsAndConditions;
      privacyPoicyText = projectConfig.data.privacyPolicy;
      demoCredential = (await SecurePrefs.getBool(
        SecureStorageKeys.DEMO_CREDENTIAL,
      ));

      // ✅ THEME COLOR PRIORITY LOGIC
      // 1. Check if user has selected custom theme color
      // 2. If yes, use custom color; if no, use project config color
      final customThemeColor = await SecurePrefs.getString(
        SecureStorageKeys.customThemeColor,
      );

      if (customThemeColor != null && customThemeColor.isNotEmpty) {
        // Use custom theme color selected by user
        _logger.i("Using custom theme color: $customThemeColor");
        appPrimeColor = customThemeColor;
        appSecColor = customThemeColor;
      } else {
        // Use project config color (default)
        _logger.i(
          "Using project config color: ${projectConfig.data.appPrimaryColor}",
        );
        appPrimeColor = projectConfig.data.appPrimaryColor;
        //: only one color need to use that's why sec color set as primary
        appSecColor = projectConfig.data.appPrimaryColor;
      }

      appPrimeColor = appPrimeColor.replaceAll("#", "");
      appSecColor = appSecColor.replaceAll("#", "");
      int colorIntPrime = int.parse("0xFF$appPrimeColor");
      int colorIntSec = int.parse("0xFF$appSecColor");
      AppColors.appPriSecColor.primaryColor = Color(colorIntPrime);
      AppColors.appPriSecColor.secondaryColor = Color(colorIntSec);

      _logger.i("😊😊appLogo😊😊:$appLogo");
      _logger.i("😊😊appPrime😊😊:${AppColors.appPriSecColor.primaryColor}");
      _logger.i(
        "😊😊appSecColor😊😊:${AppColors.appPriSecColor.secondaryColor}",
      );

      return projectConfig;
    } catch (e) {
      _logger.e('Error fetching project configuration', e);

      if (e is AppError) {
        rethrow;
      }

      throw AppError('Failed to fetch project configuration: ${e.toString()}');
    }
  }

  /// Validates if the configuration response is valid
  // ignore: unused_element
  bool _isValidConfiguration(ProjectConfig config) {
    if (!config.status) {
      _logger.w('Configuration status is false');
      return false;
    }

    if (config.data.configId <= 0) {
      _logger.w('Invalid config ID: ${config.data.configId}');
      return false;
    }

    _logger.i('Configuration validation passed');
    return true;
  }

  /// Gets a safe/default configuration in case API fails
  ProjectConfig getDefaultConfiguration() {
    _logger.w('Using default project configuration');

    return ProjectConfig(
      status: true,
      message: 'Default configuration loaded',
      toast: false,
      data: ProjectConfigData(
        appLogoLight: '',
        appLogoDark: '',
        webLogoLight: '',
        webLogoDark: '',
        twilioAccountSid: '',
        twilioAuthToken: '',
        twilioPhoneNumber: '',
        password: '',
        emailBanner: '',
        configId: 1,
        phoneAuthentication: true,
        emailAuthentication: true,
        maximumMembersInGroup: 10,
        showAllContacts: true,
        showPhoneContacts: true,
        userNameFlow: true,
        contactFlow: true, // Set to true for testing, normally would be false
        appName: 'whoxa',
        appEmail: '',
        appText: '',
        appPrimaryColor: '#FCC604',
        appSecondaryColor: '#FAE390',
        demoCredential: false,
        appIosLink: '',
        appAndroidLink: '',
        appTellAFriendText: '',
        emailService: '',
        smtpHost: '',
        email: '',
        emailTitle: '',
        copyrightText: '',
        privacyPolicy: '',
        termsAndConditions: '',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  /// The notification screen is the admin-broadcast feed:
  /// `POST /users/list-broadcast-notification?page=&limit=` — paging stays
  /// in the query string, the body is empty.
  ///
  /// NEW's shim returns OLD's envelope byte-for-byte
  /// ({status,data:{Records,Pagination},message,toast}), so it parses
  /// straight into [NotificationListModel] with no adapting. The per-user
  /// `/notifications` feed is deliberately NOT used here — that one carries
  /// per-message/per-call pings, not the broadcasts this screen shows.
  Future<NotificationListModel> getNotificationListRepo({
    int page = 1,
    int limit = 20,
  }) async {
    _logger.i('Fetching Notification list');

    try {
      final response = await _apiClient.request(
        '${ApiEndpoints.listBroadcastNotification}?page=$page&limit=$limit',
        method: 'POST',
      );

      if (response is! Map<String, dynamic>) {
        throw AppError("Unexpected Notification list response: $response");
      }

      return NotificationListModel.fromJson(response);
    } catch (e) {
      _logger.e("Error fetching notification list");

      if (e is AppError) {
        rethrow;
      }
      throw AppError("Failed to fetch Notification list: ${e.toString()}");
    }
  }

  /// Pairs with the per-user feed above — `POST /notifications/read-all`
  /// is a real, confirmed endpoint (`notifications.controller.ts`), unlike
  /// the broadcast list which has no server-side "mark read" concept.
  Future<MarkReadNotifiModel> marReadNotifiRepo() async {
    try {
      await NotificationRepository(_apiClient).markAllRead();
      return MarkReadNotifiModel(status: true, data: const [], message: 'OK');
    } catch (e) {
      _logger.e("Error marking notifications read: $e");
      return MarkReadNotifiModel(
        status: false,
        data: const [],
        message: e.toString(),
      );
    }
  }
}
