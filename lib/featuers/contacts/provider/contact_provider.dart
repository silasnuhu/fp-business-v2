// import 'package:flutter/foundation.dart';
// import 'package:flutter_contacts/flutter_contacts.dart';
// import 'package:whoxa/core/error/app_error.dart';
// import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
// import 'package:whoxa/featuers/contacts/data/model/get_contact_model.dart';
// import 'package:whoxa/featuers/contacts/data/repository/contact_repo.dart';

// class ContactListProvider with ChangeNotifier {
//   final ContactRepo _contactRepo;

//   ContactListProvider(this._contactRepo);

//   bool _isLoading = false;
//   bool _isInitialized = false;
//   String? _errorMessage;
//   bool _isInternetIssue = false;

//   List<ContactModel> _allContacts = [];
//   List<ContactModel> _filteredChatContacts = [];
//   List<ContactModel> _filteredInviteContacts = [];
//   List<ContactModel> _chatContacts = [];
//   List<ContactModel> _inviteContacts = [];

//   // Getters
//   bool get isLoading => _isLoading;
//   String? get errorMessage => _errorMessage;
//   bool get isInternetIssue => _isInternetIssue;
//   List<ContactModel> get chatContacts => _filteredChatContacts;
//   List<ContactModel> get inviteContacts => _filteredInviteContacts;

//   // Initialize contacts only once
//   Future<void> initializeContacts() async {
//     if (!_isInitialized) {
//       await loadContacts();
//       _isInitialized = true;
//     }
//   }

//   // Load contacts from both device and API
//   Future<void> loadContacts() async {
//     _isLoading = true;
//     _errorMessage = null;
//     _isInternetIssue = false;
//     notifyListeners();

//     try {
//       // 1. Request contacts permission
//       bool permissionGranted = await FlutterContacts.requestPermission();

//       if (!permissionGranted) {
//         _errorMessage = 'Contact permission denied';
//         _isLoading = false;
//         notifyListeners();
//         return;
//       }

//       // 2. Fetch contacts from device
//       final deviceContacts = await FlutterContacts.getContacts(
//         withProperties: true,
//         withPhoto: true,
//       );

//       // 3. Prepare contact details for API
//       List<Map<String, dynamic>> contactsForApi = [];
//       for (var contact in deviceContacts) {
//         if (contact.phones.isNotEmpty) {
//           for (var phone in contact.phones) {
//             String cleanNumber = _cleanPhoneNumber(phone.number);
//             if (cleanNumber.isNotEmpty) {
//               contactsForApi.add({
//                 'name': contact.displayName,
//                 'number': cleanNumber, // Send as string to avoid parsing issues
//               });
//             }
//           }
//         }
//       }

//       // 4. Send contacts to API to get matches
//       final apiResponse = await _contactRepo.contactGet(contactsForApi);

//       if (apiResponse.status == true && apiResponse.data != null) {
//         // 5. Process API response - Filter out null values and add logging
//         debugPrint(
//           'API Response received. Contact details length: ${apiResponse.data!.contactDetails?.length ?? 0}',
//         );

//         final validContactDetails =
//             (apiResponse.data!.contactDetails ?? [])
//                 .where((contact) => contact != null)
//                 .cast<ContactDetails>()
//                 .toList();

//         debugPrint(
//           'Valid contacts after filtering nulls: ${validContactDetails.length}',
//         );

//         processContacts(deviceContacts, validContactDetails);
//       } else {
//         _errorMessage = apiResponse.message ?? 'Failed to load contacts';
//         debugPrint('API Response failed: ${apiResponse.message}');
//       }
//     } on AppError catch (e) {
//       final errorData = extractErrorData(e);
//       _errorMessage = errorData?['message'] ?? 'Unknown error';
//       _isInternetIssue = _errorMessage!.contains('No internet connection');
//     } catch (e) {
//       _errorMessage = 'Failed to load contacts: ${e.toString()}';
//       debugPrint('Contact loading error: $e');
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   // Clean phone number to ensure consistent format
//   String _cleanPhoneNumber(String phoneNumber) {
//     // Remove all non-numeric characters
//     String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

//     // Remove leading zeros
//     while (cleanNumber.startsWith('0')) {
//       cleanNumber = cleanNumber.substring(1);
//     }

//     // Ensure it's not too short
//     if (cleanNumber.length < 6) {
//       return '';
//     }

//     return cleanNumber;
//   }

//   // Process and categorize contacts
//   void processContacts(
//     List<Contact> deviceContacts,
//     List<ContactDetails> apiContacts,
//   ) {
//     _allContacts = [];
//     _chatContacts = [];
//     _inviteContacts = [];

//     // Create a map of API contacts for quick lookup
//     Map<String, ContactDetails> apiContactsMap = {};
//     for (var contact in apiContacts) {
//       // Add null check for contact and its properties
//       if (contact != null && contact.number != null) {
//         // Clean the API contact number for consistent matching
//         String cleanApiNumber = _cleanPhoneNumber(contact.number!);
//         if (cleanApiNumber.isNotEmpty) {
//           apiContactsMap[cleanApiNumber] = contact;
//         }
//       }
//     }

//     // Process device contacts and categorize based on API data
//     for (var contact in deviceContacts) {
//       if (contact.phones.isEmpty) continue;

//       for (var phone in contact.phones) {
//         String cleanNumber = _cleanPhoneNumber(phone.number);
//         if (cleanNumber.isEmpty) continue;

//         // Check if this contact exists in API results
//         final apiContact = apiContactsMap[cleanNumber];

//         // Create model
//         final contactModel = ContactModel(
//           name: contact.displayName,
//           phoneNumber: cleanNumber,
//           userId: apiContact?.userId?.toString(),
//           photo: contact.photo,
//         );

//         _allContacts.add(contactModel);

//         // Categorize based on userId
//         if (apiContact?.userId != null) {
//           _chatContacts.add(contactModel);
//         } else {
//           _inviteContacts.add(contactModel);
//         }
//       }
//     }

//     // Sort contacts alphabetically
//     _chatContacts.sort((a, b) => a.name.compareTo(b.name));
//     _inviteContacts.sort((a, b) => a.name.compareTo(b.name));

//     // Initialize filtered lists
//     _filteredChatContacts = List.from(_chatContacts);
//     _filteredInviteContacts = List.from(_inviteContacts);
//   }

//   // Search functionality
//   void searchContacts(String query) {
//     if (query.isEmpty) {
//       _filteredChatContacts = List.from(_chatContacts);
//       _filteredInviteContacts = List.from(_inviteContacts);
//     } else {
//       _filteredChatContacts =
//           _chatContacts
//               .where(
//                 (contact) =>
//                     contact.name.toLowerCase().contains(query.toLowerCase()) ||
//                     contact.phoneNumber.contains(query),
//               )
//               .toList();

//       _filteredInviteContacts =
//           _inviteContacts
//               .where(
//                 (contact) =>
//                     contact.name.toLowerCase().contains(query.toLowerCase()) ||
//                     contact.phoneNumber.contains(query),
//               )
//               .toList();
//     }
//     notifyListeners();
//   }

//   // Refresh contacts
//   Future<void> refreshContacts() async {
//     await loadContacts();
//   }

//   // Invite a contact
//   Future<void> inviteContact(ContactModel contact) async {
//     // Implement SMS invitation logic here
//     // This could use a platform channel to send an SMS or share via other methods
//     debugPrint('Inviting contact: ${contact.name} - ${contact.phoneNumber}');

