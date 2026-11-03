import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:whoxa/featuers/language_method/data/model/lang_list_model.dart';
import 'package:whoxa/featuers/language_method/data/model/word_list_model.dart'
    as word_list;

// NEW has no `language` module at all — confirmed absent from actual
// backend source (no controller anywhere in src/, not just per the
// migration guide's §16). Translations are now bundled with the app as
// static JSON assets (assets/lang/<code>.json) instead of being fetched
// from a server, so the language list and word list below are served
// from those assets rather than from ApiClient/ApiEndpoints.
class LanguageRepository {
  LanguageRepository(Object? apiClient);

  word_list.WordListModel? wordListModel;
  LanguageListModel? languageListModel;

  // Ordered so that LanguagePopUp's `reverse: true` ListView.builder (see
  // lang_popup.dart) renders English first, matching the original design's
  // top-to-bottom order: English, Español, Français, Italiano, العربية.
  static final List<Records> supportedLanguages = [
    Records(
      languageId: 5,
      language: 'العربية',
      languageAlignment: 'RTL',
      country: 'SA',
      status: true,
      defaultStatus: false,
      createdAt: '',
      updatedAt: '',
    ),
    Records(
      languageId: 4,
      language: 'Italiano',
      languageAlignment: 'LTR',
      country: 'IT',
      status: true,
      defaultStatus: false,
      createdAt: '',
      updatedAt: '',
    ),
    Records(
      languageId: 3,
      language: 'Français',
      languageAlignment: 'LTR',
      country: 'FR',
      status: true,
      defaultStatus: false,
      createdAt: '',
      updatedAt: '',
    ),
    Records(
      languageId: 2,
      language: 'Español',
      languageAlignment: 'LTR',
      country: 'ES',
      status: true,
      defaultStatus: false,
      createdAt: '',
      updatedAt: '',
    ),
    Records(
      languageId: 1,
      language: 'English',
      languageAlignment: 'LTR',
      country: 'US',
      status: true,
      defaultStatus: true,
      createdAt: '',
      updatedAt: '',
    ),
  ];

  static const Map<int, String> _assetCodeByLanguageId = {
    1: 'en',
    2: 'es',
    3: 'fr',
    4: 'it',
    5: 'ar',
  };

  Future<LanguageListModel> langListRepo() async {
    return languageListModel = LanguageListModel(
      status: true,
      data: Data(records: supportedLanguages),
      message: 'Loaded from bundled static language list',
      toast: false,
    );
  }

  Future<word_list.WordListModel> wordListRepo({
    required String languageId,
  }) async {
    final assetCode =
        _assetCodeByLanguageId[int.tryParse(languageId) ?? -1] ?? 'en';

    try {
      final raw = await rootBundle.loadString('assets/lang/$assetCode.json');
      final Map<String, dynamic> decoded = jsonDecode(raw);

      final records = <word_list.Records>[];
      var keyId = 0;
      decoded.forEach((key, value) {
        keyId++;
        records.add(
          word_list.Records(
            keyId: keyId,
            key: key,
            translation: value?.toString(),
          ),
        );
      });

      return wordListModel = word_list.WordListModel(
        status: true,
        data: word_list.Data(records: records),
        message: 'Loaded from bundled static translations',
        toast: false,
      );
    } catch (_) {
      return wordListModel = word_list.WordListModel(
        status: true,
        data: word_list.Data(records: const []),
        message: 'No bundled translations for this language',
        toast: false,
      );
    }
  }
}
