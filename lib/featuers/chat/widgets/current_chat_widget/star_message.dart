// ========================================
// star_indicator_widget.dart - Reusable Star Component
// ========================================

import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';

/// Reusable star indicator widget for starred messages
class StarIndicatorWidget extends StatelessWidget {
  final bool isStarred;
  final bool isSentByMe;
  final StarDisplayType displayType;
  final double? iconSize;
  final Color? starColor;

  const StarIndicatorWidget({
    super.key,
    required this.isStarred,
    required this.isSentByMe,
    this.displayType = StarDisplayType.iconOnly,
    this.iconSize,
    this.starColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isStarred) return const SizedBox.shrink();

    switch (displayType) {
      case StarDisplayType.iconOnly:
        return _buildIconOnly();
      case StarDisplayType.iconWithText:
        return _buildIconWithText(context);
      case StarDisplayType.badge:
        return _buildBadge(context);
      case StarDisplayType.subtle:
        return _buildSubtle();
    }
  }

  /// Simple star icon only
  Widget _buildIconOnly() {
    return Icon(Icons.star, color: _getStarColor(), size: iconSize ?? 12);
  }

  /// Star icon with "Starred" text
  Widget _buildIconWithText(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, color: _getStarColor(), size: iconSize ?? 12),
        SizedBox(width: SizeConfig.width(1)),
        Text(
          'Starred',
          style: AppTypography.captionText(context).copyWith(
            color: _getStarColor(),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Badge style with background
  Widget _buildBadge(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.width(2),
        vertical: SizeConfig.height(0.2),
      ),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: Colors.white, size: iconSize ?? 10),
          SizedBox(width: SizeConfig.width(1)),
          Text(
            'Starred',
            style: AppTypography.captionText(context).copyWith(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Subtle star with reduced opacity
  Widget _buildSubtle() {
    return Icon(
      Icons.star,
      color: _getStarColor().withValues(alpha: 0.7),
      size: iconSize ?? 10,
    );
  }

  /// Get appropriate star color based on message sender and theme
  Color _getStarColor() {
    if (starColor != null) return starColor!;

    if (isSentByMe) {
      // For sent messages (usually with dark background)
      return Colors.white.withValues(alpha: 0.9);
    } else {
      // For received messages (usually with light background)
      return Colors.amber;
    }
  }
}

/// Available display types for star indicator
enum StarDisplayType {
  /// Just the star icon
  iconOnly,

  /// Star icon with "Starred" text
  iconWithText,

  /// Badge style with background
  badge,

  /// Subtle star with reduced opacity
  subtle,
}

/// Factory methods for common star configurations
extension StarIndicatorFactory on StarIndicatorWidget {
  /// Create star for metadata row (subtle, small)
  static Widget forMetadata({
    required bool isStarred,
    required bool isSentByMe,
  }) {
    return StarIndicatorWidget(
      isStarred: isStarred,
      isSentByMe: isSentByMe,
      displayType: StarDisplayType.iconOnly,
      iconSize: 12,
    );
  }

  /// Create star badge for overlay (more prominent)
  static Widget forBadge({required bool isStarred, required bool isSentByMe}) {
    return StarIndicatorWidget(
      isStarred: isStarred,
      isSentByMe: isSentByMe,
      displayType: StarDisplayType.badge,
      iconSize: 10,
    );
  }

  /// Create star with text for standalone display
  static Widget withText({required bool isStarred, required bool isSentByMe}) {
    return StarIndicatorWidget(
      isStarred: isStarred,
      isSentByMe: isSentByMe,
      displayType: StarDisplayType.iconWithText,
      iconSize: 14,
    );
  }

  /// Create subtle star for secondary contexts
  static Widget subtle({required bool isStarred, required bool isSentByMe}) {
    return StarIndicatorWidget(
      isStarred: isStarred,
      isSentByMe: isSentByMe,
      displayType: StarDisplayType.subtle,
      iconSize: 10,
    );
  }
}
