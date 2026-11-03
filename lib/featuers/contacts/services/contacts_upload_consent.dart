import 'package:flutter/material.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

/// Apple Guideline 5.1.2: the user must be told their contacts are uploaded
/// to our server, and how they're used, and must consent before any upload.
class ContactsUploadConsent {
  static const String _key = 'CONTACTS_UPLOAD_CONSENT';

  static Future<bool> hasConsent() => SecurePrefs.getBool(_key);

  /// Returns true if the user has consented (asks if not yet asked).
  static Future<bool> ensure([BuildContext? context]) async {
    if (await hasConsent()) return true;

    final ctx = context ?? NavigationHelper.context;
    if (ctx == null || !ctx.mounted) return false;

    final agreed = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Upload your contacts?'),
            content: const Text(
              'To show which of your contacts already use Whoxa Business, '
              'the names and phone numbers in your address book will be '
              'uploaded to our servers. They are used only to find and '
              'connect you with your contacts and to let you invite others. '
              'They are not sold or used for advertising.\n\n'
              'You can change this later in your device Settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("Don't Allow"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Agree & Continue'),
              ),
            ],
          ),
    );

    if (agreed == true) {
      await SecurePrefs.setBool(_key, true);
      return true;
    }
    return false;
  }
}
