/// A private, per-user chat tag (`/chat-labels`, BUSINESS_CATALOG_LABELS_API §5).
///
/// `label_id` is a plain number here, whereas the conversation payload's
/// `participants[].labelIds` carries the same ids as strings — convert before
/// comparing.
class ChatLabel {
  final int? labelId;
  final String? labelText;
  final String? labelColor;
  final bool? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatLabel({
    this.labelId,
    this.labelText,
    this.labelColor,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatLabel.fromJson(Map<String, dynamic> json) {
    return ChatLabel(
      labelId: int.tryParse('${json['label_id']}'),
      labelText: json['label_text'] as String?,
      labelColor: json['label_color'] as String?,
      status: json['status'] as bool?,
      createdAt: DateTime.tryParse('${json['created_at']}'),
      updatedAt: DateTime.tryParse('${json['updated_at']}'),
    );
  }

  ChatLabel copyWith({
    int? labelId,
    String? labelText,
    String? labelColor,
    bool? status,
  }) {
    return ChatLabel(
      labelId: labelId ?? this.labelId,
      labelText: labelText ?? this.labelText,
      labelColor: labelColor ?? this.labelColor,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
