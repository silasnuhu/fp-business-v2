import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/provider/label_provider.dart';
import 'package:whoxa/featuers/chat/widgets/color_picker_widget.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/flag_label_icon.dart';

class AddEditLabelDialog extends StatefulWidget {
  const AddEditLabelDialog({super.key});

  @override
  State<AddEditLabelDialog> createState() => _AddEditLabelDialogState();
}

class _AddEditLabelDialogState extends State<AddEditLabelDialog> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return Consumer<LabelProvider>(
      builder: (context, provider, child) {
        final isEditing = provider.isEditing;

        return Dialog(
          backgroundColor: AppThemeManage.appTheme.darkGreyColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: SizeConfig.screenWidth - 40,
              maxHeight: SizeConfig.screenHeight * 0.8,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isEditing
                                  ? AppString.profileStrings.editLabel
                                  : AppString.profileStrings.addNewLabel,
                              style: AppTypography.h5(context).copyWith(
                                color: AppThemeManage.appTheme.textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: SizeConfig.getFontSize(20),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: AppThemeManage.appTheme.darkWhiteColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Label Text Field
                      Text(
                        AppString.profileStrings.labelText, //'Label Text',
                        style: AppTypography.innerText14(context).copyWith(
                          color: AppThemeManage.appTheme.textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: provider.labelTextController,
                        style: AppTypography.innerText14(
                          context,
                        ).copyWith(color: AppThemeManage.appTheme.textColor),
                        decoration: InputDecoration(
                          hintText:
                              AppString
                                  .profileStrings
                                  .enterLabelName, //'Enter label name',
                          hintStyle: AppTypography.innerText14(
                            context,
                          ).copyWith(color: AppColors.textColor.textGreyColor),
                          filled: true,
                          fillColor: AppThemeManage.appTheme.scaffoldBackColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppThemeManage.appTheme.borderColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppThemeManage.appTheme.borderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.appPriSecColor.primaryColor,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppString
                                .profileStrings
                                .labelTextIsRequired; //'Label text is required';
                          }
                          if (value.trim().length < 2) {
                            return AppString
                                .profileStrings
                                .labelTextMustBe; //'Label text must be at least 2 characters';
                          }
                          return null;
                        },
                        maxLength: 50,
                        buildCounter: (
                          context, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) {
                          return Text(
                            '$currentLength/${maxLength ?? 0}',
                            style: AppTypography.captionText(context).copyWith(
                              color: AppColors.textColor.textGreyColor,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 24),

                      // Color Picker
                      Text(
                        AppString.profileStrings.labelColor, //'Label Color',
                        style: AppTypography.innerText14(context).copyWith(
                          color: AppThemeManage.appTheme.textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),

                      // Selected Color Preview
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppThemeManage.appTheme.scaffoldBackColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppThemeManage.appTheme.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 16),
                            FlagLabelIcon(
                              size: 32,
                              color: _getColorFromHex(provider.selectedColor),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                provider.selectedColor,
                                style: AppTypography.innerText14(
                                  context,
                                ).copyWith(
                                  color: AppThemeManage.appTheme.textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),

                      // Color Picker Grid
                      ColorPickerWidget(
                        selectedColor: provider.selectedColor,
                        onColorSelected: provider.setSelectedColor,
                      ),
                      SizedBox(height: 24),

                      // Error Message
                      if (provider.errorMessage.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  provider.errorMessage,
                                  style: AppTypography.innerText14(
                                    context,
                                  ).copyWith(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed:
                                  provider.isSaving
                                      ? null
                                      : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: AppThemeManage.appTheme.borderColor,
                                  ),
                                ),
                              ),
                              child: Text(
                                AppString.cancel, //'Cancel',
                                style: AppTypography.innerText14(
                                  context,
                                ).copyWith(
                                  color: AppColors.textColor.textGreyColor,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: provider.isSaving ? null : _saveLabel,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppColors.appPriSecColor.primaryColor,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child:
                                  provider.isSaving
                                      ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color:
                                              AppThemeManage
                                                  .appTheme
                                                  .scaffoldBackColor,
                                        ),
                                      )
                                      : Text(
                                        isEditing
                                            ? AppString.profileStrings.update
                                            : AppString.profileStrings.create,
                                        style: AppTypography.innerText14(
                                          context,
                                        ).copyWith(
                                          color:
                                              AppThemeManage
                                                  .appTheme
                                                  .scaffoldBackColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getColorFromHex(String hexColor) {
    try {
      return Color(int.parse(hexColor.substring(1), radix: 16) + 0xFF000000);
    } catch (e) {
      return AppColors.appPriSecColor.primaryColor;
    }
  }

  Future<void> _saveLabel() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<LabelProvider>(context, listen: false);
    provider.clearError();

    bool success;
    if (provider.isEditing) {
      success = await provider.updateLabel();
    } else {
      success = await provider.addLabel();
    }

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }
}
