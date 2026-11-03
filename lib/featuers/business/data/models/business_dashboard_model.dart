/// `GET /business/dashboard?days=7|30|90`.
///
/// `totals` is "right now"; `period` and [messagesByDay] cover the last
/// [periodDays] calendar days (today included), zero-filled, oldest first.
/// Only the business's own direct chats are counted.
class BusinessDashboard {
  final int periodDays;
  final int chats;
  final int unreadChats;
  final int catalogItems;
  final int labels;
  final int newChats;
  final int messagesReceived;

  /// Includes auto replies; [greetingsSent] + [awaysSent] say how many of
  /// those were automatic.
  final int messagesSent;
  final int greetingsSent;
  final int awaysSent;

  /// Views of the business's catalog items in the period (each viewer counts
  /// once per item per day; the owner's own opens don't count).
  final int catalogViews;
  final List<DashboardCatalogItem> topCatalogItems;
  final List<DashboardDay> messagesByDay;
  final List<DashboardLabel> topLabels;

  const BusinessDashboard({
    this.periodDays = 7,
    this.chats = 0,
    this.unreadChats = 0,
    this.catalogItems = 0,
    this.labels = 0,
    this.newChats = 0,
    this.messagesReceived = 0,
    this.messagesSent = 0,
    this.greetingsSent = 0,
    this.awaysSent = 0,
    this.catalogViews = 0,
    this.topCatalogItems = const [],
    this.messagesByDay = const [],
    this.topLabels = const [],
  });

  static int _i(dynamic v) => int.tryParse('$v') ?? 0;

  factory BusinessDashboard.fromJson(Map<String, dynamic> json) {
    final totals = (json['totals'] as Map?) ?? const {};
    final period = (json['period'] as Map?) ?? const {};
    final auto = (period['auto_replies_sent'] as Map?) ?? const {};
    final days = json['messages_by_day'];
    final labels = json['top_labels'];
    final items = json['top_catalog_items'];
    return BusinessDashboard(
      periodDays: _i(json['period_days']),
      chats: _i(totals['chats']),
      unreadChats: _i(totals['unread_chats']),
      catalogItems: _i(totals['catalog_items']),
      labels: _i(totals['labels']),
      newChats: _i(period['new_chats']),
      messagesReceived: _i(period['messages_received']),
      messagesSent: _i(period['messages_sent']),
      greetingsSent: _i(auto['greeting']),
      awaysSent: _i(auto['away']),
      catalogViews: _i(period['catalog_views']),
      topCatalogItems:
          items is List
              ? items
                  .whereType<Map>()
                  .map(
                    (e) => DashboardCatalogItem.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList()
              : const [],
      messagesByDay:
          days is List
              ? days
                  .whereType<Map>()
                  .map((e) => DashboardDay.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : const [],
      topLabels:
          labels is List
              ? labels
                  .whereType<Map>()
                  .map((e) => DashboardLabel.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : const [],
    );
  }
}

class DashboardDay {
  final String date;
  final int received;
  final int sent;

  const DashboardDay({
    required this.date,
    required this.received,
    required this.sent,
  });

  factory DashboardDay.fromJson(Map<String, dynamic> json) => DashboardDay(
    date: (json['date'] ?? '').toString(),
    received: int.tryParse('${json['received']}') ?? 0,
    sent: int.tryParse('${json['sent']}') ?? 0,
  );
}

class DashboardLabel {
  final int labelId;
  final String labelText;
  final String labelColor;
  final int chats;

  const DashboardLabel({
    required this.labelId,
    required this.labelText,
    required this.labelColor,
    required this.chats,
  });

  factory DashboardLabel.fromJson(Map<String, dynamic> json) => DashboardLabel(
    labelId: int.tryParse('${json['label_id']}') ?? 0,
    labelText: (json['label_text'] ?? '').toString(),
    labelColor: (json['label_color'] ?? '#888888').toString(),
    chats: int.tryParse('${json['chats']}') ?? 0,
  );
}

/// One of the up-to-5 most viewed catalog items.
class DashboardCatalogItem {
  final int catalogId;
  final String title;
  final int views;

  const DashboardCatalogItem({
    required this.catalogId,
    required this.title,
    required this.views,
  });

  // The item payload's exact key names aren't pinned down in the API notes,
  // so the count is read from the likely spellings.
  factory DashboardCatalogItem.fromJson(Map<String, dynamic> json) =>
      DashboardCatalogItem(
        catalogId: int.tryParse('${json['catalog_id']}') ?? 0,
        title: (json['title'] ?? '').toString(),
        views:
            int.tryParse(
              '${json['views'] ?? json['view_count'] ?? json['total_views'] ?? json['count'] ?? 0}',
            ) ??
            0,
      );
}
