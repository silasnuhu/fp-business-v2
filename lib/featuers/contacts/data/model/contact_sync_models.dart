import 'dart:convert';

// ==========================================================================
// 1. SYNC DATA — saved after every sync to detect changes next time
// ==========================================================================

/// What we save locally after every successful sync.
/// Used to compare device contacts and find added/updated/deleted.
class ContactSyncData {
  final String? syncTimestamp;
  final List<SavedContact> contacts;

  ContactSyncData({this.syncTimestamp, this.contacts = const []});

  /// True when app has never synced before (fresh install / logged out)
  bool get isFirstSync => syncTimestamp == null;

  Map<String, dynamic> toJson() => {
    'sync_timestamp': syncTimestamp,
    'contacts': contacts.map((c) => c.toJson()).toList(),
  };

  factory ContactSyncData.fromJson(Map<String, dynamic> json) {
    return ContactSyncData(
      syncTimestamp: json['sync_timestamp'] as String?,
      contacts:
          (json['contacts'] as List<dynamic>?)
              ?.map((c) => SavedContact.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory ContactSyncData.fromJsonString(String jsonString) {
    return ContactSyncData.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  String toJsonString() => jsonEncode(toJson());
}

/// A single contact saved locally — phone + name is enough to detect changes.
class SavedContact {
  final String phone;
  final String name;
  final String countryCode;

  SavedContact({
    required this.phone,
    required this.name,
    this.countryCode = '',
  });

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'name': name,
    'country_code': countryCode,
  };

  factory SavedContact.fromJson(Map<String, dynamic> json) {
    return SavedContact(
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '',
    );
  }
}

/// Result of comparing device contacts with saved contacts.
class ContactChanges {
  final List<Map<String, dynamic>> added;
  final List<Map<String, dynamic>> updated;
  final List<Map<String, dynamic>> deleted;

  ContactChanges({
    required this.added,
    required this.updated,
    required this.deleted,
  });

  bool get isEmpty => added.isEmpty && updated.isEmpty && deleted.isEmpty;
  int get totalChanges => added.length + updated.length + deleted.length;
}

// ==========================================================================
// 2. CACHED CONTACT — for instant UI load (from get-contacts API response)
// ==========================================================================

/// Cached version of a registered contact from get-contacts API.
/// This is what we show instantly on app open.
class CachedContact {
  final String name;
  final String number;
  final int? userId;
  final String? userName;
  final String? profilePic;
  final String? bannerImage;
  final bool? isChatLock;
  final int? chatId;

  CachedContact({
    required this.name,
    required this.number,
    this.userId,
    this.userName,
    this.profilePic,
    this.bannerImage,
    this.isChatLock,
    this.chatId,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'number': number,
    'user_id': userId,
    'user_name': userName,
    'profile_pic': profilePic,
    'banner_image': bannerImage,
    'is_chat_lock': isChatLock,
    'chat_id': chatId,
  };

  factory CachedContact.fromJson(Map<String, dynamic> json) {
    return CachedContact(
      name: json['name'] as String? ?? '',
      number: json['number'] as String? ?? '',
      userId: json['user_id'] as int?,
      userName: json['user_name'] as String?,
      profilePic: json['profile_pic'] as String?,
      bannerImage: json['banner_image'] as String?,
      isChatLock: json['is_chat_lock'] as bool?,
      chatId: json['chat_id'] as int?,
    );
  }
}

/// Wrapper for the entire cached contacts list.
class CachedContactList {
  final List<CachedContact> contacts;
  final String? cachedAt; // When this cache was created

  CachedContactList({required this.contacts, this.cachedAt});

  bool get isEmpty => contacts.isEmpty;
  bool get isNotEmpty => contacts.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'contacts': contacts.map((c) => c.toJson()).toList(),
    'cached_at': cachedAt,
  };

  factory CachedContactList.fromJson(Map<String, dynamic> json) {
    return CachedContactList(
      contacts:
          (json['contacts'] as List<dynamic>?)
              ?.map((c) => CachedContact.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      cachedAt: json['cached_at'] as String?,
    );
  }

  factory CachedContactList.fromJsonString(String jsonString) {
    return CachedContactList.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  String toJsonString() => jsonEncode(toJson());
}
