import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:video_player/video_player.dart';

class VideoPreview extends StatefulWidget {
  final String? videoUrl;
  final File? videoFile;
  const VideoPreview({super.key, this.videoUrl, this.videoFile});

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  Future<void>? _initializeVideoPlayerFuture;
  late AnimationController _animationController;
  bool isPlay = true;
  double videoProgress = 0.0;
  late SliderThemeData _sliderThemeData;

  @override
  void initState() {
    super.initState();
    initVideo();
  }

  @override
  void dispose() {
    disposeVideo();
    super.dispose();
  }

  // void initVideo() {
  //   _controller = VideoPlayerController.networkUrl(
  //     Uri.parse(widget.videoUrl!),
  //     videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  //   );
  //   _initializeVideoPlayerFuture = _controller!.initialize();
  //   _controller!.addListener(_videoListener);
  //   _controller!.play();
  //   _controller!.setLooping(true);
  //   _controller!.setVolume(1.0);

  //   _animationController = AnimationController(
  //     vsync: this,
  //     duration: const Duration(milliseconds: 600),
  //   );
  // }

  void initVideo() {
    if (widget.videoFile != null) {
      _controller = VideoPlayerController.file(widget.videoFile!);
    } else if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl!),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    } else {
      throw Exception("No video source provided");
    }

    _initializeVideoPlayerFuture = _controller!.initialize();
    _controller!.addListener(_videoListener);
    _controller!.play();
    _controller!.setLooping(true);
    _controller!.setVolume(1.0);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        videoProgress =
            _controller!.value.position.inMilliseconds /
            _controller!.value.duration.inMilliseconds;
        videoProgress = videoProgress.clamp(0.0, 1.0);
      });
    }
  }

  void disposeVideo() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
  }

  void play() {
    _controller?.play();
    setState(() {});
  }

  void pause() {
    _controller?.pause();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _sliderThemeData = SliderTheme.of(context).copyWith(trackHeight: 5.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        color: AppColors.transparent,
        child: FutureBuilder(
          future: _initializeVideoPlayerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              bool isPortrait = _controller!.value.aspectRatio < 1;
              return Stack(
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (_controller!.value.isPlaying) {
                        pause();
                        isPlay = false;
                        _animationController.reverse();
                      } else {
                        play();
                        _animationController.animateBack(
                          1,
                          duration: const Duration(milliseconds: 500),
                        );
                        Future.delayed(const Duration(milliseconds: 500), () {
                          isPlay = true;
                          setState(() {});
                        });
                      }
                    },
                    child: Center(
                      child:
                          isPortrait
                              ? FittedBox(
                                fit:
                                    BoxFit
                                        .contain, // Centers the video properly
                                clipBehavior: Clip.antiAliasWithSaveLayer,
                                child: SizedBox(
                                  width: _controller!.value.size.width,
                                  height: _controller!.value.size.height,
                                  child: AspectRatio(
                                    aspectRatio: _controller!.value.aspectRatio,
                                    child: VideoPlayer(_controller!),
                                  ),
                                ),
                              )
                              : ClipRRect(
                                child: AspectRatio(
                                  aspectRatio: _controller!.value.aspectRatio,
                                  child: VideoPlayer(_controller!),
                                ),
                              ),
                    ),
                  ),
                  isPlay
                      ? const SizedBox.shrink()
                      : Positioned.fill(
                        child: Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              if (_controller!.value.isPlaying) {
                                pause();
                                isPlay = false;
                                _animationController.reverse();
                              } else {
                                play();
                                _animationController.animateBack(
                                  1,
                                  duration: const Duration(milliseconds: 500),
                                );
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () {
                                    isPlay = true;
                                    setState(() {});
                                  },
                                );
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.white.withValues(alpha: 0.46),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: AnimatedIcon(
                                  progress: _animationController,
                                  icon: AnimatedIcons.play_pause,
                                  color: AppColors.white,
                                  size: 35,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  Positioned(
                    // left: 25,
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          [
                                _controller!.value.position.inMinutes,
                                _controller!.value.position.inSeconds,
                              ]
                              .map(
                                (seg) => seg
                                    .remainder(60)
                                    .toString()
                                    .padLeft(2, '0'),
                              )
                              .join(':'),
                          style: AppTypography.captionText(
                            context,
                          ).copyWith(color: AppColors.white),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: SliderTheme(
                            data: _sliderThemeData.copyWith(
                              inactiveTrackColor: AppColors.white.withValues(
                                alpha: 0.15,
                              ),
                              activeTrackColor:
                                  AppColors.appPriSecColor.primaryColor,
                              trackHeight: 3.0,
                              thumbColor:
                                  AppColors.appPriSecColor.secondaryColor,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7.0,
                              ),
                              overlayColor: AppColors
                                  .appPriSecColor
                                  .secondaryColor
                                  .withValues(alpha: 0.32),
                              overlayShape: SliderComponentShape.noOverlay,
                              //  const RoundSliderOverlayShape(overlayRadius: 0.0),
                            ),
                            child: Slider(
                              value: videoProgress,
                              onChanged: (double value) {},
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          [
                                _controller!.value.duration.inMinutes,
                                _controller!.value.duration.inSeconds,
                              ]
                              .map(
                                (seg) => seg
                                    .remainder(60)
                                    .toString()
                                    .padLeft(2, '0'),
                              )
                              .join(':'),
                          style: AppTypography.captionText(
                            context,
                          ).copyWith(color: AppColors.white),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: SizeConfig.screenWidth,
                        height: SizeConfig.sizedBoxHeight(132),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: const Alignment(0, 0.2),
                            colors: [
                              AppColors.black.withValues(alpha: 1),
                              AppColors.black.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        child: const SizedBox(),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return Center(child: commonLoading());
            }
          },
        ),
      ),
    );
  }
}
