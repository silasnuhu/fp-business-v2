// *****************************************************************************************
// * Filename: project_config_provider.dart                                                *
// * Developer: Deval Joshi                                    *
// * Date: 25 June 25                             *
// * Description: Provider for managing project configuration state                        *
// *****************************************************************************************

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/notification/model/mark_read_model.dart';
import 'package:whoxa/featuers/notification/model/notification_model.dart';
import 'package:whoxa/featuers/project-config/data/config_model.dart';
import 'package:whoxa/featuers/project-config/data/config_repo.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

class ProjectConfigProvider with ChangeNotifier {
  final ProjectConfigRepository _repository;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  ProjectConfigProvider(this._repository);

  // Private variables
  ProjectConfig? _projectConfig;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isFetchedThisSession =
      false; // ✅ Track if fetched from network this session
  String? _errorMessage;
  bool _hasError = false;

  NotificationListModel? _notificationListModel;
  MarkReadNotifiModel? _markReadNotifiModel;
  bool _isNotification = false;
  bool _isReadNotifi = false;
  bool isInternetIssue = false;

  // Getters
  ProjectConfig? get projectConfig => _projectConfig;
  ProjectConfigData? get configData => _projectConfig?.data;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get hasError => _hasError;
  bool get hasValidConfig => _projectConfig != null && _projectConfig!.status;
  bool get isNotification => _isNotification;
  bool get isReadNotifi => _isReadNotifi;
  MarkReadNotifiModel? get markReadNotifiModel => _markReadNotifiModel;
  NotificationListModel? get notificationListModel => _notificationListModel;
  Data? get notificaitonData => _notificationListModel?.data;

  // Configuration getters for easy access
  String get appName => configData?.appName ?? 'Rabtah Saj';
  String get appPrimaryColor => configData?.appPrimaryColor ?? '#FCC604';
  String get appSecondaryColor => configData?.appSecondaryColor ?? '#FAE390';
  bool get isPhoneAuthEnabled => configData?.phoneAuthentication ?? true;
  bool get isEmailAuthEnabled => configData?.emailAuthentication ?? true;
  int get maxGroupMembers => configData?.maximumMembersInGroup ?? 10;
  bool get showAllContacts => configData?.showAllContacts ?? true;
  bool get showPhoneContacts => configData?.showPhoneContacts ?? true;
  String get appLogoLight => configData?.appLogoLight ?? '';
  String get appLogoDark => configData?.appLogoDark ?? '';
  String get privacyPolicy => configData?.privacyPolicy ?? '';
  String get termsAndConditions => configData?.termsAndConditions ?? '';

  // New getters for the flow configuration
  bool get userNameFlow => configData?.userNameFlow ?? true;
  bool get contactFlow => configData?.contactFlow ?? true;

  // Debug method to log all config values
  void debugLogConfigValues() {
    debugPrint('🔧 ===== PROJECT CONFIG DEBUG =====');
    debugPrint('📱 App Name: $appName');
    debugPrint('🎨 Primary Color: $appPrimaryColor');
    debugPrint('📞 Phone Auth: $isPhoneAuthEnabled');
    debugPrint('📧 Email Auth: $isEmailAuthEnabled');
    debugPrint('👥 Show All Contacts: $showAllContacts');
    debugPrint('📱 Show Phone Contacts: $showPhoneContacts');
    debugPrint('👤 User Name Flow: $userNameFlow');
    debugPrint('📞 Contact Flow: $contactFlow');
    debugPrint('✅ Has Valid Config: $hasValidConfig');
    debugPrint('🔄 Is Loading: $isLoading');
    debugPrint('❌ Has Error: $hasError');
    if (hasError) {
      debugPrint('🚨 Error Message: $errorMessage');
    }
    debugPrint('🔧 ===== END CONFIG DEBUG =====');
  }

  String get appText => configData?.appText ?? '';
  String get copyrightText => configData?.copyrightText ?? '';

