// ignore_for_file: must_be_immutable
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/ads/banner_ad_widget.dart';
import 'package:whoxa/core/services/chat_notification_navigator.dart';
import 'package:whoxa/featuers/ai_assistant/provider/ai_assistant_provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/contacts/screen/contact_list.dart';
import 'package:whoxa/featuers/call/call_history/screens/call_history_screen.dart';
import 'package:whoxa/featuers/home/screens/home_screen.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/featuers/provider/tabbar_provider.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/featuers/subscription/provider/subscription_provider.dart';
import 'package:whoxa/featuers/story/screens/story_list.dart';
import 'package:whoxa/screens/settings/settings.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

class NewTabbarScreen extends StatefulWidget {
  const NewTabbarScreen({super.key});

  @override
  State<NewTabbarScreen> createState() => _NewTabbarScreenState();
}

class _NewTabbarScreenState extends State<NewTabbarScreen>
    with WidgetsBindingObserver {
  final List<dynamic> handlePages = [
    const HomeScreen(),
    // ChatListScreen(),
    const StoryList(),

    // const ContactList(),
    const CallHistoryScreen(),
    const ContactListScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProjectConfigProvider>(
        context,
        listen: false,
      ).fetchNotificationList();
      // Decides whether the home screen shows the AI Assistant button.
      Provider.of<AiAssistantProvider>(context, listen: false).startSession();
      // Opens a chat whose notification was tapped before the tabbar existed
      // (cold start), and lets later taps open chats right away.
      ChatNotificationNavigator.instance.onHomeReady();
      // premium_user (hides ads, shows the blue tick).
      Provider.of<SubscriptionProvider>(context, listen: false).refreshStatus();
    });

    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Picks up renewals / expiry that happened while the app was away.
      Provider.of<SubscriptionProvider>(context, listen: false).refreshStatus();
    }
  }

  @override
  void dispose() {
    ChatNotificationNavigator.instance.onHomeDisposed();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndDocked,
      body: Consumer2<TabbarProvider, LanguageProvider>(
        builder: (context, tabbarProvider, languageProvider, _) {
          return handlePages[tabbarProvider.currentIndex];
        },
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerAdWidget(),
          Consumer3<TabbarProvider, ThemeProvider, LanguageProvider>(
            builder:
                (context, tabbarProvider, themeProvider, languageProvider, _) {
                  return Container(
                    padding: const EdgeInsets.only(bottom: 15, top: 10),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      border: Border.all(
                        color: AppThemeManage.appTheme.transprent,
                      ),
                      color: AppThemeManage.appTheme.scaffoldBackColor,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 36.6,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                          color: AppColors.shadowColor.c000000.withValues(
                            alpha: 0.40,
                          ),
                        ),
                      ],
                    ),
                    child: MediaQuery.removePadding(
                      context: context,
                      removeBottom: true,
                      child: BottomNavigationBar(
                        type: BottomNavigationBarType.fixed,
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        selectedItemColor:
                            AppThemeManage.appTheme.darkWhiteColor,
                        unselectedItemColor: Colors.black,
                        showSelectedLabels: true,
                        showUnselectedLabels: true,
                        currentIndex: tabbarProvider.currentIndex,
                        selectedLabelStyle: AppTypography.footerText10(context)
                            .copyWith(
                              color: AppThemeManage.appTheme.darkWhiteColor,
                            ),
                        onTap: (index) {
                          setState(() {
                            tabbarProvider.currentIndex = index;
                            if (index == 0 || index == 4) {
                              Provider.of<ChatProvider>(
                                context,
                                listen: false,
                              ).countApi();
                            }
                          });
                          if (index == 1) {
                            userProfile;
                            setState(() {});
                          }
                        },
                        items: [
                          tabbarProvider.currentIndex == 0
                              ? BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: newTabbarFooterIcon(
                                      svgImageFill:
                                          AppAssets.bottomNavIcons.homeColor,
                                      image:
                                          AppAssets.bottomNavIcons.homeUnfill,
                                      padding: SizeConfig.getPaddingOnly(
                                        left: 1,
                                      ),
                                      paddingColor: SizeConfig.getPaddingOnly(
                                        top: 2.5,
                                      ),
                                    ),
                                  ),
                                  label: AppString.bottomNavString.chat,
                                )
                              : BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: SvgPicture.asset(
                                      AppAssets.bottomNavIcons.homeUnfill,
                                      colorFilter: ColorFilter.mode(
                                        AppThemeManage.appTheme.darkWhiteColor,
                                        BlendMode.srcIn,
                                      ),
                                      height: SizeConfig.safeHeight(3.5),
                                    ),
                                  ),
                                  label: AppString.bottomNavString.chat,
                                ),
                          tabbarProvider.currentIndex == 1
                              ? BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: newTabbarFooterIcon(
                                      svgImageFill:
                                          AppAssets.bottomNavIcons.statusColor,
                                      image: AppAssets.bottomNavIcons.status,
                                      padding: SizeConfig.getPaddingOnly(
                                        left: 2,
                                      ),
                                      paddingColor: SizeConfig.getPaddingOnly(
                                        top: 2.5,
                                      ),
                                    ),
                                  ),
                                  label: AppString.bottomNavString.status,
                                )
                              : BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: SvgPicture.asset(
                                      AppAssets.bottomNavIcons.status,
                                      height: SizeConfig.safeHeight(3.5),
                                      colorFilter: ColorFilter.mode(
                                        AppThemeManage.appTheme.darkWhiteColor,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  label: AppString.bottomNavString.status,
                                ),
                          tabbarProvider.currentIndex == 2
                              ? BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: newTabbarFooterIcon(
                                      svgImageFill:
                                          AppAssets.bottomNavIcons.callColor,
                                      image:
                                          AppAssets.bottomNavIcons.callUnfill,
                                      height: SizeConfig.safeHeight(3.5),
                                      padding: SizeConfig.getPaddingOnly(
                                        left: 1.3,
                                      ),
                                      paddingColor: SizeConfig.getPaddingOnly(
                                        top: 2,
                                      ),
                                    ),
                                  ),
                                  label: AppString.bottomNavString.call,
                                )
                              : BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: SvgPicture.asset(
                                      AppAssets.bottomNavIcons.call1,
                                      height: SizeConfig.safeHeight(3.5),
                                      colorFilter: ColorFilter.mode(
                                        AppThemeManage.appTheme.darkWhiteColor,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  label: AppString.bottomNavString.call,
                                ),
                          tabbarProvider.currentIndex == 3
                              ? BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: newTabbarFooterIcon(
                                      svgImageFill:
                                          AppAssets.bottomNavIcons.contactColor,
                                      image: AppAssets.bottomNavIcons.contact,
                                      padding: SizeConfig.getPaddingOnly(
                                        left: 2.5,
                                      ),
                                      paddingColor: SizeConfig.getPaddingOnly(
                                        top: 2,
                                      ),
                                    ),
                                  ),
                                  label: AppString.bottomNavString.contact,
                                )
                              : BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: SvgPicture.asset(
                                      AppAssets.bottomNavIcons.contact,
                                      height: SizeConfig.safeHeight(3.5),
                                      colorFilter: ColorFilter.mode(
                                        AppThemeManage.appTheme.darkWhiteColor,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  label: AppString.bottomNavString.contact,
                                ),
                          tabbarProvider.currentIndex == 4
                              ? BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: newTabbarFooterIcon(
                                      svgImageFill:
                                          AppAssets.bottomNavIcons.settingColor,
                                      image: AppAssets.bottomNavIcons.setting,
                                      padding: SizeConfig.getPaddingOnly(
                                        left: 1,
                                      ),
                                      paddingColor: SizeConfig.getPaddingOnly(
                                        top: 2.5,
                                      ),
                                    ),
                                  ),
                                  label: AppString.bottomNavString.setting,
                                )
                              : BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: SvgPicture.asset(
                                      AppAssets.bottomNavIcons.setting,
                                      height: SizeConfig.safeHeight(3.5),
                                      colorFilter: ColorFilter.mode(
                                        AppThemeManage.appTheme.darkWhiteColor,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  label: AppString.bottomNavString.setting,
                                ),
                        ],
                      ),
                    ),
                  );
                },
          ),
        ],
      ),
    );
  }
}
