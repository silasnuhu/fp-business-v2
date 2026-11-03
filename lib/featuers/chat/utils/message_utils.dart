import 'package:whoxa/utils/enums.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class MessageTypeUtils {
  /// Converts MessageType enum to API-compatible string format
  static String messageContentType(MessageType messageType) {
    switch (messageType) {
      case MessageType.Text:
        return "text";
      case MessageType.Image:
        return "image";
      case MessageType.File:
        return "doc";
      case MessageType.Video:
        return "video";
      case MessageType.Gif:
        return "gif";
      case MessageType.Location:
        return "location";
      case MessageType.Social:
        return "social";
      case MessageType.Contact:
        return "contact";
      case MessageType.StoryReply:
        return "story_reply";
      case MessageType.Link:
        return "link";
      case MessageType.Voice:
        return "voice";
      case MessageType.Poll:
        return 'poll';
    }
  }

  /// Converts API string format back to MessageType enum
  static MessageType messageTypeFromString(String typeString) {
    switch (typeString.toLowerCase()) {
      case "text":
        return MessageType.Text;
      case "image":
        return MessageType.Image;
      case "doc":
        return MessageType.File;
      case "video":
        return MessageType.Video;
      case "gif":
        return MessageType.Gif;
      case "location":
        return MessageType.Location;
      case "social":
        return MessageType.Social;
      case "contact":
        return MessageType.Contact;
      case "story_reply":
      // NEW backend's wire name for a story reply (§6.8 — no dedicated
      // model, just `type: 'feed_reference'` + a free-form metadata bag).
      case "feed_reference":
        return MessageType.StoryReply;
      case "link":
        return MessageType.Link;
      case "voice":
        return MessageType.Voice;
      case "poll":
        return MessageType.Poll;
      default:
        return MessageType.Text; // Default fallback
    }
  }

  /// Get display name for message type (for UI purposes)
  static String getDisplayName(MessageType messageType) {
    switch (messageType) {
      case MessageType.Text:
        return AppString.text;
      case MessageType.Image:
        return AppString.image;
      case MessageType.File:
        return AppString.document;
      case MessageType.Video:
        return AppString.video;
      case MessageType.Gif:
        return AppString.gif;
      case MessageType.Location:
        return AppString.location;
      case MessageType.Social:
        return AppString.socialPost;
      case MessageType.Contact:
        return AppString.contact;
      case MessageType.StoryReply:
        return AppString.storyReply;
      case MessageType.Link:
        return AppString.link;
      case MessageType.Voice:
        return AppString.voice;
      case MessageType.Poll:
        return AppString.poll;
    }
  }

  /// Converts the app's internal wire-type string (still OLD-shaped, e.g.
  /// "doc"/"voice" — used throughout ~35-40 widget `case` sites) to NEW's
  /// renamed value for outgoing requests only (§6.5: doc -> document,
  /// voice -> audio). Applied once at MessageRepository's send call.
  static String toNewOutgoingType(String internalType) {
    switch (internalType) {
      case 'doc':
        return 'document';
      case 'voice':
        return 'audio';
      case 'story_reply':
        return 'feed_reference';
      // NEW has no `link` type (SendMessageDto rejects it) — a link is sent
      // as plain text and recognised again on the way in (MessageAdapter).
      case 'link':
        return 'text';
      default:
        return internalType;
    }
  }

  /// Converts a NEW response's `type` field back to the internal
  /// OLD-shaped value so every existing widget `case 'doc':`/`case
  /// 'voice':` keeps matching unchanged. Applied once at MessageAdapter
  /// when parsing a message DTO — never touches local cache
  /// (de)serialization (Records.toJson/fromJson), only the network
  /// boundary.
  static String fromNewIncomingType(String? newType) {
    switch (newType) {
      case 'document':
        return 'doc';
      case 'audio':
        return 'voice';
      case 'feed_reference':
        return 'story_reply';
      default:
        return newType ?? 'text';
    }
  }

  /// Check if message type requires file upload
  static bool requiresFileUpload(MessageType messageType) {
    return messageType == MessageType.Image ||
        messageType == MessageType.File ||
        messageType == MessageType.Video ||
        messageType == MessageType.Gif ||
        messageType == MessageType.Voice;
  }

  /// Get appropriate file picker extensions for message type
  static List<String>? getAllowedExtensions(MessageType messageType) {
    switch (messageType) {
      case MessageType.Image:
        return ['jpg', 'jpeg', 'png', 'webp', 'gif'];
      case MessageType.File:
        return ['pdf', 'doc', 'docx', 'txt'];
      case MessageType.Video:
        return ['mp4', 'mov', 'avi', 'hevc', 'h.264', 'mkv'];
      case MessageType.Gif:
        return ['gif'];
      default:
        return null;
    }
  }
}
