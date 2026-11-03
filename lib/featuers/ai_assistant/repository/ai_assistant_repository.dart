import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/chat/data/conversation_dto.dart';

/// `GET /ai-assistant/config`. [enabled] is false when the backend has no AI
/// provider key configured — the entry point must be hidden then.
class AiAssistantConfig {
  final bool enabled;
  final String? provider;
  final String? model;

  const AiAssistantConfig({required this.enabled, this.provider, this.model});

  factory AiAssistantConfig.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    final data = map['data'] is Map<String, dynamic> ? map['data'] : map;
    return AiAssistantConfig(
      enabled: data['enabled'] == true,
      provider: data['provider']?.toString(),
      model: data['model']?.toString(),
    );
  }
}

// REST client for the two AI-specific endpoints. Everything else about the
// AI chat (history, sending) goes through the normal `/messages` endpoints.
class AiAssistantRepository {
  final ApiClient _apiClient;

  AiAssistantRepository(this._apiClient);

  Future<AiAssistantConfig> getConfig() async {
    final response = await _apiClient.request(
      '${ApiEndpoints.aiAssistant}/config',
      method: 'GET',
    );
    return AiAssistantConfig.fromJson(response);
  }

  /// Get-or-create: the first call ever creates the 1:1 conversation with the
  /// bot and seeds it; every later call returns that same conversation.
  Future<ConversationDto?> getChat() async {
    final response = await _apiClient.request(
      '${ApiEndpoints.aiAssistant}/chat',
      method: 'GET',
    );
    if (response is! Map<String, dynamic>) return null;
    final data = response['data'];
    return ConversationDto.fromJson(
      data is Map<String, dynamic> ? data : response,
    );
  }
}
