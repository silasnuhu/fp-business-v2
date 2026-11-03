// ignore_for_file: library_private_types_in_public_api

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/story/provider/story_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:get_thumbnail_video/index.dart';

class TrimmerView extends StatefulWidget {
  final File file;

  const TrimmerView(this.file, {super.key});

  @override
  _TrimmerViewState createState() => _TrimmerViewState();
}

class _TrimmerViewState extends State<TrimmerView> {
  final Trimmer _trimmer = Trimmer();

  double _startValue = 0.0;
  double _endValue = 0.0;

  bool _isPlaying = false;
  // ignore: unused_field
  final bool _progressVisibility = false;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  final Duration maxTrimLength = const Duration(seconds: 30);

  void _loadVideo() {
    _trimmer.loadVideo(videoFile: widget.file);
    final duration = _trimmer.videoPlayerController?.value.duration;
    if (duration != null) {
      setState(() {
        _endValue = duration.inSeconds.toDouble();
        _startValue = 0.0;
        trimmedDurationStr = (_endValue - _startValue).toStringAsFixed(2);
      });
    }
  }

  String formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());

    // Prevent negative or large accidental durations
    if (duration.inHours > 1 || seconds < 0 || seconds > 600) {
      // Arbitrary cap — 10 mins max — to catch bugs
      return "00:00:00";
    }

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final secs = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$secs";
  }

  @override
  void initState() {
    super.initState();

    _loadVideo();
  }

  String trimmedDurationStr = "0.00";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(SizeConfig.sizedBoxHeight(70)),
        child: AppBar(
          backgroundColor: AppColors.black,
          leading: Padding(
            padding: const EdgeInsets.all(16.0),
            child: customeBackArrowBalck(context, color: AppColors.white),
          ),
        ),
      ),

      body: Consumer<StoryProvider>(
        builder: (context, storyProvider, _) {
          return Container(
            color: Colors.black,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          VideoViewer(trimmer: _trimmer),
                          TextButton(
                            autofocus: false,
                            child: Container(
                              height: SizeConfig.sizedBoxHeight(60),
                              width: SizeConfig.sizedBoxWidth(60),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.black.withValues(alpha: 0.5),
                              ),
                              child:
                                  _isPlaying
                                      ? Icon(
                                        Icons.pause,
                                        size: SizeConfig.sizedBoxHeight(30),
                                        color: Colors.white,
                                      )
                                      : Icon(
                                        Icons.play_arrow,
                                        size: SizeConfig.sizedBoxHeight(30),
                                        color: Colors.white,
                                      ),
                            ),

                            onPressed: () async {
                              bool playbackState = await _trimmer
                                  .videoPlaybackControl(
                                    startValue: _startValue,
                                    endValue: _endValue,
                                  );
                              setState(() {
                                _isPlaying = playbackState;
                              });
                            },
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(1),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                            child: Container(
                              height: 90,
                              color: AppColors.white.withValues(alpha: 0.05),
                              padding: SizeConfig.getPaddingSymmetric(
                                horizontal: 1,
                              ),
                              child: SizedBox(
                                height: 70,
                                width: double.infinity,
                                child: TrimViewer(
                                  trimmer: _trimmer,
                                  viewerHeight: 50.0,
                                  viewerWidth:
                                      MediaQuery.of(context).size.width,
                                  // maxVideoLength:
                                  //     _trimmer
                                  //         .videoPlayerController!
                                  //         .value
                                  //         .duration,
                                  maxVideoLength: const Duration(seconds: 30),
                                  type: ViewerType.fixed,
                                  onChangeStart: (value) => _startValue = value,
                                  onChangeEnd: (value) => _endValue = value,
                                  onChangePlaybackState:
                                      (value) =>
                                          setState(() => _isPlaying = value),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: SizeConfig.sizedBoxHeight(90),
                    color: AppColors.black,
                    child: Padding(
                      padding: SizeConfig.getPaddingOnly(
                        left: 15,
                        right: 15,
                        bottom: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: storyProvider.typeMessageCtrl,
                              onEditingComplete: () {
                                // FocusScope.of(context).requestFocus(typeNode);
                              },
                              onTap: () {},
                              maxLines: 2,
                              minLines: 1,
                              maxLength: 255,
                              textInputAction: TextInputAction.newline,
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.multiline,
                              style: AppTypography.smallText(context).copyWith(
                                color: AppColors.textColor.textGreyColor,
                              ),
                              // focusNode: typeNode,
                              decoration: InputDecoration(
                                counterText: "",
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                fillColor: AppColors.transparent,
                                filled: true,
                                hintText: AppString.storyStrings.addCaption,
                                hintStyle: AppTypography.smallText(
                                  context,
                                ).copyWith(
                                  color: AppColors.textColor.textGreyColor,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(
                                    color: AppColors.strokeColor.c1A1919,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(
                                    color: AppColors.strokeColor.c1A1919,
                                  ),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide.none,
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(
                                    color: AppColors.textColor.textErrorColor1,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(
                                    color: AppColors.textColor.textErrorColor1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: SizeConfig.sizedBoxWidth(13)),
                          InkWell(
                            onTap: () async {
                              if (isDemo) {
                                snackbarNew(
                                  context,
                                  msg: "Demo accounts cannot upload stories",
                                );
                                return;
                              }
                              closeKeyboard();
                              storyProvider.isStoryUploadLoading(true);
                              try {
                                await _trimmer.saveTrimmedVideo(
                                  startValue: _startValue,
                                  endValue: _endValue,
                                  storageDir:
                                      Platform.isIOS
                                          ? StorageDir
                                              .applicationDocumentsDirectory
                                          : StorageDir.externalStorageDirectory,
                                  onSave: (String? outputPath) async {
                                    if (outputPath == null ||
                                        !context.mounted) {
                                      snackbarNew(
                                        context,
                                        msg: "Trimming failed",
                                      );
                                      storyProvider.isStoryUploadLoading(false);
                                      return;
                                    }

                                    // 👈 NEW: Rename to safe filename (no colons, commas, etc.)
                                    final originalFile = File(outputPath);
                                    final directory = originalFile.parent;
                                    final safeFileName =
                                        "trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4";
                                    final safePath =
                                        '${directory.path}/$safeFileName';

                                    final renamedFile = await originalFile
                                        .rename(safePath);
                                    _logger.v(
                                      "Video📽️ 🎞 Trimmed & renamed file: ${renamedFile.path}",
                                    );

                                    // Generate thumbnail from the renamed file
                                    String? thumbnailPath;
                                    final generatedThumbnail =
                                        await generateVideoThumbnail(
                                          renamedFile.path,
                                        );
                                    if (generatedThumbnail != null &&
                                        generatedThumbnail.isNotEmpty) {
                                      thumbnailPath = generatedThumbnail;
                                      _logger.d(
                                        'Video📽️ Generated thumbnail: $thumbnailPath',
                                      );
                                    }

                                    // 👉 Now compress the safe renamed file
                                    await storyProvider.compressVideo(
                                      renamedFile.path,
                                    );

                                    // Use compressed or fallback
                                    final compressedFilePath =
                                        storyProvider.compressedVideoPath;
                                    final uploadFile =
                                        (compressedFilePath.isNotEmpty &&
                                                File(
                                                  compressedFilePath,
                                                ).existsSync())
                                            ? File(compressedFilePath)
                                            : renamedFile;

                                    storyProvider.selectedMediaFile =
                                        uploadFile;
                                    storyProvider.selectedMediaType = 'video';

                                    // Upload
                                    final success = await storyProvider
                                        .storyUploadApi(
                                          "video",
                                          uploadFile,
                                          thumbnailPath: thumbnailPath,
                                          storyProvider.typeMessageCtrl.text,
                                        );

                                    if (!context.mounted) return;

                                    if (success) {
                                      storyProvider.typeMessageCtrl.clear();
                                      Navigator.pop(context);
                                    } else {
                                      snackbarNew(
                                        context,
                                        msg:
                                            storyProvider.errorMessage ??
                                            "Upload failed",
                                      );
                                    }
                                  },
                                );
                              } catch (e) {
                                storyProvider.isStoryUploadLoading(false);
                                _logger.e(
                                  "Error during trim/compress/upload: $e",
                                );
                                if (context.mounted) {
                                  snackbarNew(
                                    context,
                                    msg:
                                        "Something went wrong. Please try again.",
                                  );
                                }
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
                                    storyProvider.isLoading
                                        ? SizedBox(
                                          height: SizeConfig.sizedBoxHeight(20),
                                          width: SizeConfig.sizedBoxWidth(20),
                                          child: commonLoading2(),
                                        )
                                        : Image.asset(
                                          AppAssets.send,
                                          color: AppColors.black,
                                          height: SizeConfig.sizedBoxHeight(24),
                                          width: SizeConfig.sizedBoxWidth(24),
                                        ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Generate video thumbnail
  Future<String?> generateVideoThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.PNG,
        maxWidth: 300,
        maxHeight: 300,
        quality: 75,
      );

      _logger.d("Thumbnail generated: ${thumbnailFile.path}");
      return thumbnailFile.path;
    } catch (e) {
      _logger.e("Failed to generate video thumbnail: $e");
      return null;
    }
  }
}
