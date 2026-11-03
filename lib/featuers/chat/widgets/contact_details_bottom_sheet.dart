import 'package:whoxa/featuers/contacts/screen/save_contact.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/utils/avatar_initials.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class ContactDetailsBottomSheet extends StatelessWidget {
  final String contactName;
  final String? phoneNumber;
  final String? userId;

  const ContactDetailsBottomSheet({
    super.key,
    required this.contactName,
    this.phoneNumber,
    this.userId,
  });

  String _getInitials(String name) => avatarInitials(name);

  Future<void> _copyToClipboard(String text, BuildContext context) async {
    Clipboard.setData(ClipboardData(text: text));
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppString.copiedToClipboard,
          style: AppTypography.innerText12Mediu(context).copyWith(
            color: ThemeColorPalette.getTextColor(
              AppColors.appPriSecColor.primaryColor,
            ),
          ),
        ),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.appPriSecColor.primaryColor,
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    } catch (e) {
      debugPrint('Could not launch $phoneUri');
    }
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber);
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    } catch (e) {
      debugPrint('Could not launch $smsUri');
    }
  }

  Future<void> _addToContacts(BuildContext context) async {
    if (phoneNumber == null || phoneNumber!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppString.noPhoneNumberAvailable),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      // Use the contact service to add contact
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => SaveContact(name: contactName, number: phoneNumber),
        ),
      );
      // final success = await ContactService.addContact(
      //   contactName,
      //   phoneNumber!,
      // );

      // if (context.mounted) {
      //   if (success) {
      //     String message =
      //         Platform.isAndroid
      //             ? 'Opening contacts app with pre-filled data'
      //             : 'Opening contacts app. Please add manually:\nName: $contactName\nPhone: $phoneNumber';

      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(
      //         content: Text(message),
      //         backgroundColor: AppColors.appPriSecColor.primaryColor,
      //         duration: Duration(seconds: Platform.isAndroid ? 2 : 4),
      //       ),
      //     );
      //   } else {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(
      //         content: Text(
      //           'Please add contact manually:\nName: $contactName\nPhone: $phoneNumber',
      //         ),
      //         backgroundColor: AppColors.appPriSecColor.primaryColor,
      //         duration: Duration(seconds: 4),
      //       ),
      //     );
      //   }
      // }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please add contact manually:\nName: $contactName\nPhone: $phoneNumber',
            ),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.scaffoldBackColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          SizedBox(height: 24),

          // Contact Avatar
          Hero(
            tag: 'contact_avatar_$contactName',
            child: CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.appPriSecColor.primaryColor,
              child: Text(
                _getInitials(contactName),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),
            ),
          ),

          SizedBox(height: 16),

          // Contact Name
          Text(
            contactName,
            style: AppTypography.h2(
              context,
            ).copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),

          if (phoneNumber != null && phoneNumber!.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              phoneNumber!,
              style: AppTypography.mediumText(
                context,
              ).copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],

          SizedBox(height: 32),

          // Action Buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Call Button (if phone number available)
                if (phoneNumber != null && phoneNumber!.isNotEmpty)
                  _buildActionButton(
                    icon: Icons.call,
                    label: 'Call',
                    color: Colors.green,
                    onTap: () {
                      _makeCall(phoneNumber!);
                      Navigator.pop(context);
                    },
                  ),

                SizedBox(height: 12),

                // SMS Button (if phone number available)
                if (phoneNumber != null && phoneNumber!.isNotEmpty)
                  _buildActionButton(
                    icon: Icons.message,
                    label: 'Send SMS',
                    color: AppColors.appPriSecColor.primaryColor,
                    onTap: () {
                      _sendSMS(phoneNumber!);
                      Navigator.pop(context);
                    },
                  ),

                SizedBox(height: 12),

                // Copy Number Button
                if (phoneNumber != null && phoneNumber!.isNotEmpty)
                  _buildActionButton(
                    icon: Icons.copy,
                    label: 'Copy Number',
                    color: Colors.grey[700]!,
                    onTap: () {
                      _copyToClipboard(phoneNumber!, context);
                    },
                  ),

                SizedBox(height: 12),

                // Add to Contacts Button
                _buildActionButton(
                  icon: Icons.person_add,
                  label: 'Add to Contacts',
                  color: Colors.blue,
                  onTap: () async {
                    Navigator.pop(context);
                    await _addToContacts(context);
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Close Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Close',
                  style: AppTypography.mediumText(context).copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
