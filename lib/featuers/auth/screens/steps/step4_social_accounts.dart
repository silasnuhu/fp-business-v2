// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/business_profile_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/widgets/global_textfield.dart';

class Step4SocialAccounts extends StatefulWidget {
  const Step4SocialAccounts({super.key});

  @override
  State<Step4SocialAccounts> createState() => _Step4SocialAccountsState();
}

class _Step4SocialAccountsState extends State<Step4SocialAccounts> {
  final _formKey = GlobalKey<FormState>();

  final List<Map<String, dynamic>> _socialPlatforms = [
    {
      'key': 'facebook_link',
      'label': 'Facebook',
      'hint': 'https://facebook.com/yourpage',
      'icon': Icons.facebook,
      'color': const Color(0xFF1877F2),
    },
    {
      'key': 'instagram_link',
      'label': 'Instagram',
      'hint': 'https://instagram.com/youraccount',
      'icon': Icons.camera_alt,
      'color': const Color(0xFFE4405F),
    },
    {
      'key': 'linkedin_link',
      'label': 'LinkedIn',
      'hint': 'https://linkedin.com/company/yourcompany',
      'icon': Icons.business,
      'color': const Color(0xFF0A66C2),
    },
    {
      'key': 'youtube_link',
      'label': 'YouTube',
      'hint': 'https://youtube.com/c/yourchannel',
      'icon': Icons.play_circle_outline,
      'color': const Color(0xFFFF0000),
    },
    {
      'key': 'vk_link',
      'label': 'VK',
      'hint': 'https://vk.com/yourpage',
      'icon': Icons.share,
      'color': const Color(0xFF4C75A3),
    },
  ];

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
                Text(
                  'Let\'s customer know your presence on social media',
                  textAlign: TextAlign.center,
                  style: AppTypography.captionText(context).copyWith(
                    color: AppColors.textColor.textGreyColor,
                    fontSize: SizeConfig.getFontSize(14),
                  ),
                ),

                SizedBox(height: SizeConfig.height(3)),

                // Social Media Fields
                ..._socialPlatforms.map(
                  (platform) => _buildSocialField(provider, platform),
                ),

                SizedBox(height: SizeConfig.height(2)),

                // Benefits Card
                _buildBenefitsCard(),

                SizedBox(height: SizeConfig.height(2)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocialField(
    BusinessProfileProvider provider,
    Map<String, dynamic> platform,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: SizeConfig.height(2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: platform['color'].withValues(alpha: 0.1),
                ),
                child: Icon(
                  platform['icon'],
                  color: platform['color'],
                  size: 20,
                ),
              ),
              SizedBox(width: SizeConfig.width(2)),
              Text(
                platform['label'],
                style: AppTypography.innerText12Mediu(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: SizeConfig.height(1)),

          GlobalTextField1(
            lable: '',
            hintText: platform['hint'],
            controller: provider.controllers[platform['key']]!,
            context: context,
            keyboardType: TextInputType.url,
            onEditingComplete: () {},
            maxLength: 100,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                if (!value.trim().startsWith('http://') &&
                    !value.trim().startsWith('https://')) {
                  return 'Please enter a valid URL starting with http:// or https://';
                }

                // Basic URL validation
                final Uri? uri = Uri.tryParse(value.trim());
                if (uri == null || !uri.hasAbsolutePath) {
                  return 'Please enter a valid ${platform['label']} URL';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard() {
    return Container(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
            AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: AppColors.appPriSecColor.primaryColor,
                size: 24,
              ),
              SizedBox(width: SizeConfig.width(2)),
              Text(
                'Why connect social accounts?',
                style: AppTypography.captionText(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.appPriSecColor.primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: SizeConfig.height(1.5)),

          ..._buildBenefitsList().map(
            (benefit) => Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 6),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.appPriSecColor.primaryColor,
                    ),
                  ),
                  SizedBox(width: SizeConfig.width(2)),
                  Expanded(
                    child: Text(
                      benefit,
                      style: AppTypography.innerText08(context).copyWith(
                        color: AppColors.textColor.text3A3333,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: SizeConfig.height(1)),

          Container(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.bgColor.bgWhite.withValues(alpha: 0.8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  size: 16,
                  color: AppColors.textColor.textGreyColor,
                ),
                SizedBox(width: SizeConfig.width(1)),
                Expanded(
                  child: Text(
                    'Your social links are only visible to customers',
                    style: AppTypography.innerText08(context).copyWith(
                      color: AppColors.textColor.textGreyColor,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _buildBenefitsList() {
    return [
      'Build credibility and trust with customers',
      'Increase your online presence and visibility',
      'Drive more traffic to your social media pages',
      'Keep customers updated with your latest content',
      'Create multiple touchpoints for customer engagement',
      'Showcase your business personality and culture',
    ];
  }
}
