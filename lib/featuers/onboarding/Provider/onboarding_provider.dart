import 'dart:io';
import 'package:whoxa/featuers/chat/widgets/country_code.dart';
import 'package:whoxa/core/services/device_country_code_service.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:whoxa/featuers/auth/services/fcm_service.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart';

class OnboardingProvider extends ChangeNotifier {
  void initPermission() {
    // Initialize permissions list based on platform
    initPermissionsList();

    // ✅ CRITICAL FIX: Reset permission tracking on fresh starts for iOS
    // This prevents cached states from interfering with actual system permission status
    if (Platform.isIOS) {
      debugPrint(
        "🔄 iOS: Resetting permission tracking to sync with system state",
      );
      permissionsGranted.clear();
    }

    // Make sure permission check is complete before proceeding with the flow
    checkAllPermissionsStatus().then((_) {
      permissionsInitialized = true;
      notify();
    });
  }

  void notify() {
    notifyListeners();
  }

  int currentStep = 0;
  final int totalSteps = 4;

  void onBack() {
    if (currentStep > 0) {
      currentStep--;
      notifyListeners();
    }
  }

  void reset() {
    currentStep = 0;
    notifyListeners();
  }

  // ✅ APPLE COMPLIANCE (Guideline 5.1.1(iv)): "Skip" must not let the user
  // dismiss our custom priming screen without ever reaching the system
  // permission dialog. Skip still triggers the one-time OS prompt, then
  // proceeds to the next step regardless of the outcome - unlike "Next",
  // which requires a second tap once permission is granted.
  Future<void> skipCurrentPermission(BuildContext context) async {
    String permissionName = "";
    switch (currentStep) {
      case 0:
        permissionName = "Notification";
        break;
      case 1:
        permissionName = "Location";
        break;
      case 2:
        permissionName = "Contacts";
        break;
      case 3:
        permissionName = "Gallery";
        break;
    }

    debugPrint(
      "⏭️ User tapped Skip for $permissionName - still routing to the system permission prompt",
    );

    userInitiatedPermissionRequest = true;
    requestingPermission = true;
    notifyListeners();

    bool isGranted = false;
    try {
      switch (currentStep) {
        case 0:
          isGranted = await requestNotificationPermission();
          break;
        case 1:
          isGranted = await requestLocationPermission();
          if (isGranted) {
            await getCountryISOFromLocation();
          }
          break;
        case 2:
          isGranted = await requestContactPermission();
          break;
        case 3:
          isGranted = await requestMediaPermission();
          break;
      }
    } finally {
      requestingPermission = false;
      userInitiatedPermissionRequest = false;
      notifyListeners();
    }

    if (!context.mounted) return;

    // Show informational message
    snackbarNew(
      context,
      msg:
          isGranted
              ? "$permissionName permission granted."
              : "$permissionName skipped. You can enable it later in Settings.",
    );

    await Future.delayed(const Duration(milliseconds: 200));

    if (!context.mounted) return;

    // Move to next step or finish regardless of the permission outcome
    if (currentStep < 3) {
      currentStep++;
      notifyListeners();
    } else {
      // Complete onboarding
      await SecurePrefs.setBool(SecureStorageKeys.PERMISSION, true);
      permission = true;

      debugPrint("🎯 ONBOARDING COMPLETED (via skip flow)");

      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    }
  }

  bool requestingPermission = false;
  int currentPermissionIndex = 0;
  bool showPermissionDialog = false;
  bool continuePressed = false;
  bool permissionRequestComplete = false;
  bool permissionsInitialized = false;

  // Flag to track user-initiated permission requests (important for iOS)
  bool userInitiatedPermissionRequest = false;

  // Track which permissions have already been granted
  Map<Permission, bool> permissionsGranted = {};
  List<Map<String, dynamic>> permissions = [];

