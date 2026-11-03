import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/featuers/ai_assistant/provider/ai_assistant_provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/widgets/global.dart';

/// Home-screen entry point to the AI Assistant chat. Hidden while the
/// backend reports the feature as disabled.
class AiAssistantFab extends StatelessWidget {
  const AiAssistantFab({super.key});

  Future<void> _open(BuildContext context) async {
    final aiProvider = context.read<AiAssistantProvider>();
    final chatProvider = context.read<ChatProvider>();

    final target = await aiProvider.openChat(chatProvider);
    // The flag can flip server-side at any time; refresh it for next time.
    unawaited(aiProvider.loadConfig());
    if (!context.mounted) return;

    if (target == null) {
      snackbarNew(
        context,
        msg: 'Could not open AI Assistant. Please try again.',
      );
      return;
    }

    toUserProfileCall = '';
    NavigationHelper.navigateToChat(
      context,
      chatId: target.chatId,
      userId: target.botUserId,
      fullName: AiAssistantProvider.botDisplayName,
      profilePic: '',
      unseenCount: target.unseenCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.appPriSecColor.primaryColor;
    final iconColor = ThemeColorPalette.getTextColor(primary);

    return Consumer<AiAssistantProvider>(
      builder: (context, aiProvider, _) {
        if (!aiProvider.isEnabled) return const SizedBox.shrink();

        return FloatingActionButton(
          heroTag: 'ai_assistant_fab',
          tooltip: AiAssistantProvider.botDisplayName,
          backgroundColor: primary,
          shape: const CircleBorder(),
          onPressed: aiProvider.isOpening ? null : () => _open(context),
          child:
              aiProvider.isOpening
                  ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: iconColor,
                    ),
                  )
                  : SvgPicture.asset(
                    AppAssets.aiIcon,
                    height: 28,
                    width: 28,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                  ),
        );
      },
    );
  }
}
