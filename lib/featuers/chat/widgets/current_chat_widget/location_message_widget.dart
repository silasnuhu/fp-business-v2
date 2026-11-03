import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/base_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/delete_message_widget.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

class LocationMessageWidget extends BaseMessageWidget {
  final VoidCallback? onTap;
  final double? latitude;
  final double? longitude;
  final bool isStarred; // ✅ NEW: Star status parameter
  final Function(int)? onReplyTap; // ✅ NEW: Callback for reply tap
  final bool isForPinned;
  final bool openedFromStarred; // ✅ NEW: Opened from starred messages

  const LocationMessageWidget({
    super.key,
    required super.chat,
    required super.currentUserId,
    required this.isForPinned,
    this.onTap,
    this.latitude,
    this.longitude,
    this.isStarred = false, // ✅ NEW: Default to false
    this.onReplyTap, // ✅ NEW: Optional callback for reply tap
    this.openedFromStarred = false, // ✅ NEW: Opened from starred messages
  });

  @override
  Widget build(BuildContext context) {
    final isSentByMe = chat.senderId.toString() == currentUserId;
    final hasParentMessage = chat.parentMessage != null;

    // ✅ Additional safety check: if message is deleted, don't render location
    if (chat.messageContent == 'This message was deleted.' ||
        chat.messageContent == 'This message was deleted' ||
        chat.deletedForEveryone == true) {
      return DeletedMessageWidget(chat: chat, currentUserId: currentUserId);
    }

    GoogleMapController? mapcontroller;

    Future<String> loadMapStyle(bool isDark) async {
      return await rootBundle.loadString(
        isDark ? AppAssets.lightMap : AppAssets.darkMap,
      );
    }

    return GestureDetector(
      onTap:
          openedFromStarred
              ? onTap
              : isForPinned
              ? () {}
              : () => _openInGoogleMaps(),
      child: Column(
        crossAxisAlignment:
            openedFromStarred
                ? CrossAxisAlignment.start
                : isSentByMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: [
          Container(
            width:
                isForPinned
                    ? SizeConfig.screenWidth * 0.5
                    : SizeConfig.screenWidth * 0.7,
            height:
                isForPinned
                    ? SizeConfig.height(15)
                    : hasParentMessage
                    ? SizeConfig.height(30)
                    : SizeConfig.height(20),
            decoration: BoxDecoration(
              color: messageBackgroundColor,
              borderRadius:
                  (openedFromStarred && isSentByMe)
                      ? BorderRadius.circular(7)
                      : messageBorderRadius,
              border:
                  isSentByMe
                      ? Border.all(
                        color: (Fp.dark ? Fp.violet.withValues(alpha: 0.32) : const Color(0xFFEDE6FF)),
                        width: isForPinned ? 4 : 2,
                      )
                      : Border.all(
                        color: AppThemeManage.appTheme.chatOppoColor,
                        width: isForPinned ? 4 : 2,
                      ),
            ),
            child: Column(
              children: [
                // ✅ NEW: Show parent message if this is a reply
                if (hasParentMessage) ...[
                  isForPinned
                      ? SizedBox.shrink()
                      : _buildParentMessagePreview(context, isSentByMe),
                  SizedBox(height: 3),
                ],
                Expanded(
                  child: ClipRRect(
                    borderRadius: messageBorderRadius,
                    child: Stack(
                      children: [
                        // Google Maps view
                        if (latitude != null && longitude != null)
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(latitude!, longitude!),
                              zoom: 16.0,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('location'),
                                position: LatLng(latitude!, longitude!),
                                infoWindow: const InfoWindow(
                                  title: 'Shared Location',
                                ),
                              ),
                            },
                            zoomControlsEnabled: false,
                            scrollGesturesEnabled: false,
                            rotateGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            mapToolbarEnabled: false,
                            compassEnabled: false,
                            onMapCreated: (
                              GoogleMapController controller,
                            ) async {
                              mapcontroller = controller;
                              final style = await loadMapStyle(
                                isLightModeGlobal,
                              );
                              // ignore: deprecated_member_use
                              mapcontroller!.setMapStyle(style);
                            },
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.appPriSecColor.primaryColor
                                  .withValues(alpha: 0.1),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 40,
                                  color: AppColors.appPriSecColor.primaryColor,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Location',
                                  style: AppTypography.mediumText(
                                    context,
                                  ).copyWith(
                                    color:
                                        AppColors.appPriSecColor.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Open in new icon (top right)
                        if (latitude != null && longitude != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppThemeManage.appTheme.whiteBorder,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.open_in_new,
                                size: 16,
                                color: AppColors.appPriSecColor.primaryColor,
                              ),
                            ),
                          ),
                        isForPinned
                            ? SizedBox.shrink()
                            : Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: SizeConfig.sizedBoxHeight(27),
                                color:
                                    isSentByMe
                                        ? AppColors
                                            .appPriSecColor
                                            .secondaryColor
                                        : AppThemeManage.appTheme.chatOppoColor,
                                child: Center(
                                  child: Text(
                                    AppString.viewLocation,
                                    style: AppTypography.innerText12Mediu(
                                      context,
                                    ).copyWith(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isSentByMe
                                              ? ThemeColorPalette.getTextColor(
                                                AppColors
                                                    .appPriSecColor
                                                    .primaryColor,
                                              )
                                              // AppColors
                                              //     .textColor
                                              //     .textBlackColor
                                              : AppThemeManage
                                                  .appTheme
                                                  .textColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          isForPinned
              ? SizedBox.shrink()
              : SizedBox(height: SizeConfig.height(1)),
          (isForPinned || openedFromStarred)
              ? SizedBox.shrink()
              : ChatRelatedWidget.buildMetadataRow(
                context: context,
                chat: chat,
                isStarred: isStarred,
                isSentByMe: isSentByMe,
              ),
          (isForPinned || openedFromStarred)
              ? SizedBox.shrink()
              : SizedBox(height: SizeConfig.height(0)),
        ],
      ),
    );
  }

  Future<void> _openInGoogleMaps() async {
    if (latitude == null || longitude == null) return;

    final url =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening Google Maps: $e');
    }
  }

  /// Build parent message preview with tap functionality
  Widget _buildParentMessagePreview(BuildContext context, bool isSentByMe) {
    final parentMessage = chat.parentMessage!;
    final parentContent = parentMessage['message_content'] ?? 'Message';
    final parentType = parentMessage['message_type'] ?? 'text';
    final parentThumbnail = parentMessage['message_thumbnail'];
    final parentMessageId = parentMessage['message_id'];

    return GestureDetector(
      onTap: () {
        // Handle tap to navigate to original message
        if (onReplyTap != null && parentMessageId != null) {
          onReplyTap!(parentMessageId as int);
        }
      },
      child: Container(
        constraints: BoxConstraints(maxWidth: SizeConfig.width(70)),
        padding: SizeConfig.getPaddingSymmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: AppThemeManage.appTheme.bg488DarkGrey,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with reply icon and sender name
            Row(
              children: [
                Text(
                  ChatRelatedWidget.getSenderName(
                    context,
                    parentMessage,
                    currentUserId,
                  ),
                  style: AppTypography.captionText(context).copyWith(
                    color: AppColors.appPriSecColor.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),

            // Content preview
            _buildParentMessageContent(
              context,
              parentType,
              parentContent,
              parentThumbnail,
              isSentByMe,
            ),
          ],
        ),
      ),
    );
  }

  /// Build parent message content based on type
  Widget _buildParentMessageContent(
    BuildContext context,
    String messageType,
    String content,
    String? thumbnail,
    bool isSentByMe,
  ) {
    // ✅ Check if the message is deleted and show only text
    if (content == 'This message was deleted.' ||
        content == 'This message was deleted' ||
        content.isEmpty) {
      return ChatRelatedWidget.buildTextPreview(
        context: context,
        content: AppString.thisMessageWasDeleted,
        isSentByMe: isSentByMe,
      );
    }

    switch (messageType.toLowerCase()) {
      case 'voice':
        return ChatRelatedWidget.buildVoicePreview(
          context: context,
          isSentByMe: isSentByMe,
        );
      case 'image':
        return ChatRelatedWidget.buildImagePreview(
          context: context,
          imageUrl: content,
          isSentByMe: isSentByMe,
        );
      case 'video':
        return ChatRelatedWidget.buildVideoPreview(
          context: context,
          videoUrl: content,
          thumbnailUrl: thumbnail,
          isSentByMe: isSentByMe,
        );
      case 'document':
      case 'doc':
      case 'pdf':
        return ChatRelatedWidget.buildDocumentPreview(context, isSentByMe);
      case 'location':
        return ChatRelatedWidget.buildLocationPreview(context, isSentByMe);
      case 'contact':
        return ChatRelatedWidget.buildContactPreview(context, isSentByMe);
      case 'link':
        return ChatRelatedWidget.buildLinkPreview(
          context: context,
          content: content,
          isSentByMe: isSentByMe,
        );
      case 'poll':
        return ChatRelatedWidget.buildPollPreview(
          context: context,
          content: content,
          isSentByMe: isSentByMe,
        );
      case 'text':
      default:
        return ChatRelatedWidget.buildTextPreview(
          context: context,
          content: content,
          isSentByMe: isSentByMe,
        );
    }
  }
}
