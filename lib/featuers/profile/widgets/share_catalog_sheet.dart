import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/repository/message_repository.dart';
import 'package:whoxa/utils/enums.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

/// Lets the business share a catalog product into one of its chats.
///
/// There is no dedicated message type: it goes out as a normal `text` message
/// whose `body` is a readable fallback and whose `metadata.catalog` is a
/// snapshot of the product (the web app sends the same shape), so apps that
/// don't know the card still show something sensible.
Future<void> showShareCatalogSheet(BuildContext context, Catalog catalog) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
    builder: (_) => _ShareCatalogSheet(catalog: catalog),
  );
}

class _ShareCatalogSheet extends StatefulWidget {
  final Catalog catalog;
  const _ShareCatalogSheet({required this.catalog});

  @override
  State<_ShareCatalogSheet> createState() => _ShareCatalogSheetState();
}

class _ShareCatalogSheetState extends State<_ShareCatalogSheet> {
  final MessageRepository _messages = MessageRepository(
    GetIt.instance<ApiClient>(),
  );
  int? _sendingTo;

  Map<String, dynamic> _snapshot() {
    final c = widget.catalog;
    return {
      'catalog_id': c.catalogId,
      'title': c.title ?? '',
      'price': c.price,
      'description': c.description ?? '',
      'category_name': c.categoryName ?? '',
      'country_of_origin': c.countryOfOrigin ?? '',
      // Snapshot images are plain URLs.
      'images':
          (c.catalogImages ?? [])
              .map((i) => i.image ?? '')
              .where((u) => u.isNotEmpty)
              .toList(),
    };
  }

  String _fallbackBody() {
    final c = widget.catalog;
    final lines = <String>[
      '🛍️ ${c.title ?? ''}',
      if (c.price != null) '${c.price}',
      if ((c.description ?? '').isNotEmpty) c.description!,
    ];
    return lines.join('\n');
  }

  Future<void> _send(int conversationId) async {
    setState(() => _sendingTo = conversationId);
    try {
      await _messages.sendMessage(
        conversationId: conversationId,
        messageType: MessageType.Text,
        messageContent: _fallbackBody(),
        metadata: {'catalog': _snapshot()},
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product sent')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingTo = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is AppError ? e.message : 'Failed to send product'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chats =
        context
            .read<ChatProvider>()
            .chatListData
            .chats
            .where((c) => c.records?.isNotEmpty == true)
            .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Send product to…',
                style: AppTypography.h5(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppThemeManage.appTheme.textColor,
                ),
              ),
            ),
            if (chats.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No chats yet'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: chats.length,
                  itemBuilder: (context, i) {
                    final chat = chats[i];
                    final record = chat.records!.first;
                    final chatId = record.chatId ?? 0;
                    final isGroup = record.chatType == 'group';
                    final name =
                        isGroup
                            ? (record.groupName ?? 'Group')
                            : (chat.peerUserData?.fullName?.isNotEmpty == true
                                ? chat.peerUserData!.fullName!
                                : chat.peerUserData?.userName ?? 'Chat');
                    return ListTile(
                      title: Text(name),
                      trailing:
                          _sendingTo == chatId
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                              : const Icon(Icons.send_outlined, size: 18),
                      enabled: _sendingTo == null && chatId > 0,
                      onTap: () => _send(chatId),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
