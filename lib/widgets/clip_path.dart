import 'package:flutter/material.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

class DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

Widget yellowImageWidget(BuildContext context) {
  return
  // SizedBox(
  //   width: MediaQuery.sizeOf(context).width,
  //   child: Image.asset(
  //     AppAssets.backImage,
  //     width: MediaQuery.sizeOf(context).width,
  //     color: AppColors.appPriSecColor.primaryColor,
  //   ),
  // );
  ClipPath(
    clipper: DiagonalClipper(),
    child: Container(
      width: MediaQuery.sizeOf(context).width,
      height: MediaQuery.sizeOf(context).height * 0.26,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(AppAssets.backImage),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            AppColors.appPriSecColor.primaryColor,
            BlendMode.srcIn,
          ),
        ),
      ),
    ),
  );
}
