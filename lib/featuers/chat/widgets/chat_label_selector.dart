import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/provider/label_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/flag_label_icon.dart';
import 'package:whoxa/widgets/global.dart';

class ChatLabelSelector extends StatefulWidget {
  final int chatId;
  final String? chatName;
  final List<int>? currentlyAppliedLabels;

  const ChatLabelSelector({
    super.key,
    required this.chatId,
    this.chatName,
    this.currentlyAppliedLabels,
  });

  @override
  State<ChatLabelSelector> createState() => _ChatLabelSelectorState();
}

class _ChatLabelSelectorState extends State<ChatLabelSelector> {
  late Set<int> _selectedLabelIds;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedLabelIds = Set<int>.from(widget.currentlyAppliedLabels ?? []);
    _loadLabels();
  }

  void _loadLabels() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LabelProvider>(context, listen: false);
      if (provider.labels.isEmpty) {
        provider.loadLabels(refresh: true);
      }
    });
  }

  Color _parseColor(String? colorString) {
    try {
      if (colorString?.isNotEmpty == true) {
        return Color(
          int.parse(colorString!.substring(1), radix: 16) + 0xFF000000,
        );
      }
    } catch (e) {
      // If parsing fails, return default color
    }
    return AppColors.appPriSecColor.primaryColor;
  }

  void _toggleLabel(int labelId) {
    setState(() {
      if (_selectedLabelIds.contains(labelId)) {
        _selectedLabelIds.remove(labelId);
      } else if (_selectedLabelIds.length < 3) {
        _selectedLabelIds.add(labelId);
      } else {
        // Show message that max 3 labels allowed
        _showMaxLabelsMessage();
      }
    });
  }

  void _showMaxLabelsMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum 3 labels can be applied to a chat'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _applyLabels() async {
    // ✅ DEMO MODE: Block label assignment for demo accounts
    if (checkDemoMode(context)) return;

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final provider = Provider.of<LabelProvider>(context, listen: false);

    // Get original applied labels and current selected labels
    final originalLabels = List<int>.from(widget.currentlyAppliedLabels ?? []);
    final newLabels = _selectedLabelIds.toList();

    // Use the new unified update method
    final success = await provider.updateChatLabels(
      chatId: widget.chatId,
      currentLabels: originalLabels,
      newLabels: newLabels,
    );

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (success) {
        // Refresh chat list to show updated labels
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        chatProvider.refreshChatList();

        // Capture the messenger before popping, since the sheet's own
        // context is deactivated once Navigator.pop runs.
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context, true);
        _showSuccessMessage(messenger);
      } else {
        _showErrorMessage(provider.errorMessage);
      }
    }
  }

  void _showSuccessMessage(ScaffoldMessengerState messenger) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Labels updated successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.isNotEmpty ? message : 'Failed to apply labels'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return Container(
      height: SizeConfig.height(80),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.scaffoldBackColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppThemeManage.appTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Labels',
                        style: AppTypography.h5(context).copyWith(
                          color: AppThemeManage.appTheme.textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.chatName ?? 'Chat',
                        style: AppTypography.innerText14(
                          context,
                        ).copyWith(color: AppColors.textColor.textGreyColor),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Select up to 3 labels for this chat. Tap to add/remove labels.',
                        style: AppTypography.innerText12Ragu(
                          context,
                        ).copyWith(color: AppColors.textColor.textGreyColor),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_selectedLabelIds.length}/3',
                  style: AppTypography.innerText14(context).copyWith(
                    color:
                        _selectedLabelIds.length >= 3
                            ? Colors.orange
                            : AppColors.textColor.textGreyColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Labels list
          Expanded(
            child: Consumer<LabelProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.appPriSecColor.primaryColor,
                    ),
                  );
                }

                if (provider.errorMessage.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.textColor.textGreyColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          provider.errorMessage,
                          style: AppTypography.innerText14(
                            context,
                          ).copyWith(color: AppColors.textColor.textGreyColor),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.loadLabels(refresh: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.appPriSecColor.primaryColor,
                          ),
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.labels.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.label_outline,
                          size: 48,
                          color: AppColors.textColor.textGreyColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No labels available',
                          style: AppTypography.innerText16(context).copyWith(
                            color: AppColors.textColor.textGreyColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create labels in Business Tools > Labels\nto organize your chats.',
                          style: AppTypography.innerText12Ragu(
                            context,
                          ).copyWith(color: AppColors.textColor.textGreyColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  itemCount: provider.labels.length,
                  itemBuilder: (context, index) {
                    final label = provider.labels[index];
                    final isSelected = _selectedLabelIds.contains(
                      label.labelId,
                    );
                    final wasOriginallyApplied =
                        widget.currentlyAppliedLabels?.contains(
                          label.labelId,
                        ) ??
                        false;
                    final labelColor = _parseColor(label.labelColor);

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppThemeManage.appTheme.darkGreyColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.appPriSecColor.primaryColor
                                  : AppThemeManage.appTheme.borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _toggleLabel(label.labelId!),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                // Label icon
                                FlagLabelIcon(size: 24, color: labelColor),
                                SizedBox(width: 16),

                                // Label text
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label.labelText ?? '',
                                        style: AppTypography.innerText14(
                                          context,
                                        ).copyWith(
                                          color:
                                              AppThemeManage.appTheme.textColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (wasOriginallyApplied && !isSelected)
                                        Text(
                                          'Will be removed',
                                          style: AppTypography.innerText10(
                                            context,
                                          ).copyWith(
                                            color: Colors.orange,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        )
                                      else if (!wasOriginallyApplied &&
                                          isSelected)
                                        Text(
                                          'Will be added',
                                          style: AppTypography.innerText10(
                                            context,
                                          ).copyWith(
                                            color: Colors.green,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        )
                                      else if (wasOriginallyApplied &&
                                          isSelected)
                                        Text(
                                          'Currently applied',
                                          style: AppTypography.innerText10(
                                            context,
                                          ).copyWith(
                                            color:
                                                AppColors
                                                    .textColor
                                                    .textGreyColor,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Selection indicator
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color:
                                        AppColors.appPriSecColor.primaryColor,
                                    size: 24,
                                  )
                                else
                                  Icon(
                                    Icons.radio_button_unchecked,
                                    color:
                                        AppThemeManage.appTheme.darkWhiteColor,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Apply button
          Container(
            padding: EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _applyLabels,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appPriSecColor.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child:
                    _isLoading
                        ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          AppString
                              .profileStrings
                              .updateLabels, //'Update Labels',
                          style: AppTypography.innerText16(context).copyWith(
                            color: ThemeColorPalette.getTextColor(
                              AppColors.appPriSecColor.primaryColor,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
