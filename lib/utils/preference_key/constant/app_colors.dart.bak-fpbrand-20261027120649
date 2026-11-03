import 'package:flutter/material.dart';

class AppColors {
  static TextColor textColor = TextColor();
  static AppPriSecColor appPriSecColor = AppPriSecColor();
  static StrokeColor strokeColor = StrokeColor();
  static OpacityColor opacityColor = OpacityColor();
  static BGColor bgColor = BGColor();
  static GradientColor gradientColor = GradientColor();
  static ChatBubbleColor chatBubbleColor = ChatBubbleColor();
  static ShadowColor shadowColor = ShadowColor();
  static VerifiedColro verifiedColor = VerifiedColro();
  static DarkModeColor darkModeColor = DarkModeColor();
  // static ThemeBoolColor themeBoolColor = ThemeBoolColor();

  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Colors.grey;

  static const Color transparent = Colors.transparent;

  static LinearGradient subscriptionGradient = LinearGradient(
    colors: <Color>[
      Color(0xff037B03),
      appPriSecColor.secondaryColor.withValues(alpha: 0.90),
      const Color.fromARGB(255, 61, 190, 61),
      bgColor.bg4Color,
      bgColor.bg4Color,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient borderGradiant = LinearGradient(
    colors: <Color>[Color(0xff9E9E9E), Color(0xff9E9E9E), Color(0xff1B1B1B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
  );

  static Shader linearGradient = LinearGradient(
    colors: <Color>[appPriSecColor.secondaryColor, appPriSecColor.primaryColor],
  ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0));

  static LinearGradient blackShadowGradient = LinearGradient(
    colors: <Color>[
      shadowColor.c000000.withValues(alpha: 0),
      shadowColor.c000000.withValues(alpha: 51),
      shadowColor.c000000.withValues(alpha: 71),
    ],

    begin: Alignment.bottomCenter,
    end: Alignment.bottomCenter,
  );
}

//============================================================================================================================================================
//======================================================================== TYPOGRAPHY COLOR ==================================================================
//============================================================================================================================================================
class TextColor {
  final Color textBlackColor = Colors.black;
  final Color textGreyColor = Color(0xff909091);
  final Color textWhiteColor = Color(0xffFFFFFF);
  final Color text3A3333 = Color(0xff3A3333);
  final Color text3F3F3F = Color(0xff3F3F3F);
  final Color textErrorColor = Color(0xffDD6666);
  final Color textErrorColor1 = Color(0xffFF2525);
  final Color textDarkGray = Color(0xff737373);
  final Color text808080 = Color(0xff808080);
}

class AppPriSecColor {
  Color primaryColor = Color(0xffFCC604);
  Color secondaryColor = Color(0xffFAE390);
  Color secondaryRed = Color(0xffFF2525);
  // Color secondaryLightColor = AppColors.appPriSecColor.secondaryColor
  //     .withValues(alpha: 0.50);
}

class GradientColor {
  final LinearGradient gradientColor = LinearGradient(
    colors: <Color>[
      AppColors.appPriSecColor.secondaryColor,
      AppColors.appPriSecColor.primaryColor,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  final LinearGradient headerColor = LinearGradient(
    colors: <Color>[
      AppColors.appPriSecColor.secondaryColor,
      AppColors.appPriSecColor.primaryColor,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  final LinearGradient logoColor = LinearGradient(
    colors: <Color>[
      AppColors.appPriSecColor.secondaryColor,
      AppColors.appPriSecColor.primaryColor,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  final LinearGradient starredColor = LinearGradient(
    colors: <Color>[
      AppColors.bgColor.bg4Color.withValues(alpha: 0.50),
      AppColors.bgColor.bg4Color,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  LinearGradient starredColorDark = LinearGradient(
    colors: <Color>[
      Colors.transparent, // keep most part visible
      Colors.black,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class StrokeColor {
  final Color greyColor = Color(0xffCFCFCF);
  final Color whiteColor = Colors.white;
  final Color cEEEEEE = Color(0xffEEEEEE);
  final Color c1A1919 = Color(0xff1A1919);
  final Color cECECEC = Color(0xffECECEC);
  final Color cF9F9F9 = Color(0xffF9F9F9);
}

class SelectBoxColor {
  final Color cF9F9F9 = Color(0xffF9F9F9);
}

class VerifiedColro {
  final Color c00C32B = Color(0xff00C32B);
}

class OpacityColor {
  //========= Opacity primary color
  final Color opacityPrimColor = AppColors.appPriSecColor.primaryColor
      .withValues(alpha: 0.1);
  final Color opacityPrimColor08 = AppColors.appPriSecColor.primaryColor
      .withValues(alpha: 0.08);

  //========= Opacity secondary color
  final Color opacitySecColor = AppColors.appPriSecColor.secondaryColor
      .withValues(alpha: 0.1);
  final Color opacitySec2 = AppColors.appPriSecColor.secondaryColor.withValues(
    alpha: 0.2,
  );
  final Color opacitySec04 = AppColors.appPriSecColor.secondaryColor.withValues(
    alpha: 0.04,
  );
  final Color opacitySec5 = AppColors.appPriSecColor.secondaryColor.withValues(
    alpha: 0.5,
  );
  final Color opacitySec06 = AppColors.appPriSecColor.secondaryColor.withValues(
    alpha: 0.06,
  );
  final Color opacitySec08 = AppColors.appPriSecColor.secondaryColor.withValues(
    alpha: 0.08,
  );
  final Color cFEF6D7B8 = Color(0xffFEF6D7).withValues(alpha: 0.72);

  //========== Grey Opacity Color
  final Color opacityGreyColor = Color(0xffFFFFFF).withValues(alpha: 0.3);
  //========== black opacity
  final Color opacityBlack06 = AppColors.textColor.textBlackColor.withValues(
    alpha: 0.6,
  );
}

class BGColor {
  final Color bg1Color = Color(0xffFAFAFA);
  final Color bg2Color = Color(0xffECEBEB);
  final Color bg3Color = Color(0xffF3F3F3);
  final Color bg4Color = Color(0xffFFFFFF);
  final Color bgWhite = Colors.white;
  final Color bgCFCFCF = Color(0xffCFCFCF);
  final Color bgEFEFEF = Color(0xffEFEFEF);
  final Color bgBlack = Colors.black;
}

class ChatBubbleColor {
  // final Color chatOppositeColor = Color(0xffDDDDDD);
  // final Color chatYellowColor = Color(0xffF8E6A7);
  final Color chatSecBubble = AppColors.appPriSecColor.secondaryColor
      .withValues(alpha: 0.5);
  final Color chatPriBubble = AppColors.appPriSecColor.primaryColor.withValues(
    alpha: 0.5,
  );
  // final Color chatOppositBuuble = Color(0xffECEBEB);
}

class ShadowColor {
  final Color c000000 = Color(0xff000000);
  final Color cE9E9E9 = Color(0xffE9E9E9);
}

class DarkModeColor {
  final Color blackColor = Color(0xff181818);
  final Color blackGray = Color(0xff242424);
  final Color blackGrayBorder = Color(0xff373737);
  final Color chatDarkColor1 = Color(0xff4A4A4A);
  final Color chatDarkColor2 = AppColors.bgColor.bg4Color.withValues(
    alpha: 0.15,
  );
  final Color blackTextGrey = Color(0xff959595);
}

/// Theme color palette for user customization
class ThemeColorPalette {
  static final List<Color> colors = [
    // Row 1
    Color(0xff2E8B57), // Dark Green //** white
    Color(0xffB4E7B4), // Light Green
    Color(0xff5B5FED), // Blue //** white
    Color(0xffC7C5F3), // Light Lavender
    // Row 2
    Color(0xffA855D9), // Magenta //** white
    Color(0xffE5C7EF), // Light Pink/Lavender
    Color(0xffE76F51), // Coral //** white
    Color(0xffF4C7B7), // Light Peach
    // Row 3
    Color(0xff1A7B7B), // Dark Teal //** white
    Color(0xffA7E0E0), // Cyan
    Color(0xff2563EB), // Navy Blue //** white
    Color(0xffBAD7F2), // Light Blue
    // Row 4
    Color(0xff1E3A5F), // Dark Navy //** white
    Color(0xffB8C5D6), // Light Gray-Blue
    Color(0xff3D5A40), // Dark Green //** white
    Color(0xffC9D5C9), // Light Sage
    // Row 5
    Color(0xff6B1F3B), // Burgundy //** white
    Color(0xffF8C7DD), // Light Pink
    Color(0xff2D2D2D), // Black //** white
    Color(0xffBDBDBD), // Gray
    // Row 6
    Color(0xff8B6F47), // Brown //** white
    Color(0xffF4E4D0), // Beige
    Color(0xffB4A07A), // Tan
    Color(0xffF0E9DD), // Light Tan
    // Row 7
    Color(0xff14B8A6), // Teal //** white
    Color(0xffA7F3E8), // Light Cyan
    Color(0xffEAB308), // Yellow
    Color(0xffFEF3C7), // Light Yellow
    // Row 8
    Color(0xff84CC16), // Lime Green //** white
    Color(0xffD9F99D), // Light Lime
    Color(0xffEC4899), // Pink //** white
    Color(0xffFCE7F3), // Light Pink
    // Row 9
    Color(0xffEF4444), // Red //** white
    Color(0xffFECDD3), // Light Pink
    Color(0xffF97316), // Orange //** white
    Color(0xffFED7AA), // Light Peach
    // Row 10
    Color(0xffD97706), // Gold //** white
    Color(0xffFEF3C7), // Cream
  ];

  static Color getTextColor(Color background) {
    // Colors manually chosen to use white text (from your list)
    // const whiteTextColors = {
    //   0xff2E8B57,
    //   0xff5B5FED,
    //   0xffA855D9,
    //   0xffE76F51,
    //   0xff1A7B7B,
    //   0xff2563EB,
    //   0xff1E3A5F,
    //   0xff3D5A40,
    //   0xff6B1F3B,
    //   0xff2D2D2D,
    //   0xff8B6F47,
    //   0xff14B8A6,
    //   0xff84CC16,
    //   0xffEC4899,
    //   0xffEF4444,
    //   0xffF97316,
    //   0xffD97706,
    // };

    // // If the background color matches one of the dark ones → return white text
    // if (whiteTextColors.contains(background.toARGB32())) {
    //   return AppColors.textColor.textWhiteColor;
    // }

    // // Otherwise → return black text
    // return AppColors.textColor.textBlackColor;
    final double luminance = background.computeLuminance();

    // If color is bright → return black text
    // If color is dark → return white text
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
