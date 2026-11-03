import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/contacts/data/model/get_contact_model.dart';
import 'package:whoxa/featuers/contacts/data/contact_hash.dart';

class ContactRepo {
  final ApiClient _apiClient;

  ContactRepo(this._apiClient);

  GetContactModel contactModel = GetContactModel();

  // NEW merges create/update into one upsert-only `/contacts/sync`:
  // `contact_details` -> `contacts`, and each entry's `number` -> `phoneNumber`
  // (§4.4). `name` is still accepted but NEW silently discards it — never
  // stored, never returned. Response is "summary counts, not full list"
  // (§4.5); exact field names aren't given verbatim by the guide, so
  // GetContactModel.fromJson only relies on a `status`/`success` signal.
  Future<GetContactModel> contactGet(List<Map<String, dynamic>> contact) async {
    try {
      // Verified against actual backend DTO (SyncContactsDto/ContactEntryDto,
      // src/contacts/dto/sync-contacts.dto.ts): each entry only accepts
      // `name` (optional) and `phoneNumber` (required). Callers also pass a
      // `country_code` key (see ContactProvider's contactsForApi) which
      // isn't part of the DTO at all — the global ValidationPipe's
      // whitelist/forbidNonWhitelisted applies to this nested array too, so
      // leaving it in would 400 the entire sync. Build a clean entry
      // instead of just renaming `number`.
      final renamed =
          contact
              .map(
                (c) => {
                  if (c['name'] != null) 'name': c['name'],
                  'phoneNumber': c['number'],
                },
              )
              .toList();

      final response = await _apiClient.request(
        ApiEndpoints.userCreateContact,
        method: "POST",
        body: {'contacts': renamed},
      );

      contactModel = GetContactModel.fromJson(response);

      return contactModel;
    } catch (e) {
      rethrow;
    }
  }

  Future<GetContactModel> getContacts() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.getContacts,
        method: "GET",
      );

      final contactModel = GetContactModel.fromJson(response);
      return contactModel;
    } catch (e) {
      rethrow;
    }
  }

  // NEW's GET /contacts returns {items, total, limit, offset} — a bare
  // object, not the old {status, data} envelope — with `name` now meaning
  // the matched app user's own name (the locally-synced address-book name
  // is never stored server-side anymore, see `contactGet` above). The
  // per-item field names beyond `items` aren't given verbatim by the guide;
  // ContactDetails.fromJson below is best-effort, matching the curated user
  // fields confirmed elsewhere (verify-OTP, §3.5) — verify against a live
  // response before relying on this beyond display purposes.
  //
  // PAGINATION: the backend defaults to `limit = 20` (QueryContactsDto,
  // src/contacts/dto/query-contacts.dto.ts) and this endpoint has no
  // "return everything" mode — a single un-paged call silently drops every
  // registered contact past the 20th (ordered by the peer's fullName asc),
  // which is why a contact who sorts late can be completely absent on one
  // device while present on the other. Loop `offset` in `limit`-sized pages
  // (backend caps `limit` at 100) until we've pulled `total` rows.
  Future<List<ContactDetails>> getContactsList() async {
    const int pageSize = 100; // backend @Max(100)
    const int safetyPageCap = 100; // hard stop: 10k contacts

    try {
      final all = <ContactDetails>[];
      var offset = 0;

      for (var page = 0; page < safetyPageCap; page++) {
        final response = await _apiClient.request(
          '${ApiEndpoints.getContacts}?limit=$pageSize&offset=$offset',
          method: "GET",
        );

        if (response is! Map<String, dynamic>) break;

        final items = response['items'];
        if (items is! List || items.isEmpty) break;

        all.addAll(
          items
              .whereType<Map<String, dynamic>>()
              .map((contact) => ContactDetails.fromJson(contact)),
        );

        final total = response['total'];
        offset += pageSize;

        if (items.length < pageSize) break;
        if (total is int && offset >= total) break;
      }

      return all;
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------- discovery
  String? _pepper;
  bool? _discoverEnabled;

  /// Fetch (once) the hashing parameters. When the server has no pepper
  /// configured this returns false and callers fall back to the legacy
  /// plaintext sync, so an un-migrated backend never breaks the app.
  Future<bool> _loadDiscoverConfig() async {
    if (_discoverEnabled != null) return _discoverEnabled!;
    try {
      final res = await _apiClient.request(
        ApiEndpoints.contactsDiscoverConfig,
        method: "GET",
      );
      final map = res is Map<String, dynamic> ? res : <String, dynamic>{};
      _pepper = (map['pepper'] as String?)?.trim();
      _discoverEnabled = map['enabled'] == true && (_pepper ?? '').isNotEmpty;
    } catch (_) {
      _discoverEnabled = false;
    }
    return _discoverEnabled!;
  }

  /// Hash-only address-book sync. The server matches the digests against
  /// registered numbers and writes the same contact_list rows the plaintext
  /// endpoint did, so `GET /contacts` is unchanged.
  Future<GetContactModel> discoverContacts(
    List<Map<String, dynamic>> contacts,
  ) async {
    if (!await _loadDiscoverConfig()) {
      return contactGet(contacts);
    }

    final entries = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final c in contacts) {
      final e164 = ContactHash.toE164(
        c['country_code'] as String?,
        c['number'] as String?,
      );
      if (e164 == null) continue;
      final hash = ContactHash.digest(e164, _pepper!);
      if (!seen.add(hash)) continue;
      final name = (c['name'] as String?)?.trim() ?? '';
      entries.add({
        'hash': hash,
        if (name.isNotEmpty) 'name': name,
      });
    }
    if (entries.isEmpty) return GetContactModel(status: true);

    final response = await _apiClient.request(
      ApiEndpoints.contactsDiscover,
      method: "POST",
      body: {'contacts': entries},
    );
    contactModel = GetContactModel.fromJson(response);
    return contactModel;
  }
}