  // Initialize permissions list based on platform
  void initPermissionsList() {
    // Base permissions for all platforms
    permissions = [
      {
        'permission': Permission.notification,
        'title': 'Notifications',
        'description':
            'Allow notifications to stay updated with new messages and important alerts.',
      },
      {
        'permission': Permission.location,
        'title': 'Location',
        'description':
            'Share your location for location-based features and nearby friend suggestions.',
      },
      {
        'permission': Permission.camera,
        'title': 'Camera',
        'description':
            'Access your camera to take photos and make video calls with friends.',
      },
      {
        'permission': Permission.microphone,
        'title': 'Microphone',
        'description':
            'Use your microphone for voice messages and audio calls.',
      },
      {
        'permission': Permission.contacts,
        'title': 'Contacts',
        'description':
            'Find friends who are already using the app and connect easily.',
      },
    ];

    // Add platform-specific permissions
    if (Platform.isIOS) {
      // Add Photos permission only for iOS
      permissions.add({
        'permission': Permission.photos,
        'title': 'Photos',
        'description':
            'Share photos from your gallery with friends and family.',
      });
    }
  }

  /// ✅ IMPROVED: Check notification permission with iOS-specific handling
  Future<bool> checkNotificationPermission() async {
    try {
      var status = await Permission.notification.status;

      if (Platform.isIOS) {
        // ✅ iOS notification permissions can be provisional, granted, or denied
        // Provisional means notifications are delivered quietly to Notification Center
        bool isGranted = status.isGranted || status.isProvisional;
        debugPrint(
          "iOS Notification permission status: $status, isGranted: $isGranted",
        );
        return isGranted;
      } else {
        // Android handling
        bool isGranted = status.isGranted;
        debugPrint(
          "Android Notification permission status: $status, isGranted: $isGranted",
        );
        return isGranted;
      }
    } catch (e) {
      debugPrint("Error checking notification permission: $e");
      return false;
    }
  }

  Future<bool> checkPhotoPermission() async {
    try {
      // On iOS, photos permission has different statuses
      if (Platform.isIOS) {
        // ✅ FIXED: Check for limited, added, or full access on iOS
        var status = await Permission.photos.status;
        bool isGranted = status.isGranted || status.isLimited;
        debugPrint(
          "iOS Photos permission status: $status, isGranted: $isGranted",
        );
        return isGranted;
      } else if (Platform.isAndroid) {
        // ✅ IMPROVED: Check multiple media permissions on Android
        var photosStatus = await Permission.photos.status;
        var videosStatus = await Permission.videos.status;
        var storageStatus = await Permission.storage.status;

        bool isGranted =
            photosStatus.isGranted ||
            videosStatus.isGranted ||
            storageStatus.isGranted;
        debugPrint(
          "Android Media permissions - Photos: $photosStatus, Videos: $videosStatus, Storage: $storageStatus, isGranted: $isGranted",
        );
        return isGranted;
      }
      return false;
    } catch (e) {
      debugPrint("Error checking photo permission: $e");
      return false;
    }
  }

  // Check the status of all permissions and store results
  Future<void> checkAllPermissionsStatus() async {
    debugPrint("Checking permission status for all permissions...");

    for (var permissionData in permissions) {
      final permission = permissionData['permission'] as Permission;

      // ✅ IMPROVED: Use specialized permission checking methods
      if (permission == Permission.notification) {
        final isNotificationGranted = await checkNotificationPermission();
        permissionsGranted[permission] = isNotificationGranted;
        debugPrint(
          "Notification permission status: $isNotificationGranted (special iOS check)",
        );
      } else if (permission == Permission.photos) {
        final isPhotoGranted = await checkPhotoPermission();
        permissionsGranted[permission] = isPhotoGranted;
        debugPrint("Photos permission status: $isPhotoGranted (special check)");
      } else {
        // Standard permission check for other permissions (location, contacts, etc.)
        final status = await permission.status;
        permissionsGranted[permission] = status.isGranted;
        debugPrint(
          "Permission ${permission.toString()} status: ${status.isGranted}",
        );
      }
    }

    // Log all permission statuses for debugging
    permissionsGranted.forEach((permission, isGranted) {
      debugPrint(
        "Permission check result: ${permission.toString()} = $isGranted",
      );
    });
  }

  // Save that we've gone through permissions
  void savePermissionsRequested() {
    try {
      // Hive.box('userdata').put('permissionsrequested', true);
      debugPrint("Successfully saved permissionsrequested flag to Hive");
    } catch (e) {
      debugPrint("Error saving permissionsrequested flag: $e");
    }
  }

