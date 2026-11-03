// ignore_for_file: use_build_context_synchronously, avoid_print, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/story/data/model/get_all_story_model.dart';
import 'package:whoxa/featuers/story/provider/story_provider.dart';
import 'package:whoxa/featuers/story/screens/status_view.dart';
import 'package:whoxa/featuers/story/screens/story_upload.dart';
import 'package:whoxa/featuers/story/screens/story_view.dart';
import 'package:whoxa/featuers/story/screens/trimmer_view.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
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
// import 'package:status_view/status_view.dart';
// import 'package:whoxa/featuers/story/data/model/get_all_story_model.dart';

class StoryList extends StatefulWidget {
  const StoryList({super.key});

  @override
  State<StoryList> createState() => _StoryListState();
}

class _StoryListState extends State<StoryList> with TickerProviderStateMixin {
  late Future<void> storyProvider;

  // Tab controller for different media types
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    debugPrint("authToken:$authToken");
    debugPrint("userProfile:$userProfile");
    setState(() {
      userProfile;
    });
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      storyProvider =
          Provider.of<StoryProvider>(context, listen: false).getAllStories();
    });
  }

  // Helper method to get display name using ContactNameService
  String _getDisplayName(dynamic storyUser) {
    final configProvider = Provider.of<ProjectConfigProvider>(
      context,
      listen: false,
    );

    // 🎯 FIXED: Use getDisplayNameStable for consistent priority behavior
    return ContactNameService.instance.getDisplayNameStable(
      userId: storyUser.userId,
      configProvider: configProvider,
      contextFullName: storyUser.fullName, // Pass the full name from story user
      firstName: storyUser.firstName,
      lastName: storyUser.lastName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.transparent,
        systemOverlayStyle: systemUI(),
        // flexibleSpace: flexibleSpace(),
        title: Text(
          AppString.storyStrings.status,
          style: AppTypography.h2(context).copyWith(
            fontWeight: FontWeight.w600,
            fontFamily: AppTypography.fontFamily.poppinsBold,
          ),
        ), //appDynamicLogo(height: SizeConfig.sizedBoxHeight(31)),
      ),
      body: Consumer<StoryProvider>(
        builder: (context, storyProvider, _) {
          if (storyProvider.isGetStory && storyProvider.hasLoadedOnce) {
            return Center(child: commonLoading());
          }
          if (storyProvider.errorMessage != null &&
              !storyProvider.hasLoadedOnce) {
            return Center(
              child:
                  storyProvider.isInternetIssue
                      ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            AppAssets.svgIcons.internet,
                            colorFilter: ColorFilter.mode(
                              AppColors.appPriSecColor.primaryColor,
                              BlendMode.srcIn,
                            ),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              storyProvider.getAllStories();
                            },
                            style: ElevatedButton.styleFrom(
                              fixedSize: Size(
                                SizeConfig.sizedBoxWidth(100),
                                SizeConfig.sizedBoxHeight(40),
                              ),
                              backgroundColor:
                                  AppColors.appPriSecColor.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(AppString.retry),
                          ),
                        ],
                      )
                      : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error,
                              size: 34,
                              color: AppColors.textColor.textGreyColor,
                            ),
                            SizedBox(height: 16),
                            Text(
                              storyProvider.errorMessage ??
                                  'Failed to load media',
                              style: AppTypography.mediumText(context),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                storyProvider.getAllStories();
                              },
                              style: ElevatedButton.styleFrom(
                                fixedSize: Size(
                                  SizeConfig.sizedBoxWidth(100),
                                  SizeConfig.sizedBoxHeight(40),
                                ),
                                backgroundColor:
                                    AppColors.appPriSecColor.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(AppString.retry),
                            ),
                          ],
                        ),
                      ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: SizeConfig.height(1)),
              //*********************************************************/
              //**************** My Status *****************************//
              //*********************************************************/
              myStatusView(context, storyProvider),
              Divider(
                color: AppThemeManage.appTheme.borderColor,
                height: 1,
                thickness: 1.5,
              ),
              //*********************************************************/
              //**************** Recent Updates Status *****************//
              //*********************************************************/
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.appPriSecColor.primaryColor,
                indicatorWeight: 1,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(
                    width: 1.5,
                    color: AppColors.appPriSecColor.primaryColor,
                  ),
                ),
                dividerColor: AppThemeManage.appTheme.borderColor,
                labelColor: AppColors.textColor.textBlackColor,
                padding: EdgeInsets.zero,
                unselectedLabelColor: AppColors.textColor.textGreyColor,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          AppAssets.bottomNavIcons.status,
                          height: 16,
                          color: AppColors.textColor.textDarkGray,
                        ),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            AppString.storyStrings.recentUpdates,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.innerText12Mediu(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          AppAssets.bottomNavIcons.status,
                          height: 16,
                          color: AppColors.textColor.textDarkGray,
                        ),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            AppString.storyStrings.viewedStatus,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.innerText12Mediu(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Recent Updates Content
                    recentUpdates(context, storyProvider),

                    // Viewed Status Content
                    viewedStatus(context, storyProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget myStatusView(BuildContext context, StoryProvider storyProvider) {
    onTapFunction() async {
      storyProvider.clearPickedMedia();
      await storyProvider.getImageFromGallery1(context);

      final selectedFile = storyProvider.selectedMediaFile;
      final selectedType = storyProvider.selectedMediaType;
      // final trimmer = storyProvider.trimmer;
      if (selectedFile == null || selectedType == null) return;

      if (selectedType == 'image') {
        Navigator.pushNamed(context, AppRoutes.storyUpload).then((_) {
          // storyProvider.getAllStories();
          storyProvider.notify();
        });
      } else if (selectedType == 'video') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TrimmerView(selectedFile)),
        ).then((_) {
          storyProvider.getAllStories();
          storyProvider.notify();
        });
      }
    }

    return ListTile(
      leading: Stack(
        children: [
          InkWell(
            onTap: () {
              onTapFunction();
            },
            splashColor: Colors.transparent,
            child: Container(
              height: SizeConfig.sizedBoxHeight(50),
              width: SizeConfig.sizedBoxWidth(50),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bgColor.bg4Color,
                border: Border.all(color: AppThemeManage.appTheme.borderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: CommonProfileAvatar(
                  imageUrl: userProfile,
                  name: "$firstName $lastName".trim(),
                  radius: SizeConfig.sizedBoxHeight(25),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              height: SizeConfig.sizedBoxHeight(12),
              width: SizeConfig.sizedBoxWidth(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.appPriSecColor.secondaryColor,
              ),
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.ibadahGroupIcons.addSvg,
                  color: AppThemeManage.appTheme.bg4BlackColor,
                  height: SizeConfig.sizedBoxHeight(8),
                ),
              ),
            ),
          ),
        ],
      ),
      title: InkWell(
        onTap: () {
          onTapFunction();
        },
        splashColor: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                // userName,
                "$firstName $lastName",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.innerText14(context),
              ),
            ),
            const OwnVerifiedBadge(size: 16, leading: 4),
          ],
        ),
      ),
      subtitle: InkWell(
        onTap: () {
          onTapFunction();
        },
        splashColor: Colors.transparent,
        child: Text(
          AppString.storyStrings.tapToAddYourStory,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.innerText12Mediu(
            context,
          ).copyWith(color: AppColors.textColor.textGreyColor),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          storyProvider.getMyStories.isEmpty
              ? SizedBox.shrink()
              : InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.myStoryView).then((_) {
                    storyProvider.getAllStories();
                    storyProvider.notify();
                  });
                },
                splashColor: Colors.transparent,
                child: SvgPicture.asset(
                  AppAssets.eyeStory,
                  color: AppThemeManage.appTheme.darkWhiteColor,
                  height: SizeConfig.sizedBoxHeight(24),
                ),
              ),
          storyProvider.getMyStories.isEmpty
              ? SizedBox.shrink()
              : Text(
                AppString.myStory, //"My Story",
                style: AppTypography.innerText10(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
              ),
        ],
      ),
    );
  }

  Widget recentUpdates(BuildContext context, StoryProvider storyProvider) {
    List<RecentStories> otherUserStories =
        storyProvider.getRecentStoryList
            .where((story) => story.userId.toString() != userID)
            .toList();
    return otherUserStories.isEmpty
        ? _buildEmptyState(
          icon: AppAssets.emptyDataIcons.emptystatus2,
          title: AppString.emptyDataString.noStatusFound,
          subtitle: AppString.emptyDataString.youdonthaveanystatustoshow,
        )
        : SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.paddingOf(context).bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: SizeConfig.height(1)),
              ListView.separated(
                itemCount: otherUserStories.length,
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: NeverScrollableScrollPhysics(),
                separatorBuilder: (context, index) {
                  return Divider(color: AppThemeManage.appTheme.borderColor);
                },
                itemBuilder: (context, index) {
                  var getStory = otherUserStories[index];

                  // Sort stories by createdAt (oldest first)
                  final sortedStories =
                      getStory.stories!
                        ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

                  // Get the createdAt of the last (most recent) story
                  final lastStoryCreatedAt =
                      sortedStories.isNotEmpty
                          ? sortedStories.last.createdAt!
                          : getStory
                              .createdAt!; // fallback if no stories (unlikely)

                  return statusDesign(
                    context,
                    index,
                    storyProvider,
                    _getDisplayName(otherUserStories[index]),
                    otherUserStories[index].profilePic!,
                    getStory.stories!.length,
                    getStory.viewedCount ?? 0,
                    lastStoryCreatedAt,
                    true,
                    otherUserStories,
                    [],
                    userId: getStory.userId,
                  );
                },
              ),
            ],
          ),
        );
  }

  Widget viewedStatus(BuildContext context, StoryProvider storyProvider) {
    List<ViewedStories> otherUserStories =
        storyProvider.getViewedStoryList
            .where((story) => story.userId.toString() != userID)
            .toList();
    return otherUserStories.isEmpty
        ? _buildEmptyState(
          icon: AppAssets.emptyDataIcons.emptystatus2,
          title: AppString.emptyDataString.noStatusFound,
          subtitle: AppString.emptyDataString.youdonthaveanystatustoshow,
        )
        : SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.paddingOf(context).bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: SizeConfig.height(1)),
              ListView.separated(
                itemCount: otherUserStories.length,
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: NeverScrollableScrollPhysics(),
                separatorBuilder: (context, index) {
                  return Divider(color: AppThemeManage.appTheme.borderColor);
                },
                itemBuilder: (context, index) {
                  var getStory = otherUserStories[index];

                  // Sort stories by createdAt (oldest first)
                  final sortedStories =
                      getStory.stories!
                        ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

                  // Get the createdAt of the last (most recent) story
                  final lastStoryCreatedAt =
                      sortedStories.isNotEmpty
                          ? sortedStories.last.createdAt!
                          : getStory
                              .createdAt!; // fallback if no stories (unlikely)

                  return statusDesign(
                    context,
                    index,
                    storyProvider,
                    _getDisplayName(otherUserStories[index]),
                    otherUserStories[index].profilePic!,
                    getStory.stories!.length,
                    getStory.viewedCount ?? 0,
                    lastStoryCreatedAt,
                    false,
                    [],
                    otherUserStories,
                    userId: getStory.userId,
                  );
                },
              ),
            ],
          ),
        );
  }

  Widget statusDesign(
    BuildContext context,
    int index,
    StoryProvider storyProvider,
    String name,
    String profile,
    int totalStories,
    int seenStories,
    String date,
    bool isRecentStoryView,
    List<RecentStories> recentStoryList,
    List<ViewedStories> viewedStoryList, {
    int? userId,
  }) {
    return ListTile(
      dense: true,
      contentPadding: SizeConfig.getPaddingSymmetric(
        vertical: 0,
        horizontal: 20,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => StoriesView(
                  isMyStory: false,
                  recentStories: recentStoryList,
                  viewedStories: viewedStoryList,
                  initialIndex: index,
                  isRecentStoryView: isRecentStoryView,
                ),
          ),
        ).then((_) {
          setState(() {});
        });
      },
      leading: StatusView(
        radius: 25,
        spacing: 10,
        strokeWidth: 1,
        indexOfSeenStatus: seenStories,
        numberOfStatus: totalStories,
        padding: 5,
        centerImageUrl: profile,
        name: name,
        seenColor: Colors.grey.shade400,
        unSeenColor: AppThemeManage.appTheme.blackPrimary,
      ),
      title: UserNameWithBadge(
        userId: userId,
        name: name,
        style: AppTypography.innerText14(context),
      ),
      subtitle: Text(
        formatStoryDate(date),
        style: AppTypography.smallText(context).copyWith(
          color: AppColors.textColor.textGreyColor,
          fontSize: SizeConfig.getFontSize(11),
        ),
      ),
    );
  }

  Widget titleText(BuildContext context, {required String title}) {
    return Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
      child: Text(
        title,
        style: AppTypography.h4(context).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Future bottomSheetDesigin(BuildContext context, StoryProvider storyProvider) {
    return bottomSheetGobal(
      context,
      insetPadding: SizeConfig.getPaddingOnly(left: 40, right: 40, bottom: 10),
      bottomsheetHeight: SizeConfig.sizedBoxHeight(150),
      title: AppString.settingStrigs.profilePhoto,
      child: Column(
        children: [
          SizedBox(height: SizeConfig.height(3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              bottomContainer(
                context,
                title: AppString.settingStrigs.camera,
                img: AppAssets.svgIcons.camera,
                onTap: () {
                  Navigator.pop(context);
                  getImageFromCamera(storyProvider);
                },
              ),
              SizedBox(width: SizeConfig.width(10)),
              bottomContainer(
                context,
                title: AppString.settingStrigs.gellery,
                img: AppAssets.svgIcons.gellery,
                onTap: () async {
                  Navigator.pop(context); // Close the bottom sheet first

                  await storyProvider.getImageFromGallery1(context);

                  final selectedFile = storyProvider.selectedMediaFile;
                  final selectedType = storyProvider.selectedMediaType;
                  // final trimmer = storyProvider.trimmer;

                  if (selectedFile != null) {
                    if (selectedType == 'image') {
                      Navigator.pushNamed(context, AppRoutes.storyUpload);
                    } else if (selectedType == 'video') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrimmerView(selectedFile),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget bottomContainer(
    BuildContext context, {
    required String title,
    required String img,
    required Function() onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.opacityColor.opacitySecColor,
            ),
            child: Padding(
              padding: SizeConfig.getPadding(12),
              child: Center(child: SvgPicture.asset(img, height: 22)),
            ),
          ),
          SizedBox(height: SizeConfig.height(1)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.captionText(context),
          ),
        ],
      ),
    );
  }

  final picker = ImagePicker();
  Future getImageFromCamera(StoryProvider storyProvider) async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      storyProvider.selectedMediaFile = File(pickedFile.path);
      storyProvider.selectedMediaType = "image";
      storyProvider.notify();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => StoryUpload()),
      );
    } else {
      debugPrint('No image selected.');
    }
  }

  Widget _buildEmptyState({
    required String icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        children: [
          SizedBox(height: SizeConfig.height(25)),
          SvgPicture.asset(
            icon,
            height: SizeConfig.sizedBoxHeight(64),
            color: AppColors.appPriSecColor.secondaryColor,
          ),
          SizedBox(height: 16),
          Text(title, style: AppTypography.h3(context)),
          SizedBox(height: 5),
          Text(
            subtitle,
            style: AppTypography.innerText12Mediu(
              context,
            ).copyWith(color: AppColors.textColor.textGreyColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