  /// ✅ Load cached config immediately for fast startup (NO network call)
  /// This is called during dependency injection setup
  /// Returns true if cached config was loaded, false otherwise
  Future<bool> loadCachedConfig() async {
    try {
      _logger.i('📦 Loading cached project configuration...');
      final cachedConfigJson = await SecurePrefs.getString(
        SecureStorageKeys.PROJECT_CONFIG,
      );

      if (cachedConfigJson != null && cachedConfigJson.isNotEmpty) {
        final configMap = jsonDecode(cachedConfigJson);
        _projectConfig = ProjectConfig.fromJson(configMap);
        // ✅ DO NOT set _isInitialized here - only set it after network fetch
        // This ensures splash screen will still call the API
        _logger.i('✅ Cached project configuration loaded successfully');
        _logger.i('📋 Cached App Name: ${_projectConfig?.data.appName}');

        // ✅ CRITICAL FIX: DO NOT call notifyListeners() during DI setup
        // The Provider tree might not be ready yet, and this can cause issues
        // We'll notify listeners when we fetch from network in splash screen
        // notifyListeners(); // ❌ Removed to prevent issues during DI setup

        return true;
      } else {
        _logger.i('ℹ️ No cached configuration found');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Failed to load cached configuration: $e');
      return false;
    }
  }

  /// ✅ CRITICAL FIX: Save config to cache for fast startup next time
  Future<void> _saveCachedConfig() async {
    try {
      if (_projectConfig != null) {
        final configJson = jsonEncode(_projectConfig!.toJson());
        await SecurePrefs.setString(
          SecureStorageKeys.PROJECT_CONFIG,
          configJson,
        );
        _logger.i('💾 Project configuration cached successfully');
      }
    } catch (e) {
      _logger.e('❌ Failed to save configuration to cache: $e');
    }
  }

  /// ✅ FIXED: Fetch project configuration from network
  /// This should be called from splash screen AFTER dependencies are ready
  /// Always fetches fresh config on app startup (unless already fetched this session)
  Future<bool> initializeProjectConfig({bool forceRefresh = false}) async {
    // ✅ FIX: Check if already fetched THIS SESSION, not just initialized
    if (_isFetchedThisSession && hasValidConfig && !forceRefresh) {
      _logger.i('✅ Project configuration already fetched this session');
      return true;
    }

    _logger.i('🌐 Fetching project configuration from network...');
    _setLoading(true);
    _clearError();

    try {
      // ✅ ALWAYS fetch from network on app startup
      await _fetchConfiguration();

      // ✅ Save to cache for next app startup
      await _saveCachedConfig();

      _isInitialized = true;
      _isFetchedThisSession = true; // ✅ Mark as fetched this session
      _logger.i(
        '✅ Project configuration initialized successfully from network',
      );
      return true;
    } catch (e) {
      _logger.e('❌ Failed to initialize project configuration from network', e);

      // ✅ If we have cached config, use it as fallback
      if (hasValidConfig) {
        _logger.w('⚠️ Using cached configuration as fallback');
        _isInitialized = true;
        return true;
      }

      await _handleConfigurationError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh configuration data
  Future<void> refreshConfiguration() async {
    _logger.i('Refreshing project configuration');
    _setLoading(true);
    _clearError();

    try {
      await _fetchConfiguration();
      _logger.i('Project configuration refreshed successfully');
    } catch (e) {
      _logger.e('Failed to refresh project configuration', e);
      await _handleConfigurationError(e);
    } finally {
      _setLoading(false);
    }
  }

  /// Private method to fetch configuration from repository
  Future<void> _fetchConfiguration() async {
    try {
      final config = await _repository.getProjectConfiguration();
      _projectConfig = config;
      _logger.i('Configuration fetched and stored successfully');
      _logger.d('App Name: ${config.data.appName}');
      notifyListeners();
    } catch (e) {
      _logger.e('Error in _fetchConfiguration', e);
      rethrow;
    }
  }

  List<Records>? notificationList;
  final List<Records> _notificationList = [];
  Future<void> fetchNotificationList() async {
    try {
      _isNotification = true;
      _errorMessage = null;
      isInternetIssue = false;
      notifyListeners();

      final notification = await _repository.getNotificationListRepo();
      _notificationListModel = notification;

      notificationList ??= []; // Initialize if null
      notificationList!.clear();
      _notificationList.clear(); // Clear old data

      if (_notificationListModel?.status == true &&
          _notificationListModel?.data?.records != null) {
        // int? myUserId = int.tryParse(userID); // Convert String to int
        final allRecords = _notificationListModel!.data!.records!;

        notificationList!.addAll(allRecords);
        _notificationList.addAll(allRecords); // ✅ add full list
        marReadNitifiApi();
      } else {
        _errorMessage = _notificationListModel?.message ?? 'Unknown error';
      }
    } on AppError catch (e) {
      final data = extractErrorData(e);
      _errorMessage = data?['message'] ?? 'Unknown error';
      isInternetIssue = e.isNetworkError;
    } catch (e) {
      _errorMessage = 'Unexpected error occurred';
      _logger.e("Error in Notification fetch: $e");
    } finally {
      _isNotification = false;
      notifyListeners();
    }
  }

  Map<String, List<Records>> get groupedNotification {
    Map<String, List<Records>> grouped = {};

    // Newest first, so the list reads top-to-bottom from the latest
    // notification. The API order is not guaranteed.
    final sorted = List<Records>.from(_notificationList)..sort((a, b) {
      final aDate = DateTime.tryParse(a.createdAt ?? '');
      final bDate = DateTime.tryParse(b.createdAt ?? '');
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });

    for (var notifi in sorted) {
      DateTime notifiDate = DateTime.parse(notifi.createdAt!);
      DateTime now = DateTime.now();
      String dateKey;

      if (notifiDate.year == now.year &&
          notifiDate.month == now.month &&
          notifiDate.day == now.day) {
        dateKey = 'Today';
      } else if (notifiDate.year == now.year &&
          notifiDate.month == now.month &&
          notifiDate.day == now.day - 1) {
        dateKey = 'Yesterday';
      } else {
        dateKey = '${notifiDate.day}/${notifiDate.month}/${notifiDate.year}';
      }

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(notifi);
    }

    return grouped;
  }

  Future<void> marReadNitifiApi() async {
    try {
      _isReadNotifi = true;
      _errorMessage = null;
      notifyListeners();

      final markNotification = await _repository.marReadNotifiRepo();
      _markReadNotifiModel = markNotification;

      if (_markReadNotifiModel?.status == true) {
        _logger.d(_markReadNotifiModel!.message!);
      } else {
        _errorMessage = _markReadNotifiModel?.message ?? "Unknown error";
      }
    } on AppError catch (e) {
      final data = extractErrorData(e);
      _errorMessage = data?['message'] ?? 'Unknown error';
    } catch (e) {
      _errorMessage = 'Unexpected error occurred';
      _logger.e("Error in Notification Mark Read: $e");
    } finally {
      _isReadNotifi = false;
      notifyListeners();
    }
  }

  /// Handle configuration errors by loading default config
  Future<void> _handleConfigurationError(dynamic error) async {
    _setError(error.toString());

    // Load default configuration to ensure app can still run
    try {
      _projectConfig = _repository.getDefaultConfiguration();
      _logger.w('Loaded default configuration due to error');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to load even default configuration', e);
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set error state
  void _setError(String error) {
    _errorMessage = error;
    _hasError = true;
    notifyListeners();
  }

  /// Clear error state
  void _clearError() {
    _errorMessage = null;
    _hasError = false;
    notifyListeners();
  }

  /// Check if specific features are enabled
  bool isFeatureEnabled(String feature) {
    switch (feature.toLowerCase()) {
      case 'phone_auth':
        return isPhoneAuthEnabled;
      case 'email_auth':
        return isEmailAuthEnabled;
      case 'show_all_contacts':
        return showAllContacts;
      case 'show_phone_contacts':
        return showPhoneContacts;
      default:
        return false;
    }
  }

  /// Get configuration value by key
  dynamic getConfigValue(String key) {
    if (!hasValidConfig) return null;

    switch (key) {
      case 'app_name':
        return appName;
      case 'app_primary_color':
        return appPrimaryColor;
      case 'app_secondary_color':
        return appSecondaryColor;
      case 'max_group_members':
        return maxGroupMembers;
      default:
        return null;
    }
  }

  /// Reset the provider state
  void reset() {
    _projectConfig = null;
    _isLoading = false;
    _isInitialized = false;
    _isFetchedThisSession = false; // ✅ Reset session flag
    _errorMessage = null;
    _hasError = false;
    notifyListeners();
    _logger.i('Project configuration provider reset');
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
