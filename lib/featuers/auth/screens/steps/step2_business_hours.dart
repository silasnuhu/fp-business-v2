import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/business_profile_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

class Step2BusinessHours extends StatefulWidget {
  const Step2BusinessHours({super.key});

  @override
  State<Step2BusinessHours> createState() => _Step2BusinessHoursState();

  // Create a public validation interface
  static bool validateCurrentStep(BusinessProfileProvider provider) {
    final state = stepKey.currentState;
    return state?.validateStep(provider) ?? false;
  }

  static String getCurrentValidationMessage() {
    final state = stepKey.currentState;
    return state?.getValidationMessage() ??
        'Please complete the business hours setup';
  }

  // Check if we're currently on step 1 (mode selection) within the component
  static bool isOnInternalStepOne() {
    final state = stepKey.currentState;
    return state?._showStepTwo != true;
  }

  // Handle the Next button action for internal step navigation
  static void handleInternalNext(BusinessProfileProvider provider) {
    final state = stepKey.currentState;
    if (state != null && state._selectedMode.isNotEmpty) {
      state._handleInternalNext(provider);
    }
  }

  // Get the button text based on current internal step
  static String getButtonText() {
    return isOnInternalStepOne() ? 'Next' : 'Continue';
  }

  // Get selected mode for validation
  static String? getSelectedMode() {
    final state = stepKey.currentState;
    return state?._selectedMode;
  }

  // Private global key for internal use
  // ignore: library_private_types_in_public_api
  static final GlobalKey<_Step2BusinessHoursState> stepKey =
      GlobalKey<_Step2BusinessHoursState>();
}

class _Step2BusinessHoursState extends State<Step2BusinessHours> {
  bool _showStepTwo = false;
  String _selectedMode = '';

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
  Widget build(BuildContext context) {
    return Consumer<BusinessProfileProvider>(
      builder: (context, provider, child) {
        return _showStepTwo
            ? _buildStepTwoContent(provider)
            : _buildStepOneContent(provider);
      },
    );
  }

  // Step 1: Mode Selection Screen
  Widget _buildStepOneContent(BusinessProfileProvider provider) {
    return SingleChildScrollView(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(height: SizeConfig.height(3)),

          // Title
          Text(
            'Add Your Business Hours',
            style: AppTypography.h3(context).copyWith(
              fontWeight: FontWeight.bold,
              fontSize: SizeConfig.getFontSize(18),
              color: AppThemeManage.appTheme.textColor,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: SizeConfig.height(1)),

          Text(
            'Let customer know when you are open\nand close each day',
            style: AppTypography.captionText(context).copyWith(
              fontSize: SizeConfig.getFontSize(13),
              color: AppThemeManage.appTheme.textGreyWhite,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: SizeConfig.height(4)),

          // Mode Selection Radio Options
          _buildRadioOption('selectedHours', 'Open for selected hours'),

          SizedBox(height: SizeConfig.height(1.5)),

          _buildRadioOption('alwaysOpen', 'Always Open'),

          SizedBox(height: SizeConfig.height(1.5)),

          _buildRadioOption('appointmentsOnly', 'Appointments Only'),

          SizedBox(height: SizeConfig.height(3)),
        ],
      ),
    );
  }

