import 'dart:math';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/story/provider/story_provider.dart';
import 'package:whoxa/featuers/story/screens/story_view/story_view_inner.dart';
import 'package:whoxa/main.dart';
import 'package:whoxa/utils/packages/story/flutter_story_presenter.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

class MyStoriesView extends StatefulWidget {
  final bool isMyStory;
  final int initialIndex;
  final int initialStoryIndex;

  const MyStoriesView({
    super.key,
    required this.isMyStory,
    required this.initialIndex,
    this.initialStoryIndex = 0,
  });

  @override
  // ignore: library_private_types_in_public_api
  _MyStoriesViewState createState() => _MyStoriesViewState();
}

class _MyStoriesViewState extends State<MyStoriesView> {
  late PageController pageController;
  double currentPageValue = 0.0;
  late FlutterStoryController controller;
  TextEditingController msgControllerl = TextEditingController();

  @override
  void initState() {
    super.initState();
    logger.v("Story intialIndexPage:${widget.initialIndex}");
    logger.v("Story intialIndexStory:${widget.initialStoryIndex}");
    pageController = PageController(initialPage: widget.initialIndex);
    msgControllerl = TextEditingController();
  }

  @override
  void dispose() {
    pageController.dispose();
    msgControllerl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Material(
        color: Colors.black.withValues(alpha: 0.95),
        child: Scaffold(
          backgroundColor: AppColors.transparent,
          body: Consumer2<StoryProvider, ChatProvider>(
            builder: (context, storyProvider, chatProvider, _) {
              debugPrint(
                "storyProvider.getMyStories:${storyProvider.getMyStories.length}",
              );
              return PageView.builder(
                controller: pageController,
                itemCount: storyProvider.myStory.length,
                itemBuilder: (context, index) {
                  // final controller = FlutterStoryController();
                  return AnimatedBuilder(
                    animation: pageController,
                    child: MyStoryView(
                      storyModel: storyProvider.myStory,
                      pageController: pageController,
                      currentIndex: index,
                      totalUsers: storyProvider.myStory.length,
                      isMyStory: widget.isMyStory,
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
                        )!.clamp(0.0, maxOpacity);
                        final isPaging = opacity != maxOpacity;
                        final transform = Matrix4.identity();
                        transform.setEntry(3, 2, 0.003);
                        transform.rotateY(-rotationY * (pi / 180.0));

                        return Transform(
                          alignment:
                              isLeaving
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
