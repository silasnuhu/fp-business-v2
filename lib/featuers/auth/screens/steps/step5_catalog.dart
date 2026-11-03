import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/business_profile_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/widgets/global.dart';

class Step5Catalog extends StatefulWidget {
  const Step5Catalog({super.key});

  @override
  State<Step5Catalog> createState() => _Step5CatalogState();
}

class _Step5CatalogState extends State<Step5Catalog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final List<File> _catalogImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSavingProduct = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load catalogs when the widget initializes - but only if userID is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCatalogsOnInit();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProfileProvider>(
      builder: (context, provider, child) {
        // Add a loading check
        if (provider.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading catalogs...'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Optional Badge
              /*Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Catalog',
                          style: AppTypography.captionText(context).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: SizeConfig.getFontSize(13),
                            color: AppThemeManage.appTheme.textColor,
                          ),
                        ),
                        SizedBox(height: SizeConfig.height(1)),
                        Text(
                          'Showcase your products and services to customers',
                          style: AppTypography.captionText(context).copyWith(
                            color: AppThemeManage.appTheme.textGreyWhite,
                            fontSize: SizeConfig.getFontSize(11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: SizeConfig.getPaddingSymmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'OPTIONAL',
                      style: AppTypography.innerText08(context).copyWith(
                        color: AppColors.appPriSecColor.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: SizeConfig.getFontSize(10),
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: SizeConfig.height(4)),
              */

              // Main Content based on catalog state
              if (provider.catalogs.isEmpty) ...[
                _buildMainCatalogSection(),
                SizedBox(height: SizeConfig.height(3)),
              ] else ...[
                _buildCompletionSection(provider),
                SizedBox(height: SizeConfig.height(3)),
              ],

              SizedBox(height: SizeConfig.height(2)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCatalogCard(
    Map<String, dynamic> catalog, {
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: SizeConfig.getPaddingSymmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Container(
                width: SizeConfig.sizedBoxWidth(70),
                height: SizeConfig.sizedBoxHeight(70),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildCatalogImage(catalog),
                ),
              ),

              SizedBox(width: SizeConfig.width(4)),

              // Content - Title, Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      catalog['title'] ?? '',
                      style: AppTypography.captionText(context).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: SizeConfig.getFontSize(16),
                        color: AppColors.appPriSecColor.primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: SizeConfig.height(0.5)),

                    // Description
                    Text(
                      catalog['description'] ?? '',
                      style: AppTypography.innerText08(context).copyWith(
                        color: AppThemeManage.appTheme.textGreyWhite,
                        fontSize: SizeConfig.getFontSize(13),
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              SizedBox(width: SizeConfig.width(3)),

              // Price
              if (catalog['price'] != null &&
                  catalog['price'].toString().isNotEmpty)
                Text(
                  '\$${catalog['price']}',
                  style: AppTypography.captionText(context).copyWith(
                    color: AppThemeManage.appTheme.textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: SizeConfig.getFontSize(16),
                  ),
                ),
            ],
          ),
        ),

        // Divider
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AppThemeManage.appTheme.borderColor.withValues(alpha: 0.3),
          ),
      ],
    );
  }

  Widget _buildMainCatalogSection() {
    return Column(
      children: [
        // Subtitle
        Text(
          'Setup your whoxa mobile storefront',
          style: AppTypography.captionText(context).copyWith(
            color: AppThemeManage.appTheme.textGreyWhite,
            fontSize: SizeConfig.getFontSize(14),
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: SizeConfig.height(4)),

        // Catalog Illustration
        Center(
          child: SizedBox(
            width: SizeConfig.sizedBoxWidth(200),
            height: SizeConfig.sizedBoxHeight(160),
            child: SvgPicture.asset(
              AppAssets.businessAssets.catalog,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(
                AppColors.appPriSecColor.primaryColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),

        SizedBox(height: SizeConfig.height(4)),

        // Benefits List
        _buildBenefitItem(
          'Offer better browsing',
          'Show what you are selling right in Whoxa',
        ),

        SizedBox(height: SizeConfig.height(2)),

        _buildBenefitItem(
          'Share your offerings',
          'Send your items or entire catalogue in chats',
        ),

        SizedBox(height: SizeConfig.height(2)),

        _buildBenefitItem(
          'Get started fast',
          "It's just a few steps and saves space on your phone",
        ),

        SizedBox(height: SizeConfig.height(15)),

        // Add Catalogue Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _showAddCatalogueBottomSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.appPriSecColor.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: SizeConfig.getPaddingSymmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Add Catalogue',
              style: AppTypography.h5(context).copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: SizeConfig.getFontSize(16),
              ),
            ),
          ),
        ),

        SizedBox(height: SizeConfig.height(2)),

        // Skip Button
        TextButton(
          onPressed: _skipCatalogAndComplete,
          child: Text(
            'Skip',
            style: AppTypography.captionText(context).copyWith(
              color: AppThemeManage.appTheme.textGreyWhite,
              fontSize: SizeConfig.getFontSize(16),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(String title, String subtitle) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.captionText(context).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: SizeConfig.getFontSize(16),
              color: AppThemeManage.appTheme.textColor,
            ),
          ),
          SizedBox(height: SizeConfig.height(0.5)),
          Text(
            subtitle,
            style: AppTypography.captionText(context).copyWith(
              color: AppThemeManage.appTheme.textGreyWhite,
              fontSize: SizeConfig.getFontSize(14),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImagesWithModalState(
    StateSetter setModalState,
    FormFieldState<List<File>>? field,
  ) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (pickedFiles.isNotEmpty) {
        setModalState(() {
          _catalogImages.addAll(
            pickedFiles.map((file) => File(file.path)).toList(),
          );
        });
        // Update form field if provided
        field?.didChange(_catalogImages);
        // Also update the main widget state
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
      }
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _countryController.clear();
    _catalogImages.clear();
  }

  Future<void> _loadCatalogsOnInit() async {
    if (!mounted) return;

    final provider = Provider.of<BusinessProfileProvider>(
      context,
      listen: false,
    );

    // Check if userID is available before trying to load catalogs
    if (userID.isEmpty) {
      return;
    }

    // Load catalogs from API
    try {
      await provider.loadCatalogs();
    } catch (e) {
      // Handle error silently for now
    }
  }

  void _showAddCatalogueBottomSheet() {
    // Call API to update profile_setup_step to 5 when user taps Add Catalogue
    // final provider = Provider.of<BusinessProfileProvider>(
    //   context,
    //   listen: false,
    // );
    // provider.updateBusinessProfileRepo({
    //   'profile_setup_step': 5,
    // }).then((_) {
    //   debugPrint('Profile setup step updated to 5 on Add Catalogue tap');
    // }).catchError((e) {
    //   debugPrint('Error updating profile_setup_step: $e');
    // });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Consumer<BusinessProfileProvider>(
              builder: (context, provider, child) {
                return DraggableScrollableSheet(
                  initialChildSize: 0.95,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (_, controller) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppThemeManage.appTheme.scaffoldBackColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Stack(
                        children: [
                          provider.catalogs.isEmpty
                              ? _buildEmptyBottomSheet(controller, provider)
                              : _buildCatalogueListBottomSheet(
                                controller,
                                provider,
                              ),
                          // ✅ Show loading overlay when saving
                          if (_isSavingProduct)
                            Container(
                              color: Colors.black.withValues(alpha: 0.5),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.appPriSecColor.primaryColor,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Adding product...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyBottomSheet(
    ScrollController controller,
    BusinessProfileProvider provider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        controller: controller,
        child: Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              SizedBox(height: SizeConfig.height(3)),

              // Title
              Text(
                'Add Catalogue',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: SizeConfig.getFontSize(22),
                  color: Colors.black,
                ),
              ),

              SizedBox(height: SizeConfig.height(1)),

              // Subtitle
              Text(
                'Send products and services directly to\nyour customers with whoxa catalogue',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: SizeConfig.getFontSize(14),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: SizeConfig.height(8)),

              // Add New Item Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFFFFF8E1), // Light yellow background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddProductBottomSheet();
                  },
                  icon: Icon(
                    Icons.add,
                    color: Colors.orange[700],
                    size: SizeConfig.getFontSize(18),
                  ),
                  label: Text(
                    'Add New Item',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[700],
                      fontSize: SizeConfig.getFontSize(16),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: SizeConfig.getPaddingSymmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              SizedBox(height: SizeConfig.height(8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogueListBottomSheet(
    ScrollController controller,
    BusinessProfileProvider provider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        controller: controller,
        child: Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              SizedBox(height: SizeConfig.height(3)),

              // Title
              Text(
                'Add Catalogue',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: SizeConfig.getFontSize(22),
                  color: Colors.black,
                ),
              ),

              SizedBox(height: SizeConfig.height(1)),

              // Subtitle
              Text(
                'Send products and services directly to\nyour customers with whoxa catalogue',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: SizeConfig.getFontSize(14),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: SizeConfig.height(4)),

              // Catalogue List
              ...provider.catalogs.map(
                (catalog) => _buildBottomSheetCatalogCard(catalog),
              ),

              SizedBox(height: SizeConfig.height(3)),

              // Add New Item Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFFFFF8E1), // Light yellow background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddProductBottomSheet();
                  },
                  icon: Icon(
                    Icons.add,
                    color: Colors.orange[700],
                    size: SizeConfig.getFontSize(18),
                  ),
                  label: Text(
                    'Add New Item',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[700],
                      fontSize: SizeConfig.getFontSize(16),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: SizeConfig.getPaddingSymmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              SizedBox(height: SizeConfig.height(4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetCatalogCard(Map<String, dynamic> catalog) {
    return Container(
      margin: SizeConfig.getPaddingOnly(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image - larger and rectangular
          Container(
            width: SizeConfig.sizedBoxWidth(80),
            height: SizeConfig.sizedBoxHeight(80),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[100],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildCatalogImage(catalog),
            ),
          ),

          SizedBox(width: SizeConfig.width(4)),

          // Content - Title, Description, and Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Price Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Expanded(
                      child: Text(
                        catalog['title'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: SizeConfig.getFontSize(16),
                          color:
                              Colors.orange[700], // Orange title like in image
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    SizedBox(width: SizeConfig.width(2)),

                    // Price
                    if (catalog['price'] != null &&
                        catalog['price'].toString().isNotEmpty)
                      Text(
                        '\$${catalog['price']}',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: SizeConfig.getFontSize(16),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: SizeConfig.height(0.5)),

                // Description
                Text(
                  catalog['description'] ?? '',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: SizeConfig.getFontSize(13),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProductBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Consumer<BusinessProfileProvider>(
          builder: (context, provider, child) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return DraggableScrollableSheet(
                  initialChildSize: 0.95,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (_, controller) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppThemeManage.appTheme.scaffoldBackColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: _buildProductFormBottomSheet(
                        controller,
                        provider,
                        setModalState,
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProductFormBottomSheet(
    ScrollController controller,
    BusinessProfileProvider provider,
    StateSetter setModalState,
  ) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        controller: controller,
        child: Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppThemeManage.appTheme.textGreyWhite.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              SizedBox(height: SizeConfig.height(2)),

              // Title
              Center(
                child: Text(
                  'Add Catalogue',
                  style: AppTypography.h5(context).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: SizeConfig.getFontSize(18),
                    color: AppThemeManage.appTheme.textColor,
                  ),
                ),
              ),

              SizedBox(height: SizeConfig.height(3)),

              // Form Fields
              // Product Title
              _buildFormField(
                label: 'Title*',
                hintText: 'Enter Title',
                controller: _titleController,
                maxLength: 50,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Please enter product title';
                  }
                  if (value!.trim().length < 3) {
                    return 'Product title must be at least 3 characters';
                  }
                  return null;
                },
              ),

              SizedBox(height: SizeConfig.height(2)),

              // Description
              _buildFormField(
                label: 'Description*',
                hintText: 'Enter Description',
                controller: _descriptionController,
                maxLines: 3,
                maxLength: 200,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Please enter product description';
                  }
                  if (value!.trim().length < 10) {
                    return 'Description must be at least 10 characters';
                  }
                  return null;
                },
              ),

              SizedBox(height: SizeConfig.height(2)),

              // Price
              _buildFormField(
                label: 'Price',
                hintText: 'Enter Price',
                controller: _priceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                prefixText: '\$ ',
                validator: (value) {
                  if (value?.trim().isNotEmpty ?? false) {
                    final price = double.tryParse(value!.trim());
                    if (price == null) {
                      return 'Please enter a valid price';
                    }
                    if (price < 0) {
                      return 'Price cannot be negative';
                    }
                    if (price > 999999) {
                      return 'Price cannot exceed \$999,999';
                    }
                  }
                  return null;
                },
              ),

              SizedBox(height: SizeConfig.height(2)),

              // Images Section
              _buildImagesSectionWithState(setModalState),

              SizedBox(height: SizeConfig.height(3)),

              // Add Button
              SizedBox(
                width: double.infinity,
                child:
                    _isSavingProduct
                        ? Container(
                          height: SizeConfig.sizedBoxHeight(56),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.appPriSecColor.primaryColor
                                .withValues(alpha: 0.5),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        )
                        : ElevatedButton(
                          onPressed:
                              _isSavingProduct
                                  ? null
                                  : () => _saveProductFromBottomSheet(
                                    provider,
                                    setModalState,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.appPriSecColor.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: SizeConfig.getPaddingSymmetric(
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              _isSavingProduct
                                  ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : Text(
                                    'Add',
                                    style: AppTypography.h5(context).copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: SizeConfig.getFontSize(16),
                                    ),
                                  ),
                        ),
              ),

              SizedBox(height: SizeConfig.height(2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: AppTypography.innerText12Mediu(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppThemeManage.appTheme.textColor,
              fontSize: SizeConfig.getFontSize(14),
            ),
            children: [
              TextSpan(text: label.replaceAll('*', '')),
              if (label.contains('*'))
                TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        SizedBox(height: SizeConfig.height(0.5)),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: TextCapitalization.sentences,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            prefix:
                prefixText != null
                    ? Center(
                      widthFactor: 0.0,
                      child: Padding(
                        padding: SizeConfig.getPaddingOnly(left: 10, right: 20),
                        child: Text(
                          prefixText,
                          style: AppTypography.innerText08(context).copyWith(
                            color: AppThemeManage.appTheme.textGreyWhite,
                            fontSize: SizeConfig.getFontSize(16),
                          ),
                        ),
                      ),
                    )
                    : null,

            hintStyle: AppTypography.innerText08(context).copyWith(
              color: AppThemeManage.appTheme.textGreyWhite,
              fontSize: SizeConfig.getFontSize(12),
            ),
            filled: true,
            fillColor: AppThemeManage.appTheme.bg4BlackGrey.withValues(
              alpha: 0.1,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppThemeManage.appTheme.borderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppThemeManage.appTheme.borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppColors.appPriSecColor.primaryColor,
              ),
            ),
            contentPadding: SizeConfig.getPaddingSymmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagesSectionWithState(StateSetter setModalState) {
    return FormField<List<File>>(
      initialValue: _catalogImages,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select at least one product image';
        }
        return null;
      },
      builder: (FormFieldState<List<File>> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: AppTypography.innerText12Mediu(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppThemeManage.appTheme.textColor,
                  fontSize: SizeConfig.getFontSize(14),
                ),
                children: [
                  TextSpan(text: 'Images '),
                  TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            SizedBox(height: SizeConfig.height(1)),

            Container(
              height: 90,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      field.hasError
                          ? Colors.red.shade600
                          : AppThemeManage.appTheme.borderColor,
                  width: field.hasError ? 1.5 : 1,
                ),
                color:
                    field.hasError
                        ? Colors.red.shade50.withValues(alpha: 0.1)
                        : AppThemeManage.appTheme.scaffoldBackColor,
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Add image button
                  InkWell(
                    onTap:
                        () => _pickImagesWithModalState(setModalState, field),
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppThemeManage.appTheme.borderColor,
                          style: BorderStyle.solid,
                        ),
                        color: AppThemeManage.appTheme.bg4BlackGrey.withValues(
                          alpha: 0.1,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: AppThemeManage.appTheme.textGreyWhite,
                        size: 32,
                      ),
                    ),
                  ),

                  // Selected images
                  ..._catalogImages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final image = entry.value;

                    return Container(
                      margin: EdgeInsets.only(left: 8),
                      child: Stack(
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(image, fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  _catalogImages.removeAt(index);
                                });
                                // Update form field
                                field.didChange(_catalogImages);
                                // Also update the main widget state
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            if (field.hasError)
              Padding(
                padding: SizeConfig.getPaddingOnly(top: 8, left: 4),
                child: Text(
                  field.errorText!,
                  style: AppTypography.captionText(
                    context,
                  ).copyWith(color: Colors.red.shade600, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCatalogImage(Map<String, dynamic> catalog) {
    // Try different possible image field structures from API
    dynamic imageData =
        catalog['Catalog_images'] ??
        catalog['images'] ??
        catalog['catalog_images'];

    String? imageUrl;
    if (imageData is List && imageData.isNotEmpty) {
      if (imageData[0] is Map) {
        imageUrl =
            imageData[0]['image'] ??
            imageData[0]['url'] ??
            imageData[0]['path'];
      } else if (imageData[0] is String) {
        imageUrl = imageData[0];
      }
    } else if (imageData is String && imageData.isNotEmpty) {
      imageUrl = imageData;
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value:
                    loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.appPriSecColor.primaryColor,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.image_outlined,
              color: AppThemeManage.appTheme.textGreyWhite,
              size: SizeConfig.getFontSize(24),
            );
          },
        ),
      );
    }

    return Icon(
      Icons.image_outlined,
      color: AppThemeManage.appTheme.textGreyWhite,
      size: SizeConfig.getFontSize(24),
    );
  }

  Widget _buildCompletionSection(BusinessProfileProvider provider) {
    return Column(
      children: [
        // Show existing catalogs list first
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Products (${provider.catalogs.length})',
              style: AppTypography.captionText(context).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: SizeConfig.getFontSize(14),
                color: AppThemeManage.appTheme.textColor,
              ),
            ),
            SizedBox(height: SizeConfig.height(1)),

            // Product Cards
            if (provider.catalogs.isNotEmpty)
              ...provider.catalogs.asMap().entries.map((entry) {
                final index = entry.key;
                final catalog = entry.value;
                final isLast = index == provider.catalogs.length - 1;
                return _buildCatalogCard(catalog, showDivider: !isLast);
              }),
          ],
        ),

        SizedBox(height: SizeConfig.height(2)),

        // Completion Message
        /* Container(
          width: double.infinity,
          padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.green.shade50,
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.green.shade600,
                size: SizeConfig.getFontSize(20),
              ),
              SizedBox(width: SizeConfig.width(3)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Great! Your products are ready',
                      style: AppTypography.captionText(context).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: SizeConfig.getFontSize(13),
                        color: Colors.green.shade800,
                      ),
                    ),
                    Text(
                      'You can add more products or continue to complete your business setup.',
                      style: AppTypography.innerText08(context).copyWith(
                        fontSize: SizeConfig.getFontSize(11),
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: SizeConfig.height(2)), 
        */

        // Add More Products Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showAddCatalogueBottomSheet,
            icon: Icon(
              Icons.add,
              color: AppColors.appPriSecColor.primaryColor,
              size: SizeConfig.getFontSize(18),
            ),
            label: Text(
              'Add More Products',
              style: AppTypography.h5(context).copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.appPriSecColor.primaryColor,
                fontSize: SizeConfig.getFontSize(16),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppColors.appPriSecColor.primaryColor,
                width: 1.5,
              ),
              padding: SizeConfig.getPaddingSymmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        SizedBox(height: SizeConfig.height(2)),
      ],
    );
  }

  Future<void> _skipCatalogAndComplete() async {
    if (!mounted) return;

    final provider = Provider.of<BusinessProfileProvider>(
      context,
      listen: false,
    );

    try {
      // Complete the profile setup without adding catalogs
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

  Future<void> _saveProductFromBottomSheet(
    BusinessProfileProvider provider,
    StateSetter setModalState,
  ) async {
    // ✅ Prevent multiple clicks - return early if already saving
    if (_isSavingProduct) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Set loading state - update both parent and modal state
    setState(() {
      _isSavingProduct = true;
    });
    setModalState(() {});

    try {
      await provider.addCatalog(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: _priceController.text.trim(),
        countryOfOrigin:
            _countryController.text.trim().isEmpty
                ? 'Not specified'
                : _countryController.text.trim(),
        images: _catalogImages,
      );

      if (mounted) {
        setState(() {
          _isSavingProduct = false;
        });
        setModalState(() {});
        Navigator.pop(context);
        _clearForm();
        snackbarNew(context, msg: 'Product added successfully!');

        // The provider.addCatalog() already refreshes the catalog data and notifies listeners
        // The main screen should automatically show the completion state
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingProduct = false;
        });
        setModalState(() {});
        // Show user-friendly error message
        String errorMessage = 'Failed to add product';
        if (e.toString().contains('invalid input syntax for type integer')) {
          errorMessage = 'Please enter a valid price';
        } else if (e.toString().contains('AppError:')) {
          // Extract message after "AppError: "
          final match = RegExp(r'AppError:\s*(.+)').firstMatch(e.toString());
          if (match != null) {
            errorMessage = match.group(1) ?? errorMessage;
          }
        } else {
          errorMessage = 'Failed to add product. Please try again.';
        }
        snackbarNew(context, msg: errorMessage);
      }
    }
  }
}
