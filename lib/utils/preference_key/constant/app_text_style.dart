import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

class AppTypography {
  // Base text style that includes the font
  static FontFamily fontFamily = FontFamily();
  static TextStyle _baseStyle(BuildContext context) {
    return TextStyle(
      fontFamily: fontFamily.poppins,
      color: AppThemeManage.appTheme.textColor,
    );
  }

  // Headings
  static TextStyle h1(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontFamily: fontFamily.poppinsSemiBold,
      fontSize: SizeConfig.getFontSize(28),
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
  }

  static TextStyle h2(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(24),
      fontFamily: fontFamily.poppinsMedium,
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
  }

  static TextStyle h220(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontFamily: fontFamily.poppinsMedium,
      fontSize: SizeConfig.getFontSize(20),
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
  }

  static TextStyle h3(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(18),
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
  }

  static TextStyle h4(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(16),
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
  }

  static TextStyle h418(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontFamily: fontFamily.poppinsSemiBold,
      fontSize: SizeConfig.getFontSize(18),
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
  }

  static TextStyle h5(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(14),
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
  }

  static TextStyle h526(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontFamily: fontFamily.poppinsBold,
      fontSize: SizeConfig.getFontSize(26),
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
  }

  // Big text
  static TextStyle bigText(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(18),
      fontWeight: FontWeight.w300,
      height: 1.5,
    );
  }

  // Large, Medium, Small text
  static TextStyle largeText(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(16),
      fontWeight: FontWeight.w300,
      height: 1.5,
    );
  }

  static TextStyle mediumText(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(14),
      fontWeight: FontWeight.w300,
      height: 1.5,
    );
  }

  static TextStyle smallText(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(12),
      fontWeight: FontWeight.w300,
      height: 1.5,
    );
  }

  // Menu
  static TextStyle menuText(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(9),
      fontWeight: FontWeight.w400,
      height: 1.2,
    );
  }

  // Inputs / Buttons
  static TextStyle buttonText(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(14),
      fontWeight: FontWeight.w500,
      height: 1.4,
    );
  }

  static TextStyle inputPlaceholder(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(14),
      fontWeight: FontWeight.w400,
      height: 1.4,
    );
  }

  static TextStyle inputPlaceholderSmall(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(12),
      fontWeight: FontWeight.w400,
      height: 1.4,
    );
  }

  static TextStyle captionText(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(12),
      fontWeight: FontWeight.w400,
      height: 1.4,
    );
  }

  // Underlined text
  static TextStyle underlinedTextMedium(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(14),
      fontWeight: FontWeight.w500,
      height: 1.4,
      decoration: TextDecoration.underline,
    );
  }

  static TextStyle underlinedTextSmall(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(12),
      fontWeight: FontWeight.w500,
      height: 1.4,
      decoration: TextDecoration.underline,
    );
  }

  static TextStyle subText(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(8),
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
  }

  static TextStyle text12(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(12),
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
  }

  //============= inner text ==============================
  static TextStyle innerText08(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(8),
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
  }

  static TextStyle innerText10(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(10),
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
  }

  static TextStyle innerText11(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(12),
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
  }

  static TextStyle innerText12Ragu(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(12),
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
  }

  static TextStyle innerText12Mediu(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(12),
      fontFamily: fontFamily.poppinsMedium,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
  }

  static TextStyle innerText14(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontFamily: fontFamily.poppinsMedium,
      fontSize: SizeConfig.getFontSize(14),
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
  }

  static TextStyle innerText16(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontFamily: fontFamily.poppinsMedium,
      fontSize: SizeConfig.getFontSize(16),
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
  }

  //======================= TextBox/Upper Text
  static TextStyle textBoxUpperText10(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(10),
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
  }

  static TextStyle textBoxUpperText11(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(11),
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
  }

  static TextStyle textBoxUpperText12(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontFamily: fontFamily.poppinsMedium,
      fontSize: SizeConfig.getFontSize(12),
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
  }

  //================= Button text ===========================
  static TextStyle buttonText12(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontFamily: fontFamily.poppinsMedium,
      fontSize: SizeConfig.getFontSize(12),
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
  }

  static TextStyle buttonText10(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontSize: SizeConfig.getFontSize(10),
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
  }

  //================ Footer Text ==================================
  static TextStyle footerText10(BuildContext context) {
    return _baseStyle(context).copyWith(
      fontFamily: fontFamily.poppinsMedium,
      fontSize: SizeConfig.getFontSize(10),
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
  }
}

class FontFamily {
  final String poppins = "Poppins";
  final String poppinsBold = "PoppinsBold";
  final String poppinsMedium = "PoppinsMedium";
  final String poppinsSemiBold = "PoppinsSemibold";
  final String vietnam = "vietnam";
  final String brittany = "brittany";
  final String lexend = "lexend";
  final String jostSemiBold = "JostSemibold";
}
