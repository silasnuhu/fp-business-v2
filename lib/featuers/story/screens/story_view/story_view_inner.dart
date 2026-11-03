import 'dart:developer';
import 'dart:ui';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/provider/tabbar_provider.dart';
import 'package:whoxa/featuers/story/data/model/model.dart';
import 'package:whoxa/featuers/story/provider/story_provider.dart';
import 'package:whoxa/featuers/story/screens/story_view/message_box_view.dart';
import 'package:whoxa/featuers/story/screens/story_view/my_story_viewed_list.dart';
import 'package:whoxa/featuers/story/screens/story_view/profile_view.dart';
import 'package:whoxa/main.dart';
import 'package:whoxa/screens/new_tabbar.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/enums.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/packages/story/src/controller/flutter_story_controller.dart';
import 'package:whoxa/utils/packages/story/src/models/story_view_indicator_config.dart';
import 'package:whoxa/utils/packages/story/src/utils/story_utils.dart';
import 'package:whoxa/utils/packages/story/src/story_presenter/story_view.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';

class MyStoryView extends StatefulWidget {
  const MyStoryView({
    super.key,
    required this.storyModel,
    required this.pageController,
    required this.currentIndex,
    required this.totalUsers,
    required this.isMyStory,
    this.onComplete,
    this.initialIndex = 0,
    this.pauseNotifier,
  });

  final List<StoryModel> storyModel;
  final PageController pageController;
  final int currentIndex;
  final int totalUsers;
  final bool isMyStory;
  final VoidCallback? onComplete;
  final int initialIndex;

  /// When true (e.g. an interstitial ad is showing) the story is paused.
  final ValueListenable<bool>? pauseNotifier;

  @override
  State<MyStoryView> createState() => _MyStoryViewState();
}

class _MyStoryViewState extends State<MyStoryView> with WidgetsBindingObserver {
  late FlutterStoryController controller;
  TextEditingController msgControllerl = TextEditingController();
  final ConsoleAppLogger _logger = ConsoleAppLogger();
  bool completedOnce = false;
  bool disposed = false;
  ChatProvider? _chatProvider;
  int currentStoryIndex = 0;
  // ignore: unused_field
  String? _storyCaption;
  String? _storyTime; // 👈 keep time in state
  String? _storyID;

  @override
  void initState() {
    debugPrint("currentIndex:${widget.currentIndex}");
    controller = FlutterStoryController();
    WidgetsBinding.instance.addObserver(this);
    widget.pauseNotifier?.addListener(_onPauseChanged);

    if (widget.storyModel[widget.currentIndex].stories.isNotEmpty) {
      final firstStory = widget.storyModel[widget.currentIndex].stories[0];
      if (firstStory is CustomStoryItem) {
        _storyTime = firstStory.storyTime;
        _storyCaption = firstStory.storyCaption;
        _storyID = firstStory.storyId;
      }
    }
    super.initState();
  }

