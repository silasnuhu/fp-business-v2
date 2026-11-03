// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:whoxa/featuers/subscription/widgets/verified_badge.dart';
import 'package:whoxa/featuers/subscription/provider/subscription_provider.dart';
import 'package:whoxa/featuers/auth/provider/business_profile_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global_textfield.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/widgets/business_location_picker.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart'
    as usernamecheck;

class EditBusinessProfileScreen extends StatefulWidget {
  final usernamecheck.UserNameCheckModel? userProfile;
  final String? scrollToSection; // Add parameter for auto-scroll

  const EditBusinessProfileScreen({
    super.key,
    this.userProfile,
    this.scrollToSection,
  });

  @override
  State<EditBusinessProfileScreen> createState() =>
      _EditBusinessProfileScreenState();
}

class _EditBusinessProfileScreenState extends State<EditBusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _socialMediaKey = GlobalKey(); // Key for social media section
  File? _coverImage;
  File? _logoImage;

  // Removal of an image already saved on the server is staged here and only
  // applied when the form is saved.
  bool _removeCover = false;
  bool _removeLogo = false;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isSaving = false;

  // Business hours state variables (like step2)
  String _selectedHoursMode = 'selectedHours';

  final List<String> _weekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  final List<String> _weekdayLabels = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentProfileData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(String section) {
    if (section == 'socialMedia' && _socialMediaKey.currentContext != null) {
      Scrollable.ensureVisible(
        _socialMediaKey.currentContext!,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadCurrentProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<BusinessProfileProvider>(
        context,
        listen: false,
      );

      // Always load categories first
      await provider.reloadCategories();

      if (widget.userProfile?.data?.records?.isNotEmpty == true) {
        // Pre-fill form with existing data from find-user API
        final record = widget.userProfile!.data!.records!.first;
        await _prefillFormDataWithCategory(provider, record);
      } else {
        // Fallback to API if no data passed
        await provider.initializeProfileSetup();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Auto-scroll to section after data is loaded and UI is rebuilt
        if (widget.scrollToSection != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Add a small delay to ensure UI is fully rendered
            Future.delayed(const Duration(milliseconds: 500), () {
              _scrollToSection(widget.scrollToSection!);
            });
          });
        }
      }
    }
  }

  Future<void> _prefillFormDataWithCategory(
    BusinessProfileProvider provider,
    usernamecheck.Records record,
  ) async {
    // The business profile carries its category as {category_id, name}.
    final categoryId = int.tryParse('${record.categories?['category_id']}');
    if (categoryId != null && categoryId > 0) {
      provider.setSelectedCategory(categoryId);
    }

    // Continue with existing form pre-fill logic
    _prefillFormData(provider, record);
  }

  void _prefillFormData(
    BusinessProfileProvider provider,
    usernamecheck.Records record,
  ) {
    provider.setBusinessCoordinates(record.latitude, record.longitude);
    // Pre-fill form controllers with existing data
    provider.controllers['full_name']?.text = record.companyName ?? '';
    provider.controllers['description']?.text = record.description ?? '';
    provider.controllers['website']?.text = record.website ?? '';
    provider.controllers['mobile_num']?.text =
        "${record.countryCode ?? ''} ${record.mobileNum ?? ''}";
    provider.controllers['location']?.text = record.location ?? '';
    provider.controllers['facebook_link']?.text = record.facebookLink ?? '';
    provider.controllers['instagram_link']?.text =
        record.instagramLink ?? ''; // Not available in current model
    provider.controllers['youtube_link']?.text = record.youtubeLink ?? '';
    provider.controllers['linkedin_link']?.text = record.linkedinLink ?? '';
    provider.controllers['vk_link']?.text = record.vkLink ?? '';

    // Set business hours type based on flags
    if (record.byAppointmentsOnly == true || record.appointmentsOnly == true) {
      provider.setBusinessHoursType('by_appointments');
      setState(() {
        _selectedHoursMode = 'appointmentsOnly';
      });
    } else if (record.alwaysOpen == true) {
      provider.setBusinessHoursType('always_open');
      setState(() {
        _selectedHoursMode = 'alwaysOpen';
      });
      // For always open, parse the actual business hours to respect user's selection
      _parseBusinessHours(provider, record.businessHours);
    } else {
      provider.setBusinessHoursType('custom');
      setState(() {
        _selectedHoursMode = 'selectedHours';
      });
      // Parse business hours if available
      _parseBusinessHours(provider, record.businessHours);
    }
  }

  void _parseBusinessHours(
    BusinessProfileProvider provider,
    Map<String, dynamic>? businessHours,
  ) {
    if (businessHours == null) {
      debugPrint('EditBusinessProfile: No business hours data to parse');
      return;
    }

    debugPrint('EditBusinessProfile: Parsing business hours: $businessHours');

    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    List<String> openDays = [];

    for (String day in days) {
      final hours = businessHours[day] as String?;
      debugPrint('EditBusinessProfile: $day = $hours');

      if (hours != null && hours.toLowerCase() != 'closed') {
        openDays.add(day);

        // Parse time if in "HH:MMtoHH:MM" or "HH:MM to HH:MM" format
        if (hours.contains('to')) {
          final parts =
              hours.contains(' to ') ? hours.split(' to ') : hours.split('to');
          if (parts.length == 2) {
            final openTime = _parseTime(parts[0].trim());
            final closeTime = _parseTime(parts[1].trim());

            debugPrint(
              'EditBusinessProfile: $day open: $openTime, close: $closeTime',
            );

            if (openTime != null && closeTime != null) {
              provider.setIndividualDayTime(day, 'openTime', openTime);
              provider.setIndividualDayTime(day, 'closeTime', closeTime);
            }
          }
        }
      }
    }

    // Update provider with open days
    provider.selectedOpenDays.clear();
    provider.selectedOpenDays.addAll(openDays);

    provider.selectedCloseDays.clear();
    provider.selectedCloseDays.addAll(
      days.where((day) => !openDays.contains(day)).toList(),
    );

    debugPrint('EditBusinessProfile: Open days: $openDays');
    debugPrint(
      'EditBusinessProfile: Close days: ${provider.selectedCloseDays}',
    );

    // Trigger UI update
    provider.refreshUI();
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      // Handle "HH:MM" format
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Fp.ink,
      appBar: AppBar(
        backgroundColor: Fp.violet,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: ThemeColorPalette.getTextColor(
              Fp.violet,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppString
              .profileStrings
              .editBusinessProfile, //'Edit Business Profile',
          style: Fp.h2.copyWith(
            color: ThemeColorPalette.getTextColor(
              Fp.violet,
            ),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: ThemeColorPalette.getTextColor(
                    Fp.violet,
                  ),
                  strokeWidth: 2,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                AppString.profileStrings.save, //'Save',
                style: Fp.body.copyWith(
                  color: ThemeColorPalette.getTextColor(
                    Fp.violet,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: commonLoading())
              : Consumer<BusinessProfileProvider>(
                builder: (context, provider, child) {
                  return Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        children: [
                          // Cover Image and Logo Section
                          _buildCoverImageHeader(),

                          // Form Content
                          Padding(
                            padding: SizeConfig.getPaddingSymmetric(
                              horizontal: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Business Basic Info Section Business Information
                                _buildSectionTitle(
                                  AppString.profileStrings.businessInformation,
                                ),
                                _buildBusinessInfoSection(provider),

                                SizedBox(height: SizeConfig.height(2)),

                                // Business Hours Section Business Hours
                                _buildSectionTitle(
                                  AppString.profileStrings.businessHours,
                                ),
                                _buildBusinessHoursSection(provider),

                                SizedBox(height: SizeConfig.height(2)),

                                // Location & Website Section Location & Contact
                                _buildSectionTitle(
                                  AppString.profileStrings.locationContact,
                                ),
                                _buildLocationContactSection(provider),

                                SizedBox(height: SizeConfig.height(2)),

                                // Social Links Section Social Media Links
                                Container(
                                  key: _socialMediaKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionTitle(
                                        AppString
                                            .profileStrings
                                            .socialMediaLinks,
                                      ),
                                      _buildSocialLinksSection(provider),
                                    ],
                                  ),
                                ),

                                SizedBox(height: SizeConfig.height(4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  Widget _removeButton({required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.close, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildProfilePictureContent() {
    final hasExistingProfilePic =
        !_removeLogo &&
        (widget.userProfile?.data?.records?.first.profilePic?.isNotEmpty ??
            false);

    if (hasExistingProfilePic) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: widget.userProfile!.data!.records!.first.profilePic!,
          width: SizeConfig.sizedBoxWidth(100),
          height: SizeConfig.sizedBoxHeight(100),
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => _buildDefaultProfilePicture(),
          placeholder:
              (context, url) => Container(
                width: SizeConfig.sizedBoxWidth(100),
                height: SizeConfig.sizedBoxHeight(100),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Fp.violet.withValues(
                    alpha: 0.1,
                  ),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Fp.violet,
                    strokeWidth: 2,
                  ),
                ),
              ),
        ),
      );
    } else {
      return _buildDefaultProfilePicture();
    }
  }

  Widget _buildDefaultProfilePicture() {
    return Container(
      width: SizeConfig.sizedBoxWidth(60),
      height: SizeConfig.sizedBoxHeight(60),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Fp.violet.withValues(alpha: 0.1),
      ),
      child: Center(
        child: SvgPicture.asset(
          AppAssets.businessAssets.businessProfileLogoTemplate,
          height: SizeConfig.sizedBoxHeight(30),
          width: SizeConfig.sizedBoxWidth(30),
          colorFilter: ColorFilter.mode(
            Fp.violet,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: SizeConfig.getPaddingSymmetric(vertical: 8),
      child: Text(
        title,
        style: Fp.bodyStrong.copyWith(
          fontWeight: FontWeight.w700,
          color: Fp.text,
        ),
      ),
    );
  }

  Widget _buildCoverImageHeader() {
    final hasExistingBanner =
        !_removeCover &&
        (widget.userProfile?.data?.records?.first.bannerImage?.isNotEmpty ??
            false);

    return Column(
      children: [
        // Cover Image Background
        Stack(
          children: [
            Container(
              height: SizeConfig.sizedBoxHeight(200),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient:
                    _coverImage == null && !hasExistingBanner
                        ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Fp.violet.withValues(
                              alpha: 0.8,
                            ),
                            Fp.cyan.withValues(
                              alpha: 0.6,
                            ),
                          ],
                        )
                        : null,
                image:
                    _coverImage != null
                        ? DecorationImage(
                          image: FileImage(_coverImage!),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  _coverImage == null && hasExistingBanner
                      ? CachedNetworkImage(
                        imageUrl:
                            widget
                                .userProfile!
                                .data!
                                .records!
                                .first
                                .bannerImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorWidget:
                            (context, url, error) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Fp.violet
                                        .withValues(alpha: 0.8),
                                    Fp.cyan
                                        .withValues(alpha: 0.6),
                                  ],
                                ),
                              ),
                            ),
                      )
                      : _coverImage == null && !hasExistingBanner
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              AppAssets.businessAssets.businessCoverTemp,
                              height: SizeConfig.sizedBoxHeight(50),
                              width: SizeConfig.sizedBoxWidth(50),
                              colorFilter: ColorFilter.mode(
                                AppColors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                            SizedBox(height: SizeConfig.height(1)),
                            Text(
                              AppString
                                  .profileStrings
                                  .tapToAddCoverImage, //'Tap to add cover image',
                              style: AppTypography.captionText(
                                context,
                              ).copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                      : null,
            ),

            // Remove cover image (picked or already saved)
            if (_coverImage != null || hasExistingBanner)
              Positioned(
                top: 10,
                left: 10,
                child: _removeButton(
                  tooltip: 'Remove cover image',
                  onTap: () {
                    setState(() {
                      if (_coverImage != null) {
                        _coverImage = null;
                      } else {
                        _removeCover = true;
                      }
                    });
                  },
                ),
              ),

            // Change button overlay for existing banner image
            if (_coverImage == null && hasExistingBanner)
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap:
                      () => bottomSheetCameraGallery(
                        context,
                        isLogo: false,
                      ), // _pickImage(isLogo: false),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          AppString.profileStrings.change, //'Change',
                          style: Fp.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Tap area for adding new image when no existing image
            if (_coverImage == null && !hasExistingBanner)
              Positioned.fill(
                child: GestureDetector(
                  onTap:
                      () => bottomSheetCameraGallery(
                        context,
                        isLogo: false,
                      ), //_pickImage(isLogo: false),
                  child: Container(color: Colors.transparent),
                ),
              ),
          ],
        ),

        // Logo positioned with negative margin to overlap cover
        Transform.translate(
          offset: Offset(0, -SizeConfig.height(5)), // Pull up to overlap cover
          child: Stack(
            children: [
              GestureDetector(
                onTap:
                    () => bottomSheetCameraGallery(
                      context,
                      isLogo: true,
                    ), //_pickImage(isLogo: true),
                child: Container(
                  width: SizeConfig.sizedBoxWidth(100),
                  height: SizeConfig.sizedBoxHeight(100),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Fp.ink,
                    border: Border.all(
                      color: Fp.ink,
                      width: 4,
                    ),
                    image:
                        _logoImage != null
                            ? DecorationImage(
                              image: FileImage(_logoImage!),
                              fit: BoxFit.cover,
                            )
                            : null,
                  ),
                  child:
                      _logoImage == null ? _buildProfilePictureContent() : null,
                ),
              ),

              // Remove logo (picked or already saved)
              if (_logoImage != null ||
                  (!_removeLogo &&
                      (widget
                              .userProfile
                              ?.data
                              ?.records
                              ?.first
                              .profilePic
                              ?.isNotEmpty ??
                          false)))
                Positioned(
                  top: 0,
                  right: 0,
                  child: _removeButton(
                    tooltip: 'Remove logo',
                    onTap: () {
                      setState(() {
                        if (_logoImage != null) {
                          _logoImage = null;
                        } else {
                          _removeLogo = true;
                        }
                      });
                    },
                  ),
                ),

              // Edit icon positioned at bottom-right
              Positioned(
                bottom: 5,
                right: 5,
                child: GestureDetector(
                  onTap:
                      () => bottomSheetCameraGallery(
                        context,
                        isLogo: true,
                      ), //_pickImage(isLogo: true),
                  child: Container(
                    width: SizeConfig.sizedBoxWidth(28),
                    height: SizeConfig.sizedBoxHeight(28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Fp.violet,
                      border: Border.all(
                        color: Fp.ink,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _logoImage != null ||
                              (!_removeLogo &&
                                  (widget
                                          .userProfile
                                          ?.data
                                          ?.records
                                          ?.first
                                          .profilePic
                                          ?.isNotEmpty ??
                                      false))
                          ? Icons.edit
                          : Icons.add,
                      size: 14,
                      color: Fp.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessInfoSection(BusinessProfileProvider provider) {
    return Column(
      children: [
        // Business Name Field — the blue tick is its prefix icon while the
        // owner has an active subscription (null otherwise, so no empty gap).
        Consumer<SubscriptionProvider>(
          builder: (context, subscription, _) {
            return GlobalTextField1(
              lable: AppString.profileStrings.businessName, //'Business Name',
              lable2: '*',
              hintText:
                  AppString
                      .profileStrings
                      .enterYourbusinessName, //'Enter your business name',
              controller: provider.controllers['full_name']!,
              context: context,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              onEditingComplete: () {},
              maxLength: 50,
              suffixIcon:
                  subscription.premiumUser
                      ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: VerifiedBadge(size: 20),
                      )
                      : null,
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return AppString
                      .profileStrings
                      .pleaseEnterBusinessName; //'Please enter business name';
                }
                return null;
              },
            );
          },
        ),

        // Description Field
        GlobalTextField1(
          lable: AppString.profileStrings.description, //'Description',
          lable2: '*',
          hintText:
              AppString
                  .profileStrings
                  .enterDescription, //'Enter business description...',
          controller: provider.controllers['description']!,
          context: context,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 6,
          maxLength: 500,
          contentPadding: EdgeInsetsGeometry.all(10),
          onEditingComplete: () {},
          validator: (value) {
            if (value?.trim().isEmpty ?? true) {
              return AppString
                  .profileStrings
                  .pleaseDescription; //'Please enter business description';
            }
            return null;
          },
        ),

        // Category Selection
        _buildLabelWithAsterisk(AppString.profileStrings.category),

        _buildCategoryDropdown(provider),
      ],
    );
  }

  Widget _buildBusinessHoursSection(BusinessProfileProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Business Hours Mode Selection (Step2 Style)
        _buildStep2StyleModeSelection(provider),

        SizedBox(height: SizeConfig.height(2)),

        // Business Hours Content Based on Mode (Step2 Style)
        _buildStep2StyleBusinessHoursContent(provider),
      ],
    );
  }

  Widget _buildLocationContactSection(BusinessProfileProvider provider) {
    return Column(
      children: [
        // Location Field
        GlobalTextField1(
          lable: AppString.profileStrings.location, //'Location',
          lable2: '*',
          hintText:
              AppString
                  .profileStrings
                  .enterBusinessLocation, //'Enter business location',
          controller: provider.controllers['location']!,
          context: context,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          onEditingComplete: () {},
          validator: (value) {
            if (value?.trim().isEmpty ?? true) {
              return AppString
                  .profileStrings
                  .pleaseEnterLocation; //'Please enter location';
            }
            return null;
          },
        ),

        SizedBox(height: SizeConfig.height(1.5)),

        // Map Widget (Stepper Style)
        _buildMapWidget(provider),

        SizedBox(height: SizeConfig.height(2)),

        GlobalTextField1(
          lable: AppString.profileStrings.contact, //'Contact',
          hintText:
              AppString
                  .profileStrings
                  .enterMobileNumber, //'Enter mobile number',
          controller: provider.controllers['mobile_num']!,
          context: context,
          keyboardType: TextInputType.number,
          onEditingComplete: () {},
          isOnlyRead: true,
          onTap: () {
            snackbarNew(
              context,
              msg: AppString.profileStrings.yourMobileCannot,
            );
          },
        ),

        SizedBox(height: SizeConfig.height(2)),

        // Website Field
        GlobalTextField1(
          lable: AppString.profileStrings.website, //'Website',
          hintText:
              AppString
                  .profileStrings
                  .enterWebsite, //'Enter website URL (optional)',
          controller: provider.controllers['website']!,
          context: context,
          keyboardType: TextInputType.url,
          onEditingComplete: () {},
        ),
      ],
    );
  }

  Widget _buildSocialLinksSection(BusinessProfileProvider provider) {
    // Social media platforms configuration (same as MyBusinessProfileScreen and step4)
    final socialPlatforms = [
      {
        'key': 'facebook_link',
        'label': 'Facebook',
        'hint':
            AppString
                .profileStrings
                .enterFacebookUrl, //'Enter Facebook profile URL',
        'icon': Icons.facebook,
        'color': const Color(0xFF1877F2),
        'controller': provider.controllers['facebook_link']!,
      },
      {
        'key': 'instagram_link',
        'label': 'Instagram',
        'hint':
            AppString
                .profileStrings
                .enterInstagramUrl, //'Enter Instagram profile URL',
        'icon': Icons.camera_alt,
        'color': const Color(0xFFE4405F),
        'controller': provider.controllers['instagram_link']!,
      },
      {
        'key': 'linkedin_link',
        'label': 'LinkedIn',
        'hint':
            AppString
                .profileStrings
                .enterLinkedInUrl, //'Enter LinkedIn profile URL',
        'icon': Icons.business,
        'color': const Color(0xFF0A66C2),
        'controller': provider.controllers['linkedin_link']!,
      },
      {
        'key': 'youtube_link',
        'label': 'YouTube',
        'hint':
            AppString
                .profileStrings
                .enterYoutubUrl, //'Enter YouTube channel URL',
        'icon': Icons.play_circle_outline,
        'color': const Color(0xFFFF0000),
        'controller': provider.controllers['youtube_link']!,
      },
      {
        'key': 'vk_link',
        'label': 'VK',
        'hint': AppString.profileStrings.enterVKUrl, //'Enter VK profile URL',
        'icon': Icons.share,
        'color': const Color(0xFF4C75A3),
        'controller': provider.controllers['vk_link']!,
      },
    ];

    return Column(
      children:
          socialPlatforms.map((platform) {
            final Color color = platform['color'] as Color;
            final IconData icon = platform['icon'] as IconData;
            final String label = platform['label'] as String;
            final String hint = platform['hint'] as String;
            final TextEditingController controller =
                platform['controller'] as TextEditingController;

            return Column(
              children: [
                _buildSocialLinkField(label, hint, controller, icon, color),
                if (platform != socialPlatforms.last)
                  SizedBox(height: SizeConfig.height(1.5)),
              ],
            );
          }).toList(),
    );
  }

  Widget _buildSocialLinkField(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.innerText12Mediu(context).copyWith(
            fontWeight: FontWeight.w600,
            color: Fp.text,
          ),
        ),
        SizedBox(height: SizeConfig.height(0.5)),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Fp.hairlineStrong),
          ),
          child: Row(
            children: [
              Container(
                padding: SizeConfig.getPaddingSymmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  style: AppTypography.captionText(
                    context,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTypography.captionText(
                      context,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: SizeConfig.getPaddingSymmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabelWithAsterisk(String label) {
    return Padding(
      padding: SizeConfig.getPaddingSymmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: RichText(
          text: TextSpan(
            style: AppTypography.innerText12Mediu(context).copyWith(
              fontWeight: FontWeight.w600,
              color: Fp.text,
            ),
            children: [
              TextSpan(text: '$label '),
              TextSpan(text: '*', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(BusinessProfileProvider provider) {
    if (provider.isLoading) {
      return Container(
        padding: SizeConfig.getPaddingSymmetric(vertical: 20),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              AppString
                  .profileStrings
                  .loadingCategories, //'Loading categories...',
              style: AppTypography.captionText(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
            ),
          ],
        ),
      );
    }

    if (provider.categories.isEmpty) {
      return Container(
        padding: SizeConfig.getPaddingSymmetric(vertical: 20),
        child: Text(
          AppString.profileStrings.noCategories, //'No categories available',
          style: AppTypography.captionText(
            context,
          ).copyWith(color: AppColors.textColor.textGreyColor),
        ),
      );
    }

    String selectedCategoryName = '';
    if (provider.selectedCategoryId != null) {
      final selectedCategory = provider.categories.firstWhere(
        (category) => category['category_id'] == provider.selectedCategoryId,
        orElse: () => <String, dynamic>{},
      );
      selectedCategoryName = selectedCategory['name'] ?? '';
    }

    return FormField<int>(
      initialValue: provider.selectedCategoryId,
      validator: (value) {
        if (value == null) {
          return AppString
              .profileStrings
              .pleaseSelectCategory; //'Please select a category';
        }
        return null;
      },
      builder: (FormFieldState<int> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _showCategoryBottomSheet(context, provider, state),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        state.hasError
                            ? AppColors.textColor.textErrorColor1
                            : AppThemeManage.appTheme.greyBlackGrey,
                  ),
                  color: AppThemeManage.appTheme.bg4BlackGrey,
                ),
                child: Container(
                  padding: SizeConfig.getPaddingSymmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedCategoryName.isEmpty
                              ? AppString
                                  .profileStrings
                                  .selectCategory //'Select a category'
                              : selectedCategoryName,
                          style: AppTypography.inputPlaceholder(
                            context,
                          ).copyWith(
                            fontSize: SizeConfig.getFontSize(12),
                            color:
                                selectedCategoryName.isEmpty
                                    ? AppColors.textColor.textGreyColor
                                    : Fp.text,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Fp.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: SizeConfig.getPaddingOnly(top: 8, left: 16),
                child: Text(
                  state.errorText!,
                  style: Fp.caption.copyWith(
                    color: AppColors.textColor.textErrorColor1,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showCategoryBottomSheet(
    BuildContext context,
    BusinessProfileProvider provider,
    FormFieldState<int> state,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Fp.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Fp.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: SizeConfig.height(2)),

              // Title
              Text(
                AppString.profileStrings.selectcategory, //'Select Category',
                style: Fp.h2.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Fp.text,
                ),
              ),
              SizedBox(height: SizeConfig.height(2)),

              // Categories list
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: SizeConfig.sizedBoxHeight(400),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children:
                        provider.categories.map<Widget>((category) {
                          final isSelected =
                              provider.selectedCategoryId ==
                              category['category_id'];
                          return InkWell(
                            onTap: () {
                              provider.setSelectedCategory(
                                category['category_id'],
                              );
                              state.didChange(category['category_id']);
                              Navigator.pop(context);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: SizeConfig.getPaddingSymmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              margin: SizeConfig.getPaddingSymmetric(
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? Fp.violet
                                            .withValues(alpha: 0.1)
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category['name'] ?? '',
                                      style: AppTypography.inputPlaceholder(
                                        context,
                                      ).copyWith(
                                        fontSize: SizeConfig.getFontSize(14),
                                        color:
                                            Fp.text,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color:
                                          Fp.violet,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
              SizedBox(height: SizeConfig.height(2)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage({required bool isLogo}) async {
    // ✅ DEMO MODE: Block image selection for demo accounts
    if (checkDemoMode(context)) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          if (isLogo) {
            _logoImage = File(pickedFile.path);
            _removeLogo = false;
          } else {
            _coverImage = File(pickedFile.path);
            _removeCover = false;
          }
        });

        // Add image to provider for later use
        if (mounted) {
          final provider = Provider.of<BusinessProfileProvider>(
            context,
            listen: false,
          );
          if (isLogo) {
            provider.addImage(File(pickedFile.path));
          } else {
            // Set banner image for cover image
            provider.setBannerImage(File(pickedFile.path));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _pickImageCamera({required bool isLogo}) async {
    // ✅ DEMO MODE: Block image capture for demo accounts
    if (checkDemoMode(context)) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          if (isLogo) {
            _logoImage = File(pickedFile.path);
            _removeLogo = false;
          } else {
            _coverImage = File(pickedFile.path);
            _removeCover = false;
          }
        });

        // Add image to provider for later use
        if (mounted) {
          final provider = Provider.of<BusinessProfileProvider>(
            context,
            listen: false,
          );
          if (isLogo) {
            provider.addImage(File(pickedFile.path));
          } else {
            // Set banner image for cover image
            provider.setBannerImage(File(pickedFile.path));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  // Step2 Style Business Hours Methods
  Widget _buildStep2StyleModeSelection(BusinessProfileProvider provider) {
    // Header with Hours text and mode dropdown
    return Container(
      decoration: BoxDecoration(
        color: Fp.inkRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Fp.hairlineStrong),
      ),
      padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(
            AppString.profileStrings.hours, //'Hours',
            style: Fp.h1.copyWith(
              fontWeight: FontWeight.w600,
              color: Fp.text,
            ),
          ),
          const Spacer(),
          // Mode dropdown selector
          PopupMenuButton<String>(
            onSelected: (String mode) {
              setState(() {
                _selectedHoursMode = mode;
              });

              // Update provider state and handle mode changes
              if (mode == 'alwaysOpen') {
                provider.setBusinessHoursType('always_open');
                // For always open mode, keep the current day selection but set 24-hour times for open days
                for (String day in provider.selectedOpenDays) {
                  provider.setIndividualDayTime(
                    day,
                    'openTime',
                    const TimeOfDay(hour: 0, minute: 0),
                  );
                  provider.setIndividualDayTime(
                    day,
                    'closeTime',
                    const TimeOfDay(hour: 0, minute: 0),
                  );
                }
              } else if (mode == 'appointmentsOnly') {
                provider.setBusinessHoursType('by_appointments');
                // Clear all open days for appointments only
                provider.selectedOpenDays.clear();
                provider.selectedCloseDays.clear();
                provider.selectedCloseDays.addAll(_weekdays);
              } else {
                provider.setBusinessHoursType('custom');
              }

              provider.refreshUI();
            },
            color: Fp.inkRaised,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.zero,
            position: PopupMenuPosition.under,
            offset: const Offset(20, 25),
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 250),
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'selectedHours',
                    padding: SizeConfig.getPaddingSymmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Open for selected hours',
                        style: Fp.h2.copyWith(
                          fontSize: SizeConfig.getFontSize(14),
                          color:
                              _selectedHoursMode == 'selectedHours'
                                  ? Fp.violet
                                  : Fp.text,
                          fontWeight:
                              _selectedHoursMode == 'selectedHours'
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'alwaysOpen',
                    padding: SizeConfig.getPaddingSymmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Always Open',
                        style: Fp.h2.copyWith(
                          fontSize: SizeConfig.getFontSize(14),
                          color:
                              _selectedHoursMode == 'alwaysOpen'
                                  ? Fp.violet
                                  : Fp.text,
                          fontWeight:
                              _selectedHoursMode == 'alwaysOpen'
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'appointmentsOnly',
                    padding: SizeConfig.getPaddingSymmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Appointments Only',
                        style: Fp.h2.copyWith(
                          fontSize: SizeConfig.getFontSize(14),
                          color:
                              _selectedHoursMode == 'appointmentsOnly'
                                  ? Fp.violet
                                  : Fp.text,
                          fontWeight:
                              _selectedHoursMode == 'appointmentsOnly'
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getModeDisplayText(),
                  style: Fp.h2.copyWith(
                    fontSize: SizeConfig.getFontSize(14),
                    color: Fp.violet,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: SizeConfig.width(1)),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: SizeConfig.getFontSize(14),
                  color: Fp.violet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2StyleBusinessHoursContent(
    BusinessProfileProvider provider,
  ) {
    // For Appointments Only, show a simple confirmation
    if (_selectedHoursMode == 'appointmentsOnly') {
      return _buildAppointmentsOnlyContent();
    }

    // Days list with toggle switches (Step2 Style)
    return _buildStep2StyleDaysListContent(provider);
  }

  Widget _buildAppointmentsOnlyContent() {
    return Container(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: Fp.inkRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Fp.hairlineStrong),
      ),
      child: Column(
        children: [
          // Icon
          Container(
            width: SizeConfig.sizedBoxWidth(60),
            height: SizeConfig.sizedBoxHeight(60),
            decoration: BoxDecoration(
              color: Fp.violet.withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.calendar_today,
              color: Fp.violet,
              size: SizeConfig.getFontSize(30),
            ),
          ),

          SizedBox(height: SizeConfig.height(2)),

          // Title
          Text(
            AppString.profileStrings.appointmentsOnly, //'Appointments Only',
            style: Fp.h1.copyWith(
              fontWeight: FontWeight.bold,
              color: Fp.text,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: SizeConfig.height(1)),

          // Description
          Text(
            '${AppString.profileStrings.yourBusineesOperates}\n${AppString.profileStrings.customersWillNeedTo}',
            style: Fp.caption.copyWith(
              fontSize: SizeConfig.getFontSize(14),
              color: Fp.textMuted,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Step2 Style unified days list content - single card with dividers
  Widget _buildStep2StyleDaysListContent(BusinessProfileProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Fp.inkRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Fp.hairlineStrong),
      ),
      child: Column(
        children: List.generate(_weekdays.length, (index) {
          final day = _weekdays[index];
          final label = _weekdayLabels[index];
          final isOpen = provider.selectedOpenDays.contains(day);
          final isConfigured = provider.isDayConfigured(day);
          final isLastItem = index == _weekdays.length - 1;
          final canEditHours = _selectedHoursMode == 'selectedHours';

          return Column(
            children: [
              InkWell(
                onTap:
                    canEditHours && isOpen
                        ? () => _showStep2StyleTimePickerForDay(
                          context,
                          provider,
                          day,
                          label,
                        )
                        : null,
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(12) : Radius.zero,
                  bottom: isLastItem ? const Radius.circular(12) : Radius.zero,
                ),
                child: Container(
                  padding: SizeConfig.getPaddingSymmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: Fp.h2.copyWith(
                                color: Fp.text,
                                fontWeight: FontWeight.w600,
                                fontSize: SizeConfig.getFontSize(14),
                              ),
                            ),
                            SizedBox(height: SizeConfig.height(0.4)),
                            Text(
                              _getDayStatusText(
                                day,
                                isOpen,
                                isConfigured,
                                provider,
                              ),
                              style: AppTypography.captionText(
                                context,
                              ).copyWith(
                                color:
                                    isOpen
                                        ? (_selectedHoursMode == 'alwaysOpen'
                                            ? Colors.green.shade600
                                            : (isConfigured
                                                ? Colors.green.shade600
                                                : AppThemeManage
                                                    .appTheme
                                                    .textGreyWhite))
                                        : Colors.red.shade400,
                                fontSize: SizeConfig.getFontSize(11),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Arrow icon for selected hours mode when open
                      if (canEditHours && isOpen)
                        Padding(
                          padding: EdgeInsets.only(right: SizeConfig.width(3)),
                          child: Icon(
                            Icons.keyboard_arrow_right,
                            color: Fp.textMuted,
                            size: SizeConfig.getFontSize(20),
                          ),
                        ),

                      // Toggle Switch
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: isOpen,
                          onChanged: (value) {
                            if (canEditHours && value) {
                              // For selected hours, open time picker immediately when toggling on
                              provider.toggleOpenDay(day);
                              if (!isConfigured) {
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  () {
                                    if (mounted) {
                                      _showStep2StyleTimePickerForDay(
                                        context,
                                        provider,
                                        day,
                                        label,
                                      );
                                    }
                                  },
                                );
                              }
                            } else {
                              provider.toggleOpenDay(day);
                            }
                          },
                          activeThumbColor: Colors.white,
                          activeTrackColor:
                              Fp.violet,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey.shade300,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Add divider except for last item
              if (!isLastItem)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Fp.hairlineStrong,
                  indent: 20,
                  endIndent: 20,
                ),
            ],
          );
        }),
      ),
    );
  }

  String _getDayStatusText(
    String day,
    bool isOpen,
    bool isConfigured,
    BusinessProfileProvider provider,
  ) {
    if (!isOpen) {
      return 'Closed';
    }

    if (_selectedHoursMode == 'alwaysOpen' && isOpen) {
      return 'Open 24 hours';
    } else if (_selectedHoursMode == 'selectedHours') {
      if (isConfigured) {
        return provider.getBusinessHoursDisplayText(day);
      } else {
        return 'Tap to set hours';
      }
    }
    return 'Open';
  }

  String _getModeDisplayText() {
    switch (_selectedHoursMode) {
      case 'selectedHours':
        return 'Open for selected hours';
      case 'alwaysOpen':
        return 'Always Open';
      case 'appointmentsOnly':
        return 'Appointments Only';
      default:
        return 'Open for selected hours';
    }
  }

  // Step2 Style Time Picker (copied from step2)
  void _showStep2StyleTimePickerForDay(
    BuildContext context,
    BusinessProfileProvider provider,
    String day,
    String dayLabel,
  ) {
    // Get current times or default values
    TimeOfDay currentOpenTime =
        provider.getIndividualDayTime(day, 'openTime') ??
        TimeOfDay(hour: 10, minute: 0);
    TimeOfDay currentCloseTime =
        provider.getIndividualDayTime(day, 'closeTime') ??
        TimeOfDay(hour: 22, minute: 0);

    TimeOfDay tempOpenTime = currentOpenTime;
    TimeOfDay tempCloseTime = currentCloseTime;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgColor.bgWhite,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: SizeConfig.getPaddingSymmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dayLabel,
                                  style: AppTypography.h3(
                                    context,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.close),
                              ),
                            ],
                          ),

                          SizedBox(height: SizeConfig.height(2)),

                          Text(
                            'Set business hours for $dayLabel',
                            style: Fp.caption,
                          ),

                          SizedBox(height: SizeConfig.height(3)),

                          // Open Time Section
                          _buildTimePickerSection(
                            'Opening Time',
                            tempOpenTime,
                            (TimeOfDay newTime) {
                              setState(() {
                                tempOpenTime = newTime;
                              });
                            },
                            context,
                          ),

                          SizedBox(height: SizeConfig.height(2)),

                          // Close Time Section
                          _buildTimePickerSection(
                            'Closing Time',
                            tempCloseTime,
                            (TimeOfDay newTime) {
                              setState(() {
                                tempCloseTime = newTime;
                              });
                            },
                            context,
                          ),

                          SizedBox(height: SizeConfig.height(3)),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                provider.setIndividualDayTime(
                                  day,
                                  'openTime',
                                  tempOpenTime,
                                );
                                provider.setIndividualDayTime(
                                  day,
                                  'closeTime',
                                  tempCloseTime,
                                );
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Fp.violet,
                                padding: SizeConfig.getPaddingSymmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Save Hours',
                                style: Fp.h2.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: SizeConfig.height(1)),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildTimePickerSection(
    String title,
    TimeOfDay time,
    Function(TimeOfDay) onTimeChanged,
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Fp.hairlineStrong),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Fp.caption.copyWith(
              color: Fp.textMuted,
              fontSize: SizeConfig.getFontSize(12),
            ),
          ),
          SizedBox(height: SizeConfig.height(1)),
          GestureDetector(
            onTap: () {
              _showCupertinoTimePicker(context, time, onTimeChanged);
            },
            child: Container(
              width: double.infinity,
              padding: SizeConfig.getPaddingSymmetric(
                horizontal: 12,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: Fp.ink,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Fp.hairlineStrong),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Fp.violet,
                    size: SizeConfig.getFontSize(20),
                  ),
                  SizedBox(width: SizeConfig.width(2)),
                  Text(
                    time.format(context),
                    style: Fp.h2.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Fp.text,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Fp.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Map Widget (Stepper Style)
  Widget _buildMapWidget(BusinessProfileProvider provider) {
    // Use default coordinates for now - can be enhanced to use actual location
    final lat = 40.7128; // Default to NYC
    final lng = -74.0060;
    final LatLng businessLocation = LatLng(lat, lng);

    return Container(
      decoration: BoxDecoration(
        color: Fp.inkRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Fp.hairlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map Header
          Padding(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Fp.violet,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  AppString
                      .profileStrings
                      .businessLocation, //'Business Location',
                  style: Fp.h2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Fp.text,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    // Navigate to map picker screen
                    _showMapPicker(provider);
                  },
                  child: Text(
                    AppString.profileStrings.change, //'Change',
                    style: Fp.caption.copyWith(
                      color: Fp.violet,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Map Container
          SizedBox(
            height: 200,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: businessLocation,
                  zoom: 15.0,
                ),
                markers: {
                  Marker(
                    markerId: MarkerId('business_location'),
                    position: businessLocation,
                    infoWindow: InfoWindow(
                      title: 'Business Location',
                      snippet:
                          provider.controllers['location']?.text ??
                          'Tap to set location',
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                  ),
                },
                mapType: MapType.normal,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: false,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                onTap: (LatLng location) {
                  _showMapPicker(provider);
                },
                onMapCreated: (GoogleMapController controller) {
                  // Map created callback
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMapPicker(BusinessProfileProvider provider) {
    // Use the same BusinessLocationPicker as in Step3
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => BusinessLocationPicker(
              initialAddress: provider.controllers['location']?.text,
              initialLatitude: provider.businessLatitude,
              initialLongitude: provider.businessLongitude,
              onLocationSelected: (address, latitude, longitude) {
                // Update provider with new location data
                provider.controllers['location']?.text = address;
                provider.setBusinessCoordinates(latitude, longitude);
              },
            ),
      ),
    );
  }

  void _showCupertinoTimePicker(
    BuildContext context,
    TimeOfDay initialTime,
    Function(TimeOfDay) onTimeChanged,
  ) {
    DateTime initialDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      initialTime.hour,
      initialTime.minute,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: SizeConfig.sizedBoxHeight(300),
            decoration: BoxDecoration(
              color: AppColors.bgColor.bgWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: SizeConfig.getPaddingSymmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: Fp.h2,
                        ),
                      ),
                      Text(
                        'Select Time',
                        style: Fp.h1.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Fp.text,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Done',
                          style: Fp.h2.copyWith(
                            color: Fp.violet,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: Fp.hairlineStrong),

                // Cupertino Time Picker
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: false,
                    initialDateTime: initialDateTime,
                    onDateTimeChanged: (DateTime newDateTime) {
                      final newTime = TimeOfDay(
                        hour: newDateTime.hour,
                        minute: newDateTime.minute,
                      );
                      onTimeChanged(newTime);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _saveProfile() async {
    // ✅ DEMO MODE: Block profile save for demo accounts
    if (checkDemoMode(context)) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final provider = Provider.of<BusinessProfileProvider>(
        context,
        listen: false,
      );

      // Prepare all profile data
      final profileData = {
        'full_name': provider.controllers['full_name']?.text.trim(),
        'description': provider.controllers['description']?.text.trim(),
        'category_id': provider.selectedCategoryId,
        'location': provider.controllers['location']?.text.trim(),
        'website': provider.controllers['website']?.text.trim(),
        'facebook_link': provider.controllers['facebook_link']?.text.trim(),
        'instagram_link': provider.controllers['instagram_link']?.text.trim(),
        'linkedin_link': provider.controllers['linkedin_link']?.text.trim(),
        'youtube_link': provider.controllers['youtube_link']?.text.trim(),
        'vk_link': provider.controllers['vk_link']?.text.trim(),
      };

      // Add business hours data based on the selected mode
      if (_selectedHoursMode == 'alwaysOpen') {
        profileData['always_open'] = true;
        profileData['appointments_only'] = false;
        profileData['open_days'] = provider.selectedOpenDays;
        profileData['close_days'] = provider.selectedCloseDays;
        final businessHoursData = provider.getBusinessHoursForAPI();
        profileData.addAll(businessHoursData);
      } else if (_selectedHoursMode == 'appointmentsOnly') {
        profileData['always_open'] = false;
        profileData['appointments_only'] = true;
        profileData['open_days'] = [];
        profileData['close_days'] = _weekdays;
      } else if (_selectedHoursMode == 'selectedHours') {
        profileData['always_open'] = false;
        profileData['appointments_only'] = false;
        profileData['open_days'] = provider.selectedOpenDays;
        profileData['close_days'] = provider.selectedCloseDays;
        final businessHoursData = provider.getBusinessHoursForAPI();
        profileData.addAll(businessHoursData);
      }

      // Handle website URL - auto-add https:// if needed
      String website = provider.controllers['website']?.text.trim() ?? '';
      if (website.isNotEmpty) {
        if (!website.startsWith('http://') && !website.startsWith('https://')) {
          website = 'https://$website';
        }
      }
      profileData['website'] = website;

      // Staged removals of images already on the server: an empty
      // `cover_image_url` clears the cover; the logo is the account avatar, so
      // it is removed through the avatar endpoint.
      if (_removeCover && _coverImage == null) {
        profileData['remove_cover'] = true;
      }
      if (_removeLogo && _logoImage == null) {
        await provider.removeLogo();
      }

      // Prepare files for upload with multiple file keys
      if (_logoImage != null || _coverImage != null) {
        profileData['pictureType'] =
            'profile_pic'; // Always use profile_pic when any image is selected

        Map<String, File> fileMap = {};

        if (_logoImage != null) {
          fileMap['files'] = _logoImage!;
          debugPrint(
            'EditBusinessProfile: Adding profile picture with key: files, filePath: ${_logoImage!.path}',
          );
        }

        if (_coverImage != null) {
          fileMap['banner_image'] = _coverImage!;
          debugPrint(
            'EditBusinessProfile: Adding banner image with key: banner_image, filePath: ${_coverImage!.path}',
          );
        }

        debugPrint(
          'EditBusinessProfile: Sending single request with ${fileMap.length} images and pictureType: profile_pic',
        );

        // Send single request with multiple files
        await provider.updateBusinessProfileRepoMultipleFiles(
          profileData,
          fileMap,
        );
      } else {
        // No images selected, just update profile data
        await provider.updateBusinessProfileRepo(profileData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future bottomSheetCameraGallery(
    BuildContext context, {
    required bool isLogo,
  }) {
    return bottomSheetGobal(
      context,
      bottomsheetHeight: SizeConfig.safeHeight(30),
      title: AppString.settingStrigs.profilePhoto,
      child: Column(
        children: [
          SizedBox(height: SizeConfig.height(3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              bottomContainer(
                context,
                title: AppString.settingStrigs.camera,
                img: AppAssets.svgIcons.camera,
                onTap: () {
                  _pickImageCamera(isLogo: isLogo);
                  //authProvider.getImageFromCamera();
                  Navigator.pop(context);
                },
              ),
              SizedBox(width: SizeConfig.width(15)),
              bottomContainer(
                context,
                title: AppString.settingStrigs.gellery,
                img: AppAssets.svgIcons.gellery,
                onTap: () {
                  _pickImage(isLogo: isLogo);
                  //authProvider.getImageFromGallery();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget bottomContainer(
    BuildContext context, {
    required String title,
    required String img,
    required Function() onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Fp.cyan.withValues(
                alpha: 0.30,
              ),
            ),
            child: Padding(
              padding: SizeConfig.getPadding(12),
              child: Center(
                child: SvgPicture.asset(
                  img,
                  height: 22,
                  color: Fp.text,
                ),
              ),
            ),
          ),
          SizedBox(height: SizeConfig.height(1)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Fp.caption,
          ),
        ],
      ),
    );
  }
}
