// ignore_for_file: unused_field

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';
import 'package:whoxa/featuers/report/widgets/report_user_dialog.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart'
    as usernamecheck;
import 'package:whoxa/featuers/chat/data/models/chat_media_model.dart' as media;
import 'package:whoxa/featuers/chat/data/models/link_model.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/chat/repository/chat_repository.dart';
import 'package:whoxa/featuers/chat/widgets/chat_files_views_handle/image_view.dart';
import 'package:whoxa/featuers/chat/widgets/chat_files_views_handle/video_view.dart';
import 'package:whoxa/featuers/call/call_model.dart';
import 'package:whoxa/featuers/call/call_ui.dart';
import 'package:whoxa/featuers/profile/provider/profile_provider.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/metadata_service.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/clip_path.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';
import 'package:whoxa/featuers/chat/data/starred_messages_model.dart'
    as starred;

class UserProfileView extends StatefulWidget {
  final int userId;
  final int? chatId;
  final bool blockFlag; // Instant block status for initial UI rendering
  final String? chatName;
  final bool isAdminChat;
  // Already-known peer avatar/name (e.g. from the chat app bar) shown while
  // the profile is loading, instead of the static default image.
  final String? initialProfilePic;
  final String? initialName;

  const UserProfileView({
    super.key,
    required this.userId,
    this.chatId,
    this.blockFlag = false,
    this.chatName,
    this.isAdminChat = false,
    this.initialProfilePic,
    this.initialName,
  });

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  usernamecheck.UserNameCheckModel? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;
  bool _blockStatusChanged = false;
  bool _isClearingChat = false;

  final ChatRepository _chatRepository = GetIt.instance<ChatRepository>();

  // Cache initial block status to prevent UI flickering
  String _cachedBlockScenario = 'none';
  bool _hasInitializedBlockState = false;

  media.ChatMediaResponse? _mediaResponse;
  bool _hasError = false;

  // Tab controller for different media types
  late TabController _tabController;

  // Filtered lists for different media types
  final List<media.Records> _allMedia = [];
  List<media.Records> _images = [];
  List<media.Records> _videos = [];
  List<media.Records> _documents = [];
  List<media.Records> _links = [];
  late Future<Metadata> metadataFuture;

  // Future<void> _loadChatMedia(String type) async {
  //   setState(() {
  //     _isLoading = true;
  //     _hasError = false;
  //     _errorMessage = null;
  //   });

  //   try {
  //     final response = await _chatRepository.getChatMedia(
  //       chatId: widget.chatId!,
  //       type: type, //'media',
  //     );

  //     if (response != null && response.status) {
  //       setState(() {
  //         _mediaResponse = response;
  //         _allMedia = response.data!.records;

  //         // Filter media by type
  //         if (type == "media") {
  //           _images = _allMedia.where((media) => media.isImage).toList();
  //           _videos = _allMedia.where((media) => media.isVideo).toList();
  //         }
  //         if (type == "doc") {
  //           _documents = _allMedia.where((media) => media.isDocument).toList();
  //         }
  //         if (type == "link") {
  //           _links = _allMedia.where((media) => media.isLinks).toList();
  //         }
  //         debugPrint("_images:${_images.length.toString()}");
  //         debugPrint("_video:${_videos.length.toString()}");
  //         debugPrint("_document:${_documents.length.toString()}");
  //         debugPrint("_links:${_links.length.toString()}");

  //         _isLoading = false;
  //         _hasError = false;
  //       });
  //     } else {
  //       setState(() {
  //         _hasError = true;
  //         _errorMessage = response?.message ?? 'Failed to load media';
  //         _isLoading = false;
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _hasError = true;
  //       _errorMessage = 'Error loading media: $e';
  //       _isLoading = false;
  //     });
  //   }
  // }

  List<MediaSection> _sections = [];

