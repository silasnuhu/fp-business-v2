import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/chat/data/models/label_model.dart';
import 'package:whoxa/utils/logger.dart';

/// `/chat-labels` (BUSINESS_CATALOG_LABELS_API §5). A chat holds at most 3
/// labels per user; assigning a 4th fails with 400.
class LabelRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'LabelRepository',
  );

  LabelRepository(this._apiClient);

  ChatLabel _label(dynamic response) {
    final data = response is Map ? response['data'] : null;
    return ChatLabel.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  /// `GET /chat-labels` — non-deleted, ordered by `label_id` ascending.
  Future<List<ChatLabel>> getLabels() async {
    final response = await _apiClient.request(
      ApiEndpoints.chatLabels,
      method: 'GET',
    );
    final data = response is Map ? response['data'] : null;
    final records = data is Map ? data['Records'] : null;
    if (records is! List) return [];
    return records
        .whereType<Map>()
        .map((e) => ChatLabel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `GET /chat-labels/colors` — the backend's suggested palette (12 colours,
  /// name + hex). `label_color` itself is still a free string, so this is only
  /// a suggestion. Returns hex strings; empty if the payload has none.
  Future<List<String>> getColors() async {
    final response = await _apiClient.request(
      '${ApiEndpoints.chatLabels}/colors',
      method: 'GET',
    );
    var data = response is Map ? response['data'] : response;
    if (data is Map) data = data['Records'] ?? data['colors'] ?? data['Colors'];
    if (data is! List) return [];

    final hexes = <String>[];
    for (final item in data) {
      final raw =
          item is Map
              ? (item['hex'] ?? item['color'] ?? item['value'])
              : item;
      final hex = raw?.toString().trim() ?? '';
      if (RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$').hasMatch(hex)) {
        hexes.add(hex);
      }
    }
    return hexes;
  }

  Future<ChatLabel> addLabel({
    required String labelText,
    required String labelColor,
  }) async {
    final response = await _apiClient.request(
      ApiEndpoints.chatLabels,
      method: 'POST',
      body: {'label_color': labelColor, 'label_text': labelText},
    );
    return _label(response);
  }

  /// `PATCH /chat-labels/:id` — any of label_text, label_color, status.
  Future<ChatLabel> updateLabel({
    required int labelId,
    String? labelText,
    String? labelColor,
    bool? status,
  }) async {
    final response = await _apiClient.request(
      '${ApiEndpoints.chatLabels}/$labelId',
      method: 'PATCH',
      body: {
        if (labelText != null) 'label_text': labelText,
        if (labelColor != null) 'label_color': labelColor,
        if (status != null) 'status': status,
      },
    );
    return _label(response);
  }

  /// Soft delete; the server also removes the label from every chat.
  Future<void> deleteLabel(int labelId) async {
    await _apiClient.request(
      '${ApiEndpoints.chatLabels}/$labelId',
      method: 'DELETE',
    );
  }

  /// Puts the label in the first free slot of the chat.
  /// 409 if already on the chat, 400 if all 3 slots are used.
  Future<void> assignLabel({
    required int labelId,
    required int conversationId,
  }) async {
    _logger.i('Assign label $labelId -> conversation $conversationId');
    await _apiClient.request(
      '${ApiEndpoints.chatLabels}/$labelId/assign',
      method: 'POST',
      body: {'conversation_id': conversationId},
    );
  }

  /// No-op server-side when the label isn't on the chat.
  Future<void> unassignLabel({
    required int labelId,
    required int conversationId,
  }) async {
    _logger.i('Unassign label $labelId <- conversation $conversationId');
    await _apiClient.request(
      '${ApiEndpoints.chatLabels}/$labelId/unassign',
      method: 'POST',
      body: {'conversation_id': conversationId},
    );
  }

  /// Diffs [currentLabels] against [newLabels] and issues the matching
  /// unassign/assign calls (unassign first so a full chat can be re-labelled).
  Future<void> updateChatLabels({
    required int conversationId,
    required List<int> currentLabels,
    required List<int> newLabels,
  }) async {
    final toRemove = currentLabels.where((id) => !newLabels.contains(id));
    final toAdd = newLabels.where((id) => !currentLabels.contains(id));

    for (final id in toRemove) {
      await unassignLabel(labelId: id, conversationId: conversationId);
    }
    for (final id in toAdd) {
      await assignLabel(labelId: id, conversationId: conversationId);
    }
  }
}
