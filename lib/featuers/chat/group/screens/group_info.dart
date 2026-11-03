// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/featuers/chat/group/data/group_admin_repository.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/featuers/report/widgets/report_user_dialog.dart';
import 'package:whoxa/featuers/chat/data/models/link_model.dart';
import 'package:whoxa/featuers/chat/group/provider/group_provider.dart';
import 'package:whoxa/featuers/chat/group/data/model/group_member_response.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/featuers/chat/repository/chat_repository.dart';
import 'package:whoxa/featuers/chat/repository/conversation_repository.dart';
import 'package:whoxa/featuers/chat/widgets/chat_files_views_handle/image_view.dart';
import 'package:whoxa/featuers/chat/widgets/chat_files_views_handle/video_view.dart';
import 'package:whoxa/featuers/call/call_ui.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/avatar_initials.dart';
import 'package:whoxa/utils/metadata_service.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/widgets/clip_path.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/featuers/chat/data/models/chat_media_model.dart' as media;
import 'package:whoxa/featuers/call/call_model.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupName;
  final String? groupDescription;
  final String? groupImage;
  final int? groupId;
  final int memberCount;
  final VoidCallback? onGroupDeleted;

  const GroupInfoScreen({
    super.key,
    required this.groupName,
    this.groupDescription,
    this.groupImage,
    this.groupId,
    this.memberCount = 0,
    this.onGroupDeleted,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final double _horizontalPaddding = 16;

  final ChatRepository _chatRepository = GetIt.instance<ChatRepository>();

  final ConsoleAppLogger _logger = ConsoleAppLogger();
  bool _isDeleting = false;
  bool _isClearingChat = false;
  bool _showFullDescription = false;
  bool _showAllMembers = false;
  int? _currentUserId;

  // Updated group data from API response
  String? _updatedGroupName;
  String? _updatedGroupDescription;
  String? _updatedGroupImage;

  // Group members map for online status checking
  final Map<int, GroupMember> _groupMembersMap = {};

  // Filtered lists for different media types
  final List<media.Records> _allMedia = [];
  List<media.Records> _images = [];
  List<media.Records> _videos = [];
  List<media.Records> _links = [];
  List<media.Records> _documents = [];
  late Future<Metadata> metadataFuture;

  bool _isLoading = true;

  // Group admin surface (permissions, invite link, join requests).
  final GroupAdminRepository _adminRepo = GroupAdminRepository(
    GetIt.instance<ApiClient>(),
  );
  Map<String, dynamic> _perms = const {};
  String? _inviteUrl;
  List<Map<String, dynamic>> _joinRequests = const [];
  bool _adminLoading = true;

  // Future<void> _loadChatMedia() async {
  //   setState(() {
  //     _isLoading = true;
  //     _hasError = false;
  //     _errorMessage = null;
  //   });

  //   try {
  //     final response = await _chatRepository.getChatMedia(
  //       chatId: widget.groupId!,
  //       type: 'media',
  //     );

  //     if (response != null && response.status) {
  //       setState(() {
  //         _mediaResponse = response;
  //         _allMedia = response.data!.records;

  //         // Filter media by type
  //         _images = _allMedia.where((media) => media.isImage).toList();
  //         _videos = _allMedia.where((media) => media.isVideo).toList();
  //         _documents =
  //             _allMedia
  //                 .where((media) => media.isDocument || media.isAudio)
  //                 .toList();

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
    });

    try {
      final results = await Future.wait([
        _chatRepository.getChatMedia(chatId: widget.groupId!, type: 'media'),
        _chatRepository.getChatMedia(chatId: widget.groupId!, type: 'doc'),
        _chatRepository.getChatMedia(chatId: widget.groupId!, type: 'link'),
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
        _isLoading = false;
      });
    }
  }

  bool get _isMember => Provider.of<GroupProvider>(
    context,
    listen: false,
  ).members.any((e) => e.userId == int.parse(userID));

  void _makeCall(BuildContext context, CallType callType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => CallScreen(
              chatId: widget.groupId!,
              chatName: widget.groupName,
              callType: callType,
              isIncoming: false,
            ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    debugPrint("Group ID : ${widget.groupId}");
    debugPrint('desc : ${widget.groupDescription}');
    // Initialize with widget values
    _updatedGroupName = widget.groupName;
    _updatedGroupDescription = widget.groupDescription;
    _updatedGroupImage = widget.groupImage;
    _loadAllMedia();
    _loadGroupAdmin();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    await _getCurrentUserIdAsync();
    if (widget.groupId != null) {
      _loadGroupMembers();
      _loadGroupDescription();
    }
  }

  /// The description passed in can be missing or stale (e.g. opened from a
  /// notification or an older cached chat list), so read the current one from
  /// `GET /conversations/:id`. It is shown in the description card and
  /// pre-fills the edit sheet.
  Future<void> _loadGroupDescription() async {
    try {
      final conversation = await ConversationRepository(
        GetIt.instance<ApiClient>(),
      ).getConversation(widget.groupId!.toString());
      if (!mounted || conversation == null) return;
      final description = conversation.description?.trim() ?? '';
      if (description == (_updatedGroupDescription ?? '')) return;
      setState(() => _updatedGroupDescription = description);
    } catch (e) {
      _logger.e('Error loading group description: $e');
    }
  }

  Future<int?> _getCurrentUserIdAsync() async {
    try {
      final String? userIdString = await SecurePrefs.getString(
        SecureStorageKeys.USERID,
      );
      _currentUserId = int.tryParse(userIdString ?? '');
      return _currentUserId;
    } catch (e) {
      _logger.e('Error getting current user ID: $e');
      return null;
    }
  }

  bool _isCurrentUserAdmin(GroupProvider groupProvider) {
    if (_currentUserId == null) return false;

    // First check the loaded members
    final currentUserMember = _groupMembersMap[_currentUserId];
    if (currentUserMember != null) {
      return currentUserMember.isAdmin;
    }

    // Fallback: check in provider's members list
    final members = groupProvider.members;
    final currentMember = members.firstWhere(
      (member) => member.userId == _currentUserId,
      orElse:
          () => GroupMember(
            participantId: -1,
            userId: -1,
            updateCounter: false,
            isAdmin: false,
            isDeleted: false,
            lastMessageId: 0,
            createdAt: '',
            updatedAt: '',
            chatId: -1,
            lastSeen: null,
            isLocked: false,
          ),
    );

    return currentMember.userId != -1 ? currentMember.isAdmin : false;
  }

  bool _isCurrentUser(int userId) {
    return _currentUserId == userId;
  }

  // Flag for allowing all members to edit group info
  static const bool _allowAllMembersToEdit = true;

  bool _canEditGroup(GroupProvider groupProvider) {
    if (_allowAllMembersToEdit) {
      return true;
    }
    return _isCurrentUserAdmin(groupProvider);
  }

  void _loadGroupMembers() {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    groupProvider.getGroupMembers(chatId: widget.groupId!);
  }

  // Update group members map when members are loaded
  void _updateGroupMembersMap(List<GroupMember> members) {
    _groupMembersMap.clear();
    for (final member in members) {
      _groupMembersMap[member.userId] = member;
    }
  }

  // Get online group members count using ChatProvider
  int _getOnlineGroupMembersCount(ChatProvider chatProvider) {
    return _groupMembersMap.values
        .where((user) => chatProvider.isUserOnline(user.userId))
        .length;
  }

  // Check if specific user is online via ChatProvider
  bool _isUserOnlineFromChatProvider(int userId, ChatProvider chatProvider) {
    return chatProvider.isUserOnline(userId);
  }

  void _makeAdmin(GroupMember member, GroupProvider groupProvider) async {
    // ✅ DEMO MODE: Block make admin action for demo accounts
    if (isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppString.demoAccountsCannotManageGroupAdmins,
          ),
          backgroundColor: AppColors.textColor.textErrorColor,
        ),
      );
      return;
    }

    // final confirmed = await _showConfirmationDialog(
    //   title: 'Make Admin',
    //   content: 'Are you sure you want to make ${member.displayName} an admin?',
    //   confirmText: 'Make Admin',
    // );
    final confirmed = await _showGlobalBottomSheet(
      context: context,
      title: AppString.geoupProfileString.makeAdmin,
      subtitle:
          '${AppString.geoupProfileString.areyousureyouwanttomake} ${member.displayName} ${AppString.geoupProfileString.anadmin}?',
      confirmButtonText: AppString.geoupProfileString.confirm,
    );

    if (confirmed && widget.groupId != null) {
      final success = await groupProvider.makeGroupAdmin(
        chatId: widget.groupId!,
        userId: member.userId,
        isRemove: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '${member.displayName} ${AppString.geoupProfileString.isnowanadmin}'
                  : '${AppString.geoupProfileString.failedtomake} ${member.displayName} ${AppString.geoupProfileString.anadmin}',
            ),
            backgroundColor:
                success
                    ? AppColors.appPriSecColor.primaryColor
                    : AppColors.textColor.textErrorColor,
          ),
        );
      }
    }
  }

  void _removeMember(GroupMember member, GroupProvider groupProvider) async {
    // ✅ DEMO MODE: Block remove member action for demo accounts
    if (isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppString.demoAccountsCannotRemoveGroupMembers,
          ),
          backgroundColor: AppColors.textColor.textErrorColor,
        ),
      );
      return;
    }

    // final confirmed = await _showConfirmationDialog(
    //   title: 'Remove Member',
    //   content:
    //       'Are you sure you want to remove ${member.displayName} from the group?',
    //   confirmText: 'Remove',
    //   isDestructive: true,
    // );

    final confirmed = await _showGlobalBottomSheet(
      context: context,
      title: AppString.geoupProfileString.removeMember,
      subtitle:
          '${AppString.geoupProfileString.areyousureyouwanttoremove} ${member.displayName} ${AppString.geoupProfileString.fromthegroup}?',
      confirmButtonText: AppString.geoupProfileString.remove,
    );

    if (confirmed && widget.groupId != null) {
      final success = await groupProvider.removeGroupMember(
        chatId: widget.groupId!,
        userId: member.userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '${member.displayName} ${AppString.geoupProfileString.removedfromgroup}'
                  : '${AppString.geoupProfileString.failedtoremove} ${member.displayName}',
            ),
            backgroundColor:
                success
                    ? AppColors.appPriSecColor.primaryColor
                    : AppColors.textColor.textErrorColor,
          ),
        );
      }
    }
  }

  void _addMemberToGroup() {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final existingMemberIds =
        groupProvider.members.map((member) => member.userId).toList();

    debugPrint('🔍 Add Member Navigation:');
    debugPrint('  Group ID: ${widget.groupId}');
    debugPrint('  Existing Members Count: ${existingMemberIds.length}');
    debugPrint('  Existing Member IDs: $existingMemberIds');

    Navigator.pushNamed(
      context,
      AppRoutes.contactListScreen,
      arguments: {
        'createGroupMode': false,
        'isForAddMoreMember': true,
        'isAddMemberMode': true,
        'groupId': widget.groupId,
        'existingMemberIds': existingMemberIds,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      resizeToAvoidBottomInset: true,
      // appBar: _buildAppBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBody(),
          if (_isClearingChat) _buildClearChatLoadingOverlay(),
        ],
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
              color: AppColors.bgColor.bg4Color,
              border: Border.all(color: Colors.white, width: 4),
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
            onTap: () => Navigator.pop(context),
            child: customeBackArrowBalck(context, isBackBlack: true),
          ),
        ),
      ],
    );
  }

  /// True only when the group has an actual icon to show (network URL that
  /// isn't the backend "not found" placeholder, or a local file path).
  bool get _hasRealGroupImage {
    final image = _updatedGroupImage ?? widget.groupImage;
    if (image == null || image.isEmpty) return false;
    if (image == kNotFoundProfileImageUrl) return false;
    return image.startsWith('http://') ||
        image.startsWith('https://') ||
        image.startsWith('/') ||
        image.startsWith('file://');
  }

  Widget _buildGroupLetterAvatar({required double radius}) {
    return CommonProfileAvatar(
      imageUrl: null,
      name: _updatedGroupName ?? widget.groupName,
      radius: radius,
      isGroup: true,
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      body: Column(
        children: [
          profileWidget2(
            context,
            isBackArrow: true,
            title: AppString.gropuInfo,
            profileChild: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.bgColor.bg4Color,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.strokeColor.cECECEC),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child:
                    _hasRealGroupImage
                        ? CachedNetworkImage(
                          imageUrl: _updatedGroupImage ?? widget.groupImage!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) {
                            return Center(
                              child: Icon(
                                Icons.person,
                                color: AppColors.bgColor.bgWhite,
                              ),
                            );
                          },
                        )
                        : _buildGroupLetterAvatar(radius: 50),
              ),
            ),
            // image:
            //     (_updatedGroupImage ?? widget.groupImage) != null &&
            //             (_updatedGroupImage ?? widget.groupImage)!.isNotEmpty
            //         ? _updatedGroupImage ?? widget.groupImage!
            //         : null,
          ),

          // chatProfileWidget(
          //   context,
          //   profileChild: Container(
          //     height: 120,
          //     width: 120,
          //     decoration: BoxDecoration(
          //       color: AppColors.bgColor.bgWhite,
          //       borderRadius: BorderRadius.circular(120),
          //       border: Border.all(
          //         color: AppColors.strokeColor.greyColor,
          //         width: 2,
          //       ),
          //     ),
          //     child: Padding(
          //       padding: const EdgeInsets.all(20),
          //       child: SvgPicture.asset(
          //         AppAssets.svgIcons.createGroupImage,
          //         fit: BoxFit.cover,
          //       ),
          //     ),
          //     // Padding(
          //     //   padding: const EdgeInsets.all(12),
          //     //   child: ClipRRect(
          //     //     borderRadius: BorderRadius.circular(120),
          //     //     child: SvgPicture.asset(
          //     //       AppAssets.svgIcons.createGroupImage,
          //     //       fit: BoxFit.cover,
          //     //       width: 120,
          //     //       height: 120,
          //     //     ),
          //     //     // Image.asset(
          //     //     //   AppAssets.defaultUser,
          //     //     //   fit: BoxFit.cover,
          //     //     //   width: 120,
          //     //     //   height: 120,
          //     //     // ),
          //     //   ),
          //     // ),
          //   ),
          // ),
          SizedBox(height: SizeConfig.height(30)),
          Center(child: commonLoading()),
        ],
      ),
    );
  }


  Future<void> _loadGroupAdmin() async {
    final id = widget.groupId;
    if (id == null) {
      if (mounted) setState(() => _adminLoading = false);
      return;
    }
    try {
      final perms = await _adminRepo.permissions(id);
      final isAdmin = perms['isAdmin'] == true;
      final requests = isAdmin ? await _adminRepo.joinRequests(id) : const <Map<String, dynamic>>[];
      Map<String, dynamic>? link;
      if (isAdmin) link = await _adminRepo.inviteLink(id);
      if (!mounted) return;
      setState(() {
        _perms = perms;
        _joinRequests = requests;
        _inviteUrl = link?['url'] as String?;
        _adminLoading = false;
      });
    } catch (e) {
      _logger.e('group admin load failed: $e');
      if (mounted) setState(() => _adminLoading = false);
    }
  }

  Future<void> _togglePermission(String key, bool value) async {
    final id = widget.groupId;
    if (id == null) return;
    setState(() => _perms = {..._perms, key: value});
    try {
      final updated = await _adminRepo.updatePermissions(id, {key: value});
      if (mounted) setState(() => _perms = {..._perms, ...updated});
    } catch (e) {
      if (!mounted) return;
      setState(() => _perms = {..._perms, key: !value});
      snackbarNew(context, msg: 'Could not update the permission');
      _logger.e('permission update failed: $e');
    }
  }

  Future<void> _resetInviteLink() async {
    final id = widget.groupId;
    if (id == null) return;
    try {
      final link = await _adminRepo.resetInviteLink(id);
      if (!mounted) return;
      setState(() => _inviteUrl = link['url'] as String?);
      snackbarNew(context, msg: 'New invite link created');
    } catch (e) {
      _logger.e('invite reset failed: $e');
      if (mounted) snackbarNew(context, msg: 'Could not reset the link');
    }
  }

  Future<void> _decideRequest(String requestId, bool approve) async {
    final id = widget.groupId;
    if (id == null) return;
    try {
      await _adminRepo.decide(id, requestId, approve: approve);
      await _loadGroupAdmin();
    } catch (e) {
      _logger.e('join request decision failed: $e');
      if (mounted) snackbarNew(context, msg: 'Could not update the request');
    }
  }

  Widget _buildGroupAdmin() {
    if (_adminLoading || widget.groupId == null) return const SizedBox.shrink();
    final isAdmin = _perms['isAdmin'] == true;
    if (!isAdmin) return const SizedBox.shrink();

    Widget switchRow(String key, String title, String subtitle) {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: Colors.white,
        activeTrackColor: Fp.violet,
        value: _perms[key] == true,
        onChanged: (v) => _togglePermission(key, v),
        title: Text(title, style: Fp.bodyStrong),
        subtitle: Text(subtitle, style: Fp.caption.copyWith(color: Fp.textMuted)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _horizontalPaddding),
          child: const FpSectionLabel('Group admin'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _horizontalPaddding),
          child: FpSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Permissions', style: Fp.bodyStrong),
                const SizedBox(height: 4),
                Text(
                  'Decide what members can do in this group.',
                  style: Fp.caption.copyWith(color: Fp.textMuted),
                ),
                switchRow('onlyAdminsCanEditInfo', 'Edit group info',
                    'Name, description and icon'),
                switchRow('onlyAdminsCanPost', 'Send messages',
                    'When off, only admins can post'),
                switchRow('onlyAdminsCanAddMembers', 'Add members',
                    'Who can bring new people in'),
                switchRow(
                    'sendHistoryToNewMembers',
                    'Send old messages to new members',
                    'Off: new members start empty and you can send the history yourself'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _horizontalPaddding),
          child: FpSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite link', style: Fp.bodyStrong),
                const SizedBox(height: 6),
                SelectableText(
                  _inviteUrl ?? 'No link yet',
                  style: Fp.caption.copyWith(color: Fp.textMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FpGhostButton(
                        label: 'Copy',
                        expand: true,
                        onPressed: () {
                          final url = _inviteUrl;
                          if (url == null) return;
                          Clipboard.setData(ClipboardData(text: url));
                          snackbarNew(context, msg: 'Invite link copied');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FpGhostButton(
                        label: 'Reset',
                        expand: true,
                        onPressed: _resetInviteLink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Resetting revokes the current link immediately.',
                  style: Fp.caption.copyWith(color: Fp.textFaint),
                ),
              ],
            ),
          ),
        ),
        if (_joinRequests.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _horizontalPaddding),
            child: FpSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Join requests', style: Fp.bodyStrong),
                  const SizedBox(height: 4),
                  Text(
                    '${_joinRequests.length} waiting for approval',
                    style: Fp.caption.copyWith(color: Fp.textMuted),
                  ),
                  const SizedBox(height: 8),
                  for (final r in _joinRequests)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (r['name'] ?? r['userName'] ?? 'Member').toString(),
                            style: Fp.body,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Decline',
                          icon: Icon(Icons.close_rounded, color: Fp.danger),
                          onPressed: () =>
                              _decideRequest(r['requestId'].toString(), false),
                        ),
                        IconButton(
                          tooltip: 'Approve',
                          icon: Icon(Icons.check_rounded, color: Fp.mint),
                          onPressed: () =>
                              _decideRequest(r['requestId'].toString(), true),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      // padding: SizeConfig.getPadding(16),
      child: Consumer<GroupProvider>(
        builder: (context, groupProvider, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              profileWidget(
                context,
                isBackArrow: true,
                title: AppString.gropuInfo,
                image:
                    _hasRealGroupImage
                        ? _updatedGroupImage ?? widget.groupImage!
                        : null,
                // No group icon: show the group's letter avatar (same as chat
                // list / chat app bar) instead of the user's own profile pic.
                placeholder: _buildGroupLetterAvatar(radius: 51),
                actionButton:
                    _canEditGroup(groupProvider)
                        ? _isMember
                            ? InkWell(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: _editGroup,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: SvgPicture.asset(
                                  AppAssets.ibadahGroupIcons.edit,
                                  height: 20,
                                  width: 20,
                                ),
                                // Icon(
                                //   Icons.edit_rounded,
                                //   color: AppColors.black,
                                // ),
                              ),
                            )
                            : null
                        : null,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _horizontalPaddding),
                child: _buildGroupName(groupProvider.members),
              ),
              // _buildGroupHeader(),
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _horizontalPaddding),
                child: rowContainer(),
              ),
              SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _horizontalPaddding),
                child: _buildGroupDescription(),
              ),
              (_updatedGroupDescription ?? widget.groupDescription)?.isEmpty ??
                      false
                  ? SizedBox.shrink()
                  : SizedBox(height: 24),
              _buildGroupAdmin(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _horizontalPaddding),
                child: _buildMediaLinksDocs(_allMedia),
              ),
              SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _horizontalPaddding),
                child: _buildGroupStats(),
              ),
              SizedBox(height: 24),
              (_isMember && _isCurrentUserAdmin(groupProvider))
                  ? Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _horizontalPaddding,
                    ),
                    child: Container(
                      padding: SizeConfig.getPaddingSymmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: AppThemeManage.appTheme.darkGreyColor,
                        borderRadius: BorderRadius.circular(12),

                        boxShadow: getBoxShadow(),
                      ),
                      child: _buildActionItem(
                        icon: Icons.person_add,
                        iconWidget: SvgPicture.asset(
                          AppAssets.ibadahGroupIcons.addMember,
                          height: 23,
                          width: 23,
                        ),
                        title: AppString.addMembers,
                        onTap: _addMemberToGroup,
                      ),
                    ),
                  )
                  : SizedBox.shrink(),
              ((_isMember && _isCurrentUserAdmin(groupProvider)))
                  ? SizedBox(height: 24)
                  : SizedBox.shrink(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _horizontalPaddding),
                child: _buildGroupMembers(),
              ),
              SizedBox(height: 24),
              // _buildActionsList(),
              // SizedBox(height: 32),

              // groupProvider.members.any(
              //       (element) =>
              //           element.userId == int.parse(userID),
              //     )
              (_isMember)
                  ? Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _horizontalPaddding,
                    ),
                    child: _buildReportExit(groupProvider),
                  )
                  : SizedBox.shrink(),
              (_isMember) ? SizedBox(height: 32) : SizedBox.shrink(),
              // if (_isCurrentUserAdmin(groupProvider))
              //   _buildDangerZone(),
            ],
          );
        },
      ),
    );
  }

  BoxDecoration _getDecoration() {
    return BoxDecoration(
      color: AppThemeManage.appTheme.darkGreyColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: getBoxShadow(),
    );
  }

  Widget _buildReportExit(GroupProvider groupProvider) {
    return Container(
      decoration: _getDecoration(),
      child: Column(
        children: [
          SizedBox(height: 7),
          // Clear chat — empties only this member's view of the group's
          // history (`POST /conversations/:id/clear`); the group stays listed.
          _buildListTile(
            title: AppString.homeScreenString.clearChat,
            imagePath: AppAssets.groupProfielIcons.clearchat,
            onTap: _isClearingChat ? () {} : _confirmClearChat,
          ),
          Divider(color: AppThemeManage.appTheme.borderColor),
          _buildListTile(
            title: AppString.exitGroup,
            imagePath: AppAssets.groupProfielIcons.userBock,
            onTap:
                _isDeleting
                    ? () {}
                    : () {
                      showGlobalBottomSheet(
                        context: context,
                        title: AppString.exitGroup,
                        cancelButtonText: AppString.cancel,
                        subtitle:
                            '${AppString.areyousureyouwanttoleave} "${widget.groupName}"? ${AppString.youwillnolongerreceivemessagesfromthisgroup}',
                        confirmButtonText: AppString.exit,
                        isLoading: _isDeleting,
                        onConfirm: () {
                          Navigator.of(context).pop();
                          _performLeaveGroup();
                        },
                      );
                    },
          ),
          // Report group — `POST /report/report-user {chat_id}`.
          if (widget.groupId != null) ...[
            Divider(color: AppThemeManage.appTheme.borderColor),
            _buildListTile(
              title: '${AppString.report} ${widget.groupName}',
              imagePath: AppAssets.chatImage.report,
              onTap: () {
                showReportGroupDialog(
                  context,
                  chatId: widget.groupId!,
                  title: '${AppString.report} ${widget.groupName}',
                );
              },
            ),
          ],
          // _isCurrentUserAdmin(groupProvider)
          //     ? Divider(color: AppColors.strokeColor.cECECEC)
          //     : SizedBox.shrink(),
          // _isCurrentUserAdmin(groupProvider)
          //     ? _buildListTile(
          //       title: _isDeleting ? 'Deleting...' : 'Delete Group',
          //       imagePath: AppAssets.settingsIcosn.profiledelete,

          //       onTap:
          //           _isDeleting
          //               ? () {}
          //               : () {
          //                 showGlobalBottomSheet(
          //                   context: context,
          //                   title: 'Delete Group',
          //                   subtitle:
          //                       'Are you sure you want to delete this group?',
          //                   confirmButtonText: 'Delete',
          //                   isLoading: _isDeleting,
          //                   onConfirm: () {
          //                     Navigator.of(context).pop();
          //                     _performDeleteGroup();
          //                   },
          //                 );
          //               },
          //     )
          //     : SizedBox.shrink(),
          SizedBox(height: 7),
        ],
      ),
    );
  }

  void _confirmClearChat() {
    if (_isClearingChat || widget.groupId == null) return;

    // ✅ DEMO MODE: same restriction as deleting a chat.
    if (isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppString.pleaseUseRealAccountToTest,
          ),
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

  /// Clears this member's view of the history; ChatProvider empties the open
  /// thread (if it's this group), its cache and the chat-list preview, so the
  /// chat screen underneath is already empty when the user navigates back.
  Future<void> _performClearChat() async {
    if (!mounted || widget.groupId == null) return;
    setState(() => _isClearingChat = true);

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final success = await chatProvider.clearChat(chatId: widget.groupId!);

    if (!mounted) return;
    setState(() {
      _isClearingChat = false;
      // The cleared messages' media is gone from this member's view too.
      if (success) {
        _images = [];
        _videos = [];
        _documents = [];
        _links = [];
        _sections = [];
      }
    });

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

  Widget _buildListTile({
    required String title,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SvgPicture.asset(
                imagePath,
                height: 19,
                width: 19,
                colorFilter: ColorFilter.mode(
                  AppColors.textColor.textErrorColor1,
                  BlendMode.srcIn,
                ),
              ),
            ),

            Text(
              title,
              style: AppTypography.innerText12Mediu(context).copyWith(
                color: AppColors.textColor.textErrorColor1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
    // ListTile(
    //   contentPadding: EdgeInsets.zero,
    //   minVerticalPadding: 0,
    //   leading:
    //   title: Text(
    //     title,
    //     style: AppTypography.innerText12Mediu(context).copyWith(
    //       color: AppColors.textColor.textErrorColor1,
    //       fontWeight: FontWeight.w600,
    //     ),
    //   ),
    // );
  }

  Widget _buildMediaLinksDocs(List<media.Records> mediaList) {
    return container(
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
                  'chatId': widget.groupId,
                  'chatName': widget.groupName,
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
                      Text(
                        (
                            // _allMedia.length +
                            _images.length +
                                _videos.length +
                                _documents.length +
                                _links.length)
                            .toString(),
                        style: AppTypography.innerText12Mediu(context).copyWith(
                          color: AppThemeManage.appTheme.chatMediaText,
                        ),
                      ), // media count
                      SizedBox(width: SizeConfig.width(3)),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: AppThemeManage.appTheme.chatMediaText,
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
                                    color: AppThemeManage.appTheme.borderColor,
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

  Widget rowContainer() {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        boxShadow: getBoxShadow(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // audio call method
            rowAudioVideoSearchContainer(
              context: context,
              onTap: () {
                if (_isMember) {
                  _makeCall(context, CallType.audio);
                } else {
                  snackbarNew(
                    context,
                    msg:
                        AppString
                            .geoupProfileString
                            .youarenotamemberofthisgroup,
                  );
                }
                // Navigator.of(context).push(
                //   MaterialPageRoute(
                //     builder:
                //         (_) => CallScreen(
                //           chatId: widget.chatId!,
                //           chatName: widget.chatName!,
                //           callType: CallType.audio,
                //           isIncoming: false,
                //         ),
                //     fullscreenDialog: true,
                //   ),
                // );
              },
              title: AppString.geoupProfileString.audio,
              svgImage: AppAssets.bottomNavIcons.call1,
            ),
            SizedBox(width: SizeConfig.width(5)),
            // video call method
            rowAudioVideoSearchContainer(
              context: context,
              onTap: () {
                if (_isMember) {
                  _makeCall(context, CallType.video);
                } else {
                  snackbarNew(
                    context,
                    msg:
                        AppString
                            .geoupProfileString
                            .youarenotamemberofthisgroup,
                  );
                }
                // Navigator.of(context).push(
                //   MaterialPageRoute(
                //     builder:
                //         (_) => CallScreen(
                //           chatId: widget.chatId!,
                //           chatName: widget.chatName!,
                //           callType: CallType.video,
                //           isIncoming: false,
                //         ),
                //     fullscreenDialog: true,
                //   ),
                // );
              },
              title: AppString.geoupProfileString.video,
              svgImage: AppAssets.chatMsgTypeIcon.videoMsg,
            ),
            SizedBox(width: SizeConfig.width(5)),
            // search call method
            rowAudioVideoSearchContainer(
              context: context,
              onTap: () {
                Navigator.pop(context, "search");
              },
              title: AppString.geoupProfileString.search,
              svgImage: AppAssets.homeIcons.search,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupName(List<GroupMember> members) {
    // Filter out deleted members
    final activeMembers = members.where((member) => !member.isDeleted).toList();

    // Sort members: Group Owner (admin) at top, then other members
    activeMembers.sort((a, b) {
      if (a.isAdmin && !b.isAdmin) return -1;
      if (!a.isAdmin && b.isAdmin) return 1;
      return 0;
    });

    return Column(
      children: [
        SizedBox(height: 25),
        Align(
          alignment: Alignment.center,
          child: Text(
            _updatedGroupName ?? widget.groupName,
            style: AppTypography.h2(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),

        // SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppString.geoupProfileString.group,
              style: AppTypography.innerText12Mediu(
                context,
              ).copyWith(color: AppColors.textColor.textDarkGray),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Container(
                height: 4,
                width: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.textColor.textDarkGray,
                ),
              ),
            ),
            Text(
              '${activeMembers.length} ${AppString.geoupProfileString.member}',
              style: AppTypography.innerText12Mediu(
                context,
              ).copyWith(color: AppColors.textColor.textDarkGray),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDefaultGroupIcon() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.8),
            AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.group, size: 48, color: Colors.white),
    );
  }

  List<BoxShadow> getBoxShadow() {
    return [
      BoxShadow(
        color: AppColors.black.withValues(alpha: 0.07),
        blurRadius: 10,
        spreadRadius: 0,
        offset: Offset(0, 0),
      ),
    ];
  }

  Widget _buildGroupDescription() {
    final description = _updatedGroupDescription ?? widget.groupDescription;

    if (description == null || description.trim().isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: SizeConfig.getPadding(16),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: getBoxShadow(),
        // border: Border.all(
        //   color: AppColors.strokeColor.greyColor.withValues(alpha: 0.3),
        // ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon(
              //   Icons.info_outline,
              //   size: 20,
              //   color: AppColors.appPriSecColor.primaryColor,
              // ),
              // SizedBox(width: 8),
              Text(
                AppString.description,
                style: AppTypography.h5(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () {
                if (description.length > 100) {
                  setState(() {
                    _showFullDescription = !_showFullDescription;
                  });
                }
              },
              child: Text(
                _showFullDescription || description.length <= 100
                    ? description
                    : '${description.substring(0, 100)}...',
                style: AppTypography.innerText12Mediu(context).copyWith(
                  color: AppColors.textColor.textDarkGray,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (description.length > 100)
            Padding(
              padding: SizeConfig.getPaddingOnly(top: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showFullDescription = !_showFullDescription;
                  });
                },
                child: Text(
                  _showFullDescription ? 'Show less' : 'Show more',
                  style: AppTypography.buttonText(context).copyWith(
                    color: AppColors.appPriSecColor.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupMembers() {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        if (groupProvider.isMembersLoading) {
          return _buildMembersLoadingState();
        }

        if (groupProvider.membersError != null) {
          return _buildMembersErrorState(groupProvider.membersError!);
        }

        final members = groupProvider.members;
        if (members.isEmpty) {
          return _buildNoMembersState();
        }

        return _buildMembersContent(members, groupProvider);
      },
    );
  }

  Widget _buildMembersLoadingState() {
    return Container(
      padding: SizeConfig.getPadding(16),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SizedBox(height: SizeConfig.height(2)),
          Row(
            children: [
              Icon(
                Icons.people,
                size: 20,
                color: AppColors.appPriSecColor.primaryColor,
              ),
              SizedBox(width: 8),
              Text(
                AppString.groupMembers,
                style: AppTypography.h5(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                commonLoading(),
                SizedBox(height: 8),
                Text(
                  '${AppString.loadingMembers}...',
                  style: AppTypography.captionText(
                    context,
                  ).copyWith(color: AppColors.textColor.textGreyColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersErrorState(String error) {
    return Container(
      padding: SizeConfig.getPadding(16),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.people,
                size: 20,
                color: AppColors.appPriSecColor.primaryColor,
              ),
              SizedBox(width: 8),
              Text(
                AppString.groupMembers,
                style: AppTypography.h5(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 32,
                  color: AppColors.textColor.textErrorColor,
                ),
                SizedBox(height: 8),
                Text(
                  AppString.failedtoloadMembers,
                  style: AppTypography.captionText(
                    context,
                  ).copyWith(color: AppColors.textColor.textErrorColor),
                ),
                SizedBox(height: 8),
                TextButton(
                  onPressed: _loadGroupMembers,
                  child: Text(
                    AppString.retry,
                    style: AppTypography.buttonText(
                      context,
                    ).copyWith(color: AppColors.appPriSecColor.primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMembersState() {
    return Container(
      padding: SizeConfig.getPadding(16),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.people,
                size: 20,
                color: AppColors.appPriSecColor.primaryColor,
              ),
              SizedBox(width: 8),
              Text(
                AppString.gropuInfo,
                style: AppTypography.h5(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 20),
          Center(
            child: Text(
              AppString.noMembersFound,
              style: AppTypography.captionText(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersContent(
    List<GroupMember> members,
    GroupProvider groupProvider,
  ) {
    // Update the group members map for online status checking
    _updateGroupMembersMap(members);

    // Filter out deleted members
    final activeMembers = members.where((member) => !member.isDeleted).toList();

    // Sort members: Group Owner (admin) at top, then other members
    // activeMembers.sort((a, b) {
    //   if (a.isAdmin && !b.isAdmin) return -1;
    //   if (!a.isAdmin && b.isAdmin) return 1;
    //   return 0;
    // });
    final isCurrentUserAdmin = _isCurrentUserAdmin(groupProvider);

    activeMembers.sort((a, b) {
      final aIsCurrentUser = _isCurrentUser(a.userId);
      final bIsCurrentUser = _isCurrentUser(b.userId);

      // Case 1: If I am admin → I come first
      if (isCurrentUserAdmin) {
        if (aIsCurrentUser && !bIsCurrentUser) return -1;
        if (!aIsCurrentUser && bIsCurrentUser) return 1;
        if (a.isAdmin && !b.isAdmin) return -1;
        if (!a.isAdmin && b.isAdmin) return 1;
        return 0;
      }
      // Case 2: If I am not admin → Admins first, then me
      else {
        if (a.isAdmin && !b.isAdmin) return -1;
        if (!a.isAdmin && b.isAdmin) return 1;
        if (aIsCurrentUser && !bIsCurrentUser) return -1;
        if (!aIsCurrentUser && bIsCurrentUser) return 1;
        return 0;
      }
    });

    final displayMembers =
        _showAllMembers ? activeMembers : activeMembers.take(5).toList();
    final hasMoreMembers = activeMembers.length > 5;

    return Container(
      padding: SizeConfig.getPadding(16),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: getBoxShadow(),
        // border: Border.all(
        //   color: AppColors.strokeColor.greyColor.withValues(alpha: 0.3),
        // ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${activeMembers.length} ${AppString.groupMembers}',
                style: AppTypography.h5(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...displayMembers.map(
            (member) => _buildMemberItem(member, groupProvider),
          ),
          if (hasMoreMembers) ...[
            SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _showAllMembers = !_showAllMembers;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showAllMembers
                          ? 'Show Less'
                          : 'Show All (${activeMembers.length - 5} more)',
                      style: AppTypography.buttonText(
                        context,
                      ).copyWith(color: AppColors.appPriSecColor.primaryColor),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      _showAllMembers ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppColors.appPriSecColor.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberItem(GroupMember member, GroupProvider groupProvider) {
    final isCurrentUser = _isCurrentUser(member.userId);
    final isAdmin = member.isAdmin;
    final profilePic = member.profilePic;

    return Consumer2<ChatProvider, ProjectConfigProvider>(
      builder: (context, chatProvider, configProvider, child) {
        // Use ContactNameService for consistent naming like in chat list —
        // saved contact name always wins, business users included.
        final displayName = ContactNameService.instance.getDisplayName(
          userId: member.userId,
          userFullName: member.user?.fullName,
          userName: member.user?.userName,
          userEmail: member.user?.email,
          configProvider: configProvider,
        );
        // Deleted accounts get the placeholder icon, never a picture.
        final isDeletedAccount = ContactNameService.instance.isUserDeleted(
          member.userId,
        );
        final isOnline = _isUserOnlineFromChatProvider(
          member.userId,
          chatProvider,
        );

        // Check if contact flow is enabled and mobile number is available
        final config = configProvider.configData;
        final shouldShowMobileNumber =
            config?.contactFlow == true && member.mobileNum.isNotEmpty;

        return GestureDetector(
          onTap: () async {
            if (isCurrentUser) {
              // nothing
            } else {
              // ── 1. Check lock FIRST — before any navigation ──────────────────
              if (member.isLocked == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(AppString.thisUserHasLockedTheirChat),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
                return; // stop here — no navigation
              }

              // ── 2. Block status ───────────────────────────────────────────────
              bool isBlocked = false;
              try {
                isBlocked = chatProvider.getInstantBlockStatusByUserId(
                  member.userId,
                );
              } catch (e) {
                debugPrint('NavigationHelper: Error getting block status: $e');
              }

              chatProvider.resetAll();

              await Navigator.pushNamed(
                context,
                AppRoutes.universalChat,
                arguments: {
                  'chatId': 0,
                  'userId': member.userId,
                  'chatName': ContactNameService.instance.resolveName(
                    userId: member.userId,
                    fullName: member.user?.fullName,
                    userName: member.user?.userName,
                    email: member.user?.email,
                    fallback: 'unknown',
                  ),
                  'profilePic': member.user?.profilePic ?? '',
                  'isGroupChat': false,
                  'blockFlag': isBlocked,
                },
              ).then((_) async {});

              chatProvider.setIsDisposedOfChat(false);
              if (!mounted) return;
              chatProvider.initOfUniversal(
                context: context,
                chatId: widget.groupId ?? 0,
                userId: 0,
                isGroupChat: true,
              );
            }
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.appPriSecColor.secondaryColor
                          .withValues(alpha: 0.1),
                      backgroundImage:
                          profilePic.isNotEmpty && !isDeletedAccount
                              ? NetworkImage(profilePic)
                              : null,
                      child:
                          isDeletedAccount
                              ? Icon(
                                Icons.person,
                                color: AppColors.appPriSecColor.primaryColor,
                              )
                              : profilePic.isEmpty
                              ? Text(
                                _getInitials(displayName),
                                style: AppTypography.buttonText(
                                  context,
                                ).copyWith(
                                  color: AppColors.appPriSecColor.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                              : null,
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.appPriSecColor.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: UserNameWithBadge(
                                        userId: member.userId,
                                        badgeSize: 15,
                                        name:
                                            isCurrentUser
                                                ? '$displayName (You)'
                                                : displayName,
                                        style: AppTypography.mediumText(
                                          context,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    member.isLocked == true
                                        ? Icon(
                                          Icons.lock_rounded,
                                          color:
                                              AppThemeManage
                                                  .appTheme
                                                  .textGreyWhite,
                                          size: 12,
                                        )
                                        : SizedBox.shrink(),
                                  ],
                                ),
                                if (shouldShowMobileNumber)
                                  Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Text(
                                      '${member.countryCode} ${member.mobileNum}',
                                      style: AppTypography.captionText(
                                        context,
                                      ).copyWith(
                                        color:
                                            AppColors.textColor.textGreyColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isAdmin)
                            Container(
                              padding: SizeConfig.getPaddingSymmetric(
                                horizontal: 12,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppThemeManage.appTheme.chatBuuble,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                AppString.admin,
                                style: AppTypography.captionText(
                                  context,
                                ).copyWith(
                                  color: AppColors.textColor.textBlackColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 2),

                      if (isOnline)
                        Text(
                          "Online",
                          // _getMemberStatus(member, isOnline),
                          style: AppTypography.captionText(context).copyWith(
                            color:
                                isOnline
                                    ? AppColors.appPriSecColor.primaryColor
                                    : AppColors.textColor.textGreyColor,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isCurrentUserAdmin(groupProvider) && !isCurrentUser)
                  PopupMenuButton<String>(
                    color: AppThemeManage.appTheme.scaffoldBackColor,
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppThemeManage.appTheme.textColor,
                    ),
                    onSelected:
                        (value) =>
                            _handleMemberAction(value, member, groupProvider),
                    // ❌ Make/Remove Admin removed from this menu: NEW has
                    // no promote/demote-admin endpoint at all (§5.3/§5.7 of
                    // the migration guide) — role is fixed at group
                    // creation. Hiding the action rather than leaving a
                    // button that would silently fail (GroupProvider's
                    // makeGroupAdmin/removeGroupAdmin now refuse locally
                    // instead of calling a nonexistent endpoint).
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            value: 'remove_member',
                            child: Text(
                              AppString.remove,
                              style: TextStyle(
                                color: AppColors.textColor.textErrorColor,
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'send_history',
                            child: Text(
                              'Send old messages',
                              style: TextStyle(
                                color: AppColors.textColor.textBlackColor,
                              ),
                            ),
                          ),
                        ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getInitials(String name) => avatarInitials(name);

  // ignore: unused_element
  String _getMemberStatus(GroupMember member, bool isOnline) {
    if (isOnline) {
      return 'Online';
    }

    if (member.lastSeen != null && member.lastSeen!.isNotEmpty) {
      try {
        final lastSeenTime = DateTime.parse(member.lastSeen!);
        final now = DateTime.now();
        final difference = now.difference(lastSeenTime);

        if (difference.inMinutes < 1) {
          return 'Last seen just now';
        } else if (difference.inHours < 1) {
          return 'Last seen ${difference.inMinutes}m ago';
        } else if (difference.inDays < 1) {
          return 'Last seen ${difference.inHours}h ago';
        } else {
          return 'Last seen ${difference.inDays}d ago';
        }
      } catch (e) {
        return 'Last seen recently';
      }
    }

    return 'Joined ${member.joinedDate}';
  }

  void _handleMemberAction(
    String action,
    GroupMember member,
    GroupProvider groupProvider,
  ) {
    switch (action) {
      case 'make_admin':
        _makeAdmin(member, groupProvider);
        break;
      case 'remove_admin':
        _removeAdmin(member, groupProvider);
        break;
      case 'remove_member':
        _removeMember(member, groupProvider);
        break;
      case 'send_history':
        _sendHistory(member);
        break;
    }
  }

  /// WhatsApp "send old messages": lets this member see the group history
  /// from before they joined (works regardless of the group setting).
  Future<void> _sendHistory(GroupMember member) async {
    final id = widget.groupId;
    if (id == null) return;
    try {
      await _adminRepo.sendHistory(id, member.userId);
      if (mounted) {
        snackbarNew(
          context,
          msg: 'Old messages sent to ${member.displayName}',
        );
      }
    } catch (e) {
      _logger.e('send history failed: $e');
      if (mounted) snackbarNew(context, msg: 'Could not send the history');
    }
  }

  void _removeAdmin(GroupMember member, GroupProvider groupProvider) async {
    // final confirmed = await _showConfirmationDialog(
    //   title: 'Remove Admin',
    //   content:
    //       'Are you sure you want to remove admin rights from ${member.displayName}?',
    //   confirmText: 'Remove Admin',
    // );

    final confirmed = await _showGlobalBottomSheet(
      context: context,
      title: AppString.geoupProfileString.removeAdmin,
      subtitle:
          '${AppString.geoupProfileString.removeRights} ${member.displayName}?',
      confirmButtonText: 'Remove ',
    );

    if (confirmed && widget.groupId != null) {
      //this api is work for both remove and add
      final success = await groupProvider.makeGroupAdmin(
        chatId: widget.groupId!,
        userId: member.userId,
        isRemove: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '${member.displayName} ${AppString.geoupProfileString.isNowAnRemoveAsAdmin}'
                  : '${AppString.geoupProfileString.failedtoremove} ${member.displayName} ${AppString.geoupProfileString.anadmin}',
            ),
            backgroundColor:
                success
                    ? AppColors.appPriSecColor.primaryColor
                    : AppColors.textColor.textErrorColor,
          ),
        );
      }
    }
  }

  // ignore: unused_element
  Future<bool> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                title,
                style: AppTypography.h4(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      isDestructive ? AppColors.textColor.textErrorColor : null,
                ),
              ),
              content: Text(content, style: AppTypography.mediumText(context)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    AppString.cancel,
                    style: AppTypography.buttonText(
                      context,
                    ).copyWith(color: AppColors.textColor.textGreyColor),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    confirmText,
                    style: AppTypography.buttonText(context).copyWith(
                      color:
                          isDestructive
                              ? AppColors.textColor.textErrorColor
                              : AppColors.appPriSecColor.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // 2. Build Group Stats Method
  Widget _buildGroupStats() {
    return Consumer2<GroupProvider, ChatProvider>(
      builder: (context, groupProvider, chatProvider, child) {
        final actualMemberCount =
            groupProvider.members.isNotEmpty
                ? groupProvider.members.length
                : (groupProvider.memberCount > 0
                    ? groupProvider.memberCount
                    : widget.memberCount);
        final adminCount = groupProvider.adminCount;

        // Use ChatProvider to get accurate online count
        final onlineCount = _getOnlineGroupMembersCount(chatProvider);

        return Container(
          padding: SizeConfig.getPadding(16),
          decoration: BoxDecoration(
            color: AppThemeManage.appTheme.darkGreyColor,
            borderRadius: BorderRadius.circular(12),
            // border: Border.all(
            //   color: AppColors.strokeColor.greyColor.withValues(alpha: 0.3),
            // ),
            boxShadow: getBoxShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppString.groupStatistics,
                style: AppTypography.h5(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    imagePath: AppAssets.ibadahGroupIcons.groupMember,
                    label: AppString.members,
                    value: '$actualMemberCount',
                  ),
                  _buildStatItem(
                    imagePath: AppAssets.ibadahGroupIcons.groupAdmin,
                    label: AppString.admins,
                    value: '$adminCount',
                  ),
                  _buildStatItem(
                    imagePath: AppAssets.ibadahGroupIcons.groupAdmin,
                    label: AppString.onlineStatus,
                    isForOnline: true,
                    value: '$onlineCount',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method for _buildGroupStats
  Widget _buildStatItem({
    // required IconData icon,
    required String imagePath,
    required String label,
    required String value,
    bool isForOnline = false,
    Color? color,
  }) {
    return Column(
      children: [
        Container(
          padding: SizeConfig.getPadding(12),
          decoration: BoxDecoration(
            color: (color ?? AppThemeManage.appTheme.appSndColor),
            shape: BoxShape.circle,
          ),
          child:
              isForOnline
                  ? Container(
                    height: 21,
                    width: 21,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.verifiedColor.c00C32B,
                    ),
                  )
                  : Image.asset(imagePath, height: 24, width: 24),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: AppTypography.h5(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.captionText(
            context,
          ).copyWith(color: AppColors.textColor.textGreyColor),
        ),
      ],
    );
  }

  // 3. Build Actions List Method
  // ignore: unused_element
  Widget _buildActionsList() {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.strokeColor.greyColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              if (_isCurrentUserAdmin(groupProvider)) ...[
                _buildActionItem(
                  icon: Icons.person_add,
                  title: AppString.addMembers,
                  onTap: _addMemberToGroup,
                ),
                _buildDivider(),
              ],
              // _buildActionItem(
              //   icon: Icons.notifications,
              //   title: 'Notifications',
              //   subtitle: 'Manage group notifications',
              //   onTap: _manageNotifications,
              // ),
              _buildDivider(),
              _buildActionItem(
                icon: Icons.photo_library,
                title: AppString.mediaFiles,
                onTap: _viewMedia,
              ),
              _buildDivider(),
              _buildActionItem(
                icon: Icons.search,
                title: AppString.searchMessages,
                onTap: _searchMessages,
              ),
              if (!_isCurrentUserAdmin(groupProvider)) ...[
                _buildDivider(),
                _buildActionItem(
                  icon: Icons.exit_to_app,
                  title: AppString.leaveGroup,
                  onTap: _leaveGroup,
                  isDestructive: true,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Helper method for _buildActionsList
  Widget _buildActionItem({
    required IconData icon,
    required String title,
    // required String subtitle,
    required VoidCallback onTap,
    Widget? iconWidget,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: SizeConfig.getPadding(10),
        decoration: BoxDecoration(
          color:
              isDestructive
                  ? AppColors.textColor.textErrorColor.withValues(alpha: 0.5)
                  : AppThemeManage.appTheme.appSndColor,
          shape: BoxShape.circle,
        ),
        child:
            iconWidget ??
            Icon(
              icon,
              size: 20,
              color:
                  isDestructive
                      ? AppColors.textColor.textErrorColor
                      : AppColors.appPriSecColor.primaryColor,
            ),
      ),
      title: Text(
        title,
        style: AppTypography.mediumText(context).copyWith(
          fontWeight: FontWeight.w600,
          color:
              isDestructive
                  ? AppColors.textColor.textErrorColor
                  : AppThemeManage.appTheme.textColor,
        ),
      ),
      onTap: onTap,
    );
  }

  // Helper method for dividers
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: AppColors.strokeColor.greyColor.withValues(alpha: 0.3),
      indent: 68,
    );
  }

  // 5. Edit Group Method (onPressed: _editGroup)
  void _editGroup() {
    // ✅ DEMO MODE: Block edit group action for demo accounts
    if (isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppString.demoAccountsCannotEditGroupInformation,
          ),
          backgroundColor: AppColors.textColor.textErrorColor,
        ),
      );
      return;
    }

    // bottomSheetGobalWithoutTitle(
    //   context,
    //   borderRadius: BorderRadius.circular(30),
    //   bottomsheetHeight: SizeConfig.sizedBoxHeight(525),
    //   child: _buildEditGroupBottomSheet(),
    // );
    showBottomSheetGobal(
      context,
      bottomsheetHeight: MediaQuery.sizeOf(context).height * 0.67,
      borderRadius: BorderRadius.circular(30),
      title: AppString.editGroup,
      child: _buildEditGroupBottomSheet(),
    );
    // showModalBottomSheet(
    //   context: context,
    //   isScrollControlled: true,
    //   backgroundColor: Colors.transparent,
    //   builder: (context) => _buildEditGroupBottomSheet(),
    // );
  }

  Widget _buildEditGroupBottomSheet() {
    final nameController = TextEditingController(
      text: _updatedGroupName ?? widget.groupName,
    );
    final descController = TextEditingController(
      text: _updatedGroupDescription ?? widget.groupDescription ?? '',
    );
    const int maxGroupNameLength = 30;
    const int maxGroupDescLength = 120;
    File? selectedImageFile;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16,
            // bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group Image
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.appPriSecColor.secondaryColor
                              .withValues(alpha: 0.1),
                          border: Border.all(
                            color: AppColors.appPriSecColor.primaryColor
                                .withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child:
                              selectedImageFile != null
                                  ? Image.file(
                                    selectedImageFile!,
                                    fit: BoxFit.cover,
                                  )
                                  : (_updatedGroupImage ?? widget.groupImage) !=
                                          null &&
                                      (_updatedGroupImage ?? widget.groupImage)!
                                          .isNotEmpty
                                  ? Image.network(
                                    _updatedGroupImage ?? widget.groupImage!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildDefaultGroupIcon();
                                    },
                                  )
                                  : _buildDefaultGroupIcon(),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap:
                              () => _selectGroupImage(
                                setModalState,
                                selectedImageFile,
                                (file) {
                                  setModalState(() {
                                    selectedImageFile = file;
                                  });
                                },
                              ),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.appPriSecColor.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppThemeManage.appTheme.darkGreyColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: AppThemeManage.appTheme.scaffoldBackColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // Group Name
                Text(
                  AppString.groupName,
                  style: AppTypography.h5(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.appPriSecColor.primaryColor,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  maxLength: maxGroupNameLength,
                  // Same rule as the create-group screen: a group name carries no
                  // whitespace at all - leading, trailing or between words.
                  // `deny` also strips spaces out of pasted text.
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  style: AppTypography.innerText14(context),
                  decoration: InputDecoration(
                    hintText: AppString.enterGroupName,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.appPriSecColor.primaryColor,
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppThemeManage.appTheme.borderColor,
                        width: 2,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppThemeManage.appTheme.borderColor,
                        width: 2,
                      ),
                    ),
                    counterText: '',
                    suffixIcon: Padding(
                      padding: EdgeInsets.only(right: 12, top: 12),
                      child: Text(
                        '${nameController.text.length}/$maxGroupNameLength',
                        style: AppTypography.captionText(context).copyWith(
                          color:
                              nameController.text.length >= maxGroupNameLength
                                  ? AppColors.textColor.textErrorColor
                                  : AppColors.textColor.textGreyColor,
                        ),
                      ),
                    ),
                    suffixIconConstraints: BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                  ),
                  onChanged: (value) {
                    setModalState(() {});
                  },
                ),
                SizedBox(height: 16),
                // Group Description
                Text(
                  AppString.groupDescription,
                  style: AppTypography.h5(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.appPriSecColor.primaryColor,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: descController,
                  maxLength: maxGroupDescLength,
                  maxLines: 3,
                  style: AppTypography.innerText14(context),
                  decoration: InputDecoration(
                    hintText: AppString.enterGroupDescription,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.appPriSecColor.primaryColor,
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppThemeManage.appTheme.borderColor,
                        width: 2,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppThemeManage.appTheme.borderColor,
                        width: 2,
                      ),
                    ),
                    counterText: '',
                    suffixIcon: Padding(
                      padding: EdgeInsets.only(right: 12, top: 12),
                      child: Text(
                        '${descController.text.length}/$maxGroupDescLength',
                        style: AppTypography.captionText(context).copyWith(
                          color:
                              descController.text.length >= maxGroupDescLength
                                  ? AppColors.textColor.textErrorColor
                                  : AppColors.textColor.textGreyColor,
                        ),
                      ),
                    ),
                    suffixIconConstraints: BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                  ),
                  onChanged: (value) {
                    setModalState(() {});
                  },
                ),
                SizedBox(height: 24),
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        nameController.text.trim().isEmpty || _isDeleting
                            ? null
                            : () => _handleUpdateGroup(
                              nameController.text.trim(),
                              descController.text.trim(),
                              setModalState,
                              selectedImageFile,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.appPriSecColor.primaryColor,
                      foregroundColor: Colors.white,
                      padding: SizeConfig.getPaddingSymmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isDeleting
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  '${AppString.updating}...',
                                  style: AppTypography.buttonText(
                                    context,
                                  ).copyWith(
                                    color: AppColors.textColor.textBlackColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                            : Text(
                              AppString.save,
                              style: AppTypography.buttonText(context).copyWith(
                                color: AppColors.textColor.textBlackColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectGroupImage(
    StateSetter setModalState,
    File? currentFile,
    Function(File?) onImageSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: SizeConfig.getPadding(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  AppString.selectGroupImage,
                  style: AppTypography.h4(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      svgImagePath: AppAssets.svgIcons.camera,
                      label: AppString.settingStrigs.camera,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromCamera(setModalState, onImageSelected);
                      },
                    ),
                    _buildImageSourceOption(
                      svgImagePath: AppAssets.svgIcons.gellery,
                      label: AppString.settingStrigs.gellery,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromGallery(setModalState, onImageSelected);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildImageSourceOption({
    // required IconData icon,
    required String svgImagePath,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: SizeConfig.getPadding(20),
        // decoration: BoxDecoration(
        //   color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.05),
        //   borderRadius: BorderRadius.circular(12),
        //   border: Border.all(
        //     color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.2),
        //   ),
        // ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,

                gradient: AppColors.gradientColor.gradientColor.withOpacity(
                  0.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SvgPicture.asset(svgImagePath, height: 23, width: 23),
              ),
            ),
            // Icon(icon, size: 32, color: AppColors.black),
            SizedBox(height: 10),
            Text(
              label,
              style: AppTypography.mediumText(context).copyWith(
                // color: AppColors.appPriSecColor.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera(
    StateSetter setModalState,
    Function(File?) onImageSelected,
  ) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        onImageSelected(imageFile);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppString.photoCapturedSuccessfully),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppString.errorAccessingCamera}: $e'),
          backgroundColor: AppColors.textColor.textErrorColor,
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery(
    StateSetter setModalState,
    Function(File?) onImageSelected,
  ) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        onImageSelected(imageFile);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppString.imageSelectedSuccessfully),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppString.errorAccessingGallery}: $e'),
          backgroundColor: AppColors.textColor.textErrorColor,
        ),
      );
    }
  }

  Future<void> _handleUpdateGroup(
    String groupName,
    String groupDescription,
    StateSetter setModalState,
    File? selectedImageFile,
  ) async {
    if (widget.groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppString.errorGroupIDNotFound),
          backgroundColor: AppColors.textColor.textErrorColor,
        ),
      );
      return;
    }

    try {
      // Show loading state
      setModalState(() {
        _isDeleting = true; // Reuse loading state
      });
      debugPrint("Selected Image File $selectedImageFile");

      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      final response = await groupProvider.updateGroup(
        chatId: widget.groupId!,
        groupName: groupName,
        groupDescription: groupDescription,
        pictureType: selectedImageFile != null ? 'group_icon' : null,
        groupIcon: selectedImageFile,
      );

      if (mounted) {
        setModalState(() {
          _isDeleting = false;
        });

        if (response != null && response['status'] == true) {
          // Update local state with values from server response
          final serverData = response['data'] as Map<String, dynamic>?;
          setState(() {
            _updatedGroupName = serverData?['group_name'] ?? groupName;
            _updatedGroupDescription =
                serverData?['group_description'] ?? groupDescription;
            if (serverData?['group_icon'] != null &&
                serverData!['group_icon'].toString().isNotEmpty) {
              _updatedGroupImage = serverData['group_icon'];
            }
          });

          // Refresh chat list to update group name in chat list
          final chatProvider = Provider.of<ChatProvider>(
            context,
            listen: false,
          );
          await chatProvider.refreshChatList();

          if (!mounted) return;
          Navigator.pop(context);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppString.groupUpdatedSuccessfully),
              backgroundColor: AppColors.appPriSecColor.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppString.failedToUpdateGroup),
              backgroundColor: AppColors.textColor.textErrorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setModalState(() {
          _isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppString.errorUpdatingGroup}: $e'),
            backgroundColor: AppColors.textColor.textErrorColor,
          ),
        );
      }
    }
  }

  // ignore: unused_element
  void _manageNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: SizeConfig.getPadding(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  AppString.notificationSettings,
                  style: AppTypography.h4(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 20),
                _buildNotificationOption('All Messages', true),
                _buildNotificationOption('Mentions Only', false),
                _buildNotificationOption('Muted', false),
                SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Future<bool> _showGlobalBottomSheet({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String confirmButtonText,
    String? cancelButtonText,
    bool isLoading = false,
  }) async {
    final result = await bottomSheetGobalWithoutTitle(
      context,
      bottomsheetHeight: SizeConfig.height(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.height(3)),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
            child: Text(
              title,
              style: AppTypography.captionText(context).copyWith(
                fontSize: SizeConfig.getFontSize(15),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: SizeConfig.height(2)),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
            child: Text(
              subtitle,
              style: AppTypography.captionText(context).copyWith(
                color: AppColors.textColor.textGreyColor,
                fontSize: SizeConfig.getFontSize(13),
              ),
            ),
          ),
          SizedBox(height: SizeConfig.height(4)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: customBorderBtn(
                  context,
                  onTap: () => Navigator.pop(context, false), // return false
                  title: cancelButtonText ?? AppString.cancel,
                ),
              ),
              isLoading
                  ? SizedBox(
                    height: SizeConfig.sizedBoxHeight(35),
                    width: SizeConfig.sizedBoxWidth(35),
                    child: commonLoading(),
                  )
                  : SizedBox(
                    height: SizeConfig.height(5),
                    width: SizeConfig.width(35),
                    child: customBtn2(
                      context,
                      onTap: () => Navigator.pop(context, true), // return true
                      child: Text(
                        confirmButtonText,
                        style: AppTypography.h5(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: ThemeColorPalette.getTextColor(
                            AppColors.appPriSecColor.primaryColor,
                          ), // AppColors.textColor.textBlackColor,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );

    return result ?? false; // default to false if closed without action
  }

  // Helper method for notification options
  Widget _buildNotificationOption(String title, bool isSelected) {
    return ListTile(
      title: Text(title, style: AppTypography.mediumText(context)),
      trailing: Radio<bool>(
        value: true,
        // ignore: deprecated_member_use
        groupValue: isSelected,
        // ignore: deprecated_member_use
        onChanged: (value) {
          Navigator.pop(context);
          // Implement notification setting change
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppString.notificationSettingChangedto}: $title',
              ),
              backgroundColor: AppColors.appPriSecColor.primaryColor,
            ),
          );
        },
        activeColor: AppColors.appPriSecColor.primaryColor,
      ),
      onTap: () {
        Navigator.pop(context);
        // Implement notification setting change
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppString.notificationSettingChangedto}: $title'),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
          ),
        );
      },
    );
  }

  // 2. View Media Method
  void _viewMedia() {
    // Option 1: Simple placeholder
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppString.mediaGalleryComingSoon)));

    // Option 2: Navigate to media gallery (uncomment when ready)
    /*
  Navigator.pushNamed(
    context,
    AppRoutes.groupMediaGallery,
    arguments: {
      'groupId': widget.groupId,
      'groupName': widget.groupName,
    },
  );
  */

    // Option 3: Show media grid in bottom sheet
    /*
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: GroupMediaGallery(
        groupId: widget.groupId!,
      ),
    ),
  );
  */
  }

  // 3. Search Messages Method
  void _searchMessages() {
    Navigator.pop(
      context,
      "search",
    ); // Return "search" to indicate search mode should be enabled
  }

  // 4. Leave Group Method
  void _leaveGroup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppString.leaveGroupQuestion,
            style: AppTypography.h4(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          content: Text(
            AppString.areYouSureLeaveGroupName(widget.groupName),
            style: AppTypography.mediumText(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppString.cancel,
                style: AppTypography.buttonText(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performLeaveGroup();
              },
              child: Text(
                'Leave',
                style: AppTypography.buttonText(context).copyWith(
                  color: AppColors.textColor.textErrorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper method to perform leave group action
  void _performLeaveGroup() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('${AppString.leavingGroup}...'),
            ],
          ),
          backgroundColor: AppColors.appPriSecColor.primaryColor,
        ),
      );

      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      final success = await groupProvider.removeGroupMember(
        chatId: widget.groupId!,
        userId: int.parse(userID),
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppString.youHaveLeftTheGroup),
              backgroundColor: AppColors.appPriSecColor.primaryColor,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        throw Exception(AppString.failedToLeaveGroup);
      }

      // Temporary simulation - remove when API is ready
      await Future.delayed(Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppString.youHaveLeftTheGroup),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppString.failedToLeaveGroup}: $e'),
            backgroundColor: AppColors.textColor.textErrorColor,
          ),
        );
      }
    }
  }

  // 5. Delete Group Method (referenced in _buildDangerZone)
  // ignore: unused_element
  void _deleteGroup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppString.deleteGroupQuestion,
            style: AppTypography.h4(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textColor.textErrorColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppString.areYouSureDeleteName(widget.groupName),
                style: AppTypography.mediumText(context),
              ),
              SizedBox(height: 12),
              Container(
                padding: SizeConfig.getPadding(12),
                decoration: BoxDecoration(
                  color: AppColors.textColor.textErrorColor.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppString.thisActionCannotBeUndone,
                      style: AppTypography.captionText(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor.textErrorColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      AppString.allMessagesWillBePermanentlyDeleted,
                      style: AppTypography.captionText(
                        context,
                      ).copyWith(color: AppColors.textColor.textErrorColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppString.cancel,
                style: AppTypography.buttonText(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performDeleteGroup();
              },
              child: Text(
                AppString.deleteForever,
                style: AppTypography.buttonText(context).copyWith(
                  color: AppColors.textColor.textErrorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper method to perform delete group action
  void _performDeleteGroup() async {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('${AppString.deletingGroup}...'),
            ],
          ),
          backgroundColor: AppColors.textColor.textErrorColor,
          duration: Duration(seconds: 5),
        ),
      );

      // Implement delete group API call
      // Uncomment when API method is ready
      /*
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final success = await groupProvider.deleteGroup(chatId: widget.groupId!);
    
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppString.groupDeletedSuccessfully),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
          ),
        );
        widget.onGroupDeleted?.call();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      throw Exception('Failed to delete group');
    }
    */

      // Temporary simulation - remove when API is ready
      await Future.delayed(Duration(seconds: 3));

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppString.groupDeletedSuccessfully),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
          ),
        );
        widget.onGroupDeleted?.call();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppString.failedToDeleteGroup}: $e'),
            backgroundColor: AppColors.textColor.textErrorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }
}

class MediaSection {
  final String title;
  final List<media.Records> items;

  MediaSection({required this.title, required this.items});
}
