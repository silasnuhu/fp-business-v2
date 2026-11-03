import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/widgets/chat_label_selector.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/widgets/global.dart';

/// "Manage Labels" row on a chat's info screen: opens the label picker for
/// that conversation (a chat holds at most 3 of the business's labels).
class ManageLabelsTile extends StatelessWidget {
  final int chatId;
  final String? chatName;

  const ManageLabelsTile({super.key, required this.chatId, this.chatName});

  /// Label ids currently on [chatId], read from the cached chat list.
  List<int> _appliedLabels(ChatProvider chatProvider) {
    for (final chat in chatProvider.chatListData.chats) {
      final record = chat.records?.isNotEmpty == true ? chat.records!.first : null;
      if (record?.chatId == chatId) {
        return (record!.labelIds ?? const [])
            .map((e) => int.tryParse('$e'))
            .whereType<int>()
            .toList();
      }
    }
    return [];
  }

  void _openSelector(BuildContext context) {
    final applied = _appliedLabels(
      Provider.of<ChatProvider>(context, listen: false),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => ChatLabelSelector(
            chatId: chatId,
            chatName: chatName,
            currentlyAppliedLabels: applied,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth < 360 ? 10 : 15),
      child: container(
        context,
        radius: screenWidth < 360 ? 8 : 10,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 0),
            blurRadius: screenWidth < 360 ? 8 : 10,
            spreadRadius: 0,
            color: AppColors.shadowColor.c000000.withValues(alpha: 0.07),
          ),
        ],
        child: ListTile(
          leading: Container(
            height: SizeConfig.height(10),
            width: SizeConfig.width(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.appPriSecColor.secondaryColor,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.label_outline,
                size: 20,
                color: ThemeColorPalette.getTextColor(
                  AppColors.appPriSecColor.primaryColor,
                ),
              ),
            ),
          ),
          title: Text(
            'Manage Labels',
            style: AppTypography.innerText14(context),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: AppThemeManage.appTheme.darkWhiteColor,
            size: 10,
          ),
          onTap: () => _openSelector(context),
        ),
      ),
    );
  }
}
