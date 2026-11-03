import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/provider/label_provider.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';

class ChatLabelChip extends StatelessWidget {
  final String labelText;
  final String labelColor;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const ChatLabelChip({
    super.key,
    required this.labelText,
    required this.labelColor,
    this.fontSize = 10,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    try {
      chipColor = Color(
        int.parse(labelColor.substring(1), radix: 16) + 0xFF000000,
      );
    } catch (e) {
      chipColor = AppColors.appPriSecColor.primaryColor;
    }

    return Container(
      padding: padding ?? EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        labelText,
        style: AppTypography.innerText10(context).copyWith(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Chips for the label ids on a conversation, resolved through the cached
/// `GET /chat-labels` list ([LabelProvider]). An id missing from the cache
/// (e.g. label created on another device) triggers one refetch.
class ChatLabelChipList extends StatefulWidget {
  final List<int> labelIds;
  final double? fontSize;
  final EdgeInsetsGeometry? chipPadding;
  final double spacing;
  final double runSpacing;

  const ChatLabelChipList({
    super.key,
    required this.labelIds,
    this.fontSize = 10,
    this.chipPadding,
    this.spacing = 4,
    this.runSpacing = 3,
  });

  @override
  State<ChatLabelChipList> createState() => _ChatLabelChipListState();
}

class _ChatLabelChipListState extends State<ChatLabelChipList> {
  bool _requestedRefetch = false;

  @override
  Widget build(BuildContext context) {
    if (widget.labelIds.isEmpty) return const SizedBox.shrink();

    final provider = context.watch<LabelProvider>();
    final chips = <Widget>[];
    var hasUnknown = false;

    for (final id in widget.labelIds) {
      final label = provider.getLabelById(id);
      if (label == null) {
        hasUnknown = true;
        continue;
      }
      if (label.labelText == null || label.labelColor == null) continue;
      chips.add(
        ChatLabelChip(
          labelText: label.labelText!,
          labelColor: label.labelColor!,
          fontSize: widget.fontSize,
          padding: widget.chipPadding,
        ),
      );
    }

    if (hasUnknown && !_requestedRefetch && !provider.isLoading) {
      _requestedRefetch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) provider.loadLabels();
      });
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: chips,
    );
  }
}
