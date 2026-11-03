// ignore_for_file: avoid_print
import 'package:whoxa/featuers/chat/widgets/country_code.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/core/services/device_country_code_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/packages/phone_field/intl_phone_field.dart';
import 'package:whoxa/utils/packages/phone_field/phone_number.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/widgets/global_textfield.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final _loginFormKey = GlobalKey<FormState>();
  bool isPhoneValid = false;
  PhoneNumber? phoneNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getCountryISOFromLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back from background
      getCountryISOFromLocation();
    }
  }

  /// Detects country from GPS location and updates the auth provider.
  /// Uses DeviceCountryCodeService for fallback (+1 US).
  /// Priority: GPS location → Device locale → Fallback (+1)
  Future<String?> getCountryISOFromLocation() async {
    try {
      // Check location permission first
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          debugPrint(
            '📍 Location permission denied, using device-detected fallback',
          );
          return _useDeviceDetectedCountry();
        }
      } else if (permission == LocationPermission.deniedForever) {
        debugPrint(
          '📍 Location permission permanently denied, using device-detected fallback',
        );
        return _useDeviceDetectedCountry();
      }

      // Check if location service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint(
          '📍 Location service disabled, using device-detected fallback',
        );
        return _useDeviceDetectedCountry();
      }

      // Get current position
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
        debugPrint(
          '📍 Could not determine country from GPS, using device-detected fallback',
        );
        return _useDeviceDetectedCountry();
      }

      final newCountry = placemarks.first.isoCountryCode!.toUpperCase();

      // Save to storage
      await SecurePrefs.setString(
        SecureStorageKeys.COUNTRY_SHORT_NAME,
        newCountry,
      );

      // Also update DeviceCountryCodeService for consistency
      final dialCode = getDialCodeFromISO(newCountry);
      if (dialCode.isNotEmpty) {
        await DeviceCountryCodeService.instance.updateCountryCode(
          dialCode.replaceAll('+', ''),
          newCountry,
        );
      }

      if (!mounted) return newCountry;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Update ISO
      authProvider.defaultCountrySortName = newCountry;

      // Convert ISO → Dial Code and update
      authProvider.selectedCountrycode = dialCode;

      // Clear phone number when country changes
      authProvider.mobilecontroller.clear();

      setState(() {
        countryShortName = newCountry;
      });

      debugPrint('📍 Country detected from GPS: $newCountry ($dialCode)');
      return newCountry;
    } catch (e) {
      debugPrint('📍 Error detecting country from GPS: $e');
      return _useDeviceDetectedCountry();
    }
  }

  /// Fallback method - uses device locale when location is not available
  /// This is used when GPS detection fails or location permission is denied
  /// Priority: Device locale → Fallback to +1 (US)
  String? _useDeviceDetectedCountry() {
    if (!mounted) return null;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Try to get country from device locale via DeviceCountryCodeService
    // This was already initialized with locale detection in dependency_injection
    final detectionSource = DeviceCountryCodeService.instance
        .getDetectionSource();
    final detectedIsoCode = DeviceCountryCodeService.instance
        .getDefaultIsoCode();
    final detectedDialCode = DeviceCountryCodeService.instance
        .getDefaultDialCodeWithPlus();

    // Use device-detected country (from locale) if available
    // Only use hardcoded fallback if truly no detection method worked
    if (detectionSource != 'fallback' && detectionSource != 'unknown') {
      authProvider.defaultCountrySortName = detectedIsoCode;
      authProvider.selectedCountrycode = detectedDialCode;

      setState(() {
        countryShortName = detectedIsoCode;
      });

      debugPrint(
        '📍 Location not available, using device locale: $detectedIsoCode ($detectedDialCode) via $detectionSource',
      );
      return detectedIsoCode;
    }

    // True fallback - no detection method worked
    const fallbackIsoCode = 'US';
    const fallbackDialCode = '+1';

    authProvider.defaultCountrySortName = fallbackIsoCode;
    authProvider.selectedCountrycode = fallbackDialCode;

    setState(() {
      countryShortName = fallbackIsoCode;
    });

    debugPrint(
      '📍 No country detection available (source: $detectionSource), using fallback: $fallbackIsoCode ($fallbackDialCode)',
    );
    return fallbackIsoCode;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return scaffoldPageDesign(
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          backgroundColor: AppColors.transparent,
          automaticallyImplyLeading: false,
          systemOverlayStyle: systemUI(),
          elevation: 0,
          scrolledUnderElevation: 0,
          // leading: Padding(
          //   padding: const EdgeInsets.all(15.0),
          //   child: customeBackArrowBalck(context),
          // ),
        ),
        body: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            authProvider.isSelectLoginType = AppString.phone;
            debugPrint("isPhoneAuthEnabled:$isPhoneAuthEnabled");
            debugPrint("isEmailAuthEnabled:$isEmailAuthEnabled");
            authProvider.defaultCountrySortName = countryShortName;
            debugPrint(
              "authProvider.defaultCountrySortName:: ${authProvider.defaultCountrySortName}",
            );
            return Form(
              key: _loginFormKey,
              child: SingleChildScrollView(
                child: Padding(
                  padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: SizeConfig.height(3)),
                      appDynamicLogo(height: 50),
                      SizedBox(height: SizeConfig.height(3)),
                      container(
                        context,
                        child: Padding(
                          padding: SizeConfig.getPadding(20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppString.welcome,
                                    style: AppTypography.h1(context),
                                  ),
                                  SizedBox(width: SizeConfig.width(2)),
                                  SvgPicture.asset(
                                    AppAssets.hand,
                                    height: SizeConfig.sizedBoxHeight(19),
                                  ),
                                ],
                              ),
                              SizedBox(height: SizeConfig.height(1.5)),
                              Text(
                                AppString.hello,
                                textAlign: TextAlign.center,
                                style: AppTypography.h3(context).copyWith(
                                  fontSize: SizeConfig.getFontSize(14),
                                ),
                              ),
                              if (isPhoneAuthEnabled == true &&
                                  isEmailAuthEnabled == true)
                                SizedBox(height: SizeConfig.height(5)),
                              // ======================= login type widget
                              if (isPhoneAuthEnabled == true &&
                                  isEmailAuthEnabled == true)
                                loginType(context, authProvider),
                              // ======================= login type widget
                              SizedBox(height: SizeConfig.height(3)),
                              authProvider.isSelectLoginType == AppString.phone
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        AppString
                                            .loginEmailPhoneString
                                            .mobileNumber,
                                        style: AppTypography.text12(
                                          context,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    )
                                  : SizedBox.shrink(),
                              authProvider.isSelectLoginType == AppString.phone
                                  ? SizedBox(height: SizeConfig.height(0.5))
                                  : SizedBox.shrink(),
                              authProvider.isSelectLoginType == AppString.phone
                                  ? IntlPhoneField(
                                      key: ValueKey(
                                        authProvider.defaultCountrySortName,
                                      ),
                                      dropdownDecoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey.shade300,
                                            width: 1.0,
                                          ),
                                        ),
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.deny(
                                          RegExp(r'[,.\-]'),
                                        ),
                                      ],
                                      dropdownTextStyle:
                                          AppTypography.innerText11(context),
                                      showCountryFlag: false,
                                      showDropdownIcon: true,
                                      dropdownIcon: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 13,
                                      ),
                                      dropdownIconPosition:
                                          IconPosition.trailing,
                                      initialCountryCode:
                                          authProvider.defaultCountrySortName,
                                      initialValue:
                                          authProvider.selectedCountrycode,
                                      onChanged: (number) async {
                                        bool valid = false;

                                        try {
                                          valid = number.isValidNumber();
                                        } catch (e) {
                                          // NumberTooShortException, NumberTooLongException, etc.
                                          valid = false;
                                        }
                                        print(number);
                                        phone = number.completeNumber;
                                        phoneNumber = number;
                                        isPhoneValid = valid;
                                        authProvider.validateInput();
                                      },
                                      onCountryChanged: (value) {
                                        setState(() {
                                          isPhoneValid = false;
                                        });
                                        authProvider.selectedCountrycode =
                                            "+${value.dialCode}";
                                        debugPrint(
                                          authProvider.selectedCountrycode,
                                        );

                                        authProvider.defaultSelectedCountry =
                                            value.name;
                                        authProvider.defaultCountrySortName =
                                            value.code;
                                        countryShortName =
                                            authProvider.defaultCountrySortName;
                                        DeviceCountryCodeService.instance
                                            .updateCountryCode(
                                              value.dialCode,
                                              authProvider
                                                  .defaultCountrySortName,
                                            );
                                        debugPrint(
                                          'Country Name: ${value.name}',
                                        );
                                        debugPrint(
                                          'Default Country Name: ${authProvider.defaultSelectedCountry}',
                                        );
                                        debugPrint(
                                          'Country Code: ${value.dialCode}',
                                        );
                                        debugPrint(
                                          'Country ISO Code: ${value.code}',
                                        );
                                      },

                                      cursorColor: AppColors.black,
                                      autofocus: false,
                                      autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                      style: AppTypography.innerText11(context),
                                      controller: authProvider.mobilecontroller,
                                      keyboardType: TextInputType.number,
                                      flagsButtonPadding:
                                          SizeConfig.getPaddingOnly(left: 5),
                                      decoration: InputDecoration(
                                        fillColor: AppColors.transparent,
                                        filled: true,
                                        counterText: '',
                                        contentPadding:
                                            SizeConfig.getPaddingSymmetric(
                                              vertical: 10,
                                              horizontal: 20,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10.0,
                                          ),
                                          borderSide: BorderSide(
                                            color:
                                                AppColors.strokeColor.greyColor,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10.0,
                                          ),
                                          borderSide: BorderSide(
                                            color:
                                                AppColors.strokeColor.greyColor,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10.0,
                                          ),
                                          borderSide: BorderSide(
                                            color:
                                                AppColors.strokeColor.greyColor,
                                          ),
                                        ),
                                        disabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10.0,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10.0,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppColors
                                                .textColor
                                                .textErrorColor1,
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10.0,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppColors
                                                .textColor
                                                .textErrorColor1,
                                          ),
                                        ),
                                        errorStyle: TextStyle(
                                          color: AppColors
                                              .textColor
                                              .textErrorColor1,
                                          fontSize: SizeConfig.getFontSize(12),
                                        ),
                                      ),
                                      validator: (value) {
                                        authProvider.validateInput(); // Ensure validation is checked on form submit
                                        if (phone == null ||
                                            phone!.isEmpty ||
                                            authProvider
                                                .mobilecontroller
                                                .text
                                                .isEmpty) {
                                          return 'Please Enter Your Valid Number';
                                        }
                                        return null;
                                      },
                                    )
                                  : GlobalTextField1(
                                      lable: AppString.email,
                                      keyboardType: TextInputType.emailAddress,
                                      controller: authProvider.emailcontroller,
                                      style: AppTypography.captionText(context),
                                      style1: AppTypography.h5(context),
                                      hintStyle:
                                          AppTypography.captionText(context)
                                              .copyWith(
                                                color: AppColors
                                                    .textColor
                                                    .textGreyColor,
                                              ),
                                      isEmail: true,
                                      maxLength: 30,
                                      filled: true,
                                      onEditingComplete: () {},
                                      hintText: AppString
                                          .loginEmailPhoneString
                                          .entermail,
                                      context: context,
                                    ),
                              SizedBox(height: SizeConfig.height(1)),

                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  authProvider.isSelectLoginType ==
                                          AppString.phone
                                      ? AppString
                                            .loginEmailPhoneString
                                            .weWillPhone
                                      : AppString
                                            .loginEmailPhoneString
                                            .weWillEmail,
                                  style: AppTypography.menuText(context)
                                      .copyWith(
                                        color:
                                            AppColors.textColor.textGreyColor,
                                      ),
                                ),
                              ),
                              SizedBox(height: SizeConfig.height(5)),
                              Padding(
                                padding: SizeConfig.getPaddingSymmetric(
                                  horizontal: 20,
                                ),
                                child: !isPhoneValid
                                    ? customBtn2(
                                        context,
                                        boxShadow: [],
                                        onTap: isPhoneValid
                                            ? () {
                                                debugPrint(
                                                  'Valid number: ${phoneNumber!.completeNumber}',
                                                );
                                              }
                                            : null,
                                        color: AppColors.grey.withValues(
                                          alpha: 0.1,
                                        ),
                                        child: Text(
                                          AppString
                                              .loginEmailPhoneString
                                              .sendOtp,
                                          style: AppTypography.h5(context)
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.grey
                                                    .withValues(alpha: 0.5),
                                              ),
                                        ),
                                      )
                                    : authProvider.isLoading
                                    ? commonLoading()
                                    : customBtn2(
                                        context,
                                        onTap: () async {
                                          if (!context.mounted) return;
                                          closeKeyboard();
                                          authProvider.otpController.text = '';
                                          if (authProvider.isSelectLoginType ==
                                              AppString.phone) {
                                            if (authProvider
                                                .mobilecontroller
                                                .text
                                                .trim()
                                                .isNotEmpty) {
                                              authProvider.setLoadingOtp(false);
                                              final isSuccess = await authProvider
                                                  .loginMobileApi(
                                                    context,
                                                    countryCode: authProvider
                                                        .selectedCountrycode,
                                                    phoneNumber: authProvider
                                                        .mobilecontroller
                                                        .text,
                                                    countryFullName: authProvider
                                                        .defaultSelectedCountry,
                                                    selectedCountrySortName:
                                                        authProvider
                                                            .defaultCountrySortName,
                                                  );
                                              if (!context.mounted) return;
                                              if (isSuccess) {
                                                debugPrint(
                                                  'Default Country Name: ${authProvider.defaultSelectedCountry}',
                                                );
                                                final msg =
                                                    authProvider.errorMessage!;
                                                snackbarNew(context, msg: msg);
                                                Navigator.pushNamed(
                                                  context,
                                                  AppRoutes.otp,
                                                );
                                              } else {
                                                final msg =
                                                    authProvider.errorMessage!;
                                                snackbarNew(context, msg: msg);
                                              }
                                            } else {
                                              snackbarNew(
                                                context,

                                                msg: AppString
                                                    .pleaseEnterMobilenumber,
                                              );
                                            }
                                          } else {
                                            //   //-------------------------------------------------------------------
                                            //   //-------------------- Email login method API call ---------------------
                                            //   //-------------------------------------------------------------------
                                            if (_loginFormKey.currentState!
                                                .validate()) {
                                              authProvider.setLoadingOtp(false);
                                              final isSuccess =
                                                  await authProvider.loginApi(
                                                    context,
                                                    authProvider
                                                        .emailcontroller
                                                        .text
                                                        .trim(),
                                                  );
                                              if (!context.mounted) return;
                                              if (isSuccess) {
                                                snackbarNew(
                                                  context,

                                                  msg: authProvider.errorMessage
                                                      .toString(),
                                                );
                                                Navigator.pushNamed(
                                                  context,
                                                  AppRoutes.otp,
                                                  //         // MaterialPageRoute(
                                                  //         //   builder:
                                                  //         //       (context) => OtpScreen(
                                                  //         //         countryCode: "",
                                                  //         //         mobileNum: "",
                                                  //         //         email:
                                                  //         //             authProvider
                                                  //         //                 .emailcontroller
                                                  //         //                 .text,
                                                  //         //       ),
                                                  //         // ),
                                                );
                                              } else {
                                                final msg =
                                                    authProvider.errorMessage!;
                                                snackbarNew(context, msg: msg);
                                              }
                                            }
                                          }
                                        },
                                        child: Text(
                                          AppString
                                              .loginEmailPhoneString
                                              .sendOtp,
                                          style: AppTypography.h5(context)
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    ThemeColorPalette.getTextColor(
                                                      AppColors
                                                          .appPriSecColor
                                                          .primaryColor,
                                                    ),
                                                // AppColors
                                                //     .textColor
                                                //     .textBlackColor,
                                              ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Demo Credentials Section - Moved outside the card
                      if (demoCredential || AppConfig.isDemo)
                        Column(
                          children: [
                            SizedBox(height: SizeConfig.height(2)),
                            _buildDemoCredentials(authProvider),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Demo Credentials Widget
  Widget _buildDemoCredentials(AuthProvider authProvider) {
    final code = AppConfig.demoCountryCode;
    final flagCode = "US";
    final countryName = "United States";
    final demoNmuber = AppConfig.demoPhoneNumber;
    return Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.appPriSecColor.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SizeConfig.height(1.5)),
                Padding(
                  padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                  child: Text(
                    'For Demo',
                    style: TextStyle(
                      fontSize: SizeConfig.getFontSize(16),
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      color: ThemeColorPalette.getTextColor(
                        AppColors.appPriSecColor.primaryColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: SizeConfig.height(0.8)),
                Padding(
                  padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                  child: Divider(
                    color: AppColors.white.withValues(alpha: 0.3),
                    thickness: 1,
                  ),
                ),
                SizedBox(height: SizeConfig.height(1)),
                Padding(
                  padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                  child: Text(
                    'Mobile Number: $code $demoNmuber',
                    style: TextStyle(
                      fontSize: SizeConfig.getFontSize(14),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                      color: ThemeColorPalette.getTextColor(
                        AppColors.appPriSecColor.primaryColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: SizeConfig.height(1)),
                Padding(
                  padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                  child: Text(
                    'OTP: 123456',
                    style: TextStyle(
                      fontSize: SizeConfig.getFontSize(14),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                      color: ThemeColorPalette.getTextColor(
                        AppColors.appPriSecColor.primaryColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: SizeConfig.height(1.5)),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 15,
            child: GestureDetector(
              onTap: () {
                // Copy the demo phone number to the text field
                authProvider.selectedCountrycode = code;
                authProvider.mobilecontroller.text = demoNmuber;
                authProvider.defaultCountrySortName = flagCode; // US
                authProvider.defaultSelectedCountry =
                    countryName; // United States
                countryShortName = authProvider.defaultCountrySortName;
                DeviceCountryCodeService.instance.updateCountryCode(
                  code,
                  authProvider.defaultCountrySortName,
                );
                setState(() {
                  isPhoneValid = true;
                });
              },
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.copy,
                  color: ThemeColorPalette.getTextColor(
                    AppColors.appPriSecColor.primaryColor,
                  ),
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget loginType(BuildContext context, AuthProvider authProvider) {
  return Padding(
    padding: SizeConfig.getPaddingSymmetric(horizontal: 35),
    child: Container(
      height: SizeConfig.sizedBoxHeight(43),
      width: SizeConfig.width(MediaQuery.sizeOf(context).width),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.appPriSecColor.primaryColor),
        color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.03),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          InkWell(
            onTap: () {
              authProvider.setLoginType(AppString.phone);
              debugPrint(authProvider.isSelectLoginType);
            },
            child: Text(
              AppString.phone,
              style: AppTypography.buttonText(context).copyWith(
                fontSize: SizeConfig.getFontSize(15),
                color: authProvider.isSelectLoginType == AppString.phone
                    ? AppColors.appPriSecColor.primaryColor
                    : AppColors.textColor.textGreyColor,
              ),
            ),
          ),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(vertical: 10),
            child: VerticalDivider(color: AppColors.strokeColor.greyColor),
          ),
          InkWell(
            onTap: () {
              authProvider.setLoginType(AppString.email);
              debugPrint(authProvider.isSelectLoginType);
            },
            child: Text(
              AppString.email,
              style: AppTypography.buttonText(context).copyWith(
                fontSize: SizeConfig.getFontSize(15),
                color: authProvider.isSelectLoginType == AppString.email
                    ? AppColors.appPriSecColor.primaryColor
                    : AppColors.textColor.textGreyColor,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
