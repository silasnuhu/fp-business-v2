import 'package:whoxa/utils/preference_key/constant/strings.dart';

enum UserNameStatus { initial, success, error, loading }

enum ApiRequestType { POST, PUT, GET, DELETE }

enum ChatType {
  text,
  image,
  location,
  document,
  video,
  audio,
  link,
  gif,
  contact,
  story_reply,
  voice,
  poll,
}
// ignore_for_file: constant_identifier_names

enum PaginationFrom {
  MainComment,
  Followers,
  Following,
  Chats,
  GiftHistory,
  CoinHistory,
  ProfileSocial,
  PeerProfileSocial,
  ProfileLikesSocial,
  PeerProfileLikesSocial,
  ProfileGifts,
  PeerProfileGifts,
  LiveUsersList,
  BookmarkList,
}

enum PeerProfileFromWhere {
  HomeReels,
  FollowerScreen,
  FollowingScreren,
  ExploreUser,
  SearchUser,
  Chat,
  Bookmark,
}

enum ReportBlockFromWhere { HomeReels, PeerProfile }

enum ReelsFromWhere {
  HomeReels,
  MyProfile,
  PeerProfile,
  Chat,
  ProfileLikesSocial,
  PeerProfileLikesSocial,
  Bookmark,

  /// LIVE STREAM FOR GIFT ONLY
  LiveStream,
}

enum MessageType {
  Text,
  Image,
  Video,
  File,
  Gif,
  Location,
  Social,
  Contact,
  StoryReply,
  Link,
  Voice,
  Poll,
}

enum PaymentMethods { Stripe, ApplePay, GooglePay, Paypal }

enum PaymentStatus { Success, Failed }

enum WithrawMethods { Paypal, Stripe, Bank }

MessageType stringToMessageType(String? messageTypeString) {
  switch (messageTypeString?.toLowerCase()) {
    case 'text':
      return MessageType.Text;
    case 'image':
    case 'photo':
      return MessageType.Image;
    case 'file':
    case 'document':
    case 'doc':
      return MessageType.File;
    case 'video':
      return MessageType.Video;
    case 'gif':
      return MessageType.Gif;
    case 'location':
      return MessageType.Location;
    case 'social':
      return MessageType.Social;
    case 'contact':
      return MessageType.Contact;
    case 'story_reply':
    case 'feed_reference':
      return MessageType.StoryReply;
    case 'link':
      return MessageType.Link;
    case 'voice':
      return MessageType.Voice;
    case 'poll':
      return MessageType.Poll;
    default:
      return MessageType.Text;
  }
}

//message type show in chatlist
String messageContentWithEmojiSafe(
  dynamic messageType,
  String? messageContent,
) {
  MessageType type = MessageType.Text; // Default

  if (messageType is MessageType) {
    type = messageType;
  } else if (messageType is String) {
    type = stringToMessageType(messageType);
  } else if (messageType is int) {
    // If stored as integer index
    type =
        MessageType.values[messageType.clamp(0, MessageType.values.length - 1)];
  }

  switch (type) {
    case MessageType.Text:
      return messageContent ?? AppString.nomessagesyet;
    case MessageType.Image:
      return AppString.photoEmoji;
    case MessageType.File:
      return AppString.documentEmoji;
    case MessageType.Video:
      return AppString.videoEmoji;
    case MessageType.Gif:
      return AppString.gifMaskEmoji;
    case MessageType.Location:
      return AppString.locationEmoji;
    case MessageType.Link:
      return AppString.linkEmoji;
    case MessageType.Contact:
      return AppString.contactEmoji;
    case MessageType.StoryReply:
      return AppString.storyReply;
    case MessageType.Voice:
      return AppString.voiceEmoji;
    case MessageType.Poll:
      return AppString.poll;
    default:
      return AppString.messageEmoji;
  }
}
