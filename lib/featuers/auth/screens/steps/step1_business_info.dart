import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/business_profile_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/widgets/global_textfield.dart';

class Step1BusinessInfo extends StatefulWidget {
  const Step1BusinessInfo({super.key});

  @override
  State<Step1BusinessInfo> createState() => _Step1BusinessInfoState();
}

class _Step1BusinessInfoState extends State<Step1BusinessInfo> {
  final _formKey = GlobalKey<FormState>();
  File? _coverImage;
  File? _logoImage;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProfileProvider>(
      builder: (context, provider, child) {
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Cover Image Header with Logo
                _buildCoverImageHeader(),

                // Form Content
                Padding(
                  padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: SizeConfig.height(3)),

                      // Business Name Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: AppTypography.innerText12Mediu(
                                context,
                              ).copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppThemeManage.appTheme.textColor,
                              ),
                              children: [
                                const TextSpan(text: 'Business Name '),
                                TextSpan(
                                  text: '*',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),

                          GlobalTextField1(
                            hintText: 'Enter your business name',
                            controller: provider.controllers['full_name']!,
                            context: context,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.sentences,
                            onEditingComplete: () {},
                            maxLength: 50,
                            validator: (value) {
                              if (value?.trim().isEmpty ?? true) {
                                return 'Please enter business name';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      SizedBox(height: SizeConfig.height(2)),

                      // Description Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: AppTypography.innerText12Mediu(
                                context,
                              ).copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppThemeManage.appTheme.textColor,
                              ),
                              children: [
                                const TextSpan(text: 'Description '),
                                TextSpan(
                                  text: '*',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: SizeConfig.height(0.5)),
                          Container(
                            height: SizeConfig.sizedBoxHeight(140),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppThemeManage.appTheme.borderColor,
                              ),
                              color: AppThemeManage.appTheme.scaffoldBackColor,
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                        provider.controllers['description']!,
                                    keyboardType: TextInputType.multiline,
                                    maxLines: null,
                                    minLines: 4,
                                    maxLength: 100,
                                    textAlign: TextAlign.start,
                                    textAlignVertical: TextAlignVertical.top,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    expands: false,
                                    style: AppTypography.captionText(
                                      context,
                                    ).copyWith(
                                      color: AppThemeManage.appTheme.textColor,
                                      height: 1.4,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter business description...',
                                      hintStyle: AppTypography.captionText(
                                        context,
                                      ).copyWith(
                                        color:
                                            AppThemeManage
                                                .appTheme
                                                .textGreyWhite,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      contentPadding:
                                          SizeConfig.getPaddingSymmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                      counterText: '', // Hide default counter
                                      alignLabelWithHint: true,
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.never,
                                    ),
                                    validator: (value) {
                                      if (value?.trim().isEmpty ?? true) {
                                        return 'Please enter business description';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      // Trigger rebuild to update character counter
                                      setState(() {});
                                    },
                                  ),
                                ),
                                // Custom character counter
                                Container(
                                  padding: SizeConfig.getPaddingSymmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${provider.controllers['description']!.text.length}/100',
                                    style: AppTypography.captionText(
                                      context,
                                    ).copyWith(
                                      color:
                                          AppThemeManage.appTheme.textGreyWhite,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: SizeConfig.height(2)),

                      // Category Selection
                      RichText(
                        text: TextSpan(
                          style: AppTypography.innerText12Mediu(
                            context,
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppThemeManage.appTheme.textColor,
                          ),
                          children: [
                            const TextSpan(text: 'Category '),
                            TextSpan(
                              text: '*',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: SizeConfig.height(1)),

                      _buildCategoryDropdown(provider),

                      SizedBox(height: SizeConfig.height(4)),

                      // Contact Details Section
                      _buildContactDetailsSection(provider),

                      SizedBox(height: SizeConfig.height(10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverImageHeader() {
    return SizedBox(
      height: SizeConfig.sizedBoxHeight(250),
      child: Stack(
        children: [
          // Cover Image Background
          Container(
            height: SizeConfig.sizedBoxHeight(200),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient:
                  _coverImage == null
                      ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.appPriSecColor.primaryColor.withValues(
                            alpha: 0.8,
                          ),
                          AppColors.appPriSecColor.secondaryColor.withValues(
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
                _coverImage == null
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
                            'Add Cover Image',
                            style: AppTypography.captionText(context).copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : null,
          ),

          // Cover Image Tap Area
          if (_coverImage == null)
            Positioned.fill(
              top: 0,
              bottom: 50,
              child: GestureDetector(
                onTap: () => _pickImage(isLogo: false),
                child: Container(color: Colors.transparent),
              ),
            ),

          // Remove cover image
          if (_coverImage != null)
            Positioned(
              top: 12,
              right: 12,
              child: _removeButton(
                tooltip: 'Remove cover image',
                onTap: () => _removeImage(isLogo: false),
              ),
            ),

          // Logo positioned at bottom center
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => _pickImage(isLogo: true),
                    child: Container(
                      width: SizeConfig.sizedBoxWidth(100),
                      height: SizeConfig.sizedBoxHeight(100),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppThemeManage.appTheme.scaffoldBackColor,
                        border: Border.all(color: AppColors.white, width: 4),
                        // boxShadow: [
                        //   BoxShadow(
                        //     color: AppColors.black.withValues(alpha: 0.08),
                        //     blurRadius: 8,
                        //     spreadRadius: 0,
                        //     offset: const Offset(0, 4),
                        //   ),
                        // ],
                        image:
                            _logoImage != null
                                ? DecorationImage(
                                  image: FileImage(_logoImage!),
                                  fit: BoxFit.cover,
                                )
                                : null,
                      ),
                      child:
                          _logoImage == null
                              ? Container(
                                width: SizeConfig.sizedBoxWidth(60),
                                height: SizeConfig.sizedBoxHeight(60),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.appPriSecColor.primaryColor
                                      .withValues(alpha: 0.1),
                                ),
                                child: Center(
                                  child: SvgPicture.asset(
                                    AppAssets
                                        .businessAssets
                                        .businessProfileLogoTemplate,
                                    height: SizeConfig.sizedBoxHeight(30),
                                    width: SizeConfig.sizedBoxWidth(30),
                                    colorFilter: ColorFilter.mode(
                                      AppColors.appPriSecColor.primaryColor,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              )
                              : null,
                    ),
                  ),

                  // Remove logo
                  if (_logoImage != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _removeButton(
                        tooltip: 'Remove logo',
                        onTap: () => _removeImage(isLogo: true),
                      ),
                    ),

                  // "+" icon positioned at bottom-right
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: GestureDetector(
                      onTap: () => _pickImage(isLogo: true),
                      child: Container(
                        width: SizeConfig.sizedBoxWidth(28),
                        height: SizeConfig.sizedBoxHeight(28),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.appPriSecColor.primaryColor,
                          border: Border.all(color: AppColors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Add Logo Text
          if (_logoImage == null)
            Positioned(
              bottom: -20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Add Logo',
                  style: AppTypography.captionText(context).copyWith(
                    color: AppThemeManage.appTheme.textGreyWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactDetailsSection(BusinessProfileProvider provider) {
    return Container(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.8),
            AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Contact Details',
                style: AppTypography.innerText12Mediu(
                  context,
                ).copyWith(fontWeight: FontWeight.w600, color: AppColors.black),
              ),
              Text(
                ' (Non Changeable)',
                style: AppTypography.captionText(context).copyWith(
                  color: AppColors.black.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: SizeConfig.height(2)),

          // Phone Number
          Text(
            'Phone Number',
            style: AppTypography.captionText(
              context,
            ).copyWith(fontWeight: FontWeight.w500, color: AppColors.black),
          ),
          SizedBox(height: SizeConfig.height(0.5)),
          Container(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgColor.bgWhite,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.phone,
                  size: 16,
                  color: AppColors.textColor.textGreyColor,
                ),
                SizedBox(width: 8),
                Text(
                  '${provider.userProfile['country_code']?.toString() ?? '+91'} ${provider.userProfile['mobile_num']?.toString() ?? 'Not available'}',
                  style: AppTypography.captionText(context),
                ),
                Spacer(),
                Icon(Icons.verified, size: 16, color: Colors.green),
              ],
            ),
          ),

          SizedBox(height: SizeConfig.height(1.5)),

          // Country
          Text(
            'Country',
            style: AppTypography.captionText(
              context,
            ).copyWith(fontWeight: FontWeight.w500, color: AppColors.black),
          ),
          SizedBox(height: SizeConfig.height(0.5)),
          Container(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgColor.bgWhite,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppColors.textColor.textGreyColor,
                ),
                SizedBox(width: 8),
                Text(
                  provider.userProfile['country']?.toString() ??
                      'Not available',
                  style: AppTypography.captionText(context),
                ),
              ],
            ),
          ),
        ],
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
              'Loading categories...',
              style: AppTypography.captionText(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
            ),
          ],
        ),
      );
    }

    if (provider.errorMessage.isNotEmpty && provider.categories.isEmpty) {
      return Container(
        padding: SizeConfig.getPaddingSymmetric(vertical: 20),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.textColor.textErrorColor1,
            ),
            SizedBox(height: 8),
            Text(
              'Failed to load categories',
              style: AppTypography.captionText(
                context,
              ).copyWith(color: AppColors.textColor.textErrorColor1),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                // Retry loading categories
                await provider.reloadCategories();
              },
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (provider.categories.isEmpty) {
      return Container(
        padding: SizeConfig.getPaddingSymmetric(vertical: 20),
        child: Text(
          'No categories available',
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
          return 'Please select a category';
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
                              ? 'Select a category'
                              : selectedCategoryName,
                          style: AppTypography.inputPlaceholder(
                            context,
                          ).copyWith(
                            fontSize: SizeConfig.getFontSize(12),
                            color:
                                selectedCategoryName.isEmpty
                                    ? AppColors.textColor.textGreyColor
                                    : AppThemeManage.appTheme.textColor,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppThemeManage.appTheme.textGreyWhite,
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
                  style: AppTypography.captionText(context).copyWith(
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
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
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
                  color: AppThemeManage.appTheme.textGreyWhite,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: SizeConfig.height(2)),

              // Title
              Text(
                'Select Category',
                style: AppTypography.h5(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppThemeManage.appTheme.textColor,
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
                                        ? AppColors.appPriSecColor.primaryColor
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
                                            AppThemeManage.appTheme.textColor,
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
                                          AppColors.appPriSecColor.primaryColor,
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
            border: Border.all(color: AppColors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(Icons.close, size: 16, color: AppColors.white),
        ),
      ),
    );
  }

  /// Drops the picked (not yet uploaded) logo / cover image, both here and in
  /// the provider so it isn't sent on "Next".
  void _removeImage({required bool isLogo}) {
    final provider = Provider.of<BusinessProfileProvider>(
      context,
      listen: false,
    );
    setState(() {
      if (isLogo) {
        _logoImage = null;
      } else {
        _coverImage = null;
      }
    });
    if (isLogo) {
      while (provider.images.isNotEmpty) {
        provider.removeImage(0);
      }
    } else {
      provider.removeBannerImage();
    }
  }

  Future<void> _pickImage({required bool isLogo}) async {
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
          } else {
            _coverImage = File(pickedFile.path);
          }
        });

        // Add image to provider with picture_type for banner_image
        if (mounted) {
          final provider = Provider.of<BusinessProfileProvider>(
            context,
            listen: false,
          );
          if (isLogo) {
            provider.addImage(File(pickedFile.path));
          } else {
            // Set banner image separately for cover image
            provider.setBannerImage(File(pickedFile.path));
          }
        }
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }
}
