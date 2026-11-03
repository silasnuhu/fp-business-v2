// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

class CallWidget extends StatelessWidget {
  final Function() onTapAudio;
  final Function() onTapVideo;
  const CallWidget({
    super.key,
    required this.onTapAudio,
    required this.onTapVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onTapAudio,
          child: SvgPicture.asset(
            AppAssets.bottomNavIcons.call1,
            color: AppColors.white,
            height: SizeConfig.sizedBoxHeight(24),
          ),
        ),
        SizedBox(width: SizeConfig.sizedBoxWidth(16)),
        InkWell(
          onTap: onTapVideo,
          child: SvgPicture.asset(
            AppAssets.groupProfielIcons.video,
            color: AppColors.white,
            height: SizeConfig.sizedBoxHeight(24),
          ),
        ),
        SizedBox(width: SizeConfig.sizedBoxWidth(15)),
      ],
    );
  }
}
