import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/data/blocked_user_model.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/gradient_border.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';

class BlockListScreen extends StatefulWidget {
  const BlockListScreen({super.key});

  @override
  State<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  @override
  void initState() {
    super.initState();
    // Load blocked users when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.loadBlockedUsers();
    });
  }

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
            AppString.settingStrigs.blockList,
            style: AppTypography.h220(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: Consumer2<ChatProvider, ProjectConfigProvider>(
        builder: (context, chatProvider, configProvider, child) {
          if (chatProvider.isBlockListLoading) {
            return Center(child: commonLoading());
          }

          if (chatProvider.blockedUsers.isEmpty) {
            return Align(
              alignment: Alignment.center,
              child: Column(
                children: [
                  SizedBox(height: SizeConfig.height(30)),
                  SvgPicture.asset(
                    AppAssets.emptyDataIcons.emptyBlock,
                    colorFilter: ColorFilter.mode(
                      AppColors.appPriSecColor.secondaryColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(height: SizeConfig.height(2)),
                  Text(
                    AppString.blockUserStrings.noBlockContact,
                    style: AppTypography.h3(context).copyWith(),
                  ),
                  SizedBox(height: SizeConfig.height(0.5)),
                  Text(
                    AppString.blockUserStrings.youdonthaveanyblockContact,
                    style: AppTypography.smallText(
                      context,
                    ).copyWith(color: AppColors.textColor.textDarkGray),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: SizeConfig.height(3)),
                ListView.separated(
                  itemCount: chatProvider.blockedUsers.length,
                  physics: NeverScrollableScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  separatorBuilder: (context, index) {
                    return Padding(
                      padding: SizeConfig.getPaddingSymmetric(vertical: 3),
                      child: Divider(
                        color: AppThemeManage.appTheme.borderColor,
                      ),
                    );
                  },
                  itemBuilder: (context, index) {
                    final blockedUserRecord = chatProvider.blockedUsers[index];
                    return _buildBlockedUserItem(
                      context,
                      blockedUserRecord,
                      chatProvider,
                      configProvider,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build blocked user item widget
  Widget _buildBlockedUserItem(
    BuildContext context,
    BlockedUserRecord blockedUserRecord,
    ChatProvider chatProvider,
    ProjectConfigProvider configProvider,
  ) {
    final blockedUser = blockedUserRecord.blocked;
    if (blockedUser == null) {
      return SizedBox.shrink();
    }

    // Use ContactNameService for consistent naming like in chat list and group members
    final displayName = ContactNameService.instance.getDisplayName(
      userId: blockedUser.userId,
      userFullName: blockedUser.fullName,
      userName: blockedUser.userName,
      userEmail: blockedUser.email,
      configProvider: configProvider,
      firstName: blockedUser.firstName,
      lastName: blockedUser.lastName,
    );
    final profilePic = blockedUser.profilePic ?? '';
    final userId = blockedUser.userId ?? 0;

    return Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Profile picture, or the initials of the name ("Amit Primo" ->
              // "AP") when the user has none.
              CommonProfileAvatar(
                imageUrl: profilePic,
                name: displayName,
                radius: SizeConfig.sizedBoxHeight(25),
              ),
              SizedBox(width: SizeConfig.width(5)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: SizeConfig.safeWidth(45),
                    child: UserNameWithBadge(
                      userId: blockedUser.userId,
                      name: displayName,
                      style: AppTypography.innerText14(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (blockedUser.mobileNum != null) ...[
                    Text(
                      '${blockedUser.countryCode ?? ''}${blockedUser.mobileNum ?? ''}', //??'User ID: $userId',
                      maxLines: 1,
                      style: AppTypography.smallText(
                        context,
                      ).copyWith(color: AppColors.textColor.textGreyColor),
                    ),
                  ],
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap:
                () => _handleUnblockUser(
                  context,
                  userId,
                  displayName,
                  chatProvider,
                ),
            child: Container(
              height: SizeConfig.sizedBoxHeight(31),
              width: SizeConfig.sizedBoxWidth(80),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: GradientBoxBorder(
                  gradient: AppColors.gradientColor.gradientColor,
                ),
              ),
              child: Center(
                child: Text(
                  AppString.settingStrigs.unblock,
                  style: AppTypography.buttonText12(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle unblock user functionality
  void _handleUnblockUser(
    BuildContext context,
    int userId,
    String displayName,
    ChatProvider chatProvider,
  ) {
    bottomSheetGobalWithoutTitle(
      context,
      bottomsheetHeight: SizeConfig.height(23),
      isCrossIconHide: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.height(3)),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
            child: Text(
              AppString.blockUserStrings.unbolockUser,
              textAlign: TextAlign.start,
              style: AppTypography.captionText(context).copyWith(
                fontSize: SizeConfig.getFontSize(15),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: SizeConfig.height(2)),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
            child: Text(
              '${AppString.blockUserStrings.areYouSureYouWantToUnblock} $displayName?',
              textAlign: TextAlign.start,
              style: AppTypography.captionText(context).copyWith(
                color: AppColors.textColor.textGreyColor,
                fontSize: SizeConfig.getFontSize(13),
              ),
            ),
          ),
          SizedBox(height: SizeConfig.height(3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: customBorderBtn(
                  context,
                  onTap: () {
                    Navigator.pop(context);
                  },
                  title: AppString.cancel,
                ),
              ),
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: customBtn2(
                  context,
                  onTap: () async {
                    Navigator.pop(context);

                    final success = await chatProvider.blockUnblockUser(
                      userId,
                      0,
                    );

                    if (success) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '$displayName ${AppString.blockUserStrings.hasBeenUnblocked}',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      await chatProvider.countApi();
                    } else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${AppString.blockUserStrings.failedToUnblock} $displayName. ${AppString.pleaseTryAgain}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Text(
                    AppString.blockUserStrings.unblockU,
                    style: AppTypography.h5(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor.textBlackColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
