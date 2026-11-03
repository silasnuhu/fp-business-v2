import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/auth/provider/business_profile_provider.dart';
import 'package:whoxa/featuers/auth/screens/steps/step1_business_info.dart';
import 'package:whoxa/featuers/auth/screens/steps/step2_business_hours.dart';
import 'package:whoxa/featuers/auth/screens/steps/step3_location_website.dart';
import 'package:whoxa/featuers/auth/screens/steps/step4_social_accounts.dart';
import 'package:whoxa/featuers/auth/screens/steps/step5_catalog.dart';
import 'package:whoxa/widgets/custom_step_indicator.dart';
import 'package:whoxa/widgets/global.dart';

/// Five-step business profile setup, rebuilt on the Flickpitch design system.
///
/// The step content widgets, validation rules and provider calls are
/// untouched - only the shell (header, progress rail, footer buttons,
/// snackbars) was moved off the stock theme kit.
class BusinessProfileStepper extends StatefulWidget {
  const BusinessProfileStepper({super.key});

  @override
  State<BusinessProfileStepper> createState() => _BusinessProfileStepperState();
}

class _BusinessProfileStepperState extends State<BusinessProfileStepper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndCheckProfile();
    });
  }

  Future<void> _initializeAndCheckProfile() async {
    final provider = Provider.of<BusinessProfileProvider>(
      context,
      listen: false,
    );
    await provider.initializeProfileSetup();

    // Already set up (e.g. reached this screen by mistake): go to the app.
    if (mounted && provider.isSetupComplete) {
      provider.redirectToMainApp(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Fp.ink,
        body: FpCanvas(
          child: SafeArea(
            child: Consumer<BusinessProfileProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Fp.violet),
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Fp.s20,
                        Fp.s12,
                        Fp.s20,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BUSINESS SETUP', style: Fp.label.copyWith(color: Fp.violetGlow)),
                          const SizedBox(height: Fp.s4),
                          Text('Set up your business', style: Fp.display),
                        ],
                      ),
                    ),
                    const SizedBox(height: Fp.s12),
                    CustomStepIndicator(
                      currentStep: provider.currentStep,
                      totalSteps: 5,
                      stepTitles: const [
                        'Business Information',
                        'Business Hours',
                        'More ways to find you',
                        'Add Social Media',
                        'Add Catalouge',
                      ],
                      onBackPressed: () => provider.previousStep(),
                    ),
                    Expanded(child: _buildStepContent(provider.currentStep)),
                    if (provider.currentStep != 4) _buildNavigationButtons(provider),
                    if (provider.currentStep == 4 && provider.catalogs.isNotEmpty)
                      _buildCatalogNavigationButtons(provider),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(int currentStep) {
    switch (currentStep) {
      case 0:
        return const Step1BusinessInfo();
      case 1:
        return Step2BusinessHours(key: Step2BusinessHours.stepKey);
      case 2:
        return const Step3LocationWebsite();
      case 3:
        return const Step4SocialAccounts();
      case 4:
        return const Step5Catalog();
      default:
        return const Step1BusinessInfo();
    }
  }

  Widget _footer(Widget child) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Fp.s20, Fp.s16, Fp.s20, Fp.s16),
      decoration: BoxDecoration(
        color: Fp.inkSoft,
        border: Border(top: BorderSide(color: Fp.hairline)),
      ),
      child: SafeArea(child: child),
    );
  }

  Widget _primaryAction({
    required String label,
    required VoidCallback onPressed,
    required bool busy,
  }) {
    if (busy) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Fp.rPill),
          color: Fp.violet.withValues(alpha: 0.4),
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ),
      );
    }
    return FpPrimaryButton(
      label: label,
      expand: true,
      onPressed: onPressed,
    );
  }

  Widget _buildNavigationButtons(BusinessProfileProvider provider) {
    final bool isOptionalStep = provider.currentStep >= 3;
    final bool isLastStep = provider.currentStep == 4;
    final bool isBusinessHoursStep = provider.currentStep == 1;

    return _footer(
      Row(
        children: [
          if (isOptionalStep && !isLastStep) ...[
            Expanded(
              child: FpGhostButton(
                label: 'Skip',
                expand: true,
                onPressed: () => _handleSkipStep(provider),
              ),
            ),
            const SizedBox(width: Fp.s12),
          ],
          Expanded(
            flex: isOptionalStep && !isLastStep ? 2 : 1,
            child: _primaryAction(
              label: isLastStep
                  ? 'Complete Setup'
                  : (isBusinessHoursStep
                      ? Step2BusinessHours.getButtonText()
                      : 'Continue'),
              busy: provider.isSubmitting,
              onPressed: () => _handleNextStep(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogNavigationButtons(BusinessProfileProvider provider) {
    return _footer(
      _primaryAction(
        label: 'Get Started',
        busy: provider.isSubmitting,
        onPressed: () => _handleCatalogComplete(provider),
      ),
    );
  }

  void _handleSkipStep(BusinessProfileProvider provider) async {
    final wasLastStep = provider.currentStep == 4;
    await provider.skipStep();

    if (wasLastStep && mounted) {
      provider.redirectToMainApp(context);
    }
  }

  void _handleCatalogComplete(BusinessProfileProvider provider) async {
    try {
      await provider.nextStep();
      if (mounted) {
        provider.redirectToMainApp(context);
      }
    } catch (e) {
      if (mounted) {
        snackbarNew(context, msg: 'Failed to complete setup: $e');
      }
    }
  }

  /// Flickpitch-styled validation/error toast, matching the old copy exactly.
  void _showError(String message, {bool withOk = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: Fp.body.copyWith(color: Colors.white)),
        backgroundColor: Fp.danger,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Fp.rSm),
        ),
        margin: const EdgeInsets.all(Fp.s16),
        action: withOk
            ? SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              )
            : null,
      ),
    );
  }

  void _handleNextStep(BusinessProfileProvider provider) async {
    // Special handling for Business Hours internal navigation
    if (provider.currentStep == 1 && Step2BusinessHours.isOnInternalStepOne()) {
      final selectedMode = Step2BusinessHours.getSelectedMode();
      if (selectedMode != null && selectedMode.isNotEmpty) {
        Step2BusinessHours.handleInternalNext(provider);
        return;
      }
      _showError('Please select a business hours option');
      return;
    }

    // Validate form fields on current step
    bool isFormValid = true;
    String validationMessage = '';

    switch (provider.currentStep) {
      case 0:
        if (provider.controllers['full_name']?.text.trim().isEmpty ?? true) {
          isFormValid = false;
          validationMessage = 'Please enter business name';
        } else if (provider.controllers['description']?.text.trim().isEmpty ??
            true) {
          isFormValid = false;
          validationMessage = 'Please enter business description';
        } else if (provider.selectedCategoryId == null) {
          isFormValid = false;
          validationMessage = 'Please select a category';
        }
        break;
      case 1:
        isFormValid = Step2BusinessHours.validateCurrentStep(provider);
        if (!isFormValid) {
          validationMessage = Step2BusinessHours.getCurrentValidationMessage();
        }
        break;
    }

    if (!isFormValid) {
      _showError(validationMessage, withOk: true);
      return;
    }

    final bool wasLastStep = provider.currentStep == 4;
    final success = await provider.nextStep();

    if (!success && mounted) {
      _showError(provider.errorMessage, withOk: true);
    } else if (success && wasLastStep && mounted) {
      provider.redirectToMainApp(context);
    }
  }
}
