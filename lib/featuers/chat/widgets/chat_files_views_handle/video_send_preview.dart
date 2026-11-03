import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

/// Full-screen preview of a picked video before it is sent. Plays the
/// original [video]. Pops `true` when the user taps send — preparing and
/// sending then happen back on the chat screen; closing or going back pops
/// `false`/null.
class VideoSendPreviewScreen extends StatefulWidget {
  final File video;

  const VideoSendPreviewScreen({super.key, required this.video});

  static Future<bool> show(BuildContext context, File video) async {
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VideoSendPreviewScreen(video: video),
      ),
    );
    return confirmed == true;
  }

  @override
  State<VideoSendPreviewScreen> createState() => _VideoSendPreviewScreenState();
}

class _VideoSendPreviewScreenState extends State<VideoSendPreviewScreen> {
  late final VideoPlayerController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.video);
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          _controller.play();
        })
        .catchError((Object e) {
          debugPrint('Video send preview error: $e');
          if (mounted) setState(() => _hasError = true);
        });
  }

  @override
  void deactivate() {
    // Stop playback as soon as the screen starts leaving (close button,
    // system back or swipe), not only once the route is fully removed.
    if (_controller.value.isInitialized) _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    // Releases the native player, its decoder and the file handle.
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_controller.value.isInitialized) return;
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  void _close(bool send) {
    _controller.pause();
    Navigator.pop(context, send);
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.appPriSecColor.primaryColor;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _controller.value.isInitialized) _controller.pause();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => _close(false),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child:
                      _hasError
                          ? Icon(
                            Icons.videocam_off,
                            size: 64,
                            color: Colors.grey[600],
                          )
                          : !_controller.value.isInitialized
                          ? const CircularProgressIndicator(color: Colors.white)
                          : GestureDetector(
                            onTap: _togglePlay,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AspectRatio(
                                  aspectRatio: _controller.value.aspectRatio,
                                  child: VideoPlayer(_controller),
                                ),
                                ValueListenableBuilder<VideoPlayerValue>(
                                  valueListenable: _controller,
                                  builder:
                                      (context, value, _) =>
                                          value.isPlaying
                                              ? const SizedBox.shrink()
                                              : const CircleAvatar(
                                                radius: 30,
                                                backgroundColor: Colors.black54,
                                                child: Icon(
                                                  Icons.play_arrow,
                                                  size: 40,
                                                  color: Colors.white,
                                                ),
                                              ),
                                ),
                              ],
                            ),
                          ),
                ),
              ),
              if (_controller.value.isInitialized)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: primary,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FloatingActionButton(
                    heroTag: 'video_send_preview_fab',
                    tooltip: AppString.send,
                    backgroundColor: primary,
                    shape: const CircleBorder(),
                    onPressed: () => _close(true),
                    child: Icon(
                      Icons.send,
                      color: ThemeColorPalette.getTextColor(primary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
