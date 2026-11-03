import 'dart:async';
import 'dart:ui';

import 'package:whoxa/core/deep_links/invite_link_handler.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:whoxa/design/fp_theme_sync.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/dependency_injection.dart';
import 'package:whoxa/featuers/auth/services/fcm_service.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/provider_list.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/app_version.dart';
import 'package:whoxa/core/app_life_cycle.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/widgets/global.dart';
import 'utils/brand_theme.dart';

final ConsoleAppLogger logger = ConsoleAppLogger();

String? _startupError;
String? _startupDetail;

/// Main entry point for the application.
/// Wraps the bootstrap so a startup failure shows a readable error screen
/// instead of the app closing with no message on the device.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    _startupError ??= details.exceptionAsString();
    _startupDetail ??= details.stack?.toString();
    logger.e('FlutterError: ${details.exceptionAsString()}');
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _startupError ??= error.toString();
    _startupDetail ??= stack.toString();
    logger.e('Uncaught platform error: $error');
    return true;
  };

  try {
    // A plugin that never completes (mobile-only plugins on web) must never
    // leave the app with no widget tree at all: bound the bootstrap and mount
    // the UI regardless once it expires.
    await _bootstrap().timeout(
      const Duration(seconds: 20),
      onTimeout: () => logger.e('Bootstrap timed out - starting UI anyway'),
    );
    runApp(MultiProvider(providers: appProviders, child: const MyApp()));

    // Invite links: open the app straight into the community join flow.
    InviteLinkHandler.instance.start();
  } catch (e, s) {
    logger.e('FATAL startup error', e);
    runApp(StartupErrorApp(error: e.toString(), detail: s.toString()));
  }
}

Future<void> _bootstrap() async {

  // Local key-value store for the chat message-page cache (see
  // ChatCacheService) — must be ready before anything could possibly touch
  // that cache, so it's initialized synchronously up front rather than
  // folded into the parallel Future.wait below.
  await Hive.initFlutter();

  // ── Fresh-install guard ────────────────────────────────────────────────
  // iOS keeps flutter_secure_storage keychain items even after the app is
  // deleted, so a reinstalled app would otherwise reload the previous
  // (possibly demo) account's cached data on first launch — token, user
  // prefs and, most visibly, the ContactNameService name caches, which then
  // show the old account's contact names for the new user. Hive lives in
  // the app-support directory, which IS wiped on uninstall, so a missing
  // flag here reliably means "first launch after a fresh install".
  try {
    final installFlags = await Hive.openBox('app_install_flags');
    if (installFlags.get('installed') != true) {
      logger.i('Fresh install detected — clearing stale secure storage');
      await SecurePrefs.clear();
      await installFlags.put('installed', true);
    }
  } catch (e) {
    logger.e('Fresh-install guard failed', e);
  }

  try {
    // ✅ CRITICAL FIX: Parallelize independent operations for faster startup
    await Future.wait([
      // Firebase initialization - skipped on web (no options are configured
      // for the web target and the call never resolves there, which would
      // block runApp entirely).
      if (kIsWeb)
        Future<void>.value()
      else
        Firebase.initializeApp().then((value) {
        logger.i('Firebase initialized successfully');
        // Register the background message handler as early as possible —
        // it must be set before runApp() to reliably catch messages that
        // arrive while the app is backgrounded/terminated.
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
        // Initialize Firebase Analytics after Firebase
        return FirebaseAnalytics.instance
            .setAnalyticsCollectionEnabled(true)
            .then((_) {
              logger.i('Firebase Analytics initialized successfully');
            });
      }),

      // AdMob SDK — failures must never block app startup (mobile only)
      if (kIsWeb)
        Future<void>.value()
      else
        MobileAds.instance
            .initialize()
            .then((_) => logger.i('AdMob initialized successfully'))
            .catchError((Object e) => logger.e('AdMob init failed', e)),

      // App version fetch
      getAppVersion(),

      // Load user preferences (can run in parallel with Firebase)
      SecureStorageKeys().loadUserFromPrefs(),

      // Load boolean values
      SecureStorageKeys().loadeBoolValuePrefes(),

      // Load theme preference
      SecurePrefs.getBoolLighDark(SecureStorageKeys.isLightMode).then((value) {
        isLightModeGlobal = value;
        debugPrint("isLightModeGlobal:$isLightModeGlobal");
      }),
    ]);

    debugPrint("isDemo loaded on app start:$isDemo");

    // Setup dependencies (includes cached config loading)
    await setupDependencies();
    logger.i('Dependencies setup completed');

    // Check for a cold-start incoming-call notification before the widget
    // tree exists at all — see checkColdStartNotification() doc comment.
    // Doing this here (rather than leaving it to FcmService.initialize(),
    // which only runs later from MyApp's post-frame callback) means
    // SplashScreen's own post-frame callback can never race ahead of it.
    await FcmService().checkColdStartNotification();

    logger.i('FCM will be initialized once the app widget is ready');

    logger.i('App initialization completed successfully');
  } catch (e) {
    logger.e('Error initializing application', e);
  }

  // NOTE: runApp() is called by main(), so a bootstrap failure can be
  // surfaced on screen instead of closing the app silently.
}

