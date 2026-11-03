// File: lib/features/groups/providers/group_provider.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:whoxa/featuers/chat/group/data/model/create_group_response.dart';
import 'package:whoxa/featuers/chat/group/data/model/group_member_response.dart';
import 'package:whoxa/featuers/chat/group/data/repository/group_repository.dart';
import 'package:whoxa/utils/logger.dart';

class GroupProvider with ChangeNotifier {
  final GroupRepo _repo;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  GroupProvider(this._repo);

  // Loading states
  bool _isLoading = false;
  bool _isMembersLoading = false;
  bool _isMemberActionLoading = false;

  // Error states
  String? _error;
  String? _membersError;

  // Data
  CreateGroupResponse? _response;
  GroupMembersResponse? _membersResponse;
  List<GroupMember> _members = [];

  // Group info
  String? _groupName;
  String? _groupDescription;
  String? _groupIcon;

  // Getters
  bool get isLoading => _isLoading;
  bool get isMembersLoading => _isMembersLoading;
  bool get isMemberActionLoading => _isMemberActionLoading;

  String? get error => _error;
  String? get membersError => _membersError;

  CreateGroupResponse? get response => _response;
  GroupMembersResponse? get membersResponse => _membersResponse;
  List<GroupMember> get members => _members;

  // Group info getters
  String? get groupName => _groupName;
  String? get groupDescription => _groupDescription;
  String? get groupIcon => _groupIcon;

  // Helper getters
  int get memberCount => _members.length;
  List<GroupMember> get admins => _members.where((m) => m.isAdmin).toList();
  List<GroupMember> get regularMembers =>
      _members.where((m) => !m.isAdmin).toList();
  int get adminCount => admins.length;
  int get onlineMemberCount => _members.where((m) => m.isOnline == true).length;

  bool isMember(String userId) {
    final parsedId = int.tryParse(userId);
    if (parsedId == null) return false;
    return members.any((e) => e.userId == parsedId);
  }

