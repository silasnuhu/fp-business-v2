import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

/// Settings row that opens the Get Verified / subscription screen. Mirrors the
/// layout of the other rows in the settings list.
class SubscriptionSettingsTile extends StatelessWidget {
  const SubscriptionSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild when the app language changes (AppString has no context, so
    // nothing else would trigger it).
    context.watch<LanguageProvider>();
    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.subscription),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppThemeManage.appTheme.borderColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.appPriSecColor.primaryColor.withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: _AnimatedVerifiedBadge(size: 20)),
            ),
            SizedBox(width: SizeConfig.width(4)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppString.subscriptionStrings.getVerified,
                    style: AppTypography.innerText12Mediu(context),
                  ),
                  Text(
                    AppString.subscriptionStrings.goAdFree,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.inputPlaceholderSmall(context)
                        .copyWith(
                          fontFamily: AppTypography.fontFamily.poppins,
                          color: AppColors.textColor.textGreyColor,
                          fontSize: SizeConfig.getFontSize(10),
                        ),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              AppDirectionality.appDirectionIcon.arrow,
              height: SizeConfig.safeHeight(3),
              colorFilter: ColorFilter.mode(
                AppThemeManage.appTheme.darkWhiteColor,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Verified badge: a scalloped (star-like) border that rotates continuously,
/// with a check icon that stays fixed in the center.
class _AnimatedVerifiedBadge extends StatefulWidget {
  final double size;
  const _AnimatedVerifiedBadge({required this.size});

  @override
  State<_AnimatedVerifiedBadge> createState() => _AnimatedVerifiedBadgeState();
}

class _AnimatedVerifiedBadgeState extends State<_AnimatedVerifiedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppThemeManage.appTheme.textColor;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating scalloped border
          RotationTransition(
            turns: _controller,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _ScallopBadgePainter(color: color),
            ),
          ),
          // Fixed check icon (does not rotate)
          Icon(
            Icons.check_rounded,
            size: widget.size * 0.55,
            color: ThemeColorPalette.getTextColor(
              AppThemeManage.appTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScallopBadgePainter extends CustomPainter {
  final Color color;
  final int points;

  _ScallopBadgePainter({required this.color}) : points = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.82;

    final path = Path();
    final totalSteps = points * 2;
    for (int i = 0; i < totalSteps; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (math.pi * 2 / totalSteps) * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScallopBadgePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.points != points;
}
