import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/business_profile_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/widgets/global_textfield.dart';
import 'package:whoxa/widgets/business_location_picker.dart';

class Step3LocationWebsite extends StatefulWidget {
  const Step3LocationWebsite({super.key});

  @override
  State<Step3LocationWebsite> createState() => _Step3LocationWebsiteState();
}

class _Step3LocationWebsiteState extends State<Step3LocationWebsite> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProfileProvider>(
      builder: (context, provider, child) {
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Text(
                    'Tell customers where your business is located or where you operate.',
                    style: AppTypography.captionText(context).copyWith(
                      color: AppThemeManage.appTheme.textGreyWhite,
                      fontSize: SizeConfig.getFontSize(12),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: SizeConfig.height(3)),

                // Address Field with Red Asterisk
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: AppTypography.innerText12Mediu(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeManage.appTheme.textColor,
                        ),
                        children: [
                          const TextSpan(text: 'Business Address '),
                          TextSpan(
                            text: '*',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: SizeConfig.height(0.5)),
                    TextFormField(
                      controller: provider.controllers['location']!,
                      keyboardType: TextInputType.streetAddress,
                      maxLines: 2,
                      maxLength: 150,
                      style: AppTypography.captionText(context).copyWith(
                        color: AppThemeManage.appTheme.textColor,
                        fontSize: SizeConfig.getFontSize(13),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter your business address',
                        hintStyle: AppTypography.captionText(context).copyWith(
                          color: AppThemeManage.appTheme.textGreyWhite,
                          fontSize: SizeConfig.getFontSize(13),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppThemeManage.appTheme.borderColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppThemeManage.appTheme.borderColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.appPriSecColor.primaryColor,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red.shade600),
                        ),
                        contentPadding: SizeConfig.getPaddingSymmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        fillColor: AppThemeManage.appTheme.scaffoldBackColor,
                        filled: true,
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Please enter business address';
                        }
                        return null;
                      },
                    ),
                  ],
                ),

                SizedBox(height: SizeConfig.height(2)),

                // Google Map Integration Placeholder
                _buildMapSection(provider),

                SizedBox(height: SizeConfig.height(3)),

                // Website Field
                GlobalTextField1(
                  lable: 'Website (Optional)',
                  hintText: 'https://www.yourwebsite.com',
                  controller: provider.controllers['website']!,
                  context: context,
                  keyboardType: TextInputType.url,
                  onEditingComplete: () {},
                  maxLength: 100,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      String url = value.trim();

                      // Auto-add https:// if no protocol is specified
                      if (!url.startsWith('http://') &&
                          !url.startsWith('https://')) {
                        // Check if it looks like a valid domain
                        if (url.contains('.') && !url.contains(' ')) {
                          // Don't show error, let the system auto-add protocol
                          return null;
                        } else {
                          return 'Please enter a valid website URL (e.g., www.example.com)';
                        }
                      }

                      // Basic URL validation for URLs with protocol
                      final Uri? uri = Uri.tryParse(url);
                      if (uri == null ||
                          !uri.hasScheme ||
                          !uri.host.contains('.')) {
                        return 'Please enter a valid website URL';
                      }
                    }
                    return null;
                  },
                ),

                SizedBox(height: SizeConfig.height(2)),

                // Business email (optional; maps to `business_email`)
                GlobalTextField1(
                  lable: 'Business Email (Optional)',
                  hintText: 'hello@yourbusiness.com',
                  controller: provider.controllers['business_email']!,
                  context: context,
                  keyboardType: TextInputType.emailAddress,
                  onEditingComplete: () {},
                  maxLength: 100,
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isNotEmpty &&
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),

                SizedBox(height: SizeConfig.height(2)),

                // Additional Information Card
                _buildInfoCard(),

                SizedBox(height: SizeConfig.height(2)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapSection(BusinessProfileProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location on Map (Optional)',
          style: AppTypography.innerText12Mediu(context).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: SizeConfig.getFontSize(13),
            color: AppThemeManage.appTheme.textColor,
          ),
        ),
        SizedBox(height: SizeConfig.height(1)),

        Container(
          width: double.infinity,
          height: SizeConfig.sizedBoxHeight(200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  provider.businessLatitude != null &&
                          provider.businessLongitude != null
                      ? AppColors.appPriSecColor.primaryColor
                      : AppThemeManage.appTheme.borderColor,
              width:
                  provider.businessLatitude != null &&
                          provider.businessLongitude != null
                      ? 2
                      : 1,
            ),
            color:
                provider.businessLatitude != null &&
                        provider.businessLongitude != null
                    ? AppColors.appPriSecColor.primaryColor.withValues(
                      alpha: 0.1,
                    )
                    : AppThemeManage.appTheme.scaffoldBackColor,
          ),
          child: InkWell(
            onTap: () => _showMapDialog(),
            child:
                provider.businessLatitude != null &&
                        provider.businessLongitude != null
                    ? _buildSelectedLocationView(provider)
                    : _buildEmptyMapView(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMapView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.location_on_outlined,
          size: SizeConfig.getFontSize(48),
          color: AppThemeManage.appTheme.textGreyWhite,
        ),
        SizedBox(height: SizeConfig.height(1)),
        Text(
          'Tap to select location on map',
          style: AppTypography.captionText(context).copyWith(
            color: AppThemeManage.appTheme.textColor,
            fontSize: SizeConfig.getFontSize(13),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: SizeConfig.height(0.5)),
        Text(
          'Help customers find your exact location',
          style: AppTypography.innerText08(context).copyWith(
            color: AppThemeManage.appTheme.textGreyWhite,
            fontSize: SizeConfig.getFontSize(11),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedLocationView(BusinessProfileProvider provider) {
    return Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: AppColors.appPriSecColor.primaryColor,
                size: SizeConfig.getFontSize(24),
              ),
              SizedBox(width: SizeConfig.width(2)),
              Text(
                'Selected Location',
                style: AppTypography.captionText(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.appPriSecColor.primaryColor,
                  fontSize: SizeConfig.getFontSize(13),
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: () => _showMapDialog(),
                icon: Icon(
                  Icons.edit,
                  color: AppThemeManage.appTheme.textGreyWhite,
                  size: SizeConfig.getFontSize(18),
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: SizeConfig.sizedBoxWidth(24),
                  minHeight: SizeConfig.sizedBoxHeight(24),
                ),
              ),
            ],
          ),
          SizedBox(height: SizeConfig.height(1)),
          Text(
            provider.controllers['location']?.text ?? 'Selected location',
            style: AppTypography.captionText(context).copyWith(
              color: AppThemeManage.appTheme.textColor,
              fontSize: SizeConfig.getFontSize(12),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          // if (provider.businessLatitude != null &&
          //     provider.businessLongitude != null) ...[
          //   SizedBox(height: SizeConfig.height(1)),
          //   Text(
          //     'Lat: ${provider.businessLatitude!.toStringAsFixed(6)}, Lng: ${provider.businessLongitude!.toStringAsFixed(6)}',
          //     style: AppTypography.innerText08(context).copyWith(
          //       color: AppThemeManage.appTheme.textGreyWhite,
          //       fontSize: SizeConfig.getFontSize(10),
          //     ),
          //   ),
          // ],
          Spacer(),
          Center(
            child: Text(
              'Tap to change location',
              style: AppTypography.innerText08(context).copyWith(
                color: AppColors.appPriSecColor.primaryColor,
                fontSize: SizeConfig.getFontSize(11),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
        border: Border.all(
          color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: AppColors.appPriSecColor.primaryColor,
            size: SizeConfig.getFontSize(24),
          ),
          SizedBox(width: SizeConfig.width(3)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why provide location details?',
                  style: AppTypography.captionText(context).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: SizeConfig.getFontSize(13),
                    color: AppColors.appPriSecColor.primaryColor,
                  ),
                ),
                SizedBox(height: SizeConfig.height(0.8)),
                Text(
                  '• Help customers find and visit your business\n'
                  '• Improve your visibility in local searches\n'
                  '• Build trust with accurate location information\n'
                  '• Enable location-based features',
                  style: AppTypography.innerText08(context).copyWith(
                    color: AppThemeManage.appTheme.textColor,
                    fontSize: SizeConfig.getFontSize(11),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMapDialog() {
    final provider = Provider.of<BusinessProfileProvider>(
      context,
      listen: false,
    );

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
}
