import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:whoxa/utils/packages/story/src/controller/flutter_story_controller.dart';
import 'package:whoxa/utils/packages/story/src/models/story_view_audio_config.dart';
import 'package:whoxa/utils/packages/story/src/models/story_view_image_config.dart';
import 'package:whoxa/utils/packages/story/src/models/story_view_text_config.dart';
import 'package:whoxa/utils/packages/story/src/models/story_view_video_config.dart';
import 'package:whoxa/utils/packages/story/src/models/story_view_web_config.dart';
import 'package:whoxa/utils/packages/story/src/utils/story_utils.dart';

class StoryItem {
  const StoryItem({
    this.url,
    this.userID,
    this.storyID,
    required this.storyItemType,
    this.thumbnail,
    this.isMuteByDefault = false,
    this.duration = const Duration(
      seconds: 8,
    ), // ← Changed default to 8s (more standard for stories)
    this.storyItemSource = StoryItemSource.network,
    this.videoConfig,
    this.errorWidget,
    this.imageConfig,
    this.textConfig,
    this.webConfig,
    this.customWidget,
    this.audioConfig,
  }) : assert(
         storyItemType == StoryItemType.custom || url != null,
         'URL is required for non-custom story items (image, video, text, web).',
       ),
       assert(
         storyItemType != StoryItemType.custom || customWidget != null,
         'customWidget is required when storyItemType is custom.',
       ),
       assert(
         storyItemType != StoryItemType.video || url != null,
         'URL is required for video stories.',
       ),
       assert(duration > Duration.zero, 'Duration must be greater than zero.');

  /// Duration to display this story item
  /// Recommended: 5–15 seconds for images/text, auto for videos
  final Duration duration;

  /// Background thumbnail (shown while loading main content)
  final Widget? thumbnail;

  /// Fallback widget on load/error
  final Widget? errorWidget;

  /// Custom builder for fully custom stories
  /// Returns a widget using optional controller and audio player
  final Widget Function(
    FlutterStoryController? controller,
    AudioPlayer? audioPlayer,
  )?
  customWidget;

  /// Type of story content
  final StoryItemType storyItemType;

  /// Media source: network URL, asset path, or file path
  final String? url;

  /// Unique identifier for the user who posted this story
  final String? userID;

  /// Unique identifier for this specific story
  final String? storyID;

  /// Whether video should start muted (default: false)
  final bool isMuteByDefault;

  /// Source type: network, asset, or file
  final StoryItemSource storyItemSource;

  // Configurations per type
  final StoryViewImageConfig? imageConfig;
  final StoryViewVideoConfig? videoConfig;
  final StoryViewAudioConfig? audioConfig;
  final StoryViewTextConfig? textConfig;
  final StoryViewWebConfig? webConfig;

  // Convenience getters (optional but very useful)

  bool get isImage => storyItemType == StoryItemType.image;
  bool get isVideo => storyItemType == StoryItemType.video;
  bool get isText => storyItemType == StoryItemType.text;
  bool get isWeb => storyItemType == StoryItemType.web;
  bool get isCustom => storyItemType == StoryItemType.custom;

  bool get hasAudio => audioConfig != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryItem &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          userID == other.userID &&
          storyID == other.storyID &&
          storyItemType == other.storyItemType &&
          duration == other.duration;

  @override
  int get hashCode =>
      url.hashCode ^
      userID.hashCode ^
      storyID.hashCode ^
      storyItemType.hashCode ^
      duration.hashCode;

  @override
  String toString() {
    return 'StoryItem(type: $storyItemType, url: $url, userID: $userID, storyID: $storyID, duration: $duration)';
  }
}
