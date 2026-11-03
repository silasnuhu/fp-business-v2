import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/core/services/media/business_image_uploader.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart'
    as usernamecheck;
import 'package:whoxa/featuers/auth/data/repositories/login_repository.dart';
import 'package:whoxa/featuers/business/data/business_profile_mapper.dart';
import 'package:whoxa/featuers/business/data/models/business_profile_model.dart';
import 'package:whoxa/featuers/business/data/repositories/business_repository.dart';
import 'package:whoxa/featuers/profile/data/repositories/catalog_repository.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart' as g;

/// Business profile setup wizard + edit state.
///
/// The screens still talk to this provider with the legacy profile
/// vocabulary (`full_name`, `description`, `website`, …); every write goes
/// through [BusinessProfileMapper] into the `/business/profile` upsert, so the
/// API field names live in one place.
class BusinessProfileProvider extends ChangeNotifier {
  final BusinessRepository _repository = GetIt.instance<BusinessRepository>();
  final CatalogRepository _catalogRepository =
      GetIt.instance<CatalogRepository>();
  final LoginRepository _loginRepository = GetIt.instance<LoginRepository>();
  final BusinessImageUploader _uploader =
      GetIt.instance<BusinessImageUploader>();
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  // Current state
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';
  BusinessProfile? _profile;

  /// Account fields the setup screens display (country code, mobile, …).
  Map<String, dynamic> _userProfile = {};
  List<dynamic> _categories = [];

  // Form controllers and data
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _formData = {};
  final List<File> _images = [];
  File? _bannerImage;
  int? _selectedCategoryId;
  String _businessHoursType =
      'custom'; // 'always_open', 'by_appointments', 'custom'
  List<String> _selectedOpenDays = [];
  List<String> _selectedCloseDays = [];
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  // The business API has no coordinates field, so these are UI-only (the
  // location picker still uses them to fill in the address text).
  double? _businessLatitude;
  double? _businessLongitude;

  // Individual day times - Map<day, Map<'openTime'|'closeTime', TimeOfDay>>
  final Map<String, Map<String, TimeOfDay?>> _individualDayTimes = {
    'monday': {'openTime': null, 'closeTime': null},
    'tuesday': {'openTime': null, 'closeTime': null},
    'wednesday': {'openTime': null, 'closeTime': null},
    'thursday': {'openTime': null, 'closeTime': null},
    'friday': {'openTime': null, 'closeTime': null},
    'saturday': {'openTime': null, 'closeTime': null},
    'sunday': {'openTime': null, 'closeTime': null},
  };

  List<Map<String, dynamic>> _catalogs = [];

  // Getters
  int get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String get errorMessage => _errorMessage;
  BusinessProfile? get profile => _profile;

  /// True once the business has saved a profile (a name, at minimum).
  bool get isSetupComplete => _profile?.isSetUp ?? false;
  Map<String, dynamic> get userProfile => _userProfile;
  List<dynamic> get categories => _categories;
  Map<String, TextEditingController> get controllers => _controllers;
  Map<String, dynamic> get formData => _formData;
  List<File> get images => _images;
  File? get bannerImage => _bannerImage;
  int? get selectedCategoryId => _selectedCategoryId;
  String get businessHoursType => _businessHoursType;
  List<String> get selectedOpenDays => _selectedOpenDays;
  List<String> get selectedCloseDays => _selectedCloseDays;
  TimeOfDay? get openTime => _openTime;
  TimeOfDay? get closeTime => _closeTime;
  Map<String, Map<String, TimeOfDay?>> get individualDayTimes =>
      _individualDayTimes;
  List<Map<String, dynamic>> get catalogs => _catalogs;
  double? get businessLatitude => _businessLatitude;
  double? get businessLongitude => _businessLongitude;

  BusinessProfileProvider() {
    _initializeControllers();
  }

