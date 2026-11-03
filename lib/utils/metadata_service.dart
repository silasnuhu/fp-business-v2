// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/data/models/link_model.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

// class MetadataService {
//   static final Map<String, Future<Metadata>> _futureCache = {};

//   static Future<Metadata> fetchMetadata(String url) {
//     if (_futureCache.containsKey(url)) {
//       debugPrint("🔄 Using in-memory cache for: $url");
//       return _futureCache[url]!;
//     }

//     final future = _fetchAndCache(url);
//     _futureCache[url] = future;
//     return future;
//   }

//   static Future<Metadata> _fetchAndCache(String url) async {
//     final localStorageKey = "metadata_${Uri.encodeComponent(url)}";
//     debugPrint("🌐 Requested URL: $url");
//     debugPrint("🗝 Local Storage Key: $localStorageKey");

//     try {
//       // 1️⃣ Check SecurePrefs cache
//       final cachedData = await SecurePrefs.getString(localStorageKey);
//       if (cachedData != null) {
//         debugPrint("✅ Loaded from SecurePrefs: $cachedData");
//         final jsonData = jsonDecode(cachedData);
//         return Metadata.fromJson(jsonData);
//       }

//       // 2️⃣ API Call
//       final requestUrl =
//           "https://api.microlink.io/?url=${Uri.encodeComponent(url)}";
//       debugPrint("📡 Sending Request: $requestUrl");

//       final response = await http.get(Uri.parse(requestUrl));
//       debugPrint("📥 Response Status: ${response.statusCode}");
//       debugPrint("📥 Response Body: ${response.body}");

//       if (response.statusCode == 200) {
//         final body = jsonDecode(response.body);
//         final data = body['data'] ?? {};

//         debugPrint("📦 Extracted Data: $data");

//         final metadata = Metadata(
//           title: data['title'] ?? '',
//           description: data['description'] ?? '',
//           image: data['image']?['url'] ?? data['logo']?['url'] ?? '',
//           publisher: data['publisher'] ?? '',
//         );

//         // 3️⃣ Save to SecurePrefs
//         await SecurePrefs.setString(
//           localStorageKey,
//           jsonEncode(metadata.toJson()),
//         );
//         debugPrint("💾 Saved to SecurePrefs: ${metadata.toJson()}");

//         return metadata;
//       } else {
//         debugPrint("❌ API Error: ${response.statusCode}");
//         return Metadata(title: '', description: '', image: '', publisher: '');
//       }
//     } catch (e) {
//       debugPrint("🚨 Exception: $e");
//       return Metadata(title: '', description: '', image: '', publisher: '');
//     }
//   }
// }
// below Without third party api/package use and fetch data from url and above commented method is third party api through data fetch
class MetadataService {
  static final Map<String, Future<Metadata>> _futureCache = {};

  static Future<Metadata> fetchMetadata(String url) {
    if (_futureCache.containsKey(url)) {
      debugPrint("🔄 Using in-memory cache for: $url");
      return _futureCache[url]!;
    }

    final future = _fetchAndCache(url);
    _futureCache[url] = future;
    return future;
  }

  static Future<Metadata> _fetchAndCache(String url) async {
    final localStorageKey = "metadata_${Uri.encodeComponent(url)}";
    debugPrint("🌐 Requested URL: $url");
    debugPrint("🗝 Local Storage Key: $localStorageKey");

    try {
      // 1️⃣ Check SecurePrefs cache
      final cachedData = await SecurePrefs.getString(localStorageKey);
      if (cachedData != null) {
        debugPrint("✅ Loaded from SecurePrefs: $cachedData");
        final jsonData = jsonDecode(cachedData);
        return Metadata.fromJson(jsonData);
      }

      // 2️⃣ Fetch HTML directly
      debugPrint("📡 Sending Request (direct HTML fetch)...");
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        debugPrint("❌ HTTP Error: ${response.statusCode}");
        return Metadata(title: '', description: '', image: '', publisher: '');
      }

      final body = await response.transform(utf8.decoder).join();

      // 🔎 Helper to extract meta tags
      String? extractMeta(String name) {
        final match = RegExp(
          '<meta[^>]+(property|name)=["\']$name["\'][^>]+content=["\']([^"\']+)["\']',
          caseSensitive: false,
        ).firstMatch(body);
        return match?.group(2);
      }

      // 3️⃣ Extract metadata with fallbacks
      final title =
          extractMeta("og:title") ??
          extractMeta("twitter:title") ??
          RegExp(
            r'<title>(.*?)</title>',
            caseSensitive: false,
          ).firstMatch(body)?.group(1) ??
          '';

      final description =
          extractMeta("og:description") ??
          extractMeta("twitter:description") ??
          extractMeta("description") ??
          '';

      final image =
          extractMeta("og:image") ?? extractMeta("twitter:image") ?? "";

      final publisher =
          extractMeta("og:site_name") ??
          extractMeta("twitter:site") ??
          Uri.parse(url).host;

      final metadata = Metadata(
        title: title.trim(),
        description: description.trim(),
        image: image.trim(),
        publisher: publisher.trim(),
      );

      // 4️⃣ Save to SecurePrefs
      await SecurePrefs.setString(
        localStorageKey,
        jsonEncode(metadata.toJson()),
      );
      debugPrint("💾 Saved to SecurePrefs: ${metadata.toJson()}");

      return metadata;
    } catch (e) {
      debugPrint("🚨 Exception: $e");
      return Metadata(title: '', description: '', image: '', publisher: '');
    }
  }
}
