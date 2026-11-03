/// `GET/POST /business/auto-replies` — settings for the messages the SERVER
/// sends on the business's behalf (greeting / away). The app only edits them.
class AutoReplies {
  final bool greetingEnabled;
  final String greetingMessage;
  final bool awayEnabled;
  final String awayMessage;

  /// `outside_hours` (default) or `always`.
  final String awayMode;

  const AutoReplies({
    this.greetingEnabled = false,
    this.greetingMessage = '',
    this.awayEnabled = false,
    this.awayMessage = '',
    this.awayMode = modeOutsideHours,
  });

  static const String modeOutsideHours = 'outside_hours';
  static const String modeAlways = 'always';

  factory AutoReplies.fromJson(Map<String, dynamic> json) {
    return AutoReplies(
      greetingEnabled: json['greeting_enabled'] == true,
      greetingMessage: (json['greeting_message'] ?? '').toString(),
      awayEnabled: json['away_enabled'] == true,
      awayMessage: (json['away_message'] ?? '').toString(),
      awayMode: (json['away_mode'] ?? modeOutsideHours).toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'greeting_enabled': greetingEnabled,
    'greeting_message': greetingMessage,
    'away_enabled': awayEnabled,
    'away_message': awayMessage,
    'away_mode': awayMode,
  };
}
