// ignore_for_file: must_be_immutable

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/packages/phone_field/countries.dart';
import 'package:whoxa/utils/packages/phone_field/intl_phone_field.dart';
import 'package:whoxa/utils/packages/phone_field/phone_number.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

Widget twoText(
  BuildContext context, {
  required String text1,
  String text2 = "",
  Color colorText2 = Colors.red,
  Color colorText1 = AppColors.black,
  double size = 10,
  FontWeight? fontWeight,
  TextStyle? style1,
  TextStyle? style2,
  void Function()? onTap2,
  MainAxisAlignment? mainAxisAlignment,
  MainAxisSize? mainAxisSize,
}) {
  return Row(
    mainAxisAlignment: mainAxisAlignment ?? MainAxisAlignment.center,
    mainAxisSize: mainAxisSize ?? MainAxisSize.max,
    children: [
      Text(
        "$text1 ",
        style: style1 ?? AppTypography.h5(context).copyWith(color: colorText1),
      ),
      GestureDetector(
        onTap: onTap2,
        child: Text(
          text2,
          style:
              style2 ?? AppTypography.h5(context).copyWith(color: colorText2),
        ),
      ),
    ],
  );
}

Widget searchBar(
  BuildContext context, {
  controller1,
  Function(String)? onChanged,
  String? hintText,
}) {
  return TextFormField(
    controller: controller1,
    onChanged: onChanged,
    cursorColor: AppColors.strokeColor.greyColor,
    style: AppTypography.inputPlaceholderSmall(context),
    decoration: InputDecoration(
      prefixIcon: Padding(
        padding: SizeConfig.getPadding(15),
        child: SvgPicture.asset(
          AppAssets.homeIcons.search,
          colorFilter: ColorFilter.mode(
            AppColors.textColor.textDarkGray,
            BlendMode.srcIn,
          ),
          height: SizeConfig.safeHeight(2),
        ),
      ),
      // floatingLabelBehavior: FloatingLabelBehavior.never,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      fillColor: AppThemeManage.appTheme.darkGreyColor,
      filled: true,
      hintText: hintText ?? AppString.homeScreenString.searchUser,
      hintStyle: AppTypography.inputPlaceholderSmall(
        context,
      ).copyWith(color: AppColors.textColor.textGreyColor),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppThemeManage.appTheme.borderColor),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppThemeManage.appTheme.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppThemeManage.appTheme.borderColor),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppThemeManage.appTheme.borderColor),
      ),
    ),
  );
}

class GlobalTextField1 extends StatelessWidget {
  final String? lable;
  final String? lable2;
  final TextEditingController controller;
  final void Function()? onEditingComplete;
  final void Function(String)? onChanged;
  final String hintText;
  final bool isBackgroundWhite;
  final FormFieldValidator<String>? validator;
  final bool isOnlyRead;
  final bool isForPhoneNumber;
  final bool isLabel;
  final FocusNode? focusNode;
  final bool isEmail;
  final bool isForProfile;
  final String imagePath;
  final int maxLines;
  final Widget? suffixIcon;
  final Widget? preffixIcon;
  final int? maxLength;
  final EdgeInsetsGeometry? contentPadding;
  final Color? focusedBorderColor;
  final void Function()? onTap;
  final bool? filled;
  final Color? fillColor;
  final TextCapitalization? textCapitalization;
  final BuildContext context;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final TextStyle? style1;
  final TextStyle? hintStyle;
  final AutovalidateMode? autovalidateMode;

