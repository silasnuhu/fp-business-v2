import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';

class AvatarSelectionScreen extends StatefulWidget {
  const AvatarSelectionScreen({super.key});

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      Provider.of<AuthProvider>(
        context,
        listen: false,
      ).loadAvatars(isSelected: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor.bgWhite,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          shape: Border(
            bottom: BorderSide(color: AppColors.shadowColor.cE9E9E9),
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
            AppString.settingStrigs.selectAvatar,
            style: AppTypography.h3(context),
          ),
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoadingAvatars) {
            return Center(child: commonLoading());
          }

          if (authProvider.avatars.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    size: 64,
                    color: AppColors.textColor.textGreyColor,
                  ),
                  SizedBox(height: SizeConfig.height(2)),
                  Text(
                    "No avatars available",
                    style: AppTypography.h5(
                      context,
                    ).copyWith(color: AppColors.textColor.textGreyColor),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: 20,
              vertical: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Choose your avatar",
                  style: AppTypography.h4(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: SizeConfig.height(2)),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1,
                    ),
                    itemCount: authProvider.avatars.length,
                    itemBuilder: (context, index) {
                      final avatar = authProvider.avatars[index];
                      final isSelected =
                          authProvider.selectedAvatar?.avatarId ==
                          avatar.avatarId;

                      return GestureDetector(
                        onTap: () {
                          authProvider.selectAvatar(avatar);
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? AppColors.appPriSecColor.primaryColor
                                      : AppColors.strokeColor.greyColor,
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: AppColors
                                            .appPriSecColor
                                            .primaryColor
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              avatar.avatarMedia ?? '',
                              fit: BoxFit.cover,
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.strokeColor.greyColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.broken_image,
                                    color: AppColors.textColor.textGreyColor,
                                    size: 40,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
