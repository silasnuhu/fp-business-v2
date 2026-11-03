import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/services/video_thumbnail_service.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

/// Poster frame for a video attachment, used everywhere a video needs a still:
/// chat bubbles, the pinned bar, the shared-media grid.
///
/// Resolution order:
///   1. a real image thumbnail from the backend, when one exists;
///   2. otherwise a frame extracted on-device by [VideoThumbnailService] — the
///      NEW backend's video-thumbnail queue processor is a stub, so
///      `attachment.thumbnailUrl` is effectively always null;
///   3. a caller-supplied (or default grey videocam) placeholder while the
///      frame is being extracted and if every path fails.
class VideoThumbnailView extends StatefulWidget {
  /// The video's own URL / local path — the source a frame is pulled from.
  final String videoUrl;

  /// Whatever the message/media model exposes as a "thumbnail". May be empty,
  /// null, or (because of the adapter's fallback) the video URL itself.
  final String? backendThumbnailUrl;

  final double? width;
  final double? height;
  final BoxFit fit;

  /// Shown while a frame is being extracted and when everything fails.
  /// `loading` distinguishes the two so callers can show a spinner vs an icon.
  final Widget Function(BuildContext context, bool loading)? placeholderBuilder;

  const VideoThumbnailView({
    super.key,
    required this.videoUrl,
    this.backendThumbnailUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
  });

  @override
  State<VideoThumbnailView> createState() => _VideoThumbnailViewState();
}

class _VideoThumbnailViewState extends State<VideoThumbnailView> {
  String? _generatedPath;
  bool _generating = false;

  bool get _hasUsableBackendThumb {
    final url = widget.backendThumbnailUrl?.trim() ?? '';
    if (url.isEmpty) return false;
    if (url == widget.videoUrl.trim()) return false;
    return !VideoThumbnailService.instance.isVideoExtension(url);
  }

  @override
  void initState() {
    super.initState();
    if (!_hasUsableBackendThumb) _generate();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.backendThumbnailUrl != widget.backendThumbnailUrl) {
      _generatedPath = null;
      if (!_hasUsableBackendThumb) _generate();
    }
  }

  Future<void> _generate() async {
    final source = widget.videoUrl.trim();
    if (source.isEmpty || _generating) return;
    if (!VideoThumbnailService.instance.isSupportedVideo(source)) return;
    setState(() => _generating = true);
    final path = await VideoThumbnailService.instance.getThumbnail(source);
    if (!mounted) return;
    setState(() {
      _generating = false;
      _generatedPath = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_hasUsableBackendThumb) {
      child = CachedNetworkImage(
        imageUrl: widget.backendThumbnailUrl!.trim(),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorWidget: (context, url, error) => _placeholder(false),
      );
    } else if (_generatedPath != null) {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final int? cacheW =
          widget.width != null && widget.width! > 0
              ? (widget.width! * dpr).round()
              : null;
      child = Image.file(
        File(_generatedPath!),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        cacheWidth: cacheW,
        errorBuilder: (context, error, stackTrace) => _placeholder(false),
      );
    } else {
      child = _placeholder(_generating);
    }

    if (widget.width != null || widget.height != null) {
      return SizedBox(width: widget.width, height: widget.height, child: child);
    }
    return child;
  }

  Widget _placeholder(bool loading) {
    if (widget.placeholderBuilder != null) {
      return widget.placeholderBuilder!(context, loading);
    }
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.grey,
      alignment: Alignment.center,
      child:
          loading
              ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : Icon(
                Icons.videocam,
                size: 40,
                color: AppColors.textColor.textGreyColor,
              ),
    );
  }
}
