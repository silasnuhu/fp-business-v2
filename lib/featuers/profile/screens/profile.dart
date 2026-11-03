// ignore_for_file: avoid_print, deprecated_member_use, use_build_context_synchronously
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/avatar_initials.dart';
import 'package:whoxa/utils/enums.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/widgets/global_textfield.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<void> authProvider;
  final _profileFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    debugPrint("authToken:$authToken");
    Future.microtask(() {
      authProvider =
          Provider.of<AuthProvider>(
            context,
            listen: false,
          ).userProfileApiGet(context: context);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.bg4BlackColor,
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isGetProfile && !authProvider.hasLoadedOnce) {
            return profileLoader(context);
          }
          if (authProvider.errorMessage != null &&
              !authProvider.hasLoadedOnce) {
            return Center(
              child:
                  authProvider.isInternetIssue
                      ? SvgPicture.asset(
                        AppAssets.svgIcons.internet,
                        colorFilter: ColorFilter.mode(
                          AppColors.appPriSecColor.primaryColor,
                          BlendMode.srcIn,
                        ),
                      )
                      : Text(
                        authProvider.errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTypography.buttonText(
                          context,
                        ).copyWith(color: AppColors.textColor.textErrorColor1),
                      ),
            );
          }
          return Form(
            key: _profileFormKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        profileWidget2(
                          context,
                          isBackArrow: true,
                          title: AppString.settingStrigs.profile,
                          profileChild: profileImage(context, authProvider),
                          isEditShow: true,
                        ),
                        SizedBox(height: SizeConfig.height(5)),
                        //**************************************************
                        //******************* USER NAME ******************
                        //**************************************************
                        Padding(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 30,
                          ),
                          child: GlobalTextField1(
                            lable2: "*",
                            isOnlyRead: true,
                            // onTap: () {
                            //   authProvider.isCheckuserName = true;
                            // }, //as per request it is not editable date:18/08/2025
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9._]'),
                              ),
                            ],
                            lable: AppString.addInfoScreenString.userName,
                            keyboardType: TextInputType.emailAddress,
                            style: AppTypography.inputPlaceholder(
                              context,
                            ).copyWith(fontSize: SizeConfig.getFontSize(12)),
                            hintStyle: AppTypography.inputPlaceholder(
                              context,
                            ).copyWith(
                              fontSize: SizeConfig.getFontSize(12),
                              color: AppColors.textColor.textGreyColor,
                            ),
                            onChanged: (String searchText) {
                              authProvider.onUserNameChanged(searchText);
                              debugPrint("userID:$userID");
                              debugPrint("authToken:$authToken");
                            },
                            controller: authProvider.userNameController,
                            onEditingComplete: () {},
                            maxLines: 1,
                            maxLength: 20,
                            suffixIcon: Builder(
                              builder: (_) {
                                switch (authProvider.userNameStatus) {
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
                            hintText: AppString.addInfoScreenString.userName,
                            context: context,
                          ),
                        ),
                        SizedBox(height: SizeConfig.height(0.5)),
                        //**************************************************
                        //****************** FIRST NAME ******************
                        //**************************************************
                        Padding(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 30,
                          ),
                          child: GlobalTextField1(
                            lable: AppString.addInfoScreenString.firstName,
                            lable2: "*",
                            keyboardType: TextInputType.name,
                            style: AppTypography.inputPlaceholder(
                              context,
                            ).copyWith(fontSize: SizeConfig.getFontSize(12)),
                            hintStyle: AppTypography.inputPlaceholder(
                              context,
                            ).copyWith(
                              fontSize: SizeConfig.getFontSize(12),
                              color: AppColors.textColor.textGreyColor,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            controller: authProvider.fNameController,
                            onEditingComplete: () {},
                            hintText: AppString.addInfoScreenString.firstName,
                            context: context,
                            maxLength: 10,
                          ),
                        ),
                        SizedBox(height: SizeConfig.height(0.5)),
                        //**************************************************
                        //****************** LAST NAME ******************
                        //**************************************************
                        Padding(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 30,
                          ),
                          child: GlobalTextField1(
                            lable: AppString.addInfoScreenString.lastName,
                            lable2: "*",
                            keyboardType: TextInputType.name,
                            style: AppTypography.inputPlaceholder(
                              context,
                            ).copyWith(fontSize: SizeConfig.getFontSize(12)),
                            hintStyle: AppTypography.inputPlaceholder(
                              context,
                            ).copyWith(
                              fontSize: SizeConfig.getFontSize(12),
                              color: AppColors.textColor.textGreyColor,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            controller: authProvider.lNameController,
                            onEditingComplete: () {},
                            hintText: AppString.addInfoScreenString.lastName,
                            context: context,
                            maxLength: 10,
                          ),
                        ),
                        SizedBox(height: SizeConfig.height(0.5)),
                        //**************************************************
                        //****************** PHONE NUMBER ******************
                        //**************************************************
                        isEmailAuthEnabled
                            ? SizedBox.shrink()
                            : authProvider.isSelectLoginType != AppString.phone
                            ? Padding(
                              padding: SizeConfig.getPaddingSymmetric(
                                horizontal: 30,
                              ),
                              child: twoText(
                                context,
                                mainAxisAlignment: MainAxisAlignment.start,
                                text1:
                                    AppString
                                        .loginEmailPhoneString
                                        .mobileNumber,
                                size: SizeConfig.getFontSize(12),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                            : SizedBox.shrink(),
                        // isEmailAuthEnabled
                        //     ? SizedBox.shrink()
                        //     : authProvider.isSelectLoginType != AppString.phone
                        //     ? SizedBox(height: SizeConfig.height(1))
                        //     : SizedBox.shrink(),
                        // isEmailAuthEnabled
                        //     ? SizedBox.shrink()
                        //     : authProvider.isSelectLoginType != AppString.phone
                        //     ? Padding(
                        //       padding: SizeConfig.getPaddingSymmetric(
                        //         horizontal: 30,
                        //       ),
                        //       child: IntlPhoneField(
                        //         dropdownDecoration: BoxDecoration(
                        //           border: Border(
                        //             right: BorderSide(
                        //               color: Colors.grey.shade300,
                        //               width: 1.0,
                        //             ),
                        //           ),
                        //         ),
                        //         dropdownTextStyle:
                        //             AppTypography.inputPlaceholder(
                        //               context,
                        //             ).copyWith(
                        //               fontSize: SizeConfig.getFontSize(14),
                        //             ),
                        //         showCountryFlag: false,
                        //         showDropdownIcon: true,
                        //         dropdownIcon: Icon(
                        //           Icons.keyboard_arrow_down_rounded,
                        //           size: 13,
                        //         ),
                        //         dropdownIconPosition: IconPosition.trailing,
                        //         initialValue: authProvider.selectedCountrycode,
                        //         onCountryChanged: (value) {
                        //           authProvider.selectedCountrycode =
                        //               "+${value.dialCode}";
                        //           debugPrint(
                        //             '+${authProvider.selectedCountrycode}',
                        //           );

                        //           authProvider.defaultSelectedCountry =
                        //               value.name;
                        //           debugPrint('Country Name: ${value.name}');
                        //           debugPrint(
                        //             'Default Country Name: ${authProvider.defaultSelectedCountry}',
                        //           );
                        //           debugPrint('Country Code: ${value.dialCode}');
                        //           debugPrint('Country ISO Code: ${value.code}');
                        //         },
                        //         onChanged: (number) {
                        //           debugPrint(number.completeNumber);
                        //           phone = number.completeNumber;
                        //           authProvider.validateInput();
                        //         },
                        //         cursorColor: AppColors.black,
                        //         autofocus: false,
                        //         autovalidateMode:
                        //             AutovalidateMode.onUserInteraction,
                        //         style: AppTypography.inputPlaceholder(
                        //           context,
                        //         ).copyWith(
                        //           fontSize: SizeConfig.getFontSize(12),
                        //         ),
                        //         controller: authProvider.mobilecontroller,
                        //         keyboardType: TextInputType.number,
                        //         flagsButtonPadding: SizeConfig.getPaddingOnly(
                        //           left: 5,
                        //         ),
                        //         decoration: InputDecoration(
                        //           fillColor: AppColors.transparent,
                        //           filled: true,
                        //           counterText: '',
                        //           contentPadding:
                        //               SizeConfig.getPaddingSymmetric(
                        //                 vertical: 10,
                        //                 horizontal: 20,
                        //               ),
                        //           border: OutlineInputBorder(
                        //             borderRadius: BorderRadius.circular(10.0),
                        //             borderSide: BorderSide(
                        //               color: AppColors.strokeColor.greyColor,
                        //             ),
                        //           ),
                        //           focusedBorder: OutlineInputBorder(
                        //             borderRadius: BorderRadius.circular(10.0),
                        //             borderSide: BorderSide(
                        //               color: AppColors.strokeColor.greyColor,
                        //             ),
                        //           ),
                        //           enabledBorder: OutlineInputBorder(
                        //             borderRadius: BorderRadius.circular(10.0),
                        //             borderSide: BorderSide(
                        //               color: AppColors.strokeColor.greyColor,
                        //             ),
                        //           ),
                        //           disabledBorder: OutlineInputBorder(
                        //             borderRadius: BorderRadius.circular(10.0),
                        //             borderSide: BorderSide.none,
                        //           ),
                        //           errorBorder: OutlineInputBorder(
                        //             borderRadius: BorderRadius.circular(10.0),
                        //             borderSide: BorderSide(
                        //               color:
                        //                   AppColors.textColor.textErrorColor1,
                        //             ),
                        //           ),
                        //           focusedErrorBorder: OutlineInputBorder(
                        //             borderRadius: BorderRadius.circular(10.0),
                        //             borderSide: BorderSide(
                        //               color:
                        //                   AppColors.textColor.textErrorColor1,
                        //             ),
                        //           ),
                        //           errorStyle: TextStyle(
                        //             color: AppColors.textColor.textErrorColor1,
                        //             fontSize: SizeConfig.getFontSize(12),
                        //           ),
                        //         ),
                        //         validator: (value) {
                        //           authProvider
                        //               .validateInput(); // Ensure validation is checked on form submit
                        //           if (phone == null ||
                        //               phone!.isEmpty ||
                        //               authProvider
                        //                   .mobilecontroller
                        //                   .text
                        //                   .isEmpty) {
                        //             return 'Please Enter Your Valid Number';
                        //           }
                        //           return null;
                        //         },
                        //       ),
                        //     )
                        //     //**************************************************
                        //     //****************** EMAIL ADDRESS ******************
                        //     //**************************************************
                        //     : isPhoneAuthEnabled
                        //     ? SizedBox.shrink()
                        //     : Padding(
                        //       padding: SizeConfig.getPaddingSymmetric(
                        //         horizontal: 30,
                        //       ),
                        //       child: GlobalTextField1(
                        //         lable: AppString.email,
                        //         lable2: "*",
                        //         controller: authProvider.emailcontroller,
                        //         isEmail: true,
                        //         keyboardType: TextInputType.emailAddress,
                        //         style: AppTypography.inputPlaceholder(
                        //           context,
                        //         ).copyWith(
                        //           fontSize: SizeConfig.getFontSize(12),
                        //         ),
                        //         hintStyle: AppTypography.inputPlaceholder(
                        //           context,
                        //         ).copyWith(
                        //           fontSize: SizeConfig.getFontSize(12),
                        //           color: AppColors.textColor.textGreyColor,
                        //         ),
                        //         textCapitalization:
                        //             TextCapitalization.sentences,
                        //         filled: true,
                        //         onEditingComplete: () {},
                        //         hintText:
                        //             AppString.loginEmailPhoneString.entermail,
                        //         context: context,
                        //         maxLength: 50,
                        //       ),
                        //     ),
                        // isPhoneAuthEnabled
                        //     ? SizedBox.shrink()
                        //     : SizedBox(height: SizeConfig.height(0.5)),
                        //**************************************************
                        //****************** GENDER ******************
                        //**************************************************
                        /* commented for now as per request date: 18/08/2025
                        Padding(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 30,
                          ),
                          child: Align(
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
                        ),
                        SizedBox(height: SizeConfig.height(1)),
                        Padding(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 40,
                          ),
                          child: Row(
                            children: [
                              MaleFemaleRadioBtn(
                                onTap: () {
                                  authProvider.setGenderType(
                                    AppString.addInfoScreenString.male,
                                  );
                                },
                                maleFemaleTitle: authProvider.isSelected,
                                matchString: AppString.addInfoScreenString.male,
                              ),
                              SizedBox(width: SizeConfig.width(8)),
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
                        ),

                        SizedBox(height: SizeConfig.height(2)),
                        */
                        Padding(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 25,
                          ),
                          child: Divider(
                            color: AppThemeManage.appTheme.greyBlackGrey,
                          ),
                        ),
                        SizedBox(height: SizeConfig.height(2)),
                        //**************************************************
                        //****************** CONTACT DETAIL ******************
                        //**************************************************
                        Padding(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 20,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient:
                                  AppThemeManage.appTheme.primSecoOppcaity,
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
                                            style: AppTypography.innerText14(
                                              context,
                                            ).copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                "(${AppString.addInfoScreenString.nonChangeable})",
                                            style: AppTypography.innerText10(
                                              context,
                                            ).copyWith(
                                              fontSize: 10,
                                              color:
                                                  AppColors
                                                      .textColor
                                                      .textDarkGray,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: SizeConfig.height(3)),
                                  Align(
                                    alignment:
                                        AppDirectionality
                                            .appDirectionAlign
                                            .alignmentLeftRight,
                                    child: Text(
                                      authProvider.isSelectLoginType ==
                                              AppString.phone
                                          ? AppString.phoneNumber
                                          : AppString.email,
                                      style: AppTypography.innerText12Mediu(
                                        context,
                                      ).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  SizedBox(height: SizeConfig.height(1)),
                                  //**************************************************
                                  //****************** EMAIL OR PHONE NUMBER ******************
                                  //**************************************************
                                  contatsDetailContainer(
                                    context,
                                    img:
                                        authProvider.isSelectLoginType ==
                                                AppString.phone
                                            ? AppAssets.svgIcons.call
                                            : AppAssets.svgIcons.sms,
                                    title:
                                        authProvider.isSelectLoginType ==
                                                AppString.phone
                                            ? authProvider.selectedCountrycode +
                                                authProvider
                                                    .mobilecontroller
                                                    .text
                                            : authProvider.emailcontroller.text,
                                  ),
                                  SizedBox(height: SizeConfig.height(2)),
                                  Align(
                                    alignment:
                                        AppDirectionality
                                            .appDirectionAlign
                                            .alignmentLeftRight,
                                    child: Text(
                                      AppString.country,
                                      style: AppTypography.innerText12Mediu(
                                        context,
                                      ).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  SizedBox(height: SizeConfig.height(0.5)),
                                  //**************************************************
                                  //****************** COUNTRY NAME ******************
                                  //**************************************************
                                  Container(
                                    height: SizeConfig.safeHeight(6.5),
                                    width: SizeConfig.width(
                                      MediaQuery.sizeOf(context).width,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color:
                                          AppThemeManage.appTheme.traprentBg4,
                                      border: Border.all(
                                        color:
                                            AppThemeManage.appTheme.transprent,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: SizeConfig.getPaddingSymmetric(
                                        horizontal: 20,
                                      ),
                                      child: Row(
                                        children: [
                                          SvgPicture.asset(
                                            AppAssets.svgIcons.location,
                                            height: SizeConfig.safeHeight(2.5),
                                            color:
                                                AppThemeManage
                                                    .appTheme
                                                    .darkWhiteColor,
                                          ),
                                          SizedBox(
                                            width: SizeConfig.width(2.5),
                                          ),
                                          Text(
                                            authProvider.defaultSelectedCountry,

                                            style: AppTypography.innerText11(
                                              context,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  authProvider.isSelectLoginType ==
                                          AppString.phone
                                      ? SizedBox(height: SizeConfig.height(2.5))
                                      : SizedBox.shrink(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                //**************************************************
                //************************UPDATE BUTTON ************
                //**************************************************
                Padding(
                  padding: SizeConfig.getPaddingSymmetric(
                    horizontal: 65,
                    vertical: 15,
                  ).copyWith(
                    bottom: 15 + MediaQuery.of(context).padding.bottom,
                  ),
                  child:
                      authProvider.isUserProfile
                          ? commonLoading()
                          : customBtn2(
                            context,
                            onTap: () async {
                              if (_profileFormKey.currentState!.validate()) {
                                final success = await authProvider
                                    .userProfileApi(context);

                                if (success) {
                                  final msg =
                                      authProvider.errorMessage.toString();
                                  if (!context.mounted) return;
                                  snackbarNew(context, msg: msg);
                                } else {
                                  final msg =
                                      authProvider.errorMessage.toString();
                                  if (!context.mounted) return;
                                  snackbarNew(context, msg: msg);
                                }
                              }
                            },
                            child: Text(
                              AppString.submit,
                              style: AppTypography.innerText12Mediu(
                                context,
                              ).copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: SizeConfig.getFontSize(14),
                                color: ThemeColorPalette.getTextColor(
                                  AppColors.appPriSecColor.primaryColor,
                                ), //AppColors.textColor.textBlackColor,
                              ),
                            ),
                          ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget contatsDetailContainer(
  BuildContext context, {
  required String img,
  required String title,
}) {
  return Container(
    height: SizeConfig.safeHeight(6.5),
    width: SizeConfig.screenWidth,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: AppThemeManage.appTheme.traprentBg4,
      border: Border.all(color: AppThemeManage.appTheme.transprent),
    ),
    child: Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                img,
                height: SizeConfig.safeHeight(2.5),
                color: AppThemeManage.appTheme.darkWhiteColor,
              ),
              SizedBox(width: SizeConfig.width(2.5)),
              Text(
                title,
                style: AppTypography.innerText11(
                  context,
                ).copyWith(color: AppThemeManage.appTheme.textColor),
              ),
            ],
          ),
          SvgPicture.asset(AppAssets.svgIcons.verify, height: 18),
        ],
      ),
    ),
  );
}

Widget profileImage(BuildContext context, AuthProvider authProvider) {
  return Consumer<AuthProvider>(
    builder: (context, authProvider, _) {
      // Check if the profile image URL is the "not-found" URL
      bool hasValidProfileUrl =
          authProvider.profileImageUrl != null &&
          authProvider.profileImageUrl!.isNotEmpty &&
          authProvider.profileImageUrl != kNotFoundProfileImageUrl;

      return InkWell(
        onTap: () {
          bottomSheetDesigin(context, authProvider);
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgColor.bgWhite,
            borderRadius: BorderRadius.circular(130),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child:
                authProvider.image != null
                    ? Image.file(
                      authProvider.image!,
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                    )
                    : authProvider.selectedAvatar != null
                    ? Image.network(
                      authProvider.selectedAvatar!.avatarMedia ?? '',
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildProfileLetterAvatar(authProvider);
                      },
                    )
                    : hasValidProfileUrl
                    ? Image.network(
                      authProvider.profileImageUrl!,
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildProfileLetterAvatar(authProvider);
                      },
                    )
                    : _buildProfileLetterAvatar(authProvider),
          ),
        ),
      );
    },
  );
}

Widget _buildProfileLetterAvatar(AuthProvider authProvider) {
  // Compose "First Last" (same order the rest of the app resolves names in) so
  // the user's own avatar shows the SAME initials other people see for them —
  // e.g. "Kanika Thakur" -> "KT" on every device, not "K" here and "KT" there.
  final first = authProvider.fNameController.text.trim();
  final last = authProvider.lNameController.text.trim();
  final composed = [first, last].where((p) => p.isNotEmpty).join(' ');
  final String name =
      composed.isNotEmpty ? composed : (userName.isNotEmpty ? userName : '');

  final String initials = avatarInitials(name);

  return Container(
    width: 100,
    height: 100,
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
          fontSize: 40,
        ),
      ),
    ),
  );
}

Future bottomSheetDesigin(BuildContext context, AuthProvider authProvider) {
  return bottomSheetGobal(
    context,
    bottomsheetHeight: SizeConfig.safeHeight(30),
    title: AppString.settingStrigs.profilePhoto,
    child: Column(
      children: [
        SizedBox(height: SizeConfig.height(3)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            bottomContainer(
              context,
              title: AppString.settingStrigs.camera,
              img: AppAssets.svgIcons.camera,
              onTap: () {
                authProvider.getImageFromCamera();
                Navigator.pop(context);
              },
            ),
            bottomContainer(
              context,
              title: AppString.settingStrigs.gellery,
              img: AppAssets.svgIcons.gellery,
              onTap: () {
                authProvider.getImageFromGallery();
                Navigator.pop(context);
              },
            ),
            // Only offered when there is actually a picture to remove.
            // Tapping it calls DELETE /users/avatar immediately.
            if (authProvider.hasProfilePicture)
              bottomContainer(
                context,
                title: AppString.remove,
                img: AppAssets.svgIcons.trash,
                onTap: () async {
                  Navigator.pop(context);
                  final success = await authProvider.removeAvatarApi(context);
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          authProvider.errorMessage ??
                              "Failed to remove profile photo",
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ],
    ),
  );
}

Widget bottomContainer(
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
            color: AppColors.appPriSecColor.secondaryColor.withValues(
              alpha: 0.30,
            ),
          ),
          child: Padding(
            padding: SizeConfig.getPadding(12),
            child: Center(
              child: SvgPicture.asset(
                img,
                height: 22,
                color: AppThemeManage.appTheme.darkWhiteColor,
              ),
            ),
          ),
        ),
        SizedBox(height: SizeConfig.height(1)),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.captionText(context),
        ),
      ],
    ),
  );
}

