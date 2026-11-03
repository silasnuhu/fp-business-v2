// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/featuers/chat/data/models/chat_media_model.dart';
import 'package:whoxa/featuers/chat/data/models/link_model.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/repository/chat_repository.dart';
import 'package:whoxa/featuers/chat/screens/pdf_viewer_screen.dart';
import 'package:whoxa/featuers/chat/widgets/chat_files_views_handle/image_view.dart';
import 'package:whoxa/featuers/chat/widgets/chat_files_views_handle/video_view.dart';
import 'package:whoxa/featuers/chat/widgets/video_thumbnail_view.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/file_name_utils.dart';
import 'package:whoxa/utils/metadata_service.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/shimmer.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';

class ChatMediaScreen extends StatefulWidget {
  final int chatId;
  final String chatName;

  const ChatMediaScreen({
    super.key,
    required this.chatId,
    required this.chatName,
  });

  @override
  State<ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends State<ChatMediaScreen>
    with TickerProviderStateMixin {
  final ChatRepository _chatRepository = GetIt.instance<ChatRepository>();

  // ChatMediaResponse? _mediaResponse;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  // Tab controller for different media types
  late TabController _tabController;

  // Filtered lists for different media types
  List<Records> _allMedia = [];
  List<Records> _documents = [];
  List<Records> _links = [];
  late Future<Metadata> metadataFuture;

  // Map<String, List<Records>> groupByMonth(List<Records> mediaList) {
  //   final now = DateTime.now();
  //   final monthFormat = DateFormat('MMMM'); // May, June, etc.
  //   final yearFormat = DateFormat('yyyy');

  //   Map<String, List<Records>> grouped = {};

  //   for (var item in mediaList) {
  //     final createdAt = DateTime.parse(item.createdAt);
  //     String key;

  //     if (createdAt.year == now.year && createdAt.month == now.month) {
  //       key = 'This Month';
  //     } else if (createdAt.year == now.year) {
  //       key = monthFormat.format(createdAt);
  //     } else {
  //       key =
  //           '${monthFormat.format(createdAt)} ${yearFormat.format(createdAt)}';
  //     }

  //     grouped.putIfAbsent(key, () => []);
  //     grouped[key]!.add(item);
  //   }

  //   return grouped;
  // }

  Map<String, List<Records>> groupByDate(List<Records> mediaList) {
    final now = DateTime.now();
    final monthFormat = DateFormat('MMMM'); // May, June
    final yearFormat = DateFormat('yyyy');

    Map<String, List<Records>> grouped = {};

    for (var item in mediaList) {
      final createdAt = DateTime.parse(item.createdAt);
      String key;

      final difference =
          now
              .difference(
                DateTime(createdAt.year, createdAt.month, createdAt.day),
              )
              .inDays;

      if (difference == 0) {
        key = "Today";
      } else if (difference == 1) {
        key = "Yesterday";
      } else if (createdAt.year == now.year && createdAt.month == now.month) {
        key = "This Month";
      } else if (createdAt.year == now.year) {
        key = monthFormat.format(createdAt);
      } else {
        key =
            '${monthFormat.format(createdAt)} ${yearFormat.format(createdAt)}';
      }

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    return grouped;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadChatMedia(type: 'media');
    // Listen to index changes (tap or swipe)
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return; // Avoid double triggers

      switch (_tabController.index) {
        case 0:
          _loadChatMedia(type: 'media');
          break;
        case 1:
          _loadChatMedia(type: 'doc');
          break;
        case 2:
          _loadChatMedia(type: 'link');
          break;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String mediaType = '';

  Future<void> _loadChatMedia({required String type}) async {
    // ✅ Only show loader if no cached data exists for that tab
    bool shouldShowLoader = false;

    switch (type) {
      case 'media':
        chatMediaText = AppString.media;
        shouldShowLoader = _allMedia.isEmpty;
        break;
      case 'doc':
        chatMediaText = AppString.documents;
        shouldShowLoader = _documents.isEmpty;
        break;
      case 'link':
        chatMediaText = AppString.links;
        shouldShowLoader = _links.isEmpty;
        break;
    }

    if (shouldShowLoader) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    }

    try {
      final response = await _chatRepository.getChatMedia(
        chatId: widget.chatId,
        type: type.isNotEmpty ? type : 'media',
      );

      if (response != null && response.status) {
        setState(() {
          switch (type) {
            case 'media':
              _allMedia = response.data!.records;
              break;
            case 'doc':
              _documents = response.data!.records;
              break;
            case 'link':
              _links = response.data!.records;
              break;
          }
          _isLoading = false;
          _hasError = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = response?.message ?? 'Failed to load media';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error loading media: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100),
        child: AppBar(
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          shape: Border(
            bottom: BorderSide(color: AppThemeManage.appTheme.borderColor),
          ),
          systemOverlayStyle: systemUI(),
          backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
          flexibleSpace: flexibleSpace(),
          leading: Padding(
            padding: EdgeInsets.all(SizeConfig.screenWidth * 0.03),
            child: customeBackArrowBalck(context),
          ),
          titleSpacing: 1,
          title: Text(
            chatMediaText.isEmpty ? AppString.media : chatMediaText,
            style: AppTypography.h220(context),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(40),
            child: Container(
              color: AppThemeManage.appTheme.darkGreyColor,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.appPriSecColor.primaryColor,
                unselectedLabelColor: AppColors.textColor.textGreyColor,
                indicatorColor: AppColors.appPriSecColor.primaryColor,
                labelStyle: AppTypography.innerText12Mediu(
                  context,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                onTap: (value) {
                  if (value == 0) {
                    setState(() {
                      _loadChatMedia(type: 'media');
                    });
                  }
                  if (value == 1) {
                    setState(() {
                      _loadChatMedia(type: 'doc');
                    });
                  }
                  if (value == 2) {
                    setState(() {
                      _loadChatMedia(type: 'link');
                    });
                  }
                },
                tabs: [
                  Tab(
                    text:
                        "${AppString.media} (${_allMedia.isEmpty ? 0 : _allMedia.length})",
                  ),
                  Tab(
                    text:
                        "${AppString.geoupProfileString.docs} (${_documents.isEmpty ? 0 : _documents.length})",
                  ),
                  Tab(
                    text:
                        "${AppString.links} (${_links.isEmpty ? 0 : _links.length})",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body:
          _isLoading
              ? _buildLoadingView()
              : _hasError
              ? _buildErrorView()
              : _buildMediaContent(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          commonLoading(),
          SizedBox(height: 16),
          Text(
            '${AppString.loadingmedia}...',
            style: AppTypography.mediumText(context),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: AppColors.textColor.textGreyColor),
          SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Failed to load media',
            style: AppTypography.mediumText(context),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _loadChatMedia(type: 'media');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.appPriSecColor.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(AppString.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_hasError) {
      return _buildErrorView();
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _buildMediaGrid(_allMedia, 'media'),
        _buildMediaGrid(_documents, 'doc'),
        _buildMediaGrid(_links, 'link'),
      ],
    );
  }

  Widget _buildMediaGrid(List<Records> mediaList, String type) {
    debugPrint("mediaList:${mediaList.length}");
    if (mediaList.isEmpty) {
      // Show empty state based on type
      switch (type) {
        case 'media':
          return _buildEmptyState(
            icon: AppAssets.emptyDataIcons.mediaGallery,
            title: AppString.emptyDataString.noPhotosFound,
            subtitle: AppString.emptyDataString.youdonthaveanyImage,
          );
        case 'doc':
          return _buildEmptyState(
            icon: AppAssets.emptyDataIcons.mediaDocument,
            title: AppString.emptyDataString.noDocumentFound,
            subtitle: AppString.emptyDataString.youdonthaveanyDocuments,
          );
        case 'link':
          return _buildEmptyState(
            icon: AppAssets.emptyDataIcons.mediaLink,
            title: AppString.emptyDataString.noLinkFound,
            subtitle: AppString.emptyDataString.youdonthaveanyLinks,
          );
        default:
          return Text("data");
      }
    } else {
      final grouped = groupByDate(mediaList);
      final keys =
          grouped.keys
              .toList(); // Preserves insertion order (assuming mediaList is sorted descending by createdAt)

      return ListView.builder(
        itemCount: keys.length,
        itemBuilder: (context, index) {
          final key = keys[index];
          final items = grouped[key]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(
                  bottom: SizeConfig.safeHeight(1.5),
                  top: SizeConfig.safeHeight(1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppColors.appPriSecColor.primaryColor.withValues(
                          alpha: 0.3,
                        ),
                        thickness: 1,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: SizeConfig.safeWidth(4),
                        vertical: SizeConfig.safeHeight(0.5),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.appPriSecColor.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        key,
                        style: AppTypography.innerText12Mediu(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: ThemeColorPalette.getTextColor(
                            AppColors.appPriSecColor.primaryColor,
                          ), //AppColors.textColor.textBlackColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppColors.appPriSecColor.primaryColor.withValues(
                          alpha: 0.3,
                        ),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (type == 'media')
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, subIndex) {
                    final record = items[subIndex];
                    return _buildMediaItem(record);
                  },
                )
              else if (type == 'doc' || type == 'link')
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, subIndex) {
                    final record = items[subIndex];
                    return Padding(
                      padding: SizeConfig.getPaddingOnly(bottom: 5),
                      child:
                          type == 'doc'
                              ? _buildDocItem(record)
                              : _buildLinkItem(record),
                    );
                  },
                ),
            ],
          );
        },
      );
    }
  }

  // Reusable empty state widget
  Widget _buildEmptyState({
    required String icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            icon,
            height: SizeConfig.sizedBoxHeight(84),
            colorFilter: ColorFilter.mode(
              AppColors.appPriSecColor.secondaryColor,
              BlendMode.srcIn,
            ),
          ),
          SizedBox(height: 16),
          Text(title, style: AppTypography.h3(context)),
          SizedBox(height: 5),
          Text(
            subtitle,
            style: AppTypography.innerText12Mediu(
              context,
            ).copyWith(color: AppColors.textColor.textGreyColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(Records media) {
    return GestureDetector(
      onTap: () => _openMedia(media),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(0),
          color: AppThemeManage.appTheme.darkGreyColor,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.c000000.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildMediaPreview(media),
              _buildMediaTypeIcon(media),
              if (media.pinned) _buildPinnedIndicator(),
              if (media.starredFor.isNotEmpty) _buildStarredIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(Records media) {
    debugPrint("media.isImage:${media.isImage}");
    if (media.isImage) {
      return Image.network(
        media.messageContent,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder();
        },
      );
    } else if (media.isGif) {
      return Image.network(
        media.messageContent,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder();
        },
      );
    } else if (media.isVideo) {
      // Backend never populates a video thumbnail (stubbed queue processor),
      // so fall back to an on-device generated poster frame.
      return VideoThumbnailView(
        videoUrl: media.messageContent,
        backendThumbnailUrl:
            media.hasValidThumbnail ? media.messageThumbnail : null,
        fit: BoxFit.cover,
        placeholderBuilder:
            (context, loading) =>
                loading ? _buildLoadingPlaceholder() : _buildVideoPlaceholder(),
      );
    } else if (media.isDocument) {
      return _buildDocumentPlaceholder();
    } else if (media.isAudio) {
      return _buildAudioPlaceholder();
    }

    return _buildErrorPlaceholder();
  }

  Widget _buildMediaTypeIcon(Records media) {
    IconData icon;
    Color color;

    if (media.isVideo) {
      icon = Icons.play_circle_filled;
      color = Colors.white;
    } else if (media.isDocument) {
      icon = Icons.insert_drive_file;
      color = AppColors.appPriSecColor.primaryColor;
    } else if (media.isAudio) {
      icon = Icons.audiotrack;
      color = AppColors.appPriSecColor.primaryColor;
    } else {
      return SizedBox.shrink();
    }

    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildPinnedIndicator() {
    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.push_pin, color: Colors.white, size: 12),
      ),
    );
  }

  Widget _buildStarredIndicator() {
    return Positioned(
      top: 4,
      right: 4,
      child: Container(
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.star, color: Colors.white, size: 12),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: AppColors.bgColor.bg1Color,
      child: Center(child: commonLoading()),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: AppThemeManage.appTheme.darkGreyColor,
      child: Icon(Icons.error, color: AppColors.textColor.textGreyColor),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      color: AppThemeManage.appTheme.darkGreyColor,
      child: Icon(
        Icons.videocam,
        color: AppColors.textColor.textGreyColor,
        size: 32,
      ),
    );
  }

  Widget _buildDocumentPlaceholder() {
    return Container(
      color: AppColors.bgColor.bg1Color,
      child: Icon(
        Icons.insert_drive_file,
        color: AppColors.appPriSecColor.primaryColor,
        size: 32,
      ),
    );
  }

  Widget _buildAudioPlaceholder() {
    return Container(
      color: AppColors.bgColor.bg1Color,
      child: Icon(
        Icons.audiotrack,
        color: AppColors.appPriSecColor.primaryColor,
        size: 32,
      ),
    );
  }

  void _openMedia(Records media) {
    if (media.isImage) {
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder:
      //         (context) => ImageViewScreen(
      //           imageUrl: media.messageContent,
      //           heroTag: 'media_${media.messageId}',
      //         ),
      //   ),
      // );
      context.viewImage(
        imageSource: media.messageContent,
        imageTitle: media.messageContent,
        heroTag: 'media_${media.messageId}',
      );
    } else if (media.isVideo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => VideoViewerScreen(videoUrl: media.messageContent),
        ),
      );
    } else {
      // For documents and audio, you might want to implement downloading or opening
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opening ${media.messageType} files is not yet implemented',
          ),
          backgroundColor: AppColors.appPriSecColor.primaryColor,
        ),
      );
    }
  }

  Widget _buildDocItem(Records media) {
    final downloadProgress = ValueNotifier<double>(0.0);
    final isSentByMe = media.senderId.toString() == userID;
    return Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 10),
      child: FutureBuilder<bool>(
        future: Provider.of<ChatProvider>(
          context,
          listen: false,
        ).isPdfDownloaded(media.messageContent),
        builder: (context, downloadSnapshot) {
          return ValueListenableBuilder<double>(
            valueListenable: downloadProgress,
            builder: (context, progress, child) {
              final isDownloaded = downloadSnapshot.data ?? false;
              final isDownloading = progress > 0 && progress < 1;
              final fileName = prettyFileNameFromUrl(
                media.messageContent,
                fallback: 'Document',
              );

              return GestureDetector(
                onTap:
                    isDownloading
                        ? null
                        : () => _handleDocumentAction(
                          context,
                          downloadProgress,
                          fileName,
                          media,
                        ),
                child: Column(
                  crossAxisAlignment:
                      isSentByMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: SizeConfig.screenWidth * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSentByMe
                                ? AppColors.appPriSecColor.secondaryColor
                                : AppThemeManage.appTheme.chatOppoColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(9),
                          topRight: Radius.circular(9),
                          bottomRight: Radius.circular(isSentByMe ? 0 : 9),
                          bottomLeft: Radius.circular(isSentByMe ? 9 : 0),
                        ),
                      ),
                      padding: SizeConfig.getPaddingSymmetric(
                        horizontal: 3,
                        vertical: 3,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            isSentByMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: SizeConfig.getPaddingSymmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeManage.appTheme.darkGreyColor,
                              borderRadius: BorderRadius.circular(9),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        fileName,
                                        style: AppTypography.mediumText(
                                          context,
                                        ).copyWith(
                                          fontSize: SizeConfig.getFontSize(12),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2),
                                      FutureBuilder<String>(
                                        future: _getFileMetadata(
                                          fileName,
                                          media,
                                        ),
                                        builder: (context, metadataSnapshot) {
                                          return Text(
                                            _metadataOrFallback(
                                              metadataSnapshot.data,
                                              fileName,
                                            ),
                                            style: AppTypography.captionText(
                                              context,
                                            ).copyWith(
                                              fontSize: SizeConfig.getFontSize(
                                                9,
                                              ),
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
                                          color:
                                              AppColors.textColor.textDarkGray,
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
                                                        >(
                                                          AppColors
                                                              .textColor
                                                              .textGreyColor,
                                                        ),
                                                  ),
                                                  SvgPicture.asset(
                                                    AppAssets
                                                        .chatImage
                                                        .downloadArrow,
                                                    height: 10,
                                                    colorFilter:
                                                        ColorFilter.mode(
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
                    SizedBox(height: SizeConfig.height(1)),
                    buildMetadataRow(
                      context: context,
                      media: media,
                      isStarred: false,
                      isSentByMe: isSentByMe,
                    ),
                    SizedBox(height: SizeConfig.height(2)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLinkItem(Records media) {
    final isSentByMe = media.senderId.toString() == userID;

    // ✅ Extract ALL urls from message content
    final urlRegex = RegExp(
      r'(https?://[^\s]+|www\.[^\s]+)',
      caseSensitive: false,
    );
    final allUrls =
        urlRegex
            .allMatches(media.messageContent)
            .map((m) => m.group(0)!)
            .toList();

    if (allUrls.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment:
            isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // ✅ Bubble wrapper
          Container(
            constraints: BoxConstraints(
              maxWidth: SizeConfig.screenWidth * 0.80,
            ),
            decoration: BoxDecoration(
              color:
                  isSentByMe
                      ? AppColors.appPriSecColor.secondaryColor
                      : AppColors.bgColor.bg2Color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
                bottomRight: Radius.circular(isSentByMe ? 0 : 9),
                bottomLeft: Radius.circular(isSentByMe ? 9 : 0),
              ),
            ),
            padding: SizeConfig.getPaddingSymmetric(horizontal: 3, vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ One preview card per URL
                ...allUrls.asMap().entries.map((entry) {
                  final index = entry.key;
                  final url = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (index > 0) SizedBox(height: SizeConfig.height(1)),
                      GestureDetector(
                        onTap: () => _openLink(url),
                        child: FutureBuilder<Metadata>(
                          future: MetadataService.fetchMetadata(url),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return loadinglinkDesign(
                                context,
                                mesgLoad: 0,
                                isSentByMe: isSentByMe,
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.hasError ||
                                snapshot.data!.title.isEmpty) {
                              return _buildFallbackUrlTile(
                                context,
                                url,
                                isSentByMe,
                              );
                            }
                            final metadata = snapshot.data!;
                            return _buildMetadataCard(
                              context,
                              metadata,
                              isSentByMe,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }),

                SizedBox(height: SizeConfig.height(1)),
              ],
            ),
          ),
          SizedBox(height: SizeConfig.height(2)),
        ],
      ),
    );
  }

  // ✅ Rich preview card when metadata is available
  Widget _buildMetadataCard(
    BuildContext context,
    Metadata metadata,
    bool isSentByMe,
  ) {
    return Container(
      constraints: BoxConstraints(maxWidth: SizeConfig.screenWidth * 0.80),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppThemeManage.appTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    offset: Offset(0, 0),
                    blurRadius: 10,
                    spreadRadius: 0,
                    color: AppColors.shadowColor.c000000.withValues(
                      alpha: 0.07,
                    ),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  metadata.image,
                  height: MediaQuery.of(context).size.height * 0.08,
                  width: SizeConfig.sizedBoxHeight(57),
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => SizedBox(
                        height: SizeConfig.sizedBoxHeight(63),
                        width: SizeConfig.sizedBoxHeight(57),
                        child: Icon(
                          Icons.link,
                          color:
                              isSentByMe
                                  ? AppColors.appPriSecColor.primaryColor
                                  : AppThemeManage.appTheme.textColor,
                        ),
                      ),
                ),
              ),
            ),
            SizedBox(width: SizeConfig.width(3)),
            // Title / description / publisher
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (metadata.title.isNotEmpty)
                    Text(
                      metadata.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.innerText14(context),
                    ),
                  if (metadata.description.isNotEmpty)
                    Text(
                      metadata.description,
                      maxLines: metadata.publisher.isNotEmpty ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.innerText10(
                        context,
                      ).copyWith(color: AppColors.textColor.textDarkGray),
                    ),
                  if (metadata.publisher.isNotEmpty)
                    Text(
                      metadata.publisher,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.innerText10(
                        context,
                      ).copyWith(color: AppColors.textColor.textDarkGray),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Fallback when metadata fetch fails — just show URL as blue text
  Widget _buildFallbackUrlTile(
    BuildContext context,
    String url,
    bool isSentByMe,
  ) {
    return Container(
      constraints: BoxConstraints(maxWidth: SizeConfig.screenWidth * 0.80),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: SizeConfig.getPaddingSymmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.link,
            size: 18,
            color:
                isSentByMe
                    ? AppColors.appPriSecColor.primaryColor
                    : AppThemeManage.appTheme.textColor,
          ),
          SizedBox(width: SizeConfig.width(2)),
          Expanded(
            child: Text(
              url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.innerText10(context).copyWith(
                color: const Color(0xff027EB5),
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xff027EB5),
              ),
            ),
          ),
        ],
      ),
    );
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

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppString.couldNotLaunch} $url'),
          backgroundColor: AppColors.appPriSecColor.primaryColor,
        ),
      );
    }
  }

  void _handleDocumentAction(
    BuildContext context,
    ValueNotifier<double> downloadProgress,
    String fileName,
    Records media,
  ) {
    final extension = fileName.toLowerCase().split('.').last;

    if (extension == 'pdf') {
      _handleDocumentDownload(context, downloadProgress, media);
    } else {
      _openFileDirectly(context, media);
    }
  }

  void _openFileDirectly(BuildContext context, Records media) async {
    try {
      final uri = Uri.parse(media.messageContent);
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

  void _openFile(BuildContext context, String filePath, Records media) {
    final extension = filePath.toLowerCase().split('.').last;

    if (extension == 'pdf') {
      _openPdfViewer(context, filePath, media);
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

  Future<String> _getFileMetadata(String fileName, Records media) async {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        // Reads a downloaded local copy when present, else the remote file
        // — a PDF opened once keeps showing its real page-count/size line
        // instead of "Unknown PDF".
        return await Provider.of<ChatProvider>(
          context,
          listen: false,
        ).getPdfMetadataForUrl(media.messageContent);
      default:
        return _getFileTypeDisplay(fileName);
    }
  }

  /// Keeps the "Unknown PDF" / "Error loading PDF" sentinels the metadata
  /// helpers return on failure out of the UI.
  String _metadataOrFallback(String? data, String fileName) {
    if (data == null ||
        data.isEmpty ||
        data == 'Unknown PDF' ||
        data == 'Error loading PDF') {
      return _getFileTypeDisplay(fileName);
    }
    return data;
  }

  void _handleDocumentDownload(
    BuildContext context,
    ValueNotifier<double> downloadProgress,
    Records media,
  ) {
    Provider.of<ChatProvider>(context, listen: false).downloadPdfWithProgress(
      pdfUrl: media.messageContent,
      onProgress: (progress) {
        downloadProgress.value = progress;
      },
      onComplete: (filePath, metadata) {
        if (filePath != null) {
          _showOpenDialog(context, filePath, media);
        }
      },
    );
  }

  void _showOpenDialog(BuildContext context, String filePath, Records media) {
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
                    "Open ${_getFileTypeDisplay(media.messageContent.split('/').last)}",
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openFile(context, filePath, media);
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

  void _openPdfViewer(BuildContext context, String filePath, Records media) {
    final fileName = prettyFileNameFromUrl(
      media.messageContent,
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

  Widget buildMetadataRow({
    required BuildContext context,
    required Records media,
    required bool isStarred,
    required bool isSentByMe,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Pinned indicator (only show if pinned and not starred)
        if (media.pinned == true) ...[
          SvgPicture.asset(
            AppAssets.pinMessageIcon,
            height: 13,
            colorFilter: ColorFilter.mode(
              isSentByMe
                  ? AppColors.appPriSecColor.primaryColor
                  : AppColors.textColor.textGreyColor,
              BlendMode.srcIn,
            ),
          ),
          SizedBox(width: SizeConfig.width(1)),
        ],

        // Star indicator (only show if starred)
        if (isStarred) ...[
          Padding(
            padding: SizeConfig.getPaddingOnly(bottom: 2),
            child: Icon(
              Icons.star,
              size: 12,
              color: AppColors.appPriSecColor.primaryColor,
            ),
          ),
          SizedBox(width: SizeConfig.width(1)),
        ],

        if (isSentByMe) ...[
          buildMessageStatus(
            context: context,
            chat: media,
            isStarred: isStarred,
            isSentByMe: isSentByMe,
          ),
          SizedBox(width: SizeConfig.width(1)),
        ],

        // Timestamp
        Text(
          _formatTime(media.createdAt),
          style: AppTypography.captionText(context).copyWith(
            color:
                isSentByMe
                    ? AppColors.textColor.textDarkGray
                    : AppColors.textColor.textGreyColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ✅ Message status indicators
  static Widget buildMessageStatus({
    required BuildContext context,
    required Records chat,
    required bool isStarred,
    required bool isSentByMe,
  }) {
    IconData statusIcon = Icons.schedule;
    Color iconColor = AppColors.textColor.textDarkGray;

    switch (chat.messageSeenStatus.toLowerCase()) {
      case 'seen':
        statusIcon = Icons.done_all; // Double tick
        iconColor = Colors.blue; // Blue when read
        break;
      case 'sent':
        statusIcon = Icons.done_all; // Double tick
        iconColor = AppColors.textColor.textDarkGray; // Grey when sent
        break;
      case 'pending':
      default:
        statusIcon = Icons.schedule;
        iconColor = AppColors.textColor.textDarkGray;
        break;
    }

    return Icon(statusIcon, color: iconColor, size: 12);
  }

  // ✅ Helper: Format timestamp
  static String _formatTime(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final localDateTime = dateTime.toLocal(); // Convert to local time
      return DateFormat.jm().format(localDateTime); // e.g., 12:30 PM
    } catch (e) {
      return '';
    }
  }
}
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:get_it/get_it.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:whoxa/featuers/chat/data/models/chat_media_model.dart';
// import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
// import 'package:whoxa/featuers/chat/repository/chat_repository.dart';
// import 'package:whoxa/featuers/chat/screens/pdf_viewer_screen.dart';
// import 'package:whoxa/featuers/chat/widgets/chat_files_views_handle/image_view.dart';
// import 'package:whoxa/featuers/chat/widgets/chat_files_views_handle/video_view.dart';
// import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
// import 'package:whoxa/utils/app_size_config.dart';
// import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
// import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
// import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
// import 'package:whoxa/utils/preference_key/constant/strings.dart';
// import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
// import 'package:whoxa/widgets/global.dart';

// class ChatMediaScreen extends StatefulWidget {
//   final int chatId;
//   final String chatName;

//   const ChatMediaScreen({
//     super.key,
//     required this.chatId,
//     required this.chatName,
//   });

//   @override
//   State<ChatMediaScreen> createState() => _ChatMediaScreenState();
// }

// class _ChatMediaScreenState extends State<ChatMediaScreen>
//     with TickerProviderStateMixin {
//   final ChatRepository _chatRepository = GetIt.instance<ChatRepository>();

//   ChatMediaResponse? _mediaResponse;
//   bool _isLoading = true;
//   bool _hasError = false;
//   String? _errorMessage;

//   // Tab controller for different media types
//   late TabController _tabController;

//   // Filtered lists for different media types
//   List<Records> _allMedia = [];
//   List<Records> _documents = [];
//   List<Records> _links = [];

//   Map<String, List<Records>> groupByMonth(List<Records> mediaList) {
//     final now = DateTime.now();
//     final monthFormat = DateFormat('MMMM'); // May, June, etc.
//     final yearFormat = DateFormat('yyyy');

//     Map<String, List<Records>> grouped = {};

//     for (var item in mediaList) {
//       final createdAt = DateTime.parse(item.createdAt);
//       String key;

//       if (createdAt.year == now.year && createdAt.month == now.month) {
//         key = 'This Month';
//       } else {
//         key =
//             '${monthFormat.format(createdAt)} ${yearFormat.format(createdAt)}';
//       }

//       grouped.putIfAbsent(key, () => []);
//       grouped[key]!.add(item);
//     }

//     return grouped;
//   }

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//     _loadChatMedia(type: 'media');
//     // Listen to index changes (tap or swipe)
//     _tabController.addListener(() {
//       if (_tabController.indexIsChanging) return; // Avoid double triggers

//       switch (_tabController.index) {
//         case 0:
//           _loadChatMedia(type: 'media');
//           break;
//         case 1:
//           _loadChatMedia(type: 'doc');
//           break;
//         case 2:
//           _loadChatMedia(type: 'link');
//           break;
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   String mediaType = '';

//   // Future<void> _loadChatMedia({required String type}) async {
//   //   setState(() {
//   //     _isLoading = true;
//   //     _hasError = false;
//   //     _errorMessage = null;
//   //   });

//   //   try {
//   //     debugPrint("😊type😊:$type");
//   //     final response = await _chatRepository.getChatMedia(
//   //       chatId: widget.chatId,
//   //       type: type.isNotEmpty ? type : 'media',
//   //     );

//   //     if (response != null && response.status) {
//   //       setState(() {
//   //         _mediaResponse = response;
//   //         switch (type) {
//   //           case 'media':
//   //             _allMedia = response.data!.records;
//   //             break;
//   //           case 'doc':
//   //             _documents = response.data!.records;
//   //             break;
//   //           case 'link':
//   //             _links = response.data!.records;
//   //             break;
//   //         }
//   //         _isLoading = false;
//   //         _hasError = false;
//   //       });
//   //       // setState(() {
//   //       //   _mediaResponse = response;
//   //       //   _allMedia = response.data!.records;

//   //       //   // Filter media by type
//   //       //   _images = _allMedia.where((media) => media.isImage).toList();
//   //       //   _videos = _allMedia.where((media) => media.isVideo).toList();
//   //       //   _documents = _allMedia.where((media) => media.isDocument).toList();
//   //       //   _links = _allMedia.where((media) => media.isLinks).toList();

//   //       //   _isLoading = false;
//   //       //   _hasError = false;
//   //       // });
//   //     } else {
//   //       setState(() {
//   //         _hasError = true;
//   //         _errorMessage = response?.message ?? 'Failed to load media';
//   //         _isLoading = false;
//   //       });
//   //     }
//   //   } catch (e) {
//   //     setState(() {
//   //       _hasError = true;
//   //       _errorMessage = 'Error loading media: $e';
//   //       _isLoading = false;
//   //     });
//   //   }
//   // }

//   Future<void> _loadChatMedia({required String type}) async {
//     // ✅ Only show loader if no cached data exists for that tab
//     bool shouldShowLoader = false;

//     switch (type) {
//       case 'media':
//         shouldShowLoader = _allMedia.isEmpty;
//         break;
//       case 'doc':
//         shouldShowLoader = _documents.isEmpty;
//         break;
//       case 'link':
//         shouldShowLoader = _links.isEmpty;
//         break;
//     }

//     if (shouldShowLoader) {
//       setState(() {
//         _isLoading = true;
//         _hasError = false;
//         _errorMessage = null;
//       });
//     }

//     try {
//       final response = await _chatRepository.getChatMedia(
//         chatId: widget.chatId,
//         type: type.isNotEmpty ? type : 'media',
//       );

//       if (response != null && response.status) {
//         setState(() {
//           switch (type) {
//             case 'media':
//               _allMedia = response.data!.records;
//               break;
//             case 'doc':
//               _documents = response.data!.records;
//               break;
//             case 'link':
//               _links = response.data!.records;
//               break;
//           }
//           _isLoading = false;
//           _hasError = false;
//         });
//       } else {
//         setState(() {
//           _hasError = true;
//           _errorMessage = response?.message ?? 'Failed to load media';
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _hasError = true;
//         _errorMessage = 'Error loading media: $e';
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.bgColor.bg4Color,
//       appBar: PreferredSize(
//         preferredSize: Size.fromHeight(100),
//         child: AppBar(
//           scrolledUnderElevation: 0,
//           automaticallyImplyLeading: false,
//           shape: Border(
//             bottom: BorderSide(color: AppColors.shadowColor.cE9E9E9),
//           ),
//           backgroundColor: AppColors.bgColor.bg4Color,
//           systemOverlayStyle: systemUI(),
//           flexibleSpace: flexibleSpace(),
//           leading: Padding(
//             padding: SizeConfig.getPadding(16),
//             child: customeBackArrowBalck(context),
//           ),
//           titleSpacing: 1,
//           title: Text('Media', style: AppTypography.h3(context)),
//           bottom: TabBar(
//             controller: _tabController,
//             labelColor: AppColors.appPriSecColor.primaryColor,
//             unselectedLabelColor: AppColors.textColor.textGreyColor,
//             indicatorColor: AppColors.appPriSecColor.primaryColor,
//             labelStyle: AppTypography.innerText12Mediu(
//               context,
//             ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
//             onTap: (value) {
//               if (value == 0) {
//                 debugPrint("TABBAR_VALUE:$value");
//                 setState(() {
//                   _loadChatMedia(type: 'media');
//                 });
//               }
//               if (value == 1) {
//                 debugPrint("TABBAR_VALUE:$value");
//                 setState(() {
//                   _loadChatMedia(type: 'doc');
//                 });
//               }
//               if (value == 2) {
//                 debugPrint("TABBAR_VALUE:$value");
//                 setState(() {
//                   _loadChatMedia(type: 'link');
//                 });
//               }
//             },
//             tabs: [Tab(text: 'Media'), Tab(text: 'Docs'), Tab(text: 'Links')],
//           ),
//         ),
//       ),
//       body:
//           _isLoading
//               ? _buildLoadingView()
//               : _hasError
//               ? _buildErrorView()
//               : _buildMediaContent(),
//     );
//   }

//   Widget _buildLoadingView() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(
//               AppColors.appPriSecColor.primaryColor,
//             ),
//           ),
//           SizedBox(height: 16),
//           Text('Loading media...', style: AppTypography.mediumText(context)),
//         ],
//       ),
//     );
//   }

//   Widget _buildErrorView() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.error, size: 64, color: AppColors.textColor.textGreyColor),
//           SizedBox(height: 16),
//           Text(
//             _errorMessage ?? 'Failed to load media',
//             style: AppTypography.mediumText(context),
//             textAlign: TextAlign.center,
//           ),
//           SizedBox(height: 16),
//           ElevatedButton(
//             onPressed: () {
//               _loadChatMedia(type: 'media');
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.appPriSecColor.primaryColor,
//               foregroundColor: Colors.white,
//             ),
//             child: Text('Retry'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildMediaContent() {
//     if (_isLoading) {
//       return _buildLoadingView();
//     }

//     if (_hasError) {
//       return _buildErrorView();
//     }
//     return TabBarView(
//       controller: _tabController,
//       children: [
//         _buildMediaGrid(_allMedia, 'media'),
//         _buildMediaGrid(_documents, 'doc'),
//         _buildMediaGrid(_links, 'link'),
//       ],
//     );
//   }

//   Widget _buildMediaGrid(List<Records> mediaList, String type) {
//     debugPrint("mediaList:${mediaList.length}");
//     if (mediaList.isEmpty) {
//       // Show empty state based on type
//       switch (type) {
//         case 'media':
//           return _buildEmptyState(
//             icon: AppAssets.emptyDataIcons.mediaGallery,
//             title: AppString.emptyDataString.noPhotosFound,
//             subtitle: AppString.emptyDataString.youdonthaveanyImage,
//           );
//         case 'doc':
//           return _buildEmptyState(
//             icon: AppAssets.emptyDataIcons.mediaDocument,
//             title: AppString.emptyDataString.noDocumentFound,
//             subtitle: AppString.emptyDataString.youdonthaveanyDocuments,
//           );
//         case 'link':
//           return _buildEmptyState(
//             icon: AppAssets.emptyDataIcons.mediaLink,
//             title: AppString.emptyDataString.noLinkFound,
//             subtitle: AppString.emptyDataString.youdonthaveanyLinks,
//           );
//         default:
//           return Text("data");
//       }
//     } else {
//       // Debug: print only when list is not empty
//       // debugPrint("MEDIA_TYPE: $type");
//       switch (type) {
//         case 'media':
//           // Replace with your actual grid/list UI
//           return GridView.builder(
//             padding: const EdgeInsets.all(8),
//             itemCount: mediaList.length,
//             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 3,
//               crossAxisSpacing: 8,
//               mainAxisSpacing: 8,
//             ),
//             itemBuilder: (context, index) {
//               final record = mediaList[index];
//               return _buildMediaItem(record);
//             },
//           );
//         case 'doc':
//           return ListView.builder(
//             padding: const EdgeInsets.all(8),
//             itemCount: mediaList.length,
//             itemBuilder: (context, index) {
//               final record = mediaList[index];
//               return Padding(
//                 padding: SizeConfig.getPaddingOnly(bottom: 5),
//                 child: _buildDocItem(record),
//               );
//             },
//           );
//         case 'link':
//           return Container();
//         default:
//           return Text("data");
//       }
//     }
//   }

//   // Reusable empty state widget
//   Widget _buildEmptyState({
//     required String icon,
//     required String title,
//     required String subtitle,
//   }) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           SvgPicture.asset(icon, height: SizeConfig.sizedBoxHeight(84)),
//           SizedBox(height: 16),
//           Text(title, style: AppTypography.h3(context)),
//           SizedBox(height: 5),
//           Text(
//             subtitle,
//             style: AppTypography.innerText12Mediu(
//               context,
//             ).copyWith(color: AppColors.textColor.textGreyColor),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildMediaItem(Records media) {
//     return GestureDetector(
//       onTap: () => _openMedia(media),
//       child: Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(0),
//           color: AppColors.bgColor.bgWhite,
//           boxShadow: [
//             BoxShadow(
//               color: AppColors.shadowColor.c000000.withValues(alpha: 0.1),
//               blurRadius: 4,
//               offset: Offset(0, 2),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(0),
//           child: Stack(
//             fit: StackFit.expand,
//             children: [
//               _buildMediaPreview(media),
//               _buildMediaTypeIcon(media),
//               if (media.pinned) _buildPinnedIndicator(),
//               if (media.starredFor.isNotEmpty) _buildStarredIndicator(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildMediaPreview(Records media) {
//     if (media.isImage) {
//       return Image.network(
//         media.messageContent,
//         fit: BoxFit.cover,
//         errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
//         loadingBuilder: (context, child, loadingProgress) {
//           if (loadingProgress == null) return child;
//           return _buildLoadingPlaceholder();
//         },
//       );
//     } else if (media.isVideo && media.hasValidThumbnail) {
//       return Image.network(
//         media.messageThumbnail,
//         fit: BoxFit.cover,
//         errorBuilder: (context, error, stackTrace) => _buildVideoPlaceholder(),
//         loadingBuilder: (context, child, loadingProgress) {
//           if (loadingProgress == null) return child;
//           return _buildLoadingPlaceholder();
//         },
//       );
//     } else if (media.isVideo) {
//       return _buildVideoPlaceholder();
//     } else if (media.isDocument) {
//       return _buildDocumentPlaceholder();
//     } else if (media.isAudio) {
//       return _buildAudioPlaceholder();
//     }

//     return _buildErrorPlaceholder();
//   }

//   Widget _buildMediaTypeIcon(Records media) {
//     IconData icon;
//     Color color;

//     if (media.isVideo) {
//       icon = Icons.play_circle_filled;
//       color = Colors.white;
//     } else if (media.isDocument) {
//       icon = Icons.insert_drive_file;
//       color = AppColors.appPriSecColor.primaryColor;
//     } else if (media.isAudio) {
//       icon = Icons.audiotrack;
//       color = AppColors.appPriSecColor.primaryColor;
//     } else {
//       return SizedBox.shrink();
//     }

//     return Positioned(
//       bottom: 8,
//       right: 8,
//       child: Container(
//         padding: EdgeInsets.all(4),
//         decoration: BoxDecoration(
//           color: Colors.black.withValues(alpha: 0.6),
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Icon(icon, color: color, size: 16),
//       ),
//     );
//   }

//   Widget _buildPinnedIndicator() {
//     return Positioned(
//       top: 4,
//       left: 4,
//       child: Container(
//         padding: EdgeInsets.all(2),
//         decoration: BoxDecoration(
//           color: Colors.blue,
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Icon(Icons.push_pin, color: Colors.white, size: 12),
//       ),
//     );
//   }

//   Widget _buildStarredIndicator() {
//     return Positioned(
//       top: 4,
//       right: 4,
//       child: Container(
//         padding: EdgeInsets.all(2),
//         decoration: BoxDecoration(
//           color: Colors.amber,
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Icon(Icons.star, color: Colors.white, size: 12),
//       ),
//     );
//   }

//   Widget _buildLoadingPlaceholder() {
//     return Container(
//       color: AppColors.bgColor.bg1Color,
//       child: Center(
//         child: CircularProgressIndicator(
//           strokeWidth: 2,
//           valueColor: AlwaysStoppedAnimation<Color>(
//             AppColors.appPriSecColor.primaryColor,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildErrorPlaceholder() {
//     return Container(
//       color: AppColors.bgColor.bg1Color,
//       child: Icon(Icons.error, color: AppColors.textColor.textGreyColor),
//     );
//   }

//   Widget _buildVideoPlaceholder() {
//     return Container(
//       color: AppColors.bgColor.bg1Color,
//       child: Icon(
//         Icons.videocam,
//         color: AppColors.textColor.textGreyColor,
//         size: 32,
//       ),
//     );
//   }

//   Widget _buildDocumentPlaceholder() {
//     return Container(
//       color: AppColors.bgColor.bg1Color,
//       child: Icon(
//         Icons.insert_drive_file,
//         color: AppColors.appPriSecColor.primaryColor,
//         size: 32,
//       ),
//     );
//   }

//   Widget _buildAudioPlaceholder() {
//     return Container(
//       color: AppColors.bgColor.bg1Color,
//       child: Icon(
//         Icons.audiotrack,
//         color: AppColors.appPriSecColor.primaryColor,
//         size: 32,
//       ),
//     );
//   }

//   void _openMedia(Records media) {
//     if (media.isImage) {
//       // Navigator.push(
//       //   context,
//       //   MaterialPageRoute(
//       //     builder:
//       //         (context) => ImageViewScreen(
//       //           imageUrl: media.messageContent,
//       //           heroTag: 'media_${media.messageId}',
//       //         ),
//       //   ),
//       // );
//       context.viewImage(
//         imageSource: media.messageContent,
//         imageTitle: media.messageContent,
//         heroTag: 'media_${media.messageId}',
//       );
//     } else if (media.isVideo) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder:
//               (context) => VideoViewerScreen(videoUrl: media.messageContent),
//         ),
//       );
//     } else {
//       // For documents and audio, you might want to implement downloading or opening
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Opening ${media.messageType} files is not yet implemented',
//           ),
//           backgroundColor: AppColors.appPriSecColor.primaryColor,
//         ),
//       );
//     }
//   }

//   Widget _buildDocItem(Records media) {
//     final downloadProgress = ValueNotifier<double>(0.0);
//     final isSentByMe = media.senderId.toString() == userID;
//     return FutureBuilder<bool>(
//       future: Provider.of<ChatProvider>(
//         context,
//         listen: false,
//       ).isPdfDownloaded(media.messageContent),
//       builder: (context, downloadSnapshot) {
//         return ValueListenableBuilder<double>(
//           valueListenable: downloadProgress,
//           builder: (context, progress, child) {
//             final isDownloaded = downloadSnapshot.data ?? false;
//             final isDownloading = progress > 0 && progress < 1;
//             final fileName = media.messageContent.split('/').last;

//             return GestureDetector(
//               onTap:
//                   isDownloading
//                       ? null
//                       : () => _handleDocumentAction(
//                         context,
//                         downloadProgress,
//                         fileName,
//                         media,
//                       ),
//               child: Column(
//                 crossAxisAlignment:
//                     isSentByMe
//                         ? CrossAxisAlignment.end
//                         : CrossAxisAlignment.start,
//                 children: [
//                   Container(
//                     constraints: BoxConstraints(
//                       maxWidth: SizeConfig.screenWidth * 0.75,
//                     ),
//                     decoration: BoxDecoration(
//                       color:
//                           isSentByMe
//                               ? AppColors.appPriSecColor.secondaryColor
//                               : AppColors.bgColor.bg2Color,
//                       borderRadius: BorderRadius.only(
//                         topLeft: Radius.circular(9),
//                         topRight: Radius.circular(9),
//                         bottomRight: Radius.circular(isSentByMe ? 0 : 9),
//                         bottomLeft: Radius.circular(isSentByMe ? 9 : 0),
//                       ),
//                     ),
//                     padding: SizeConfig.getPaddingSymmetric(
//                       horizontal: 3,
//                       vertical: 3,
//                     ),
//                     child: Column(
//                       crossAxisAlignment:
//                           isSentByMe
//                               ? CrossAxisAlignment.end
//                               : CrossAxisAlignment.start,
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Container(
//                           padding: SizeConfig.getPaddingSymmetric(
//                             horizontal: 15,
//                             vertical: 15,
//                           ),
//                           decoration: BoxDecoration(
//                             color: AppColors.bgColor.bg4Color,
//                             borderRadius: BorderRadius.circular(9),
//                           ),
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               SvgPicture.asset(
//                                 AppAssets.chatImage.pdfImage,
//                                 height: SizeConfig.sizedBoxHeight(30),
//                               ),
//                               SizedBox(width: SizeConfig.width(3)),
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: [
//                                     Text(
//                                       fileName,
//                                       style: AppTypography.mediumText(
//                                         context,
//                                       ).copyWith(
//                                         color: AppColors.textColor.textDarkGray,
//                                         fontSize: SizeConfig.getFontSize(12),
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                       maxLines: 1,
//                                       overflow: TextOverflow.ellipsis,
//                                     ),
//                                     SizedBox(height: 2),
//                                     FutureBuilder<String>(
//                                       future:
//                                           isDownloaded
//                                               ? Provider.of<ChatProvider>(
//                                                 context,
//                                                 listen: false,
//                                               ).getPdfMetadataWhenDownloaded(
//                                                 media.messageContent,
//                                               )
//                                               : _getFileMetadata(
//                                                 fileName,
//                                                 media,
//                                               ),
//                                       builder: (context, metadataSnapshot) {
//                                         return Text(
//                                           metadataSnapshot.data ??
//                                               _getFileTypeDisplay(fileName),
//                                           style: AppTypography.captionText(
//                                             context,
//                                           ).copyWith(
//                                             fontSize: SizeConfig.getFontSize(9),
//                                             color:
//                                                 AppColors
//                                                     .textColor
//                                                     .textDarkGray,
//                                           ),
//                                         );
//                                       },
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               if (!isDownloaded)
//                                 Padding(
//                                   padding: EdgeInsets.only(
//                                     left: SizeConfig.width(2),
//                                   ),
//                                   child: Container(
//                                     width: 32,
//                                     height: 32,
//                                     decoration: BoxDecoration(
//                                       shape: BoxShape.circle,
//                                       border: Border.all(
//                                         color: AppColors.textColor.textDarkGray,
//                                       ),
//                                     ),
//                                     child:
//                                         isDownloading
//                                             ? Stack(
//                                               alignment: Alignment.center,
//                                               children: [
//                                                 CircularProgressIndicator(
//                                                   value: progress,
//                                                   strokeWidth: 2,
//                                                   valueColor:
//                                                       AlwaysStoppedAnimation<
//                                                         Color
//                                                       >(
//                                                         AppColors
//                                                             .textColor
//                                                             .textGreyColor,
//                                                       ),
//                                                 ),
//                                                 SvgPicture.asset(
//                                                   AppAssets
//                                                       .chatImage
//                                                       .downloadArrow,
//                                                   height: 10,
//                                                   color:
//                                                       AppColors
//                                                           .textColor
//                                                           .textDarkGray,
//                                                 ),
//                                               ],
//                                             )
//                                             : Padding(
//                                               padding: const EdgeInsets.all(
//                                                 8.0,
//                                               ),
//                                               child: SvgPicture.asset(
//                                                 AppAssets
//                                                     .chatImage
//                                                     .downloadArrow,
//                                                 height: 10,
//                                                 color:
//                                                     AppColors
//                                                         .textColor
//                                                         .textDarkGray,
//                                               ),
//                                             ),
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                         SizedBox(height: SizeConfig.height(1)),
//                       ],
//                     ),
//                   ),
//                   SizedBox(height: SizeConfig.height(1)),
//                   buildMetadataRow(
//                     context: context,
//                     media: media,
//                     isStarred: false,
//                     isSentByMe: isSentByMe,
//                   ),
//                   SizedBox(height: SizeConfig.height(2)),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   void _handleDocumentAction(
//     BuildContext context,
//     ValueNotifier<double> downloadProgress,
//     String fileName,
//     Records media,
//   ) {
//     final extension = fileName.toLowerCase().split('.').last;

//     if (extension == 'pdf') {
//       _handleDocumentDownload(context, downloadProgress, media);
//     } else {
//       _openFileDirectly(context, media);
//     }
//   }

//   void _openFileDirectly(BuildContext context, Records media) async {
//     try {
//       final uri = Uri.parse(media.messageContent);
//       if (await canLaunchUrl(uri)) {
//         await launchUrl(uri, mode: LaunchMode.externalApplication);
//       } else {
//         _showErrorDialog(context, 'Cannot open this file type');
//       }
//     } catch (e) {
//       _showErrorDialog(context, 'Error opening file: $e');
//     }
//   }

//   void _openFile(BuildContext context, String filePath, Records media) {
//     final extension = filePath.toLowerCase().split('.').last;

//     if (extension == 'pdf') {
//       _openPdfViewer(context, filePath, media);
//     } else {
//       _openWithSystemApp(context, filePath);
//     }
//   }

//   void _openWithSystemApp(BuildContext context, String filePath) async {
//     try {
//       final uri = Uri.file(filePath);
//       if (await canLaunchUrl(uri)) {
//         await launchUrl(uri, mode: LaunchMode.externalApplication);
//       } else {
//         _showErrorDialog(context, 'No app found to open this file type');
//       }
//     } catch (e) {
//       _showErrorDialog(context, 'Error opening file: $e');
//     }
//   }

//   void _showErrorDialog(BuildContext context, String message) {
//     showDialog(
//       context: context,
//       builder:
//           (ctx) => AlertDialog(
//             title: Text('Error'),
//             content: Text(message),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx),
//                 child: Text('OK'),
//               ),
//             ],
//           ),
//     );
//   }

//   Future<String> _getFileMetadata(String fileName, Records media) async {
//     final extension = fileName.toLowerCase().split('.').last;
//     switch (extension) {
//       case 'pdf':
//         return await Provider.of<ChatProvider>(
//           context,
//           listen: false,
//         ).getPdfMetadata(media.messageContent);
//       default:
//         return _getFileTypeDisplay(fileName);
//     }
//   }

//   void _handleDocumentDownload(
//     BuildContext context,
//     ValueNotifier<double> downloadProgress,
//     Records media,
//   ) {
//     Provider.of<ChatProvider>(context, listen: false).downloadPdfWithProgress(
//       pdfUrl: media.messageContent,
//       onProgress: (progress) {
//         downloadProgress.value = progress;
//       },
//       onComplete: (filePath, metadata) {
//         if (filePath != null) {
//           _showOpenDialog(context, filePath, media);
//         }
//       },
//     );
//   }

//   void _showOpenDialog(BuildContext context, String filePath, Records media) {
//     showModalBottomSheet(
//       context: context,
//       builder:
//           (ctx) => Container(
//             padding: const EdgeInsets.all(16),
//             child: Wrap(
//               children: [
//                 ListTile(
//                   leading: SvgPicture.asset(
//                     AppAssets.chatImage.pdfImage,
//                     height: SizeConfig.sizedBoxHeight(30),
//                   ),
//                   // Icon(
//                   //   _getFileIcon(chat.messageContent?.split('/').last ?? ''),
//                   // ),
//                   title: Text(
//                     "Open ${_getFileTypeDisplay(media.messageContent.split('/').last)}",
//                   ),
//                   onTap: () {
//                     Navigator.pop(ctx);
//                     _openFile(context, filePath, media);
//                   },
//                 ),
//                 ListTile(
//                   leading: Icon(Icons.cancel),
//                   title: Text("Cancel"),
//                   onTap: () => Navigator.pop(ctx),
//                 ),
//               ],
//             ),
//           ),
//     );
//   }

//   void _openPdfViewer(BuildContext context, String filePath, Records media) {
//     final fileName = media.messageContent.split('/').last;
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder:
//             (context) =>
//                 PdfViewerScreen(filePath: filePath, fileName: fileName),
//       ),
//     );
//   }

//   String _getFileTypeDisplay(String fileName) {
//     final extension = fileName.toLowerCase().split('.').last;
//     switch (extension) {
//       case 'pdf':
//         return 'PDF Document';
//       case 'doc':
//       case 'docx':
//         return 'Word Document';
//       case 'xls':
//       case 'xlsx':
//         return 'Excel Spreadsheet';
//       case 'ppt':
//       case 'pptx':
//         return 'PowerPoint Presentation';
//       case 'txt':
//         return 'Text Document';
//       case 'jpg':
//       case 'jpeg':
//       case 'png':
//       case 'gif':
//         return 'Image File';
//       case 'mp4':
//       case 'avi':
//       case 'mov':
//         return 'Video File';
//       case 'mp3':
//       case 'wav':
//       case 'aac':
//         return 'Audio File';
//       case 'zip':
//       case 'rar':
//       case '7z':
//         return 'Archive File';
//       default:
//         return 'Document';
//     }
//   }

//   Widget buildMetadataRow({
//     required BuildContext context,
//     required Records media,
//     required bool isStarred,
//     required bool isSentByMe,
//   }) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       mainAxisAlignment: MainAxisAlignment.end,
//       children: [
//         // Pinned indicator (only show if pinned and not starred)
//         if (media.pinned == true) ...[
//           SvgPicture.asset(
//             AppAssets.pinMessageIcon,
//             height: 13,
//             color:
//                 isSentByMe
//                     ? AppColors.appPriSecColor.primaryColor
//                     : AppColors.textColor.textGreyColor,
//           ),
//           SizedBox(width: SizeConfig.width(1)),
//         ],

//         // Star indicator (only show if starred)
//         if (isStarred) ...[
//           Padding(
//             padding: SizeConfig.getPaddingOnly(bottom: 2),
//             child: Icon(
//               Icons.star,
//               size: 12,
//               color: AppColors.appPriSecColor.primaryColor,
//             ),
//           ),
//           SizedBox(width: SizeConfig.width(1)),
//         ],

//         if (isSentByMe) ...[
//           buildMessageStatus(
//             context: context,
//             chat: media,
//             isStarred: isStarred,
//             isSentByMe: isSentByMe,
//           ),
//           SizedBox(width: SizeConfig.width(1)),
//         ],

//         // Timestamp
//         Text(
//           _formatTime(media.createdAt),
//           style: AppTypography.captionText(context).copyWith(
//             color:
//                 isSentByMe
//                     ? AppColors.textColor.textDarkGray
//                     : AppColors.textColor.textGreyColor,
//             fontSize: 10,
//           ),
//         ),
//       ],
//     );
//   }

//   // ✅ Message status indicators
//   static Widget buildMessageStatus({
//     required BuildContext context,
//     required Records chat,
//     required bool isStarred,
//     required bool isSentByMe,
//   }) {
//     IconData statusIcon = Icons.schedule;
//     Color iconColor = AppColors.textColor.textDarkGray;

//     switch (chat.messageSeenStatus.toLowerCase()) {
//       case 'seen':
//         statusIcon = Icons.done_all; // Double tick
//         iconColor = Colors.blue; // Blue when read
//         break;
//       case 'sent':
//         statusIcon = Icons.done_all; // Double tick
//         iconColor = AppColors.textColor.textDarkGray; // Grey when sent
//         break;
//       case 'pending':
//       default:
//         statusIcon = Icons.schedule;
//         iconColor = AppColors.textColor.textDarkGray;
//         break;
//     }

//     return Icon(statusIcon, color: iconColor, size: 12);
//   }

//   // ✅ Helper: Format timestamp
//   static String _formatTime(String? timestamp) {
//     if (timestamp == null) return '';

//     try {
//       final dateTime = DateTime.parse(timestamp);
//       final localDateTime = dateTime.toLocal(); // Convert to local time
//       return DateFormat.jm().format(localDateTime); // e.g., 12:30 PM
//     } catch (e) {
//       return '';
//     }
//   }
// }
