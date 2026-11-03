import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

/// Full-screen preview of a picked image before it is sent. Opens right away
/// with the original [image] while [compressed] is still running; a loader is
/// shown and send stays disabled until it completes. Pops `true` when the
/// user taps send; closing or going back pops `false`/null.
class ImageSendPreviewScreen extends StatelessWidget {
  final File image;
  final Future<File> compressed;

  const ImageSendPreviewScreen({
    super.key,
    required this.image,
    required this.compressed,
  });

  static Future<bool> show(
    BuildContext context,
    File image,
    Future<File> compressed,
  ) async {
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => ImageSendPreviewScreen(image: image, compressed: compressed),
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.appPriSecColor.primaryColor;

    return FutureBuilder<File>(
      future: compressed,
      builder: (context, snapshot) {
        final isCompressing = snapshot.connectionState != ConnectionState.done;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.file(
                            image,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (context, error, stackTrace) => Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: Colors.grey[600],
                                ),
                          ),
                        ),
                      ),
                      if (isCompressing)
                        ColoredBox(
                          color: Colors.black45,
                          child: Center(
                            child: CircularProgressIndicator(color: primary),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FloatingActionButton(
                      heroTag: 'image_send_preview_fab',
                      tooltip: AppString.send,
                      backgroundColor:
                          isCompressing
                              ? primary.withValues(alpha: 0.5)
                              : primary,
                      shape: const CircleBorder(),
                      onPressed:
                          isCompressing
                              ? null
                              : () => Navigator.pop(context, true),
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
        );
      },
    );
  }
}
