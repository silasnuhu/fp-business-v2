import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/report/data/models/report_types_model.dart';
import 'package:whoxa/featuers/report/provider/report_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';

/// Lets the user pick a reason and report a user ([userId]) or a group
/// ([chatId]). Exactly one of the two must be set.
class ReportUserDialog extends StatefulWidget {
  final int? userId;
  final int? chatId;

  const ReportUserDialog({super.key, this.userId, this.chatId})
    : assert((userId == null) != (chatId == null));

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  ReportType? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ReportProvider>();
      provider.clearMessages();
      provider.fetchReportTypes();
    });
  }

  Future<void> _submit(ReportProvider provider) async {
    final selected = _selected;
    if (selected == null || provider.isSubmittingReport) return;

    final success = await provider.report(
      userId: widget.userId,
      chatId: widget.chatId,
      reportTypeId: selected.reportTypeId,
    );
    if (!mounted) return;

    if (success) {
      final message =
          provider.successMessage.isNotEmpty
              ? provider.successMessage
              : AppString.yourReportSubmitted;
      // Show first: the snackbar resolves the root navigator from this context.
      snackbarNew(context, msg: message);
      Navigator.of(context).pop();
    } else {
      snackbarNew(
        context,
        msg:
            provider.submitErrorMessage.isNotEmpty
                ? provider.submitErrorMessage
                : AppString.somethingWentWrongTryAgain,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingReportTypes) {
          return Center(child: commonLoading());
        }

        if (provider.errorMessage.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red[600]),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          provider.errorMessage,
                          style: TextStyle(color: Colors.red[600]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: provider.fetchReportTypes,
                    child: Text(
                      AppString.retry,
                      style: TextStyle(
                        color: AppColors.appPriSecColor.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (provider.reportTypes.isEmpty) {
          return Center(
            child: Text(
              AppString.reportNotAvailable,
              style: AppTypography.innerText14(context),
            ),
          );
        }

        final primary = AppColors.appPriSecColor.primaryColor;
        final canSubmit = _selected != null && !provider.isSubmittingReport;

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(top: SizeConfig.height(1)),
                itemCount: provider.reportTypes.length,
                itemBuilder: (context, index) {
                  final reportType = provider.reportTypes[index];
                  final isSelected =
                      _selected?.reportTypeId == reportType.reportTypeId;
                  final isLast = index == provider.reportTypes.length - 1;

                  return InkWell(
                    onTap:
                        provider.isSubmittingReport
                            ? null
                            : () => setState(() => _selected = reportType),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                isLast
                                    ? AppColors.transparent
                                    : AppThemeManage.appTheme.borderColor,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              reportType.reportText,
                              style: AppTypography.innerText12Mediu(
                                context,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color:
                                isSelected
                                    ? primary
                                    : AppThemeManage.appTheme.borderColor,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: SizeConfig.height(5.5),
                child: customBtn2(
                  context,
                  onTap: canSubmit ? () => _submit(provider) : null,
                  color: canSubmit ? primary : primary.withValues(alpha: 0.4),
                  child:
                      provider.isSubmittingReport
                          ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ThemeColorPalette.getTextColor(primary),
                            ),
                          )
                          : Text(
                            AppString.report,
                            style: AppTypography.h5(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: ThemeColorPalette.getTextColor(primary),
                            ),
                          ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Opens the report sheet for a user. [title] is shown as the sheet title
/// (e.g. "Report John").
void showReportUserDialog(
  BuildContext context, {
  required int userId,
  required String title,
}) {
  _showReportSheet(
    context,
    title: title,
    child: ReportUserDialog(userId: userId),
  );
}

/// Opens the report sheet for a group, identified by its [chatId].
void showReportGroupDialog(
  BuildContext context, {
  required int chatId,
  required String title,
}) {
  _showReportSheet(
    context,
    title: title,
    child: ReportUserDialog(chatId: chatId),
  );
}

void _showReportSheet(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  bottomSheetGobal(
    context,
    bottomsheetHeight: SizeConfig.sizedBoxHeight(480),
    borderRadius: BorderRadius.circular(20),
    title: title,
    child: child,
  );
}
