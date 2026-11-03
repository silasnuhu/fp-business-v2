import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';

/// Same limit `PATCH /messages/:id` (and sending) enforces on `body`.
const int kMaxMessageBodyLength = 65536;

/// Shows the "Edit message" sheet prefilled with [initialText]. Resolves to
/// the new text when the user saves a real change, or null when cancelled /
/// left unchanged. Blank text can't be saved.
Future<String?> showEditMessageSheet(
  BuildContext context, {
  required String initialText,
}) {
  return bottomSheetGobalWithoutTitle<String>(
    context,
    bottomsheetHeight: SizeConfig.height(45),
    borderRadius: BorderRadius.circular(20),
    isCrossIconHide: true,
    shrinkWrap: true,
    child: _EditMessageSheet(initialText: initialText),
  );
}

class _EditMessageSheet extends StatefulWidget {
  final String initialText;

  const _EditMessageSheet({required this.initialText});

  @override
  State<_EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends State<_EditMessageSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave {
    final text = _controller.text.trim();
    return text.isNotEmpty && text != widget.initialText.trim();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 25, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppString.editMessage,
            style: AppTypography.innerText16(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: SizeConfig.height(2)),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
            maxLength: kMaxMessageBodyLength,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.innerText14(context),
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.appPriSecColor.primaryColor,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppThemeManage.appTheme.borderColor,
                  width: 2,
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: SizeConfig.height(3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: customBorderBtn(
                  context,
                  onTap: () => Navigator.pop(context),
                  title: AppString.cancel,
                ),
              ),
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: Opacity(
                  opacity: _canSave ? 1 : 0.5,
                  child: customBtn2(
                    context,
                    onTap:
                        _canSave
                            ? () => Navigator.pop(
                              context,
                              _controller.text.trim(),
                            )
                            : null,
                    child: Text(
                      AppString.save,
                      style: AppTypography.h5(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor.textBlackColor,
                      ),
                    ),
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
