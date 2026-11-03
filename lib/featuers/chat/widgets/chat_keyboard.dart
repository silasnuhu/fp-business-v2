import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

/// WhatsApp-style message composer.
///
/// Layout, left to right:
///   [ emoji ][ text … ][ attach ][ camera ]   ← one rounded field
///   [ mic / send circle ]                      ← outside the field
///
/// The emoji control is a real picker (no dependency): tapping it opens a sheet
/// and inserts at the caret. Every existing callback is preserved —
/// `onChanged`, `onTap`, `onTapPin` (attach), `onTapCamera`, hold-to-record
/// pointer events, `isLoading`, and `textOnly`.
class ChatKeyboard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final Function() onTapSendMsg;
  final void Function(PointerDownEvent)? onPointerDown;
  final void Function(PointerUpEvent)? onPointerUp;
  final Function() onTapPin;
  final Function() onTapCamera;
  final Function(String)? onChanged;
  final Function()? onTap;
  final bool isLoading;
  final bool textOnly;

  const ChatKeyboard({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onTapSendMsg,
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onTapPin,
    required this.onTapCamera,
    this.onChanged,
    this.onTap,
    this.isLoading = false,
    this.textOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Fp.ink,
        border: Border(top: BorderSide(color: Fp.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Fp.s8, Fp.s8, Fp.s8, Fp.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _field(context)),
              const SizedBox(width: Fp.s8),
              _action(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: Fp.s4),
      // Flat field: no grey pill. Thin outline + gentle radius reads cleaner
      // and lets the wallpaper show through behind the composer.
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Fp.hairlineStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!textOnly)
            _iconButton(
              icon: Icons.emoji_emotions_outlined,
              tooltip: 'Emoji',
              onTap: () => _pickEmoji(context),
            ),
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              onEditingComplete: () {
                FocusScope.of(context).requestFocus(focusNode);
              },
              onChanged: onChanged,
              onTap: onTap,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              readOnly: isLoading,
              style: Fp.body.copyWith(
                fontSize: 15.5,
                height: 1.3,
                color: isURL(controller.text.trim()) ? Fp.violet : Fp.text,
              ),
              cursorColor: Fp.violet,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: AppString.typeMessage,
                hintStyle: Fp.body.copyWith(color: Fp.textFaint),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: textOnly ? Fp.s12 : Fp.s4,
                ),
              ),
            ),
          ),
          if (!textOnly) ...[
            // WhatsApp behaviour: the attach control retracts once you start
            // typing, handing its width to the text field. It returns the
            // moment the field is empty again.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                if (value.text.trim().isNotEmpty) {
                  return const SizedBox.shrink();
                }
                return _iconButton(
                  icon: Icons.attach_file_rounded,
                  tooltip: 'Attach',
                  onTap: onTapPin,
                );
              },
            ),
            _iconButton(
              icon: Icons.photo_camera_outlined,
              tooltip: 'Camera',
              onTap: onTapCamera,
            ),
            const SizedBox(width: Fp.s4),
          ],
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final button = InkWell(
      borderRadius: BorderRadius.circular(Fp.rPill),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 23, color: Fp.textMuted),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  /// Lightweight emoji sheet — inserts at the caret so it composes with typing.
  Future<void> _pickEmoji(BuildContext context) async {
    const emojis = [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '😂',
      '🙂',
      '😊',
      '😇',
      '😍',
      '🥰',
      '😘',
      '😗',
      '😋',
      '😜',
      '🤪',
      '🤗',
      '🤔',
      '🤭',
      '😐',
      '😴',
      '😪',
      '😷',
      '🤒',
      '🥳',
      '😎',
      '🤓',
      '😢',
      '😭',
      '😤',
      '😠',
      '🤬',
      '😱',
      '😳',
      '🥺',
      '🙏',
      '👍',
      '👎',
      '👏',
      '🙌',
      '🤝',
      '💪',
      '👋',
      '❤️',
      '🧡',
      '💚',
      '💙',
      '💜',
      '🖤',
      '💔',
      '💯',
      '🔥',
      '✨',
      '🎉',
      '🎊',
      '🎁',
      '☀️',
      '🌙',
      '⭐',
    ];

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Fp.inkSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Fp.rLg)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Fp.s12),
          child: GridView.count(
            crossAxisCount: 8,
            shrinkWrap: true,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (final e in emojis)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.pop(ctx, e),
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null) return;
    final value = controller.value;
    final selection = value.selection;
    final start = selection.start >= 0 ? selection.start : value.text.length;
    final end = selection.end >= 0 ? selection.end : value.text.length;
    final text = value.text.replaceRange(start, end, chosen);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + chosen.length),
    );
    onChanged?.call(text);
  }

  Widget _action() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final showSend = hasText || textOnly;
        final enabled = hasText && !isLoading;

        if (showSend) {
          return _circle(
            onTap: enabled ? onTapSendMsg : null,
            enabled: enabled,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Image.asset(
                    AppAssets.send,
                    color: Colors.white,
                    height: 22,
                    width: 22,
                  ),
          );
        }

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: onPointerDown,
          onPointerUp: onPointerUp,
          child: _circle(
            enabled: true,
            child: SvgPicture.asset(
              'assets/images/call/microphone-on.svg',
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              height: 22,
              width: 22,
            ),
          ),
        );
      },
    );
  }

  Widget _circle({
    required Widget child,
    VoidCallback? onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Fp.fast,
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled ? Fp.accent : null,
          color: enabled ? null : Fp.inkRaised,
          shape: BoxShape.circle,
          border: enabled ? null : Border.all(color: Fp.hairline),
          boxShadow: enabled ? Fp.glow(Fp.violet) : null,
        ),
        child: enabled ? child : Opacity(opacity: 0.45, child: child),
      ),
    );
  }
}
