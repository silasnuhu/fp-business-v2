import 'dart:convert';

import 'package:crypto/crypto.dart';

/// On-device contact hashing for privacy-preserving discovery.
///
/// Mirrors the server's rules exactly (`src/otp/otp-channel.types.ts:toE164`
/// and `src/contacts/contact-hash.util.ts`): the digest is HMAC-SHA256 over
/// the E.164 string *including the leading `+`*. If these two ever diverge,
/// every contact silently stops matching - so keep the normalisation rules
/// identical when either side changes.
class ContactHash {
  ContactHash._();

  /// Build E.164 from the country code + local number the caller already
  /// parsed. Returns null when the number cannot be made sense of, so callers
  /// skip it instead of uploading a digest that can never match.
  static String? toE164(String? countryCode, String? rawNumber) {
    final digits = (rawNumber ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    var cc = (countryCode ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (cc.startsWith('00')) cc = cc.substring(2);

    // Already international (e.g. number carries +234...).
    if (cc.isNotEmpty && digits.startsWith(cc) && digits.length > cc.length + 5) {
      return '+$digits';
    }
    // Nigerian trunk form 0XXXXXXXXXX with no country code.
    if (cc.isEmpty && digits.startsWith('0') && digits.length == 11) {
      return '+234${digits.substring(1)}';
    }
    if (cc.isNotEmpty && digits.startsWith('0')) {
      return '+$cc${digits.substring(1)}';
    }
    if (cc.isNotEmpty) return '+$cc$digits';
    if (digits.length >= 10) return '+$digits';
    return null;
  }

  static String digest(String e164, String pepper) =>
      Hmac(sha256, utf8.encode(pepper)).convert(utf8.encode(e164)).toString();
}
