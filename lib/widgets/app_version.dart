import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart';

Future<void> getAppVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  debugPrint("😀😀App Name😀😀: ${packageInfo.appName}");
  debugPrint("😀😀Package Name😀😀: ${packageInfo.packageName}");
  debugPrint("😀😀Version😀😀: ${packageInfo.version}");
  debugPrint("😀😀Build Number😀😀: ${packageInfo.buildNumber}");
  await SecurePrefs.setString(
    SecureStorageKeys.APP_VERSION,
    packageInfo.version.toString(),
  );
  String? version = await SecurePrefs.getString(SecureStorageKeys.APP_VERSION);
  appVersion = version.toString();
  debugPrint("😀😀appVersion😀😀:$appVersion");
}