  const GlobalTextField1({
    super.key,
    this.lable,
    this.lable2,
    required this.controller,
    required this.onEditingComplete,
    this.onChanged,
    required this.hintText,
    required this.context,
    required this.keyboardType,
    this.isBackgroundWhite = false,
    this.validator,
    this.isOnlyRead = false,
    this.isForPhoneNumber = false,
    this.isLabel = false,
    this.focusNode,
    this.isEmail = false,
    this.isForProfile = false,
    this.imagePath = '',
    this.maxLines = 1,
    this.suffixIcon,
    this.preffixIcon,
    this.maxLength,
    this.contentPadding,
    this.focusedBorderColor,
    this.onTap,
    this.filled,
    this.fillColor,
    this.textCapitalization,
    this.inputFormatters,
    this.style,
    this.style1,
    this.hintStyle,
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    // final RegExp urlRegex = RegExp(r'^(https?:\/\/|www\.)');

    return Column(
      children: [
        twoText(
          context,
          text1: lable ?? "",
          text2: lable2 ?? "",
          style1:
              style1 ??
              AppTypography.innerText12Mediu(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
          style2: AppTypography.h5(
            context,
          ).copyWith(color: AppColors.textColor.textErrorColor1),
          mainAxisAlignment: MainAxisAlignment.start,
        ),
        (lable == null || lable == "")
            ? const SizedBox.shrink()
            : SizedBox(height: SizeConfig.height(0.5)),
        TextFormField(
          controller: controller,
          onTap: onTap,
          textCapitalization: textCapitalization ?? TextCapitalization.none,
          onEditingComplete: onEditingComplete,
          autocorrect: true,
          enableSuggestions: true,
          inputFormatters: inputFormatters,
          style:
              style ??
              AppTypography.inputPlaceholder(
                context,
              ).copyWith(fontSize: SizeConfig.getFontSize(12)),
          autovalidateMode:
              autovalidateMode ?? AutovalidateMode.onUserInteraction,
          focusNode: focusNode,
          maxLength: maxLength,
          onFieldSubmitted: (value) {},
          onSaved: (newValue) => FocusScope.of(context).nextFocus(),
          onChanged: onChanged,
          readOnly: isOnlyRead,
          maxLines: maxLines == 1 ? 1 : maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            suffixIcon: suffixIcon,
            prefixIcon: preffixIcon,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding:
                contentPadding ??
                EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical:
                      (hintText == "Comments" ||
                              hintText == "Address" ||
                              hintText == "Description" ||
                              hintText ==
                                  "Describe the goal you aim to accomplish")
                          ? 10
                          : hintText == "Notes"
                          ? 12
                          : 0,
                ),
            fillColor: AppThemeManage.appTheme.bg4BlackGrey,
            filled: true,
            hintText: hintText,
            hintStyle:
                hintStyle ??
                AppTypography.inputPlaceholder(context).copyWith(
                  fontSize: SizeConfig.getFontSize(12),
                  color: AppColors.textColor.textGreyColor,
                ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(
                color: AppThemeManage.appTheme.greyBlackGrey,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(
                color: AppThemeManage.appTheme.greyBlackGrey,
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
            ).copyWith(color: AppColors.textColor.textErrorColor1),
            labelText: isLabel ? hintText : null,
            counterStyle:
                maxLength != null
                    ? AppTypography.captionText(context).copyWith(
                      color: AppColors.textColor.textGreyColor,
                      fontSize: SizeConfig.getFontSize(10),
                    )
                    : AppTypography.captionText(
                      context,
                    ).copyWith(color: AppColors.transparent, fontSize: 0),
            labelStyle: AppTypography.captionText(context).copyWith(),
          ),
          validator:
              validator ??
              (value) {
                if ([
                  "First Name*",
                  "Last Name*",
                  "User Name",
                  "First Name",
                  "Password",
                  "Last Name",
                ].contains(hintText)) {
                  if (value == null || value.isEmpty) {
                    return 'Please Enter Your $hintText';
                  }
                  return null;
                }

                if (hintText == "Enter mail" || isEmail) {
                  final emailRegex = RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  );
                  if (value == null || value.isEmpty) {
                    return "Please Enter Email";
                  } else if (!emailRegex.hasMatch(value)) {
                    return "Please Enter Valid Email";
                  }
                  return null;
                }

                return null;
              },
        ),
      ],
    );
  }
}

//======================================================================================================================
//======================================================================================================================
//======================================================================================================================
class GlobalIntlPhoneField extends StatelessWidget {
  final String? lable;
  final String? lable2;
  final String? initialValue;
  final TextEditingController controller;
  final void Function()? onEditingComplete;
  void Function(Country)? onCountryChanged;
  void Function(PhoneNumber)? onChanged;
  FutureOr<String?> Function(PhoneNumber?)? validator;
  final String hintText;
  final bool isInvalidNumber;
  final bool isOnlyRead;
  final bool isLabel;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? contentPadding;
  final Color? focusedBorderColor;
  final void Function()? onTap;
  final bool? filled;
  final Color? fillColor;
  final BuildContext context;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final TextStyle? style1;
  final TextStyle? hintStyle;

  GlobalIntlPhoneField({
    super.key,
    this.lable,
    this.lable2,
    this.initialValue,
    required this.controller,
    required this.onEditingComplete,
    this.onCountryChanged,
    this.onChanged,
    required this.hintText,
    required this.context,
    required this.keyboardType,

    required this.isInvalidNumber,
    this.validator,
    this.isOnlyRead = false,

    this.isLabel = false,
    this.focusNode,
    this.contentPadding,
    this.focusedBorderColor,
    this.onTap,
    this.filled,
    this.fillColor,
    this.inputFormatters,
    this.style,
    this.style1,
    this.hintStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        twoText(
          context,
          text1: lable ?? "",
          text2: lable2 ?? "",
          style1: style1 ?? AppTypography.h5(context).copyWith(),
          style2: AppTypography.h5(
            context,
          ).copyWith(color: AppColors.textColor.textErrorColor1),
          mainAxisAlignment: MainAxisAlignment.start,
        ),
        (lable == null || lable == "")
            ? const SizedBox.shrink()
            : SizedBox(height: SizeConfig.height(1)),
        IntlPhoneField(
          dropdownDecoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey.shade300, width: 1.0),
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[,.\-]')),
          ],

          dropdownTextStyle: AppTypography.captionText(
            context,
          ).copyWith(fontSize: SizeConfig.getFontSize(13)),
          showCountryFlag: false,
          showDropdownIcon: true,
          dropdownIcon: Icon(Icons.keyboard_arrow_down_rounded, size: 13),
          dropdownIconPosition: IconPosition.trailing,
          initialValue: initialValue,
          onCountryChanged: onCountryChanged,
          onChanged: onChanged,
          cursorColor: AppColors.black,
          autofocus: false,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: style,
          controller: controller,
          keyboardType: keyboardType,
          flagsButtonPadding: SizeConfig.getPaddingOnly(left: 1),
          decoration: InputDecoration(
            hintStyle: hintStyle,
            fillColor: AppColors.transparent,
            filled: true,
            counterText: '',
            contentPadding: SizeConfig.getPaddingSymmetric(
              vertical: 10,
              horizontal: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: AppColors.strokeColor.greyColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: AppColors.strokeColor.greyColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: AppColors.strokeColor.greyColor),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: AppColors.strokeColor.greyColor),
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
            errorStyle: TextStyle(
              color: AppColors.textColor.textErrorColor1,
              fontSize: SizeConfig.getFontSize(12),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
