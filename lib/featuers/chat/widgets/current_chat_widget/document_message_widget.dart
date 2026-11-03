// import 'package:flutter/material.dart';
// import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
// import 'package:whoxa/featuers/chat/widgets/current_chat_widget/base_message_widget.dart';
// import 'package:whoxa/utils/app_size_config.dart';
// import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
// import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';

// class DocumentMessageWidget extends BaseMessageWidget {
//   final VoidCallback? onTap;
//   final ChatProvider chatProvider;

//   const DocumentMessageWidget({
//     super.key,
//     required super.chat,
//     required super.currentUserId,
//     required this.chatProvider,
//     this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<bool>(
//       future: chatProvider.isPdfDownloaded(chat.messageContent!),
//       builder: (context, downloadSnapshot) {
//         return ValueListenableBuilder<double>(
//           // You'll need to implement a ValueNotifier for download progress
//           valueListenable: ValueNotifier<double>(0.0),
//           builder: (context, downloadProgress, child) {
//             final isDownloaded = downloadSnapshot.data ?? false;
//             final isDownloading = downloadProgress > 0 && downloadProgress < 1;
//             final fileName = chat.messageContent?.split('/').last ?? 'Document';

//             return GestureDetector(
//               onTap: isDownloading ? null : () => _handleDocumentDownload(),
//               child: Container(
//                 constraints: BoxConstraints(
//                   maxWidth: SizeConfig.screenWidth * 0.75,
//                 ),
//                 decoration: BoxDecoration(
//                   color: messageBackgroundColor,
//                   borderRadius: messageBorderRadius,
//                 ),
//                 padding: SizeConfig.getPaddingSymmetric(
//                   horizontal: 12,
//                   vertical: 8,
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Container(
//                       width: 40,
//                       height: 40,
//                       decoration: BoxDecoration(
//                         color: AppColors.textColor.textErrorColor.withValues(alpha:
//                           0.1,
//                         ),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Icon(
//                         Icons.picture_as_pdf,
//                         color: AppColors.textColor.textErrorColor,
//                         size: 24,
//                       ),
//                     ),
//                     SizedBox(width: SizeConfig.width(3)),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Text(
//                             fileName,
//                             style: AppTypography.mediumText(context).copyWith(
//                               color: messageTextColor,
//                               fontWeight: FontWeight.w500,
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                           SizedBox(height: 2),
//                           FutureBuilder<String>(
//                             future:
//                                 isDownloaded
//                                     ? chatProvider.getPdfMetadataWhenDownloaded(
//                                       chat.messageContent!,
//                                     )
//                                     : chatProvider.getPdfMetadata(
//                                       chat.messageContent!,
//                                     ),
//                             builder: (context, metadataSnapshot) {
//                               if (metadataSnapshot.connectionState ==
//                                   ConnectionState.waiting) {
//                                 return Text(
//                                   'Loading...',
//                                   style: AppTypography.captionText(
//                                     context,
//                                   ).copyWith(
//                                     color: messageTextColor.withValues(alpha: 0.7),
//                                   ),
//                                 );
//                               }
//                               return Text(
//                                 metadataSnapshot.data ?? 'Unknown PDF',
//                                 style: AppTypography.captionText(
//                                   context,
//                                 ).copyWith(
//                                   color: messageTextColor.withValues(alpha: 0.7),
//                                 ),
//                               );
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
//                     if (!isDownloaded) ...[
//                       SizedBox(width: SizeConfig.width(2)),
//                       Container(
//                         width: 32,
//                         height: 32,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           color: messageTextColor.withValues(alpha: 0.1),
//                         ),
//                         child:
//                             isDownloading
//                                 ? Stack(
//                                   alignment: Alignment.center,
//                                   children: [
//                                     CircularProgressIndicator(
//                                       value: downloadProgress,
//                                       strokeWidth: 2,
//                                       valueColor: AlwaysStoppedAnimation<Color>(
//                                         messageTextColor,
//                                       ),
//                                     ),
//                                     Icon(
//                                       Icons.download,
//                                       size: 16,
//                                       color: messageTextColor,
//                                     ),
//                                   ],
//                                 )
//                                 : Icon(
//                                   Icons.download,
//                                   size: 16,
//                                   color: messageTextColor,
//                                 ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   void _handleDocumentDownload() {
//     chatProvider.downloadPdfWithProgress(
//       pdfUrl: chat.messageContent!,
//       onProgress: (progress) {
//         // Update progress notifier here
//       },
//       onComplete: (filePath, metadata) {
//         if (filePath != null && onTap != null) {
//           onTap!();
//         }
//       },
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/screens/pdf_viewer_screen.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/base_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/delete_message_widget.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/file_name_utils.dart';

class DocumentMessageWidget extends BaseMessageWidget {
  final VoidCallback? onTap;
  final ChatProvider chatProvider;
  final bool isStarred; // ✅ NEW: Star status parameter
  final Function(int)? onReplyTap; // ✅ NEW: Callback for reply tap
  final bool isForPinned;
  final bool openedFromStarred; // If Opened from the Starred Messages Screen

  const DocumentMessageWidget({
    super.key,
    required super.chat,
    required super.currentUserId,
    required this.chatProvider,
    this.onTap,
    this.isStarred = false, // ✅ NEW: Default to false
    this.onReplyTap, // ✅ NEW: Optional callback for reply tap
    required this.isForPinned,
    this.openedFromStarred =
        false, // If Opened from the Starred Messages Screen
  });

  @override
  Widget build(BuildContext context) {
    final downloadProgress = ValueNotifier<double>(0.0);
    final isSentByMe = chat.senderId.toString() == currentUserId;
    final hasParentMessage = chat.parentMessage != null;

    // ✅ Additional safety check: if message is deleted, don't render document
    if (chat.messageContent == 'This message was deleted.' ||
        chat.messageContent == 'This message was deleted' ||
        chat.deletedForEveryone == true) {
      return DeletedMessageWidget(chat: chat, currentUserId: currentUserId);
    }

    return FutureBuilder<bool>(
      future: chatProvider.isPdfDownloaded(chat.messageContent!),
      builder: (context, downloadSnapshot) {
        return ValueListenableBuilder<double>(
          valueListenable: downloadProgress,
          builder: (context, progress, child) {
            final isDownloaded = downloadSnapshot.data ?? false;
            final isDownloading = progress > 0 && progress < 1;
            final fileName = prettyFileNameFromUrl(
              chat.messageContent,
              fallback: 'Document',
            );

            return GestureDetector(
              onTap:
                  openedFromStarred
                      ? onTap
                      : isDownloading
                      ? null
                      : () => _handleDocumentAction(
                        context,
                        downloadProgress,
                        fileName,
                      ),
              child: Column(
                crossAxisAlignment:
                    openedFromStarred
                        ? CrossAxisAlignment.start
                        : isSentByMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: SizeConfig.screenWidth * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: messageBackgroundColor,
                      borderRadius:
                          (openedFromStarred && isSentByMe)
                              ? BorderRadius.circular(9)
                              : AppDirectionality.appDirectionBorderRadius
                                  .chatBubbleRadius(
                                    isSentByMe: isSentByMe,
                                    hasParentMessage: false,
                                  ),
                    ),
                    padding: SizeConfig.getPaddingSymmetric(
                      horizontal: 5,
                      vertical: 5,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isSentByMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ✅ NEW: Show parent message if this is a reply
                        if (hasParentMessage) ...[
                          isForPinned
                              ? SizedBox.shrink()
                              : _buildParentMessagePreview(context, isSentByMe),
                          isForPinned ? SizedBox.shrink() : SizedBox(height: 3),
                        ],
                        // Main document content
                        Container(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeManage.appTheme.darkGreyColor,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                AppAssets.chatImage.pdfImage,
                                height: SizeConfig.sizedBoxHeight(30),
                              ),
                              SizedBox(width: SizeConfig.width(3)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      fileName,
                                      style: AppTypography.mediumText(
                                        context,
                                      ).copyWith(
                                        // Reads at the same weight as the chat
                                        // body now that bubbles use 15px.
                                        fontSize: SizeConfig.getFontSize(13),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2),
                                    FutureBuilder<String>(
                                      future: _getFileMetadata(fileName),
                                      builder: (context, metadataSnapshot) {
                                        return Text(
                                          _metadataOrFallback(
                                            metadataSnapshot.data,
                                            fileName,
                                          ),
                                          style: AppTypography.captionText(
                                            context,
                                          ).copyWith(
                                            fontSize: SizeConfig.getFontSize(9),
                                            color:
                                                AppColors
                                                    .textColor
                                                    .textDarkGray,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if (!isDownloaded)
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: SizeConfig.width(2),
                                  ),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.textColor.textDarkGray,
                                      ),
                                    ),
                                    child:
                                        isDownloading
                                            ? Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                CircularProgressIndicator(
                                                  value: progress,
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(messageTextColor),
                                                ),
                                                SvgPicture.asset(
                                                  AppAssets
                                                      .chatImage
                                                      .downloadArrow,
                                                  height: 10,
                                                  colorFilter: ColorFilter.mode(
                                                    AppColors
                                                        .textColor
                                                        .textDarkGray,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                              ],
                                            )
                                            : Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: SvgPicture.asset(
                                                AppAssets
                                                    .chatImage
                                                    .downloadArrow,
                                                height: 10,
                                                colorFilter: ColorFilter.mode(
                                                  AppColors
                                                      .textColor
                                                      .textDarkGray,
                                                  BlendMode.srcIn,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: SizeConfig.height(1)),
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
          },
        );
      },
    );
  }

  void _handleDocumentDownload(
    BuildContext context,
    ValueNotifier<double> downloadProgress,
  ) {
    chatProvider.downloadPdfWithProgress(
      pdfUrl: chat.messageContent!,
      onProgress: (progress) {
        downloadProgress.value = progress;
      },
      onComplete: (filePath, metadata) {
        if (filePath != null) {
          _showOpenDialog(context, filePath);
        }
      },
    );
  }

  void _showOpenDialog(BuildContext context, String filePath) {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              children: [
                ListTile(
                  leading: SvgPicture.asset(
                    AppAssets.chatImage.pdfImage,
                    height: SizeConfig.sizedBoxHeight(30),
                  ),
                  // Icon(
                  //   _getFileIcon(chat.messageContent?.split('/').last ?? ''),
                  // ),
                  title: Text(
                    "Open ${_getFileTypeDisplay(prettyFileNameFromUrl(chat.messageContent, fallback: ''))}",
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openFile(context, filePath);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.cancel),
                  title: Text("Cancel"),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
    );
  }

  void _openPdfViewer(BuildContext context, String filePath) {
    final fileName = prettyFileNameFromUrl(
      chat.messageContent,
      fallback: 'Document.pdf',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                PdfViewerScreen(filePath: filePath, fileName: fileName),
      ),
    );
  }

  // File type handling methods
  // IconData _getFileIcon(String fileName) {
  //   final extension = fileName.toLowerCase().split('.').last;
  //   switch (extension) {
  //     case 'pdf':
  //       return Icons.picture_as_pdf;
  //     case 'doc':
  //     case 'docx':
  //       return Icons.description;
  //     case 'xls':
  //     case 'xlsx':
  //       return Icons.table_chart;
  //     case 'ppt':
  //     case 'pptx':
  //       return Icons.slideshow;
  //     case 'txt':
  //       return Icons.text_snippet;
  //     case 'jpg':
  //     case 'jpeg':
  //     case 'png':
  //     case 'gif':
  //       return Icons.image;
  //     case 'mp4':
  //     case 'avi':
  //     case 'mov':
  //       return Icons.video_file;
  //     case 'mp3':
  //     case 'wav':
  //     case 'aac':
  //       return Icons.audio_file;
  //     case 'zip':
  //     case 'rar':
  //     case '7z':
  //       return Icons.folder_zip;
  //     default:
  //       return Icons.insert_drive_file;
  //   }
  // }

  // Color _getFileIconColor(String fileName) {
  //   final extension = fileName.toLowerCase().split('.').last;
  //   switch (extension) {
  //     case 'pdf':
  //       return AppColors.textColor.textErrorColor;
  //     case 'doc':
  //     case 'docx':
  //       return Colors.blue;
  //     case 'xls':
  //     case 'xlsx':
  //       return Colors.green;
  //     case 'ppt':
  //     case 'pptx':
  //       return Colors.orange;
  //     case 'txt':
  //       return Colors.grey;
  //     case 'jpg':
  //     case 'jpeg':
  //     case 'png':
  //     case 'gif':
  //       return Colors.purple;
  //     case 'mp4':
  //     case 'avi':
  //     case 'mov':
  //       return Colors.red;
  //     case 'mp3':
  //     case 'wav':
  //     case 'aac':
  //       return Colors.cyan;
  //     case 'zip':
  //     case 'rar':
  //     case '7z':
  //       return Colors.brown;
  //     default:
  //       return AppColors.textColor.textErrorColor;
  //   }
  // }

  String _getFileTypeDisplay(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return 'PDF Document';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'xls':
      case 'xlsx':
        return 'Excel Spreadsheet';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint Presentation';
      case 'txt':
        return 'Text Document';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'Image File';
      case 'mp4':
      case 'avi':
      case 'mov':
        return 'Video File';
      case 'mp3':
      case 'wav':
      case 'aac':
        return 'Audio File';
      case 'zip':
      case 'rar':
      case '7z':
        return 'Archive File';
      default:
        return 'Document';
    }
  }

  Future<String> _getFileMetadata(String fileName) async {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        // Reads the already-downloaded local copy when present, otherwise
        // fetches the remote file — so a PDF that was opened once keeps
        // showing its real "N Pages • PDF • X.XX MB" line instead of
        // "Unknown PDF".
        return await chatProvider.getPdfMetadataForUrl(chat.messageContent!);
      default:
        return _getFileTypeDisplay(fileName);
    }
  }

  /// The PDF-metadata helpers return the sentinel strings "Unknown PDF" /
  /// "Error loading PDF" when the file can't be read (offline, expired
  /// URL). Don't surface those to the user — fall back to a plain
  /// "PDF Document" / file-type label instead.
  String _metadataOrFallback(String? data, String fileName) {
    if (data == null ||
        data.isEmpty ||
        data == 'Unknown PDF' ||
        data == 'Error loading PDF') {
      return _getFileTypeDisplay(fileName);
    }
    return data;
  }

  void _handleDocumentAction(
    BuildContext context,
    ValueNotifier<double> downloadProgress,
    String fileName,
  ) {
    final extension = fileName.toLowerCase().split('.').last;

    if (extension == 'pdf') {
      _handleDocumentDownload(context, downloadProgress);
    } else {
      _openFileDirectly(context);
    }
  }

  void _openFileDirectly(BuildContext context) async {
    try {
      final uri = Uri.parse(chat.messageContent!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        _showErrorDialog(context, 'Cannot open this file type');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, 'Error opening file: $e');
    }
  }

  void _openFile(BuildContext context, String filePath) {
    final extension = filePath.toLowerCase().split('.').last;

    if (extension == 'pdf') {
      _openPdfViewer(context, filePath);
    } else {
      _openWithSystemApp(context, filePath);
    }
  }

  void _openWithSystemApp(BuildContext context, String filePath) async {
    try {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        _showErrorDialog(context, 'No app found to open this file type');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, 'Error opening file: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppString.error),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppString.ok),
              ),
            ],
          ),
    );
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
        constraints: BoxConstraints(maxWidth: SizeConfig.screenWidth * 0.75),
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
