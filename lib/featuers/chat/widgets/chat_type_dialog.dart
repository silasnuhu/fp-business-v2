import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

// ✅ ENHANCED: Updated chatTypeDailog with multi-select support
Future chatTypeDailog(
  BuildContext context, {
  chats.Records? message,
  Function(chats.Records)? onPinUnpin,
  Function(chats.Records)? onReply,
  Function(chats.Records, bool)? onDelete,
  Function(chats.Records)? onStarUnstar,
  Function(chats.Records)? onMultiSelect, // ✅ RENAMED: From onMultiDelete to
  // Only passed for the user's own editable text messages — the caller
  // decides eligibility, so a null here simply hides the row.
  Function(chats.Records)? onEdit,
  bool isStarred = false,
}) {
  // ✅ ENHANCED: Calculate dynamic height based on available options
  double calculateDialogHeight() {
    int optionCount = 0;

    // Count available options
    if (message != null && onEdit != null) optionCount++; // Edit
    if (message != null && onPinUnpin != null) optionCount++; // Pin/Unpin
    optionCount++; // Copy (always available)
    optionCount++; // Reply (always available)
    optionCount++; // Forward (always available)
    if (message != null && onStarUnstar != null) optionCount++; // Star/Unstar
    if (message != null && onMultiSelect != null) {
      optionCount++; // ✅ Multi-Select
    }
    // ✅ DEMO MODE: Count delete option for all users (demo check handled in callback)
    if (message != null && onDelete != null) optionCount++; // Delete
    optionCount++; // Report (always available)

    // Calculate height: base height + (option count * item height)
    double baseHeight = 8; // Top/bottom padding
    double itemHeight =
        message!.messageType == 'text'
            ? 50
            : message.messageType == 'story_reply'
            ? 30
            : message.messageType == 'poll'
            ? 35
            : 40; // Each option height including divider

    return baseHeight + (optionCount * itemHeight);
  }

  Future ap = showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color.fromRGBO(0, 0, 0, 0.57),
    builder:
        (_) => Dialog(
          alignment: Alignment.bottomCenter,
          elevation: 0,
          insetPadding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
          backgroundColor: AppColors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3.8, sigmaY: 3.8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: SizeConfig.sizedBoxHeight(35),
                    width: SizeConfig.sizedBoxWidth(35),
                    decoration: BoxDecoration(
                      color: AppThemeManage.appTheme.darkGreyColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: AppThemeManage.appTheme.darkWhiteColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: SizeConfig.height(2)),
                Container(
                  height: SizeConfig.sizedBoxHeight(calculateDialogHeight()),
                  decoration: BoxDecoration(
                    color: AppThemeManage.appTheme.darkGreyColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: SizeConfig.getPaddingOnly(top: 5),
                    child: Scrollbar(
                      thumbVisibility: true,
                      thickness: 4.0,
                      radius: Radius.circular(10),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(right: 8),
                        child: Column(
                          children: [
                            Container(
                              height: 2,
                              width: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color:
                                    AppThemeManage.appTheme.textGreyblackGrey,
                              ),
                            ),
                            Padding(
                              padding: SizeConfig.getPaddingSymmetric(
                                vertical: 10,
                                horizontal: 15,
                              ),
                              child: messageContent(context, message),
                            ),
                            // Copy option
                            if (message!.messageType == 'text' ||
                                message.messageType == "link" ||
                                message.messageType == 'story_reply') ...[
                              dailogRow(
                                onTap: () {
                                  Navigator.pop(context);
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: message.messageContent ?? "",
                                    ),
                                  );
                                  snackbarNew(
                                    context,
                                    msg: AppString.messagecopied,
                                  );
                                },
                                context,
                                title: AppString.chatBubbleStrings.copy,
                                img: AppAssets.chatImage.copy,
                              ),
                              Divider(
                                color: AppThemeManage.appTheme.borderColor,
                              ),
                            ],

                            // Edit option (own text messages only)
                            if (onEdit != null) ...[
                              dailogRow(
                                onTap: () {
                                  Navigator.pop(context);
                                  onEdit(message);
                                },
                                context,
                                title: AppString.chatBubbleStrings.edit,
                                img: AppAssets.ibadahGroupIcons.edit,
                              ),
                              Divider(
                                color: AppThemeManage.appTheme.borderColor,
                              ),
                            ],

                            // Reply option
                            dailogRow(
                              onTap: () {
                                Navigator.pop(context);
                                if (onReply != null) {
                                  onReply(message);
                                }
                              },
                              context,
                              title: AppString.chatBubbleStrings.reply,
                              img: AppAssets.chatImage.reply,
                            ),
                            Divider(color: AppThemeManage.appTheme.borderColor),

                            // Forward
                            if (message.messageType != 'story_reply' &&
                                message.messageType != 'poll') ...[
                              if (onMultiSelect != null) ...[
                                dailogRow(
                                  onTap: () {
                                    Navigator.pop(context, 'forward');
                                    onMultiSelect(message);
                                  },
                                  context,
                                  title: AppString.chatBubbleStrings.forward,
                                  img: AppAssets.chatImage.forward,
                                ),
                                Divider(
                                  color: AppThemeManage.appTheme.borderColor,
                                ),
                              ],
                            ],

                            // Pin/Unpin option
                            if (message.messageType != 'story_reply') ...[
                              if (onPinUnpin != null) ...[
                                dailogRow(
                                  onTap: () {
                                    Navigator.pop(context);
                                    onPinUnpin(message);
                                  },
                                  context,
                                  title:
                                      message.pinned == true
                                          ? AppString
                                              .homeScreenString
                                              .unpinMessage
                                          : AppString
                                              .homeScreenString
                                              .pinMessage,
                                  img:
                                      message.pinned == true
                                          ? AppAssets.chatImage.unpinnedIcon
                                          : AppAssets.chatImage.pinborder,
                                  isPinOption: true,
                                  isPinned: message.pinned == true,
                                ),
                                Divider(
                                  color: AppThemeManage.appTheme.borderColor,
                                ),
                              ],
                            ],

                            // Star/Unstar option
                            if (message.messageType != 'story_reply') ...[
                              if (onStarUnstar != null) ...[
                                dailogRow(
                                  onTap: () {
                                    Navigator.pop(context);
                                    onStarUnstar(message);
                                  },
                                  context,
                                  title:
                                      isStarred
                                          ? AppString
                                              .settingStrigs
                                              .unstarMessage
                                          : AppString
                                              .chatBubbleStrings
                                              .starMessage,
                                  img:
                                      isStarred
                                          ? AppAssets
                                              .starredMessageIcon
                                              .starslash
                                          : AppAssets.chatImage.starMsg,
                                  isStarOption: true,
                                  isStarred: isStarred,
                                ),
                                Divider(
                                  color: AppThemeManage.appTheme.borderColor,
                                ),
                              ],
                            ],

                            // ✅ ENHANCED: Multi-Select option (renamed from Multi-Delete)
                            // if (message != null && onMultiSelect != null) ...[
                            //   dailogRow(
                            //     onTap: () {
                            //       Navigator.pop(context);
                            //       onMultiSelect(message);
                            //     },
                            //     context,
                            //     title: "Select Multiple", // ✅ More descriptive title
                            //     img: Icons.checklist,
                            //     isMultiSelectOption: true, // ✅ Renamed flag
                            //   ),
                            //   Divider(color: AppColors.bgColor.bg3Color),
                            // ],

                            // Delete option
                            // ✅ DEMO MODE: Show delete option for all users (demo check handled in callback)
                            if (onDelete != null) ...[
                              dailogRow(
                                onTap: () {
                                  Navigator.pop(context, 'delete');
                                  onDelete(
                                    message,
                                    false,
                                  ); // false = delete for me
                                },
                                context,
                                title: AppString.homeScreenString.deleteMessage,
                                img: AppAssets.trash,
                              ),
                            ],

                            // Report option
                            // dailogRow(
                            //   onTap: () {
                            //     Navigator.pop(context);
                            //     // Handle report
                            //   },
                            //   context,
                            //   title: AppString.chatBubbleStrings.report,
                            //   img: AppAssets.chatImage.report,
                            // ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
  return ap;
}

// ✅ ENHANCED: Updated dailogRow with multi-select styling
Widget dailogRow(
  BuildContext context, {
  required Function() onTap,
  required String title,
  required dynamic img,
  bool isPinOption = false,
  bool isPinned = false,
  bool isStarOption = false,
  bool isStarred = false,
  bool isMultiSelectOption = false, // ✅ RENAMED: From isMultiDeleteOption
}) {
  // ✅ ENHANCED: Updated color logic for multi-select
  Color getIconColor() {
    if (title.contains("Delete")) {
      return AppColors.textColor.textErrorColor1;
    } else {
      return AppThemeManage.appTheme.textColor;
    }
  }

  Color getTextColor() {
    if (title.contains("Delete")) {
      return AppColors.textColor.textErrorColor1;
    } else {
      return AppThemeManage.appTheme.textColor;
    }
  }

  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Icon handling with enhanced styling
          if (img is String)
            SvgPicture.asset(
              img,
              height: SizeConfig.sizedBoxHeight(20),
              colorFilter: ColorFilter.mode(getIconColor(), BlendMode.srcIn),
            )
          else if (img is IconData)
            // ✅ ENHANCED: Special animations for different option types
            _buildAnimatedIcon(
              img,
              getIconColor(),
              isStarOption,
              isStarred,
              isMultiSelectOption, // ✅ Updated parameter name
            ),

          SizedBox(width: SizeConfig.width(5)),

          // ✅ ENHANCED: Updated text styling
          Text(
            title,
            style: AppTypography.innerText14(context).copyWith(
              color: getTextColor(),
              fontWeight: FontWeight.w600,
              // fontWeight: _getTextWeight(
              //   isStarOption,
              //   isStarred,
              //   isMultiSelectOption, // ✅ Updated parameter name
              // ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ✅ ENHANCED: Updated helper method for animated icons
Widget _buildAnimatedIcon(
  IconData iconData,
  Color color,
  bool isStarOption,
  bool isStarred,
  bool isMultiSelectOption, // ✅ RENAMED: From isMultiDeleteOption
) {
  if (isStarOption && isStarred) {
    // Star animation
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300),
      tween: Tween(begin: 0.8, end: 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Icon(
            iconData,
            size: SizeConfig.sizedBoxHeight(20),
            color: color,
          ),
        );
      },
    );
  } else if (isMultiSelectOption) {
    // ✅ ENHANCED: Multi-select animation with improved visual feedback
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400),
      tween: Tween(begin: 0.9, end: 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.15,
              ), // ✅ Slightly more visible background
              borderRadius: BorderRadius.circular(
                6,
              ), // ✅ Slightly larger radius
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Icon(
              iconData,
              size: SizeConfig.sizedBoxHeight(18),
              color: color,
            ),
          ),
        );
      },
    );
  } else {
    // Default icon
    return Icon(iconData, size: SizeConfig.sizedBoxHeight(20), color: color);
  }
}

