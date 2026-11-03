import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

Widget globButton({
  required String name,
  void Function()? onTap,
  Gradient? gradient,
  double? radius,
  bool isOuntLined = false,
  double? height,
  double horizontal = 0.0,
  double vertical = 15,
  TextStyle? textStyle,
  Widget? child,
  Color color = AppColors.white,
  bool isInner = false,
}) {
  return Padding(
    padding: SizeConfig.getPaddingSymmetric(
      horizontal: horizontal,
      vertical: vertical,
    ),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        // height: height ?? 50,
        decoration:
            isOuntLined == false
                ? BoxDecoration(
                  borderRadius: BorderRadius.circular(radius ?? 40),
                  gradient: gradient ?? AppColors.gradientColor.gradientColor,
                )
                : BoxDecoration(
                  borderRadius: BorderRadius.circular(radius ?? 40),
                  color:
                      isInner
                          ? AppColors.opacityColor.opacitySec08
                          : AppColors.bgColor.bgWhite,
                  border: Border.all(color: color),
                ),
        child:
            child ??
            Center(
              child:
                  textStyle != null
                      ? Text(name, style: textStyle)
                      : Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color:
                              isOuntLined == false
                                  ? AppColors.white
                                  : AppColors.black,
                        ),
                      ),
            ),
      ),
    ),
  );
}