/// Shown only when app bootstrap throws before the real UI is mounted.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, required this.detail});

  final String error;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1022),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flickpitch could not start',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please screenshot this screen and send it to support.',
                  style: TextStyle(color: Color(0xFFB9BEDC), fontSize: 13),
                ),
                const SizedBox(height: 18),
                SelectableText(
                  error,
                  style: const TextStyle(
                    color: Color(0xFFFF8A8A),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                SelectableText(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF8C93B8),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ Setup FCM handlers when app widget is ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setupFcmWhenReady();
      // ✅ REMOVED: Call notification handling moved to splash screen for better coordination
      // This prevents race conditions between splash navigation and call navigation
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// ✅ Initialize socket services for logged-in users AFTER UI renders
  Future<void> _setupFcmWhenReady() async {
    // ✅ OFFLINE-FIRST: Socket/chat connectivity doesn't depend on FCM at
    // all — start it immediately in parallel rather than waiting on FCM
    // setup to finish first, so an FCM setup failure can't hold up chat.
    final socketInitFuture = _initializeSocketServicesIfLoggedIn();

    try {
      logger.i('🚀 Setting up Firebase Cloud Messaging...');
      await FcmService().initialize();
      logger.i('✅ FCM setup completed');
    } catch (e) {
      logger.e('❌ Error setting up FCM: $e');
    } finally {
      await socketInitFuture;
    }
  }

  /// ✅ CRITICAL FIX: Initialize socket services only if user is logged in
  Future<void> _initializeSocketServicesIfLoggedIn() async {
    try {
      // Check if user is logged in
      final token = await SecurePrefs.getString(SecureStorageKeys.TOKEN);
      final isLoggedIn = token != null && token.isNotEmpty;

      if (isLoggedIn) {
        logger.i('🔄 User logged in - initializing socket services...');

        // Small delay to ensure all setup is complete
        await Future.delayed(Duration(milliseconds: 100));

        // Initialize socket services
        await initializeSocketAfterLogin();

        logger.i('✅ Socket services initialized for logged-in user');
      } else {
        logger.i(
          '📱 User not logged in - socket services will initialize after login',
        );
      }
    } catch (e) {
      logger.e('❌ Error initializing socket services: $e');
      // Don't rethrow - app should continue even if socket init fails
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Update app foreground state for FCM foreground-message handling
    switch (state) {
      case AppLifecycleState.resumed:
        FcmService().setAppForegroundState(true);
        logger.d('📱 App resumed - foreground: true');
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        FcmService().setAppForegroundState(false);
        logger.d('🏠 App paused/inactive - foreground: false');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lock orientation to portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    final lang = Provider.of<LanguageProvider>(context);
    AppString.initStrings(lang); // ✅ initialize all strings with provider

    return AppLifecycleManager(
      child: MaterialApp(
        navigatorKey:
            NavigationHelper.navigatorKey, // ✅ Critical for navigation
        navigatorObservers: [
          NavigationHelper.routeTracker,
          NavigationHelper.pageRouteObserver,
        ],
        debugShowCheckedModeBanner: false,

        title: 'Flickpitch Business',
        theme: ThemeData(
          // Brand seed: every Material 3 default (ripples, chips, switches,
          // progress indicators) now derives from Flickpitch purple instead of
          // white, so new screens inherit the brand without extra styling.
          colorScheme: ColorScheme.fromSeed(
            seedColor: FpBrand.purple,
            primary: FpBrand.purple,
            secondary: FpBrand.purpleSoft,
          ),
          useMaterial3: true,
          // Flat app bars: the chat screens paint their own headers, so a
          // tinted elevation shadow only muddied them.
          appBarTheme: const AppBarTheme(
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            centerTitle: false,
          ),
          // Primary actions: solid brand purple, rounded, no drop shadow.
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: FpBrand.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FpBrand.radiusMd),
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: FpBrand.purple,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FpBrand.radiusMd),
              ),
            ),
          ),
          // Inputs: soft filled fields with a brand focus ring.
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FpBrand.radiusMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FpBrand.radiusMd),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FpBrand.radiusMd),
              borderSide: const BorderSide(color: FpBrand.purple, width: 1.6),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FpBrand.radiusLg),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FpBrand.radiusSm),
            ),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white, // ✅ country picker dialog
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FpBrand.radiusLg),
            ),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
          // Modern scroll behavior
          scrollbarTheme: const ScrollbarThemeData(
            thumbVisibility: WidgetStatePropertyAll(false),
          ),
          // Improved text scaling
          textTheme: const TextTheme().apply(
            fontFamily: AppTypography.fontFamily.poppins,
          ),
        ),
        // Improved scroll behavior for web/desktop
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.unknown,
          },
        ),
        // Accessibility
        shortcuts: WidgetsApp.defaultShortcuts,
        actions: WidgetsApp.defaultActions,
        onGenerateRoute: AppRoutes.generateRoute,
        initialRoute: AppRoutes.splash,
        // Performance optimizations
        builder: (context, child) {
          // Keep the redesign's static tokens in sync with ThemeProvider so the
          // theme picker / light-dark switch actually repaint every screen.
          FpThemeSync.apply(context);

          // Only apply bottom inset padding on Android for 3-button navigation
          final isAndroid =
              Theme.of(context).platform == TargetPlatform.android;
          final bottomInset = isAndroid
              ? MediaQuery.of(context).viewPadding.bottom
              : 0.0;

          return Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) {
              return Directionality(
                textDirection: userTextDirection == 'RTL'
                    ? TextDirection.rtl
                    : TextDirection.ltr,

                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: MediaQuery.of(context).textScaler
                        .clamp(minScaleFactor: 0.8, maxScaleFactor: 1.3),
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      // Dismiss keyboard when tapping anywhere on screen (iOS fix)
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: bottomInset > 0 ? bottomInset : 0,
                      ),
                      child: child!,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
