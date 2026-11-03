import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/ai_assistant/provider/ai_assistant_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

/// Received-style bubble showing the AI reply while it is still generating:
/// typing dots until the first chunk, then the text streamed so far. It is
/// only a preview — the real message replaces it when `new_message` arrives.
/// Renders nothing when no reply is in progress for [chatId].
class AiReplyPreviewBubble extends StatelessWidget {
  final int chatId;

  const AiReplyPreviewBubble({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final preview = context.select<AiAssistantProvider, String?>(
      (provider) => provider.replyPreviewFor(chatId),
    );
    if (preview == null) return const SizedBox.shrink();

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: SizeConfig.width(70)),
        padding: SizeConfig.getPaddingSymmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: AppThemeManage.appTheme.chatOppText,
          borderRadius: AppDirectionality.appDirectionBorderRadius
              .chatBubbleRadius(isSentByMe: false, hasParentMessage: false),
        ),
        child:
            preview.isEmpty
                ? const _TypingDots()
                : Text(
                  preview,
                  style: AppTypography.innerText12Ragu(
                    context,
                  ).copyWith(color: AppThemeManage.appTheme.textColor),
                ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppThemeManage.appTheme.textColor;
    return SizedBox(
      height: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              // Each dot pulses a third of a cycle after the previous one.
              final phase = (_controller.value - index / 3) % 1.0;
              final opacity =
                  phase < 0.5 ? 0.3 + phase * 1.4 : 1.0 - (phase - 0.5) * 1.4;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity: opacity.clamp(0.3, 1.0),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