  // Common method to request permission with platform-specific handling
  Future<bool> requestPermission(
    Permission permission,
    String permissionName,
  ) async {
    final status = await permission.status;

    // If already granted, return true
    if (status.isGranted) {
      permissionsGranted[permission] = true;

      // ✅ CRITICAL: Setup FCM if notification permission already granted
      if (permission == Permission.notification) {
        try {
          await FcmService().initialize();
          debugPrint(
            "✅ FCM setup completed (permission already granted)",
          );
        } catch (e) {
          debugPrint(
            "⚠️ Error setting up FCM (permission already granted): $e",
          );
        }
      }

      notifyListeners();
      return true;
    }

    // For iOS, need specific handling to ensure the prompt shows
    if (Platform.isIOS) {
      debugPrint("iOS: Requesting permission: $permissionName");

      // Set userInitiatedPermissionRequest to true, iOS requires user-initiated actions
      if (!userInitiatedPermissionRequest) {
        debugPrint("iOS: User initiated flag was not set!");
      }

      try {
        // Request permission - on iOS this should show the system dialog
        final result = await permission.request();
        debugPrint("iOS: Permission result for $permissionName: $result");

        // Update tracking
        permissionsGranted[permission] = result.isGranted;
        notifyListeners();

        return result.isGranted;
      } catch (e) {
        debugPrint("Error requesting iOS permission: $e");
        return false;
      }
    } else {
      // Android handling
      if (status.isDenied) {
        final result = await permission.request();
        permissionsGranted[permission] = result.isGranted;

        // ✅ CRITICAL: Setup FCM after notification permission is granted
        if (result.isGranted && permission == Permission.notification) {
          try {
            await FcmService().initialize();
            debugPrint(
              "✅ Android: FCM setup completed after permission grant",
            );
          } catch (e) {
            debugPrint(
              "⚠️ Android: Error setting up FCM after permission grant: $e",
            );
          }
        }

        notifyListeners();
        return result.isGranted;
      }

      // Permanently denied case
      permissionsGranted[permission] = false;
      notifyListeners();
      return false;
    }
  }

  // Individual permission request methods that use the common method
  // ✅ IMPROVED: Handle iOS notification permission with provisional state
  Future<bool> requestNotificationPermission() async {
    // For iOS, use the specific notification request approach
    if (Platform.isIOS) {
      debugPrint("iOS: Requesting notification permission specifically");

      try {
        // ✅ CRITICAL FIX: Double-check current status before requesting
        final initialStatus = await Permission.notification.status;
        debugPrint("🔍 iOS: Initial notification status check: $initialStatus");

        // Check if already granted (including provisional)
        if (initialStatus.isGranted || initialStatus.isProvisional) {
          permissionsGranted[Permission.notification] = true;

          // ✅ CRITICAL: Setup FCM even if permission already granted
          try {
            await FcmService().initialize();
            debugPrint(
              "✅ iOS: FCM setup completed (permission already granted/provisional)",
            );
          } catch (e) {
            debugPrint(
              "⚠️ iOS: Error setting up FCM (permission already granted/provisional): $e",
            );
          }

          notifyListeners();
          debugPrint(
            "✅ iOS: Notification already granted/provisional: $initialStatus",
          );
          return true;
        }

        // ✅ iOS CRITICAL FIX: Never treat notification permission as permanently denied
        // On iOS, requesting again after denial may work, and we don't want settings dialog
        if (initialStatus.isPermanentlyDenied) {
          debugPrint(
            "⚠️ iOS: Notification permission marked as permanently denied - but we'll try once more",
          );
          // Continue to request - iOS sometimes allows this
        }

        // ✅ iOS CRITICAL FIX: Always try to request permission unless already granted
        // Don't overthink the status - just request it once
        debugPrint(
          "🔐 iOS: Requesting notification permission (status: $initialStatus)",
        );

        // iOS CRITICAL: Add delay before permission request to ensure proper UI state
        await Future.delayed(Duration(milliseconds: 500));

        // Request permission - iOS will handle showing dialog or not
        final result = await Permission.notification.request();

        // Important: On iOS, check for both granted and provisional
        final checkStatus = await Permission.notification.status;
        bool isEffectivelyGranted =
            checkStatus.isGranted || checkStatus.isProvisional;

        debugPrint(
          "iOS: Notification permission result: $result, status check: $checkStatus, effectively granted: $isEffectivelyGranted",
        );

        // Update tracking with the actual status
        permissionsGranted[Permission.notification] = isEffectivelyGranted;

        // ✅ CRITICAL: Setup FCM after permission is granted
        if (isEffectivelyGranted) {
          try {
            await FcmService().initialize();
            debugPrint(
              "✅ iOS: FCM setup completed after permission grant",
            );
          } catch (e) {
            debugPrint(
              "⚠️ iOS: Error setting up FCM after permission grant: $e",
            );
          }
        }

        notifyListeners();

        return isEffectivelyGranted;
      } catch (e) {
        debugPrint("❌ Error requesting iOS notification permission: $e");
        // iOS FALLBACK: Don't block onboarding flow due to permission errors
        permissionsGranted[Permission.notification] = false;
        notifyListeners();
        return false;
      }
    } else {
      // For other platforms, use the common method
      return await requestPermission(Permission.notification, "Notification");
    }
  }

