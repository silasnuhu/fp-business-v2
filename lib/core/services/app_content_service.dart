import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/dependency_injection.dart';

/// Admin-managed app copy and switches, fetched from `GET /app/content`.
///
/// Everything here has a hard-coded fallback: if the request fails (offline,
/// cold start, API hiccup) the app must render sensible text rather than a
/// blank greeting or a broken membership gate.
class AppContentService {
  AppContentService._();
  static final AppContentService instance = AppContentService._();

  bool greetingEnabled = true;
  bool membershipEnabled = true;
  String _morning = 'Good morning, {{name}}';
  String _afternoon = 'Good afternoon, {{name}}';
  String _evening = 'Good evening, {{name}}';

  bool _loaded = false;
  DateTime? _fetchedAt;

  /// Refetch at most every 5 minutes unless [force] is set.
  bool get needsRefresh =>
      !_loaded ||
      _fetchedAt == null ||
      DateTime.now().difference(_fetchedAt!) > const Duration(minutes: 5);

  Future<void> load({bool force = false}) async {
    if (!force && !needsRefresh) return;
    try {
      final res = await getIt<ApiClient>().request('/app/content');
      dynamic node = res;
      if (node is Map && node['data'] != null) node = node['data'];
      if (node is Map) {
        final greeting = node['greeting'];
        if (greeting is Map) {
          greetingEnabled = greeting['enabled'] != false;
          _morning = (greeting['morning'] ?? _morning).toString();
          _afternoon = (greeting['afternoon'] ?? _afternoon).toString();
          _evening = (greeting['evening'] ?? _evening).toString();
        }
        final membership = node['membership'];
        if (membership is Map) {
          membershipEnabled = membership['enabled'] != false;
        }
      }
      _loaded = true;
      _fetchedAt = DateTime.now();
    } catch (_) {
      // Keep whatever we have (defaults on first run) — never block the UI.
    }
  }

  /// Time-of-day greeting with the user's first name substituted.
  /// Returns null when the admin has switched the greeting off, so callers can
  /// fall back to their previous copy.
  String? greetingFor(String? fullName, {DateTime? now}) {
    if (!greetingEnabled) return null;
    final hour = (now ?? DateTime.now()).hour;
    final template = hour < 12
        ? _morning
        : (hour < 17 ? _afternoon : _evening);
    final first = (fullName ?? '').trim().split(RegExp(r'\s+')).first;
    final name = first.isEmpty ? 'there' : first;
    return template.replaceAll(RegExp(r'\{\{\s*name\s*\}\}'), name);
  }
}
