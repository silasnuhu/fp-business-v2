import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

/// Fixed avatar for the AI Assistant bot user — used instead of a profile
/// photo lookup wherever the bot is shown.
class AiAssistantAvatar extends StatelessWidget {
  final double radius;

  const AiAssistantAvatar({super.key, required this.radius});

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.appPriSecColor.primaryColor;
    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: EdgeInsets.all(radius * 0.45),
      decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
      child: SvgPicture.asset(
        AppAssets.aiIcon,
        colorFilter: ColorFilter.mode(
          ThemeColorPalette.getTextColor(primary),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