  Future<bool> requestLocationPermission() async {
    return await requestPermission(Permission.location, "Location");
  }

  Future<bool> requestContactPermission() async {
    return await requestPermission(Permission.contacts, "Contacts");
  }

  // ✅ IMPROVED: Special handling for media permissions with iOS limited access
  Future<bool> requestMediaPermission() async {
    // iOS handling - request photos permission with limited access support
    if (Platform.isIOS) {
      try {
        // First check if already granted (including limited)
        final status = await Permission.photos.status;
        if (status.isGranted || status.isLimited) {
          permissionsGranted[Permission.photos] = true;
          notifyListeners();
          debugPrint("iOS: Photos already granted/limited: $status");
          return true;
        }

        // Request permission
        final result = await Permission.photos.request();
        final checkStatus = await Permission.photos.status;
        bool isEffectivelyGranted =
            checkStatus.isGranted || checkStatus.isLimited;

        debugPrint(
          "iOS: Photos permission result: $result, status check: $checkStatus, effectively granted: $isEffectivelyGranted",
        );

        permissionsGranted[Permission.photos] = isEffectivelyGranted;
        notifyListeners();
        return isEffectivelyGranted;
      } catch (e) {
        debugPrint("Error requesting iOS photos permission: $e");
        return false;
      }
    } else {
      // Android handling - request multiple permissions
      final photoStatus = await Permission.photos.status;
      final videoStatus = await Permission.videos.status;
      final storageStatus = await Permission.storage.status;

      bool granted =
          photoStatus.isGranted ||
          videoStatus.isGranted ||
          storageStatus.isGranted;

      if (!granted) {
        final requestedPhoto = await Permission.photos.request();
        final requestedVideo = await Permission.videos.request();
        final requestedStorage = await Permission.storage.request();

        granted =
            requestedPhoto.isGranted ||
            requestedVideo.isGranted ||
            requestedStorage.isGranted;

        // Update all statuses
        permissionsGranted[Permission.photos] = requestedPhoto.isGranted;
        permissionsGranted[Permission.videos] = requestedVideo.isGranted;
        permissionsGranted[Permission.storage] = requestedStorage.isGranted;
      } else {
        permissionsGranted[Permission.photos] = photoStatus.isGranted;
        permissionsGranted[Permission.videos] = videoStatus.isGranted;
        permissionsGranted[Permission.storage] = storageStatus.isGranted;
      }

      notifyListeners();
      return granted;
    }
  }

  bool isPermissionGranted(Permission permission) {
    return permissionsGranted[permission] ?? false;
  }

  // Log all permission statuses for debugging
  Future<void> logAllPermissionStatuses() async {
    debugPrint("==================== PERMISSION STATUSES ====================");
    final notifications = await Permission.notification.status;
    final location = await Permission.location.status;
    final contacts = await Permission.contacts.status;
    final camera = await Permission.camera.status;
    final microphone = await Permission.microphone.status;

    if (Platform.isIOS) {
      final photos = await Permission.photos.status;
      debugPrint("Photos permission (iOS): $photos");
    } else {
      final storage = await Permission.storage.status;
      debugPrint("Storage permission (Android): $storage");
    }

    debugPrint("Notification permission: $notifications");
    debugPrint("Location permission: $location");
    debugPrint("Contacts permission: $contacts");
    debugPrint("Camera permission: $camera");
    debugPrint("Microphone permission: $microphone");
    debugPrint("===========================================================");
  }

