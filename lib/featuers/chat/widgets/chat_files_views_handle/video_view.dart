import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/widgets/global.dart';

class VideoViewerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoViewerScreen({super.key, required this.videoUrl});

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  late VideoPlayerController _controller;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });

    _controller.addListener(() {
      if (_controller.value.hasError) {
        debugPrint("Video player error: ${_controller.value.errorDescription}");
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleUI,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_controller.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              Center(child: commonLoading()),

            if (_showUI)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  icon: customeBackArrowBalck(context, color: AppColors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),

            if (_showUI && _controller.value.isInitialized)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.grey,
                  ),
                ),
              ),

            if (_showUI && _controller.value.isInitialized)
              Positioned(
                bottom: 80,
                child: IconButton(
                  iconSize: 60,
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension VideoViewerNavigation on BuildContext {
  Future<void> viewVideo({required String videoUrl}) {
    return Navigator.push(
      this,
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return VideoViewerScreen(videoUrl: videoUrl);
        },
      ),
    );
  }
}