Future avatarList(BuildContext context) {
  return bottomSheetGobal(
    context,
    bottomsheetHeight: SizeConfig.sizedBoxHeight(505),
    title: AppString.avatarScreenString.selectAvatarPhoto,
    child: Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isGetProfile && !authProvider.hasLoadedOnce) {
          return Center(child: commonLoading());
        }
        if (authProvider.errorMessage != null && !authProvider.hasLoadedOnce) {
          return Center(
            child:
                authProvider.isInternetIssue
                    ? SvgPicture.asset(
                      AppAssets.svgIcons.internet,
                      colorFilter: ColorFilter.mode(
                        AppColors.appPriSecColor.primaryColor,
                        BlendMode.srcIn,
                      ),
                    )
                    : Text(
                      authProvider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTypography.buttonText(
                        context,
                      ).copyWith(color: AppColors.textColor.textErrorColor1),
                    ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: SizeConfig.height(3)),
            Expanded(
              child: SingleChildScrollView(
                child: GridView.builder(
                  itemCount: authProvider.avatars.length,
                  shrinkWrap: true,
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 0,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final avatar = authProvider.avatars[index];
                    final isSelected =
                        authProvider.tempSelectedAvatar?.avatarId ==
                        avatar.avatarId;
                    return InkWell(
                      onTap: () {
                        authProvider.selectAvatarTemp(avatar);
                      },
                      child: Stack(
                        children: [
                          Container(
                            height: SizeConfig.sizedBoxHeight(90),
                            width: SizeConfig.sizedBoxWidth(90),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    isSelected
                                        ? AppColors.appPriSecColor.primaryColor
                                        : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: SizeConfig.getPadding(3),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      AppColors.appPriSecColor.secondaryColor,
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: CachedNetworkImage(
                                  imageUrl: avatar.avatarMedia ?? "",
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) {
                                    return Center(
                                      child: Icon(
                                        Icons.person,
                                        color: AppColors.bgColor.bg4Color,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Checkmark icon if selected
                          if (isSelected)
                            Positioned(
                              right: 10,
                              bottom: 20,
                              child: Container(
                                height: SizeConfig.sizedBoxHeight(18),
                                width: SizeConfig.sizedBoxWidth(18),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.gradientColor.logoColor,
                                  border: Border.all(
                                    color: AppColors.bgColor.bgWhite,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.check,
                                  color: Colors.black,
                                  size: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: SizeConfig.getPaddingSymmetric(
                horizontal: 40,
                vertical: 20,
              ),
              child: customBtn2(
                context,
                onTap: () {
                  if (authProvider.tempSelectedAvatar != null) {
                    authProvider.selectAvatar(authProvider.tempSelectedAvatar!);
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppString.pleaseSelectAnAvatar)),
                    );
                  }
                },
                child: Text(
                  AppString.save,
                  style: AppTypography.h5(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor.textBlackColor,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Widget profileLoader(BuildContext context) {
  return Column(
    children: [
      profileWidget2(
        context,
        isBackArrow: true,
        title: AppString.settingStrigs.profile,
        profileChild: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.strokeColor.cECECEC),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Image.asset(
              AppAssets.defaultUser,
              fit: BoxFit.cover,
              width: 100,
              height: 100,
            ),
          ),
        ),
      ),

      SizedBox(height: SizeConfig.height(30)),
      Center(child: commonLoading()),
    ],
  );
}