  Future<void> checkAllPermissions() async {
    bool anyPermissionGranted = false;

    for (final permData in permissions) {
      final permission = permData['permission'] as Permission;
      if (await permission.isGranted) {
        anyPermissionGranted = true;
        permissionsGranted[permission] = true;
      } else {
        permissionsGranted[permission] = false;
      }
    }

    await SecurePrefs.setBool(
      SecureStorageKeys.PERMISSION,
      anyPermissionGranted,
    );
    permission = anyPermissionGranted;

    notifyListeners();
  }

  Future<void> onNext(BuildContext context) async {
    // Log current permission statuses
    await logAllPermissionStatuses();

    // ✅ CRITICAL FIX: Re-check current permission status before proceeding
    await checkAllPermissionsStatus();

    // Get current permission for this step
    String permissionName = "";
    bool isCurrentlyGranted = false;

    switch (currentStep) {
      case 0:
        permissionName = "Notification";
        // ✅ FIX: Use the specialized check for iOS notifications
        isCurrentlyGranted = await checkNotificationPermission();
        break;
      case 1:
        permissionName = "Location";
        final locationStatus = await Permission.location.status;
        isCurrentlyGranted = locationStatus.isGranted;
        break;
      case 2:
        permissionName = "Contacts";
        // ✅ FIX: Check current contact permission status properly
        final contactStatus = await Permission.contacts.status;
        isCurrentlyGranted = contactStatus.isGranted;
        break;
      case 3:
        permissionName = "Gallery";
        // For gallery, we check different permissions based on platform
        if (Platform.isIOS) {
          isCurrentlyGranted = await checkPhotoPermission();
        } else {
          final photoStatus = await Permission.photos.status;
          final videoStatus = await Permission.videos.status;
          final storageStatus = await Permission.storage.status;
          isCurrentlyGranted =
              photoStatus.isGranted ||
              videoStatus.isGranted ||
              storageStatus.isGranted;
        }
        break;
      default:
        permissionName = "";
        isCurrentlyGranted = false;
    }

    debugPrint(
      "🔍 Permission check for $permissionName: isCurrentlyGranted = $isCurrentlyGranted",
    );

    // If permission is already granted, move to next step
    if (isCurrentlyGranted) {
      debugPrint(
        "✅ $permissionName permission already granted - moving to next step",
      );
      // Move to next step or finish
      if (currentStep < 3) {
        currentStep++;
        notifyListeners();
      } else {
        // ✅ iOS FIX: Save onboarding completion regardless of actual permissions granted
        // This ensures iOS navigation flow works correctly even if user denies some permissions
        await SecurePrefs.setBool(SecureStorageKeys.PERMISSION, true);
        permission = true;

        // 🔍 DEBUG: Verify onboarding completion is saved properly
        final permi = await SecurePrefs.getBool(SecureStorageKeys.PERMISSION);
        debugPrint("🎯 ONBOARDING COMPLETED (iOS):");
        debugPrint("  SecurePrefs PERMISSION: $permi");
        debugPrint("  Global permission variable: $permission");
        debugPrint("  Platform: iOS - onboarding flow completed");

        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
      return;
    }

    // If permission is not granted, request it
    // This flag is critical for iOS - set it before requesting
    userInitiatedPermissionRequest = true;
    debugPrint("Setting userInitiatedPermissionRequest = true");

    // Request the relevant permission
    bool isGranted = false;
    requestingPermission = true;
    notifyListeners();

    try {
      switch (currentStep) {
        case 0: // Notification
          isGranted = await requestNotificationPermission();
          break;
        case 1: // Location
          isGranted = await requestLocationPermission();
          if (isGranted) {
            await getCountryISOFromLocation();
          }
          break;
        case 2: // Contacts
          isGranted = await requestContactPermission();
          break;
        case 3: // Gallery
          isGranted = await requestMediaPermission();
          break;
      }
    } finally {
      requestingPermission = false;
      notifyListeners();
    }

    // Reset flag after permission request
    userInitiatedPermissionRequest = false;
    debugPrint("Reset userInitiatedPermissionRequest = false");

    if (!context.mounted) return;

    if (isGranted) {
      // Show success message but DON'T move to next step
      // The user will need to press the Next button again
      // snackbarNew(
      //   context,
      //   msg: "$permissionName permissions granted. Press Next to continue.",
      // );

      //Update UI to show "Next" button instead of "Allow"
      notifyListeners();
    } else {
      // ✅ APPLE COMPLIANCE FIX: Permissions are OPTIONAL
      // User denied permission - show informational message but ALLOW them to proceed
      // This complies with Apple Guidelines 5.1.5 (Location) and 4.5.4 (Notifications)
      debugPrint(
        "⚠️ $permissionName permission denied - allowing user to proceed anyway",
      );

      // Show a non-blocking informational message
      snackbarNew(
        context,
        msg: "$permissionName is optional. Some features may be limited.",
      );

      // ✅ CRITICAL: Allow user to proceed to next step even without permission
      await Future.delayed(const Duration(milliseconds: 300));

      if (!context.mounted) return;

      // Move to next step or finish
      if (currentStep < 3) {
        currentStep++;
        notifyListeners();
      } else {
        // Complete onboarding even if permissions were denied
        await SecurePrefs.setBool(SecureStorageKeys.PERMISSION, true);
        permission = true;

        debugPrint("🎯 ONBOARDING COMPLETED (permissions optional):");
        debugPrint("  User proceeded without granting all permissions");

        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    }

    // Log permission statuses after the request
    await logAllPermissionStatuses();
  }

  /// Detects country from GPS location and updates DeviceCountryCodeService.
  /// Uses DeviceCountryCodeService for fallback (+1 US).
  /// Priority: GPS location → Device locale → Fallback (+1)
  Future<String?> getCountryISOFromLocation() async {
    try {
      // Check if location service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('📍 Location service disabled, using device-detected fallback');
        return _useDeviceDetectedCountryOnboarding();
      }

      // Check location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('📍 Location permission not granted, using device-detected fallback');
        return _useDeviceDetectedCountryOnboarding();
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Reverse geocode to get country
      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty || placemarks.first.isoCountryCode == null) {
        debugPrint('📍 Could not determine country from GPS, using device-detected fallback');
        return _useDeviceDetectedCountryOnboarding();
      }

      final newCountry = placemarks.first.isoCountryCode!.toUpperCase();

      // Save to storage
      await SecurePrefs.setString(
        SecureStorageKeys.COUNTRY_SHORT_NAME,
        newCountry,
      );

      // Convert ISO → Dial Code
      final dialCode = getDialCodeFromISO(newCountry);

      // Update DeviceCountryCodeService for consistency across the app
      if (dialCode.isNotEmpty) {
        await DeviceCountryCodeService.instance.updateCountryCode(
          dialCode.replaceAll('+', ''),
          newCountry,
        );
      }

      countryShortName = newCountry;
      notify();

      debugPrint('📍 Country detected from GPS: $newCountry ($dialCode)');
      return newCountry;
    } catch (e) {
      debugPrint('📍 Error detecting country from GPS: $e');
      return _useDeviceDetectedCountryOnboarding();
    }
  }

