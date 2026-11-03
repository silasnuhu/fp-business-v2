// import 'package:flutter/material.dart';
// import 'package:whoxa/utils/app_size_config.dart';
// import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
// import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
// import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
// import 'package:whoxa/utils/preference_key/constant/strings.dart';

// class ChatAppbarTitle extends StatefulWidget {
//   final String profile;
//   final String title;
//   final String onlineStatus;
//   final Function() onTap;

//   const ChatAppbarTitle({
//     super.key,
//     required this.profile,
//     required this.title,
//     required this.onlineStatus,
//     required this.onTap,
//   });

//   @override
//   State<ChatAppbarTitle> createState() => _ChatAppbarTitleState();
// }

// class _ChatAppbarTitleState extends State<ChatAppbarTitle>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _animation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 1500),
//       vsync: this,
//     );
//     _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
//     );

//     // Start animation if typing
//     if (widget.onlineStatus == "typing...") {
//       _animationController.repeat();
//     }
//   }

//   @override
//   void didUpdateWidget(ChatAppbarTitle oldWidget) {
//     super.didUpdateWidget(oldWidget);

//     // Handle typing animation state changes
//     if (widget.onlineStatus == "typing..." &&
//         oldWidget.onlineStatus != "typing...") {
//       _animationController.repeat();
//     } else if (widget.onlineStatus != "typing..." &&
//         oldWidget.onlineStatus == "typing...") {
//       _animationController.stop();
//       _animationController.reset();
//     }
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   Widget _buildOnlineStatusText() {
//     if (widget.onlineStatus == "typing...") {
//       return AnimatedBuilder(
//         animation: _animation,
//         builder: (context, child) {
//           return Row(
//             children: [
//               Text(
//                 "typing",
//                 style: AppTypography.mediumText(context).copyWith(
//                   color: AppColors.textColor.textWhiteColor.withValues(
//                     alpha: 0.72,
//                   ),
//                 ),
//               ),
//               SizedBox(width: 2),
//               // Animated typing dots
//               Row(
//                 children: List.generate(3, (index) {
//                   final delay = index * 0.3;
//                   final opacity =
//                       _animation.value > delay && _animation.value < delay + 0.3
//                           ? 1.0
//                           : 0.3;
//                   return Container(
//                     margin: EdgeInsets.only(right: 2),
//                     child: Opacity(
//                       opacity: opacity,
//                       child: Text(
//                         "•",
//                         style: AppTypography.mediumText(context).copyWith(
//                           color: AppColors.textColor.textWhiteColor,
//                           fontSize: 16,
//                         ),
//                       ),
//                     ),
//                   );
//                 }),
//               ),
//             ],
//           );
//         },
//       );
//     } else {
//       // Display online/offline status with appropriate color
//       final isOnline = widget.onlineStatus == AppString.online;
//       return Text(
//         widget.onlineStatus,
//         style: AppTypography.mediumText(context).copyWith(
//           color:
//               isOnline
//                   ? Colors
//                       .green // Green color for online
//                   : AppColors.textColor.textWhiteColor.withValues(alpha: 0.72),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: widget.onTap,
//       child: Row(
//         children: [
//           // Profile picture with online indicator
//           Stack(
//             children: [
//               SizedBox(
//                 height: SizeConfig.sizedBoxHeight(50),
//                 width: SizeConfig.sizedBoxWidth(50),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(50),
//                   child:
//                       widget.profile.isNotEmpty
//                           ? Image.network(
//                             widget.profile,
//                             fit: BoxFit.cover,
//                             errorBuilder: (context, error, stackTrace) {
//                               return Image.asset(
//                                 AppAssets.gpimage,
//                                 fit: BoxFit.cover,
//                               );
//                             },
//                           )
//                           : Image.asset(AppAssets.gpimage, fit: BoxFit.cover),
//                 ),
//               ),
//               // Online indicator dot
//               if (widget.onlineStatus == AppString.online)
//                 Positioned(
//                   bottom: 0,
//                   right: 0,
//                   child: Container(
//                     width: 14,
//                     height: 14,
//                     decoration: BoxDecoration(
//                       color: Colors.green,
//                       shape: BoxShape.circle,
//                       border: Border.all(color: Colors.white, width: 2),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//           SizedBox(width: SizeConfig.sizedBoxWidth(12)),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 // User name
//                 Text(
//                   widget.title,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: AppTypography.h4(
//                     context,
//                   ).copyWith(color: AppColors.textColor.textWhiteColor),
//                 ),
//                 SizedBox(height: 2),
//                 // Online status with animation
//                 _buildOnlineStatusText(),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';

class ChatAppbarTitle extends StatefulWidget {
  final String profile;
  final String title;
  final String? onlineStatus; // Make nullable
  final Widget? statusWidget; // Add widget option
  final Widget? avatar; // Replaces the profile-photo avatar when set
  final Function()? onTap; // null: title isn't tappable
  // false: title only — no status line under it (e.g. the AI Assistant)
  final bool showStatus;
  // Peer user id; when that user is premium a blue tick follows the title.
  final int? userId;

  const ChatAppbarTitle({
    super.key,
    required this.profile,
    required this.title,
    this.onlineStatus, // Optional string
    this.statusWidget, // Optional widget
    this.avatar,
    required this.onTap,
    this.showStatus = true,
    this.userId,
  }) : assert(
         (onlineStatus != null) ^ (statusWidget != null),
         'Either onlineStatus or statusWidget must be provided, but not both',
       );

  @override
  State<ChatAppbarTitle> createState() => _ChatAppbarTitleState();
}

class _ChatAppbarTitleState extends State<ChatAppbarTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Start animation if typing (only for string status)
    if (widget.onlineStatus == "typing...") {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(ChatAppbarTitle oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle typing animation state changes (only for string status)
    if (widget.onlineStatus != null) {
      if (widget.onlineStatus == "typing..." &&
          oldWidget.onlineStatus != "typing...") {
        _animationController.repeat();
      } else if (widget.onlineStatus != "typing..." &&
          oldWidget.onlineStatus == "typing...") {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get _currentStatus {
    return widget.onlineStatus ?? "";
  }

  Widget _buildOnlineStatusText() {
    // If statusWidget is provided, use it directly
    if (widget.statusWidget != null) {
      return widget.statusWidget!;
    }

    // Otherwise, use the original string-based logic
    if (_currentStatus == "typing...") {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Row(
            children: [
              Text(
                AppString.typing,
                style: AppTypography.mediumText(
                  context,
                ).copyWith(color: AppColors.textColor.textDarkGray),
              ),
              SizedBox(width: 2),
              // Animated typing dots
              Row(
                children: List.generate(3, (index) {
                  final delay = index * 0.3;
                  final opacity =
                      _animation.value > delay && _animation.value < delay + 0.3
                          ? 1.0
                          : 0.3;
                  return Container(
                    margin: EdgeInsets.only(right: 2),
                    child: Opacity(
                      opacity: opacity,
                      child: Text(
                        "•",
                        style: AppTypography.mediumText(context).copyWith(
                          color: AppColors.textColor.textDarkGray,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      );
    } else {
      // Display online/offline status with appropriate color
      final isOnline = _currentStatus == AppString.online;
      return Text(
        _currentStatus,
        style: AppTypography.mediumText(context).copyWith(
          color:
              isOnline
                  ? Colors
                      .green // Green color for online
                  : AppColors.textColor.textDarkGray,
        ),
      );
    }
  }

  bool get _isUserOnline {
    if (widget.statusWidget != null) {
      // For widget status, we can't easily determine online state
      // You might need to pass this as a separate parameter if needed
      return false;
    }
    return _currentStatus == AppString.online;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      child: Row(
        children: [
          // Profile picture with online indicator
          Stack(
            children: [
              widget.avatar ??
                  CommonProfileAvatar(
                    imageUrl: widget.profile,
                    name: widget.title,
                    radius: SizeConfig.sizedBoxHeight(25),
                  ),
              // Online indicator dot
              if (_isUserOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.textColor.textDarkGray,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: SizeConfig.sizedBoxWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // User name
                UserNameWithBadge(
                  userId: widget.userId,
                  name: widget.title,
                  badgeSize: 18,
                  style: AppTypography.h4(context),
                ),
                if (widget.showStatus) ...[
                  SizedBox(height: 2),
                  // Online status with animation or custom widget
                  _buildOnlineStatusText(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
