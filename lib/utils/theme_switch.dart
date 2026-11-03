// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

class CustomSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CustomSwitch({super.key, required this.value, required this.onChanged});

  @override
  _CustomSwitchState createState() => _CustomSwitchState();
}

class _CustomSwitchState extends State<CustomSwitch>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  String switch1 = '';

  String switch2 = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
    );
    // Initialize animation but don't store it since it's not used
    AlignmentTween(
      begin: widget.value ? Alignment.centerRight : Alignment.centerLeft,
      end: widget.value ? Alignment.centerLeft : Alignment.centerRight,
    ).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _animationController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController!,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            if (_animationController!.isCompleted) {
              _animationController!.reverse();
            } else {
              _animationController!.forward();
            }
            widget.value == false
                ? widget.onChanged(true)
                : widget.onChanged(false);
          },
          child: Container(
            width: 46.0,
            height: 25.0,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.appPriSecColor.primaryColor),
              borderRadius: BorderRadius.circular(24.0),
              // color: Appcolors.appPriSecColor.appPrimblue
              // _circleAnimation!.value == Alignment.centerLeft
              //     ? AppColors.darkModeColor.blackColor
              //     : AppColors.appPriSecColor.primaryColor,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                top: 2.0,
                bottom: 2.0,
                right: 1.0,
                left: 1.0,
              ),
              child: Container(
                alignment:
                    widget.value
                        ? ((Directionality.of(context) == TextDirection.rtl)
                            ? Alignment.centerRight
                            : Alignment.centerLeft)
                        : ((Directionality.of(context) == TextDirection.rtl)
                            ? Alignment.centerLeft
                            : Alignment.centerRight),
                child: Container(
                  width: 22.0,
                  height: 22.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.appPriSecColor.primaryColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
