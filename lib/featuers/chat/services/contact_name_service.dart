import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/featuers/chat/repository/conversation_repository.dart';
import 'package:whoxa/featuers/contacts/data/repository/contact_repo.dart';
import 'package:whoxa/featuers/contacts/data/model/get_contact_model.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/utils/network_info.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/common_profile_avatar.dart'
    show kDeletedAccountName;
import 'dart:convert';

class ContactNameService {
  static ContactNameService? _instance;
  static ContactNameService get instance =>
      _instance ??= ContactNameService._();

  late final Future<void> _storageReady;

  ContactNameService._() {
    _storageReady = _initializeFromStorage();
  }

  Future<void> _initializeFromStorage() async {
    try {
      // Load contact cache from storage
      final String? cachedData = await SecurePrefs.getString(_cacheKey);
      if (cachedData != null && cachedData.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(cachedData);
        final Map<String, dynamic> contacts = decoded['contacts'] ?? {};
        final String? lastUpdate = decoded['lastUpdate'];

        _deviceContactNameCache = contacts.map(
          (key, value) => MapEntry(int.parse(key), value.toString()),
        );

        if (lastUpdate != null) {
          _lastCacheUpdate = DateTime.tryParse(lastUpdate);
        }

        if (kDebugMode) {
          debugPrint(
            '✅ Loaded ${_deviceContactNameCache.length} contacts from storage',
          );
        }
      }

      // Load final display name cache from storage
      final String? finalCachedData = await SecurePrefs.getString(
        _finalNameCacheKey,
      );
      if (finalCachedData != null && finalCachedData.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(finalCachedData);
        _finalDisplayNameCache = decoded.map(
          (key, value) => MapEntry(int.parse(key), value.toString()),
        );

        if (kDebugMode) {
          debugPrint(
            '✅ Loaded ${_finalDisplayNameCache.length} final names from storage',
          );
        }
      }

      // Load API user data cache from storage
      final String? apiCachedData = await SecurePrefs.getString(
        _apiDataCacheKey,
      );
      if (apiCachedData != null && apiCachedData.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(apiCachedData);
        _apiUserDataCache = decoded.map(
          (key, value) => MapEntry(
            int.parse(key),
            (value as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v?.toString()),
            ),
          ),
        );

        if (kDebugMode) {
          debugPrint(
            '✅ Loaded ${_apiUserDataCache.length} API user data from storage',
          );
        }
      }

      final String? premiumData = await SecurePrefs.getString(
        _premiumUsersKey,
      );
      if (premiumData != null && premiumData.isNotEmpty) {
        premiumUsers.value = {
          ...premiumUsers.value,
          ...(json.decode(premiumData) as List).whereType<int>(),
        };
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading contact cache from storage: $e');
      }
      _isInitialized = true; // Still mark as initialized to prevent blocking
    }
  }

  final ConversationRepository _conversationRepo = ConversationRepository(
    ApiClient(Dio(), NetworkInfoImpl(Connectivity())),
  );

  final ContactRepo _contactRepo = ContactRepo(
    ApiClient(Dio(), NetworkInfoImpl(Connectivity())),
  );

  /// Priority-1 source of truth: the name the user saved this person as in their
  /// device address book, matched to a backend userId by phone number. Written
  /// ONLY by [updateCacheWithContacts] (fed from ContactProvider). The new
  /// backend never returns the device-saved name, so this is the only place it
  /// lives on the client.
  Map<int, String> _deviceContactNameCache = {};
  Map<int, String> _finalDisplayNameCache = {}; // Cache for final decided names
  Map<int, Map<String, String?>> _apiUserDataCache =
      {}; // Backend profile data (userName, fullName) — fallback only
  DateTime? _lastCacheUpdate;

  /// Users whose curated profile (`GET /users/:id`, `GET /users/batch`) came
  /// back with `isDeleted: true`. They render as [kDeletedAccountName]
  /// everywhere — ahead of a saved contact name or a locked-in cached name.
  /// A deleted account never comes back (re-registering the number creates
  /// a new user id), so ids are only ever added.
  final Set<int> _deletedUserIds = <int>{};
  /// Users the backend flagged `premiumUser` (blue tick). Fed by every
  /// curated profile read (`users/batch`, `users/:id`) through
  /// [noteUserProfile]; persisted so a cold start shows the tick on the
  /// cached chat list. The set is replaced, never mutated, so listeners
  /// always see a change.
  final ValueNotifier<Set<int>> premiumUsers = ValueNotifier(<int>{});
  static const String _premiumUsersKey = 'premium_users_cache';

  /// Contacts whose `premiumUser` flag was already looked up this session
  /// (`GET /contacts` does not carry it, so it is read from `users/batch`).
  final Set<int> _premiumChecked = <int>{};

  bool isPremiumUser(int? userId) =>
      userId != null && premiumUsers.value.contains(userId);

  void _setPremium(int userId, bool premium) {
    if (premiumUsers.value.contains(userId) == premium) return;
    final next = {...premiumUsers.value};
    premium ? next.add(userId) : next.remove(userId);
    premiumUsers.value = next;
    SecurePrefs.setString(_premiumUsersKey, json.encode(next.toList()))
        .catchError((_) {});
  }

  static const Duration _cacheValidityDuration = Duration(minutes: 10);
  static const String _cacheKey = 'contact_name_cache';
  static const String _finalNameCacheKey = 'final_display_name_cache';
  static const String _apiDataCacheKey = 'api_user_data_cache';

  bool _isLoading = false;
  // ignore: unused_field
  bool _isInitialized = false;

  Future<void> loadAndCacheContacts() async {
    if (_isLoading) return;

    // ✅ Wait for the persisted cache (including last-update timestamp) to
    // finish loading from storage first — otherwise a cold-start call here
    // can race _initializeFromStorage() and see _lastCacheUpdate as null,
    // triggering a needless network call even though the cache is fresh.
    await _storageReady;
    if (_isLoading) return;

    final now = DateTime.now();
    if (_lastCacheUpdate != null &&
        now.difference(_lastCacheUpdate!) < _cacheValidityDuration) {
      debugPrint('Contact cache is still valid, skipping reload');
      return;
    }

    _isLoading = true;
    try {
      // 🔄 UPDATED: Use the new getContactsList method for consistency
      debugPrint(
        '🔄 loadAndCacheContacts: Using getContactsList for contact sync',
      );
      final contactDetailsList = await _contactRepo.getContactsList();

      if (contactDetailsList.isNotEmpty) {
        // Use the new sync method to handle contact updates properly
        await syncContactDataFromApi(contactDetailsList);

        _lastCacheUpdate = now;

        if (kDebugMode) {
          debugPrint(
            '✅ loadAndCacheContacts: Synced ${contactDetailsList.length} contacts',
          );
          debugPrint(
            '   Local contacts cached: ${_deviceContactNameCache.length}',
          );
          debugPrint('   API users cached: ${_apiUserDataCache.length}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ loadAndCacheContacts: No contacts returned from API');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ loadAndCacheContacts: Error loading contacts: $e');
      }
      // Continue - other contact loading mechanisms might work
    } finally {
      _isLoading = false;
    }
  }

  /// Replace the device-saved-name cache (priority 1). Any user whose saved
  /// name was added / changed / removed has its anti-flicker decision dropped
  /// so the new name takes effect immediately, without depending on the caller
  /// to also invoke [clearFinalNameCache].
  Future<void> updateCacheWithContacts(Map<int, String> contacts) async {
    final affected = <int>{
      ..._deviceContactNameCache.keys,
      ...contacts.keys,
    }.where((id) => _deviceContactNameCache[id] != contacts[id]);
    for (final id in affected) {
      _finalDisplayNameCache.remove(id);
    }

    _deviceContactNameCache
      ..clear()
      ..addAll(contacts);
    _lastCacheUpdate = DateTime.now();
    await _saveToStorage();

    if (kDebugMode) {
      debugPrint(
        'Contact cache manually updated with ${contacts.length} contacts',
      );
      for (final entry in contacts.entries) {
        debugPrint('Cached contact: userId=${entry.key}, name=${entry.value}');
      }
    }
  }

  /// Sync backend profile data (from GET /contacts) into the FALLBACK cache only.
  ///
  /// The new backend's `name` field here is the peer's own `fullName ?? userName`
  /// — NOT the device-saved contact name — so it must never touch
  /// [_deviceContactNameCache] (priority 1). It only feeds the fallback tiers.
  Future<void> syncContactDataFromApi(List<ContactDetails> apiContacts) async {
    int changed = 0;
    final List<int> changedUserIds = [];
    final premiumUnknown = <int>[];

    for (final apiContact in apiContacts) {
      if (apiContact.userId == null) continue;

      final userId = apiContact.userId!;
      if (apiContact.premiumUser != null) {
        _setPremium(userId, apiContact.premiumUser!);
        _premiumChecked.add(userId);
      } else if (_premiumChecked.add(userId)) {
        premiumUnknown.add(userId);
      }
      final profileFullName = _clean(apiContact.name);
      final profileUserName = _clean(apiContact.userName);

      final existing = _apiUserDataCache[userId];
      if (existing == null ||
          existing['fullName'] != profileFullName ||
          existing['userName'] != profileUserName) {
        changed++;
        changedUserIds.add(userId);
      }

      _apiUserDataCache[userId] = {
        'userName': profileUserName,
        'fullName': profileFullName,
        'email': null,
      };
    }

    // Re-evaluate any user whose fallback data changed — but only drop
    // final-cache entries that were NOT locked in by a device-saved name
    // (priority 1 must stay stable).
    for (final userId in changedUserIds) {
      if (!_deviceContactNameCache.containsKey(userId)) {
        _finalDisplayNameCache.remove(userId);
      }
    }

    await _saveToStorage();

    // Not awaited: the tick shows up on its own once `users/batch` answers
    // (each read goes through noteUserProfile, which records `premiumUser`).
    if (premiumUnknown.isNotEmpty) {
      _conversationRepo
          .getUserBasicProfiles([for (final id in premiumUnknown) '$id'])
          .catchError((_) => <String, Map<String, dynamic>>{});
    }

    if (kDebugMode) {
      debugPrint(
        '[ContactSync] Profile fallback cache updated: $changed changed, '
        '${_apiUserDataCache.length} total',
      );
    }
  }

  // 🔄 DEPRECATED: Keep old method name for compatibility, redirect to new method
  Future<void> syncApiUserData(List<ContactDetails> apiContacts) async {
    await syncContactDataFromApi(apiContacts);
  }

  // Save cache to persistent storage
  Future<void> _saveToStorage() async {
    try {
      final Map<String, dynamic> cacheData = {
        'contacts': _deviceContactNameCache.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        'lastUpdate': _lastCacheUpdate?.toIso8601String(),
      };
      await SecurePrefs.setString(_cacheKey, json.encode(cacheData));

      // Also save final display name cache
      final Map<String, dynamic> finalCacheData = _finalDisplayNameCache.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      await SecurePrefs.setString(
        _finalNameCacheKey,
        json.encode(finalCacheData),
      );

      // Save API user data cache
      final Map<String, dynamic> apiCacheData = _apiUserDataCache.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      await SecurePrefs.setString(_apiDataCacheKey, json.encode(apiCacheData));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving contact cache to storage: $e');
      }
    }
  }

  // ==========================================================================
  // NAME RESOLUTION — one priority chain for the whole app
  //
  //   1. Saved contact name  (device address book, matched by phone number)
  //   2. firstName + lastName
  //   3. firstName
  //   4. lastName
  //   5. Existing fallback  (profile fullName → userName → email →
  //                          caller's literal fallback → "Unknown User")
  //
  // null / empty / whitespace-only values are skipped at every tier.
  // ==========================================================================

  /// Trim + empty check. Returns null for null / blank / whitespace-only.
  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Tiers 2–4: "First Last" → "First" → "Last" → null.
  static String? _composeName(String? firstName, String? lastName) {
    final first = _clean(firstName);
    final last = _clean(lastName);
    if (first != null && last != null) return '$first $last';
    return first ?? last;
  }

  bool isUserDeleted(int? userId) =>
      userId != null && _deletedUserIds.contains(userId);

  /// Records the `isDeleted` flag and fallback name fields carried by a
  /// curated user object. Called by every repository that reads
  /// `GET /users/:id` / `GET /users/batch`, so a profile fetched once for
  /// any reason (viewing it, loading a group's members, ...) stays available
  /// as a tier-5 fallback even if a *later* fetch for the same userId fails
  /// (e.g. the per-participant re-fetch after a group call ends).
  void noteUserProfile(Map<String, dynamic>? profile) {
    if (profile == null) return;
    final userId = int.tryParse(
      '${profile['userId'] ?? profile['user_id'] ?? ''}',
    );
    if (userId == null) return;

    final premium = profile['premiumUser'] ?? profile['premium_user'];
    final isDeleted = (profile['isDeleted'] ?? profile['is_deleted']) == true;
    if (premium is bool || isDeleted) {
      _setPremium(userId, !isDeleted && premium == true);
    }

    final fullName = _clean(profile['fullName']?.toString());
    final userName = _clean(profile['userName']?.toString());
    final email = _clean(profile['email']?.toString());
    if (fullName != null || userName != null || email != null) {
      _apiUserDataCache[userId] = {
        'userName': userName ?? _apiUserDataCache[userId]?['userName'],
        'fullName': fullName ?? _apiUserDataCache[userId]?['fullName'],
        'email': email ?? _apiUserDataCache[userId]?['email'],
      };
      _saveToStorage().catchError((e) {
        if (kDebugMode) {
          debugPrint('Error saving after noting profile for $userId: $e');
        }
      });
    }

    if ((profile['isDeleted'] ?? profile['is_deleted']) != true) return;
    if (!_deletedUserIds.add(userId)) return;

    // Drop the name locked in from before the deletion.
    if (_finalDisplayNameCache.remove(userId) != null) {
      _saveToStorage().catchError((e) {
        if (kDebugMode) {
          debugPrint('Error saving after marking user $userId deleted: $e');
        }
      });
    }
  }

  /// The single reusable resolver. Every display site funnels through here.
  ///
  /// [fallback] is the caller's own literal (e.g. `'Someone'`, `'Unknown User'`),
  /// used only after every real name source is exhausted. [configProvider] is
  /// accepted for call-site compatibility but no longer gates resolution.
  String resolveName({
    int? userId,
    String? firstName,
    String? lastName,
    String? fullName,
    String? userName,
    String? email,
    String? fallback,
    // ignore: avoid_unused_constructor_parameters
    ProjectConfigProvider? configProvider,
  }) {
    // A deleted account is always "Deleted Account" — never a saved contact
    // name or a name cached from before the deletion.
    if (isUserDeleted(userId)) return kDeletedAccountName;

    // Anti-fluctuation: a decision already locked in for this user wins, so the
    // name never flips between rebuilds / data sources.
    if (userId != null) {
      final cached = _finalDisplayNameCache[userId];
      if (cached != null) return cached;
    }

    // Tier 1 — saved contact name (device address book).
    final deviceName =
        userId == null ? null : _clean(_deviceContactNameCache[userId]);
    if (deviceName != null) {
      _saveFinalDisplayName(userId, deviceName);
      return deviceName;
    }

    // Tiers 2–4 — first / last name parts from the calling context.
    final composed = _composeName(firstName, lastName);
    if (composed != null) {
      _saveFinalDisplayName(userId, composed);
      return composed;
    }

    // Tier 5 — existing fallback chain.
    final profile = userId == null ? null : _apiUserDataCache[userId];
    final resolved =
        _clean(fullName) ??
        _clean(profile?['fullName']) ??
        _clean(userName) ??
        _clean(profile?['userName']) ??
        _clean(email);
    if (resolved != null) {
      _saveFinalDisplayName(userId, resolved);
      return resolved;
    }

    // Nothing concrete — use the caller's literal, but do NOT cache it so the
    // name re-resolves once real data arrives.
    return _clean(fallback) ?? 'Unknown User';
  }

  String getDisplayName({
    required int? userId,
    required String? userFullName,
    required String? userName,
    required String? userEmail,
    required ProjectConfigProvider? configProvider,
    String? firstName,
    String? lastName,
  }) {
    return resolveName(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      fullName: userFullName,
      userName: userName,
      email: userEmail,
      configProvider: configProvider,
    );
  }

  /// Anti-flickering display name for UI screens. Same priority chain as
  /// [resolveName]; [contextFullName] is the full name from the calling context
  /// (e.g. `PeerUserData.fullName`).
  String getDisplayNameStable({
    required int? userId,
    required ProjectConfigProvider? configProvider,
    String? contextFullName,
    String? firstName,
    String? lastName,
  }) {
    return resolveName(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      fullName: contextFullName,
      configProvider: configProvider,
    );
  }

  // Save the final display name decision to prevent fluctuation
  void _saveFinalDisplayName(int? userId, String displayName) {
    if (userId != null) {
      _finalDisplayNameCache[userId] = displayName;
      // Save to persistent storage asynchronously
      _saveToStorage().catchError((e) {
        if (kDebugMode) {
          debugPrint('Error saving final display name cache: $e');
        }
      });
    }
  }

  void clearCache() {
    _deviceContactNameCache.clear();
    _finalDisplayNameCache.clear();
    _apiUserDataCache.clear();
    _deletedUserIds.clear();
    _lastCacheUpdate = null;
    // Clear persistent storage
    _clearStorageCache();

    if (kDebugMode) {
      debugPrint(
        '🧹 ContactNameService: All caches cleared (local contacts + final names + API data)',
      );
    }
  }

  // Clear only the anti-fluctuation cache to allow priority fix to take effect
  void clearFinalNameCache() {
    _finalDisplayNameCache.clear();
    // Save the updated cache state
    _saveToStorage().catchError((e) {
      if (kDebugMode) {
        debugPrint('Error saving after clearing final name cache: $e');
      }
    });

    if (kDebugMode) {
      debugPrint(
        '🧹 ContactNameService: Final name cache cleared, names will be re-evaluated with fixed priority',
      );
    }
  }

  Future<void> _clearStorageCache() async {
    try {
      await SecurePrefs.setString(_cacheKey, '');
      await SecurePrefs.setString(_finalNameCacheKey, '');
      await SecurePrefs.setString(_apiDataCacheKey, '');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error clearing storage cache: $e');
      }
    }
  }

  bool get hasCachedContacts => _deviceContactNameCache.isNotEmpty;

  int get cachedContactsCount => _deviceContactNameCache.length;

  // Check if a user is saved in contacts
  bool isUserInContacts(int? userId) {
    if (userId == null) return false;
    return _deviceContactNameCache.containsKey(userId);
  }

  // Get the current final display name for a user (for debugging)
  String? getFinalDisplayName(int? userId) {
    if (userId == null) return null;
    return _finalDisplayNameCache[userId];
  }

  // Force refresh a specific user's display name (clears final cache for that user)
  void refreshUserDisplayName(int? userId) {
    if (userId != null && _finalDisplayNameCache.containsKey(userId)) {
      _finalDisplayNameCache.remove(userId);
      _saveToStorage().catchError((e) {
        if (kDebugMode) {
          debugPrint('Error saving after refreshing user display name: $e');
        }
      });
      if (kDebugMode) {
        debugPrint('🔄 Refreshed display name cache for userId: $userId');
      }
    }
  }

  // 🐛 DEBUG METHOD: Get detailed source information for a user's name
  Map<String, dynamic> getNameSourceDebugInfo(int? userId) {
    if (userId == null) {
      return {'error': 'userId is null'};
    }

    Map<String, dynamic> debugInfo = {
      'userId': userId,
      'hasLocalContact': _deviceContactNameCache.containsKey(userId),
      'localContactName': _deviceContactNameCache[userId],
      'hasFinalCache': _finalDisplayNameCache.containsKey(userId),
      'finalCachedName': _finalDisplayNameCache[userId],
      'cacheTimestamp': _lastCacheUpdate?.toIso8601String(),
    };

    if (kDebugMode) {
      debugPrint('🐛 DEBUG INFO for userId $userId:');
      debugInfo.forEach((key, value) {
        debugPrint('   $key: $value');
      });
    }

    return debugInfo;
  }

  // 🐛 DEBUG METHOD: Trace name selection process step by step
  String getDisplayNameWithTrace({
    required int? userId,
    required String? userFullName,
    required String? userName,
    required String? userEmail,
    required ProjectConfigProvider? configProvider,
  }) {
    if (kDebugMode) {
      debugPrint('🔍 TRACE: Starting name resolution for userId $userId');
      debugPrint(
        '   Input: fullName="$userFullName", userName="$userName", email="$userEmail"',
      );
    }

    // Get regular display name with enhanced logging
    String result = getDisplayName(
      userId: userId,
      userFullName: userFullName,
      userName: userName,
      userEmail: userEmail,
      configProvider: configProvider,
    );

    if (kDebugMode) {
      debugPrint('🎯 TRACE RESULT: userId $userId → "$result"');
      getNameSourceDebugInfo(userId); // Print debug info
    }

    return result;
  }

  // 🐛 DEBUG METHOD: List all cached contacts
  void printAllCachedContacts() {
    if (kDebugMode) {
      debugPrint(
        '📋 ALL CACHED LOCAL CONTACTS (${_deviceContactNameCache.length}):',
      );
      _deviceContactNameCache.forEach((userId, name) {
        debugPrint('   userId: $userId → "$name"');
      });

      debugPrint(
        '📋 ALL FINAL CACHED NAMES (${_finalDisplayNameCache.length}):',
      );
      _finalDisplayNameCache.forEach((userId, name) {
        debugPrint('   userId: $userId → "$name"');
      });

      debugPrint('📋 ALL API USER DATA (${_apiUserDataCache.length}):');
      _apiUserDataCache.forEach((userId, userData) {
        debugPrint(
          '   userId: $userId → userName:"${userData['userName']}", fullName:"${userData['fullName']}"',
        );
      });
    }
  }

  // 🐛 DEBUG METHOD: Check if API data exists for a specific user
  Map<String, String?> getApiUserData(int userId) {
    return _apiUserDataCache[userId] ??
        {'userName': null, 'fullName': null, 'email': null};
  }

  // 🧪 TEST METHOD: Simulate API response with updated name field (single source of truth)
  Future<void> simulateApiNameUpdate(
    int userId,
    String newApiName, {
    String? userName,
  }) async {
    if (kDebugMode) {
      debugPrint('🧪 SIMULATING API NAME UPDATE for userId=$userId');
      debugPrint(
        '   New API name field: "$newApiName" (single source of truth)',
      );
      debugPrint('   UserName: "${userName ?? 'unchanged'}"');

      // Show current state
      final currentApiName = _deviceContactNameCache[userId];
      final currentFinalName = _finalDisplayNameCache[userId];
      debugPrint('   Current API name: "${currentApiName ?? 'none'}"');
      debugPrint(
        '   Current final cached name: "${currentFinalName ?? 'none'}"',
      );

      // Create fake ContactDetails representing API response
      final fakeApiResponse = ContactDetails(
        userId: userId,
        userName: userName,
        name: newApiName, // This is the ONLY display name source
        number: 'test_number',
        profilePic: null,
      );

      // Call sync method (simulating API response processing)
      await syncContactDataFromApi([fakeApiResponse]);

      // Show result
      final updatedApiName = _deviceContactNameCache[userId];
      final updatedFinalName = _finalDisplayNameCache[userId];
      debugPrint('🧪 SIMULATION COMPLETE:');
      debugPrint('   Final API name: "${updatedApiName ?? 'none'}"');
      debugPrint(
        '   Final display cache: "${updatedFinalName ?? 'cleared - will re-evaluate'}"',
      );
      debugPrint(
        '   Name change applied: ${currentApiName != updatedApiName ? 'YES' : 'NO'}',
      );
      debugPrint(
        '   UI will refresh: ${currentFinalName != null && updatedFinalName == null ? 'YES' : 'NO'}',
      );
    }
  }

  // 🧪 TEST METHOD: Test API-only name display across all screens
  Future<void> testApiOnlyNameDisplay(int userId, String newApiName) async {
    if (kDebugMode) {
      debugPrint('🧪 TESTING API-ONLY NAME DISPLAY for userId=$userId');
      debugPrint(
        '   New API name: "$newApiName" (ignores local device contacts)',
      );

      await simulateApiNameUpdate(userId, newApiName);

      debugPrint('🧪 TEST COMPLETE: All screens should show API name');
      debugPrint('   Expected display name: "$newApiName"');
      debugPrint(
        '   Screens affected: Chat List, Call Screen, Starred Messages, etc.',
      );
    }
  }
}