// ✅ ENHANCED: Updated dailogRow with message type wise content show
Widget messageContent(BuildContext context, chats.Records? message) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppThemeManage.appTheme.borderColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 15, vertical: 10),
      child:
          message!.messageType!.toLowerCase() == "text" ||
                  message.messageType!.toLowerCase() == "story_reply"
              ? Text(
                textMessageContent(
                  context,
                  messageContent: message.messageContent!,
                  messageType: message.messageType!.toLowerCase(),
                ),
                style: textStyle(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
              : Row(
                children: [
                  messageContentIcon(
                    context,
                    messageType: message.messageType!,
                  ),
                  SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      textMessageContent(
                        context,
                        messageContent: message.messageContent!,
                        messageType: message.messageType!.toLowerCase(),
                      ),
                      style: textStyle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
    ),
  );
}

String textMessageContent(
  BuildContext context, {
  required String messageType,
  required String messageContent,
}) {
  switch (messageType.toLowerCase()) {
    case 'text':
      return messageContent;
    case 'image':
      return 'Photo';
    case 'video':
      return 'Video';
    case 'document':
    case 'file':
    case 'doc':
    case 'pdf':
      return 'Document';
    case 'location':
      return 'Location';
    case 'audio':
      return 'Audio';
    case 'gif':
      return 'GIF';
    case 'contact':
      return 'Contact';
    case 'voice':
      return 'Voice message';
    default:
      return messageContent;
  }
}

TextStyle textStyle(BuildContext context) {
  return AppTypography.innerText12Mediu(
    context,
  ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 13);
}
