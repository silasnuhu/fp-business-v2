import 'package:whoxa/utils/packages/story/src/models/story_item.dart';
import 'package:whoxa/utils/packages/story/src/utils/story_utils.dart';

class StoryModel {
  final String userID;
  final String userName;
  final String fName;
  final String lName;
  final String userProfile;
  final List<StoryItem> stories;

  StoryModel({
    required this.userID,
    required this.userName,
    required this.fName,
    required this.lName,
    required this.userProfile,
    required this.stories,
  });
}

class CustomStoryItem extends StoryItem {
  final String storyId;
  final String storyCaption;
  final String storyTime;

  /// CDN URL of the story's poster image (`media.thumbnailUrl`, video only).
  /// Kept separate from [StoryItem.thumbnail], which is a loading `Widget`.
  final String? thumbnailUrl;

  CustomStoryItem({
    required this.storyId,
    required this.storyCaption,
    required this.storyTime,
    this.thumbnailUrl,
    required super.url,
    required super.userID,
    super.storyItemType = StoryItemType.image,
    super.imageConfig,
    super.videoConfig,
    super.textConfig,
    super.duration,
    super.audioConfig,
    super.customWidget,
    super.errorWidget,
    super.isMuteByDefault,
    super.storyItemSource,
    super.thumbnail,
    super.webConfig,
  });
}
