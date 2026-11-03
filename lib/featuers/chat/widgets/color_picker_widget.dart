import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:whoxa/featuers/chat/data/repositories/label_repository.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

class ColorPickerWidget extends StatefulWidget {
  final String selectedColor;
  final Function(String) onColorSelected;

  const ColorPickerWidget({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  State<ColorPickerWidget> createState() => _ColorPickerWidgetState();
}

class _ColorPickerWidgetState extends State<ColorPickerWidget> {
  List<String> _availableColors = [];
  bool _isLoading = true;

  // Label color palette
  static const List<String> _defaultColors = [
    '#FC474E', '#FEE44E', '#7EFF4F', '#56FF93', '#54E2FF', '#4F7BFF',
    '#C53EFE', '#FC4494', '#FC4751', '#7EFF4F', '#B1131D', '#5AB71D',
    '#2179B2', '#A8B61E', '#8500B3', '#672528', '#672349', '#566A26',
    '#286668', '#282368'
  ];

  @override
  void initState() {
    super.initState();
    _loadColors();
  }

  Future<void> _loadColors() async {
    // Backend palette (GET /chat-labels/colors); the built-in list is the
    // fallback when it is unreachable or empty.
    var colors = <String>[];
    try {
      colors = await GetIt.instance<LabelRepository>().getColors();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _availableColors = colors.isNotEmpty ? colors : _defaultColors;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.appPriSecColor.primaryColor,
            strokeWidth: 2,
          ),
        ),
      );
    }
    return SizedBox(
      height: 160, // Fixed height to show exactly 4 rows
      child: GridView.builder(
        shrinkWrap: true,
        physics: ScrollPhysics(), // Allow scrolling
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: _availableColors.length,
        itemBuilder: (context, index) {
          final colorHex = _availableColors[index];
          final isSelected = widget.selectedColor == colorHex;

          return _buildColorTile(colorHex, isSelected);
        },
      ),
    );
  }

  Widget _buildColorTile(String colorHex, bool isSelected) {
    Color color;
    try {
      color = Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
    } catch (e) {
      color = AppColors.appPriSecColor.primaryColor;
    }

    return GestureDetector(
      onTap: () => widget.onColorSelected(colorHex),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppThemeManage.appTheme.textColor
                : AppThemeManage.appTheme.borderColor,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? Center(
                child: Icon(
                  Icons.check,
                  color: _getContrastColor(color),
                  size: 20,
                ),
              )
            : null,
      ),
    );
  }

  Color _getContrastColor(Color color) {
    // Calculate luminance to determine if we should use black or white text
    double luminance = (0.299 * (color.r * 255.0).round() + 0.587 * (color.g * 255.0).round() + 0.114 * (color.b * 255.0).round()) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}