import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/utils/time_stamp_formatter.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class LiveLastSeenWidget extends StatefulWidget {
  final String? timestamp;
  final bool isOnline;
  final bool isTyping;

  const LiveLastSeenWidget({
    super.key,
    this.timestamp,
    required this.isOnline,
    required this.isTyping,
  });

  @override
  State<LiveLastSeenWidget> createState() => _LiveLastSeenWidgetState();
}

class _LiveLastSeenWidgetState extends State<LiveLastSeenWidget>
    with SingleTickerProviderStateMixin {
  Timer? _updateTimer;
  String _lastSeenText = '';
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for typing
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _updateLastSeenText();
    _startUpdateTimer();
  }

  @override
  void didUpdateWidget(LiveLastSeenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timestamp != widget.timestamp ||
        oldWidget.isOnline != widget.isOnline ||
        oldWidget.isTyping != widget.isTyping) {
      _updateLastSeenText();
    }
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted && !widget.isOnline && !widget.isTyping) {
        _updateLastSeenText();
      }
    });
  }

  void _updateLastSeenText() {
    if (!mounted) return;

    setState(() {
      if (widget.isTyping) {
        _lastSeenText = "typing...";
        _animationController.repeat();
      } else if (widget.isOnline) {
        _lastSeenText = AppString.online;
        _animationController.stop();
        _animationController.reset();
      } else if (widget.timestamp != null && widget.timestamp!.isNotEmpty) {
        _lastSeenText = TimestampFormatter.formatLastSeen(widget.timestamp!);
        _animationController.stop();
        _animationController.reset();
      } else {
        _lastSeenText = "";
        _animationController.stop();
        _animationController.reset();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isTyping) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Row(
            children: [
              Text(
                AppString.typing,
                style: AppTypography.mediumText(
                  context,
                ).copyWith(color: AppColors.textColor.textDarkGray),
              ),
              SizedBox(width: 2),
              // Animated typing dots
              Row(
                children: List.generate(3, (index) {
                  final delay = index * 0.3;
                  final opacity =
                      _animation.value > delay && _animation.value < delay + 0.3
                          ? 1.0
                          : 0.3;
                  return Container(
                    margin: EdgeInsets.only(right: 2),
                    child: Opacity(
                      opacity: opacity,
                      child: Text(
                        "•",
                        style: AppTypography.mediumText(context).copyWith(
                          color: AppColors.textColor.textDarkGray,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      );
    } else {
      // Display online/offline status with appropriate color
      final isOnline = widget.isOnline;
      return Text(
        _lastSeenText,
        style: AppTypography.innerText10(context).copyWith(
          fontSize: 11,
          color:
              isOnline
                  ? Colors
                      .green // Green color for online
                  : AppColors.textColor.textDarkGray,
        ),
      );
    }
  }
}