  // Create Group
  Future<void> createGroup({
    required List<int> participants,
    required String groupName,
    required String description,
    File? groupIcon,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.i('Creating group: $groupName');
      _response = await _repo.createGroup(
        participants: participants,
        groupName: groupName,
        description: description,
        groupIcon: groupIcon,
      );
      _logger.i('Group created successfully');
    } catch (e) {
      _error = e.toString();
      _logger.e('Error creating group', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update Group
  Future<Map<String, dynamic>?> updateGroup({
    required int chatId,
    required String groupName,
    required String groupDescription,
    String? pictureType,
    File? groupIcon,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.i('Updating group: $groupName (Chat ID: $chatId)');
      final response = await _repo.updateGroup(
        chatId: chatId,
        groupName: groupName,
        groupDescription: groupDescription,
        pictureType: pictureType,
        groupIcon: groupIcon,
      );

      if (response != null && (response['status'] == true)) {
        _logger.i('Group updated successfully');
        _logger.d('Update response data: ${response['data']}');

        // Update local group info from response. NEW's PATCH response uses
        // `title`/`avatarMediaId`, not `group_name`/`group_icon`, and has
        // no `group_description` field at all (§5.6) — fall back to the
        // value we just sent for name since NEW may not echo it back.
        final data = response['data'];
        _groupName =
            (data is Map ? data['title']?.toString() : null) ?? groupName;
        _groupDescription = null;
        // `avatarUrl` is the repo-resolved `cdnUrl` for the conversation's
        // avatarMediaId. This getter is read as an image src
        // (universal_chat_screen), so keep the previous value when the
        // response carries no resolvable picture rather than storing a bare
        // media id, which no image widget can load.
        _groupIcon = (response['avatarUrl'] as String?) ?? _groupIcon;

        return response;
      } else {
        _logger.w('Group update returned false or null response');
        return null;
      }
    } catch (e) {
      _error = e.toString();
      _logger.e('Error updating group', e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get Group Members
  Future<void> getGroupMembers({required int chatId}) async {
    _isMembersLoading = true;
    _membersError = null;
    notifyListeners();

    try {
      _logger.i('Fetching group members for chat: $chatId');
      _membersResponse = await _repo.getGroupMembers(chatId: chatId);
      final fetched = _membersResponse?.data.records ?? [];

      // A per-participant profile lookup inside the repo call can fail for
      // an individual member (transient network hiccup — common right after
      // a group call ends and its sockets are still tearing down), leaving
      // that member's `user` null on this fetch even though a previous
      // fetch already resolved it. Don't let that regress an already-known
      // name back to "Unknown User" — keep the last known-good profile.
      final previousByUserId = {for (final m in _members) m.userId: m};
      _members = [
        for (final m in fetched)
          if (m.user == null && previousByUserId[m.userId]?.user != null)
            GroupMember(
              participantId: m.participantId,
              isAdmin: m.isAdmin,
              updateCounter: m.updateCounter,
              isDeleted: m.isDeleted,
              lastMessageId: m.lastMessageId,
              createdAt: m.createdAt,
              updatedAt: m.updatedAt,
              chatId: m.chatId,
              userId: m.userId,
              isLocked: m.isLocked,
              user: previousByUserId[m.userId]!.user,
              isOnline: m.isOnline,
              lastSeen: m.lastSeen,
            )
          else
            m,
      ];
      _logger.i('Fetched ${_members.length} group members');

      // Log member details for debugging
      for (final member in _members) {
        _logger.d(
          'Member: ${member.displayName} (ID: ${member.userId}, Admin: ${member.isAdmin})',
        );
      }
      notifyListeners();
    } catch (e) {
      _membersError = e.toString();
      _logger.e('Error fetching group members', e);
    } finally {
      _isMembersLoading = false;
      notifyListeners();
    }
  }

  // Remove Group Member
  Future<bool> removeGroupMember({
    required int chatId,
    required int userId,
  }) async {
    _isMemberActionLoading = true;
    notifyListeners();

    try {
      _logger.i('Removing member $userId from group $chatId');
      final success = await _repo.removeGroupMember(
        chatId: chatId,
        userId: userId,
      );

      if (success) {
        // Remove member from local list
        _members.removeWhere((member) => member.userId == userId);
        _logger.i('Member removed successfully from local list');
      }

      return success;
    } catch (e) {
      _logger.e('Error removing group member', e);
      return false;
    } finally {
      _isMemberActionLoading = false;
      notifyListeners();
    }
  }

  // Add Group Member
  Future<bool> addGroupMember({
    required int chatId,
    required List<int> userIds,
  }) async {
    _isMemberActionLoading = true;
    notifyListeners();

    try {
      _logger.i('Adding member group $chatId');
      final success = await _repo.addGroupMember(
        chatId: chatId,
        userIds: userIds,
      );

      if (success) {
        // Refresh members list to get the new member
        await getGroupMembers(chatId: chatId);
        _logger.i('Member added successfully and list refreshed');
      }

      return success;
    } catch (e) {
      _logger.e('Error adding group member', e);
      return false;
    } finally {
      _isMemberActionLoading = false;
      notifyListeners();
    }
  }

  // ❌ REMOVED IN NEW, NO REPLACEMENT AT ALL (§5.3/§5.7 of the migration
  // guide): `role` ("owner"/"member") is fixed at conversation-creation
  // time; there is no API to change it afterward. Per the guide's explicit
  // instruction ("do not build a workaround, stop and report this gap"),
  // these no longer call any endpoint — they fail immediately with a clear
  // message instead of silently no-op'ing or hitting a 404. group_info.dart
  // hides the Make/Remove Admin menu entries entirely so this path isn't
  // normally reachable from the UI at all.
  Future<bool> makeGroupAdmin({
    required int chatId,
    required int userId,
    required bool isRemove,
  }) async {
    _error =
        'Changing group admins is not supported by the current backend.';
    _logger.e(
      'makeGroupAdmin called but NEW has no promote/demote-admin endpoint at all — refusing rather than guessing',
    );
    notifyListeners();
    return false;
  }

  // ❌ REMOVED IN NEW, see makeGroupAdmin above — kept as a stub only so any
  // remaining reference compiles; never actually called by the UI (it was
  // already dead code before this migration, per the architecture survey).
  Future<bool> removeGroupAdmin({
    required int chatId,
    required int userId,
  }) async {
    _error =
        'Changing group admins is not supported by the current backend.';
    _logger.e(
      'removeGroupAdmin called but NEW has no promote/demote-admin endpoint at all — refusing rather than guessing',
    );
    notifyListeners();
    return false;
  }

  // Update member online status (called from ChatProvider or external source)
  void updateMemberOnlineStatus({
    required int userId,
    required bool isOnline,
    String? lastSeen,
  }) {
    final memberIndex = _members.indexWhere(
      (member) => member.userId == userId,
    );
    if (memberIndex != -1) {
      _members[memberIndex] = _members[memberIndex].copyWith(
        isOnline: isOnline,
        lastSeen: lastSeen,
      );
      notifyListeners();
      _logger.d('Updated online status for user $userId: $isOnline');
    }
  }

  // Set group info (useful for initializing from chat data)
  void setGroupInfo({
    String? groupName,
    String? groupDescription,
    String? groupIcon,
  }) {
    _groupName = groupName;
    _groupDescription = groupDescription;
    _groupIcon = groupIcon;
    // notifyListeners();
  }

  // Clear all data
  void clearData() {
    _response = null;
    _membersResponse = null;
    _members.clear();
    _error = null;
    _membersError = null;
    _groupName = null;
    _groupDescription = null;
    _groupIcon = null;
    notifyListeners();
  }

  // Check if user is admin
  bool isUserAdmin(int userId) {
    return _members.any((member) => member.userId == userId && member.isAdmin);
  }

  // Get member by user ID
  GroupMember? getMemberByUserId(int userId) {
    try {
      return _members.firstWhere((member) => member.userId == userId);
    } catch (e) {
      return null;
    }
  }

  // Get display name for a user ID
  String getMemberDisplayName(int userId) {
    final member = getMemberByUserId(userId);
    return member?.displayName ?? 'User $userId';
  }

  // Check if a user exists in the group
  bool isMemberInGroup(int userId) {
    return _members.any((member) => member.userId == userId);
  }

  // Get available contacts for adding to group (not already members)
  List<int> getAvailableContactIds(List<int> allContactIds) {
    final memberIds = _members.map((m) => m.userId).toSet();
    return allContactIds.where((id) => !memberIds.contains(id)).toList();
  }
}
