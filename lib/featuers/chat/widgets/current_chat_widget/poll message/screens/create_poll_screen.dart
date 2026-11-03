import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/poll%20message/data/poll_model.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

class CreatePollBottomSheet extends StatefulWidget {
  final Function(PollData) onPollCreated;

  const CreatePollBottomSheet({super.key, required this.onPollCreated});

  @override
  State<CreatePollBottomSheet> createState() => _CreatePollBottomSheetState();
}

class _CreatePollBottomSheetState extends State<CreatePollBottomSheet> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _allowMultipleVotes = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 10) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  void _createPoll() {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      _showError('Please enter a question');
      return;
    }

    final options =
        _optionControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();

    if (options.length < 2) {
      _showError('Please add at least 2 options');
      return;
    }

    final poll = PollData(
      question: question,
      options:
          options
              .asMap()
              .entries
              .map((e) => PollOption(id: e.key, text: e.value))
              .toList(),
      allowMultipleVotes: _allowMultipleVotes,
      createdBy: 'currentUserId', // Replace with your currentUserId
      createdAt: DateTime.now(),
    );

    widget.onPollCreated(poll);
    Navigator.pop(context);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.appPriSecColor.secondaryRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.scaffoldBackColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ──
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: AppThemeManage.appTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──
          Padding(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                Text('Create Poll', style: AppTypography.h220(context)),
                Spacer(),
                TextButton(
                  onPressed: _createPoll,
                  child: Text(
                    'Create',
                    style: AppTypography.innerText14(context).copyWith(
                      color: AppColors.appPriSecColor.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppThemeManage.appTheme.borderColor),

          // ── Scrollable body ──
          Flexible(
            child: SingleChildScrollView(
              padding: SizeConfig.getPaddingSymmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question field
                  Text(
                    'Question',
                    style: AppTypography.innerText12Mediu(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: SizeConfig.height(1)),
                  TextFormField(
                    controller: _questionController,
                    maxLines: 2,
                    decoration: _inputDecoration(context, 'Ask a question...'),
                  ),

                  SizedBox(height: SizeConfig.height(3)),

                  // Options
                  Row(
                    children: [
                      Text(
                        'Options',
                        style: AppTypography.innerText12Mediu(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      Spacer(),
                      Text(
                        '${_optionControllers.length}/10',
                        style: AppTypography.captionText(
                          context,
                        ).copyWith(color: AppColors.textColor.textGreyColor),
                      ),
                    ],
                  ),
                  SizedBox(height: SizeConfig.height(1)),

                  // Option list
                  ...List.generate(_optionControllers.length, (index) {
                    return Padding(
                      padding: SizeConfig.getPaddingOnly(bottom: 10),
                      child: Row(
                        children: [
                          // Option number circle
                          Container(
                            height: 28,
                            width: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.appPriSecColor.primaryColor
                                  .withValues(alpha: 0.1),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: AppTypography.captionText(
                                  context,
                                ).copyWith(
                                  color: AppColors.appPriSecColor.primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: SizeConfig.width(3)),
                          Expanded(
                            child: TextFormField(
                              controller: _optionControllers[index],
                              decoration: _inputDecoration(
                                context,
                                'Option ${index + 1}',
                              ),
                            ),
                          ),
                          // Remove button (only show if more than 2)
                          if (_optionControllers.length > 2)
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.textColor.textGreyColor,
                              ),
                              onPressed: () => _removeOption(index),
                            ),
                        ],
                      ),
                    );
                  }),

                  // Add option button
                  if (_optionControllers.length < 10)
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: AppColors.appPriSecColor.primaryColor,
                        size: 18,
                      ),
                      label: Text(
                        'Add Option',
                        style: AppTypography.innerText12Mediu(context).copyWith(
                          color: AppColors.appPriSecColor.primaryColor,
                        ),
                      ),
                    ),

                  SizedBox(height: SizeConfig.height(2)),
                  Divider(color: AppThemeManage.appTheme.borderColor),
                  SizedBox(height: SizeConfig.height(1)),

                  // Allow multiple votes toggle
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allow Multiple Answers',
                              style: AppTypography.innerText12Mediu(
                                context,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Users can select more than one option',
                              style: AppTypography.captionText(
                                context,
                              ).copyWith(
                                color: AppColors.textColor.textGreyColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _allowMultipleVotes,
                        onChanged:
                            (val) => setState(() => _allowMultipleVotes = val),
                        activeThumbColor: AppColors.appPriSecColor.primaryColor,
                      ),
                    ],
                  ),
                  SizedBox(height: SizeConfig.height(2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.innerText12Ragu(
        context,
      ).copyWith(color: AppColors.textColor.textGreyColor),
      filled: true,
      fillColor: AppThemeManage.appTheme.darkGreyColor,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: AppThemeManage.appTheme.greyBlackGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: AppThemeManage.appTheme.greyBlackGrey),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide.none,
      ),
    );
  }
}

// ✅ Helper to show the bottom sheet from anywhere
void showCreatePollSheet(
  BuildContext context, {
  required Function(PollData) onPollCreated,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CreatePollBottomSheet(onPollCreated: onPollCreated),
  );
}
