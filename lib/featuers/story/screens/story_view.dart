// ignore_for_file: library_private_types_in_public_api

import 'dart:math';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/ads/interstitial_ad_service.dart';
import 'package:whoxa/featuers/story/data/model/model.dart';
import 'package:whoxa/featuers/story/provider/story_provider.dart';
import 'package:whoxa/featuers/story/screens/story_view/story_view_inner.dart';
import 'package:whoxa/main.dart';
import 'package:whoxa/utils/packages/story/src/controller/flutter_story_controller.dart';
import 'package:whoxa/utils/packages/story/src/models/story_view_image_config.dart';
import 'package:whoxa/utils/packages/story/src/models/story_view_video_config.dart';
import 'package:whoxa/utils/packages/story/src/utils/story_utils.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/featuers/story/data/model/get_all_story_model.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';

class StoriesView extends StatefulWidget {
  final bool isMyStory;
  final List<RecentStories> recentStories;
  final List<ViewedStories> viewedStories;
  final int initialIndex;
  final bool isRecentStoryView;
  final int initialStoryIndex;
  const StoriesView({
    super.key,
    required this.isMyStory,
    required this.recentStories,
    required this.viewedStories,
    required this.initialIndex,
    required this.isRecentStoryView,
    this.initialStoryIndex = 0,
  });

  @override
  _StoriesViewState createState() => _StoriesViewState();
}

class _StoriesViewState extends State<StoriesView> {
  PageController pageController = PageController();
  double currentPageValue = 0.0;

  // Show an interstitial every [_adEveryNthUserChange] times the viewer moves
  // from one user's stories to another's (opening the first story never
  // shows one).
  static const int _adEveryNthUserChange = 2;
  int _userChangeCount = 0;
  int _lastPage = -1;

  // True while the interstitial is on screen; story pages pause meanwhile.
  final ValueNotifier<bool> _adShowing = ValueNotifier<bool>(false);

  void _onUserPageChanged(int page) {
    if (_lastPage != -1 && page != _lastPage) {
      _userChangeCount++;
      if (_userChangeCount % _adEveryNthUserChange == 0) {
        InterstitialAdService.instance.showIfReady(
          onShown: () => _adShowing.value = true,
          onClosed: () => _adShowing.value = false,
        );
      }
    }
    _lastPage = page;
  }