//     // For demonstration purposes, we'll just show a success message
//     // In a real app, you'd implement the actual invitation logic
//   }
// }
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart'
    hide PermissionStatus;
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
import 'package:whoxa/featuers/contacts/data/model/contact_sync_models.dart';
import 'package:whoxa/featuers/contacts/data/model/get_contact_model.dart';
import 'package:whoxa/featuers/contacts/data/repository/contact_repo.dart';
import 'package:whoxa/featuers/contacts/services/countrycode_service.dart';
import 'package:whoxa/core/services/device_country_code_service.dart';
import 'package:whoxa/main.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart' as global;
import 'package:whoxa/widgets/global.dart';

class ContactListProvider with ChangeNotifier {
  final ContactRepo _contactRepo;

  ContactListProvider(this._contactRepo) {
    _initializeCountryCodeService();
  }

  bool _isLoading = false;
  bool _isInitialized = false;
  // Guards the "re-sync even when the device address book didn't change"
  // path so it runs at most once per app session. Needed because
  // `contact_list` rows on the backend are only created by our own
  // `/contacts/sync` upload — a peer who registers AFTER our last sync
  // produces no local address-book diff, so without this we'd never
  // re-upload and they'd stay invisible until the cache-staleness timer
  // (below) eventually tripped.
  bool _syncedThisSession = false;
  String? _errorMessage;
  bool _isInternetIssue = false;
  bool _countryCodeServiceInitialized = false;
  String? _defaultCountryCode; // User's country code from storage

  // ========== CACHED OWN NUMBER (for fast filtering) ==========
  // These are pre-computed once and reused for all 700+ contact checks
  String? _cachedOwnNumberClean;
  String? _cachedOwnNumberDigitsOnly;
  String? _cachedOwnNumberNoLeadingZeros;
  bool _ownNumberCacheValid = false;

  List<ContactModel> _allContacts = [];
  List<ContactModel> _filteredChatContacts = [];
  List<ContactModel> _filteredInviteContacts = [];
  List<ContactModel> _chatContacts = [];
  List<ContactModel> _inviteContacts = [];
  final List<ContactDetails> _demoContactList = [];

  List<int> selectedUserIds = [];

  void addUserSelection(int id) {
    selectedUserIds.add(id);
    notifyListeners();
  }

  void removeUserSelection(int id) {
    selectedUserIds.remove(id);
    notifyListeners();
  }

  int tabIndex = 0;

