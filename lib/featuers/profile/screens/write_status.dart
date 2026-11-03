// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/profile/provider/profile_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';

class StatusWriteScreen extends StatelessWidget {
  const StatusWriteScreen({super.key});

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
          leading: Padding(
            padding: SizeConfig.getPadding(12),
            child: customeBackArrowBalck(context),
          ),
          titleSpacing: 1,
          title: Text(
            AppString.settingStrigs.about,
            style: AppTypography.h220(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(left: 15, right: 15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    Text(
                      AppString.settingStrigs.currentlySetTo,
                      style: AppTypography.textBoxUpperText12(context),
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Consumer<ProfileProvider>(
                        builder: (context, profileProvider, _) {
                          return TextField(
                            controller: profileProvider.statuscontroller,
                            readOnly: false,
                            autofocus: false,
                            maxLength: 200,
                            maxLines: 8,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textCapitalization: TextCapitalization.sentences,

                            decoration: InputDecoration(
                              counterStyle: TextStyle(fontSize: 10),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppThemeManage.appTheme.borderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppThemeManage.appTheme.borderColor,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppThemeManage.appTheme.borderColor,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppThemeManage.appTheme.borderColor,
                                ),
                              ),
                              contentPadding: EdgeInsets.only(
                                top: 15,
                                left: 15,
                                bottom: 20,
                                right: 5,
                              ),
                              hintText:
                                  '${AppString.settingStrigs.writeSomething}...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w400,
                              ),
                              filled: true,
                              fillColor: AppThemeManage.appTheme.darkGreyColor,
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: SizeConfig.getPaddingOnly(left: 60, right: 60, bottom: 30),
            child: SizedBox(
              height: SizeConfig.sizedBoxHeight(45),
              child: Consumer<ProfileProvider>(
                builder: (context, profileProvider, _) {
                  return profileProvider.loadingIndex == 1
                      ? commonLoading()
                      : customBtn2(
                        context,
                        onTap: () async {
                          closeKeyboard();

                          // Start loader
                          profileProvider.setLoadingIndex(1);

                          await Future.delayed(const Duration(seconds: 1));

                          if (profileProvider.statuscontroller.text
                              .trim()
                              .isNotEmpty) {
                            profileProvider.statusText =
                                profileProvider.statuscontroller.text;

                            final success = await profileProvider.statusGetApi(
                              isGetData: false,
                            );

                            if (!context.mounted) return;

                            profileProvider.setLoadingIndex(null);

                            if (success) {
                              profileProvider.selectedabouttext =
                                  profileProvider.statuscontroller.text;
                              Navigator.pop(context);
                            } else {
                              final msg = profileProvider.errorMessage!;
                              snackbarNew(context, msg: msg);
                            }
                          } else {
                            profileProvider.setLoadingIndex(null);
                            snackbarNew(context, msg: "Please write something");
                          }
                        },
                        child: Text(
                          AppString.submit,
                          style: AppTypography.h5(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textColor.textBlackColor,
                          ),
                        ),
                      );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
