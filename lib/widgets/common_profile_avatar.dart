import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/utils/avatar_initials.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

/// Default "not found" profile image URL from backend
const String kNotFoundProfileImageUrl =
    '${ApiEndpoints.socketUrl}/uploads/not-found-images/profile-image.png';

/// Display name for a user whose profile has `isDeleted: true` (see
/// ContactNameService.resolveName). An avatar for this name always renders
/// the default placeholder icon, never a (possibly cached) picture.
const String kDeletedAccountName = 'Deleted Account';

/// A universal avatar widget that handles profile images consistently across the app.
///
/// Features:
/// - Displays network image if valid URL is provided
/// - Shows letter avatar when image URL is null, empty, or the "not-found" URL
/// - Falls back to letter avatar on image load error
/// - Uses CachedNetworkImage for performance
/// - Generates initials from user name
class CommonProfileAvatar extends StatelessWidget {
  /// The profile image URL from backend
  final String? imageUrl;

  /// The user's display name (used to generate initials)
  final String name;

  /// The radius of the avatar
  final double radius;

  /// Background color for the letter avatar (optional)
  final Color? backgroundColor;

  /// Text color for the initials (optional)
  final Color? textColor;

  /// Font size for the initials (optional, defaults to radius * 0.8)
  final double? fontSize;

  /// Whether this is a group avatar
  final bool isGroup;

  const CommonProfileAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.radius = 24,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.isGroup = false,
  });

  /// Checks if the profile image URL is valid and should be loaded
  bool get _hasValidImageUrl {
    if (imageUrl == null || imageUrl!.isEmpty) return false;
    if (imageUrl == kNotFoundProfileImageUrl) return false;
    if (!imageUrl!.startsWith('http://') && !imageUrl!.startsWith('https://')) {
      return false;
    }
    return true;
  }

  /// Generates initials from the user's name. Delegates to the app-wide
  /// [avatarInitials] helper so every list renders the same person identically.
  String get _initials => avatarInitials(name, isGroup: isGroup);

  /// Gets the background color for the avatar
  Color get _backgroundColor {
    if (backgroundColor != null) return backgroundColor!;
    return AppColors.textColor.textDarkGray;
  }

  /// Gets the text color for the initials
  Color get _textColor {
    if (textColor != null) return textColor!;
    return AppColors.textColor.textWhiteColor;
  }

  /// Gets the font size for the initials
  double get _fontSize {
    if (fontSize != null) return fontSize!;
    return radius * 0.8;
  }

  bool get _isDeletedAccount => !isGroup && name == kDeletedAccountName;

  @override
  Widget build(BuildContext context) {
    if (_isDeletedAccount) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: _backgroundColor,
        child: Icon(Icons.person, color: _textColor, size: radius * 1.2),
      );
    }
    if (_hasValidImageUrl) {
      return _buildNetworkAvatar(context);
    }
    return _buildLetterAvatar();
  }

  /// Builds the network image avatar with error fallback
  Widget _buildNetworkAvatar(BuildContext context) {
    // Cap the decoded bitmap to the avatar's actual on-screen size (in
    // physical pixels) instead of letting cached_network_image decode the
    // source image at full resolution — this widget renders on nearly every
    // screen in the app (chat list, chat thread, contacts, group info), so
    // avatars sourced from large originals were paying a real memory/decode
    // tax for pixels that were never shown.
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheDimension = (radius * 2 * devicePixelRatio).round();

    return CircleAvatar(
      radius: radius,
      backgroundColor: _backgroundColor,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          // Only cap ONE axis: passing both memCacheWidth and memCacheHeight
          // makes ResizeImage decode to an exact square, discarding the
          // source aspect ratio and squishing portrait photos before
          // BoxFit.cover can crop them. Constraining width alone keeps the
          // decoded bitmap proportional while still capping decode cost.
          memCacheWidth: cacheDimension,
          placeholder: (context, url) => _buildLetterAvatar(),
          errorWidget: (context, url, error) => _buildLetterAvatar(),
        ),
      ),
    );
  }

  /// Builds the letter avatar with initials
  Widget _buildLetterAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _backgroundColor,
      child: isGroup && (name.isEmpty || name == 'Unknown')
          ? Icon(
              Icons.group,
              color: _textColor,
              size: radius,
            )
          : Text(
              _initials,
              style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.bold,
                fontSize: _fontSize,
              ),
            ),
    );
  }
}