  void _initializeControllers() {
    final controllerKeys = [
      'full_name',
      'description',
      'website',
      'mobile_num',
      'business_email',
      'location',
      'facebook_link',
      'instagram_link',
      'youtube_link',
      'linkedin_link',
      'vk_link',
    ];

    for (final key in controllerKeys) {
      _controllers[key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Method to trigger UI rebuild - can be called from child widgets
  void refreshUI() {
    notifyListeners();
  }

  String _messageFor(Object e) => e is AppError ? e.message : e.toString();

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  /// Fetches the caller's business profile (`null` data ⇒ never set up).
  /// Safe to call repeatedly; also refreshes the cached profile.
  Future<BusinessProfile?> loadProfile() async {
    try {
      _profile = await _repository.getProfile();
      await _syncFullName(_profile);
      notifyListeners();
      return _profile;
    } catch (e) {
      _logger.e('Failed to load business profile: ${_messageFor(e)}');
      rethrow;
    }
  }

  /// The business name IS the account's `fullName` — keep the global and the
  /// persisted `FULL_NAME` in step with `/business/profile`.
  Future<void> _syncFullName(BusinessProfile? profile) async {
    final name = profile?.businessName.trim() ?? '';
    if (name.isEmpty || name == g.fullName) return;
    g.fullName = name;
    try {
      await SecurePrefs.setMultiple({SecureStorageKeys.FULL_NAME: name});
    } catch (e) {
      _logger.e('Could not persist business name: $e');
    }
  }

  /// Own business as the merged user+business record the profile screens read.
  Future<usernamecheck.UserNameCheckModel?> loadOwnBusinessRecord() async {
    final profile = await loadProfile();
    if (profile == null) return null;
    final model = BusinessProfileMapper.toUserNameCheckModel(
      profile,
      account: {
        'user_id': g.userID,
        'user_name': g.userName,
        'profile_pic': g.userProfile,
      },
    );
    // The catalog preview on the profile screen reads `record.catalogs`.
    try {
      model.data!.records!.first.catalogs =
          await _catalogRepository.getCatalogs();
    } catch (e) {
      _logger.e('Could not load catalogs for profile preview: $e');
    }
    return model;
  }

  Future<void> initializeProfileSetup() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _loadCategories();

      _userProfile = {
        'country_code': g.contrycode,
        'mobile_num': g.mobileNum,
        'country': g.country,
      };

      try {
        _profile = await _repository.getProfile();
        await _syncFullName(_profile);
      } catch (e) {
        _logger.e('Failed to load business profile: ${_messageFor(e)}');
        _profile = null;
      }

      // No server-side "setup step": a saved profile means setup is done, and
      // an empty one starts from step 1.
      _currentStep = 0;
      if (_profile != null) {
        _prefillFormData(_profile!);
      } else {
        _prefillAccountDefaults();
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize profile setup: ${_messageFor(e)}';
      _logger.e(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final list = await _repository.getCategories();
      _categories = list.map((c) => c.toMap()).toList();
      _logger.i('Categories loaded: ${_categories.length} items');
    } catch (e) {
      _logger.e('Error loading categories: $e');
      _errorMessage = 'Failed to load categories: ${_messageFor(e)}';
      _categories = [];
    }
    notifyListeners();
  }

  /// Public method to reload categories
  Future<void> reloadCategories() async {
    _logger.i('Manually reloading categories...');
    await _loadCategories();
  }

  void _prefillAccountDefaults() {
    _controllers['mobile_num']?.text = "${g.contrycode}${g.mobileNum}";
  }

  /// Fills the form controllers/state from the server profile.
  void _prefillFormData(BusinessProfile p) {
    _controllers['full_name']?.text = p.businessName;
    _controllers['description']?.text = p.about;
    _controllers['website']?.text = p.otherUrl;
    _controllers['location']?.text = p.businessAddress;
    _controllers['business_email']?.text = p.businessEmail;
    _controllers['mobile_num']?.text =
        p.businessPhone.isNotEmpty
            ? p.businessPhone
            : "${g.contrycode}${g.mobileNum}";
    _controllers['facebook_link']?.text = p.facebookUrl;
    _controllers['instagram_link']?.text = p.instagramUrl;
    _controllers['youtube_link']?.text = p.youtubeUrl;
    _controllers['linkedin_link']?.text = p.linkedinUrl;
    _controllers['vk_link']?.text = p.vkUrl;
    _selectedCategoryId = p.categoryId > 0 ? p.categoryId : null;
    _businessLatitude = p.latitude;
    _businessLongitude = p.longitude;

    _prefillBusinessHours(p.businessHours);
  }

  static const _dayNames = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  TimeOfDay? _parseTime(String s) {
    final parts = s.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Fills the hours state from the API shape
  /// `{mode, days: {monday: {is_open, open_time, close_time}}}`.
  void _prefillBusinessHours(Map<String, dynamic> hours) {
    final mode = hours['mode']?.toString();
    _businessHoursType =
        mode == 'always_open'
            ? 'always_open'
            : mode == 'appointment_only'
            ? 'by_appointments'
            : 'custom';

    final days = hours['days'];
    if (_businessHoursType == 'custom' && days is! Map) {
      // Nothing saved yet: default every day to open 10:00–22:00.
      _selectedOpenDays = List.from(_dayNames);
      _selectedCloseDays = [];
      _individualDayTimes.forEach((day, times) {
        times['openTime'] = const TimeOfDay(hour: 10, minute: 0);
        times['closeTime'] = const TimeOfDay(hour: 22, minute: 0);
      });
      return;
    }
    if (_businessHoursType != 'custom') {
      setBusinessHoursType(_businessHoursType);
      return;
    }

    _selectedOpenDays = [];
    _selectedCloseDays = [];
    for (final day in _dayNames) {
      final d = (days as Map)[day];
      if (d is! Map || d['is_open'] != true) {
        _selectedCloseDays.add(day);
        _individualDayTimes[day]!['openTime'] = null;
        _individualDayTimes[day]!['closeTime'] = null;
        continue;
      }
      _selectedOpenDays.add(day);
      _individualDayTimes[day]!['openTime'] = _parseTime('${d['open_time']}');
      _individualDayTimes[day]!['closeTime'] = _parseTime('${d['close_time']}');
    }
  }

  // ---------------------------------------------------------------------------
  // Wizard navigation
  // ---------------------------------------------------------------------------

  Future<bool> nextStep() async {
    _isSubmitting = true;
    _errorMessage = '';
    notifyListeners();

    try {
      if (!_validateCurrentStep()) {
        return false;
      }

      final stepData = _prepareStepData();

      if (_currentStep == 0) {
        await _saveWithImages(
          stepData,
          _images.isNotEmpty ? _images.first : null,
          _bannerImage,
        );
      } else {
        final saved = await _repository.saveProfile(
          BusinessProfileMapper.toApiFields(stepData),
        );
        await _syncFullName(saved);
      }

      if (_currentStep < 4) {
        _currentStep++;
        if (_currentStep == 4) {
          await _loadCatalogs();
        }
      } else {
        await _completeProfileSetup();
        return true;
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to save step data: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  Future<void> skipStep() async {
    if (_currentStep >= 3 && _currentStep <= 4) {
      _currentStep++;
      notifyListeners();

      if (_currentStep == 4) {
        _loadCatalogs();
      }
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Business Info
        if (_controllers['full_name']?.text.trim().isEmpty ?? true) {
          _errorMessage = 'Please enter business name';
          return false;
        }
        if (_controllers['description']?.text.trim().isEmpty ?? true) {
          _errorMessage = 'Please enter business description';
          return false;
        }
        if (_selectedCategoryId == null) {
          _errorMessage = 'Please select a category';
          return false;
        }
        break;
      case 1: // Business Hours
        if (_businessHoursType == 'custom') {
          if (_selectedOpenDays.isEmpty) {
            _errorMessage = 'Please select open days';
            return false;
          }
          for (String day in _selectedOpenDays) {
            if (!isDayConfigured(day)) {
              _errorMessage =
                  'Please set open and close times for all selected days';
              return false;
            }
          }
        }
        break;
      case 2: // Location & Website
        if (_controllers['location']?.text.trim().isEmpty ?? true) {
          _errorMessage = 'Please enter location';
          return false;
        }
        if (_controllers['website']?.text.trim().isNotEmpty ?? false) {
          final website = _controllers['website']?.text.trim() ?? '';
          if (!website.startsWith('http://') &&
              !website.startsWith('https://')) {
            if (!website.contains('.') || website.contains(' ')) {
              _errorMessage =
                  'Please enter a valid website URL (e.g., www.example.com)';
              return false;
            }
          }
        }
        final email = _controllers['business_email']?.text.trim() ?? '';
        if (email.isNotEmpty &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
          _errorMessage = 'Please enter a valid email address';
          return false;
        }
        break;
      case 3: // Social Accounts (optional)
        break;
      case 4: // Catalog (optional)
        break;
    }
    return true;
  }

  /// Legacy-vocabulary payload for the current step; translated to API field
  /// names by [BusinessProfileMapper] before it is sent.
  Map<String, dynamic> _prepareStepData() {
    final data = <String, dynamic>{};

    switch (_currentStep) {
      case 0: // Business Info
        data['full_name'] = _controllers['full_name']?.text.trim();
        data['description'] = _controllers['description']?.text.trim();
        data['category_id'] = _selectedCategoryId;
        break;
      case 1: // Business Hours
        data['always_open'] = _businessHoursType == 'always_open';
        data['appointments_only'] = _businessHoursType == 'by_appointments';
        if (_businessHoursType != 'by_appointments') {
          data.addAll(getBusinessHoursForAPI());
        }
        break;
      case 2: // Location & Website
        data['location'] = _controllers['location']?.text.trim();

        // Auto-add https:// if needed
        String website = _controllers['website']?.text.trim() ?? '';
        if (website.isNotEmpty &&
            !website.startsWith('http://') &&
            !website.startsWith('https://')) {
          website = 'https://$website';
        }
        data['website'] = website;
        data['mobile_num'] = _controllers['mobile_num']?.text.trim() ?? '';
        data['business_email'] =
            _controllers['business_email']?.text.trim() ?? '';
        if (_businessLatitude != null && _businessLongitude != null) {
          data['latitude'] = _businessLatitude;
          data['longitude'] = _businessLongitude;
        }
        break;
      case 3: // Social Accounts
        data['facebook_link'] = _controllers['facebook_link']?.text.trim();
        data['instagram_link'] = _controllers['instagram_link']?.text.trim();
        data['youtube_link'] = _controllers['youtube_link']?.text.trim();
        data['linkedin_link'] = _controllers['linkedin_link']?.text.trim();
        data['vk_link'] = _controllers['vk_link']?.text.trim();
        break;
      case 4: // Catalog: products are saved as they are added.
        break;
    }

    return data;
  }

  Future<void> _completeProfileSetup() async {
    // Everything is saved step by step; just make sure the cached profile
    // reflects the server so the rest of the app sees setup as complete.
    await loadProfile();
  }

  void redirectToMainApp(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.tabbar,
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _loadCatalogs() async {
    try {
      final catalogs = await _catalogRepository.getCatalogs();
      _catalogs = catalogs.map((c) => c.toJson()).toList();
      notifyListeners();
    } catch (e) {
      _logger.e('Error loading catalogs: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers for UI
  // ---------------------------------------------------------------------------

  void setSelectedCategory(int categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setBusinessHoursType(String type) {
    _businessHoursType = type;

    final allDays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    if (type == 'always_open') {
      // Always Open: every day open, 24 hours (00:00 to 00:00)
      _selectedOpenDays = List.from(allDays);
      _selectedCloseDays.clear();
      _openTime = const TimeOfDay(hour: 0, minute: 0);
      _closeTime = const TimeOfDay(hour: 0, minute: 0);

      _individualDayTimes.forEach((day, times) {
        times['openTime'] = const TimeOfDay(hour: 0, minute: 0);
        times['closeTime'] = const TimeOfDay(hour: 0, minute: 0);
      });
    } else if (type == 'by_appointments') {
      // Appointments Only: no specific hours
      _selectedOpenDays.clear();
      _selectedCloseDays.clear();
      _openTime = null;
      _closeTime = null;

      _individualDayTimes.forEach((day, times) {
        times['openTime'] = null;
        times['closeTime'] = null;
      });
    } else {
      // Custom: every day open 10:00–22:00 by default
      const defaultOpenTime = TimeOfDay(hour: 10, minute: 0);
      const defaultCloseTime = TimeOfDay(hour: 22, minute: 0);

      _individualDayTimes.forEach((day, times) {
        times['openTime'] = defaultOpenTime;
        times['closeTime'] = defaultCloseTime;
      });

      _selectedOpenDays = List.from(allDays);
      _selectedCloseDays.clear();
    }
    notifyListeners();
  }

  void toggleOpenDay(String day) {
    if (_selectedOpenDays.contains(day)) {
      _selectedOpenDays.remove(day);
      _selectedCloseDays.add(day);
      _individualDayTimes[day]!['openTime'] = null;
      _individualDayTimes[day]!['closeTime'] = null;
    } else {
      _selectedOpenDays.add(day);
      _selectedCloseDays.remove(day);
      if (_individualDayTimes[day]!['openTime'] == null ||
          _individualDayTimes[day]!['closeTime'] == null) {
        _individualDayTimes[day]!['openTime'] = const TimeOfDay(
          hour: 9,
          minute: 0,
        );
        _individualDayTimes[day]!['closeTime'] = const TimeOfDay(
          hour: 18,
          minute: 0,
        );
      }
    }
    notifyListeners();
  }

  void setOpenTime(TimeOfDay time) {
    _openTime = time;
    notifyListeners();
  }

  void setCloseTime(TimeOfDay time) {
    _closeTime = time;
    notifyListeners();
  }

  void setBusinessCoordinates(double? latitude, double? longitude) {
    _businessLatitude = latitude;
    _businessLongitude = longitude;
    notifyListeners();
  }

  void setIndividualDayTime(String day, String timeType, TimeOfDay time) {
    if (_individualDayTimes.containsKey(day)) {
      _individualDayTimes[day]![timeType] = time;
      notifyListeners();
    }
  }

  TimeOfDay? getIndividualDayTime(String day, String timeType) {
    return _individualDayTimes[day]?[timeType];
  }

  bool isDayConfigured(String day) {
    final dayTimes = _individualDayTimes[day];
    return dayTimes != null &&
        dayTimes['openTime'] != null &&
        dayTimes['closeTime'] != null;
  }

  void addImage(File image) {
    _images.add(image);
    notifyListeners();
  }

  void removeImage(int index) {
    if (index < _images.length) {
      _images.removeAt(index);
      notifyListeners();
    }
  }

  void setBannerImage(File image) {
    _bannerImage = image;
    notifyListeners();
  }

  void removeBannerImage() {
    _bannerImage = null;
    notifyListeners();
  }

  // Public method to load catalogs
  Future<void> loadCatalogs() async {
    await _loadCatalogs();
  }

  // ---------------------------------------------------------------------------
  // Saving
  // ---------------------------------------------------------------------------

  /// Uploads the optional logo (the account avatar) and cover image, then
  /// upserts the profile. The logo goes through the account avatar endpoint;
  /// the cover image is uploaded via the media API and saved as a URL.
  Future<void> _saveWithImages(
    Map<String, dynamic> legacyData,
    File? logo,
    File? cover,
  ) async {
    if (logo != null) {
      await _loginRepository.updateAvatarRepo(image: logo);
    }

    String? coverUrl;
    if (cover != null) {
      coverUrl = await _uploader.upload(cover);
      if (coverUrl == null) {
        throw Exception('Cover image upload failed');
      }
    }

    // Edit-screen saves carry the map pin along (latitude + longitude are
    // sent together).
    final withCoords = Map<String, dynamic>.from(legacyData);
    if (!withCoords.containsKey('latitude') &&
        _businessLatitude != null &&
        _businessLongitude != null) {
      withCoords['latitude'] = _businessLatitude;
      withCoords['longitude'] = _businessLongitude;
    }
    _profile = await _repository.saveProfile(
      BusinessProfileMapper.toApiFields(withCoords, coverImageUrl: coverUrl),
    );
    await _syncFullName(_profile);
  }

  /// Removes the business logo, which is the account avatar
  /// (`DELETE /users/avatar`).
  Future<void> removeLogo() async {
    try {
      await _loginRepository.deleteAvatarRepo();
    } catch (e) {
      _errorMessage = 'Failed to remove logo: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      rethrow;
    }
    notifyListeners();
  }

  /// Multi-file save used by the edit screen: `files` is the logo,
  /// `banner_image` the cover.
  Future<Map<String, dynamic>> updateBusinessProfileRepoMultipleFiles(
    Map<String, dynamic> data,
    Map<String, File> fileMap,
  ) async {
    await _saveWithImages(data, fileMap['files'], fileMap['banner_image']);
    notifyListeners();
    return {'status': true};
  }

  Future<void> addCatalog({
    required String title,
    required String description,
    required String price,
    required String countryOfOrigin,
    List<File>? images,
  }) async {
    try {
      final urls = await _uploader.uploadAll(images ?? const []);
      await _catalogRepository.createCatalog(
        title: title,
        price: (double.tryParse(price) ?? 0).round(),
        description: description,
        countryOfOrigin: countryOfOrigin,
        images: urls,
      );
      await _loadCatalogs();
    } catch (e) {
      _errorMessage = 'Failed to add catalog: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      rethrow;
    }
  }

  /// Legacy-format business hours (`{"business_hours": {"monday": "9:00 to
  /// 18:00", …, "sunday": "closed"}}`); [BusinessProfileMapper] converts it to
  /// the API's `mon…sun` / `HH:mm-HH:mm` shape when saving.
  Map<String, dynamic> getBusinessHoursForAPI() {
    if (_businessHoursType == 'custom' || _businessHoursType == 'always_open') {
      final Map<String, String> businessHours = {};

      const weekdays = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];

      for (String day in weekdays) {
        if (_selectedOpenDays.contains(day)) {
          if (_businessHoursType == 'always_open') {
            businessHours[day] = '00:00 to 00:00';
          } else {
            final openTime = _individualDayTimes[day]?['openTime'];
            final closeTime = _individualDayTimes[day]?['closeTime'];

            if (openTime != null && closeTime != null) {
              businessHours[day] =
                  '${_formatTimeForBackend(openTime)} to ${_formatTimeForBackend(closeTime)}';
            } else {
              businessHours[day] = '10:00 to 22:00';
            }
          }
        } else {
          businessHours[day] = 'closed';
        }
      }

      return {'business_hours': businessHours};
    }

    return {};
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // 24-hour HH:mm
  String _formatTimeForBackend(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String getBusinessHoursDisplayText(String day) {
    if (_businessHoursType != 'custom') return '';

    if (_selectedOpenDays.contains(day)) {
      final openTime = _individualDayTimes[day]?['openTime'];
      final closeTime = _individualDayTimes[day]?['closeTime'];

      if (openTime != null && closeTime != null) {
        return '${_formatTimeOfDay(openTime)} to ${_formatTimeOfDay(closeTime)}';
      } else {
        return '10:00 AM to 10:00 PM';
      }
    } else {
      return 'Closed';
    }
  }

  /// Save from the edit screen. [data] uses the legacy vocabulary; [files]
  /// (with [fileKey] `files` = logo, `banner_image` = cover) are optional.
  Future<Map<String, dynamic>> updateBusinessProfileRepo(
    Map<String, dynamic> data, {
    List<File>? files,
    String fileKey = 'files',
  }) async {
    try {
      final file = (files != null && files.isNotEmpty) ? files.first : null;
      await _saveWithImages(
        data,
        fileKey == 'files' ? file : null,
        fileKey == 'banner_image' ? file : null,
      );
      notifyListeners();
      return {'status': true};
    } catch (e) {
      _errorMessage = 'Failed to update profile: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      rethrow;
    }
  }
}
