// ✅ Core Services
import 'package:dio/dio.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/network/network_listner.dart';
import 'package:whoxa/dependency_injection.dart';
import 'package:whoxa/featuers/auth/data/repositories/login_repository.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/utils/network_info.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

final authRepo = getIt<LoginRepository>();

final authProvider = getIt<AuthProvider>();
final themeProvider = getIt<ThemeProvider>();

final dio = getIt<Dio>();
final networkInfo = getIt<NetworkInfo>();
final apiClient = getIt<ApiClient>();
final securePrefs = getIt<SecurePrefs>();
final networkListener = getIt<NetworkListener>();