  void updateTabIndex(int val) {
    tabIndex = val;
    notifyListeners();
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInternetIssue => _isInternetIssue;
  List<ContactModel> get fullContactList => _allContacts;

  /// ✅ For demo accounts, return only API contacts (no device contacts)
  /// For regular accounts, return only registered contacts (like WhatsApp)
  List<ContactModel> get chatContacts {
    if (isDemo) {
      // Demo account: Show only API contacts (already processed in processContacts)
      debugPrint(
        '📱 DEMO MODE: Returning API contacts only (${_filteredChatContacts.length})',
      );
      return _filteredChatContacts;
    } else {
      // Regular account: Show only registered contacts
      return _filteredChatContacts;
    }
  }

  List<ContactModel> get inviteContacts => _filteredInviteContacts;
  List<ContactDetails> get demoContactList => _demoContactList;

  // Initialize country code service and get device/location-based country code
  // Priority logic for contacts without country code:
  // Priority 1: Contact's saved country code (if exists)
  // Priority 2: GPS-detected country code (most accurate)
  // Priority 3: Device locale/region (when location is disabled)
  // Priority 4: Fallback to +1 (US) only as last resort
  Future<void> _initializeCountryCodeService() async {
    if (!_countryCodeServiceInitialized) {
      await CountryCodeService.initialize();

      try {
        // Ensure DeviceCountryCodeService is initialized
        if (!DeviceCountryCodeService.instance.isInitialized) {
          await DeviceCountryCodeService.instance.initialize();
        }

        // Get detection source for logging
        final detectionSource =
            DeviceCountryCodeService.instance.getDetectionSource();

        // Use detected country code from any valid source (GPS, locale, manual)
        // Only use fallback if detection truly failed
        if (detectionSource != 'fallback' && detectionSource != 'unknown') {
          // Use device-detected country code (GPS, locale, or manual)
          _defaultCountryCode =
              DeviceCountryCodeService.instance.getDefaultDialCode();
          debugPrint(
            '📍 Contact country code detected: +$_defaultCountryCode '
            '(${DeviceCountryCodeService.instance.getDefaultIsoCode()}) '
            'via $detectionSource',
          );
        } else {
          // True fallback - no detection method worked
          _defaultCountryCode = '1';
          debugPrint(
            '📍 No country detection available (source: $detectionSource), using fallback: +$_defaultCountryCode',
          );
        }
      } catch (e) {
        debugPrint('Error initializing device country code: $e');
        // Fallback to +1 (US) when detection fails completely
        _defaultCountryCode = '1';
        debugPrint('Using fallback country code: +$_defaultCountryCode');
      }

      _countryCodeServiceInitialized = true;
    }
  }

  /// FAST INIT: Load cache first (instant UI), then sync in background.
  /// Always triggers background sync to detect new contacts on device.
  Future<void> initializeContacts() async {
    debugPrint(
      '🔍 ContactListProvider.initializeContacts() called - _isInitialized: $_isInitialized',
    );

    // -------------------------------------------------------
    // ALREADY INITIALIZED: Just trigger background sync for new activity
    // -------------------------------------------------------
    if (_isInitialized) {
      debugPrint(
        '✅ Already initialized — triggering background sync for new activity',
      );
      // Still run background sync to detect new contacts (non-blocking)
      _backgroundSync()
          .then((_) {
            debugPrint('✅ Background sync (re-check) completed');
          })
          .catchError((e) {
            debugPrint('❌ Background sync (re-check) failed: $e');
          });
      return;
    }

    debugPrint('🚀 Starting contact initialization...');

    // -------------------------------------------------------
    // STEP 1: Load cached contacts → show UI instantly (~50ms)
    // -------------------------------------------------------
    final hasCache = await loadContactsFromCache();
    if (hasCache) {
      _isInitialized = true;
      debugPrint('✅ Cache loaded — UI ready instantly');
    }

    // -------------------------------------------------------
    // STEP 2: Background sync (does NOT block UI)
    // -------------------------------------------------------
    // Use Future (not await) so it runs in background
    _backgroundSync()
        .then((_) {
          debugPrint('✅ Background sync completed');
        })
        .catchError((e) {
          debugPrint('❌ Background sync failed: $e');
        });

    // If no cache (first time), wait for sync to finish
    if (!hasCache) {
      debugPrint('📱 No cache found — waiting for first sync...');
      await _backgroundSync();
      _isInitialized = true;
      debugPrint('✅ First sync completed - _isInitialized set to true');
    }
  }

  /// Background sync: read device contacts → diff → sync API → get-contacts → update UI.
  /// This runs WITHOUT blocking the UI.
  Future<void> _backgroundSync() async {
    try {
      await _initializeCountryCodeService();
      await loadContacts();
    } catch (e) {
      debugPrint('Background sync error: $e');
    }
  }

  // Force contact upload regardless of initialization state (use after logout)
  Future<void> forceUploadContacts() async {
    debugPrint(
      '🔄 forceUploadContacts() called - forcing contact upload regardless of initialization state',
    );
    await _initializeCountryCodeService();
    await loadContacts();
    _isInitialized = true;
    debugPrint('✅ Force contact upload completed');
  }

  // Load contacts from both device and API
  Future<void> loadContacts() async {
    // ✅ FIX: Only show loading indicator if no contacts are currently displayed
    // This allows cached contacts to remain visible during background sync
    final showLoading = _chatContacts.isEmpty;

    if (showLoading) {
      _isLoading = true;
    }
    _errorMessage = null;
    _isInternetIssue = false;

    if (showLoading) {
      notifyListeners();
    }

    try {
      // Ensure country code service is initialized
      await _initializeCountryCodeService();

      // ✅ Update own number cache ONCE at start (used for filtering 700+ contacts)
      _updateOwnNumberCache();

      // 1. ✅ FIX: Check contacts permission status first to avoid duplicate iOS prompts
      debugPrint('🔍 Checking contact permission status...');

      // First check if we already have permission without triggering a new request
      final currentPermission = await Permission.contacts.status;
      debugPrint('📱 Current contact permission status: $currentPermission');

      bool permissionGranted = currentPermission.isGranted;

      if (!permissionGranted) {
        debugPrint(
          '🔐 Contact permission not granted, requesting permission...',
        );
        // Only request permission if we don't already have it
        final permissionStatus = await FlutterContacts.permissions.request(
          PermissionType.readWrite,
        );
        permissionGranted = permissionStatus == PermissionStatus.granted;

        if (!permissionGranted) {
          debugPrint('❌ Contact permission request denied');
          _errorMessage = 'Contact permission denied';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      debugPrint('✅ Contact permission confirmed: $permissionGranted');

      // 2. Fetch contacts from device
      final deviceContacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone, ContactProperty.photoThumbnail},
      );

      // 3. Prepare contact details for API
      List<Map<String, dynamic>> contactsForApi = [];
      Map<String, Map<String, dynamic>> uniqueContacts = {};

      for (var contact in deviceContacts) {
        if (contact.phones.isEmpty) continue;

        final rawDisplayName = contact.displayName ?? '';
        String bestName =
            rawDisplayName.trim().isEmpty ? 'Unknown' : rawDisplayName;

        for (var phone in contact.phones) {
          final phoneData = _parsePhoneNumber(phone.number);
          String countryCode = phoneData['country_code'] ?? '';
          String number = phoneData['number'] ?? '';

          if (number.isEmpty || number.length < 6) {
            // Country-code parsing failed (odd formatting, unknown code,
            // extension, …). Don't drop the contact — fall back to the raw
            // digits, trimmed to the last 10, which is exactly what the
            // backend does to match (`normalizePhoneNumber` = digits.slice(-10)).
            final rawDigits = phone.number.replaceAll(RegExp(r'[^0-9]'), '');
            final fallback = rawDigits.length > 10
                ? rawDigits.substring(rawDigits.length - 10)
                : rawDigits;
            if (fallback.length < 6) continue;
            countryCode = '';
            number = fallback;
          }

          // Full normalized key (e.g., "91|9023489473")
          String key = '$countryCode|$number';

          if (!uniqueContacts.containsKey(key)) {
            // First time seeing this number → add it
            uniqueContacts[key] = {
              'name': bestName,
              'number': number,
              'country_code': countryCode,
            };
          } else {
            // Already seen → update name only if the current one is better (non-empty)
            if (bestName.isNotEmpty && bestName != 'Unknown') {
              uniqueContacts[key]!['name'] = bestName;
            }
          }
        }
      }

      // Convert map values to list
      contactsForApi = uniqueContacts.values.toList();

      debugPrint('Contacts prepared for API: ${contactsForApi.length}');
      debugPrint(
        'Sample contact: ${contactsForApi.isNotEmpty ? contactsForApi.first : 'None'}',
      );

      // 4. Sync contacts with backend.
      // NEW backend has exactly one contacts-write endpoint (`POST
      // /contacts/sync`, see ContactsController) — no separate
      // create-contacts vs incremental delta-sync split like OLD had. It's
      // a plain upsert keyed on (user_id, contact_user_id): re-sending the
      // full current contact list every time is intentional and cheap —
      // Postgres skips any row whose phone number didn't change via a WHERE
      // guard (see ContactsService.sync), so there's nothing to gain from
      // hand-rolling a client-side diff into a separate call. `findChanges`
      // below is kept purely as a local heuristic (compares against the
      // last-saved snapshot) so we can skip the network round-trip entirely
      // when nothing changed on-device since last sync.
      final savedSyncData = await loadSyncData();

      // Build phone -> contact map for diff detection (use number as key for matching)
      final contactsByPhone = <String, Map<String, dynamic>>{};
      for (final c in contactsForApi) {
        final phone = c['number'] as String? ?? '';
        if (phone.isNotEmpty) {
          contactsByPhone[phone] = c;
        }
      }

      bool shouldRefreshContacts = false;

      if (savedSyncData.isFirstSync) {
        debugPrint(
          '📱 First time sync: sending ${contactsForApi.length} contacts',
        );
        shouldRefreshContacts = await doFullSync(
          allContactsForApi: contactsForApi,
          contactsByPhone: contactsByPhone,
        );
      } else {
        debugPrint(
          '🔄 Checking for local changes against ${savedSyncData.contacts.length} saved contacts',
        );
        final changes = findChanges(
          currentDeviceContacts: contactsByPhone,
          savedContacts: savedSyncData.contacts,
        );

        if (changes.isEmpty) {
          if (!_syncedThisSession) {
            // No local diff, but re-upload once per session so the backend
            // can create `contact_list` rows for peers who registered since
            // our last sync (that event leaves no trace in the device
            // address book, so `findChanges` can't see it).
            debugPrint(
              'ℹ️ No local changes, but first sync this session — re-syncing to catch newly-registered peers',
            );
            shouldRefreshContacts = await doFullSync(
              allContactsForApi: contactsForApi,
              contactsByPhone: contactsByPhone,
            );
          } else {
            debugPrint('✅ No changes detected - skipping sync API call');
          }
        } else {
          debugPrint(
            '📤 ${changes.totalChanges} local changes detected — re-syncing full contact list',
          );
          shouldRefreshContacts = await doFullSync(
            allContactsForApi: contactsForApi,
            contactsByPhone: contactsByPhone,
          );
        }
      }

      _syncedThisSession = true;

      // Check cache staleness as fallback (refresh periodically even if no changes)
      if (!shouldRefreshContacts) {
        shouldRefreshContacts = await isCacheStale();
      }

      // 5. Conditionally fetch registered contacts from get-contacts API
      if (shouldRefreshContacts) {
        debugPrint('🔄 Refreshing contacts from get-contacts API...');
        try {
          final validContactDetails = await _contactRepo.getContactsList();

          debugPrint(
            'Get-contacts API Response received. Contact details length: ${validContactDetails.length}',
          );
          debugPrint(
            'Sample contact from get-contacts: ${validContactDetails.isNotEmpty ? "${validContactDetails.first.name} - ${validContactDetails.first.profilePic}" : "None"}',
          );

          _demoContactList.clear();
          if (mobileNum == "9000000001") {
            _demoContactList.addAll(validContactDetails);
            logger.i("_demoContactList :::: ${jsonEncode(_demoContactList)}");
          }

          // Feed the backend profile data into the FALLBACK cache FIRST, then
          // process device contacts — processContacts() -> _notifyContactNameService()
          // pushes the device-saved names (priority 1) as the last write and
          // clears the final-name cache itself.
          await ContactNameService.instance.syncContactDataFromApi(
            validContactDetails,
          );
          processContacts(deviceContacts, validContactDetails);

          // 6. Cache for instant load next time
          await saveCachedContacts(validContactDetails);

          notifyListeners();
        } catch (e) {
          _errorMessage = 'Failed to get updated contacts: $e';
          debugPrint('get-contacts failed: $e');
        }
      } else {
        debugPrint(
          '⏭️ Skipping get-contacts API - no changes detected, using cached data',
        );
        // Use cached contacts for UI (already loaded in initializeContacts)
        // Just process with existing cache to ensure UI is consistent
        final cached = await loadCachedContacts();
        if (cached.isNotEmpty) {
          final cachedContactDetails =
              cached.contacts
                  .map(
                    (c) => ContactDetails(
                      name: c.name,
                      number: c.number,
                      userId: c.userId,
                      userName: c.userName,
                      profilePic: c.profilePic,
                      isChatLock: c.isChatLock,
                      chatId: c.chatId,
                    ),
                  )
                  .toList();
          processContacts(deviceContacts, cachedContactDetails);
          // Note: _notifyContactNameService() inside processContacts() now clears
          // the cache and updates with fresh device names, then calls notifyListeners()
        }
      }
    } on AppError catch (e) {
      final errorData = extractErrorData(e);
      _errorMessage = errorData?['message'] ?? 'Unknown error';
      _isInternetIssue = e.isNetworkError;
    } catch (e) {
      _errorMessage = 'Failed to load contacts: ${e.toString()}';
      debugPrint('Contact loading error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Parse phone number to extract country code and number using the service
  Map<String, String> _parsePhoneNumber(String phoneNumber) {
    // Remove all non-numeric characters except +
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\+0-9]'), '');

    String countryCode = '';
    String number = '';

    if (cleanNumber.startsWith('+')) {
      // Phone number has country code - use the service to find it
      final matchedCode = CountryCodeService.findBestMatchingCountryCode(
        cleanNumber,
      );

      if (matchedCode != null) {
        countryCode = matchedCode;
        number = cleanNumber.substring(
          matchedCode.length + 1,
        ); // +1 for the '+' sign
      } else {
        // Fallback: try to extract first 1-4 digits as country code
        for (int i = 1; i <= 4 && i < cleanNumber.length; i++) {
          String potentialCode = cleanNumber.substring(1, i + 1);
          if (CountryCodeService.isValidCountryCode(potentialCode)) {
            countryCode = potentialCode;
            number = cleanNumber.substring(i + 1);
            break;
          }
        }
      }
    } else {
      // No country code present, assume it's a local number
      // Remove leading zeros
      while (cleanNumber.startsWith('0')) {
        cleanNumber = cleanNumber.substring(1);
      }

      // Use GPS-detected country code for local numbers (Priority 2)
      // Only use GPS detection, NOT device locale (locale may not reflect actual location)
      if (_defaultCountryCode != null && _defaultCountryCode!.isNotEmpty) {
        // Validate that the country code exists in our data
        if (CountryCodeService.isValidCountryCode(_defaultCountryCode!)) {
          countryCode = _defaultCountryCode!;
          debugPrint(
            '📍 Using country code: +$countryCode for local number: $cleanNumber',
          );
        } else {
          // Invalid code, use fallback +1 (US)
          countryCode = '1';
          debugPrint(
            '📍 Invalid country code: $_defaultCountryCode, using fallback: +$countryCode',
          );
        }
      } else {
        // No country code available, use fallback +1 (US)
        countryCode = '1';
        debugPrint(
          '📍 No country code available, using fallback: +$countryCode for local number: $cleanNumber',
        );
      }

      number = cleanNumber;
    }

    // Clean the number part
    number = _cleanPhoneNumber(number);

    // Validate minimum length
    if (number.length < 6) {
      return {'country_code': '', 'number': ''};
    }

    debugPrint(
      'Parsed: $phoneNumber -> countryCode: $countryCode, number: $number',
    );

    return {'country_code': countryCode, 'number': number};
  }

  /// Last 10 digits of a number — mirrors the backend's `normalizePhoneNumber`
  /// (digits-only, then `slice(-10)`) so client-side matching lines up with
  /// how `/contacts/sync` actually pairs uploaded numbers to users.
  String _last10(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 10
        ? digits.substring(digits.length - 10)
        : digits;
  }

  // Clean phone number to ensure consistent format (number part only)
  String _cleanPhoneNumber(String phoneNumber) {
    // Remove all non-numeric characters
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // Remove leading zeros
    while (cleanNumber.startsWith('0')) {
      cleanNumber = cleanNumber.substring(1);
    }

    return cleanNumber;
  }

  // ========== OWN NUMBER CACHE MANAGEMENT ==========

  /// Update the cached own number values. Call this:
  /// - At start of loadContacts()
  /// - When user's number might have changed
  /// - After login/logout
  void _updateOwnNumberCache() {
    if (global.mobileNum.isEmpty) {
      _ownNumberCacheValid = false;
      _cachedOwnNumberClean = null;
      _cachedOwnNumberDigitsOnly = null;
      _cachedOwnNumberNoLeadingZeros = null;
      return;
    }

    // Pre-compute all variations ONCE
    _cachedOwnNumberClean = _cleanPhoneNumber(global.mobileNum);

    _cachedOwnNumberDigitsOnly = global.mobileNum.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    _cachedOwnNumberNoLeadingZeros = _cachedOwnNumberDigitsOnly!.replaceFirst(
      RegExp(r'^0+'),
      '',
    );

    // Handle common country code scenarios (like +91 for India)
    if (_cachedOwnNumberNoLeadingZeros!.startsWith('91') &&
        _cachedOwnNumberNoLeadingZeros!.length > 10) {
      _cachedOwnNumberNoLeadingZeros = _cachedOwnNumberNoLeadingZeros!
          .substring(2);
    }

    _ownNumberCacheValid = true;
    debugPrint('✅ Own number cache updated: $_cachedOwnNumberClean');
  }

  /// Clear the own number cache (call on logout/reset)
  void _clearOwnNumberCache() {
    _ownNumberCacheValid = false;
    _cachedOwnNumberClean = null;
    _cachedOwnNumberDigitsOnly = null;
    _cachedOwnNumberNoLeadingZeros = null;
  }

  // Helper method to check if a contact is the user's own number
  // OPTIMIZED: Uses cached values instead of recalculating for every contact
  bool _isOwnNumber(String contactNumber) {
    // Ensure cache is valid
    if (!_ownNumberCacheValid || _cachedOwnNumberClean == null) {
      return false; // Can't filter without own number
    }

    // Clean contact number ONCE per contact (not own number)
    final cleanContactNumber = _cleanPhoneNumber(contactNumber);

    final contactNumberDigitsOnly = contactNumber.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    String contactNumberNoLeadingZeros = contactNumberDigitsOnly.replaceFirst(
      RegExp(r'^0+'),
      '',
    );

    // Handle country code for contact
    if (contactNumberNoLeadingZeros.startsWith('91') &&
        contactNumberNoLeadingZeros.length > 10) {
      contactNumberNoLeadingZeros = contactNumberNoLeadingZeros.substring(2);
    }

    /* enable to check debugging own number filter
    debugPrint('=== DEBUGGING OWN NUMBER FILTER ===');
    debugPrint('  Own number (cached clean): "$_cachedOwnNumberClean"');
    debugPrint('  Own number (cached digits): "$_cachedOwnNumberDigitsOnly"');
    debugPrint('  Own number (cached no zeros): "$_cachedOwnNumberNoLeadingZeros"');
    debugPrint('  Contact number: "$contactNumber"');
    debugPrint('  Contact (clean): "$cleanContactNumber"');
    debugPrint('  Contact (digits): "$contactNumberDigitsOnly"');
    debugPrint('  Contact (no zeros): "$contactNumberNoLeadingZeros"');
    */

    // Check all combinations using CACHED own number values
    bool isMatch =
        _cachedOwnNumberClean == cleanContactNumber ||
        _cachedOwnNumberDigitsOnly == contactNumberDigitsOnly ||
        _cachedOwnNumberNoLeadingZeros == contactNumberNoLeadingZeros ||
        _cachedOwnNumberNoLeadingZeros == cleanContactNumber ||
        _cachedOwnNumberClean == contactNumberNoLeadingZeros;

    /* enable to check debugging own number filter
    debugPrint('  FINAL MATCH RESULT: $isMatch');
    debugPrint('=== END OWN NUMBER FILTER DEBUG ===');
    */

    return isMatch;
  }

  // Process and categorize contacts
  void processContacts(
    List<Contact> deviceContacts,
    List<ContactDetails> apiContacts,
  ) {
    _allContacts = [];
    _chatContacts = [];
    _inviteContacts = [];

    // ✅ DEMO MODE: For demo accounts, ONLY show contacts from API (no device contacts)
    if (isDemo) {
      debugPrint(
        '🎭 DEMO MODE: Processing ${apiContacts.length} API contacts only (ignoring device contacts)',
      );

      for (var apiContact in apiContacts) {
        if (apiContact.number == null || apiContact.number!.isEmpty) continue;

        // Build full phone number with country code from API contact
        String fullPhoneNumber;
        if (apiContact.countryCode != null &&
            apiContact.countryCode!.isNotEmpty) {
          // API contact has country code - use it
          String cc = apiContact.countryCode!;
          if (!cc.startsWith('+')) cc = '+$cc';
          fullPhoneNumber = '$cc${apiContact.number}';
        } else {
          // No country code from API - use the number as-is
          fullPhoneNumber = apiContact.number!;
        }

        final contactModel = ContactModel(
          name: apiContact.name ?? 'Unknown',
          phoneNumber: fullPhoneNumber,
          userId: apiContact.userId?.toString(),
          photo: null,
          profilePicUrl: apiContact.profilePic,
          isChatLock: apiContact.isChatLock,
          chatId: apiContact.chatId,
        );

        _allContacts.add(contactModel);
        _chatContacts.add(
          contactModel,
        ); // All API contacts treated as registered for demo
      }

      // Sort contacts alphabetically
      _chatContacts.sort((a, b) => a.name.compareTo(b.name));

      // Set filtered lists
      _filteredChatContacts = List.from(_chatContacts);
      _filteredInviteContacts = []; // No invite contacts for demo mode

      debugPrint(
        '🎭 DEMO MODE: Showing ${_filteredChatContacts.length} API contacts',
      );

      // Notify listeners and return early
      _notifyContactNameService();
      notifyListeners();
      return;
    }

    // ✅ REGULAR MODE: Process device contacts and match with API
    // Create a map of API contacts for quick lookup. Index by BOTH the
    // cleaned number and its last-10-digit form so a device contact still
    // matches when country-code parsing on either side disagrees (the
    // backend itself matches on last-10, see normalizePhoneNumber).
    Map<String, ContactDetails> apiContactsMap = {};
    for (var contact in apiContacts) {
      // Add null check for contact's number property
      if (contact.number != null) {
        // Clean the API contact number for consistent matching
        String cleanApiNumber = _cleanPhoneNumber(contact.number!);
        if (cleanApiNumber.isNotEmpty) {
          apiContactsMap[cleanApiNumber] = contact;
          apiContactsMap.putIfAbsent(_last10(cleanApiNumber), () => contact);
        }
      }
    }

    debugPrint('Processing ${deviceContacts.length} device contacts');
    final Set<String> seenNumbers = <String>{};
    int filteredOutCount = 0;

    // Process device contacts and categorize based on API data
    for (var contact in deviceContacts) {
      if (contact.phones.isEmpty) continue;

      for (var phone in contact.phones) {
        final phoneData = _parsePhoneNumber(phone.number);
        String cleanNumber = phoneData['number']!;
        if (cleanNumber.isEmpty) {
          // Parsing failed — fall back to raw digits (last 10) so a
          // registered contact isn't silently dropped from the list.
          cleanNumber = _last10(phone.number);
          if (cleanNumber.length < 6) continue;
        }

        if (seenNumbers.contains(cleanNumber)) {
          continue; // Duplicate number, skip
        }

        // Skip if this is the user's own number - check multiple formats
        String fullNumberWithCountryCode = '';
        if (phoneData['country_code']!.isNotEmpty) {
          fullNumberWithCountryCode =
              '+${phoneData['country_code']}${phoneData['number']}';
        }

        if (_isOwnNumber(phone.number) ||
            _isOwnNumber(cleanNumber) ||
            _isOwnNumber(fullNumberWithCountryCode) ||
            _isOwnNumber(
              '+${phoneData['country_code']} ${phoneData['number']}',
            )) {
          debugPrint('*** FILTERING OUT OWN NUMBER ***');
          debugPrint('Contact: ${contact.displayName}');
          debugPrint('Original: ${phone.number}');
          debugPrint('Clean: $cleanNumber');
          debugPrint('With country code: $fullNumberWithCountryCode');
          debugPrint('*** END FILTER OUT ***');
          filteredOutCount++;
          continue;
        }

        seenNumbers.add(cleanNumber);

        // Check if this contact exists in API results — try the parsed
        // number first, then the last-10 fallback key.
        final apiContact =
            apiContactsMap[cleanNumber] ?? apiContactsMap[_last10(cleanNumber)];

        // Build full phone number with country code (if available)
        // Priority: Use saved country code from contact, don't override with device-detected
        String fullPhoneNumber;
        if (phoneData['country_code']!.isNotEmpty) {
          // Contact has a saved country code - preserve it
          fullPhoneNumber =
              '+${phoneData['country_code']}${phoneData['number']}';
        } else {
          // No country code in contact - let ContactModel apply device-detected
          fullPhoneNumber = cleanNumber;
        }

        // Create model
        final contactModel = ContactModel(
          name: contact.displayName.toString(),
          phoneNumber: fullPhoneNumber,
          userId: apiContact?.userId?.toString(),
          photo: null, // Don't use device photo anymore
          profilePicUrl: apiContact?.profilePic, // Use backend profile picture
          isChatLock: apiContact?.isChatLock,
          chatId: apiContact?.chatId,
        );

        _allContacts.add(contactModel);

        // Categorize based on userId
        if (apiContact?.userId != null) {
          _chatContacts.add(contactModel);
        } else {
          _inviteContacts.add(contactModel);
        }
      }
    }

    debugPrint('Filtered out $filteredOutCount own numbers from contact list');
    debugPrint(
      'Final contact counts - Chat: ${_chatContacts.length}, Invite: ${_inviteContacts.length}',
    );

    // Sort contacts alphabetically
    _chatContacts.sort((a, b) => a.name.compareTo(b.name));
    _inviteContacts.sort((a, b) => a.name.compareTo(b.name));

    // Initialize filtered lists with additional own number filtering as final safety check
    _filteredChatContacts =
        _chatContacts
            .where(
              (contact) =>
                  !_isOwnNumber(contact.phoneNumber) &&
                  !_isOwnNumber(
                    '+${global.contrycode.replaceAll('+', '')} ${contact.phoneNumber}',
                  ),
            )
            .toList();

    _filteredInviteContacts =
        _inviteContacts
            .where(
              (contact) =>
                  !_isOwnNumber(contact.phoneNumber) &&
                  !_isOwnNumber(
                    '+${global.contrycode.replaceAll('+', '')} ${contact.phoneNumber}',
                  ),
            )
            .toList();

    debugPrint('Final safety filter applied:');
    debugPrint('  Chat contacts before final filter: ${_chatContacts.length}');
    debugPrint(
      '  Chat contacts after final filter: ${_filteredChatContacts.length}',
    );
    debugPrint(
      '  Invite contacts before final filter: ${_inviteContacts.length}',
    );
    debugPrint(
      '  Invite contacts after final filter: ${_filteredInviteContacts.length}',
    );

    // ✅ NEW: Log demo mode behavior
    if (isDemo) {
      debugPrint('🎭 DEMO MODE ACTIVE:');
      debugPrint('  - Registered contacts: ${_filteredChatContacts.length}');
      debugPrint(
        '  - Unregistered contacts: ${_filteredInviteContacts.length}',
      );
      debugPrint(
        '  - Total contacts visible to demo user: ${_filteredChatContacts.length + _filteredInviteContacts.length}',
      );
    } else {
      debugPrint('👤 REGULAR MODE:');
      debugPrint(
        '  - Only showing registered contacts: ${_filteredChatContacts.length}',
      );
    }

    // Notify the contact name service that contacts have been updated
    _notifyContactNameService();
  }

  // Search functionality
  void searchContacts(String query) {
    if (query.isEmpty) {
      _filteredChatContacts = List.from(_chatContacts);
      _filteredInviteContacts = List.from(_inviteContacts);
    } else {
      _filteredChatContacts =
          _chatContacts
              .where(
                (contact) =>
                    !_isOwnNumber(
                      contact.phoneNumber,
                    ) && // Additional safety check
                    (contact.name.toLowerCase().contains(query.toLowerCase()) ||
                        contact.phoneNumber.contains(query)),
              )
              .toList();

      _filteredInviteContacts =
          _inviteContacts
              .where(
                (contact) =>
                    !_isOwnNumber(
                      contact.phoneNumber,
                    ) && // Additional safety check
                    (contact.name.toLowerCase().contains(query.toLowerCase()) ||
                        contact.phoneNumber.contains(query)),
              )
              .toList();
    }

    // ✅ NEW: Debug log for demo mode
    if (isDemo) {
      debugPrint(
        '🔍 DEMO MODE SEARCH: Total visible contacts after search: ${_filteredChatContacts.length + _filteredInviteContacts.length}',
      );
    }

    notifyListeners();
  }

  // Refresh contacts.
  // [force] = user-triggered hard refresh (pull-to-refresh / refresh button):
  // wipes the local sync snapshot + cached contacts so loadContacts() is
  // guaranteed to re-run a full `/contacts/sync` upload AND re-fetch the
  // (now fully paginated) `/contacts` list — the manual recovery path when a
  // contact is missing on this device.
  Future<void> refreshContacts({bool force = false}) async {
    if (force) {
      debugPrint('🔄 refreshContacts(force: true) — clearing sync + cache');
      _syncedThisSession = false;
      await clearSyncData();
      await clearCachedContacts();
    }
    await loadContacts();
  }

  // Invite a contact
  Future<void> inviteContact(ContactModel contact) async {
    // Implement SMS invitation logic here
    // This could use a platform channel to send an SMS or share via other methods
    debugPrint('Inviting contact: ${contact.name} - ${contact.phoneNumber}');
    inviteMe(contact.phoneNumber);
    // For demonstration purposes, we'll just show a success message
    // In a real app, you'd implement the actual invitation logic
  }

  Future<void> inviteMe(String phone) async {
    final uri = Uri.parse('sms:$phone?body=');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }

  // Get country info for a phone number (utility method)
  String? getCountryInfoForNumber(String phoneNumber) {
    final phoneData = _parsePhoneNumber(phoneNumber);
    if (phoneData['country_code']!.isNotEmpty) {
      final countryInfo = CountryCodeService.getCountryInfo(
        phoneData['country_code']!,
      );
      return countryInfo?['name'];
    }
    return null;
  }

  // Utility method to format phone number with country code
  String formatPhoneNumberWithCountryCode(String phoneNumber) {
    final phoneData = _parsePhoneNumber(phoneNumber);
    if (phoneData['country_code']!.isNotEmpty &&
        phoneData['number']!.isNotEmpty) {
      return '+${phoneData['country_code']} ${phoneData['number']}';
    }
    return phoneNumber;
  }

  // Method to update default country code (call this when user's country code changes)
  Future<void> updateDefaultCountryCode(String? newCountryCode) async {
    // Clean the country code - remove + sign if present
    if (newCountryCode != null && newCountryCode.isNotEmpty) {
      _defaultCountryCode =
          newCountryCode.startsWith('+')
              ? newCountryCode.substring(1)
              : newCountryCode;
    } else {
      _defaultCountryCode = null;
    }

    debugPrint('Updated default country code to: $_defaultCountryCode');

    // Optionally, you can save it to storage here if needed
    if (_defaultCountryCode != null && _defaultCountryCode!.isNotEmpty) {
      try {
        // Save with + sign to storage for consistency
        await SecurePrefs.setString(
          SecureStorageKeys.COUNTRY_CODE,
          '+$_defaultCountryCode',
        );
      } catch (e) {
        debugPrint('Error saving country code to storage: $e');
      }
    }

    // If contacts are already loaded, you might want to refresh them
    // to apply the new default country code
    if (_isInitialized) {
      await refreshContacts();
    }
  }

  // Get the current default country code
  String? get defaultCountryCode => _defaultCountryCode;

  // Reset contact provider state (call this on user logout)
  void resetContactProvider() {
    debugPrint('🔄 Resetting ContactListProvider for user logout/login');
    debugPrint('   Previous state - _isInitialized: $_isInitialized');
    _isInitialized = false;
    _syncedThisSession = false;
    _countryCodeServiceInitialized = false;
    _defaultCountryCode = null;
    _allContacts = [];
    _filteredChatContacts = [];
    _filteredInviteContacts = [];
    _chatContacts = [];
    _inviteContacts = [];
    _isLoading = false;
    _errorMessage = null;
    _isInternetIssue = false;

    // ✅ Clear own number cache (will be rebuilt on next sync)
    _clearOwnNumberCache();

    // Clear sync + cache data so next login starts fresh
    clearSyncData();
    clearCachedContacts();

    // Clear the contact name service cache as well
    try {
      ContactNameService.instance.clearCache();
      debugPrint('✅ ContactNameService cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing ContactNameService cache: $e');
    }

    notifyListeners();
    debugPrint(
      '✅ ContactListProvider reset completed - _isInitialized now: $_isInitialized',
    );
  }

  // Method to notify contact name service when contacts are loaded
  void _notifyContactNameService() {
    // This will be called after contacts are processed to update the cache
    try {
      final contactNameService = ContactNameService.instance;

      // ✅ CRITICAL: Clear old cached names FIRST (synchronous) before updating
      // This ensures chatlist won't show stale names
      contactNameService.clearFinalNameCache();

      // ✅ CRITICAL FIX: Create a map of userId to LOCAL DEVICE contact name, not API name
      Map<int, String> localContactMap = {};
      for (final contact in _chatContacts) {
        if (contact.userId != null && contact.userId!.isNotEmpty) {
          final userId = int.tryParse(contact.userId!);
          // Only map a real device-saved name — skip blank / "Unknown"
          // placeholder entries so they don't mask the profile-name fallback.
          final deviceName = contact.name.trim();
          if (userId != null &&
              deviceName.isNotEmpty &&
              deviceName.toLowerCase() != 'unknown') {
            // Use LOCAL device contact name (contact.name is from device contacts)
            localContactMap[userId] = deviceName;

            if (kDebugMode) {
              debugPrint(
                '🏆 _notifyContactNameService: userId=$userId → LOCAL NAME: "$deviceName" (Priority 1)',
              );
            }
          }
        }
      }

      debugPrint(
        '✅ Updating contact name service with ${localContactMap.length} LOCAL device contact names',
      );

      // Update cache (fire-and-forget, but cache is already cleared above)
      contactNameService
          .updateCacheWithContacts(localContactMap)
          .then((_) {
            debugPrint(
              '✅ ContactNameService cache updated with ${localContactMap.length} LOCAL device contact names (Priority 1)',
            );
            // Notify listeners again after cache is updated to refresh UI with new names
            notifyListeners();
          })
          .catchError((e) {
            debugPrint('❌ Error updating ContactNameService: $e');
          });
    } catch (e) {
      debugPrint('❌ Error notifying contact name service: $e');
    }
  }

  // Update the existing processContacts method to include cache notification
  // Note: processContacts is already defined in this class, so we add the notification there

  // ==========================================================================
  // CACHE: Save / Load / Clear cached contacts (for instant UI)
  // ==========================================================================

  /// Load cached registered contacts from local storage.
  /// This is the FAST PATH — called first on app open for instant UI.
  Future<CachedContactList> loadCachedContacts() async {
    try {
      final jsonString = await SecurePrefs.getString(
        SecureStorageKeys.CACHED_CONTACTS,
      );
      if (jsonString != null && jsonString.isNotEmpty) {
        return CachedContactList.fromJsonString(jsonString);
      }
    } catch (e) {
      debugPrint('Error loading cached contacts: $e');
    }
    return CachedContactList(contacts: []);
  }

  /// Save registered contacts to local cache after a successful get-contacts call.
  /// Next app open will load these instantly.
  Future<void> saveCachedContacts(List<ContactDetails> apiContacts) async {
    try {
      final cached = CachedContactList(
        contacts:
            apiContacts
                .where(
                  (c) => c.userId != null,
                ) // Only cache registered contacts
                .map(
                  (c) => CachedContact(
                    name: c.name ?? '',
                    number:
                        c.fullNumber ??
                        c.number ??
                        '', // Use fullNumber with country code
                    userId: c.userId,
                    userName: c.userName,
                    profilePic: c.profilePic,
                    isChatLock: c.isChatLock,
                    chatId: c.chatId,
                  ),
                )
                .toList(),
        cachedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await SecurePrefs.setString(
        SecureStorageKeys.CACHED_CONTACTS,
        cached.toJsonString(),
      );
      debugPrint(
        'Cached ${cached.contacts.length} registered contacts for instant load',
      );
    } catch (e) {
      debugPrint('Error saving cached contacts: $e');
    }
  }

  /// Clear cached contacts (call on logout).
  Future<void> clearCachedContacts() async {
    try {
      await SecurePrefs.remove(SecureStorageKeys.CACHED_CONTACTS);
    } catch (e) {
      debugPrint('Error clearing cached contacts: $e');
    }
  }

  /// Restore UI from cache — called FIRST on app open.
  /// Populates chatContacts from cache so UI shows instantly.
  /// Returns true if cache was loaded, false if empty (first time).
  Future<bool> loadContactsFromCache() async {
    final cached = await loadCachedContacts();

    if (cached.isEmpty) {
      debugPrint('No cached contacts found — first time or cleared');
      return false;
    }

    // Build ContactModel list from cache to populate UI
    _chatContacts =
        cached.contacts
            .map(
              (c) => ContactModel(
                name: c.name,
                phoneNumber: c.number,
                userId: c.userId?.toString(),
                profilePicUrl: c.profilePic,
                isChatLock: c.isChatLock,
                chatId: c.chatId,
              ),
            )
            .toList();

    // Sort alphabetically
    _chatContacts.sort((a, b) => a.name.compareTo(b.name));
    _filteredChatContacts = List.from(_chatContacts);

    // ✅ Push the cached device-contact names into ContactNameService
    // (Tier-1 / address-book priority) right away, on this fast cache-hit
    // path — otherwise Tier-1 stays empty until the slow background sync
    // finishes, and any chat list row resolved in the meantime falls
    // through to the server/account name and locks it in permanently.
    _notifyContactNameService();

    debugPrint('Loaded ${_chatContacts.length} contacts from cache — UI ready');
    notifyListeners();
    return true;
  }

  // ==========================================================================
  // SYNC: Save / Load / Clear local sync data (for diff detection)
  // ==========================================================================

  /// Load saved sync data (timestamp + contact snapshot) from local storage.
  Future<ContactSyncData> loadSyncData() async {
    try {
      final jsonString = await SecurePrefs.getString(
        SecureStorageKeys.CONTACT_SYNC_DATA,
      );
      if (jsonString != null && jsonString.isNotEmpty) {
        return ContactSyncData.fromJsonString(jsonString);
      }
    } catch (e) {
      debugPrint('Error loading sync data: $e');
    }
    return ContactSyncData();
  }

  Future<void> clearSyncDataAndRefresh() async {
    // Wipe the saved sync timestamp → forces doFullSync path next time
    await SecurePrefs.remove(SecureStorageKeys.CONTACT_SYNC_DATA);

    // Also clear cached contacts so processContacts() uses fresh API data
    await clearCachedContacts(); // your existing method

    await loadContacts();
  }

  /// Save sync data after a successful sync.
  Future<void> saveSyncData(ContactSyncData data) async {
    try {
      await SecurePrefs.setString(
        SecureStorageKeys.CONTACT_SYNC_DATA,
        data.toJsonString(),
      );
    } catch (e) {
      debugPrint('Error saving sync data: $e');
    }
  }

  /// Clear sync data (call on logout).
  Future<void> clearSyncData() async {
    try {
      await SecurePrefs.remove(SecureStorageKeys.CONTACT_SYNC_DATA);
    } catch (e) {
      debugPrint('Error clearing sync data: $e');
    }
  }

  // ==========================================================================
  // SYNC: Find changes between device contacts and saved contacts
  // ==========================================================================

  /// Compare current device contacts with saved snapshot.
  /// Returns added / updated / deleted lists for sync API.
  ContactChanges findChanges({
    required Map<String, Map<String, dynamic>> currentDeviceContacts,
    required List<SavedContact> savedContacts,
  }) {
    final added = <Map<String, dynamic>>[];
    final updated = <Map<String, dynamic>>[];
    final deleted = <Map<String, dynamic>>[];

    // Build lookup map from saved contacts: phone -> SavedContact
    final savedMap = <String, SavedContact>{};
    for (final saved in savedContacts) {
      savedMap[saved.phone] = saved;
    }

    final currentPhones = currentDeviceContacts.keys.toSet();

    // ADDED: on device but NOT in saved
    for (final entry in currentDeviceContacts.entries) {
      if (!savedMap.containsKey(entry.key)) {
        added.add(entry.value);
      }
    }

    // UPDATED: in both, but name changed
    for (final entry in currentDeviceContacts.entries) {
      final saved = savedMap[entry.key];
      if (saved != null && saved.name != entry.value['name']) {
        updated.add(entry.value);
      }
    }

    // DELETED: in saved but NOT on device anymore
    for (final saved in savedContacts) {
      if (!currentPhones.contains(saved.phone)) {
        deleted.add({
          'name': saved.name,
          'number': saved.phone,
          'country_code': saved.countryCode,
        });
      }
    }

    debugPrint(
      'Changes: +${added.length} added, ~${updated.length} updated, -${deleted.length} deleted',
    );
    return ContactChanges(added: added, updated: updated, deleted: deleted);
  }

  // ==========================================================================
  // SYNC: Send the full contact list to `/contacts/sync`
  // ==========================================================================

  /// Sends the complete current device contact list to `/contacts/sync` and
  /// saves a fresh snapshot. Used both for the very first sync and for any
  /// later sync where local changes were detected — NEW's backend has no
  /// separate incremental endpoint, and re-sending everything is cheap (see
  /// the comment above this method's caller in `loadContacts`).
  /// Always returns true since we can't tell locally whether any of the
  /// (re-)synced contacts are newly registered without asking the server.
  Future<bool> doFullSync({
    required List<Map<String, dynamic>> allContactsForApi,
    required Map<String, Map<String, dynamic>> contactsByPhone,
  }) async {
    try {
      // NEW backend rejects `/contacts/sync` with 400 ("contacts must
      // contain at least 1 elements") when the device has no contacts to
      // upload — skip the call in that case rather than letting it throw
      // and get stuck resyncing on every load (isFirstSync never clears).
      if (allContactsForApi.isEmpty) {
        debugPrint('📱 No device contacts to sync — skipping /contacts/sync call');
      } else {
        // Hash-only upload - no plaintext phone book leaves the device.
        await _contactRepo.discoverContacts(allContactsForApi);
      }

      final syncData = ContactSyncData(
        syncTimestamp: DateTime.now().toUtc().toIso8601String(),
        contacts:
            contactsByPhone.entries
                .map(
                  (e) => SavedContact(
                    phone: e.key,
                    name: e.value['name'] as String? ?? '',
                    countryCode: e.value['country_code'] as String? ?? '',
                  ),
                )
                .toList(),
      );
      await saveSyncData(syncData);

      debugPrint('📊 Full sync complete - always needs refresh');
      return true; // First sync always needs to fetch contacts
    } on AppError catch (e) {
      // A rejected sync (e.g. ACCOUNT_NOT_VERIFIED) must not blank the
      // address book: show the reason and still fall through to GET
      // /contacts, which returns whatever matches were already stored.
      debugPrint('Full sync blocked: ${e.message}');
      _errorMessage = extractErrorData(e)?['message'] ?? e.message;
      return true;
    } catch (e) {
      debugPrint('Full sync error: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // CACHE STALENESS: Check if cache is too old (fallback refresh)
  // ==========================================================================

  /// Check if cached contacts are stale (older than threshold).
  /// This is a fallback to ensure contacts are refreshed periodically.
  Future<bool> isCacheStale({
    Duration threshold = const Duration(hours: 1),
  }) async {
    try {
      final cached = await loadCachedContacts();
      if (cached.cachedAt == null) return true;

      final cachedTime = DateTime.tryParse(cached.cachedAt!);
      if (cachedTime == null) return true;

      final age = DateTime.now().toUtc().difference(cachedTime);
      final isStale = age > threshold;

      if (isStale) {
        debugPrint(
          '⏰ Cache is stale (age: ${age.inHours}h, threshold: ${threshold.inHours}h)',
        );
      }

      return isStale;
    } catch (e) {
      debugPrint('Error checking cache staleness: $e');
      return true; // Assume stale on error
    }
  }

  bool isContactNumberExists(String phone) {
    final normalizedInput = _normalizeNumber(phone);

    for (var contact in chatContacts) {
      final normalizedSaved = _normalizeNumber(contact.formattedPhoneNumber);

      if (normalizedInput == normalizedSaved) {
        return true;
      }
    }
    return false;
  }

  bool isContactNumberExistss(String phone) {
    final normalizedInput = _normalizeNumber(phone);

    final inputLast10 =
        normalizedInput.length > 10
            ? normalizedInput.substring(normalizedInput.length - 10)
            : normalizedInput;

    for (var contact in chatContacts) {
      final savedNumber = _normalizeNumber(contact.formattedPhoneNumber);

      final savedLast10 =
          savedNumber.length > 10
              ? savedNumber.substring(savedNumber.length - 10)
              : savedNumber;

      if (savedLast10 == inputLast10) {
        return true;
      }
    }

    return false;
  }

  /// Remove spaces, +, -, etc for proper compare
  String _normalizeNumber(String number) {
    return number.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Patches isChatLock + chatId in both in-memory lists and persistent cache.
  /// Call this immediately after lock/unlock API succeeds — no restart needed.
  /// Patches isChatLock + chatId in both in-memory lists and persistent cache.
  /// Matches by userId (stable, unique) — not chatId (can be null or shared).
  Future<void> patchContactLockState({
    required int userId,
    required bool isChatLock,
    int? chatId,
  }) async {
    // ── 1. Patch in-memory lists FIRST ───────────────────────────────────────
    ContactModel patch(ContactModel c) {
      final cUserId = int.tryParse(c.userId ?? '');
      if (cUserId == userId) {
        return ContactModel(
          name: c.name,
          phoneNumber: c.phoneNumber,
          userId: c.userId,
          photo: c.photo,
          profilePicUrl: c.profilePicUrl,
          isChatLock: isChatLock,
          chatId: isChatLock ? (chatId ?? c.chatId) : null,
        );
      }
      return c;
    }

    _allContacts = _allContacts.map(patch).toList();
    _chatContacts = _chatContacts.map(patch).toList();
    _filteredChatContacts = _filteredChatContacts.map(patch).toList();

    // ── 2. Verify AFTER patch ─────────────────────────────────────────────────
    debugPrint(
      '🔒 PATCH: filteredChatContacts count: ${_filteredChatContacts.length}',
    );
    final verified =
        _filteredChatContacts
            .where((c) => int.tryParse(c.userId ?? '') == userId)
            .firstOrNull;
    debugPrint(
      '🔒 VERIFY: "${verified?.name}" isChatLock=${verified?.isChatLock} chatId=${verified?.chatId}',
    );

    if (verified == null) {
      // userId not found in memory — log all userIds to debug
      debugPrint('⚠️ userId $userId NOT FOUND in filteredChatContacts!');
      debugPrint(
        '⚠️ Available userIds: ${_filteredChatContacts.map((c) => c.userId).toList()}',
      );
    }

    // ── 3. Notify AFTER patch is applied ─────────────────────────────────────
    notifyListeners();

    debugPrint(
      '✅ patchContactLockState (memory) — userId $userId → isChatLock: $isChatLock, chatId: ${isChatLock ? chatId : null}',
    );

    // ── 4. Patch persistent cache ─────────────────────────────────────────────
    try {
      final cached = await loadCachedContacts();
      if (cached.isEmpty) return;

      final updatedContacts =
          cached.contacts.map((c) {
            if (c.userId == userId) {
              return CachedContact(
                name: c.name,
                number: c.number,
                userId: c.userId,
                userName: c.userName,
                profilePic: c.profilePic,
                isChatLock: isChatLock,
                chatId: isChatLock ? (chatId ?? c.chatId) : null,
              );
            }
            return c;
          }).toList();

      final updatedCache = CachedContactList(
        contacts: updatedContacts,
        cachedAt: cached.cachedAt,
      );
      await SecurePrefs.setString(
        SecureStorageKeys.CACHED_CONTACTS,
        updatedCache.toJsonString(),
      );

      debugPrint(
        '✅ patchContactLockState (cache) — userId $userId → isChatLock: $isChatLock',
      );
    } catch (e) {
      debugPrint('❌ patchContactLockState cache write failed: $e');
    }
  }
}
