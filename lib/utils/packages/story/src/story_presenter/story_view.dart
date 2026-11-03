// ignore_for_file: unused_field

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:whoxa/utils/packages/story/src/story_presenter/story_custom_view_wrapper.dart';
import 'package:whoxa/utils/packages/story/src/utils/video_utils.dart';
import '../story_presenter/story_view_indicator.dart';
import '../models/story_item.dart';
import '../models/story_view_indicator_config.dart';
import '../controller/flutter_story_controller.dart';
// import '../controller/flutter_story_controller.dart' as storyCtrl;
import '../story_presenter/image_story_view.dart';
import '../story_presenter/video_story_view.dart';
import '../story_presenter/web_story_view.dart';
import '../story_presenter/text_story_view.dart';
import '../utils/smooth_video_progress.dart';
import '../utils/story_utils.dart';
import 'package:video_player/video_player.dart';

typedef OnStoryChanged = void Function(int);
typedef OnCompleted = Future<void> Function();
typedef OnLeftTap = void Function();
typedef OnRightTap = void Function();
typedef OnDrag = void Function();
typedef OnItemBuild = Widget? Function(int, Widget);
typedef OnVideoLoad = void Function(VideoPlayerController?);
typedef OnAudioLoaded = void Function(AudioPlayer);
typedef CustomViewBuilder = Widget Function(AudioPlayer);
typedef OnSlideDown = void Function(DragUpdateDetails);
typedef OnSlideStart = void Function(DragStartDetails);

class FlutterStoryPresenter extends StatefulWidget {
  const FlutterStoryPresenter({
    this.flutterStoryController,
    this.items = const [],
    this.onStoryChanged,
    this.onLeftTap,
    this.onRightTap,
    this.onCompleted,
    this.onPreviousCompleted,
    this.initialIndex = 0,
    this.storyViewIndicatorConfig,
    this.restartOnCompleted = true,
    this.onVideoLoad,
    this.headerWidget,
    this.footerWidget,
    this.onSlideDown,
    this.onSlideStart,
    super.key,
  }) : assert(initialIndex < items.length);

  /// List of StoryItem objects to display in the story view.
  final List<StoryItem> items;

  /// Controller for managing the current playing media.
  final FlutterStoryController? flutterStoryController;

  /// Callback function triggered whenever the story changes or the user navigates to the previous/next story.
  final OnStoryChanged? onStoryChanged;

  /// Callback function triggered when all items in the list have been played.
  final OnCompleted? onCompleted;

  /// Callback function triggered when all items in the list have been played.
  final OnCompleted? onPreviousCompleted;

  /// Callback function triggered when the user taps on the left half of the screen.
  final OnLeftTap? onLeftTap;

  /// Callback function triggered when the user taps on the right half of the screen.
  final OnRightTap? onRightTap;

  /// Callback function triggered when user drag downs the storyview.
  final OnSlideDown? onSlideDown;

  /// Callback function triggered when user starts drag downs the storyview.
  final OnSlideStart? onSlideStart;

  /// Indicates whether the story view should restart from the beginning after all items have been played.
  final bool restartOnCompleted;

  /// Index to start playing the story from initially.
  final int initialIndex;

  /// Configuration and styling options for the story view indicator.
  final StoryViewIndicatorConfig? storyViewIndicatorConfig;

  /// Callback function to retrieve the VideoPlayerController when it is initialized and ready to play.
  final OnVideoLoad? onVideoLoad;

  /// Widget to display user profile or other details at the top of the screen.
  final Widget? headerWidget;

  /// Widget to display text field or other content at the bottom of the screen.
  final Widget? footerWidget;

  @override
  State<FlutterStoryPresenter> createState() => _FlutterStoryPresenterState();
}

