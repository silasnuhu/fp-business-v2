import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/data/models/link_model.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/metadata_service.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/shimmer.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class LinkMessageWidget extends StatelessWidget {
  final chats.Records chat;
  final String currentUserId;
  final bool isStarred; // ✅ NEW: Star status parameter
  final Function(int)? onReplyTap; // ✅ NEW: Callback for reply tap
  final bool openedFromStarred; // If Opened from the Starred Messages Screen
  final bool isForPinned;

  const LinkMessageWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
    this.isStarred = false, // ✅ NEW: Default to false
    this.onReplyTap, // ✅ NEW: Optional callback for reply tap
    this.openedFromStarred =
        false, // If Opened from the Starred Messages Screen
    required this.isForPinned,
  });

  // ✅ Extract first URL from any text (mixed or pure URL)
  String? extractFirstUrl(String? text) {
    if (text == null || text.isEmpty) return null;
    final RegExp urlRegex = RegExp(
      r'(https?://[^\s]+|www\.[^\s]+)',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    return match?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    final isSentByMe = chat.senderId.toString() == currentUserId;
    final hasParentMessage = chat.parentMessage != null;

    debugPrint(chat.messageContent);
    late Future<Metadata> metadataFuture;
    final extractedUrl =
        extractFirstUrl(chat.messageContent) ?? chat.messageContent!;
    metadataFuture = MetadataService.fetchMetadata(extractedUrl);
    // metadataFuture = MetadataService.fetchMetadata(chat.messageContent!);
    return Column(
      crossAxisAlignment:
          openedFromStarred
              ? CrossAxisAlignment.start
              : isSentByMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: SizeConfig.screenWidth * 0.80),
          decoration: BoxDecoration(
            color:
                isSentByMe
                    ? (Fp.dark ? Fp.violet.withValues(alpha: 0.32) : const Color(0xFFEDE6FF))
                    : Fp.inkRaised,
            borderRadius:
                openedFromStarred
                    ? BorderRadius.circular(hasParentMessage ? 9 : 12)
                    : AppDirectionality.appDirectionBorderRadius
                        .chatBubbleRadius(
                          isSentByMe: isSentByMe,
                          hasParentMessage: hasParentMessage,
                        ),
            // isSentByMe
            //     ? openedFromStarred
            //         ? BorderRadius.circular(hasParentMessage ? 9 : 12)
            //         : BorderRadius.only(
            //           topLeft: Radius.circular(hasParentMessage ? 9 : 12),
            //           bottomLeft: Radius.circular(
            //             hasParentMessage ? 9 : 12,
            //           ),
            //           topRight: Radius.circular(
            //             hasParentMessage ? 9 : 12,
            //           ),
            //         )
            //     : BorderRadius.only(
            //       topRight: Radius.circular(hasParentMessage ? 9 : 12),
            //       bottomRight: Radius.circular(hasParentMessage ? 9 : 12),
            //       topLeft: Radius.circular(hasParentMessage ? 9 : 12),
            //     ),
          ),
          child: Padding(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: hasParentMessage ? 3 : 3,
              vertical: hasParentMessage ? 3 : 3,
            ),
            child: Column(
              crossAxisAlignment:
                  isSentByMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ ENHANCED: Show parent message if this is a reply
                if (hasParentMessage) ...[
                  isForPinned
                      ? SizedBox.shrink()
                      : _buildParentMessagePreview(
                        context,
                        isSentByMe,
                        SizeConfig.screenWidth * 0.80,
                      ),
                  isForPinned ? SizedBox.shrink() : SizedBox(height: 3),
                ],

                // Main message content
                FutureBuilder<Metadata>(
                  future: metadataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return loadinglinkDesign(
                        context,
                        mesgLoad: 0,
                        isSentByMe: isSentByMe,
                      );
                    }

                    if (!snapshot.hasData || snapshot.hasError) {
                      return loadinglinkDesign(
                        context,
                        mesgLoad: 1,
                        isSentByMe: isSentByMe,
                      );
                    }
                    if (!snapshot.hasData) {
                      return loadinglinkDesign(
                        context,
                        mesgLoad: 1,
                        isSentByMe: isSentByMe,
                      );
                    }

                    final metadata = snapshot.data!;
                    return metadata.title.isEmpty
                        ? loadinglinkDesign(
                          context,
                          mesgLoad: 1,
                          isSentByMe: isSentByMe,
                        )
                        : GestureDetector(
                          onTap: () => launchURL(chat.messageContent!),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: SizeConfig.screenWidth * 0.80,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeManage.appTheme.darkGreyColor,
                              borderRadius: BorderRadius.circular(
                                hasParentMessage ? 9 : 10,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(5.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            AppThemeManage.appTheme.borderColor,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          offset: Offset(0, 0),
                                          blurRadius: 10,
                                          spreadRadius: 0,
                                          color: AppColors.shadowColor.c000000
                                              .withValues(alpha: 0.07),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        metadata.image,
                                        height:
                                            MediaQuery.of(context).size.height *
                                            0.08,
                                        width: SizeConfig.sizedBoxHeight(57),
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return SizedBox(
                                            height: SizeConfig.sizedBoxHeight(
                                              63,
                                            ),
                                            width: SizeConfig.sizedBoxHeight(
                                              57,
                                            ),
                                            child: Icon(
                                              Icons.link,
                                              color:
                                                  isSentByMe
                                                      ? AppColors
                                                          .appPriSecColor
                                                          .primaryColor
                                                      : AppThemeManage
                                                          .appTheme
                                                          .textColor,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: SizeConfig.width(3)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (metadata.title.isNotEmpty)
                                          Text(
                                            metadata.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.innerText14(
                                              context,
                                            ),
                                          ),
                                        if (metadata.description.isNotEmpty)
                                          Text(
                                            metadata.description,
                                            maxLines:
                                                metadata.publisher.isNotEmpty
                                                    ? 2
                                                    : 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.innerText10(
                                              context,
                                            ).copyWith(
                                              color:
                                                  AppColors
                                                      .textColor
                                                      .textDarkGray,
                                            ),
                                          ),
                                        if (metadata.publisher.isNotEmpty)
                                          Text(
                                            metadata.publisher,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.innerText10(
                                              context,
                                            ).copyWith(
                                              color:
                                                  AppColors
                                                      .textColor
                                                      .textDarkGray,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                  },
                ),
                Padding(
                  padding: SizeConfig.getPaddingSymmetric(
                    horizontal: 7,
                    vertical: 7,
                  ),
                  child: _buildMessageText(context, isSentByMe),
                  // Text(
                  //   chat.messageContent!,
                  //   maxLines: 1,
                  //   style: AppTypography.innerText10(
                  //     context,
                  //   ).copyWith(color: Color(0xff027EB5)),
                  // ),
                ),
                SizedBox.shrink(),
              ],
            ),
          ),
        ),
        // ✅ NEW: Add metadata row with star
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
    );
  }

  // ✅ ENHANCED: Build parent message preview with media support and tap functionality
  Widget _buildParentMessagePreview(
    BuildContext context,
    bool isSentByMe,
    double width,
  ) {
    final parentMessage = chat.parentMessage!;
    final parentContent = parentMessage['message_content'] ?? 'Message';
    final parentType = parentMessage['message_type'] ?? 'text';
    final parentThumbnail = parentMessage['message_thumbnail'];
    final parentMessageId = parentMessage['message_id'];

    return GestureDetector(
      onTap: () {
        // ✅ NEW: Handle tap to navigate to original message
        if (onReplyTap != null && parentMessageId != null) {
          onReplyTap!(parentMessageId as int);
        }
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Container(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: AppThemeManage.appTheme.bg488DarkGrey,
            borderRadius: BorderRadius.circular(9),
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
              SizedBox(height: 1),

              // ✅ Media preview or text content
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
      ),
    );
  }

  // ✅ Build parent message content based on type
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
      case 'gif':
        return ChatRelatedWidget.buildGifPreview(
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

  Widget loadinglinkDesign(
    BuildContext context, {
    required int mesgLoad,
    required bool isSentByMe,
  }) {
    return Container(
      constraints: BoxConstraints(maxWidth: SizeConfig.screenWidth * 0.80),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            mesgLoad == 0
                ? Shimmer.fromColors(
                  baseColor: AppThemeManage.appTheme.shimmerBaseColor,
                  highlightColor: AppThemeManage.appTheme.shimmerHighColor,
                  child: Container(
                    height: SizeConfig.sizedBoxHeight(63),
                    width: SizeConfig.sizedBoxHeight(57),
                    decoration: BoxDecoration(
                      color: AppThemeManage.appTheme.borderColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )
                : Container(
                  height: SizeConfig.sizedBoxHeight(63),
                  width: SizeConfig.sizedBoxHeight(57),
                  decoration: BoxDecoration(
                    color: AppThemeManage.appTheme.borderColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.link,
                    color:
                        isSentByMe
                            ? AppColors.appPriSecColor.primaryColor
                            : AppThemeManage.appTheme.textColor,
                  ),
                ),
            SizedBox(width: SizeConfig.width(3)),
            Expanded(
              child:
                  mesgLoad == 0
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Shimmer.fromColors(
                            baseColor: AppThemeManage.appTheme.shimmerBaseColor,
                            highlightColor:
                                AppThemeManage.appTheme.shimmerHighColor,
                            child: Container(
                              height: SizeConfig.sizedBoxHeight(12),
                              width: SizeConfig.sizedBoxHeight(200),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          SizedBox(height: SizeConfig.height(1)),
                          Shimmer.fromColors(
                            baseColor: AppThemeManage.appTheme.shimmerBaseColor,
                            highlightColor:
                                AppThemeManage.appTheme.shimmerHighColor,
                            child: Container(
                              height: SizeConfig.sizedBoxHeight(12),
                              width: SizeConfig.sizedBoxHeight(160),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          SizedBox(height: SizeConfig.height(1)),
                          Shimmer.fromColors(
                            baseColor: AppThemeManage.appTheme.shimmerBaseColor,
                            highlightColor:
                                AppThemeManage.appTheme.shimmerHighColor,
                            child: Container(
                              height: SizeConfig.sizedBoxHeight(6),
                              width: SizeConfig.sizedBoxHeight(150),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          SizedBox(height: SizeConfig.height(1)),
                          Shimmer.fromColors(
                            baseColor: AppThemeManage.appTheme.shimmerBaseColor,
                            highlightColor:
                                AppThemeManage.appTheme.shimmerHighColor,
                            child: Container(
                              height: SizeConfig.sizedBoxHeight(6),
                              width: SizeConfig.sizedBoxHeight(130),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ],
                      )
                      : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: SizeConfig.height(2.5)),
                          Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AppColors.appPriSecColor.secondaryRed,
                                size: 18,
                              ),
                              SizedBox(width: SizeConfig.width(3)),
                              Text(
                                "No metadata found",
                                style: AppTypography.innerText12Mediu(
                                  context,
                                ).copyWith(
                                  color: AppColors.appPriSecColor.secondaryRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageText(BuildContext context, bool isSentByMe) {
    final fullText = chat.messageContent ?? '';

    final normalStyle = AppTypography.innerText12Ragu(context).copyWith(
      color:
          isSentByMe
              ? ThemeColorPalette.getTextColor(
                AppColors.appPriSecColor.primaryColor,
              )
              : AppThemeManage.appTheme.textColor,
    );
    final linkStyle = AppTypography.innerText12Ragu(context).copyWith(
      color: const Color(0xff027EB5),
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xff027EB5),
    );

    final spans = _parseAllFormats(fullText, normalStyle, linkStyle);
    return RichText(text: TextSpan(children: spans));
  }

  // ✅ Step 1 — Split by URL first, then apply formatting to non-URL parts
  List<TextSpan> _parseAllFormats(
    String text,
    TextStyle normalStyle,
    TextStyle linkStyle,
  ) {
    final urlRegex = RegExp(
      r'(https?://[^\s]+|www\.[^\s]+)',
      caseSensitive: false,
    );
    final matches = urlRegex.allMatches(text).toList();
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Plain/formatted text before this URL
      if (match.start > lastEnd) {
        spans.addAll(
          _parseFormatting(text.substring(lastEnd, match.start), normalStyle),
        );
      }
      // URL — tappable blue, no formatting applied
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: linkStyle,
          recognizer: TapGestureRecognizer()..onTap = () => launchURL(url),
        ),
      );
      lastEnd = match.end;
    }

    // Remaining text after last URL
    if (lastEnd < text.length) {
      spans.addAll(_parseFormatting(text.substring(lastEnd), normalStyle));
    }

    // No URLs at all — just parse formatting
    if (matches.isEmpty) {
      return _parseFormatting(text, normalStyle);
    }

    return spans;
  }

  // ✅ Step 2 — Apply bold / italic / underline / strikethrough recursively
  List<TextSpan> _parseFormatting(String text, TextStyle style) {
    // Order matters — check bold first, then others
    final patterns = [
      _FormatRule(
        regex: RegExp(r'\*(.*?)\*'),
        apply: (s) => s.copyWith(fontWeight: FontWeight.bold),
      ),
      _FormatRule(
        regex: RegExp(r'_(.*?)_'),
        apply: (s) => s.copyWith(fontStyle: FontStyle.italic),
      ),
      _FormatRule(
        regex: RegExp(r'~(.*?)~'),
        apply:
            (s) => s.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: s.color,
            ),
      ),
      _FormatRule(
        regex: RegExp(r'--(.*?)--'),
        apply:
            (s) => s.copyWith(
              decoration: TextDecoration.lineThrough,
              decorationColor: s.color,
            ),
      ),
    ];

    // Start with a single plain span
    List<TextSpan> result = [TextSpan(text: text, style: style)];

    for (final rule in patterns) {
      final newResult = <TextSpan>[];
      for (final span in result) {
        // Only split plain text spans (skip already-tappable URL spans)
        if (span.recognizer != null) {
          newResult.add(span);
          continue;
        }
        final spanText = span.text ?? '';
        final spanStyle = span.style ?? style;
        final subMatches = rule.regex.allMatches(spanText).toList();

        if (subMatches.isEmpty) {
          newResult.add(span);
          continue;
        }

        int lastEnd = 0;
        for (final match in subMatches) {
          // Text before the marker
          if (match.start > lastEnd) {
            newResult.add(
              TextSpan(
                text: spanText.substring(lastEnd, match.start),
                style: spanStyle,
              ),
            );
          }
          // Formatted text inside the markers (recursive for nested)
          final innerText = match.group(1) ?? '';
          final innerStyle = rule.apply(spanStyle);
          final innerSpans = _parseFormatting(innerText, innerStyle);
          newResult.addAll(innerSpans);

          lastEnd = match.end;
        }
        // Remaining text after last match
        if (lastEnd < spanText.length) {
          newResult.add(
            TextSpan(text: spanText.substring(lastEnd), style: spanStyle),
          );
        }
      }
      result = newResult;
    }

    return result;
  }
}

class _FormatRule {
  final RegExp regex;
  final TextStyle Function(TextStyle) apply;
  const _FormatRule({required this.regex, required this.apply});
}
