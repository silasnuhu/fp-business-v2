import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/chat/data/models/label_model.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/provider/label_provider.dart';
import 'package:whoxa/featuers/chat/widgets/add_edit_label_dialog.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/flag_label_icon.dart';
import 'package:whoxa/widgets/global.dart';

/// Label manager, rebuilt on the Flickpitch design system.
///
/// Behaviour is unchanged: load on open, add/edit through the existing
/// `AddEditLabelDialog`, long-press to delete with confirmation, and a chat
/// list refresh after a successful delete (the server strips the label from
/// every chat it was on).
class LabelManagementScreen extends StatefulWidget {
  const LabelManagementScreen({super.key});

  @override
  State<LabelManagementScreen> createState() => _LabelManagementScreenState();
}

class _LabelManagementScreenState extends State<LabelManagementScreen> {
  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  void _loadLabels() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LabelProvider>(context, listen: false);
      provider.loadLabels(refresh: true);
    });
  }

  void _showAddLabelDialog() {
    if (checkDemoMode(context)) return;

    final provider = Provider.of<LabelProvider>(context, listen: false);
    provider.clearForm();

    showDialog(
      context: context,
      builder: (context) => AddEditLabelDialog(),
    ).then((result) {
      if (result == true) {
        _showSnackBar(AppString.profileStrings.labelAdded);
      }
    });
  }

  void _showEditLabelDialog(ChatLabel label) {
    if (checkDemoMode(context)) return;

    final provider = Provider.of<LabelProvider>(context, listen: false);
    provider.setEditingLabel(label);

    showDialog(
      context: context,
      builder: (context) => AddEditLabelDialog(),
    ).then((result) {
      if (result == true) {
        _showSnackBar(AppString.profileStrings.labelUpdated);
      }
    });
  }

  void _showDeleteDialog(ChatLabel label) {
    if (checkDemoMode(context)) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Fp.inkRaised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Fp.rLg),
            ),
            title: Text(
              AppString.profileStrings.deleteLabel,
              style: Fp.h2,
            ),
            content: Text(
              '${AppString.profileStrings.areYouSureDelete} "${label.labelText}"? ${AppString.profileStrings.thisActionCannotBeUndone}',
              style: Fp.body.copyWith(color: Fp.textMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppString.cancel,
                  style: Fp.body.copyWith(color: Fp.textMuted),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteLabel(label);
                },
                child: Text(
                  AppString.settingStrigs.delete,
                  style: Fp.body.copyWith(
                    color: Fp.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _deleteLabel(ChatLabel label) async {
    final provider = Provider.of<LabelProvider>(context, listen: false);
    final success = await provider.deleteLabel(label.labelId!);

    if (success) {
      if (mounted) {
        Provider.of<ChatProvider>(context, listen: false).refreshChatList();
      }
      _showSnackBar('Label deleted successfully');
    } else {
      _showSnackBar('Failed to delete label: ${provider.errorMessage}');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Fp.inkRaised,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        child: Consumer<LabelProvider>(
          builder: (context, provider, child) {
            return RefreshIndicator(
              color: Fp.violet,
              backgroundColor: Fp.inkRaised,
              onRefresh: () => provider.loadLabels(refresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Fp.s20,
                  Fp.s12,
                  Fp.s20,
                  Fp.s40,
                ),
                children: [
                  _header(provider.labels.length),
                  const SizedBox(height: Fp.s8),
                  Text(
                    'Tag chats as New order, Paid, Follow-up — then filter your '
                    'chat list by them.',
                    style: Fp.body.copyWith(color: Fp.textMuted),
                  ),
                  const SizedBox(height: Fp.s20),
                  if (provider.isLoading && provider.labels.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Fp.s40),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Fp.violet),
                        ),
                      ),
                    )
                  else if (provider.errorMessage.isNotEmpty)
                    FpEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load labels',
                      message: provider.errorMessage,
                      action: FpPrimaryButton(
                        label: AppString.profileStrings.retry,
                        expand: false,
                        onPressed: () => provider.loadLabels(refresh: true),
                      ),
                    )
                  else if (provider.labels.isEmpty)
                    FpEmptyState(
                      icon: Icons.label_outline_rounded,
                      title: AppString.profileStrings.noLabelsYet,
                      message: AppString.profileStrings.createYouFirst,
                      action: FpPrimaryButton(
                        label: AppString.profileStrings.createLabel,
                        icon: Icons.add_rounded,
                        expand: false,
                        onPressed: _showAddLabelDialog,
                      ),
                    )
                  else
                    for (final label in provider.labels)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Fp.s12),
                        child: _labelTile(label),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(int count) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          color: Fp.text,
        ),
        const SizedBox(width: Fp.s4),
        Expanded(child: Text(AppString.profileStrings.labelManager, style: Fp.display)),
        if (count > 0)
          GestureDetector(
            onTap: _showAddLabelDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Fp.s16,
                vertical: Fp.s8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Fp.violet, Fp.violetDeep],
                ),
                borderRadius: BorderRadius.circular(Fp.rPill),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    AppString.profileStrings.add,
                    style: Fp.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _labelTile(ChatLabel label) {
    Color labelColor;
    try {
      labelColor = Color(
        int.parse(label.labelColor!.substring(1), radix: 16) + 0xFF000000,
      );
    } catch (e) {
      labelColor = Fp.violet;
    }

    return FpSurface(
      padding: EdgeInsets.zero,
      onTap: () => _showEditLabelDialog(label),
      child: InkWell(
        borderRadius: BorderRadius.circular(Fp.rLg),
        onLongPress: () => _showDeleteDialog(label),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Fp.s16,
            vertical: Fp.s16,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Fp.rSm),
                ),
                child: Center(
                  child: FlagLabelIcon(size: 20, color: labelColor),
                ),
              ),
              const SizedBox(width: Fp.s12),
              Expanded(
                child: Text(
                  label.labelText ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Fp.bodyStrong,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Fp.textFaint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
