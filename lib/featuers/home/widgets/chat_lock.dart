import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class LockOptionsSheet extends StatelessWidget {
  final Records chat;
  final String chatName;
  final VoidCallback onLockToggle;
  final VoidCallback onChangePin;
  final VoidCallback onRemovePin;

  const LockOptionsSheet({
    super.key,
    required this.chat,
    required this.chatName,
    required this.onLockToggle,
    required this.onChangePin,
    required this.onRemovePin,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = chat.participants?.first.isLocked == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header — chat name + lock status
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.appPriSecColor.primaryColor
                    .withValues(alpha: 0.1),
                child: Icon(
                  Icons.lock_rounded,
                  color: AppColors.appPriSecColor.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppThemeManage.appTheme.textColor,
                    ),
                  ),
                  Text(
                    isLocked
                        ? '${AppString.chatLockStrings.chatIsLocked} 🔒'
                        : '${AppString.chatLockStrings.chatIsUnlocked} 🔓',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),

          // ── LOCKED state: show Change PIN + Remove Lock options ──
          if (isLocked) ...[
            // Change PIN
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade50,
                child: const Icon(
                  Icons.pin_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              title: Text(
                AppString.chatLockStrings.changePin,
                style: TextStyle(color: AppThemeManage.appTheme.textColor),
              ),
              subtitle: Text(AppString.chatLockStrings.setANew4DigitPIN),
              onTap: onChangePin,
            ),

            // Remove Lock — calls onRemovePin which shows confirmation dialog
            // NO PIN entry here — just confirm → API call
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red.shade50,
                child: Icon(
                  Icons.lock_open_rounded,
                  color: Colors.red.shade400,
                  size: 20,
                ),
              ),
              title: Text(
                AppString.chatLockStrings.removeLock,
                style: TextStyle(color: Colors.red.shade400),
              ),
              subtitle: Text(AppString.chatLockStrings.disablePinProtection),
              onTap: onRemovePin, // → shows removePin confirmation dialog only
            ),
          ],

          // ── UNLOCKED state: show Lock This Chat option ──
          if (!isLocked) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.appPriSecColor.primaryColor
                    .withValues(alpha: 0.1),
                child: Icon(
                  Icons.lock_rounded,
                  color: AppColors.appPriSecColor.primaryColor,
                  size: 20,
                ),
              ),
              title: Text(
                AppString.chatLockStrings.lockThisChat,
                style: TextStyle(color: AppThemeManage.appTheme.textColor),
              ),
              subtitle: Text(AppString.chatLockStrings.setPinToProtectThisChat),
              onTap: onLockToggle, // → shows lock description dialog
            ),
          ],
        ],
      ),
    );
  }
}
