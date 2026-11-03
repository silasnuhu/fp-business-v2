// ignore_for_file: deprecated_member_use, avoid_print
// import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
import 'package:whoxa/featuers/profile/screens/custom_male_female_btn.dart';
import 'package:whoxa/featuers/profile/screens/avatar_selection_screen.dart';
import 'package:whoxa/featuers/provider/tabbar_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/avatar_initials.dart';
import 'package:whoxa/utils/enums.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/gradient_border.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/widgets/global_textfield.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';

class AddInfoScreen extends StatefulWidget {
  const AddInfoScreen({super.key});

  @override
  State<AddInfoScreen> createState() => _AddInfoScreenState();
}

class _AddInfoScreenState extends State<AddInfoScreen> {
  final _addInfoFormKey = GlobalKey<FormState>();
  final userNameKey = GlobalKey<FormFieldState>();
  int? userNameMaxLength = 20;

  @override
  void initState() {
    super.initState();

    // Call reset only ONCE when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        userNameMaxLength = 20;
      });
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.resetUserNameState(); // ← Safe here: called only once
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bgColor.bg4Color,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: SizeConfig.sizedBoxHeight(70),
          flexibleSpace: flexibleSpace(),
          systemOverlayStyle: systemUI(),
          backgroundColor: AppColors.transparent,
          // leading: Padding(
          //   padding: SizeConfig.getPadding(16),
          //   child: customeBackArrowBalck(context),
          // ),
          titleSpacing: 30,
          title: Text(
            AppString.addInfoScreenString.addInfo,
            style: AppTypography.h220(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          shape: Border(
            bottom: BorderSide(color: AppColors.strokeColor.cECECEC),
          ),
        ),
        body: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            debugPrint("isSelectLoginType:${authProvider.isSelectLoginType}");
            debugPrint(
              "userNameController:${authProvider.userNameController.text}",
            );

            return Center(
              child: Form(
                key: _addInfoFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
                        child: Column(
                          children: [
                            //**************************************************
                            //******************* PROFILE IMAGE ***************
                            //**************************************************
                            SizedBox(height: SizeConfig.height(3)),
                            //====================== USERNAME ================================================
                            //====================== USERNAME ================================================
                            // GlobalTextField1(
                            //   controller: authProvider.userNameController,

                            //   contentPadding: SizeConfig.getPaddingSymmetric(
                            //     vertical: 3,
                            //     horizontal: 15,
                            //   ),
                            //   onTap: () {
                            //     authProvider.isCheckuserName = true;
                            //   },
                            //   inputFormatters: [
                            //     FilteringTextInputFormatter.allow(
                            //       RegExp(r'[a-zA-Z0-9._]'),
                            //     ),
                            //   ],
                            //   style: AppTypography.inputPlaceholder(
                            //     context,
                            //   ).copyWith(fontSize: SizeConfig.getFontSize(12)),
                            //   hintStyle: AppTypography.inputPlaceholder(
                            //     context,
                            //   ).copyWith(
                            //     fontSize: SizeConfig.getFontSize(12),
                            //     color: AppColors.textColor.textGreyColor,
                            //   ),

                            //   lable: AppString.addInfoScreenString.userName,
                            //   keyboardType: TextInputType.emailAddress,

                            //   onChanged: (String searchText) {
                            //     authProvider.onUserNameChanged(searchText);
                            //     debugPrint("userID:$userID");
                            //     debugPrint("authToken:$authToken");
                            //   },
                            //   onEditingComplete: () {},
                            //   hintText: AppString.addInfoScreenString.userName,
                            //   context: context,
                            //   maxLines: 1,
                            //   maxLength: 16,
                            //   autovalidateMode:
                            //       AutovalidateMode.onUserInteraction,
                            //   suffixIcon: Builder(
                            //     builder: (_) {
                            //       final trimmed = authProvider.currentUserName;
                            //       if (trimmed.isEmpty) {
                            //         return const SizedBox.shrink();
                            //       }
                            //       switch (authProvider.userNameStatus) {
                            //         case UserNameStatus.loading:
                            //           return Padding(
                            //             padding: EdgeInsets.all(15),
                            //             child: SizedBox(
                            //               height: 16,
                            //               width: 16,
                            //               child: commonLoading(),
                            //             ),
                            //           );
                            //         case UserNameStatus.success:
                            //           return Container(
                            //             margin: const EdgeInsets.all(15),
                            //             child: SvgPicture.asset(
                            //               AppAssets.svgIcons.verify,
                            //               height: SizeConfig.safeHeight(1),
                            //             ),
                            //           );
                            //         case UserNameStatus.error:
                            //           return Container(
                            //             margin: const EdgeInsets.all(15),
                            //             decoration: const BoxDecoration(
                            //               color: Colors.red,
                            //               shape: BoxShape.circle,
                            //             ),
                            //             child: const Icon(
                            //               Icons.close,
                            //               size: 14,
                            //               color: Colors.white,
                            //             ),
                            //           );
                            //         default:
                            //           return const SizedBox.shrink();
                            //       }
                            //     },
                            //   ),

                            //   validator: (value) {
                            //     if (value == null || value.isEmpty) {
                            //       return 'Please enter your user name';
                            //     }

                            //     // Show error if:
                            //     // 1. We have an error message, OR
                            //     // 2. The status is explicitly "error" (more reliable than just string check)
                            //     if (authProvider.userNameStatus ==
                            //             UserNameStatus.error ||
                            //         authProvider.userNameError.isNotEmpty) {
                            //       return authProvider.userNameError.isNotEmpty
                            //           ? authProvider.userNameError
                            //           : 'Username unavailable';
                            //     }

                            //     return null;
                            //   },
                            // ),
                            twoText(
                              context,
                              text1: AppString.addInfoScreenString.userName,
                              text2: "*",
                              style1: AppTypography.innerText12Mediu(
                                context,
                              ).copyWith(fontWeight: FontWeight.w600),
                              style2: AppTypography.h5(context).copyWith(
                                color: AppColors.textColor.textErrorColor1,
                              ),
                              mainAxisAlignment: MainAxisAlignment.start,
                            ),
                            SizedBox(height: SizeConfig.height(0.5)),
                            TextFormField(
                              controller: authProvider.userNameController,
                              onTap: () {
                                authProvider.isCheckuserName = true;
                              },
                              autocorrect: true,
                              enableSuggestions: true,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9._]'),
                                ),
                              ],
                              style: AppTypography.inputPlaceholder(
                                context,
                              ).copyWith(fontSize: SizeConfig.getFontSize(12)),
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,

                              maxLength: userNameMaxLength,
                              onFieldSubmitted: (value) {},
                              onChanged: (String searchText) {
                                authProvider.onUserNameChanged(searchText);
                                debugPrint("userID:$userID");
                                debugPrint("authToken:$authToken");
                              },
                              maxLines: 1,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                counterStyle:
                                    userNameMaxLength != null
                                        ? AppTypography.captionText(
                                          context,
                                        ).copyWith(
                                          color:
                                              AppColors.textColor.textGreyColor,
                                          fontSize: SizeConfig.getFontSize(10),
                                        )
                                        : AppTypography.captionText(
                                          context,
                                        ).copyWith(
                                          color: AppColors.transparent,
                                          fontSize: 0,
                                        ),
                                suffixIcon: Builder(
                                  builder: (_) {
                                    final trimmed =
                                        authProvider.currentUserName;
                                    if (trimmed.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    switch (authProvider.userNameStatus) {
                                      case UserNameStatus.loading:
                                        return Padding(
                                          padding: EdgeInsets.all(15),
                                          child: SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: commonLoading(),
                                          ),
                                        );
                                      case UserNameStatus.success:
                                        return Container(
                                          margin: const EdgeInsets.all(15),
                                          child: SvgPicture.asset(
                                            AppAssets.svgIcons.verify,
                                            height: SizeConfig.safeHeight(1),
                                          ),
                                        );
                                      case UserNameStatus.error:
                                        return Container(
                                          margin: const EdgeInsets.all(15),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        );
                                      default:
                                        return const SizedBox.shrink();
                                    }
                                  },
                                ),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                contentPadding: SizeConfig.getPaddingSymmetric(
                                  vertical: 3,
                                  horizontal: 15,
                                ),
                                fillColor: AppThemeManage.appTheme.bg4BlackGrey,
                                filled: true,
                                hintText:
                                    AppString.addInfoScreenString.userName,
                                hintStyle: AppTypography.inputPlaceholder(
                                  context,
                                ).copyWith(
                                  fontSize: SizeConfig.getFontSize(11),
                                  color: AppColors.textColor.textGreyColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: BorderSide(
                                    color:
                                        AppThemeManage.appTheme.greyBlackGrey,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: BorderSide(
                                    color:
                                        AppThemeManage.appTheme.greyBlackGrey,
                                  ),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: BorderSide.none,
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: BorderSide(
                                    color: AppColors.textColor.textErrorColor1,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: BorderSide(
                                    color: AppColors.textColor.textErrorColor1,
                                  ),
                                ),
                                errorStyle: AppTypography.captionText(
                                  context,
                                ).copyWith(
                                  color: AppColors.textColor.textErrorColor1,
                                ),

                                labelStyle:
                                    AppTypography.captionText(
                                      context,
                                    ).copyWith(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your user name';
                                }

                                // Show error if:
                                // 1. We have an error message, OR
                                // 2. The status is explicitly "error" (more reliable than just string check)
                                if (authProvider.userNameStatus ==
                                        UserNameStatus.error ||
                                    authProvider.userNameError.isNotEmpty) {
                                  return authProvider.userNameError.isNotEmpty
                                      ? authProvider.userNameError
                                      : 'Username unavailable';
                                }

                                return null;
                              },
                            ),
                            SizedBox(height: SizeConfig.height(0.5)),
                            //====================== FIRST NAME ===================================
                            //====================== FIRST NAME ===================================
                            GlobalTextField1(
                              lable2: '*',
                              contentPadding: SizeConfig.getPaddingSymmetric(
                                vertical: 3,
                                horizontal: 15,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z]'),
                                ),
                              ],
                              style: AppTypography.inputPlaceholder(
                                context,
                              ).copyWith(fontSize: SizeConfig.getFontSize(12)),
                              hintStyle: AppTypography.inputPlaceholder(
                                context,
                              ).copyWith(
                                fontSize: SizeConfig.getFontSize(11),
                                color: AppColors.textColor.textGreyColor,
                              ),

                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.sentences,
                              lable: AppString.addInfoScreenString.firstName,
                              controller: authProvider.fNameController,
                              onEditingComplete: () {},
                              hintText: AppString.addInfoScreenString.firstName,
                              context: context,
                              maxLines: 1,
                              maxLength: 10,
                            ),
                            SizedBox(height: SizeConfig.height(0.5)),
                            //====================== LAST NAME =======================================
                            //====================== LAST NAME =======================================
                            GlobalTextField1(
                              lable2: '*',
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z]'),
                                ),
                              ],
                              style: AppTypography.inputPlaceholder(
                                context,
                              ).copyWith(fontSize: SizeConfig.getFontSize(12)),
                              hintStyle: AppTypography.inputPlaceholder(
                                context,
                              ).copyWith(
                                fontSize: SizeConfig.getFontSize(11),
                                color: AppColors.textColor.textGreyColor,
                              ),

                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.sentences,
                              lable: AppString.addInfoScreenString.lastName,
                              controller: authProvider.lNameController,
                              onEditingComplete: () {},
                              hintText: AppString.addInfoScreenString.lastName,
                              context: context,
                              maxLines: 1,
                              maxLength: 10,
                            ),
                            SizedBox(height: SizeConfig.height(0.5)),
                            //====================== MOBILE NUMBER ========================================
                            //====================== MOBILE NUMBER ========================================
                            // isPhoneAuthEnabled
                            //     ? SizedBox.shrink()
                            //     : authProvider.isSelectLoginType ==
                            //         AppString.phone
                            //     ? GlobalTextField1(
                            //       lable: AppString.email,
                            //       keyboardType: TextInputType.emailAddress,
                            //       controller: authProvider.emailcontroller,
                            //       style: AppTypography.captionText(context),
                            //       style1: AppTypography.h5(context),
                            //       hintStyle: AppTypography.captionText(
                            //         context,
                            //       ).copyWith(
                            //         color: AppColors.textColor.textGreyColor,
                            //       ),
                            //       isEmail: true,
                            //       maxLength: 30,
                            //       filled: true,
                            //       onEditingComplete: () {},
                            //       hintText:
                            //           AppString.loginEmailPhoneString.entermail,
                            //       context: context,
                            //     )
                            //     : isEmailAuthEnabled
                            //     ? SizedBox.shrink()
                            //     : GlobalIntlPhoneField(
                            //       initialValue:
                            //           authProvider.selectedCountrycode,
                            //       onCountryChanged: (value) {
                            //         authProvider.selectedCountrycode =
                            //             value.dialCode;
                            //         debugPrint(
                            //           '+${authProvider.selectedCountrycode}',
                            //         );

                            //         authProvider.defaultSelectedCountry =
                            //             value.name;
                            //         authProvider.defaultCountrySortName =
                            //             value.code;
                            //         debugPrint('Country Name: ${value.name}');
                            //         debugPrint(
                            //           'Default Country Name: ${authProvider.defaultSelectedCountry}',
                            //         );
                            //         debugPrint('Country Code: ${value.dialCode}');
                            //         debugPrint('Country ISO Code: ${value.code}');
                            //       },
                            //       onChanged: (number) {
                            //         debugPrint(number);
                            //         phone = number.completeNumber;
                            //         authProvider.validateInput();
                            //       },

                            //       style: AppTypography.inputPlaceholder(
                            //         context,
                            //       ).copyWith(
                            //         fontSize: SizeConfig.getFontSize(12),
                            //       ),
                            //       hintStyle: AppTypography.inputPlaceholder(
                            //         context,
                            //       ).copyWith(
                            //         fontSize: SizeConfig.getFontSize(12),
                            //         color: AppColors.textColor.textGreyColor,
                            //       ),
                            //       lable:
                            //           AppString
                            //               .loginEmailPhoneString
                            //               .mobileNumber,
                            //       controller: authProvider.mobilecontroller,
                            //       onEditingComplete: () {},
                            //       hintText:
                            //           AppString
                            //               .loginEmailPhoneString
                            //               .mobileNumber,
                            //       context: context,
                            //       keyboardType: TextInputType.phone,
                            //       isInvalidNumber: authProvider.isInvalidNumber,
                            //     ),
                            SizedBox(height: SizeConfig.height(0.5)),
                            //====================== GENDER ==============================================
                            //====================== GENDER ==============================================
                            Align(
                              alignment: Alignment.centerLeft,
                              child: twoText(
                                context,
                                mainAxisAlignment: MainAxisAlignment.start,
                                text1: AppString.addInfoScreenString.gender,
                                text2: "*",
                                style1: AppTypography.innerText12Mediu(
                                  context,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            SizedBox(height: SizeConfig.height(1)),
                            Row(
                              children: [
                                MaleFemaleRadioBtn(
                                  onTap: () {
                                    authProvider.setGenderType(
                                      AppString.addInfoScreenString.male,
                                    );
                                  },
                                  maleFemaleTitle: authProvider.isSelected,
                                  matchString:
                                      AppString.addInfoScreenString.male,
                                ),
                                SizedBox(width: SizeConfig.width(3)),
                                MaleFemaleRadioBtn(
                                  onTap: () {
                                    authProvider.setGenderType(
                                      AppString.addInfoScreenString.female,
                                    );
                                  },
                                  maleFemaleTitle: authProvider.isSelected,
                                  matchString:
                                      AppString.addInfoScreenString.female,
                                ),
                              ],
                            ),
                            SizedBox(height: SizeConfig.height(1)),
                            Divider(color: AppColors.bgColor.bg2Color),
                            SizedBox(height: SizeConfig.height(1)),
                          ],
                        ),
                      ),
                      //==================================== CONTACT DETAILS ==============================================
                      //==================================== CONTACT DETAILS ==============================================
                      Padding(
                        padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: AppColors.gradientColor.logoColor
                                .withOpacity(0.30),
                          ),
                          child: Padding(
                            padding: SizeConfig.getPaddingSymmetric(
                              horizontal: 20,
                              vertical: 25,
                            ),
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text:
                                              "${AppString.addInfoScreenString.contactDetails} ",
                                          style: AppTypography.h5(
                                            context,
                                          ).copyWith(
                                            fontWeight: FontWeight.w600,
                                            color:
                                                AppColors.textColor.text3A3333,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              "(${AppString.addInfoScreenString.nonChangeable})",
                                          style: AppTypography.menuText(
                                            context,
                                          ).copyWith(
                                            fontFamily:
                                                AppTypography
                                                    .fontFamily
                                                    .poppins,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                AppColors
                                                    .textColor
                                                    .textGreyColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: SizeConfig.height(3)),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    authProvider.isSelectLoginType ==
                                            AppString.phone
                                        ? AppString.phoneNumber
                                        : AppString.email,
                                    style: AppTypography.captionText(
                                      context,
                                    ).copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textColor.text3A3333,
                                    ),
                                  ),
                                ),
                                SizedBox(height: SizeConfig.height(0.5)),
                                Container(
                                  height: SizeConfig.sizedBoxHeight(45),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: AppColors.bgColor.bgWhite,
                                  ),
                                  child: Padding(
                                    padding: SizeConfig.getPaddingSymmetric(
                                      horizontal: 20,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            authProvider.isSelectLoginType ==
                                                    AppString.phone
                                                ? SvgPicture.asset(
                                                  AppAssets.svgIcons.call,
                                                  height: SizeConfig.safeHeight(
                                                    2.5,
                                                  ),
                                                  colorFilter: ColorFilter.mode(
                                                    AppColors.bgColor.bgBlack,
                                                    BlendMode.srcIn,
                                                  ),
                                                )
                                                : SvgPicture.asset(
                                                  AppAssets.svgIcons.sms,
                                                  height: SizeConfig.safeHeight(
                                                    2.5,
                                                  ),
                                                  colorFilter: ColorFilter.mode(
                                                    AppColors.bgColor.bgBlack,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                            SizedBox(
                                              width: SizeConfig.width(1),
                                            ),
                                            SizedBox(
                                              width: SizeConfig.safeWidth(50),
                                              child: Text(
                                                authProvider.isSelectLoginType ==
                                                        AppString.phone
                                                    ? contrycode + mobileNum
                                                    : email,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    AppTypography.inputPlaceholder(
                                                      context,
                                                    ).copyWith(
                                                      fontSize:
                                                          SizeConfig.getFontSize(
                                                            13,
                                                          ),
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SvgPicture.asset(
                                          AppAssets.svgIcons.verify,
                                          height: SizeConfig.safeHeight(2.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: SizeConfig.height(2.5)),
                                authProvider.isSelectLoginType ==
                                        AppString.phone
                                    ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        AppString.country,
                                        style: AppTypography.captionText(
                                          context,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    )
                                    : SizedBox.shrink(),
                                authProvider.isSelectLoginType ==
                                        AppString.phone
                                    ? SizedBox(height: SizeConfig.height(0.5))
                                    : SizedBox.shrink(),
                                authProvider.isSelectLoginType ==
                                        AppString.phone
                                    ? Container(
                                      height: SizeConfig.sizedBoxHeight(45),
                                      width: SizeConfig.safeWidth(
                                        MediaQuery.sizeOf(context).width,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: AppColors.bgColor.bgWhite,
                                      ),
                                      child: Padding(
                                        padding: SizeConfig.getPaddingSymmetric(
                                          horizontal: 20,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            SvgPicture.asset(
                                              AppAssets.svgIcons.location,
                                              height: SizeConfig.safeHeight(
                                                2.5,
                                              ),
                                              color: AppColors.bgColor.bgBlack,
                                            ),
                                            SizedBox(
                                              width: SizeConfig.width(1),
                                            ),
                                            Text(
                                              authProvider
                                                  .defaultSelectedCountry
                                                  .toString(),
                                              style:
                                                  AppTypography.inputPlaceholder(
                                                    context,
                                                  ).copyWith(
                                                    fontSize:
                                                        SizeConfig.getFontSize(
                                                          13,
                                                        ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    : SizedBox.shrink(),
                                // authProvider.isSelectLoginType ==
                                //         AppString.phone
                                //     ? SizedBox(height: SizeConfig.height(2.5))
                                //     : SizedBox.shrink(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: SizeConfig.height(2.5)),
                      Padding(
                        padding: SizeConfig.getPaddingSymmetric(horizontal: 50),
                        child:
                            authProvider.isUserProfile
                                ? commonLoading()
                                : customBtn2(
                                  context,
                                  onTap: () async {
                                    closeKeyboard();
                                    //====================== phone number flow ======================
                                    //====================== phone number flow ======================
                                    if (authProvider.isSelectLoginType ==
                                        AppString.phone) {
                                      final isFormValid =
                                          _addInfoFormKey.currentState!
                                              .validate();
                                      final isUserNameValid =
                                          authProvider.userNameStatus ==
                                          UserNameStatus.success;
                                      if (isFormValid && isUserNameValid) {
                                        if (authProvider.isSelected.isEmpty) {
                                          snackbarNew(
                                            context,

                                            msg:
                                                AppString
                                                    .pleaseaddyourgendertype,
                                          );
                                        } else {
                                          final success = await authProvider
                                              .userProfileApi(context);

                                          if (!success && context.mounted) {
                                            snackbarNew(
                                              context,

                                              msg:
                                                  authProvider.errorMessage
                                                      .toString(),
                                            );
                                          }
                                          if (success && context.mounted) {
                                            // ✅ CRITICAL FIX: Wait for userProfile API to complete and reload global variables
                                            // Add small delay to ensure SecureStorage is fully updated
                                            await Future.delayed(
                                              const Duration(milliseconds: 100),
                                            );

                                            // ✅ FIX: Get fresh userProfile from SecureStorage to ensure latest value
                                            String? freshUserProfile =
                                                await SecurePrefs.getString(
                                                  SecureStorageKeys
                                                      .USER_PROFILE,
                                                ) ??
                                                "";

                                            debugPrint(
                                              "🔍 AddInfo Phone Flow - userProfile global: '$userProfile'",
                                            );
                                            debugPrint(
                                              "🔍 AddInfo Phone Flow - userProfile fresh: '$freshUserProfile'",
                                            );
                                            debugPrint(
                                              "🔍 AddInfo Phone Flow - isEmpty: ${freshUserProfile.isEmpty}",
                                            );
                                            debugPrint(
                                              "🔍 AddInfo Phone Flow - isDefaultImage: ${freshUserProfile == "${ApiEndpoints.socketUrl}/uploads/not-found-images/profile-image.png"}",
                                            );

                                            // TEMP: avatar selection screen removed from new-user login flow
                                            // for now. Previously an empty/default profile image routed to
                                            // AppRoutes.avatarProfile here; now new users go straight to the app.
                                            {
                                              if (!context.mounted) return;
                                              Provider.of<TabbarProvider>(
                                                context,
                                                listen: false,
                                              ).navigateToIndex(0);

                                              // Initialize contacts after successful login
                                              try {
                                                final contactProvider =
                                                    Provider.of<
                                                      ContactListProvider
                                                    >(context, listen: false);
                                                debugPrint(
                                                  '🚀 AddInfo Screen: Initializing contacts after successful login',
                                                );
                                                Future.microtask(() async {
                                                  try {
                                                    await contactProvider
                                                        .initializeContacts();
                                                    debugPrint(
                                                      '✅ AddInfo Screen: Contact initialization completed successfully',
                                                    );
                                                  } catch (e) {
                                                    debugPrint(
                                                      '❌ AddInfo Screen: Error initializing contacts: $e',
                                                    );
                                                  }
                                                });
                                              } catch (e) {
                                                debugPrint(
                                                  '❌ AddInfo Screen: Error setting up contact initialization: $e',
                                                );
                                              }

                                              if (!context.mounted) return;
                                              Navigator.pushNamedAndRemoveUntil(
                                                context,
                                                AppRoutes.tabbar,
                                                (Route<dynamic> route) => false,
                                              );
                                            }
                                          }
                                        }
                                      } else {
                                        if (authProvider.userNameStatus !=
                                            UserNameStatus.success) {
                                          snackbarNew(
                                            context,
                                            msg:
                                                authProvider
                                                        .userNameError
                                                        .isNotEmpty
                                                    ? authProvider.userNameError
                                                    : 'Please enter a valid username',
                                          );
                                        }
                                        // authProvider.onUserNameChanged("");
                                      }
                                    } else {
                                      //====================== Email flow ======================
                                      //====================== Email flow ======================
                                      if (_addInfoFormKey.currentState!
                                          .validate()) {
                                        if (authProvider.mobilecontroller.text
                                            .trim()
                                            .isEmpty) {
                                          snackbarNew(
                                            context,

                                            msg:
                                                AppString
                                                    .pleaseEnterMobilenumber,
                                          );
                                        } else if (authProvider
                                            .isSelected
                                            .isEmpty) {
                                          snackbarNew(
                                            context,

                                            msg:
                                                AppString
                                                    .pleaseaddyourgendertype,
                                          );
                                        } else {
                                          final success = await authProvider
                                              .userProfileApi(context);
                                          if (!success && context.mounted) {
                                            snackbarNew(
                                              context,

                                              msg:
                                                  authProvider.errorMessage
                                                      .toString(),
                                            );
                                          }
                                          if (success && context.mounted) {
                                            // ✅ CRITICAL FIX: Wait for userProfile API to complete and reload global variables
                                            // Add small delay to ensure SecureStorage is fully updated
                                            await Future.delayed(
                                              const Duration(milliseconds: 100),
                                            );

                                            // ✅ FIX: Get fresh userProfile from SecureStorage to ensure latest value
                                            String? freshUserProfile =
                                                await SecurePrefs.getString(
                                                  SecureStorageKeys
                                                      .USER_PROFILE,
                                                ) ??
                                                "";

                                            debugPrint(
                                              "🔍 AddInfo Email Flow - userProfile global: '$userProfile'",
                                            );
                                            debugPrint(
                                              "🔍 AddInfo Email Flow - userProfile fresh: '$freshUserProfile'",
                                            );
                                            debugPrint(
                                              "🔍 AddInfo Email Flow - isEmpty: ${freshUserProfile.isEmpty}",
                                            );
                                            debugPrint(
                                              "🔍 AddInfo Email Flow - isDefaultImage: ${freshUserProfile == "${ApiEndpoints.socketUrl}/uploads/not-found-images/profile-image.png"}",
                                            );

                                            // TEMP: avatar selection screen removed from new-user login flow
                                            // for now. Previously an empty/default profile image routed to
                                            // AppRoutes.avatarProfile here; now new users go straight to the app.
                                            {
                                              if (!context.mounted) return;
                                              Provider.of<TabbarProvider>(
                                                context,
                                                listen: false,
                                              ).navigateToIndex(0);

                                              // Initialize contacts after successful login
                                              try {
                                                final contactProvider =
                                                    Provider.of<
                                                      ContactListProvider
                                                    >(context, listen: false);
                                                debugPrint(
                                                  '🚀 AddInfo Screen: Initializing contacts after successful login (email flow)',
                                                );
                                                Future.microtask(() async {
                                                  try {
                                                    await contactProvider
                                                        .initializeContacts();
                                                    debugPrint(
                                                      '✅ AddInfo Screen: Contact initialization completed successfully (email flow)',
                                                    );
                                                  } catch (e) {
                                                    debugPrint(
                                                      '❌ AddInfo Screen: Error initializing contacts (email flow): $e',
                                                    );
                                                  }
                                                });
                                              } catch (e) {
                                                debugPrint(
                                                  '❌ AddInfo Screen: Error setting up contact initialization (email flow): $e',
                                                );
                                              }

                                              if (!context.mounted) return;
                                              Navigator.pushNamedAndRemoveUntil(
                                                context,
                                                AppRoutes.tabbar,
                                                (Route<dynamic> route) => false,
                                              );
                                            }
                                          }
                                        }
                                      }
                                    }
                                  },
                                  child: Text(
                                    AppString.continues,
                                    style: AppTypography.h5(context).copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textColor.textBlackColor,
                                    ),
                                  ),
                                ),
                      ),
                      SizedBox(height: SizeConfig.height(3)),
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
}

Widget _buildLetterAvatar(AuthProvider authProvider) {
  final first = authProvider.fNameController.text.trim();
  final last = authProvider.lNameController.text.trim();
  final String name = [first, last].where((p) => p.isNotEmpty).join(' ');
  final String initials = avatarInitials(name);

  return Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      color: AppColors.textColor.textDarkGray,
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.textColor.textWhiteColor,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
      ),
    ),
  );
}

Widget profileImageAddInfo(BuildContext context, AuthProvider authProvider) {
  return InkWell(
    onTap: () {
      bottomSheetAddInfo(context, authProvider);
    },
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgColor.bgWhite,
            borderRadius: BorderRadius.circular(120),
            border: Border.all(color: AppColors.bgColor.bgWhite),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, 2),
                spreadRadius: 0,
                color: AppColors.shadowColor.c000000.withValues(alpha: 0.45),
              ),
            ],
          ),
          child: Padding(
            padding: SizeConfig.getPadding(2.5),
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: AppColors.bgColor.bgWhite,
                borderRadius: BorderRadius.circular(80),
                border: GradientBoxBorder(
                  gradient: AppColors.gradientColor.gradientColor,
                  width: 3,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(80),
                child:
                    authProvider.image != null
                        ? Image.file(
                          authProvider.image!,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                        )
                        : authProvider.selectedAvatar != null
                        ? Image.network(
                          authProvider.selectedAvatar!.avatarMedia ?? '',
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildLetterAvatar(authProvider);
                          },
                        )
                        : _buildLetterAvatar(authProvider),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 5,
          right: 5,
          child: InkWell(
            onTap: () {
              bottomSheetAddInfo(context, authProvider);
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.appPriSecColor.secondaryColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: SizeConfig.getPadding(1.2),
                child: Container(
                  height: 12,
                  width: 12,
                  decoration: BoxDecoration(
                    color: AppColors.bgColor.bgWhite,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: SizeConfig.getPadding(2.5),
                    child: SvgPicture.asset(
                      AppAssets.svgIcons.addSvg,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future bottomSheetAddInfo(BuildContext context, AuthProvider authProvider) {
  return bottomSheetGobal(
    context,
    bottomsheetHeight: SizeConfig.safeHeight(35),
    title: AppString.settingStrigs.profilePhoto,
    child: Column(
      children: [
        SizedBox(height: SizeConfig.height(3)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            bottomContainerAddInfo(
              context,
              title: AppString.settingStrigs.camera,
              img: AppAssets.svgIcons.camera,
              onTap: () {
                authProvider.getImageFromCamera();
                Navigator.pop(context);
              },
            ),
            bottomContainerAddInfo(
              context,
              title: AppString.settingStrigs.gellery,
              img: AppAssets.svgIcons.gellery,
              onTap: () {
                authProvider.getImageFromGallery();
                Navigator.pop(context);
              },
            ),
          ],
        ),
        SizedBox(height: SizeConfig.height(3)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            bottomContainerAddInfo(
              context,
              title: AppString.settingStrigs.selectAvatar,
              img: AppAssets.svgIcons.addSvg,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AvatarSelectionScreen(),
                  ),
                );
              },
            ),
            bottomContainerAddInfo(
              context,
              title: AppString.settingStrigs.delete,
              img: AppAssets.svgIcons.trash,
              onTap: () {
                authProvider.clearImageSelection();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ],
    ),
  );
}

Widget bottomContainerAddInfo(
  BuildContext context, {
  required String title,
  required String img,
  required Function() onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.opacityColor.opacitySecColor,
          ),
          child: Padding(
            padding: SizeConfig.getPadding(10),
            child: Center(child: SvgPicture.asset(img, height: 20)),
          ),
        ),
        SizedBox(height: SizeConfig.height(0.8)),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.captionText(
            context,
          ).copyWith(fontSize: SizeConfig.getFontSize(11)),
        ),
      ],
    ),
  );
}