  @override
  void initState() {
    logger.i("intialIndex:${widget.initialIndex}");
    pageController = PageController(initialPage: widget.initialIndex);
    _lastPage = widget.initialIndex;
    InterstitialAdService.instance.load();

    setState(() {});
    super.initState();
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
  void dispose() {
    pageController.dispose();
    _adShowing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Material(
        color: Colors.black.withValues(alpha: 0.95),
        child: Scaffold(
          backgroundColor: AppColors.transparent,
          body: Consumer<StoryProvider>(
            builder: (context, storyProvider, _) {
              storyProvider.recentStory.clear();
              storyProvider.viewedStory.clear();
              if (widget.isRecentStoryView) {
                for (int j = 0; j < widget.recentStories.length; j++) {
                  storyProvider.recentStory.add(
                    StoryModel(
                      userID: widget.recentStories[j].userId.toString(),
                      userName: _getDisplayName(widget.recentStories[j]),
                      userProfile: widget.recentStories[j].profilePic ?? '',
                      fName: widget.recentStories[j].firstName ?? '',
                      lName: widget.recentStories[j].lastName ?? '',
                      stories: widget.recentStories[j].stories?.reversed
                              .map((e) {
                            if (e.storyType == "image") {
                              return CustomStoryItem(
                                storyId: e.storyId.toString(),
                                url: e.media,
                                thumbnailUrl: e.thumbnail,
                                storyCaption: e.caption ?? "",
                                storyTime: e.createdAt ?? "",
                                userID:
                                    widget.recentStories[j].userId.toString(),
                                storyItemType: StoryItemType.image,
                                duration: const Duration(seconds: 10),
                                imageConfig: StoryViewImageConfig(
                                  fit: BoxFit.contain,
                                  progressIndicatorBuilder: (_, _, _) {
                                    return Center(child: commonLoading());
                                  },
                                ),
                              );
                            } else {
                              return CustomStoryItem(
                                storyId: e.storyId.toString(),
                                url: e.media,
                                thumbnailUrl: e.thumbnail,
                                storyCaption: e.caption ?? "",
                                storyTime: e.createdAt ?? "",
                                userID:
                                    widget.recentStories[j].userId.toString(),
                                storyItemType: StoryItemType.video,
                                videoConfig: StoryViewVideoConfig(
                                  cacheVideo: true,
                                  fit: BoxFit.none,
                                  useVideoAspectRatio: true,
                                  loadingWidget: Center(child: commonLoading()),
                                ),
                              );
                            }
                          }).toList() ??
                          const <CustomStoryItem>[],
                    ),
                  );
                }
              } else {
                for (int j = 0; j < widget.viewedStories.length; j++) {
                  storyProvider.viewedStory.add(
                    StoryModel(
                      userID: widget.viewedStories[j].userId.toString(),
                      userName: _getDisplayName(widget.viewedStories[j]),
                      userProfile: widget.viewedStories[j].profilePic ?? '',
                      fName: widget.viewedStories[j].firstName ?? '',
                      lName: widget.viewedStories[j].lastName ?? '',
                      stories: widget.viewedStories[j].stories?.map((e) {
                            if (e.storyType == "image") {
                              return CustomStoryItem(
                                storyId: e.storyId.toString(),
                                url: e.media,
                                thumbnailUrl: e.thumbnail,
                                userID:
                                    widget.viewedStories[j].userId.toString(),
                                storyCaption: e.caption ?? "",
                                storyTime: e.createdAt ?? "",
                                storyItemType: StoryItemType.image,
                                duration: const Duration(seconds: 10),
                                imageConfig: StoryViewImageConfig(
                                  fit: BoxFit.contain,
                                  progressIndicatorBuilder: (_, _, _) {
                                    return Center(child: commonLoading());
                                  },
                                ),
                              );
                            } else {
                              return CustomStoryItem(
                                storyId: e.storyId.toString(),
                                url: e.media,
                                thumbnailUrl: e.thumbnail,
                                userID:
                                    widget.viewedStories[j].userId.toString(),
                                storyCaption: e.caption ?? "",
                                storyTime: e.createdAt ?? "",
                                storyItemType: StoryItemType.video,
                                videoConfig: StoryViewVideoConfig(
                                  cacheVideo: true,
                                  fit: BoxFit.none,
                                  useVideoAspectRatio: true,
                                  loadingWidget: Center(child: commonLoading()),
                                ),
                              );
                            }
                          }).toList() ??
                          const <CustomStoryItem>[],
                    ),
                  );
                }
              }
              return PageView.builder(
                controller: pageController,
                onPageChanged: _onUserPageChanged,
                itemCount: widget.isRecentStoryView
                    ? storyProvider.recentStory.length
                    : storyProvider.viewedStory.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: pageController,
                    child: MyStoryView(
                      storyModel: widget.isRecentStoryView
                          ? storyProvider.recentStory
                          : storyProvider.viewedStory,
                      pageController: pageController,
                      currentIndex: index,
                      totalUsers: widget.isRecentStoryView
                          ? widget.recentStories.length
                          : widget.viewedStories.length,
                      isMyStory: widget.isMyStory,
                      pauseNotifier: _adShowing,
                      onComplete: () {
                        if (widget.isRecentStoryView) {
                          debugPrint("✅ Completed a RECENT story");
                          storyProvider.getAllStories();
                        } else {
                          debugPrint("✅ Completed a VIEWED story");
                        }
                      },
                      initialIndex: widget.initialStoryIndex,
                    ),
                    builder: (context, child) {
                      if (pageController.position.hasContentDimensions) {
                        currentPageValue = pageController.page ?? 0.0;
                        final isLeaving = (index - currentPageValue) <= 0;
                        final t = (index - currentPageValue);
                        final rotationY = lerpDouble(0, 30, t)!;
                        const maxOpacity = 0.8;
                        final num opacity = lerpDouble(
                          0,
                          maxOpacity,
                          t.abs(),
                        )!
                            .clamp(0.0, maxOpacity);
                        final isPaging = opacity != maxOpacity;
                        final transform = Matrix4.identity();
                        transform.setEntry(3, 2, 0.003);
                        transform.rotateY(-rotationY * (pi / 180.0));
                        return Transform(
                          alignment: isLeaving
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          transform: transform,
                          child: Stack(
                            children: [
                              child!,
                              if (isPaging && !isLeaving)
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: opacity as double,
                                    child: const ColoredBox(
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      return child!;
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// Custom Widget - Question
class TextOverlayView extends StatelessWidget {
  const TextOverlayView({super.key, required this.controller});

  final FlutterStoryController? controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
        image: DecorationImage(
          fit: BoxFit.cover,
          image: CachedNetworkImageProvider(
            'https://images.pexels.com/photos/1761279/pexels-photo-1761279.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 30,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "What’s your favorite outdoor activity and why?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: IntrinsicWidth(
                        child: TextFormField(
                          onTap: () {
                            controller?.pause();
                          },
                          onTapOutside: (event) {
                            // controller?.play();
                            FocusScope.of(context).unfocus();
                          },
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Type something...',
                            hintStyle: TextStyle(
                              color: Colors.black.withValues(alpha: 0.6),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -40,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xffE2DCFF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: CachedNetworkImage(
                    imageUrl: 'https://devkrest.com/logo/devkrest_outlined.png',
                    height: 40,
                    width: 40,
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

// Custom Widget - Post View
class PostOverlayView extends StatelessWidget {
  const PostOverlayView({super.key, required this.controller});

  final FlutterStoryController? controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xffff8800), Color(0xffff3300)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: IntrinsicWidth(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xffE2DCFF),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: CachedNetworkImage(
                            imageUrl:
                                'https://devkrest.com/logo/devkrest_outlined.png',
                            height: 15,
                            width: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'devkrest',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  CachedNetworkImage(
                    height: MediaQuery.of(context).size.height * 0.40,
                    fit: BoxFit.cover,
                    imageUrl:
                        'https://scontent.cdninstagram.com/v/t51.29350-15/448680084_2197193763952189_5110658492947027914_n.webp?stp=dst-jpg_e35&efg=eyJ2ZW5jb2RlX3RhZyI6ImltYWdlX3VybGdlbi4xNDQweDE4MDAuc2RyLmYyOTM1MCJ9&_nc_ht=scontent.cdninstagram.com&_nc_cat=1&_nc_ohc=VtYwOfs3y44Q7kNvgEfDjM0&edm=APs17CUBAAAA&ccb=7-5&ig_cache_key=MzM5MzIyNzQ4MjcwNjA5NzYzNQ%3D%3D.2-ccb7-5&oh=00_AYAEOmKhroMeZensvVXMuCbC8rB0vr_0P7-ecR8AKLk5Lw&oe=6678548B&_nc_sid=10d13b',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Text(
                      "India vs Afganistan",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w400,
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Widget - Audio View - 1
class AudioCustomView1 extends StatelessWidget {
  const AudioCustomView1({
    super.key,
    required this.controller,
    this.audioPlayer,
  });

  final FlutterStoryController? controller;
  final AudioPlayer? audioPlayer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
        image: DecorationImage(
          fit: BoxFit.cover,
          image: CachedNetworkImageProvider(
            'https://images.pexels.com/photos/1761279/pexels-photo-1761279.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 130),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/story/img.png',
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    StreamBuilder<bool>(
                      stream: audioPlayer?.playingStream,
                      builder: (context, snapshot) {
                        if (snapshot.data == false) {
                          return const SizedBox();
                        }
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.black.withValues(alpha: 0.54),
                          ),
                          height: 50,
                          width: 50,
                          padding: const EdgeInsets.all(5),
                          child: Image.asset(
                            'assets/story/audio-anim__.gif',
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Don't Give Up on Me",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Andy grammer",
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
