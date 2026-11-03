import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/story_item.dart';
import '../story_presenter/story_view.dart';
import '../utils/story_utils.dart';
import '../utils/video_utils.dart';

/// A widget that displays a video story view, supporting different video sources
/// (network, file, asset) and optional thumbnail and error widgets.
class VideoStoryView extends StatefulWidget {
  /// The story item containing video data and configuration.
  final StoryItem storyItem;

  /// Callback function to notify when the video is loaded.
  final OnVideoLoad? onVideoLoad;

  /// In case of single video story
  final bool? looping;

  /// Called a moment after the video fails to load/play (e.g. unsupported
  /// format or resolution), so the story view can skip to the next item.
  final VoidCallback? onVideoError;

  /// Creates a [VideoStoryView] widget.
  const VideoStoryView(
      {required this.storyItem,
      this.onVideoLoad,
      this.looping,
      this.onVideoError,
      super.key});

  @override
  State<VideoStoryView> createState() => _VideoStoryViewState();
}

class _VideoStoryViewState extends State<VideoStoryView> {
  VideoPlayerController? videoPlayerController;
  bool hasError = false;

  @override
  void initState() {
    _initialiseVideoPlayer();
    super.initState();
  }

  /// Initializes the video player controller based on the source of the video.
  Future<void> _initialiseVideoPlayer() async {
    try {
      final storyItem = widget.storyItem;
      if (storyItem.storyItemSource.isNetwork) {
        // Initialize video controller for network source.
        videoPlayerController =
            await VideoUtils.instance.videoControllerFromUrl(
          url: storyItem.url!,
          cacheFile: storyItem.videoConfig?.cacheVideo,
          videoPlayerOptions: storyItem.videoConfig?.videoPlayerOptions,
        );
      } else if (storyItem.storyItemSource.isFile) {
        // Initialize video controller for file source.
        videoPlayerController = VideoUtils.instance.videoControllerFromFile(
          file: File(storyItem.url!),
          videoPlayerOptions: storyItem.videoConfig?.videoPlayerOptions,
        );
      } else {
        // Initialize video controller for asset source.
        videoPlayerController = VideoUtils.instance.videoControllerFromAsset(
          assetPath: storyItem.url!,
          videoPlayerOptions: storyItem.videoConfig?.videoPlayerOptions,
        );
      }
      await videoPlayerController?.initialize();
      widget.onVideoLoad?.call(videoPlayerController!);
      await videoPlayerController?.play();
      await videoPlayerController?.setLooping(widget.looping ?? false);
      await videoPlayerController?.setVolume(storyItem.isMuteByDefault ? 0 : 1);
    } catch (e) {
      hasError = true;
      debugPrint('$e');
    }
    if (!mounted) return;
    setState(() {});
    if (hasError) {
      // Leave the message on screen briefly, then move on.
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) widget.onVideoError?.call();
    }
  }

  BoxFit get fit => widget.storyItem.videoConfig?.fit ?? BoxFit.cover;

  @override
  void dispose() {
    videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: (fit == BoxFit.cover) ? Alignment.topCenter : Alignment.center,
      fit: (fit == BoxFit.cover) ? StackFit.expand : StackFit.loose,
      children: [
        if (hasError) ...{
          // Custom error widget if provided, otherwise the default message.
          widget.storyItem.errorWidget ?? const _VideoErrorView(),
        } else if (widget.storyItem.videoConfig?.loadingWidget != null) ...{
          widget.storyItem.videoConfig!.loadingWidget!,
        } else if (widget.storyItem.thumbnail != null) ...{
          // Display the thumbnail if provided.
          widget.storyItem.thumbnail!,
        },
        if (videoPlayerController != null) ...{
          if (widget.storyItem.videoConfig?.useVideoAspectRatio ?? false) ...{
            // Display the video with aspect ratio if specified.
            AspectRatio(
              aspectRatio: videoPlayerController!.value.aspectRatio,
              child: VideoPlayer(
                videoPlayerController!,
              ),
            )
          } else ...{
            // Display the video fitted to the screen.
            FittedBox(
              fit: widget.storyItem.videoConfig?.fit ?? BoxFit.cover,
              alignment: Alignment.center,
              child: SizedBox(
                width: widget.storyItem.videoConfig?.width ??
                    videoPlayerController!.value.size.width,
                height: widget.storyItem.videoConfig?.height ??
                    videoPlayerController!.value.size.height,
                child: VideoPlayer(videoPlayerController!),
              ),
            )
          },
        }
      ],
    );
  }
}

/// Shown in place of the loading spinner when a story video can't be played.
class _VideoErrorView extends StatelessWidget {
  const _VideoErrorView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 64),
            SizedBox(height: 16),
            Text(
              "This video can't be played",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'The video format or quality is not supported on your device. '
              'Moving to the next story...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