  /// Fallback method - uses device locale when location is not available
  /// This is used when GPS detection fails or location permission is denied
  /// Priority: Device locale → Fallback to +1 (US)
  String _useDeviceDetectedCountryOnboarding() {
    // Try to get country from device locale via DeviceCountryCodeService
    // This was already initialized with locale detection in dependency_injection
    final detectionSource = DeviceCountryCodeService.instance.getDetectionSource();
    final detectedIsoCode = DeviceCountryCodeService.instance.getDefaultIsoCode();
    final detectedDialCode = DeviceCountryCodeService.instance.getDefaultDialCodeWithPlus();

    // Use device-detected country (from locale) if available
    // Only use hardcoded fallback if truly no detection method worked
    if (detectionSource != 'fallback' && detectionSource != 'unknown') {
      countryShortName = detectedIsoCode;
      notify();

      debugPrint(
        '📍 Location not available, using device locale: $detectedIsoCode ($detectedDialCode) via $detectionSource',
      );
      return detectedIsoCode;
    }

    // True fallback - no detection method worked
    const fallbackIsoCode = 'US';
    const fallbackDialCode = '+1';

    countryShortName = fallbackIsoCode;
    notify();

    debugPrint(
      '📍 No country detection available (source: $detectionSource), using fallback: $fallbackIsoCode ($fallbackDialCode)',
    );
    return fallbackIsoCode;
  }
}
