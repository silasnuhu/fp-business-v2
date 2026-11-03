import 'package:flutter/material.dart';

class GetContactModel {
  final bool? status;
  final GetContactData? data;
  final String? message;
  final bool? toast;

  GetContactModel({this.status, this.data, this.message, this.toast});

  // NEW's `/contacts/sync` response isn't confirmed to keep the
  // {status,data,message,toast} envelope (only described as "summary
  // counts" — §4.5), so `status` defaults to true on any non-throwing call
  // rather than assuming the key is present.
  factory GetContactModel.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    return GetContactModel(
      status: (map['status'] as bool?) ?? true,
      data:
          map['data'] != null
              ? GetContactData.fromJson(map['data'] as Map<String, dynamic>)
              : null,
      message: map['message'] as String?,
      toast: map['toast'] as bool?,
    );
  }
}

class GetContactData {
  final String? userName;
  final String? email;
  final int? mobileNum;
  final String? profilePic;
  final int? userId;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? countryCode;
  final String? country;
  final List<ContactDetails?>? contactDetails;

  GetContactData({
    this.userName,
    this.email,
    this.mobileNum,
    this.profilePic,
    this.userId,
    this.fullName,
    this.firstName,
    this.lastName,
    this.countryCode,
    this.country,
    this.contactDetails,
  });

  factory GetContactData.fromJson(Map<String, dynamic> json) {
    return GetContactData(
      userName: json['user_name'] as String?,
      email: json['email'] as String?,
      mobileNum: _parseInt(json['mobile_num']), // ✅ fixed
      profilePic: json['profile_pic'] as String?,
      userId: _parseInt(json['user_id']), // ✅ fixed (potentially same issue)
      fullName: json['full_name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      countryCode: json['country_code'] as String?,
      country: json['country'] as String?,
      contactDetails:
          json['contact_details'] != null
              ? (json['contact_details'] as List).map((item) {
                try {
                  return item != null
                      ? ContactDetails.fromJson(item as Map<String, dynamic>)
                      : null;
                } catch (e) {
                  debugPrint('Error parsing contact detail: $e');
                  return null;
                }
              }).toList()
              : null,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class ContactDetails {
  final String? name;
  final String? number; // Changed to String to handle both string and int
  final String? countryCode; // Country code from API (if available)
  final int? userId;
  final String? userName;
  final String? profilePic; // Add profile picture URL
  final bool? isChatLock;
  final int? chatId;
  // `premiumUser` when `GET /contacts` carries it; null when it does not.
  final bool? premiumUser;

  ContactDetails({
    this.name,
    this.number,
    this.countryCode,
    this.userId,
    this.userName,
    this.profilePic,
    this.isChatLock,
    this.chatId,
    this.premiumUser,
  });

  /// Get full phone number with country code
  /// Priority: If number already has +, use as-is. Otherwise prepend countryCode.
  String? get fullNumber {
    if (number == null || number!.isEmpty) return number;
    if (number!.startsWith('+')) return number; // Already has country code
    if (countryCode != null && countryCode!.isNotEmpty) {
      String cc = countryCode!;
      if (!cc.startsWith('+')) cc = '+$cc';
      return '$cc$number';
    }
    return number;
  }

  // NEW's `GET /contacts` (see ContactsService.list) returns items shaped
  // as `{id, name, userName, phoneNumber, profileImage, updatedAt}` —
  // camelCase, and different names than OLD's `number`/`user_id`/
  // `user_name`/`profile_pic` this used to parse. Confirmed directly
  // against backend source, not just the migration guide. NEW's response
  // has no `country_code`, `is_chat_lock`, or `chat_id` at all — those stay
  // null (chat-lock state is applied separately, see
  // ContactProvider.patchContactLockState).
  factory ContactDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ContactDetails();
    }

    return ContactDetails(
      name: json['name'] as String?,
      number: _parseNumber(json['phoneNumber']),
      countryCode: json['country_code'] as String?,
      userId: _parseUserId(json['id']),
      userName: json['userName'] as String?,
      profilePic: json['profileImage'] as String?,
      isChatLock: json['is_chat_lock'] as bool?,
      chatId: json['chat_id'] as int?,
      premiumUser: (json['premiumUser'] ?? json['premium_user']) as bool?,
    );
  }

  // Helper method to safely parse number (can be string or int)
  static String? _parseNumber(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    return value.toString();
  }

  // Helper method to safely parse user_id (can be string or int)
  static int? _parseUserId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'number': number,
      'user_id': userId,
      'user_name': userName,
      'profile_pic': profilePic,
      'is_chat_lock': isChatLock,
      'chat_id': chatId,
    };
  }
}
