import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';

/// Shows a finished voice recording for review. Resolves `true` when the user
/// taps send, `false` when they delete it.
Future<bool> showVoiceRecordPreview(
  BuildContext context, {
  required File file,
  required Duration recordedDuration,
}) async {
  final confirmed = await bottomSheetGobalWithoutTitle<bool>(
    context,
    barrierDismissible: false,
    isCrossIconHide: true,
    bottomsheetHeight: 200,
    child: PopScope(
      // Back must not dismiss the sheet without a send/delete decision.
      canPop: false,
      child: VoiceRecordPreview(
        file: file,
        recordedDuration: recordedDuration,
      ),
    ),
  );
  return confirmed == true;
}

class VoiceRecordPreview extends StatefulWidget {
  final File file;
  final Duration recordedDuration;

  const VoiceRecordPreview({
    super.key,
    required this.file,
    required this.recordedDuration,
  });

  @override
  State<VoiceRecordPreview> createState() => _VoiceRecordPreviewState();
}

class _VoiceRecordPreviewState extends State<VoiceRecordPreview> {
  // Own player, so previewing never touches the chat's message playback.
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  late Duration _duration = widget.recordedDuration;

  bool get _isPlaying => _state == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _subscriptions.addAll([
      _player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _state = state);
      }),
      _player.onPositionChanged.listen((position) {
        if (mounted) setState(() => _position = position);
      }),
      _player.onDurationChanged.listen((duration) {
        if (mounted && duration > Duration.zero) {
          setState(() => _duration = duration);
        }
      }),
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _position = Duration.zero);
      }),
    ]);
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setSource(DeviceFileSource(widget.file.path));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else if (_state == PlayerState.paused) {
        await _player.resume();
      } else {
        await _player.play(DeviceFileSource(widget.file.path));
      }
    } catch (e) {
      debugPrint('Voice preview playback error: $e');
    }
  }

  Future<void> _finish(bool send) async {
    try {
      await _player.stop();
    } catch (_) {}
    if (mounted) Navigator.pop(context, send);
  }

  String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.appPriSecColor.primaryColor;
    final onPrimary = ThemeColorPalette.getTextColor(primary);
    final maxMs = _duration.inMilliseconds.toDouble();
    final valueMs = _position.inMilliseconds.toDouble().clamp(
      0.0,
      maxMs > 0 ? maxMs : 0.0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: _togglePlay,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: primary,
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: onPrimary,
                    size: 28,
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: primary,
                    inactiveTrackColor: primary.withValues(alpha: 0.25),
                    thumbColor: primary,
                    overlayColor: primary.withValues(alpha: 0.15),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs > 0 ? maxMs : 1,
                    value: maxMs > 0 ? valueMs : 0,
                    onChanged:
                        maxMs > 0
                            ? (ms) {
                              final target = Duration(milliseconds: ms.round());
                              setState(() => _position = target);
                              _player.seek(target);
                            }
                            : null,
                  ),
                ),
              ),
              Text(
                _isPlaying || _position > Duration.zero
                    ? _format(_position)
                    : _format(_duration),
                style: AppTypography.captionText(
                  context,
                ).copyWith(color: AppThemeManage.appTheme.textColor),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _finish(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppString.delete,
                        style: AppTypography.captionText(context).copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _finish(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send, color: onPrimary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        AppString.send,
                        style: AppTypography.captionText(context).copyWith(
                          color: onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
