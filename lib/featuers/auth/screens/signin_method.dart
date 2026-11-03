import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class SigninMethodScreen extends StatelessWidget {
  const SigninMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: scaffoldPageDesign(
        child: Scaffold(
          backgroundColor: AppColors.transparent,
          bottomNavigationBar: BottomAppBar(
            color: AppColors.transparent,
            elevation: 0,
            height:
                SizeConfig.sizedBoxHeight(50) +
                MediaQuery.of(context).padding.bottom,
            child: Text(
              "App version: $appVersion",
              textAlign: TextAlign.center,
              style: AppTypography.menuText(context).copyWith(
                color: AppColors.appPriSecColor.primaryColor,
                fontSize: SizeConfig.getFontSize(13),
              ),
            ),
          ),
          body: Center(
            child: Padding(
              padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    AppAssets.chatAppLogo,
                    height: SizeConfig.sizedBoxHeight(66),
                  ),
                  SizedBox(height: SizeConfig.height(4)),
                  container(
                    context,
                    child: Padding(
                      padding: SizeConfig.getPadding(22),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppString.welcome,
                                style: AppTypography.h1(context),
                              ),
                              SizedBox(width: SizeConfig.width(2)),
                              SvgPicture.asset(
                                AppAssets.hand,
                                height: SizeConfig.sizedBoxHeight(19),
                              ),
                            ],
                          ),
                          SizedBox(height: SizeConfig.height(1.5)),
                          Text(
                            AppString.hello,
                            style: AppTypography.h3(context),
                          ),
                          SizedBox(height: SizeConfig.height(3.5)),
                          //========================================= Navigate to Next Screen
                          //========================================= Navigate to Next Screen
                          //========================================= Navigate to Next Screen
                          GestureDetector(
                            onTap: () {
                              Provider.of<AuthProvider>(context, listen: false)
                                  .isSelectLoginType = AppString.phone;
                              Navigator.pushNamed(context, AppRoutes.login);
                            },
                            child: Container(
                              width: SizeConfig.sizedBoxWidth(290),
                              height: SizeConfig.sizedBoxHeight(50),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.strokeColor.greyColor,
                                ),
                              ),
                              child: Padding(
                                padding: SizeConfig.getPaddingSymmetric(
                                  horizontal: 10,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      AppString
                                          .loginTypeString
                                          .continuewithPhoneorEmail,
                                      style: AppTypography.smallText(
                                        context,
                                      ).copyWith(
                                        fontFamily:
                                            AppTypography.fontFamily.poppins,
                                        color: AppColors
                                            .textColor
                                            .textBlackColor
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                    Container(
                                      width: SizeConfig.sizedBoxWidth(36),
                                      height: SizeConfig.sizedBoxHeight(36),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            AppColors
                                                .appPriSecColor
                                                .primaryColor,
                                      ),
                                      child: Center(
                                        child: SvgPicture.asset(
                                          AppAssets.arrowRight,
                                          height: SizeConfig.sizedBoxHeight(20),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: SizeConfig.height(2.7)),

                          SizedBox(height: SizeConfig.height(2.7)),
                          Padding(
                            padding: SizeConfig.getPaddingSymmetric(
                              horizontal: 20,
                            ),
                            child: customBtn2(
                              context,
                              onTap: () {},
                              child: Text(
                                AppString.loginEmailPhoneString.sendOtp,
                                style: AppTypography.h5(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textColor.textBlackColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget socialButton({
  BuildContext? context,
  required Function() onTap,
  required String img,
  required String title,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      height: SizeConfig.sizedBoxHeight(44),
      width: SizeConfig.sizedBoxHeight(280),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.appPriSecColor.secondaryColor,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5), // Space for the border effect
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white, // Inner container background
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                img,
                height: SizeConfig.sizedBoxHeight(21),
                fit: BoxFit.cover,
              ),
              SizedBox(width: SizeConfig.width(2)),
              Text(
                title,
                textAlign: TextAlign.left,
                style: AppTypography.h5(context!),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
