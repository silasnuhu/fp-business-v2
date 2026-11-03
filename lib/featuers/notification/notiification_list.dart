import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/notification/model/notification_model.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';

class NotiificationList extends StatefulWidget {
  const NotiificationList({super.key});

  @override
  State<NotiificationList> createState() => _NotiificationListState();
}

class _NotiificationListState extends State<NotiificationList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          shape: Border(
            bottom: BorderSide(color: AppThemeManage.appTheme.borderColor),
          ),
          backgroundColor: AppColors.transparent,
          systemOverlayStyle: systemUI(),
          flexibleSpace: flexibleSpace(),
          titleSpacing: 0,
          leading: Padding(
            padding: SizeConfig.getPadding(12),
            child: customeBackArrowBalck(context),
          ),
          title: Text(
            AppString.notification,
            style: AppTypography.h220(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: Consumer<ProjectConfigProvider>(
        builder: (context, notifiProvider, _) {
          if (notifiProvider.isNotification) {
            return Center(child: commonLoading());
          }
          if (notifiProvider.errorMessage != null) {
            return Center(
              child:
                  notifiProvider.isInternetIssue
                      ? SvgPicture.asset(
                        AppAssets.svgIcons.internet,
                        colorFilter: ColorFilter.mode(
                          AppColors.appPriSecColor.primaryColor,
                          BlendMode.srcIn,
                        ),
                      )
                      : Text(
                        notifiProvider.errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTypography.buttonText(
                          context,
                        ).copyWith(color: AppColors.textColor.textErrorColor1),
                      ),
            );
          }
          if (notifiProvider.notificationList!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    AppAssets.emptyDataIcons.emptyNotification,
                    height: SizeConfig.safeHeight(10),
                    colorFilter: ColorFilter.mode(
                      AppColors.appPriSecColor.secondaryColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(height: SizeConfig.height(2)),
                  Text(
                    AppString.emptyDataString.notificationNotFound,
                    style: AppTypography.h3(context),
                  ),
                  SizedBox(height: SizeConfig.height(0.5)),
                  Text(
                    AppString.emptyDataString.youdonthaveanyNotification,
                    style: AppTypography.innerText12Mediu(
                      context,
                    ).copyWith(color: AppColors.textColor.textGreyColor),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: notifiProvider.groupedNotification.length,
            itemBuilder: (context, index) {
              final dateKey = notifiProvider.groupedNotification.keys.elementAt(
                index,
              );
              final notification = notifiProvider.groupedNotification[dateKey]!;
              return Container(
                margin: EdgeInsets.only(bottom: SizeConfig.safeHeight(1.5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(
                        bottom: SizeConfig.safeHeight(1.5),
                        top: SizeConfig.safeHeight(1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: AppColors.appPriSecColor.primaryColor
                                  .withValues(alpha: 0.3),
                              thickness: 1,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: SizeConfig.safeWidth(4),
                              vertical: SizeConfig.safeHeight(0.8),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.appPriSecColor.primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _formatDateKey(dateKey),
                              style: AppTypography.innerText12Mediu(
                                context,
                              ).copyWith(
                                fontWeight: FontWeight.w600,
                                color: ThemeColorPalette.getTextColor(
                                  AppColors.appPriSecColor.primaryColor,
                                ), //AppColors.textColor.textBlackColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppColors.appPriSecColor.primaryColor
                                  .withValues(alpha: 0.3),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: notification.length,
                      separatorBuilder:
                          (context, index) => Divider(
                            color: AppThemeManage.appTheme.borderColor,
                            height: 1,
                            // thickness: 0.5,
                          ),
                      itemBuilder:
                          (context, nIndex) =>
                              notificationWidgt(notification[nIndex]),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget notificationWidgt(Records notifi) {
    return Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: SizeConfig.sizedBoxHeight(40),
            width: SizeConfig.sizedBoxWidth(40),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.appPriSecColor.primaryColor.withValues(
                alpha: 0.2,
              ),
            ),
            child: Center(
              child: SvgPicture.asset(
                AppAssets.homeIcons.notification,
                colorFilter: ColorFilter.mode(
                  AppColors.appPriSecColor.primaryColor,
                  BlendMode.srcIn,
                ),
                height: SizeConfig.sizedBoxHeight(20),
              ),
            ),
          ),
          SizedBox(width: SizeConfig.width(3)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SizeConfig.height(0.7)),
                Text(
                  notifi.title.toString(),
                  style: AppTypography.innerText12Mediu(context).copyWith(
                    fontFamily: AppTypography.fontFamily.poppinsMedium,
                  ),
                ),
                Text(
                  notifi.message.toString(),
                  // "We’re excited to announce WhoXa v1.0.6 — bringing major improvements for an even smoother experience!",
                  style: AppTypography.innerText12Ragu(
                    context,
                  ).copyWith(color: AppColors.textColor.textDarkGray),
                ),
                SizedBox(height: SizeConfig.height(0.5)),
                Text(
                  notificationTime(notifi.createdAt.toString()),
                  style: AppTypography.innerText10(context).copyWith(
                    color: AppColors.appPriSecColor.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String notificationTime(String time) {
    try {
      DateTime dateTime = DateTime.parse(time).toLocal(); // convert to local
      return DateFormat.jm().format(dateTime); // 👉 11:39 AM
    } catch (e) {
      return '';
    }
  }

  String _formatDateKey(String dateKey) {
    // If it's already "Today" or "Yesterday", return as is
    if (dateKey == 'Today' || dateKey == 'Yesterday') {
      return dateKey;
    }

    // Try to parse the date format (day/month/year)
    try {
      final parts = dateKey.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);

        final date = DateTime(year, month, day);
        final now = DateTime.now();

        // Check if it's this week
        final difference = now.difference(date).inDays;
        if (difference < 7) {
          final weekdays = [
            'Sunday',
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
          ];
          return weekdays[date.weekday % 7];
        }

        // Check if it's this year
        if (date.year == now.year) {
          final months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          return '${months[month - 1]} ${day.toString().padLeft(2, '0')}';
        }

        // For older dates, show month and year
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${months[month - 1]} ${day.toString().padLeft(2, '0')}, $year';
      }
    } catch (e) {
      // If parsing fails, return the original dateKey
      return dateKey;
    }

    return dateKey;
  }
}