  @override
  void dispose() {
    disposed = true;
    // controller.dispose();
    msgControllerl.dispose();
    widget.pauseNotifier?.removeListener(_onPauseChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int _currentStoryIndex = 0;

  void _onPauseChanged() {
    // Only the page the user is on reacts; neighbouring pages stay idle.
    final page = widget.pageController.page?.round();
    if (page != widget.currentIndex) return;
    _safeControllerCall(() {
      if (widget.pauseNotifier?.value ?? false) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  void _safeControllerCall(VoidCallback callback) {
    if (!disposed && mounted) {
      callback();
    }
  }

  @override
  void didChangeMetrics() {
    if (disposed) return;
    // Window metrics also change when the ad activity opens; don't let that
    // resume a story the ad has paused.
    if (widget.pauseNotifier?.value ?? false) return;
    final bottomInset =
        WidgetsBinding
            .instance
            .platformDispatcher
            .views
            .first
            .viewInsets
            .bottom;
    _safeControllerCall(() {
      if (bottomInset > 0) {
        controller.pause();
      } else {
        controller.play();
      }
    });

    super.didChangeMetrics();
  }

  @override
  Widget build(BuildContext context) {
    final storyViewIndicatorConfig = StoryViewIndicatorConfig(
      height: 2,
      activeColor: Colors.white,
      backgroundCompletedColor: Colors.white,
      backgroundDisabledColor: Colors.white.withValues(alpha: 0.5),
      horizontalGap: 1,
      borderRadius: 1.5,
    );

    return Consumer2<StoryProvider, ChatProvider>(
      builder: (context, storyProvider, chatProvider, _) {
        final isLoading = chatProvider.isSendingMessage;
        final stories = widget.storyModel[widget.currentIndex].stories;
        return FlutterStoryPresenter(
          flutterStoryController: controller,
          items: stories, //widget.storyModel[widget.currentIndex].stories,
          storyViewIndicatorConfig: storyViewIndicatorConfig,
          initialIndex: widget.initialIndex,
          onStoryChanged: (index) async {
            if (!mounted || disposed) return;

            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted || disposed) return;
              if (index < 0 || index >= stories.length) {
                debugPrint("⚠ Invalid story index: $index");
                return;
              }

              _currentStoryIndex = index;
              debugPrint("_currentStoryIndex:$_currentStoryIndex");
              final story = stories[_currentStoryIndex];

              if (!widget.isMyStory) {
                log("→→→→TO_USER_STORY_SEEN:");

                if (story is CustomStoryItem) {
                  debugPrint("Story_seen: $index");
                  debugPrint("Story_ID: ${story.storyId}");

                  setState(() {
                    _storyCaption = story.storyCaption;
                    _storyTime = story.storyTime;
                    _storyID = story.storyId;
                    storyID = _storyID;
                    stroyCaption = _storyCaption ?? "";
                  });

                  debugPrint("StoryTimeToUser: $_storyTime");
                  storyProvider.notify();
                  await storyProvider.viewStory(storyID: story.storyId);
                  storyProvider.notify();
                }
              } else {
                log("→→→→MY_STORY_SEEN:");
                storyProvider.storyID = story.storyID.toString();

                if (story is CustomStoryItem) {
                  debugPrint("Story_ID2: ${story.storyId}");

                  setState(() {
                    _storyCaption = story.storyCaption;
                    _storyTime = story.storyTime;
                    _storyID = story.storyId;
                    storyID = _storyID;
                    stroyCaption = _storyCaption ?? "";
                  });

                  debugPrint("StoryTimeMy: $_storyTime");
                  storyProvider.notify();
                  await storyProvider.getViewedList(storyID: story.storyId);
                  storyProvider.notify();
                }
              }
            });
          },
          onPreviousCompleted: () async {
            if (disposed) return;
            _safeControllerCall(() => controller.pause());
            await Future.delayed(const Duration(milliseconds: 200));
            if (widget.currentIndex > 0) {
              await widget.pageController.previousPage(
                duration: const Duration(milliseconds: 500),
                curve: Curves.decelerate,
              );
            }
          },
          onSlideDown: (DragUpdateDetails details) {
            if (disposed) return;
            if (details.delta.dy > 10) {
              _safeControllerCall(() => controller.pause());
              Navigator.pop(context);
            }
          },

          onCompleted: () async {
            if (completedOnce || disposed) return;
            completedOnce = true;

            _safeControllerCall(() => controller.pause());
            debugPrint("currentIndex😀:${widget.currentIndex}");
            debugPrint("totalUsers:😀:${widget.totalUsers}");
            debugPrint("😀Story complete at index: ${widget.currentIndex}");
            widget.onComplete?.call(); // 👈 notify parent
            final bool isLastStory =
                widget.currentIndex == widget.totalUsers - 1;

            if (isLastStory) {
              if (mounted) Navigator.pop(context);
              return;
            }

            // Not last story → move to next
            await Future.delayed(const Duration(milliseconds: 100));
            await widget.pageController.nextPage(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
            completedOnce = false;
          },
          footerWidget:
              widget.isMyStory
                  ? MyStoryViewList(
                    controller: controller,
                    storycaption: stroyCaption,
                  )
                  : MessageBoxView(
                    controller: controller,
                    msgController: msgControllerl,
                    storycaption: stroyCaption,
                    childSendBtn: InkWell(
                      onTap: () {
                        if (mounted &&
                            !isLoading &&
                            msgControllerl.text.trim().isNotEmpty) {
                          _sendTextMessage(
                            toUserID:
                                widget.storyModel[widget.currentIndex].userID,
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.gradientColor.gradientColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          child:
                              isLoading
                                  ? SizedBox(
                                    height: SizeConfig.sizedBoxHeight(25),
                                    width: SizeConfig.sizedBoxWidth(25),
                                    child: commonLoading2(),
                                  )
                                  : Image.asset(
                                    AppAssets.send,
                                    height: SizeConfig.sizedBoxHeight(24),
                                    width: SizeConfig.sizedBoxWidth(24),
                                    color: AppColors.black,
                                  ),
                        ),
                      ),
                    ),
                  ),
          headerWidget: ProfileView(
            userName: widget.storyModel[widget.currentIndex].userName,
            userProfile: widget.storyModel[widget.currentIndex].userProfile,
            fName: widget.storyModel[widget.currentIndex].fName,
            lName: widget.storyModel[widget.currentIndex].lName,
            isMyStory: widget.isMyStory,
            userId: int.tryParse(widget.storyModel[widget.currentIndex].userID),
            storyTime: _storyTime ?? "",
            onPauseRequested: () {
              _safeControllerCall(() => controller.pause());
              if (widget.isMyStory) {
                final story =
                    widget
                        .storyModel[widget.currentIndex]
                        .stories[_currentStoryIndex];

                if (story is CustomStoryItem) {
                  debugPrint("Story_ID_REMOVE: ${story.storyId}");
                  deleteDialo(
                    context,
                    storyProvider: storyProvider,
                    storyId: story.storyId,
                    index: widget.currentIndex,
                  ).whenComplete(() {
                    logger.i(
                      "storyProvider.isDeleteDialogClose:${storyProvider.isDeleteDialogClose}",
                    );
                    if (storyProvider.isDeleteDialogClose == true) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  });
                }
              }
            },
          ),
        );
      },
    );
  }

  Future deleteDialo(
    BuildContext context, {
    required StoryProvider storyProvider,
    required String storyId,
    required int index,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.57),
      builder:
          (_) => Dialog(
            alignment: Alignment.bottomCenter,
            elevation: 0,
            insetPadding: EdgeInsets.only(left: 10, right: 10, bottom: 10),
            backgroundColor: AppColors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3.8, sigmaY: 3.8),
              child: InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  storyProvider.deleteDialogClose(true);
                  // controller.pause();
                  await deleteStoryDialog(
                    context,
                    storyProvider: storyProvider,
                    storyid: storyId,
                    index: index,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppThemeManage.appTheme.darkGreyColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  height: SizeConfig.sizedBoxHeight(60),
                  width: SizeConfig.screenWidth,
                  child: Row(
                    children: [
                      SizedBox(width: SizeConfig.width(5)),
                      SvgPicture.asset(
                        AppAssets.trash,
                        colorFilter: ColorFilter.mode(
                          AppThemeManage.appTheme.darkWhiteColor,
                          BlendMode.srcIn,
                        ),
                        height: SizeConfig.sizedBoxHeight(20),
                      ),
                      SizedBox(width: SizeConfig.width(2)),
                      Text(AppString.delete, style: AppTypography.h4(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Future deleteStoryDialog(
    BuildContext parentContext, {
    required StoryProvider storyProvider,
    required String storyid,
    required int index,
  }) {
    return bottomSheetGobalWithoutTitle(
      parentContext,
      isCrossIconHide: true,
      bottomsheetHeight: SizeConfig.height(25),
      insetPadding: SizeConfig.getPaddingSymmetric(
        horizontal: 10,
      ).copyWith(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.height(3.5)),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
            child: Text(
              AppString.storyStrings.areYouSureYouWantTo,
              textAlign: TextAlign.start,
              style: AppTypography.innerText16(parentContext),
            ),
          ),
          SizedBox(height: SizeConfig.height(3)),
          Padding(
            padding: SizeConfig.getPaddingOnly(left: 30, right: 60),
            child: Text(
              AppString.storyStrings.areYouSureYouWantToDelet,
              textAlign: TextAlign.start,
              style: AppTypography.captionText(
                parentContext,
              ).copyWith(color: AppColors.textColor.textGreyColor),
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
                  parentContext,
                  onTap: () {
                    controller.play();
                    storyProvider.deleteDialogClose(false);
                    Navigator.pop(parentContext);
                  },
                  title: AppString.cancel,
                ),
              ),
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: customBtn2(
                  parentContext,
                  onTap: () async {
                    final success = await storyProvider.removeStoryApi(
                      storyid: storyid,
                    );
                    if (!parentContext.mounted) return;
                    if (success) {
                      final currentStories =
                          storyProvider.myStory[widget.currentIndex].stories;

                      setState(() {
                        // remove the story
                        currentStories.removeWhere(
                          (story) =>
                              story is CustomStoryItem &&
                              story.storyId == storyid,
                        );

                        if (currentStories.isEmpty) {
                          // no stories left for this user
                          storyProvider.myStory.removeAt(widget.currentIndex);

                          if (storyProvider.myStory.isEmpty) {
                            debugPrint("story_Remove_0");
                            // Navigator.pop(parentContext);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NewTabbarScreen(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                            return;
                          }

                          // ✅ Case 2: Removed last story (index now out of range)
                          if (index >= storyProvider.myStory.length) {
                            debugPrint("story_Remove_1");
                            Navigator.pop(parentContext);
                            return;
                          }
                        }
                      });

                      // refresh UI
                      storyProvider.notify();

                      // ✅ Only pop if story list still valid
                      if (index < storyProvider.myStory.length &&
                          storyProvider.myStory[index].stories.isNotEmpty) {
                        if (_currentStoryIndex >= currentStories.length) {
                          _currentStoryIndex = currentStories.length - 1;
                        }

                        debugPrint(
                          "story_Remove_2 -> showing story index $_currentStoryIndex",
                        );
                        // Navigator.pop(context); // close current story view
                        if (!mounted) return;
                        Provider.of<TabbarProvider>(
                          context,
                          listen: false,
                        ).navigateToIndex(1);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NewTabbarScreen(),
                          ),
                          (Route<dynamic> route) => false,
                        );
                      }
                    } else {
                      snackbarNew(
                        parentContext,
                        msg: storyProvider.errorMessage.toString(),
                      );
                    }
                  },
                  child:
                      storyProvider.isRemove
                          ? SizedBox(
                            height: SizeConfig.sizedBoxHeight(25),
                            width: SizeConfig.sizedBoxWidth(25),
                            child: CircularProgressIndicator(
                              strokeWidth: 1,
                              color: AppColors.black,
                            ),
                          )
                          : Text(
                            AppString.settingStrigs.delete,
                            style: AppTypography.buttonText(context).copyWith(
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

  void _sendTextMessage({required String toUserID}) {
    if (!mounted || msgControllerl.text.trim().isEmpty) return;

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
    final chatId = 0;

    _logger.d(
      "Sending message to ${chatId == 0 ? 'new user' : 'existing chat'}: $toUserID",
    );
    chatProvider.storyid = storyID;

    // Snapshot the story being replied to. NEW has no server-side story
    // wiring on a message (§6.8) — the reply goes out as
    // `type: 'feed_reference'` and this whole map rides along in the
    // message `metadata` bag so the other side can rebuild the story
    // preview (MessageAdapter._storyFromMetadata).
    final owner = widget.storyModel[widget.currentIndex];
    final stories = owner.stories;
    final currentItem =
        (_currentStoryIndex >= 0 && _currentStoryIndex < stories.length)
            ? stories[_currentStoryIndex]
            : (stories.isNotEmpty ? stories.first : null);
    final customItem = currentItem is CustomStoryItem ? currentItem : null;
    final ownerFullName = [
      owner.fName,
      owner.lName,
    ].where((s) => s.trim().isNotEmpty).join(' ');
    // Keys follow the story-reply metadata contract (storyId, storyOwnerId,
    // storyType, storyMediaUrl, storyThumbnailUrl, storyCaption); the
    // owner* display fields are extras for the bubble header.
    final storyType = switch (customItem?.storyItemType) {
      StoryItemType.video => 'video',
      StoryItemType.text => 'text',
      _ => 'image',
    };
    final mediaUrl = customItem?.url;
    // Only video stories carry a separate poster; for an image story the
    // image itself is the thumbnail.
    final thumbnailUrl =
        (customItem?.thumbnailUrl ?? '').trim().isNotEmpty
            ? customItem!.thumbnailUrl
            : (storyType == 'image' ? mediaUrl : null);
    chatProvider.storyReplyContext = <String, dynamic>{
      if (storyID != null) 'storyId': storyID,
      'storyOwnerId': owner.userID,
      'storyType': storyType,
      'storyMediaUrl': (mediaUrl ?? '').trim().isNotEmpty ? mediaUrl : null,
      'storyThumbnailUrl': thumbnailUrl,
      'storyCaption':
          (customItem?.storyCaption ?? '').trim().isNotEmpty
              ? customItem!.storyCaption
              : null,
      'ownerUserId': owner.userID,
      if (owner.userName.trim().isNotEmpty) 'ownerUserName': owner.userName,
      if (ownerFullName.isNotEmpty) 'ownerFullName': ownerFullName,
      if (owner.userProfile.trim().isNotEmpty)
        'ownerProfilePic': owner.userProfile,
    };

    chatProvider
        .sendMessage(
          userId: int.parse(toUserID),
          msgControllerl.text.trim(),
          messageType: MessageType.StoryReply,
          chatId: chatId,
        )
        .then((success) {
          if (mounted) {
            if (success) {
              msgControllerl.clear();
              _sendTypingEvent(false, toUserID);
              snackbarNew(context, msg: "Your reply has been sent");
              Navigator.pop(context);
            } else {
              // Check if there's an API error message to show
              final apiError = chatProvider.apiErrorMessage;
              if (apiError != null && apiError.isNotEmpty) {
                snackbarNew(context, msg: apiError);
                chatProvider.clearApiErrorMessage();
              }
            }
          }
        });
  }

  void _sendTypingEvent(bool isTyping, touserid) {
    if (!mounted) return;

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

    final currentChatId = chatProvider.currentChatData.chatId ?? 0;

    _logger.d(
      "Sending typing event - ChatId: $currentChatId, UserId: $touserid, IsTyping: $isTyping",
    );

    chatProvider.sendTypingStatus(currentChatId, isTyping);
  }
}