  Future<void> _loadAllMedia() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _chatRepository.getChatMedia(chatId: widget.chatId!, type: 'media'),
        _chatRepository.getChatMedia(chatId: widget.chatId!, type: 'doc'),
        _chatRepository.getChatMedia(chatId: widget.chatId!, type: 'link'),
      ]);

      final mediaResponse = results[0];
      final docResponse = results[1];
      final linkResponse = results[2];

      setState(() {
        // media -> split into images & videos
        final mediaRecords = mediaResponse?.data?.records ?? [];
        _images = mediaRecords.where((m) => m.isImage || m.isGif).toList();

        _videos = mediaRecords.where((m) => m.isVideo).toList();

        // documents
        _documents = docResponse?.data?.records ?? [];

        // links
        _links = linkResponse?.data?.records ?? [];

        // build sections
        _sections = [
          if (_images.isNotEmpty || _videos.isNotEmpty)
            MediaSection(title: "Media", items: [..._images, ..._videos]),
          if (_documents.isNotEmpty)
            MediaSection(title: "Documents", items: _documents),
          if (_links.isNotEmpty) MediaSection(title: "Links", items: _links),
        ];

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = "Error loading media: $e";
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    if (widget.chatId != 0) {
      _loadAllMedia();
    }

    // Initialize cached block state based on blockFlag parameter
    _initializeCachedBlockState();

    // Remove immediate refresh - use blockFlag for initial state, sync in background
    _performBackgroundBlockSync();
  }

  /// Initialize cached block state to prevent UI flickering during provider updates
  void _initializeCachedBlockState() {
    // Use blockFlag passed from parent to set initial state
    _cachedBlockScenario = widget.blockFlag ? 'user_blocked_other' : 'none';
    _hasInitializedBlockState = true;
  }

  /// Perform background block status sync without affecting UI
  void _performBackgroundBlockSync() {
    // Delay the sync to avoid UI flickering during initial render
    Future.delayed(Duration(milliseconds: 1000), () async {
      if (mounted) {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        // Use the non-blocking sync method instead of full refresh
        await chatProvider.syncBlockStatusOnForeground();
      }
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      debugPrint(
        'UserProfileView: Loading profile for userId: ${widget.userId}',
      );
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      final profile = await profileProvider.getPeerUserProfile(widget.userId);

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('UserProfileView: Error loading profile: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Builds a displayable phone string from the peer record, returning an
  /// empty string when the backend omits the number (avoids the "nullnull"
  /// that raw string interpolation of two null fields produced).
  String _peerPhoneNumber(usernamecheck.Records userRecord) {
    final code = userRecord.countryCode?.trim() ?? '';
    final number = userRecord.mobileNum?.trim() ?? '';
    if (number.isEmpty) return '';
    return '$code$number'.trim();
  }

  bool _hasInitialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _extractRouteArguments();
      _hasInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadStarredMessages();
      });
    }
  }

  String? _chatName;
  void _extractRouteArguments() {
    if (widget.chatId != null) {
      _chatId = widget.chatId;
      _chatName = widget.chatName;
      debugPrint(
        'DEBUG: Using widget parameters - chatId: $_chatId, chatName: $_chatName',
      );
      return;
    }

    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      _chatId = arguments['chatId'] as int?;
      _chatName = arguments['chatName'] as String?;
      debugPrint(
        'DEBUG: Extracted from route args - chatId: $_chatId, chatName: $_chatName',
      );
    } else {
      debugPrint(
        'DEBUG: No chat-specific arguments found, showing all starred messages',
      );
    }
  }

  bool _isLoadingMore = false;
  int _currentPage = 1;
  int? _chatId;
  starred.StarredMessagesResponse? _starredMessages;
  bool _hasMorePages = false;
  Future<void> _loadStarredMessages({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    }

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      debugPrint(
        'DEBUG: About to call getStarredMessages with page: $page, chatId: $_chatId',
      );
      final response = await _chatRepository.getStarredMessages(
        page: page,
        chatId: _chatId,
      );

      if (response != null && response.status == true) {
        setState(() {
          if (loadMore) {
            _starredMessages?.data?.records?.addAll(
              response.data?.records ?? [],
            );
            _currentPage = page;
          } else {
            _starredMessages = response;
            _currentPage = 1;
          }

          final pagination = response.data?.pagination;
          _hasMorePages =
              pagination != null &&
              pagination.currentPage != null &&
              pagination.totalPages != null &&
              pagination.currentPage! < pagination.totalPages!;

          _isLoading = false;
          _isLoadingMore = false;
          _hasError = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage =
              response?.message ?? 'Failed to load starred messages';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_errorMessage != null || _userProfile == null) {
      return _buildErrorScreen();
    }

    final userRecord =
        _userProfile!.data?.records?.isNotEmpty == true
            ? _userProfile!.data!.records!.first
            : null;
    if (userRecord == null) {
      return _buildErrorScreen();
    }
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _blockStatusChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      chatProfileWidget(
                        context,
                        profileChild: LayoutBuilder(
                          builder: (context, constraints) {
                            // Responsive profile image size based on screen width
                            double screenWidth =
                                MediaQuery.of(context).size.width;
                            double profileSize =
                                screenWidth < 360
                                    ? 100
                                    : screenWidth < 600
                                    ? 120
                                    : 140;

                            return Container(
                              height: profileSize,
                              width: profileSize,
                              decoration: BoxDecoration(
                                color: AppColors.bgColor.bg4Color,
                                borderRadius: BorderRadius.circular(
                                  profileSize,
                                ),
                                border: Border.all(
                                  color: AppThemeManage.appTheme.borderColor,
                                  width: screenWidth < 360 ? 1.5 : 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  profileSize,
                                ),
                                child: _buildProfileImageContent(),
                              ),
                            );
                          },
                        ),
                      ),

                      SizedBox(height: SizeConfig.height(2)),

                      // User Name - Use ContactNameService for consistent display
                      LayoutBuilder(
                        builder: (context, constraints) {
                          double screenWidth =
                              MediaQuery.of(context).size.width;

                          return Consumer<ProjectConfigProvider>(
                            builder: (context, configProvider, child) {
                              final displayName = ContactNameService.instance
                                  .getDisplayName(
                                    userId: userRecord.userId,
                                    userFullName: userRecord.fullName,
                                    userName: userRecord.userName,
                                    userEmail: userRecord.email,
                                    firstName: userRecord.firstName,
                                    lastName: userRecord.lastName,
                                    configProvider: configProvider,
                                  );

                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth < 360 ? 20 : 30,
                                ),
                                child: UserNameWithBadge(
                                  userId: userRecord.userId,
                                  name: displayName,
                                  textAlign: TextAlign.center,
                                  maxLines: screenWidth < 360 ? 2 : 1,
                                  style: AppTypography.innerText16(
                                    context,
                                  ).copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: screenWidth < 360 ? 14 : 16,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      SizedBox(height: SizeConfig.height(0.5)),

                      // Phone number (only when the backend actually returns it)
                      if (_peerPhoneNumber(userRecord).isNotEmpty)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            double screenWidth =
                                MediaQuery.of(context).size.width;

                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth < 360 ? 20 : 30,
                              ),
                              child: Text(
                                _peerPhoneNumber(userRecord),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.innerText08(
                                  context,
                                ).copyWith(
                                  color: AppColors.textColor.textDarkGray,
                                  fontSize: screenWidth < 360 ? 10 : 11,
                                ),
                              ),
                            );
                          },
                        ),

                      SizedBox(height: SizeConfig.height(3)),

                      // row in auido, video and search method
                      widget.isAdminChat ? SizedBox.shrink() : rowContainer(),
                      SizedBox(height: SizeConfig.height(2)),
                      // Profile Information
                      _buildProfileInfo(userRecord),

                      // Blocked Status Widget
                      // _buildBlockedStatusWidget(),

                      // Action Buttons
                      // _buildActionButtons(userRecord),
                      widget.isAdminChat
                          ? SizedBox.shrink()
                          : SizedBox(height: SizeConfig.height(2)),
                      widget.isAdminChat
                          ? SizedBox.shrink()
                          : _buildMediaLinksDocs(_allMedia),
                      widget.isAdminChat
                          ? SizedBox.shrink()
                          : SizedBox(height: SizeConfig.height(2)),
                      widget.isAdminChat
                          ? SizedBox.shrink()
                          : starMessageWidget(),

                      widget.isAdminChat
                          ? SizedBox.shrink()
                          : SizedBox(height: SizeConfig.height(2)),
                      widget.isAdminChat
                          ? SizedBox.shrink()
                          : _buildBlockReportMethod(
                            userRecord,
                            userFName: ContactNameService.instance.resolveName(
                              userId: userRecord.userId,
                              firstName: userRecord.firstName,
                              lastName: userRecord.lastName,
                              fullName: userRecord.fullName,
                              userName: userRecord.userName,
                              email: userRecord.email,
                              fallback: 'Unknown User',
                            ),
                          ),
                      SizedBox(height: SizeConfig.height(2)),
                    ],
                  ),
                ),
                if (_isClearingChat) _buildClearChatLoadingOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileImageContent() {
    final userRecord =
        _userProfile?.data?.records?.isNotEmpty == true
            ? _userProfile!.data!.records!.first
            : null;
    final profilePic = userRecord?.profilePic ?? '';
    final userName = ContactNameService.instance.resolveName(
      userId: userRecord?.userId,
      firstName: userRecord?.firstName,
      lastName: userRecord?.lastName,
      fullName: userRecord?.fullName,
      userName: userRecord?.userName,
      email: userRecord?.email,
      fallback: 'Unknown',
    );

    final avatar = CommonProfileAvatar(
      imageUrl: profilePic,
      name: userName,
      radius: 60,
    );

    // WhatsApp-style: tapping the avatar opens a full-screen preview of the
    // photo. Only wired up when the peer actually has a real profile photo —
    // letter-avatar fallbacks stay non-interactive.
    final hasRealPhoto =
        profilePic.isNotEmpty &&
        profilePic != kNotFoundProfileImageUrl &&
        (profilePic.startsWith('http://') || profilePic.startsWith('https://'));
    if (!hasRealPhoto) return avatar;

    final heroTag = 'peer-profile-${userRecord?.userId ?? widget.userId}';

    return GestureDetector(
      onTap: () => _showProfilePhotoDialog(profilePic, userName, heroTag),
      child: Hero(tag: heroTag, child: avatar),
    );
  }

  /// WhatsApp-style quick preview: a lightweight dialog showing the peer's
  /// profile photo (pinch-to-zoom, tap outside to dismiss) instead of pushing
  /// a full separate screen.
  void _showProfilePhotoDialog(
    String imageUrl,
    String userName,
    String heroTag,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Flexible(
                child: GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: Hero(
                    tag: heroTag,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder:
                              (context, url) => const Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => CommonProfileAvatar(
                                imageUrl: null,
                                name: userName,
                                radius: 80,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                userName,
                textAlign: TextAlign.center,
                style: AppTypography.innerText16(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileInfo(usernamecheck.Records userRecord) {
    String apiTime = userRecord.updatedAt ?? "2025-08-27T11:35:19.110Z";

    // Parse the UTC time string
    DateTime dateTime = DateTime.parse(apiTime);

    // Format to "MMM d, yyyy"
    String formattedDate = DateFormat("MMM d, yyyy").format(dateTime);

    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth < 360 ? 10 : 15,
          ),
          child: container(
            context,
            radius: screenWidth < 360 ? 8 : 10,
            boxShadow: [
              BoxShadow(
                offset: Offset(0, 0),
                blurRadius: screenWidth < 360 ? 8 : 10,
                spreadRadius: 0,
                color: AppColors.shadowColor.c000000.withValues(alpha: 0.07),
              ),
            ],
            child: Padding(
              padding: EdgeInsets.all(screenWidth < 360 ? 12 : 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // // Email
                  // if (userRecord.email != null && userRecord.email!.isNotEmpty)
                  //   _buildInfoRow(
                  //     icon: AppAssets.svgIcons.sms,
                  //     label: "Email",
                  //     value: userRecord.email!,
                  //   ),

                  // // Country
                  // if (userRecord.country != null && userRecord.country!.isNotEmpty)
                  //   _buildInfoRow(
                  //     icon: AppAssets.svgIcons.location,
                  //     label: "Country",
                  //     value: userRecord.country!,
                  //   ),

                  // // Gender
                  // if (userRecord.gender != null && userRecord.gender!.isNotEmpty)
                  //   _buildInfoRow(
                  //     icon: AppAssets.svgIcons.emojiSmile,
                  //     label: "Gender",
                  //     value: userRecord.gender!,
                  //   ),

                  // Bio
                  if (userRecord.bio != null && userRecord.bio!.isNotEmpty)
                    // _buildInfoRow(
                    //   icon: AppAssets.svgIcons.vector,
                    //   label: "Bio",
                    //   value: userRecord.bio!,
                    // ),
                    Text(
                      "${userRecord.bio}",
                      style: AppTypography.innerText16(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  if (userRecord.bio != null && userRecord.bio!.isNotEmpty)
                    SizedBox(height: SizeConfig.height(1)),

                  Row(
                    children: [
                      Text(
                        "Logged in $formattedDate",
                        style: AppTypography.innerText10(
                          context,
                        ).copyWith(color: AppColors.textColor.textDarkGray),
                      ),
                    ],
                  ),

                  // // Show limited info message if no additional details
                  // if ((userRecord.email == null || userRecord.email!.isEmpty) &&
                  //     (userRecord.country == null || userRecord.country!.isEmpty) &&
                  //     (userRecord.gender == null || userRecord.gender!.isEmpty) &&
                  //     (userRecord.bio == null || userRecord.bio!.isEmpty))
                  //   Center(
                  //     child: Text(
                  //       "Limited profile information available",
                  //       style: AppTypography.smallText(context).copyWith(
                  //         color: AppColors.textColor.textGreyColor,
                  //         fontStyle: FontStyle.italic,
                  //       ),
                  //     ),
                  //   ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildInfoRow({
    required String icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: SizeConfig.getPaddingSymmetric(vertical: 8),
      child: Row(
        children: [
          SvgPicture.asset(
            icon,
            height: 20,
            colorFilter: ColorFilter.mode(
              AppColors.appPriSecColor.primaryColor,
              BlendMode.srcIn,
            ),
          ),
          SizedBox(width: SizeConfig.width(3)),
          Text(
            "$label: ",
            style: AppTypography.smallText(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.smallText(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildBlockedStatusWidget() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Get current user ID from the provider
        final currentUserId = chatProvider.currentUserId;
        if (currentUserId == null) return SizedBox.shrink();

        // Use stable block state to prevent flickering
        String blockScenario;
        if (_hasInitializedBlockState && !_blockStatusChanged) {
          blockScenario = _cachedBlockScenario;
        } else {
          blockScenario = chatProvider.getBlockScenario(
            widget.chatId,
            widget.userId,
          );
          _cachedBlockScenario = blockScenario;
        }

        // Show appropriate blocked message based on scenario
        if (blockScenario != 'none') {
          // Get user display name for consistent messaging
          final userRecord =
              _userProfile?.data?.records?.isNotEmpty == true
                  ? _userProfile!.data!.records!.first
                  : null;

          String displayName = 'this user';
          if (userRecord != null) {
            final configProvider = Provider.of<ProjectConfigProvider>(
              context,
              listen: false,
            );
            displayName = ContactNameService.instance.getDisplayName(
              userId: userRecord.userId,
              userFullName: userRecord.fullName,
              userName: userRecord.userName,
              userEmail: userRecord.email,
              firstName: userRecord.firstName,
              lastName: userRecord.lastName,
              configProvider: configProvider,
            );
          }

          String blockMessage;
          Color blockColor;

          switch (blockScenario) {
            case 'user_blocked_other':
              blockMessage = "You blocked $displayName";
              blockColor = Colors.orange;
              break;
            case 'user_blocked_by_other':
              blockMessage = "You have been blocked by $displayName";
              blockColor = Colors.red;
              break;
            case 'mutual_block':
              blockMessage = "You and $displayName have blocked each other";
              blockColor = Colors.red;
              break;
            default:
              return SizedBox.shrink();
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              double screenWidth = MediaQuery.of(context).size.width;

              return Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: SizeConfig.height(2)),
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth < 360 ? 15 : 20,
                  vertical: screenWidth < 360 ? 12 : 15,
                ),
                decoration: BoxDecoration(
                  color: blockColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    screenWidth < 360 ? 8 : 10,
                  ),
                  border: Border.all(color: blockColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.block,
                      color: blockColor,
                      size: screenWidth < 360 ? 20 : 24,
                    ),
                    SizedBox(width: screenWidth < 360 ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            blockMessage,
                            style: AppTypography.h5(context).copyWith(
                              color: blockColor,
                              fontWeight: FontWeight.w600,
                              fontSize: screenWidth < 360 ? 14 : 16,
                            ),
                          ),
                          SizedBox(height: screenWidth < 360 ? 3 : 4),
                          Text(
                            _getBlockDescriptionMessage(blockScenario),
                            style: AppTypography.smallText(context).copyWith(
                              color: blockColor.withValues(alpha: 0.8),
                              fontSize: screenWidth < 360 ? 11 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }

        return SizedBox.shrink();
      },
    );
  }

  String _getBlockDescriptionMessage(String blockScenario) {
    final userRecord =
        _userProfile?.data?.records?.isNotEmpty == true
            ? _userProfile!.data!.records!.first
            : null;

    // Get consistent display name
    String displayName = 'this user';
    if (userRecord != null) {
      final configProvider = Provider.of<ProjectConfigProvider>(
        context,
        listen: false,
      );
      displayName = ContactNameService.instance.getDisplayName(
        userId: userRecord.userId,
        userFullName: userRecord.fullName,
        userName: userRecord.userName,
        userEmail: userRecord.email,
        firstName: userRecord.firstName,
        lastName: userRecord.lastName,
        configProvider: configProvider,
      );
    }

    switch (blockScenario) {
      case 'user_blocked_other':
        return 'You blocked $displayName. You can unblock them anytime.';
      case 'user_blocked_by_other':
        return '$displayName has blocked you. You can also block them if needed.';
      case 'mutual_block':
        return 'You and $displayName have blocked each other. Either of you can unblock to restore communication.';
      default:
        return '';
    }
  }

  // ignore: unused_element
  Widget _buildActionButtons(usernamecheck.Records userRecord) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Use stable block state to prevent flickering
        String blockScenario;
        if (_hasInitializedBlockState && !_blockStatusChanged) {
          blockScenario = _cachedBlockScenario;
        } else {
          blockScenario = chatProvider.getBlockScenario(
            widget.chatId,
            widget.userId,
          );
          _cachedBlockScenario = blockScenario;
        }

        // Determine UI state based on block scenario
        bool canShowSendMessage = blockScenario == 'none';

        return LayoutBuilder(
          builder: (context, constraints) {
            double screenWidth = MediaQuery.of(context).size.width;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal:
                    screenWidth < 360
                        ? 15
                        : screenWidth < 600
                        ? 25
                        : 30,
              ),
              child: Column(
                children: [
                  // Only Send Message button - block/unblock is handled in bottom section
                  SizedBox(
                    width: double.infinity,
                    height:
                        screenWidth < 360
                            ? 40
                            : screenWidth < 600
                            ? 45
                            : 50,
                    child: Opacity(
                      opacity: canShowSendMessage ? 1.0 : 0.5,
                      child: customBtn(
                        context,
                        title: "Send Message",
                        onTap:
                            canShowSendMessage
                                ? () {
                                  Navigator.pop(context, _blockStatusChanged);
                                  // Message button will close the profile and return to chat list
                                  // The chat list will handle opening the chat
                                }
                                : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Enhanced block dialog with consistent display names
  void _showEnhancedBlockDialog(
    ChatProvider chatProvider,
    bool isCurrentlyBlocked,
    usernamecheck.Records userRecord,
  ) {
    // ✅ DEMO MODE: Block user blocking/unblocking for demo accounts
    if (isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demo accounts cannot block or unblock users'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get consistent display name for dialog
    final configProvider = Provider.of<ProjectConfigProvider>(
      context,
      listen: false,
    );
    final displayName = ContactNameService.instance.getDisplayName(
      userId: userRecord.userId,
      userFullName: userRecord.fullName,
      userName: userRecord.userName,
      userEmail: userRecord.email,
      firstName: userRecord.firstName,
      lastName: userRecord.lastName,
      configProvider: configProvider,
    );

    bottomSheetGobalWithoutTitle(
      context,
      bottomsheetHeight: SizeConfig.safeHeight(28),
      borderRadius: BorderRadius.circular(20),
      alignment: Alignment.bottomCenter,
      isCrossIconHide: true,
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: SizeConfig.height(2)),
            Text(
              "${isCurrentlyBlocked ? AppString.homeScreenString.areYouSureUnblock : AppString.homeScreenString.areYouSureBlock} ${userRecord.fullName}?",
              textAlign: TextAlign.start,
              style: AppTypography.captionText(context).copyWith(
                fontSize: SizeConfig.getFontSize(15),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: SizeConfig.height(1.5)),
            Text(
              isCurrentlyBlocked
                  ? '${AppString.homeScreenString.areYouSureUnblock} ${userRecord.fullName}?'
                  : '${AppString.homeScreenString.areYouSureBlock} ${userRecord.fullName}? ',
              textAlign: TextAlign.start,
              style: AppTypography.captionText(context).copyWith(
                color: AppColors.textColor.textGreyColor,
                fontSize: SizeConfig.getFontSize(13),
              ),
            ),
            SizedBox(height: SizeConfig.height(3)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: SizeConfig.height(5),
                  width: SizeConfig.width(35),
                  child: customBorderBtn(
                    context,
                    onTap: () {
                      Navigator.pop(context);
                    },
                    title: AppString.cancel,
                  ),
                ),
                SizedBox(
                  height: SizeConfig.height(5),
                  width: SizeConfig.width(35),
                  child: customBtn2(
                    context,
                    onTap: () async {
                      Navigator.pop(context);

                      // Call the block/unblock API
                      final success = await chatProvider.blockUnblockUser(
                        widget.userId,
                        widget.chatId ?? 0,
                      );

                      if (mounted) {
                        if (success) {
                          // Mark that block status changed and update cached state based on provider
                          setState(() {
                            _blockStatusChanged = true;
                            // Get the actual current state from provider after API call
                            _cachedBlockScenario = chatProvider
                                .getBlockScenario(widget.chatId, widget.userId);
                          });

                          // Only refresh blocked users list, don't refresh chat list immediately
                          // to preserve the instant UI updates made by blockUnblockUser
                          await chatProvider.refreshBlockStatus();

                          // Safely show snackbar
                          try {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isCurrentlyBlocked
                                      ? '$displayName ${AppString.blockUserStrings.hasBeenUnblocked}'
                                      : '$displayName ${AppString.blockUserStrings.hasBeenBlocked}',
                                ),
                                backgroundColor:
                                    isCurrentlyBlocked
                                        ? Colors.green
                                        : Colors.orange,
                              ),
                            );
                          } catch (e) {
                            // If context is deactivated, just log the success
                            debugPrint(
                              'UserProfileView: Block/unblock successful but cannot show snackbar - context deactivated',
                            );
                          }
                        } else {
                          // Safely show error snackbar
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${AppString.blockUserStrings.failedto} ${isCurrentlyBlocked ? AppString.blockUserStrings.unblockS : AppString.blockUserStrings.blockS} $displayName. ${AppString.pleaseTryAgain}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } catch (e) {
                            // If context is deactivated, just log the error
                            debugPrint(
                              'UserProfileView: Block/unblock failed but cannot show snackbar - context deactivated',
                            );
                          }
                        }
                      }
                    },
                    child: Text(
                      isCurrentlyBlocked
                          ? AppString.homeScreenString.unblock
                          : AppString.homeScreenString.block,
                      style: AppTypography.h5(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor.textBlackColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // customBtn(
  //                     context,
  //                     title: "Send Message",
  //                     onTap: () {
  //                       Navigator.pop(context, _blockStatusChanged);
  //                       // Message button will close the profile and return to chat list
  //                       // The chat list will handle opening the chat
  //                     },
  //                   ),

  Widget _buildLoadingScreen() {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _blockStatusChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        body: Column(
          children: [
            chatProfileWidget(
              context,
              profileChild: Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: AppColors.bgColor.bgWhite,
                  borderRadius: BorderRadius.circular(120),
                  border: Border.all(
                    color: AppColors.strokeColor.greyColor,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(120),
                  child:
                      widget.initialProfilePic != null
                          ? CommonProfileAvatar(
                            imageUrl: widget.initialProfilePic,
                            name: widget.initialName ?? widget.chatName ?? '',
                            radius: 60,
                          )
                          : Image.asset(
                            AppAssets.defaultUser,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          ),
                ),
              ),
            ),

            SizedBox(height: SizeConfig.height(30)),
            Center(child: commonLoading()),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _blockStatusChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        body: Column(
          children: [
            chatProfileWidget(
              context,
              profileChild: Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: AppColors.bgColor.bgWhite,
                  borderRadius: BorderRadius.circular(120),
                  border: Border.all(
                    color: AppColors.strokeColor.greyColor,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(120),
                  child: Image.asset(
                    AppAssets.defaultUser,
                    fit: BoxFit.cover,
                    width: 120,
                    height: 120,
                  ),
                ),
              ),
            ),

            SizedBox(height: SizeConfig.height(20)),
            Center(
              child: Padding(
                padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.textColor.textErrorColor1,
                    ),
                    SizedBox(height: SizeConfig.height(2)),
                    Text(
                      _errorMessage ?? 'Profile not found',
                      style: AppTypography.h5(context),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: SizeConfig.height(3)),
                    customBtn(
                      context,
                      title: "Retry",
                      onTap: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = null;
                        });
                        _loadUserProfile();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget chatProfileWidget(
    BuildContext context, {
    required Widget profileChild,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        yellowImageWidget(context),
        Positioned(
          bottom: -15,
          left: (MediaQuery.sizeOf(context).width - 100) / 2,
          child: Container(
            height: 110,
            width: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppThemeManage.appTheme.scaffoldBackColor,
              border: Border.all(
                color: AppThemeManage.appTheme.scaffoldBackColor,
                width: 4,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipOval(child: profileChild),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context, _blockStatusChanged),
            child: customeBackArrowBalck(
              context,
              isBackBlack: true,
              color: ThemeColorPalette.getTextColor(
                AppColors.appPriSecColor.primaryColor,
              ),
            ), //Icon(Icons.arrow_back_ios_new, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget rowContainer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // audio call method
        rowAudioVideoSearchContainer(
          context: context,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (_) => CallScreen(
                      chatId: widget.chatId!,
                      chatName: widget.chatName!,
                      callType: CallType.audio,
                      isIncoming: false,
                    ),
                fullscreenDialog: true,
              ),
            );
          },
          title: AppString.geoupProfileString.audio,
          svgImage: AppAssets.bottomNavIcons.call1,
        ),
        SizedBox(width: SizeConfig.width(5)),
        // video call method
        rowAudioVideoSearchContainer(
          context: context,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (_) => CallScreen(
                      chatId: widget.chatId!,
                      chatName: widget.chatName!,
                      callType: CallType.video,
                      isIncoming: false,
                    ),
                fullscreenDialog: true,
              ),
            );
          },
          title: AppString.geoupProfileString.video,
          svgImage: AppAssets.chatMsgTypeIcon.videoMsg,
        ),
        SizedBox(width: SizeConfig.width(5)),
        // search call method
        rowAudioVideoSearchContainer(
          context: context,
          onTap: () {
            _navigateToSearchMode();
          },
          title: AppString.geoupProfileString.search,
          svgImage: AppAssets.homeIcons.search,
        ),
      ],
    );
  }

  Widget _buildBlockReportMethod(
    usernamecheck.Records userRecord, {
    required String userFName,
  }) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Use stable block state - prefer cached state during initial load to prevent flickering
        String blockScenario;
        if (_hasInitializedBlockState && !_blockStatusChanged) {
          // Use cached state for initial render stability
          blockScenario = _cachedBlockScenario;
        } else {
          // Use provider state for real-time updates after initial load
          blockScenario = chatProvider.getBlockScenario(
            widget.chatId,
            widget.userId,
          );
          // Update cache when provider state changes
          _cachedBlockScenario = blockScenario;
        }

        // Show unblock if current user has blocked the other user (either alone or mutual)
        final showUnblockOption =
            blockScenario == 'user_blocked_other' ||
            blockScenario == 'mutual_block';
        return LayoutBuilder(
          builder: (context, constraints) {
            double screenWidth = MediaQuery.of(context).size.width;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth < 360 ? 10 : 15,
              ),
              child: container(
                context,
                radius: screenWidth < 360 ? 8 : 10,
                boxShadow: [
                  BoxShadow(
                    offset: Offset(0, 0),
                    blurRadius: screenWidth < 360 ? 8 : 10,
                    spreadRadius: 0,
                    color: AppColors.shadowColor.c000000.withValues(
                      alpha: 0.07,
                    ),
                  ),
                ],
                child: Column(
                  children: [
                    // Clear chat — empties only this user's view of the
                    // history (`POST /conversations/:id/clear`); the chat
                    // stays in the list. Needs an existing conversation.
                    if (_canClearChat) ...[
                      Padding(
                        padding: EdgeInsets.all(screenWidth < 360 ? 15 : 20),
                        child: rowIconWithRedText(
                          context: context,
                          color: AppColors.appPriSecColor.secondaryRed,
                          onTap: _confirmClearChat,
                          svgImage: AppAssets.groupProfielIcons.clearchat,
                          title: AppString.homeScreenString.clearChat,
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: AppThemeManage.appTheme.borderColor,
                      ),
                    ],
                    Padding(
                      padding: EdgeInsets.all(screenWidth < 360 ? 15 : 20),
                      child: rowIconWithRedText(
                        context: context,
                        color: AppColors.appPriSecColor.secondaryRed,
                        onTap: () {
                          _showEnhancedBlockDialog(
                            chatProvider,
                            showUnblockOption,
                            userRecord,
                          );
                        },
                        svgImage: AppAssets.groupProfielIcons.userBock,
                        title:
                            "${showUnblockOption ? AppString.geoupProfileString.unBlock : AppString.geoupProfileString.block} $userFName",
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: AppThemeManage.appTheme.borderColor,
                    ),
                    // Report user — `POST /report/report-user {user_id}`.
                    Padding(
                      padding: EdgeInsets.all(screenWidth < 360 ? 15 : 20),
                      child: rowIconWithRedText(
                        context: context,
                        color: AppColors.appPriSecColor.secondaryRed,
                        onTap: () {
                          showReportUserDialog(
                            context,
                            userId: widget.userId,
                            title: '${AppString.report} $userFName',
                          );
                        },
                        svgImage: AppAssets.chatImage.report,
                        title: '${AppString.report} $userFName',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMediaLinksDocs(List<media.Records> mediaList) {
    return Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
      child: container(
        context,
        radius: 10,
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 0),
            blurRadius: 10,
            spreadRadius: 0,
            color: AppColors.shadowColor.c000000.withValues(alpha: 0.07),
          ),
        ],
        child: Column(
          children: [
            SizedBox(height: SizeConfig.height(2)),
            InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.chatMedia,
                  arguments: {
                    'chatId': widget.chatId,
                    'chatName': widget.chatName,
                  },
                );
              },
              child: Padding(
                padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppString.geoupProfileString.mediaLinkandDocs,
                      style: AppTypography.innerText12Mediu(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppThemeManage.appTheme.chatMediaText,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.appPriSecColor.primaryColor
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            (
                                // _allMedia.length +
                                _images.length +
                                    _videos.length +
                                    _documents.length +
                                    _links.length)
                                .toString(),
                            style: AppTypography.innerText12Mediu(
                              context,
                            ).copyWith(
                              color: AppColors.appPriSecColor.primaryColor,
                            ),
                          ),
                        ), // media count
                        SvgPicture.asset(
                          AppDirectionality.appDirectionIcon.arrow,
                          height: SizeConfig.safeHeight(3),
                          colorFilter: ColorFilter.mode(
                            AppThemeManage.appTheme.darkWhiteColor,
                            BlendMode.srcIn,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: SizeConfig.height(2)),
            // horozontal midea, links, docs
            SizedBox(
              height: SizeConfig.sizedBoxHeight(90),
              child:
                  _sections.isNotEmpty
                      ? Align(
                        alignment: Alignment.centerLeft,
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: SizeConfig.getPaddingOnly(left: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: _sections.length.clamp(0, 4),
                          itemBuilder: (context, index) {
                            final items = _sections[index].items;
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              // padding: SizeConfig.getPaddingOnly(left: 20),
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length.clamp(0, 4),
                              itemBuilder: (context, itemIndex) {
                                final record = items[itemIndex];
                                return Padding(
                                  padding: SizeConfig.getPaddingOnly(right: 10),
                                  child: Container(
                                    height: 90,
                                    width: 90,

                                    decoration: BoxDecoration(
                                      color:
                                          AppThemeManage.appTheme.borderColor,
                                      border: Border.all(
                                        color:
                                            AppThemeManage.appTheme.borderColor,
                                      ),
                                    ),
                                    child: _buildMediaTypeContent(record),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      )
                      : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 48,
                              color: AppColors.textColor.textGreyColor,
                            ),
                            SizedBox(height: 16),
                            Text(
                              AppString.noMediainThisCategory,
                              style: AppTypography.mediumText(context).copyWith(
                                color: AppColors.textColor.textGreyColor,
                              ),
                            ),
                          ],
                        ),
                      ),
            ),
            SizedBox(height: SizeConfig.height(2)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTypeContent(media.Records media) {
    debugPrint("media.messageType:${media.messageType}");
    return media.messageType == "image"
        ? InkWell(
          onTap: () {
            context.viewImage(
              imageSource: media.messageContent,
              imageTitle: 'Chat Image',
              heroTag: media.messageContent,
            );
          },
          child: CachedNetworkImage(
            imageUrl: media.messageContent,
            fit: BoxFit.cover,
          ),
        )
        : media.messageType == "gif"
        ? InkWell(
          onTap: () {
            context.viewImage(
              imageSource: media.messageContent,
              imageTitle: 'Chat GIF',
              heroTag: media.messageContent,
            );
          },
          child: CachedNetworkImage(
            imageUrl: media.messageContent,
            fit: BoxFit.cover,
          ),
        )
        : media.messageType == "video"
        ? InkWell(
          onTap: () {
            context.viewVideo(videoUrl: media.messageContent);
          },
          child: ClipRRect(
            borderRadius: BorderRadiusGeometry.circular(0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: media.messageThumbnail,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) {
                      return Container(
                        color: AppColors.grey,
                        child: Icon(
                          Icons.videocam,
                          size: 20,
                          color: AppColors.textColor.textGreyColor,
                        ),
                      );
                    },
                  ),
                ),
                // Play button overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.3),
                    ),
                    child: Center(
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.white.withValues(alpha: 0.9),
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          size: 15,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        : media.messageType == "link"
        ? linkWidget(media)
        : media.messageType == "doc"
        ? Padding(
          padding: const EdgeInsets.all(20.0),
          child: SvgPicture.asset(AppAssets.chatImage.pdfImage),
        )
        : SizedBox.shrink();
  }

  void _navigateToSearchMode() {
    Navigator.pop(
      context,
      "search",
    ); // Return "search" to indicate search mode should be enabled
  }

  String? extractFirstUrl(String? text) {
    if (text == null || text.isEmpty) return null;
    final RegExp urlRegex = RegExp(
      r'(https?://[^\s]+|www\.[^\s]+)',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    return match?.group(0);
  }

  Widget linkWidget(media.Records media) {
    final extractedUrl = extractFirstUrl(media.messageContent)!;
    metadataFuture = MetadataService.fetchMetadata(extractedUrl);
    // metadataFuture = MetadataService.fetchMetadata(media.messageContent);
    return GestureDetector(
      onTap: () => _openLink(media.messageContent),
      child: FutureBuilder<Metadata>(
        future: metadataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Icon(Icons.link);
          }

          if (!snapshot.hasData || snapshot.hasError) {
            return const Icon(Icons.link);
          }
          if (!snapshot.hasData) {
            return const Center(child: Icon(Icons.link));
          }
          final metadata = snapshot.data!;
          return ClipRRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.5),
                    BlendMode.darken,
                  ),
                  child: Image.network(
                    metadata.image,
                    height: SizeConfig.sizedBoxHeight(63),
                    width: SizeConfig.sizedBoxHeight(57),
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => Icon(Icons.link),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Transform.rotate(
                    angle: math.pi / 1.5,
                    child: Icon(
                      Icons.link,
                      size: SizeConfig.sizedBoxHeight(28),
                      color: AppColors.textColor.textWhiteColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppString.couldNotLaunch} $url'),
          backgroundColor: AppColors.appPriSecColor.primaryColor,
        ),
      );
    }
  }

  Widget starMessageWidget() {
    double screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth < 360 ? 10 : 15),
      child: container(
        context,
        radius: screenWidth < 360 ? 8 : 10,
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 0),
            blurRadius: screenWidth < 360 ? 8 : 10,
            spreadRadius: 0,
            color: AppColors.shadowColor.c000000.withValues(alpha: 0.07),
          ),
        ],
        child: ListTile(
          leading: Container(
            height: SizeConfig.height(10),
            width: SizeConfig.width(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.appPriSecColor.secondaryColor.withValues(
                alpha: 0.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SvgPicture.asset(
                AppAssets.settingsIcosn.star,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  AppColors.appPriSecColor.secondaryColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          title: Text(
            AppString.settingStrigs.starredMessages, // "Starred Message",
            style: AppTypography.innerText14(context),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.appPriSecColor.primaryColor.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isLoading
                      ? "0"
                      : _hasError
                      ? "0"
                      : _starredMessages?.data?.records?.isEmpty ?? true
                      ? "0"
                      : _starredMessages!.data!.records != []
                      ? _starredMessages!.data!.records!.length.toString()
                      : "0",
                  style: AppTypography.inputPlaceholderSmall(context).copyWith(
                    fontFamily: AppTypography.fontFamily.poppins,
                    color: AppColors.appPriSecColor.primaryColor,
                    fontSize: SizeConfig.getFontSize(10),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SvgPicture.asset(
                AppDirectionality.appDirectionIcon.arrow,
                height: SizeConfig.safeHeight(3),
                colorFilter: ColorFilter.mode(
                  AppThemeManage.appTheme.darkWhiteColor,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
          onTap: () {
            // Navigate to StarredMessagesScreen for this specific chat
            Navigator.pushNamed(
              context,
              AppRoutes.starredMessages,
              arguments: {
                'chatId': widget.chatId,
                'chatName': widget.chatName,
                'fromProfileOrGroupInfo': true,
              },
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLEAR CHAT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Only an existing conversation has history to clear.
  bool get _canClearChat => widget.chatId != null && widget.chatId! > 0;

  void _confirmClearChat() {
    if (_isClearingChat || !_canClearChat) return;

    // ✅ DEMO MODE: same restriction as deleting a chat.
    if (isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please use real account to test this feature'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    showGlobalBottomSheet(
      context: context,
      title: AppString.homeScreenString.clearThisChat,
      subtitle: AppString.clearChatForMeOnly,
      cancelButtonText: AppString.cancel,
      confirmButtonText: AppString.homeScreenString.clearChat,
      onConfirm: () {
        Navigator.of(context).pop();
        _performClearChat();
      },
    );
  }

  /// Clears this user's view of the history; ChatProvider empties the open
  /// thread (if it's this chat), its cache and the chat-list preview, so the
  /// chat screen underneath is already empty when the user navigates back.
  Future<void> _performClearChat() async {
    if (!mounted) return;
    setState(() => _isClearingChat = true);

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final success = await chatProvider.clearChat(chatId: widget.chatId!);

    if (!mounted) return;
    setState(() => _isClearingChat = false);

    // The cleared messages' media is gone from this user's view too.
    if (success) {
      setState(() {
        _images = [];
        _videos = [];
        _documents = [];
        _links = [];
        _sections = [];
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? AppString.chatClearedSuccessfully
              : AppString.failedToClearChatPleaseTryAgain,
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildClearChatLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.appPriSecColor.primaryColor,
                ),
              ),
              SizedBox(height: SizeConfig.height(2)),
              Text(
                '${AppString.clearingChat}...',
                style: AppTypography.innerText16(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MediaSection {
  final String title;
  final List<media.Records> items;

  MediaSection({required this.title, required this.items});
}
