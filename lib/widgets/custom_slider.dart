import 'package:flutter/material.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

class CustomSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int totlaDivisions;
  final Function(double) onChanged;
  final Color? inactiveTrackColor;
  final double? trackHeight;
  const CustomSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.totlaDivisions,
    required this.onChanged,
    this.inactiveTrackColor,
    this.trackHeight,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          padding: EdgeInsets.zero,
          trackHeight: trackHeight ?? 2,
          activeTrackColor: AppColors.appPriSecColor.secondaryColor,
          inactiveTrackColor: inactiveTrackColor ?? AppColors.white,
          thumbColor: AppColors.transparent,
          activeTickMarkColor: AppColors.transparent,
          rangeThumbShape: null,
          disabledInactiveTickMarkColor: AppColors.transparent,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0.0),
          overlayColor: AppColors.appPriSecColor.secondaryColor.withValues(
            alpha: 0.08,
          ),
          valueIndicatorColor: AppColors.appPriSecColor.secondaryColor,
        ),
        child: Slider(
          padding: EdgeInsets.zero,
          value: value,
          min: min,
          max: max,
          divisions: totlaDivisions,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
