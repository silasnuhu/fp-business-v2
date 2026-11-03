import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
import 'package:whoxa/featuers/profile/provider/profile_provider.dart';
import 'package:whoxa/featuers/provider/tabbar_provider.dart';
import 'package:whoxa/utils/packages/otp/src/pinput.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class OtpScreen extends StatefulWidget {
  // final String countryCode;
  // final String mobileNum;
  // final String email;
  const OtpScreen({
    super.key,
    // required this.countryCode,
    // required this.mobileNum,
    // required this.email,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  bool isOTPCompleted = false;
  @override
  void initState() {
    // debugPrint(widget.countryCode);
    // debugPrint(widget.mobileNum);
    startTimer();
    super.initState();
  }

  final otpFormKey = GlobalKey<FormState>();

  late Timer otpTimer;
  int currentSeconds = 90;
  void startTimer() {
    otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (currentSeconds == 0) {
        otpTimer.cancel();
        setState(() {
          currentSeconds = 90;
          debugPrint("API_CALL");
        });
      } else {
        setState(() {
          currentSeconds--;
        });
      }
    });
  }

  @override
  void dispose() {
    otpTimer.cancel();
    super.dispose();
  }

  Future<void> apiCall() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.isSelectLoginType == AppString.phone
        ? await auth.loginMobileApi(
          context,
          countryCode: auth.selectedCountrycode,
          phoneNumber: auth.mobilecontroller.text,
          countryFullName: auth.defaultSelectedCountry,
          selectedCountrySortName: auth.defaultCountrySortName,
        )
        : await auth.loginApi(context, auth.emailcontroller.text);
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final defaultPinTheme = PinTheme(
      width: SizeConfig.sizedBoxWidth(45),
      height: SizeConfig.sizedBoxHeight(45),
      textStyle: AppTypography.captionText(
        context,
      ).copyWith(fontSize: SizeConfig.getFontSize(13)),
      decoration: BoxDecoration(
        color: AppColors.transparent,
        border: Border.all(color: AppColors.strokeColor.greyColor),
        borderRadius: BorderRadius.circular(4),
      ),
    );
    final errorPinTheme = PinTheme(
      width: SizeConfig.sizedBoxWidth(45),
      height: SizeConfig.sizedBoxHeight(45),
      textStyle: AppTypography.captionText(
        context,
      ).copyWith(fontSize: SizeConfig.getFontSize(13)),
      decoration: BoxDecoration(
        color: AppColors.transparent,
        border: Border.all(color: AppColors.textColor.textErrorColor1),
        borderRadius: BorderRadius.circular(4),
      ),
    );
    final focusedPinTheme = PinTheme(
      width: SizeConfig.sizedBoxWidth(45),
      height: SizeConfig.sizedBoxHeight(45),
      textStyle: AppTypography.captionText(
        context,
      ).copyWith(fontSize: SizeConfig.getFontSize(13)),
      decoration: BoxDecoration(
        color: AppColors.transparent,
        border: Border.all(color: AppColors.strokeColor.greyColor),
        borderRadius: BorderRadius.circular(4),
      ),
    );
    final submittedPinTheme = PinTheme(
      width: SizeConfig.sizedBoxWidth(45),
      height: SizeConfig.sizedBoxHeight(45),
      textStyle: AppTypography.captionText(
        context,
      ).copyWith(fontSize: SizeConfig.getFontSize(13)),
      decoration: BoxDecoration(
        color: AppColors.transparent,
        border: Border.all(color: AppColors.strokeColor.greyColor),
        borderRadius: BorderRadius.circular(4),
      ),
    );

    return scaffoldPageDesign(
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: systemUI(),
          backgroundColor: AppColors.transparent,
          automaticallyImplyLeading: false,
        ),
        body: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return Form(
              key: otpFormKey,
              child: SingleChildScrollView(
                child: Padding(
                  padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: SizeConfig.height(3)),
                      appDynamicLogo(height: 50),
                      SizedBox(height: SizeConfig.height(7)),
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
                              SizedBox(height: SizeConfig.height(4)),
                              Text(
                                AppString
                                    .otpScreenString
                                    .digitOtpHaseBeenSentTo,
                                style: AppTypography.innerText11(
                                  context,
                                ).copyWith(
                                  color: AppColors.textColor.textGreyColor,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: SizeConfig.height(0.5)),
                              SizedBox(
                                width: SizeConfig.width(90),
                                child: Text(
                                  authProvider.isSelectLoginType ==
                                          AppString.phone
                                      ? authProvider.selectedCountrycode +
                                          authProvider.mobilecontroller.text
                                      : authProvider.emailcontroller.text,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,

                                  style: AppTypography.innerText11(
                                    context,
                                  ).copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(height: SizeConfig.height(3)),
                              if (demoCredential || AppConfig.isDemo)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: AppColors.appPriSecColor.primaryColor
                                        .withValues(alpha: 0.4),
                                  ),
                                  child: Padding(
                                    padding: SizeConfig.getPaddingSymmetric(
                                      vertical: 10,
                                    ),
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding:
                                              SizeConfig.getPaddingSymmetric(
                                                horizontal: 20,
                                              ),
                                          child: Text(
                                            'Note: In this demo version Use the OTP',
                                            style: TextStyle(
                                              fontSize: SizeConfig.getFontSize(
                                                13,
                                              ),
                                              fontWeight: FontWeight.w500,
                                              fontFamily: 'interBold',
                                              color: AppColors.black,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        GestureDetector(
                                          onTap: () {
                                            // Auto-fill OTP with demo value
                                            authProvider.otpController.text =
                                                '123456';
                                            setState(() {
                                              isOTPCompleted = true;
                                              authProvider
                                                      .isOtpValidationTriggered =
                                                  false;
                                            });
                                            snackbarNew(
                                              context,
                                              msg:
                                                  'Demo OTP filled automatically',
                                            );
                                          },
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '123456',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: "interBold",
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.content_copy,
                                                size: 18,
                                                color:
                                                    AppColors
                                                        .appPriSecColor
                                                        .primaryColor,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              SizedBox(height: SizeConfig.height(3)),
                              Pinput(
                                length: 6,
                                showCursor: true,
                                controller: authProvider.otpController,
                                autofocus: false,
                                forceErrorState:
                                    authProvider.isOtpValidationTriggered,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please Enter Otp";
                                  }
                                  return null;
                                },
                                errorText: "Please Enter Otp",
                                errorTextStyle: AppTypography.captionText(
                                  context,
                                ).copyWith(
                                  color: AppColors.textColor.textErrorColor1,
                                ),
                                errorPinTheme: errorPinTheme,
                                defaultPinTheme: defaultPinTheme,
                                focusedPinTheme: focusedPinTheme,
                                submittedPinTheme: submittedPinTheme,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                onChanged: (value) {
                                  debugPrint('val::::::$value');
                                  if (value.length == 6) {
                                    setState(() {
                                      isOTPCompleted = true;
                                    });
                                    if (authProvider.isOtpValidationTriggered) {
                                      setState(() {
                                        authProvider.isOtpValidationTriggered =
                                            false;
                                      });
                                    }
                                  } else {
                                    // While OTP is not 6 digits, keep error triggered
                                    setState(() {
                                      isOTPCompleted = false;
                                    });
                                    if (!authProvider
                                        .isOtpValidationTriggered) {
                                      setState(() {
                                        authProvider.isOtpValidationTriggered =
                                            true;
                                      });
                                    }
                                  }
                                },
                              ),
                              SizedBox(height: SizeConfig.height(1)),
                              Align(
                                alignment: Alignment.centerRight,
                                child:
                                    currentSeconds != 90
                                        ? SizedBox.shrink()
                                        : InkWell(
                                          onTap: () {
                                            if (currentSeconds == 90) {
                                              apiCall();
                                              setState(() {
                                                currentSeconds = 89;
                                                startTimer();
                                                authProvider.otpController
                                                    .clear();
                                              });
                                              snackbarNew(
                                                context,

                                                msg:
                                                    authProvider.isSelectLoginType ==
                                                            AppString.phone
                                                        ? AppString
                                                            .oTPResendonmobilenumber
                                                        : AppString
                                                            .oTPResendonemail,
                                              );
                                            }
                                          },
                                          child: Text(
                                            AppString.otpScreenString.resendOTP,
                                            style: AppTypography.menuText(
                                              context,
                                            ).copyWith(
                                              fontSize: SizeConfig.getFontSize(
                                                11,
                                              ),
                                              color:
                                                  AppColors
                                                      .appPriSecColor
                                                      .primaryColor,
                                            ),
                                          ),
                                        ),
                              ),
                              SizedBox(height: SizeConfig.height(3)),
                              Text(
                                currentSeconds == 90
                                    ? AppString.otpScreenString.resendCodein0130
                                    : currentSeconds < 10
                                    ? "${AppString.otpScreenString.resendCodein000}$currentSeconds"
                                    : "${AppString.otpScreenString.resendCodein0}${currentSeconds ~/ 60}:${(currentSeconds % 60).toString().padLeft(2, '0')}",
                                style: AppTypography.captionText(
                                  context,
                                ).copyWith(
                                  color: AppColors.textColor.textGreyColor,
                                ),
                              ),

                              SizedBox(height: SizeConfig.height(1.5)),
                              Padding(
                                padding: SizeConfig.getPaddingSymmetric(
                                  horizontal: 20,
                                ),
                                child:
                                    !isOTPCompleted
                                        ? customBtn2(
                                          context,
                                          boxShadow: [],
                                          onTap:
                                              authProvider
                                                      .isOtpValidationTriggered
                                                  ? () {
                                                    snackbarNew(
                                                      context,
                                                      msg: "Please enter OTP",
                                                    );
                                                  }
                                                  : null,
                                          color: AppColors.grey.withValues(
                                            alpha: 0.1,
                                          ),
                                          child: Text(
                                            AppString.login,
                                            style: AppTypography.h5(
                                              context,
                                            ).copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.grey.withValues(
                                                alpha: 0.5,
                                              ),
                                            ),
                                          ),
                                        )
                                        : authProvider.isLoadingOtp
                                        ? commonLoading()
                                        : customBtn2(
                                          context,
                                          onTap: () async {
                                            if (authProvider
                                                    .otpController
                                                    .text
                                                    .length <
                                                6) {
                                              setState(() {
                                                authProvider
                                                        .isOtpValidationTriggered =
                                                    true; // Trigger error border
                                              });
                                              return; // Stop further execution
                                            }

                                            // OTP is valid (6 digits)
                                            setState(() {
                                              authProvider
                                                      .isOtpValidationTriggered =
                                                  false;
                                            });
                                            authProvider.noty();
                                            if (otpFormKey.currentState!
                                                .validate()) {
                                              final isSuccess = await authProvider
                                                  .otpVerifyApi(
                                                    context,
                                                    isEmail:
                                                        authProvider.isSelectLoginType ==
                                                                AppString.phone
                                                            ? false
                                                            : true,
                                                    countryCode:
                                                        authProvider
                                                            .selectedCountrycode,
                                                    phoneNumber:
                                                        authProvider
                                                            .mobilecontroller
                                                            .text,
                                                    email:
                                                        authProvider
                                                            .emailcontroller
                                                            .text,
                                                    otp:
                                                        authProvider
                                                            .otpController
                                                            .text
                                                            .trim(),
                                                  );
                                              if (isSuccess &&
                                                  context.mounted) {
                                                // ✅ PERFORMANCE FIX: Read all SecureStorage values in PARALLEL
                                                final storageResults =
                                                    await Future.wait([
                                                      SecurePrefs.getString(
                                                        SecureStorageKeys
                                                            .USER_NAME,
                                                      ),
                                                      SecurePrefs.getString(
                                                        SecureStorageKeys
                                                            .FIRST_NAME,
                                                      ),
                                                      SecurePrefs.getString(
                                                        SecureStorageKeys
                                                            .USER_PROFILE,
                                                      ),
                                                    ]);

                                                String freshUserName =
                                                    storageResults[0] ?? "";
                                                String freshFirstName =
                                                    storageResults[1] ?? "";
                                                String freshUserProfile =
                                                    storageResults[2] ?? "";

                                                debugPrint(
                                                  "userName global:$userName",
                                                );
                                                debugPrint(
                                                  "userName fresh:$freshUserName",
                                                );
                                                debugPrint(
                                                  "firstName fresh:$freshFirstName",
                                                );
                                                debugPrint(
                                                  "userProfile global:$userProfile",
                                                );
                                                debugPrint(
                                                  "userProfile fresh:$freshUserProfile",
                                                );

                                                // ✅ PERFORMANCE FIX: Show demo dialog in background (non-blocking)
                                                if (isDemo && context.mounted) {
                                                  // Show dialog after navigation completes
                                                  Future.microtask(() {
                                                    if (context.mounted) {
                                                      _showDemoAccountDialog(
                                                        context,
                                                      );
                                                    }
                                                  });
                                                }
                                                // Show loader while checking profile and navigating
                                                // This prevents user confusion after demo dialog is dismissed
                                                authProvider.setLoadingOtp(
                                                  true,
                                                );

                                                // Check first_name instead of user_name for new users
                                                if (freshFirstName.isEmpty) {
                                                  debugPrint('1');
                                                  if (!context.mounted) return;
                                                  Navigator.pushNamedAndRemoveUntil(
                                                    context,
                                                    AppRoutes.addinfo,
                                                    (Route<dynamic> route) =>
                                                        false,
                                                  );
                                                } else {
                                                  // TEMP: avatar selection screen removed from new-user login flow for now.
                                                  // Previously, an empty/default profile image routed to AppRoutes.avatarProfile here.
                                                  debugPrint('3');
                                                  if (!context.mounted) return;
                                                  // ✅ PERFORMANCE FIX: Navigate FIRST, then load data in BACKGROUND
                                                  // This eliminates the 3-4 second delay before navigation

                                                  // Capture providers before navigation (context checked above)
                                                  // ignore: use_build_context_synchronously
                                                  final tabbarProvider =
                                                      Provider.of<
                                                        TabbarProvider
                                                      >(context, listen: false);
                                                  // ignore: use_build_context_synchronously
                                                  final profileProvider =
                                                      Provider.of<
                                                        ProfileProvider
                                                      >(context, listen: false);

                                                  tabbarProvider
                                                      .navigateToIndex(0);

                                                  // Navigate immediately - don't wait for API calls
                                                  Navigator.pushNamedAndRemoveUntil(
                                                    context,
                                                    AppRoutes.tabbar,
                                                    (Route<dynamic> route) =>
                                                        false,
                                                  );

                                                  // ✅ PERFORMANCE FIX: Load profile & status data in BACKGROUND (non-blocking)
                                                  Future.microtask(() {
                                                    // Run API calls in parallel
                                                    authProvider
                                                        .userProfileApiGet();
                                                    profileProvider
                                                        .statusGetApi(
                                                          isGetData: true,
                                                        );
                                                  });

                                                  // Initialize contacts in background (already non-blocking)
                                                  _initializeContactsAfterLogin();
                                                }
                                              } else {
                                                if (!mounted) return;
                                                // ignore: use_build_context_synchronously
                                                snackbarNew(
                                                  // ignore: use_build_context_synchronously
                                                  context,
                                                  msg:
                                                      authProvider.errorMessage
                                                          .toString(),
                                                );
                                              }
                                            }
                                            // else {
                                            //   snackbarNew(
                                            //     context,
                                            //     title: AppString.error,
                                            //     msg: "Please enter OTP",
                                            //   );
                                            // }
                                          },
                                          child: Text(
                                            AppString.login,
                                            style: AppTypography.h5(
                                              context,
                                            ).copyWith(
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
                      // Demo OTP Section - Moved outside the card
                      // SizedBox(height: SizeConfig.height(3)),
                      // _buildDemoOTP(authProvider),
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

  // Demo OTP Widget
  // Widget _buildDemoOTP(AuthProvider authProvider) {
  //   return Padding(
  //     padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
  //     child: Stack(
  //       children: [
  //         Container(
  //           width: double.infinity,
  //           decoration: BoxDecoration(
  //             color: AppColors.appPriSecColor.primaryColor,
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               SizedBox(height: SizeConfig.height(1.5)),
  //               Padding(
  //                 padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
  //                 child: Text(
  //                   'For Demo',
  //                   style: TextStyle(
  //                     fontSize: SizeConfig.getFontSize(16),
  //                     fontWeight: FontWeight.w700,
  //                     fontFamily: 'Poppins',
  //                     color: AppColors.white,
  //                   ),
  //                 ),
  //               ),
  //               SizedBox(height: SizeConfig.height(0.8)),
  //               Padding(
  //                 padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
  //                 child: Divider(
  //                   color: AppColors.white.withValues(alpha: 0.3),
  //                   thickness: 1,
  //                 ),
  //               ),
  //               SizedBox(height: SizeConfig.height(1)),
  //               Padding(
  //                 padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
  //                 child: Text(
  //                   'Note: In this demo version Use the OTP',
  //                   style: TextStyle(
  //                     fontSize: SizeConfig.getFontSize(13),
  //                     fontWeight: FontWeight.w500,
  //                     fontFamily: 'Poppins',
  //                     color: AppColors.white,
  //                   ),
  //                 ),
  //               ),
  //               // SizedBox(height: SizeConfig.height(1)),
  //               Padding(
  //                 padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
  //                 child: Text(
  //                   'OTP: 123456',
  //                   style: TextStyle(
  //                     fontSize: SizeConfig.getFontSize(16),
  //                     fontWeight: FontWeight.w700,
  //                     fontFamily: 'Poppins',
  //                     color: AppColors.white,
  //                   ),
  //                 ),
  //               ),
  //               SizedBox(height: SizeConfig.height(1.5)),
  //             ],
  //           ),
  //         ),
  //         Positioned(
  //           top: 10,
  //           right: 15,
  //           child: GestureDetector(
  //             onTap: () {
  //               // Copy the demo OTP to the text field
  //               authProvider.otpController.text = "123456";
  //               setState(() {
  //                 authProvider.isOtpValidationTriggered = false;
  //               });
  //             },
  //             child: Container(
  //               padding: EdgeInsets.all(6),
  //               decoration: BoxDecoration(
  //                 color: AppColors.white.withValues(alpha: 0.2),
  //                 borderRadius: BorderRadius.circular(6),
  //               ),
  //               child: Icon(Icons.copy, color: AppColors.white, size: 18),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  /// Initialize contacts after successful login
  void _initializeContactsAfterLogin() {
    try {
      final contactProvider = Provider.of<ContactListProvider>(
        context,
        listen: false,
      );

      debugPrint('🚀 OTP Screen: Initializing contacts after successful login');

      // Initialize contacts in background (non-blocking)
      Future.microtask(() async {
        try {
          await contactProvider.initializeContacts();
          debugPrint(
            '✅ OTP Screen: Contact initialization completed successfully',
          );
        } catch (e) {
          debugPrint('❌ OTP Screen: Error initializing contacts: $e');
        }
      });
    } catch (e) {
      debugPrint('❌ OTP Screen: Error setting up contact initialization: $e');
    }
  }

  /// Show demo account restrictions dialog
  Future<void> _showDemoAccountDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.bgColor.bg4Color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.appPriSecColor.primaryColor,
                size: 24,
              ),
              SizedBox(width: SizeConfig.width(2)),
              Text(
                AppString.demoAccountTitle,
                style: AppTypography.h3(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              AppString.demoAccountRestrictions,
              style: AppTypography.innerText11(
                context,
              ).copyWith(fontSize: 14, height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                AppString.ok,
                style: AppTypography.h5(context).copyWith(
                  color: AppColors.appPriSecColor.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
