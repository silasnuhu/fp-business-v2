// ignore_for_file: unused_local_variable

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/call/call_history/providers/call_history_provider.dart';
import 'package:whoxa/featuers/call/call_history/models/call_history_model.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';
import 'package:whoxa/main.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/avatar_initials.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  FocusNode searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchFocusNode = FocusNode();
      // Initialize contact name service for proper contact name resolution
      ContactNameService.instance.loadAndCacheContacts();

      Provider.of<CallHistoryProvider>(
        context,
        listen: false,
      ).fetchCallHistory(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = Provider.of<CallHistoryProvider>(context, listen: false);
      if (provider.hasMoreData && !provider.isLoadingMore) {
        provider.loadMoreCallHistory();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          elevation: 0,
          backgroundColor: AppColors.transparent,
          systemOverlayStyle: systemUI(),
          automaticallyImplyLeading: false,
          title: Text(
            AppString.allCalls,
            style: AppTypography.h2(context).copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: AppTypography.fontFamily.poppinsBold,
            ),
          ), //appDynamicLogo(height: SizeConfig.sizedBoxHeight(31)),
          toolbarHeight: kToolbarHeight,
          actions: [
            Consumer<CallHistoryProvider>(
              builder: (context, provider, _) {
                if (provider.paginationInfo != null) {
                  return provider.paginationInfo!.totalRecords != 0
                      ? provider.callHistory.isNotEmpty
                          ? Text(
                            '${provider.paginationInfo!.totalRecords} ${AppString.allCalls.substring(3)}',
                            style: AppTypography.smallText(context).copyWith(
                              color: AppColors.textColor.textGreyColor,
                              fontWeight: FontWeight.w400,
                            ),
                          )
                          : SizedBox.shrink()
                      : SizedBox.shrink();
                }
                return SizedBox.shrink();
              },
            ),
            SizedBox(width: 20),
          ],
        ),
        body: Column(
          children: [
            // SizedBox(height: SizeConfig.height(2)),
            // // All Calls Header Section
            // Padding(
            //   padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
            //   child: Row(
            //     children: [
            //       SvgPicture.asset(
            //         'assets/images/call_history/AllCalls_header_icon.svg',
            //         height: SizeConfig.safeHeight(2.2),
            //       ),
            //       SizedBox(width: SizeConfig.safeWidth(2.5)),
            //       Text(
            //         'All Calls',
            //         style: AppTypography.h4(context).copyWith(
            //           fontWeight: FontWeight.w600,
            //           fontSize: SizeConfig.getFontSize(18),
            //           color: AppColors.textColor.textBlackColor,
            //         ),
            //       ),
            //       Spacer(),
            //       Consumer<CallHistoryProvider>(
            //         builder: (context, provider, _) {
            //           if (provider.paginationInfo != null) {
            //             return Text(
            //               '${provider.paginationInfo!.totalRecords} calls',
            //               style: AppTypography.smallText(context).copyWith(
            //                 color: AppColors.textColor.textGreyColor,
            //                 fontWeight: FontWeight.w400,
            //               ),
            //             );
            //           }
            //           return SizedBox.shrink();
            //         },
            //       ),
            //     ],
            //   ),
            // ),
            SizedBox(height: SizeConfig.height(1.5)),

            // Add search bar
            // _buildSearchBar(),
            // SizedBox(height: SizeConfig.height(1.5)),

            // Call History List
            Expanded(
              child: Consumer<CallHistoryProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return Center(child: commonLoading());
                  }

                  if (provider.isInternetIssue) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            AppAssets.svgIcons.internet,
                            colorFilter: ColorFilter.mode(
                              AppColors.appPriSecColor.primaryColor,
                              BlendMode.srcIn,
                            ),
                          ),
                          SizedBox(height: SizeConfig.sizedBoxHeight(16)),
                          ElevatedButton(
                            onPressed: () => provider.fetchCallHistory(),
                            child: Text(AppString.retry),
                          ),
                        ],
                      ),
                    );
                  }

                  if (provider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: SizeConfig.safeHeight(8),
                            color: AppColors.textColor.textErrorColor,
                          ),
                          SizedBox(height: SizeConfig.sizedBoxHeight(16)),
                          Text(
                            provider.error!,
                            style: AppTypography.mediumText(context),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: SizeConfig.sizedBoxHeight(16)),
                          ElevatedButton(
                            onPressed: () => provider.fetchCallHistory(),
                            child: Text(AppString.retry),
                          ),
                        ],
                      ),
                    );
                  }

                  if (provider.callHistory.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            AppAssets.emptyDataIcons.emptyCallHistory,
                            height: SizeConfig.safeHeight(11),
                            colorFilter: ColorFilter.mode(
                              AppColors.appPriSecColor.secondaryColor,
                              BlendMode.srcIn,
                            ),
                          ),
                          // SizedBox(height: SizeConfig.height(2)),
                          Text(
                            AppString.emptyDataString.noCall,
                            style: AppTypography.h3(context),
                          ),
                          SizedBox(height: SizeConfig.height(0.5)),
                          Text(
                            AppString.emptyDataString.youdonthavecalllogstoshow,
                            style: AppTypography.innerText12Mediu(
                              context,
                            ).copyWith(
                              color: AppColors.textColor.textGreyColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final groupedHistory = provider.groupedCallHistory;

                  return RefreshIndicator(
                    onRefresh: () => provider.fetchCallHistory(refresh: true),
                    color: AppColors.appPriSecColor.primaryColor,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        bottom:
                            // SizeConfig.sizedBoxHeight(75) +
                            MediaQuery.of(context).padding.bottom + 20,
                      ),
                      scrollDirection: Axis.vertical,
                      itemCount:
                          groupedHistory.length +
                          (provider.hasMoreData || provider.isLoadingMore
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        // Show loading indicator at the end if loading more data
                        if (index == groupedHistory.length) {
                          return _buildLoadMoreWidget(provider);
                        }

                        final dateKey = groupedHistory.keys.elementAt(index);
                        final calls = groupedHistory[dateKey]!;

                        return Container(
                          margin: EdgeInsets.only(
                            bottom: SizeConfig.safeHeight(1.5),
                          ),
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
                                        color: AppColors
                                            .appPriSecColor
                                            .primaryColor
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
                                        color:
                                            AppColors
                                                .appPriSecColor
                                                .primaryColor,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _formatDateKey(dateKey),
                                        style: AppTypography.innerText12Mediu(
                                          context,
                                        ).copyWith(
                                          color: ThemeColorPalette.getTextColor(
                                            AppColors
                                                .appPriSecColor
                                                .primaryColor,
                                          ),
                                          // AppColors
                                          //     .textColor
                                          //     .textBlackColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: AppColors
                                            .appPriSecColor
                                            .primaryColor
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
                                padding: EdgeInsets.symmetric(
                                  vertical: SizeConfig.safeHeight(0.5),
                                ),
                                itemCount: calls.length,
                                separatorBuilder:
                                    (context, index) => Divider(
                                      color: AppColors.textColor.textGreyColor
                                          .withValues(alpha: 0.15),
                                      height: 1,
                                      thickness: 0.5,
                                      indent: SizeConfig.safeWidth(18),
                                      endIndent: SizeConfig.safeWidth(4),
                                    ),
                                itemBuilder:
                                    (context, callIndex) =>
                                        CallHistoryTile(call: calls[callIndex]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildLoadMoreWidget(CallHistoryProvider provider) {
    return Container(
      margin: EdgeInsets.only(
        top: SizeConfig.safeHeight(1),
        bottom: SizeConfig.safeHeight(2),
      ),
      padding: EdgeInsets.symmetric(
        vertical: SizeConfig.safeHeight(2),
        horizontal: SizeConfig.safeWidth(4),
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child:
            provider.isLoadingMore
                ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: SizeConfig.safeWidth(8),
                      height: SizeConfig.safeWidth(8),
                      child: commonLoading(),
                    ),
                    SizedBox(height: SizeConfig.sizedBoxHeight(12)),
                    Text(
                      'Loading more call history...',
                      style: AppTypography.mediumText(context).copyWith(
                        color: AppColors.appPriSecColor.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: SizeConfig.sizedBoxHeight(4)),
                    if (provider.paginationInfo != null)
                      Text(
                        'Page ${provider.currentPage} of ${provider.paginationInfo!.totalPages}',
                        style: AppTypography.smallText(
                          context,
                        ).copyWith(color: AppColors.textColor.textGreyColor),
                      ),
                  ],
                )
                : provider.hasMoreData
                ? GestureDetector(
                  onTap: () => provider.loadMoreCallHistory(),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: SizeConfig.safeHeight(1.5),
                      horizontal: SizeConfig.safeWidth(8),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.appPriSecColor.secondaryColor,
                          AppColors.appPriSecColor.primaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.appPriSecColor.primaryColor
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.expand_more,
                          color: AppColors.white,
                          size: SizeConfig.safeWidth(5),
                        ),
                        SizedBox(width: SizeConfig.safeWidth(2)),
                        Text(
                          'Load More Calls',
                          style: AppTypography.buttonText(context).copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                : Container(
                  padding: EdgeInsets.symmetric(
                    vertical: SizeConfig.safeHeight(1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: AppColors.appPriSecColor.primaryColor,
                        size: SizeConfig.safeWidth(6),
                      ),
                      SizedBox(height: SizeConfig.sizedBoxHeight(8)),
                      Text(
                        'All call history loaded',
                        style: AppTypography.mediumText(context).copyWith(
                          color: AppColors.appPriSecColor.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (provider.paginationInfo != null)
                        Padding(
                          padding: EdgeInsets.only(
                            top: SizeConfig.safeHeight(0.5),
                          ),
                          child: Text(
                            '${provider.paginationInfo!.totalRecords} total calls',
                            style: AppTypography.smallText(context).copyWith(
                              color: AppColors.textColor.textGreyColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      ),
    );
  }

  /// Build search bar widget - Same design as home screen
  // ignore: unused_element
  Widget _buildSearchBar() {
    return Container(
      margin: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 2),
      height: 45, // Fixed compact height
      decoration: BoxDecoration(
        color: AppColors.strokeColor.cF9F9F9,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.strokeColor.cECECEC, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        style: AppTypography.text12(
          context,
        ).copyWith(fontSize: SizeConfig.getFontSize(13)),
        autofocus: false,
        focusNode: searchFocusNode,
        onChanged: (value) {
          // Cancel previous timer
          _searchDebounceTimer?.cancel();

          if (value.trim().isEmpty) {
            // Clear search immediately if empty
            // Add search functionality to CallHistoryProvider
            return;
          }

          // Debounced search - wait 500ms after user stops typing
          _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
            if (value.trim().isNotEmpty) {
              // Add search functionality to CallHistoryProvider
              // provider.searchCallHistory(value.trim());
            }
          });
        },
        decoration: InputDecoration(
          hintText: 'Search call history',
          hintStyle: AppTypography.text12(context).copyWith(
            fontSize: SizeConfig.getFontSize(13),
            color: Colors.grey[600],
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(
              vertical: MediaQuery.of(context).size.height * 0.018,
              horizontal: MediaQuery.of(context).size.width * 0.025,
            ),
            child: SvgPicture.asset(
              AppAssets.homeIcons.search,
              height: MediaQuery.of(context).size.height * 0.03,
              colorFilter: ColorFilter.mode(
                AppColors.textColor.textDarkGray,
                BlendMode.srcIn,
              ),
            ),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 10, minHeight: 10),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: AppColors.textColor.textDarkGray,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      // Clear search in CallHistoryProvider
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: SizeConfig.getPaddingSymmetric(
            horizontal: 12,
            vertical: 8,
          ),
          isDense: true,
        ),
      ),
    );
  }
}

class CallHistoryTile extends StatelessWidget {
  final CallRecord call;

  const CallHistoryTile({super.key, required this.call});

  String _getDisplayName(BuildContext context) {
    final configProvider = Provider.of<ProjectConfigProvider>(
      context,
      listen: false,
    );

    // First try to get caller info from the call
    final caller = call.primaryCall?.caller;
    bool isGpChat = call.chat?.chatType == "group" ? true : false;
    final peeruserName =
        call.peerUser!.isNotEmpty ? call.peerUser!.first.fullName : "";
    final peeruserUSERID =
        call.peerUser!.isNotEmpty ? call.peerUser!.first.userId : 0;
    final bool isSelfUser = peeruserUSERID.toString() != userID;
    logger.v("isSelfUser:$isSelfUser");
    if (caller != null) {
      // Use fullName as fallback when userName is empty
      final contextName =
          caller.userName.isNotEmpty ? caller.userName : caller.fullName;

      // 🎯 FIXED: Use getDisplayNameStable for consistent priority behavior
      return ContactNameService.instance.getDisplayNameStable(
        userId:
            isGpChat
                ? caller.userId
                :
                // isSelfUser
                // ? peeruserUSERID
                // :
                caller.userId,
        configProvider: configProvider,
        contextFullName:
            isGpChat
                ? contextName
                :
                // isSelfUser
                // ? peeruserName
                // :
                contextName, // Pass userName or fullName as context
      );
    }

    // Fallback to the original method if no caller info
    return call.getCallerName();
  }

  String _getInitials(String name) => avatarInitials(name);

  @override
  Widget build(BuildContext context) {
    final callDirection = call.getCallDirection(userID.toString());
    final isVideoCall = call.isVideoCall;
    final callTime = DateTime.parse(call.createdAt).toLocal();
    // final formattedTime =
    //     '${callTime.hour.toString().padLeft(2, '0')}:${callTime.minute.toString().padLeft(2, '0')}';
    final formattedTime = DateFormat('hh:mm a').format(callTime).toLowerCase();

    final displayName = _getDisplayName(context);
    final caller = call.primaryCall?.caller;
    final chatTypeName =
        call.chat?.chatType == "group" ? (call.chat?.groupName ?? "") : "";
    final chatTypeProfile =
        call.chat?.chatType == "group" ? (call.chat?.groupIcon ?? "") : "";

    final peeruserProfile =
        call.peerUser!.isNotEmpty ? call.peerUser!.first.profilePic : "";
    final peeruserUSERID =
        call.peerUser!.isNotEmpty ? call.peerUser!.first.userId : 0;
    final bool isSelfUser = peeruserUSERID.toString() != userID;

    String getCallIconAsset() {
      if (callDirection == 'missed audio') {
        return AppAssets.chatMsgTypeIcon.hMissedAudioCall; //audio missed call
      } else if (callDirection == "missed video") {
        return AppAssets.chatMsgTypeIcon.hMissedVideoCall; //video missed call
      } else if (callDirection == 'incoming audio') {
        return AppAssets
            .chatMsgTypeIcon
            .hIncomingAudioCall; // incoming audio call
      } else if (callDirection == 'incoming video') {
        return AppAssets
            .chatMsgTypeIcon
            .hIncomingVideoCall; // incoming video call
      } else if (callDirection == 'outgoing audio') {
        return AppAssets
            .chatMsgTypeIcon
            .hOutGoingAudioCall; // outgoing audio call
      } else if (callDirection == 'outgoing video') {
        return AppAssets.chatMsgTypeIcon.hOutgoingVideo; // outgoing video call
      } else {
        return AppAssets
            .chatMsgTypeIcon
            .hOutGoingAudioCall; // outgoing audio call
      }
    }

    String getCallTypeText() {
      String callType = '';
      if (callDirection == 'missed audio') {
        callType = 'Missed Audio';
      } else if (callDirection == 'missed video') {
        callType = 'Missed Video';
      } else if (callDirection == 'incoming audio') {
        callType = 'Incoming Audio';
      } else if (callDirection == 'incoming video') {
        callType = 'Incoming Video';
      } else if (callDirection == 'outgoing audio') {
        callType = 'Outgoing Audio';
      } else if (callDirection == 'outgoing video') {
        callType = 'Outgoing Video';
      } else {
        callType = 'Outgoing';
      }

      callType += isVideoCall ? ' Call' : ' Call';
      return callType;
    }

    Color getCallTypeColor() {
      Color callType = AppColors.textColor.textGreyColor;
      if (callDirection == 'missed audio') {
        callType = AppColors.textColor.textErrorColor1;
      } else if (callDirection == 'missed video') {
        callType = AppColors.textColor.textErrorColor1;
      } else if (callDirection == 'incoming audio') {
        callType = AppColors.verifiedColor.c00C32B;
      } else if (callDirection == 'incoming video') {
        callType = AppColors.verifiedColor.c00C32B;
      } else if (callDirection == 'outgoing audio') {
        callType = Color(0xffFCC604);
      } else if (callDirection == 'outgoing video') {
        callType = Color(0xffFCC604);
      } else {
        callType = Color(0xffFCC604);
      }
      return callType;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.safeWidth(4),
        vertical: SizeConfig.safeHeight(1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Avatar
          call.chat?.chatType == "group"
              ? chatTypeProfile.isNotEmpty
                  ? CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(call.chat!.groupIcon),
                    backgroundColor: AppColors.textColor.textGreyColor
                        .withValues(alpha: 0.3),
                    onBackgroundImageError: (exception, stackTrace) {
                      // Handle image loading error
                    },
                  )
                  : CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.textColor.textGreyColor
                        .withValues(alpha: 0.7),
                    child: Text(
                      _getInitials(call.chat?.groupName ?? ""),
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  )
              :
              // isSelfUser
              // ? CircleAvatar(
              //   radius: 24,
              //   backgroundImage: NetworkImage(peeruserProfile.toString()),
              //   backgroundColor: AppColors.textColor.textGreyColor.withValues(
              //     alpha: 0.3,
              //   ),
              //   onBackgroundImageError: (exception, stackTrace) {
              //     // Handle image loading error
              //   },
              // )
              // :
              caller?.profilePic != null && caller!.profilePic.isNotEmpty
              ? CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(caller.profilePic),
                backgroundColor: AppColors.textColor.textGreyColor.withValues(
                  alpha: 0.3,
                ),
                onBackgroundImageError: (exception, stackTrace) {
                  // Handle image loading error
                },
              )
              : CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.textColor.textGreyColor.withValues(
                  alpha: 0.7,
                ),
                child: Text(
                  _getInitials(displayName),
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
          SizedBox(width: SizeConfig.safeWidth(3)),
          // Call Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Contact Name
                chatTypeName.isNotEmpty
                    ? RichText(
                      maxLines: 1,
                      textAlign: TextAlign.start,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: chatTypeName,
                            style: AppTypography.innerText14(
                              context,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: " ▸ ",
                            style: AppTypography.innerText14(
                              context,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: displayName,
                            style: AppTypography.innerText14(
                              context,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: PremiumBadge(userId: caller?.userId),
                          ),
                        ],
                      ),
                    )
                    : UserNameWithBadge(
                      userId: caller?.userId,
                      name: displayName,
                      style: AppTypography.innerText14(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                SizedBox(height: SizeConfig.safeHeight(0.3)),
                // Call Type with Icon
                Row(
                  children: [
                    SvgPicture.asset(
                      getCallIconAsset(),
                      height: SizeConfig.safeWidth(3.5),
                    ),
                    SizedBox(width: SizeConfig.safeWidth(1)),
                    Text(
                      getCallTypeText(),
                      style: AppTypography.innerText12Mediu(context).copyWith(
                        color:
                            getCallTypeColor(), //AppColors.textColor.textGreyColor
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Time and Date
          SizedBox(width: SizeConfig.safeWidth(0.3)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                '${callTime.day.toString().padLeft(2, '0')}/${callTime.month.toString().padLeft(2, '0')}/${callTime.year.toString().substring(2)}',
                style: AppTypography.innerText10(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
              ),
              SizedBox(height: SizeConfig.safeHeight(0.3)),
              Text(
                formattedTime,
                style: AppTypography.innerText10(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