  // Step 2: Day List View
  Widget _buildStepTwoContent(BusinessProfileProvider provider) {
    // For Appointments Only, show a simple confirmation screen
    if (_selectedMode == 'appointmentsOnly') {
      return _buildAppointmentsOnlyContent();
    }

    return SingleChildScrollView(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(height: SizeConfig.height(2)),

          // Header with Hours text and mode dropdown
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: 20,
              vertical: 16,
            ),
            child: Row(
              children: [
                Text(
                  'Hours',
                  style: AppTypography.h4(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppThemeManage.appTheme.textColor,
                  ),
                ),
                const Spacer(),
                // Mode dropdown selector
                PopupMenuButton<String>(
                  onSelected: (String mode) {
                    setState(() {
                      _selectedMode = mode;
                    });

                    // Update provider state - provider handles all mode-specific logic
                    if (mode == 'alwaysOpen') {
                      provider.setBusinessHoursType('always_open');
                    } else if (mode == 'appointmentsOnly') {
                      provider.setBusinessHoursType('by_appointments');
                    } else {
                      provider.setBusinessHoursType('custom');
                    }

                    provider.refreshUI();
                  },
                  color: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.zero,
                  position: PopupMenuPosition.under,
                  offset: const Offset(20, 25),
                  constraints: const BoxConstraints(
                    minWidth: 200,
                    maxWidth: 250,
                  ),
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
                              style: AppTypography.h5(context).copyWith(
                                fontSize: SizeConfig.getFontSize(14),
                                color:
                                    _selectedMode == 'selectedHours'
                                        ? AppColors.appPriSecColor.primaryColor
                                        : AppThemeManage.appTheme.textColor,
                                fontWeight:
                                    _selectedMode == 'selectedHours'
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
                              style: AppTypography.h5(context).copyWith(
                                fontSize: SizeConfig.getFontSize(14),
                                color:
                                    _selectedMode == 'alwaysOpen'
                                        ? AppColors.appPriSecColor.primaryColor
                                        : AppThemeManage.appTheme.textColor,
                                fontWeight:
                                    _selectedMode == 'alwaysOpen'
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
                              'Appointment Only',
                              style: AppTypography.h5(context).copyWith(
                                fontSize: SizeConfig.getFontSize(14),
                                color:
                                    _selectedMode == 'appointmentsOnly'
                                        ? AppColors.appPriSecColor.primaryColor
                                        : AppThemeManage.appTheme.textColor,
                                fontWeight:
                                    _selectedMode == 'appointmentsOnly'
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
                        style: AppTypography.h5(context).copyWith(
                          fontSize: SizeConfig.getFontSize(14),
                          color: AppColors.appPriSecColor.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: SizeConfig.width(1)),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: SizeConfig.getFontSize(14),
                        color: AppColors.appPriSecColor.primaryColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: SizeConfig.height(2)),

          // Days list with toggle switches
          _buildDaysListContent(provider),

          SizedBox(height: SizeConfig.height(3)),
        ],
      ),
    );
  }

  // Appointments Only confirmation screen
  Widget _buildAppointmentsOnlyContent() {
    return SingleChildScrollView(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(height: SizeConfig.height(6)),

          // Icon
          Container(
            width: SizeConfig.sizedBoxWidth(80),
            height: SizeConfig.sizedBoxHeight(80),
            decoration: BoxDecoration(
              color: AppColors.appPriSecColor.primaryColor.withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.calendar_today,
              color: AppColors.appPriSecColor.primaryColor,
              size: SizeConfig.getFontSize(40),
            ),
          ),

          SizedBox(height: SizeConfig.height(4)),

          // Title
          Text(
            'Appointments Only',
            style: AppTypography.h3(context).copyWith(
              fontWeight: FontWeight.bold,
              fontSize: SizeConfig.getFontSize(22),
              color: AppThemeManage.appTheme.textColor,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: SizeConfig.height(2)),

          // Description
          Text(
            'Your business operates by appointments only.\nCustomers will need to book appointments\nto visit your business.',
            style: AppTypography.captionText(context).copyWith(
              fontSize: SizeConfig.getFontSize(16),
              color: AppThemeManage.appTheme.textGreyWhite,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: SizeConfig.height(6)),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String mode, String title) {
    final isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = mode;
        });
      },
      child: Container(
        width: double.infinity,
        padding: SizeConfig.getPaddingSymmetric(horizontal: 0, vertical: 12),
        child: Row(
          children: [
            // Radio button
            Container(
              width: SizeConfig.sizedBoxWidth(20),
              height: SizeConfig.sizedBoxHeight(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected
                          ? AppColors.appPriSecColor.primaryColor
                          : AppThemeManage.appTheme.borderColor,
                  width: 2,
                ),
                color: Colors.transparent,
              ),
              child:
                  isSelected
                      ? Center(
                        child: Container(
                          width: SizeConfig.sizedBoxWidth(10),
                          height: SizeConfig.sizedBoxHeight(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.appPriSecColor.primaryColor,
                          ),
                        ),
                      )
                      : null,
            ),

            SizedBox(width: SizeConfig.width(3)),

            // Title text
            Expanded(
              child: Text(
                title,
                style: AppTypography.h5(context).copyWith(
                  fontWeight: FontWeight.w400,
                  fontSize: SizeConfig.getFontSize(14),
                  color: AppThemeManage.appTheme.textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Unified days list content - single card with dividers
  Widget _buildDaysListContent(BusinessProfileProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: List.generate(_weekdays.length, (index) {
          final day = _weekdays[index];
          final label = _weekdayLabels[index];
          final isOpen = provider.selectedOpenDays.contains(day);
          final isConfigured = provider.isDayConfigured(day);
          final isLastItem = index == _weekdays.length - 1;
          final canEditHours = _selectedMode == 'selectedHours';

          return Column(
            children: [
              InkWell(
                onTap:
                    canEditHours && isOpen
                        ? () =>
                            _showTimePickerForDay(context, provider, day, label)
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
                              style: AppTypography.h5(context).copyWith(
                                color: AppThemeManage.appTheme.textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: SizeConfig.getFontSize(14),
                              ),
                            ),
                            SizedBox(height: SizeConfig.height(0.4)),
                            Text(
                              _getDayStatusText(day, isOpen, isConfigured),
                              style: AppTypography.captionText(
                                context,
                              ).copyWith(
                                color:
                                    isOpen
                                        ? (_selectedMode == 'alwaysOpen'
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
                            color: AppThemeManage.appTheme.textGreyWhite,
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
                                      _showTimePickerForDay(
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
                              AppColors.appPriSecColor.primaryColor,
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
                  color: Colors.grey.shade200,
                  indent: 20,
                  endIndent: 20,
                ),
            ],
          );
        }),
      ),
    );
  }

  // Public validation method that can be called by parent stepper
  bool validateStep(BusinessProfileProvider provider) {
    if (!_showStepTwo) {
      // Step 1: Must have selected a mode
      return _selectedMode.isNotEmpty;
    } else {
      // Step 2: Validate based on selected mode
      if (_selectedMode == 'appointmentsOnly') {
        return true;
      }
      if (_selectedMode == 'alwaysOpen') {
        return provider.selectedOpenDays.isNotEmpty;
      }
      if (_selectedMode == 'selectedHours') {
        // Must have at least one day with configured hours
        return provider.selectedOpenDays.any(
          (day) => provider.isDayConfigured(day),
        );
      }
    }
    return false;
  }

  // Method to get validation error message
  String getValidationMessage() {
    if (!_showStepTwo) {
      return 'Please select a business hours option';
    } else {
      if (_selectedMode == 'alwaysOpen') {
        return 'Please select at least one day to be open';
      }
      if (_selectedMode == 'selectedHours') {
        return 'Please configure hours for at least one day';
      }
    }
    return 'Please complete the business hours setup';
  }

  // Internal method to handle the Next button action
  void _handleInternalNext(BusinessProfileProvider provider) {
    setState(() {
      _showStepTwo = true;
    });

    // Set the provider state - provider handles all mode-specific logic
    if (_selectedMode == 'alwaysOpen') {
      provider.setBusinessHoursType('always_open');
    } else if (_selectedMode == 'appointmentsOnly') {
      provider.setBusinessHoursType('by_appointments');
    } else {
      provider.setBusinessHoursType('custom');
    }

    // Trigger parent stepper rebuild
    provider.refreshUI();
  }

  String _getDayStatusText(String day, bool isOpen, bool isConfigured) {
    if (!isOpen) {
      return 'Closed';
    }

    if (_selectedMode == 'alwaysOpen') {
      return 'Open 24 hours';
    } else if (_selectedMode == 'selectedHours') {
      if (isConfigured) {
        return _formatTimeRange(day);
      } else {
        return 'Tap to set hours';
      }
    }
    return 'Open';
  }

  String _formatTimeRange(String day) {
    final provider = Provider.of<BusinessProfileProvider>(
      context,
      listen: false,
    );
    return provider.getBusinessHoursDisplayText(day);
  }

  String _getModeDisplayText() {
    switch (_selectedMode) {
      case 'selectedHours':
        return 'Open for selected hours';
      case 'alwaysOpen':
        return 'Always Open';
      case 'appointmentsOnly':
        return 'Appointments Only';
      default:
        return '';
    }
  }

  // Show mode selection bottom sheet

  void _showTimePickerForDay(
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
                                  ).copyWith(fontWeight: FontWeight.w600),
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
                            style: AppTypography.captionText(context).copyWith(
                              color: AppThemeManage.appTheme.textGreyWhite,
                            ),
                          ),

                          SizedBox(height: SizeConfig.height(3)),

                          // Open Time Section
                          Container(
                            width: double.infinity,
                            padding: SizeConfig.getPaddingSymmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppThemeManage.appTheme.borderColor,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Opening Time',
                                  style: AppTypography.captionText(
                                    context,
                                  ).copyWith(
                                    color:
                                        AppThemeManage.appTheme.textGreyWhite,
                                    fontSize: SizeConfig.getFontSize(12),
                                  ),
                                ),
                                SizedBox(height: SizeConfig.height(1)),
                                GestureDetector(
                                  onTap: () {
                                    _showCupertinoTimePicker(
                                      context,
                                      tempOpenTime,
                                      (TimeOfDay newTime) {
                                        setState(() {
                                          tempOpenTime = newTime;
                                        });
                                      },
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: SizeConfig.getPaddingSymmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          AppThemeManage
                                              .appTheme
                                              .scaffoldBackColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            AppThemeManage.appTheme.borderColor,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          color:
                                              AppColors
                                                  .appPriSecColor
                                                  .primaryColor,
                                          size: SizeConfig.getFontSize(20),
                                        ),
                                        SizedBox(width: SizeConfig.width(2)),
                                        Text(
                                          tempOpenTime.format(context),
                                          style: AppTypography.h5(
                                            context,
                                          ).copyWith(
                                            fontWeight: FontWeight.w500,
                                            color:
                                                AppThemeManage
                                                    .appTheme
                                                    .textColor,
                                          ),
                                        ),
                                        Spacer(),
                                        Icon(
                                          Icons.keyboard_arrow_down,
                                          color:
                                              AppThemeManage
                                                  .appTheme
                                                  .textGreyWhite,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: SizeConfig.height(2)),

                          // Close Time Section
                          Container(
                            width: double.infinity,
                            padding: SizeConfig.getPaddingSymmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppThemeManage.appTheme.borderColor,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Closing Time',
                                  style: AppTypography.captionText(
                                    context,
                                  ).copyWith(
                                    color:
                                        AppThemeManage.appTheme.textGreyWhite,
                                    fontSize: SizeConfig.getFontSize(12),
                                  ),
                                ),
                                SizedBox(height: SizeConfig.height(1)),
                                GestureDetector(
                                  onTap: () {
                                    _showCupertinoTimePicker(
                                      context,
                                      tempCloseTime,
                                      (TimeOfDay newTime) {
                                        setState(() {
                                          tempCloseTime = newTime;
                                        });
                                      },
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: SizeConfig.getPaddingSymmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          AppThemeManage
                                              .appTheme
                                              .scaffoldBackColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            AppThemeManage.appTheme.borderColor,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          color:
                                              AppColors
                                                  .appPriSecColor
                                                  .primaryColor,
                                          size: SizeConfig.getFontSize(20),
                                        ),
                                        SizedBox(width: SizeConfig.width(2)),
                                        Text(
                                          tempCloseTime.format(context),
                                          style: AppTypography.h5(
                                            context,
                                          ).copyWith(
                                            fontWeight: FontWeight.w500,
                                            color:
                                                AppThemeManage
                                                    .appTheme
                                                    .textColor,
                                          ),
                                        ),
                                        Spacer(),
                                        Icon(
                                          Icons.keyboard_arrow_down,
                                          color:
                                              AppThemeManage
                                                  .appTheme
                                                  .textGreyWhite,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                                    AppColors.appPriSecColor.primaryColor,
                                padding: SizeConfig.getPaddingSymmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Save Hours',
                                style: AppTypography.h5(context).copyWith(
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
                          style: AppTypography.h5(context).copyWith(
                            color: AppThemeManage.appTheme.textGreyWhite,
                          ),
                        ),
                      ),
                      Text(
                        'Select Time',
                        style: AppTypography.h4(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeManage.appTheme.textColor,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Done',
                          style: AppTypography.h5(context).copyWith(
                            color: AppColors.appPriSecColor.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: AppThemeManage.appTheme.borderColor),

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
}
