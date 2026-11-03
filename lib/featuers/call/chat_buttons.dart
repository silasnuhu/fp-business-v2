import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/call/call_model.dart';
import 'package:whoxa/featuers/call/call_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';

/// WhatsApp-style call control: ONE call icon with a small chevron that opens
/// the audio/video choice, instead of two icons eating header width.
class ChatCallButtons extends StatelessWidget {
  final int chatId;
  final String chatName;
  final String? profilePic;
  final int? userId; // Fallback when chatId is 0 (no existing chat)

  const ChatCallButtons({
    super.key,
    required this.chatId,
    required this.chatName,
    this.profilePic,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, provider, child) {
        if (provider.isInCall) return const SizedBox.shrink();

        return PopupMenuButton<CallType>(
          tooltip: 'Call',
          offset: const Offset(0, 42),
          color: Fp.inkRaised,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Fp.hairline),
          ),
          onSelected: (type) => _makeCall(context, type),
          itemBuilder: (context) => [
            _item(CallType.audio, Icons.call_outlined, 'Audio call'),
            _item(CallType.video, Icons.videocam_outlined, 'Video call'),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  AppAssets.bottomNavIcons.call1,
                  height: SizeConfig.sizedBoxHeight(20),
                  colorFilter: ColorFilter.mode(Fp.text, BlendMode.srcIn),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Fp.text,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<CallType> _item(CallType type, IconData icon, String label) {
    return PopupMenuItem<CallType>(
      value: type,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 19, color: Fp.text),
          const SizedBox(width: 10),
          Text(label, style: Fp.bodyStrong.copyWith(fontSize: 14)),
        ],
      ),
    );
  }

  void _makeCall(BuildContext context, CallType callType) {
    final peerId = userId ?? 0;
    debugPrint(
      '📞 ChatCallButtons._makeCall: chatId=$chatId, userId=$userId, peerId=$peerId',
    );

    if (peerId <= 0 && chatId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot start a call without a contact')),
      );
      return;
    }

    final provider = Provider.of<CallProvider>(context, listen: false);
    // chatId 0 + peerId is the "no conversation yet" case; CallProvider and
    // the manager create the conversation for it.
    provider.makeCall(
      chatId: chatId,
      callType: callType,
      chatName: chatName,
      peerId: peerId > 0 ? peerId : null,
    );
  }
}
