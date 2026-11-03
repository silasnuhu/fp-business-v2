import 'package:flutter/material.dart';
import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';

/// Shows the picked contact for a final check before it is shared. Resolves
/// `true` when the user taps send; cancel (or dismissing) resolves `false`.
Future<bool> showContactSendPreview(
  BuildContext context, {
  required ContactModel contact,
  required bool isRegistered,
}) async {
  final confirmed = await bottomSheetGobalWithoutTitle<bool>(
    context,
    isCrossIconHide: true,
    shrinkWrap: true,
    bottomsheetHeight: 320,
    child: ContactSendPreview(contact: contact, isRegistered: isRegistered),
  );
  return confirmed == true;
}

class ContactSendPreview extends StatelessWidget {
  final ContactModel contact;
  final bool isRegistered;

  const ContactSendPreview({
    super.key,
    required this.contact,
    required this.isRegistered,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.appPriSecColor.primaryColor;
    final onPrimary = ThemeColorPalette.getTextColor(primary);
    final hasPhoto =
        isRegistered &&
        contact.profilePicUrl != null &&
        contact.profilePicUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Same avatar treatment as the contact picker row.
          CircleAvatar(
            radius: 36,
            backgroundColor: isRegistered ? primary : Colors.grey[600],
            backgroundImage:
                hasPhoto ? NetworkImage(contact.profilePicUrl!) : null,
            child:
                hasPhoto
                    ? null
                    : Text(
                      contact.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
          ),
          const SizedBox(height: 12),
          Text(
            contact.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.mediumText(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppThemeManage.appTheme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  contact.formattedPhoneNumber,
                  style: AppTypography.captionText(
                    context,
                  ).copyWith(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close, color: Colors.red, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        AppString.cancel,
                        style: AppTypography.captionText(context).copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send, color: onPrimary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        AppString.send,
                        style: AppTypography.captionText(context).copyWith(
                          color: onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
