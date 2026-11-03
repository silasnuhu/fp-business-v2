import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/featuers/provider/tabbar_provider.dart';
import 'package:whoxa/core/services/cold_start_handler.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/utils/logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? animationController;
  Animation<double>? animation;
  final ConsoleAppLogger _logger = ConsoleAppLogger();
  final String splashId = DateTime.now().millisecondsSinceEpoch.toString();

  // Track initialization status
  bool _projectConfigLoaded = false;

  // Call navigation state tracking
  bool _isNavigatingToCall = false;
  bool _shouldSkipSplashNavigation = false;

  // Prevent double navigation
  static bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    debugPrint("Welcome to splash - Instance ID: $splashId");
    _logger.i("Splash screen initialized - Instance ID: $splashId");

    // ✅ CRITICAL FIX: If navigation already happened, don't initialize anything
    if (_hasNavigated) {
      _logger.i(
        "⚠️ Navigation already completed - skipping initialization to prevent double navigation",
      );
      return;
    }

    _logger.i("🔄 First splash instance - ready for navigation");

    _initializeAnimation();

    // ✅ FIX: Defer initialization until after build phase to prevent setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppInBackground();
    });
  }

  void _initializeAnimation() {
    animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    animation = CurvedAnimation(
      parent: animationController!,
      curve: Curves.easeOut,
    );

    animation!.addListener(() => setState(() {}));
    animationController!.forward();
  }

  void _initializeAppInBackground() async {
    final stopwatch = Stopwatch()..start();

    // 1. Handle a pending incoming-call cold start FIRST, ahead of project
    // config. main.dart calls FcmService().checkColdStartNotification()
    // before runApp(), so ColdStartHandler already knows the answer here —
    // this is a same-frame check, not a race against this splash's own
    // config fetch. A ringing call must reach the call screen immediately
    // instead of sitting behind a project-config network round-trip it
    // doesn't need.
    if (ColdStartHandler().hasPendingCallData) {
      _logger.i(
        "📞 Pending call notification detected — prioritizing over config load",
      );
      // Config is still needed for the rest of the app once the call ends —
      // load it in the background instead of blocking the call screen on it.
      unawaited(_initializeProjectConfig());
      await _handlePendingCallNotification();
      _logger.i("✅ Call notification handled");
      return;
    }

    // 2. Load project config — cache-first, does not block on network if a
    // valid cached config already exists (see _initializeProjectConfig)
    final usedCachedConfig = await _initializeProjectConfig();
    _logger.i("✅ Project config loaded");

    // 3. ✅ OFFLINE-FIRST: Only enforce the full branding delay on a true
    // first run where we had to wait on the network for config. Returning
    // users with a cached config get just enough time to avoid a splash
    // flash, not a flat tax on every app open.
    final minimumSplashDuration = usedCachedConfig
        ? const Duration(milliseconds: 400)
        : const Duration(seconds: 2);

    final remaining = minimumSplashDuration - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    // 4. Navigate only if not already navigated and not navigating to call
    if (!_shouldSkipSplashNavigation && mounted && !_hasNavigated) {
      _logger.i("✅ All initialization complete - navigating");
      navigationPage();
    } else {
      _logger.i(
        "⏭️ Skipping navigation - already navigated or navigating to call",
      );
    }
  }

  /// Loads project config. Returns true if a valid cached config was
  /// already available (network refresh happens silently in the background
  /// in that case), or false if we had to block on the network because
  /// there was nothing cached yet (true first launch).
  Future<bool> _initializeProjectConfig() async {
    try {
      _logger.i('🚀 Loading project configuration...');

      final configProvider = Provider.of<ProjectConfigProvider>(
        context,
        listen: false,
      );

      final langProvider = Provider.of<LanguageProvider>(
        context,
        listen: false,
      );

      // ✅ OFFLINE-FIRST: If DI setup already loaded a valid cached config,
      // don't block navigation on a network round-trip — refresh silently
      // in the background instead. Only block when there's truly nothing
      // cached to show yet.
      final hasCachedConfig = configProvider.hasValidConfig;
      if (hasCachedConfig) {
        unawaited(configProvider.initializeProjectConfig(forceRefresh: true));
      } else {
        await configProvider.initializeProjectConfig(forceRefresh: true);
      }

      // Load language data
      langProvider.fetchLangData();

      if (mounted) {
        setState(() {
          _projectConfigLoaded = true;
        });
      }

      _logger.i('✅ Project config loaded: ${configProvider.appName}');
      _logger.i('✅ Dynamic logo should now be visible');
      return hasCachedConfig;
    } catch (e) {
      _logger.e('❌ Error loading config: $e');
      // Continue anyway with defaults
      if (mounted) {
        setState(() {
          _projectConfigLoaded = true;
        });
      }
      return false;
    }
  }

  void navigationPage() async {
    _logger.i('🧭 navigationPage() called - checking conditions');

    if (!mounted) {
      _logger.i('🚫 Not mounted - returning');
      return;
    }

    // ✅ PREVENT DOUBLE NAVIGATION: Check if navigation already happened
    if (_hasNavigated) {
      _logger.i('🚫 Skipping navigation - already navigated (flag=true)');
      return;
    }

    // ✅ CRITICAL: Skip navigation if already navigating to call or should skip
    if (_isNavigatingToCall || _shouldSkipSplashNavigation) {
      _logger.i('🚫 Skipping splash navigation - call screen priority active');
      SplashNavigationTracker.markSkipped();
      return;
    }

    // ✅ CRITICAL: Mark as navigated FIRST to prevent race conditions
    _hasNavigated = true;
    _logger.i('✅ Navigation flag set to true - proceeding with navigation');

    _logger.i('🧭 Starting navigation logic');
    _logger.i('📊 Initialization status: Config=$_projectConfigLoaded');

    // Small delay to ensure safe context usage
    await Future.delayed(Duration(milliseconds: 100));

    if (!mounted) return;

    // Navigation for calls is handled from NavigationHelper
    if (!NavigationHelper.getIsNavigatingCall) {
      String route = await _handleCurrentScreen();

      // ✅ Check if widget is still mounted before navigation
      if (!mounted) {
        _logger.i('🚫 Widget not mounted - canceling navigation');
        return;
      }

      _logger.i('🚀 NAVIGATING TO: $route');
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (Route<dynamic> route) => false,
      );
      _logger.i('✅ Navigation completed to: $route');
    }
  }

  /// Handle pending call notifications
  Future<void> _handlePendingCallNotification() async {
    try {
      final coldStartHandler = ColdStartHandler();

      if (coldStartHandler.hasPendingCallData) {
        _logger.i('📞 Pending call notification - handling immediately');

        _isNavigatingToCall = true;
        _shouldSkipSplashNavigation = true;

        if (!mounted) return;

        await coldStartHandler.handlePendingNotification();

        _logger.i('✅ Call notification handled');
        return;
      }

      _logger.d('No pending call notifications');
    } catch (e) {
      _logger.e('❌ Error handling call notification: $e');
      _isNavigatingToCall = false;
      _shouldSkipSplashNavigation = false;
    }
  }

  @override
  void dispose() {
    animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUI(),
      child: Consumer<ProjectConfigProvider>(
        builder: (context, configProvider, _) {
          return Scaffold(
            backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
            body: Center(
              child: Stack(
                children: [
                  SvgPicture.asset(AppAssets.splashLine),
                  Column(
                    children: [
                      // SizedBox(height: SizeConfig.height(40)),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Use dynamic logo from project config
                            Center(
                              child: _projectConfigLoaded
                                  ? (isLightModeGlobal
                                        ? appDynamicLogo(height: 50)
                                        : appDynamicLogoDark(height: 50))
                                  : SizedBox(
                                      height: SizeConfig.sizedBoxHeight(50),
                                      width: SizeConfig.sizedBoxHeight(50),
                                      child: Center(child: commonLoading()),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<String> _handleCurrentScreen() async {
    // ✅ CRITICAL FIX: Native iOS approach handles first run detection in AppDelegate
    // iOS will clear FlutterSecureStorage automatically on first run after uninstall
    bool hasCompletedOnboarding = await SecurePrefs.getBool(
      SecureStorageKeys.PERMISSION,
    );
    String token = authToken;
    bool hasAnyUserData =
        userName.isNotEmpty || userID.isNotEmpty || token.isNotEmpty;

    // 🔍 DEBUG: Log navigation decision factors
    _logger.i("🧭 Navigation Debug:");
    _logger.i(
      "  hasCompletedOnboarding (SecurePrefs): $hasCompletedOnboarding",
    );
    _logger.i("  permission (global variable): $permission");
    _logger.i("  authToken: '${token.isEmpty ? 'EMPTY' : 'PRESENT'}'");
    _logger.i("  userName: '${userName.isEmpty ? 'EMPTY' : userName}'");
    _logger.i(
      "  userProfile: '${userProfile.isEmpty ? 'EMPTY' : userProfile}'",
    );
    _logger.i("  hasAnyUserData: $hasAnyUserData");

    // ✅ CRITICAL FIX: Simplified logic - if no onboarding completion or no user data, go to onboarding
    // The native iOS approach handles data clearing for fresh installs
    if (!hasCompletedOnboarding && !hasAnyUserData) {
      _logger.i(
        "🎯 Going to: ONBOARDING (No completed onboarding or no user data)",
      );
      return AppRoutes.onboarding;
    }

    // If token not available then navigate to signin method
    if (token.isEmpty) {
      _logger.i("🎯 Going to: LOGIN (no token)");
      return AppRoutes.login;
    }

    // Check user info completion - CRITICAL: Check firstName (mandatory field)
    String? firstName =
        await SecurePrefs.getString(SecureStorageKeys.FIRST_NAME) ?? "";
    String username = userName;

    _logger.i("🔍 Splash firstName from SecureStorage: '$firstName'");
    _logger.i("🔍 Splash userName: '$username'");

    // CRITICAL: Check firstName first - this is the mandatory field for profile completion
    if (firstName.isEmpty) {
      _logger.i(
        "🎯 Going to: ADD_INFO (firstName is empty - profile incomplete)",
      );
      Future.microtask(() {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).initializeData();
        }
      });
      return AppRoutes.login;
    }

    // Secondary check: username
    if (username.isEmpty) {
      _logger.i("🎯 Going to: ADD_INFO (no username)");
      Future.microtask(() {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).initializeData();
        }
      });
      return AppRoutes.login;
    }

    // ✅ ANDROID FIX: Read userProfile directly from secure storage to ensure fresh data
    // Don't rely on global variable which might not be updated on app restart
    String? userprofile =
        await SecurePrefs.getString(SecureStorageKeys.USER_PROFILE) ?? "";
    _logger.i("🔍 Splash userProfile from SecureStorage: '$userprofile'");
    _logger.i("🔍 Splash userProfile global variable: '$userProfile'");

    // ✅ Update global variable to ensure consistency
    userProfile = userprofile;

    if (userprofile.isEmpty) {
      // Before going to avatar, check if firstName is still empty (user might have incomplete profile)
      if (firstName.isEmpty) {
        _logger.i(
          "🎯 Going to: ADD_INFO (empty profile but firstName also empty - profile incomplete)",
        );
        Future.microtask(() {
          if (mounted) {
            Provider.of<AuthProvider>(context, listen: false).initializeData();
          }
        });
        return AppRoutes.login;
      }

      // TEMP: avatar selection screen removed from the flow for now.
      // Previously returned AppRoutes.avatarProfile here; go to the app instead.
      _logger.i(
        "🎯 Going to: TABBAR (empty profile from secure storage - avatar screen disabled)",
      );
      Future.microtask(() {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).initializeData();
          Provider.of<TabbarProvider>(
            context,
            listen: false,
          ).navigateToIndex(0);
        }
      });
      return AppRoutes.tabbar;
    } else if (userprofile ==
        "${ApiEndpoints.socketUrl}/uploads/not-found-images/profile-image.png") {
      // Before going to avatar, check if firstName is still empty (user might have incomplete profile)
      if (firstName.isEmpty) {
        _logger.i(
          "🎯 Going to: ADD_INFO (default profile but firstName also empty - profile incomplete)",
        );
        Future.microtask(() {
          if (mounted) {
            Provider.of<AuthProvider>(context, listen: false).initializeData();
          }
        });
        return AppRoutes.login;
      }

      // TEMP: avatar selection screen removed from the flow for now.
      // Previously returned AppRoutes.avatarProfile here; go to the app instead.
      _logger.i(
        "🎯 Going to: TABBAR (default profile image from secure storage - avatar screen disabled)",
      );
      Future.microtask(() {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).initializeData();
          Provider.of<TabbarProvider>(
            context,
            listen: false,
          ).navigateToIndex(0);
        }
      });
      return AppRoutes.tabbar;
    }

    // All checks passed, go to main app
    _logger.i("🎯 Going to: TABBAR (all checks passed)");
    Future.microtask(() {
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).initializeData();
        Provider.of<TabbarProvider>(context, listen: false).navigateToIndex(0);
      }
    });

    return AppRoutes.tabbar;
  }
}

// this is check for call screen redirection and again go to the tabbar
class SplashNavigationTracker {
  static bool wasSkipped = false;
  static bool cameFromNotificationTap = false;

  /// Reset the tracker after call navigation is complete
  static void reset() {
    wasSkipped = false;
    cameFromNotificationTap = false;
  }

  /// Mark splash as skipped for call navigation
  static void markSkipped() {
    wasSkipped = true;
  }

  /// Mark that user came from notification tap
  static void markCameFromNotification() {
    cameFromNotificationTap = true;
  }
}