class _FlutterStoryPresenterState extends State<FlutterStoryPresenter>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation? _currentProgressAnimation;
  int currentIndex = 0;
  bool isCurrentItemLoaded = false;
  double currentItemProgress = 0;
  VideoPlayerController? _currentVideoPlayer;
  VideoPlayerController? _preloadedNextVideoPlayer;
  double? storyViewHeight;
  AudioPlayer? _audioPlayer;
  Duration? _totalAudioDuration;
  StreamSubscription? _audioDurationSubscriptionStream;
  StreamSubscription? _audioPlayerStateStream;

  // Key to force full rebuild of story content (image/video/etc.) on navigation/restart
  Key _storyContentKey = UniqueKey();

  // Add this to track if we're in the middle of loading
  final bool _isLoadingCurrent = false;

  @override
  void initState() {
    if (_animationController != null) {
      _animationController?.reset();
      _animationController?.dispose();
      _animationController = null;
    }
    _animationController = AnimationController(vsync: this);
    currentIndex = widget.initialIndex;
    widget.flutterStoryController?.addListener(_storyControllerListener);
    _startStoryView();

    WidgetsBinding.instance.addObserver(this);

    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log("STATE ==> $state");
    switch (state) {
      case AppLifecycleState.resumed:
        _resumeMedia();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _pauseMedia();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    _preloadedNextVideoPlayer?.pause();
    _preloadedNextVideoPlayer?.dispose();
    _preloadedNextVideoPlayer = null;

    _currentVideoPlayer?.pause();
    _currentVideoPlayer?.dispose();
    _currentVideoPlayer = null;

    _animationController?.dispose();
    _audioPlayer?.dispose();
    _audioDurationSubscriptionStream?.cancel();
    _animationController = null;
    widget.flutterStoryController
      ?..removeListener(_storyControllerListener)
      ..dispose();
    _audioDurationSubscriptionStream?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Updated: Always dispose old controllers aggressively
  void _disposeAllVideoControllers() {
    _currentVideoPlayer?.pause();
    _currentVideoPlayer?.dispose();
    _currentVideoPlayer = null;

    _preloadedNextVideoPlayer?.pause();
    _preloadedNextVideoPlayer?.dispose();
    _preloadedNextVideoPlayer = null;
  }

  /// Returns the current story item.
  StoryItem get currentItem => widget.items[currentIndex];

  /// Returns the configuration for the story view indicator.
  StoryViewIndicatorConfig get storyViewIndicatorConfig =>
      widget.storyViewIndicatorConfig ?? const StoryViewIndicatorConfig();

  /// Listener for the story controller to handle various story actions.
  void _storyControllerListener() {
    final controller = widget.flutterStoryController;
    final storyStatus = controller?.storyStatus;
    final jumpIndex = controller?.jumpIndex;

    if (storyStatus != null) {
      if (storyStatus.isPlay) {
        _resumeMedia();
      } else if (storyStatus.isMute || storyStatus.isUnMute) {
        _toggleMuteUnMuteMedia();
      } else if (storyStatus.isPause) {
        _pauseMedia();
      } else if (storyStatus.isPrevious) {
        _playPrevious();
      } else if (storyStatus.isNext) {
        _playNext();
      }
    }

    if (jumpIndex != null &&
        jumpIndex >= 0 &&
        jumpIndex < widget.items.length) {
      currentIndex = jumpIndex - 1;
      _playNext();
    }
  }

  /// Starts the story view.
  void _startStoryView() {
    widget.onStoryChanged?.call(currentIndex);
    _playMedia();
    if (mounted) {
      setState(() {});
    }
  }

  /// Resets the animation controller and its listeners.
  void _resetAnimation() {
    _animationController?.stop();
    _animationController?.reset();
    // _animationController?.forward();
    _animationController
      ?..removeListener(animationListener)
      ..removeStatusListener(animationStatusListener);
  }

  /// Initializes and starts the media playback for the current story item.
  void _playMedia() {
    isCurrentItemLoaded = false;
  }

  /// Resumes the media playback.
  void _resumeMedia() {
    _audioPlayer?.play();
    if (_currentVideoPlayer?.value.isInitialized ?? false) {
      _currentVideoPlayer?.play();
    }
    if (_currentProgressAnimation != null) {
      _animationController?.forward(from: _currentProgressAnimation?.value);
    }
  }

  /// Starts the countdown for the story item duration.
  void _startStoryCountdown() {
    _currentVideoPlayer?.addListener(videoListener);
    if (_currentVideoPlayer != null) {
      return;
    }

    // if (currentItem.audioConfig != null) {
    //   _audioPlayer?.durationFuture?.then((v) {
    //     _totalAudioDuration = v;
    //     _animationController ??= AnimationController(
    //       vsync: this,
    //     );

    //     _animationController?.duration = v;

    //     _currentProgressAnimation =
    //         Tween<double>(begin: 0, end: 1).animate(_animationController!)
    //           ..addListener(animationListener)
    //           ..addStatusListener(animationStatusListener);

    //     _animationController!.forward();
    //   });
    //   _audioDurationSubscriptionStream =
    //       _audioPlayer?.positionStream.listen(audioPositionListener);
    //   _audioPlayerStateStream = _audioPlayer?.playerStateStream.listen(
    //     (event) {
    //       if (event.playing) {
    //         if (event.processingState == ProcessingState.loading) {
    //           _pauseMedia();
    //         } else {
    //           _resumeMedia();
    //         }
    //       }
    //     },
    //   );

    //   return;
    // }

    _animationController ??= AnimationController(vsync: this);

    _animationController?.duration =
        _currentVideoPlayer?.value.duration ?? currentItem.duration;

    _currentProgressAnimation =
        Tween<double>(begin: 0, end: 1).animate(_animationController!)
          ..addListener(animationListener)
          ..addStatusListener(animationStatusListener);

    // Paused from outside (e.g. an ad is showing) while this item was still
    // loading: stay put, _resumeMedia() will start the animation on play().
    if (widget.flutterStoryController?.storyStatus.isPause ?? false) return;

    _animationController!.forward();
  }

  /// Listener for the video player's state changes.
  void videoListener() {
    final dur = _currentVideoPlayer?.value.duration.inMilliseconds;
    final pos = _currentVideoPlayer?.value.position.inMilliseconds;

    if (pos == dur) {
      _playNext();
      return;
    }

    if (_currentVideoPlayer?.value.isBuffering ?? false) {
      _animationController?.stop(canceled: false);
    }

    if (_currentVideoPlayer?.value.isPlaying ?? false) {
      if (_currentProgressAnimation != null) {
        _animationController?.forward(from: _currentProgressAnimation?.value);
      }
    }
  }

  void audioPositionListener(Duration position) {
    final dur = position.inMilliseconds;
    final pos = _totalAudioDuration?.inMilliseconds;

    if (pos == dur) {
      _playNext();
      return;
    }
  }

  /// Listener for the animation progress.
  void animationListener() {
    currentItemProgress = _animationController?.value ?? 0;
  }

  /// Listener for the animation status.
  void animationStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _playNext();
    }
  }

  /// Pauses the media playback.
  void _pauseMedia() {
    _audioPlayer?.pause();
    if (_currentVideoPlayer?.value.isInitialized ?? false) {
      _currentVideoPlayer?.pause();
    }
    _animationController?.stop(canceled: false);
  }

  /// Toggles mute/unmute for the media.
  void _toggleMuteUnMuteMedia() {
    if (_currentVideoPlayer != null &&
        _currentVideoPlayer!.value.isInitialized) {
      final volume = _currentVideoPlayer!.value.volume;
      _currentVideoPlayer!.setVolume(volume > 0 ? 0 : 1);
    }
  }

  // Your _preloadNextVideo method (keep as is, just small improvement)
  Future<void> _preloadNextVideo() async {
    // Always dispose old preload first
    await _preloadedNextVideoPlayer?.dispose();
    _preloadedNextVideoPlayer = null;

    final nextIndex = currentIndex + 1;
    if (nextIndex >= widget.items.length) return;

    final nextItem = widget.items[nextIndex];
    if (!nextItem.storyItemType.isVideo) return;

    try {
      late VideoPlayerController controller;

      if (nextItem.storyItemSource.isNetwork) {
        controller = await VideoUtils.instance.videoControllerFromUrl(
          url: nextItem.url!,
          cacheFile: nextItem.videoConfig?.cacheVideo ?? true,
          videoPlayerOptions: nextItem.videoConfig?.videoPlayerOptions,
        );
      } else if (nextItem.storyItemSource.isFile) {
        controller = VideoPlayerController.file(File(nextItem.url!));
      } else {
        controller = VideoPlayerController.asset(nextItem.url!);
      }

      await controller.initialize();
      await controller.setVolume(nextItem.isMuteByDefault ? 0 : 1);
      await controller.pause(); // Keep paused until needed

      _preloadedNextVideoPlayer = controller;
    } catch (e) {
      debugPrint('Preload failed: $e');
    }
  }

  /// Plays the next story item.
  void _playNext() async {
    if (widget.items.length == 1 &&
        _currentVideoPlayer != null &&
        widget.restartOnCompleted) {
      await widget.onCompleted?.call();
      return;
    }

    // Always pause first
    _pauseMedia();

    if (_currentVideoPlayer != null &&
        currentIndex != (widget.items.length - 1)) {
      /// Dispose the video player only in case of multiple story
      isCurrentItemLoaded = false;
      setState(() {});
      _currentVideoPlayer?.removeListener(videoListener);
      _currentVideoPlayer?.dispose();
      _currentVideoPlayer = null;
    }

    if (currentIndex == widget.items.length - 1) {
      _disposeAllVideoControllers(); // Clean everything before going to next user
      await widget.onCompleted?.call();
      if (widget.restartOnCompleted) {
        currentIndex = 0;
        _resetAnimation();
        _startStoryView();
      }
      if (mounted) {
        setState(() {});
      }
      return;
    }

    currentIndex++;
    _resetAnimation();
    widget.onStoryChanged?.call(currentIndex);

    // Use preloaded controller if available (instant play!)
    if (_preloadedNextVideoPlayer != null &&
        _preloadedNextVideoPlayer!.value.isInitialized) {
      _currentVideoPlayer?.dispose();
      _currentVideoPlayer = _preloadedNextVideoPlayer;
      _preloadedNextVideoPlayer = null;

      _currentVideoPlayer!.play();
      _startStoryCountdown();
      if (mounted) setState(() {});
    } else {
      // Normal load
      _playMedia();
    }
    // _playMedia();
    setState(() {
      _storyContentKey = UniqueKey(); // Force fresh content widget
    });
    _preloadNextVideo();
  }

  /// Plays the previous story item.
  void _playPrevious() {
    // Clean up audio
    if (_audioPlayer != null) {
      _audioPlayer?.dispose();
      _audioDurationSubscriptionStream?.cancel();
      _audioPlayerStateStream?.cancel();
      _audioPlayer = null;
    }

    // Always dispose everything when going back
    _disposeAllVideoControllers();

    if (currentIndex == 0) {
      // Restart first story: force full reload by changing key
      _pauseMedia();
      _resetAnimation();

      setState(() {
        _storyContentKey =
            UniqueKey(); // ← This disposes old VideoStoryView and creates new one
      });

      // That's it! No manual forward(), no duration setting
      // New VideoStoryView will init → onVideoLoad → _startStoryCountdown() → safe forward()
      return;
    }

    // Go to previous story
    _pauseMedia();
    _resetAnimation();
    currentIndex--;

    setState(() {
      _storyContentKey = UniqueKey(); // Fresh content
    });

    widget.onStoryChanged?.call(currentIndex);
    // Preload new next video after going back
    _preloadNextVideo();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        if (currentItem.thumbnail != null) ...{currentItem.thumbnail!},
        if (currentItem.storyItemType.isCustom &&
            currentItem.customWidget != null) ...{
          Positioned.fill(
            child: StoryCustomWidgetWrapper(
              key: _storyContentKey,
              isAutoStart: true,
              builder: (audioPlayer) {
                return currentItem.customWidget!(
                  widget.flutterStoryController,
                  audioPlayer,
                );
              },
              storyItem: currentItem,
              onLoaded: () {
                isCurrentItemLoaded = true;
                _startStoryCountdown();
              },
              onAudioLoaded: (audioPlayer) {
                isCurrentItemLoaded = true;
                _audioPlayer = audioPlayer;
                _startStoryCountdown();
              },
            ),
          ),
        },
        if (currentItem.storyItemType.isImage) ...{
          Positioned.fill(
            child: ImageStoryView(
              key: _storyContentKey,
              storyItem: currentItem,
              onImageLoaded: (isLoaded) {
                isCurrentItemLoaded = isLoaded;
                _startStoryCountdown();
              },
              onAudioLoaded: (audioPlayer) {
                _audioPlayer = audioPlayer;
                isCurrentItemLoaded = true;

                _startStoryCountdown();
              },
            ),
          ),
        },
        if (currentItem.storyItemType.isVideo) ...{
          Positioned.fill(
            child: VideoStoryView(
              storyItem: currentItem,
              key: _storyContentKey,
              looping: widget.items.length == 1 && widget.restartOnCompleted,
              onVideoError: () {
                // Unplayable video: skip it (same guard as onVideoLoad).
                if (!mounted || currentItem != widget.items[currentIndex]) {
                  return;
                }
                _playNext();
              },
              onVideoLoad: (videoPlayer) {
                // isCurrentItemLoaded = true;
                // _currentVideoPlayer = videoPlayer;
                // widget.onVideoLoad?.call(videoPlayer);
                // _startStoryCountdown();
                // if (mounted) setState(() {});

                // // Preload next video as soon as current one is ready
                // _preloadNextVideo();
                // Only accept if this is still the current story
                if (!mounted || currentItem != widget.items[currentIndex]) {
                  videoPlayer?.dispose(); // Safety
                  return;
                }

                _currentVideoPlayer = videoPlayer;
                widget.onVideoLoad?.call(videoPlayer);
                _startStoryCountdown();

                if (mounted) setState(() {});

                _preloadNextVideo(); // Start preloading next
              },
            ),
          ),
        },
        if (currentItem.storyItemType.isWeb) ...{
          Positioned.fill(
            child: WebStoryView(
              storyItem: currentItem,
              key: _storyContentKey,
              onWebViewLoaded: (controller, loaded) {
                isCurrentItemLoaded = loaded;
                if (loaded) {
                  _startStoryCountdown();
                }
                currentItem.webConfig?.onWebViewLoaded?.call(
                  controller,
                  loaded,
                );
              },
            ),
          ),
        },
        if (currentItem.storyItemType.isText) ...{
          Positioned.fill(
            child: TextStoryView(
              storyItem: currentItem,
              key: _storyContentKey,
              onTextStoryLoaded: (loaded) {
                isCurrentItemLoaded = loaded;
                _startStoryCountdown();
              },
              onAudioLoaded: (audioPlayer) {
                isCurrentItemLoaded = true;
                _audioPlayer = audioPlayer;
                _startStoryCountdown();
              },
            ),
          ),
        },
        Align(
          alignment: storyViewIndicatorConfig.alignment,
          child: Padding(
            padding: storyViewIndicatorConfig.margin,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                (_currentVideoPlayer != null
                    ? SmoothVideoProgress(
                        controller: _currentVideoPlayer!,
                        builder: (context, progress, duration, child) {
                          return StoryViewIndicator(
                            currentIndex: currentIndex,
                            currentItemAnimatedValue: progress.inMilliseconds /
                                duration.inMilliseconds,
                            totalItems: widget.items.length,
                            storyViewIndicatorConfig: storyViewIndicatorConfig,
                          );
                        },
                      )
                    : _animationController != null
                        ? AnimatedBuilder(
                            animation: _animationController!,
                            builder: (context, child) => StoryViewIndicator(
                              currentIndex: currentIndex,
                              currentItemAnimatedValue: currentItemProgress,
                              totalItems: widget.items.length,
                              storyViewIndicatorConfig:
                                  storyViewIndicatorConfig,
                            ),
                          )
                        : StoryViewIndicator(
                            currentIndex: currentIndex,
                            currentItemAnimatedValue: currentItemProgress,
                            totalItems: widget.items.length,
                            storyViewIndicatorConfig: storyViewIndicatorConfig,
                          )),
              ],
            ),

            // Column(
            //   mainAxisSize: MainAxisSize.min,
            //   children: [
            //     _currentVideoPlayer != null
            //         ? SmoothVideoProgress(
            //             controller: _currentVideoPlayer!,
            //             builder: (context, progress, duration, child) {
            //               return StoryViewIndicator(
            //                 currentIndex: currentIndex,
            //                 currentItemAnimatedValue: progress.inMilliseconds /
            //                     duration.inMilliseconds,
            //                 totalItems: widget.items.length,
            //                 storyViewIndicatorConfig: storyViewIndicatorConfig,
            //               );
            //             })
            //         : _animationController != null
            //             ? AnimatedBuilder(
            //                 animation: _animationController!,
            //                 builder: (context, child) => StoryViewIndicator(
            //                   currentIndex: currentIndex,
            //                   currentItemAnimatedValue: currentItemProgress,
            //                   totalItems: widget.items.length,
            //                   storyViewIndicatorConfig:
            //                       storyViewIndicatorConfig,
            //                 ),
            //               )
            //             : StoryViewIndicator(
            //                 currentIndex: currentIndex,
            //                 currentItemAnimatedValue: currentItemProgress,
            //                 totalItems: widget.items.length,
            //                 storyViewIndicatorConfig: storyViewIndicatorConfig,
            //               ),
            //   ],
            // ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: size.width * .2,
            height: size.height,
            child: GestureDetector(onTap: _playPrevious),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: size.width * .2,
            height: size.height,
            child: GestureDetector(onTap: _playNext),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: GestureDetector(
              key: ValueKey('$currentIndex'),
              onLongPressDown: (details) => _pauseMedia(),
              onLongPressUp: _resumeMedia,
              onLongPressEnd: (details) => _resumeMedia(),
              onLongPressCancel: _resumeMedia,
              onVerticalDragStart: widget.onSlideStart?.call,
              onVerticalDragUpdate: widget.onSlideDown?.call,
            ),
          ),
        ),
        if (widget.headerWidget != null) ...{
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              bottom: storyViewIndicatorConfig.enableBottomSafeArea,
              top: storyViewIndicatorConfig.enableTopSafeArea,
              child: widget.headerWidget!,
            ),
          ),
        },
        if (widget.footerWidget != null) ...{
          Align(alignment: Alignment.bottomCenter, child: widget.footerWidget!),
        },
      ],
    );
  }
}
