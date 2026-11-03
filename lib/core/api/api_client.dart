// *****************************************************************************************
// * Filename: api_client.dart                                                             *
// * Developer: Deval Joshi                                                                *
// * Date: 11 October 2024                                                                 *                      *
// * Description: This file contains the ApiClient class, responsible for making HTTP      *
// * requests (GET, POST, PUT, DELETE). It includes error handling for network issues,     *
// * server errors, and invalid responses, while logging each request and response.        *
// *****************************************************************************************

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/network_info.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart';

class ApiClient {
  final Dio _dio;
  final NetworkInfo _networkInfo;
  final _logger = ConsoleAppLogger.forModule('ApiClient');

  ApiClient(this._dio, this._networkInfo) {
    _initializeDio();
  }

  Future<void> _initializeDio() async {
    _dio.options.baseUrl = ApiEndpoints.baseUrl;

    // Set up headers with bearer token authentication
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // A hung request previously had no client-side cutoff at all (Dio's
    // default is no timeout), which could leave a loading spinner stuck
    // indefinitely on a flaky connection instead of failing fast into the
    // existing retry/error UI.
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    // Generous enough to cover chat media (image/video/voice) uploads via
    // multipartRequest(), which shares this same Dio instance.
    _dio.options.sendTimeout = const Duration(seconds: 60);

    // Dio's default validateStatus already accepts any 2xx as success, so
    // the NEW backend's 201-on-POST (vs OLD's 200) needs no change here —
    // only callers that were comparing a body-level `status`/HTTP code to
    // the literal value 200 need updating, per-endpoint, in later phases.

    // Add logging interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // ✅ `authToken` is the in-memory mirror of SecureStorageKeys.TOKEN
          // (kept in sync at login/logout/startup-load — see global.dart and
          // AuthProvider), so this no longer costs a Keychain/Keystore round
          // trip on every single API call.
          if (authToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $authToken';
          }

          _logger.i('API Request: ${options.method} ${options.path}');
          _logger.d('Headers: ${options.headers}');
          _logger.d('Data: ${options.data}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d('Response status: ${response.statusCode}');
          _logger.d('Response data: ${response.data}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          _logger.e('Request error: ${e.message}', e);
          return handler.next(e);
        },
      ),
    );
  }

  Future<dynamic> request(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (!await _networkInfo.isConnected) {
      _logger.e('No internet connection');

      throw AppError('No internet connection', isNetworkError: true);
    }

    try {
      late Response response;

      // NEW runs on Fastify, whose built-in application/json parser rejects a
      // request that carries `Content-Type: application/json` (set globally
      // above) but an empty payload — `FST_ERR_CTP_EMPTY_JSON_BODY`
      // ("Body cannot be empty when content-type is set to
      // 'application/json'"). Several NEW endpoints legitimately take no body
      // (POST /calls/:id/answer|decline|leave, PATCH archive/unarchive, …),
      // so for body-carrying verbs default a missing body to `{}`, which
      // serializes to valid, non-empty JSON the parser accepts.
      final bodyForSend = body ?? <String, dynamic>{};

      switch (method) {
        case 'GET':
          _logger.d('Sending GET request to $endpoint');
          response = await _dio.get(endpoint, data: body);
          break;
        case 'POST':
          _logger.d(
            'Sending POST request to $endpoint with body: $bodyForSend',
          );
          response = await _dio.post(endpoint, data: bodyForSend);
          break;
        case 'PUT':
          _logger.d('Sending PUT request to $endpoint with body: $bodyForSend');
          response = await _dio.put(endpoint, data: bodyForSend);
          break;
        case 'PATCH':
          // NEW uses PATCH heavily (conversations, archive/unarchive,
          // messages, etc.) — OLD never needed this verb, so it was never
          // wired here before.
          _logger.d(
            'Sending PATCH request to $endpoint with body: $bodyForSend',
          );
          response = await _dio.patch(endpoint, data: bodyForSend);
          break;
        case 'DELETE':
          // Like POST/PUT/PATCH above, NEW has bodyless DELETEs (e.g.
          // DELETE /users/:id/block) that Fastify's json parser rejects with
          // FST_ERR_CTP_EMPTY_JSON_BODY unless a non-empty payload is sent.
          _logger.d(
            'Sending DELETE request to $endpoint with body: $bodyForSend',
          );
          response = await _dio.delete(endpoint, data: bodyForSend);
          break;
        default:
          _logger.e('Unsupported HTTP method: $method');
          throw AppError('Unsupported HTTP method', isNetworkError: true);
      }

      _logger.i('Request successful');
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    } catch (e) {
      _logger.e('Request failed', e);
      throw AppError('Request failed: $e', isNetworkError: true);
    }
  }

  // Future<dynamic> multipartRequest(
  //   String endpoint, {
  //   required Map<String, dynamic> body,
  //   required Map<String, String> files,
  // }) async {
  //   if (!await _networkInfo.isConnected) {
  //     _logger.e('No internet connection');
  //     throw AppError('No internet connection');
  //   }

  //   try {
  //     FormData formData = FormData.fromMap(body);
  //     for (var entry in files.entries) {
  //       String fileName = entry.value.split('/').last;
  //       formData.files.add(
  //         MapEntry(
  //           entry.key,
  //           await MultipartFile.fromFile(entry.value, filename: fileName),
  //         ),
  //       );
  //     }

  //     _logger.d('Sending multipart request to $endpoint');
  //     Response response = await _dio.post(endpoint, data: formData);
  //     _logger.i('Multipart request successful');
  //     return response.data;
  //   } on DioException catch (e) {
  //     _handleDioException(e);
  //   } catch (e) {
  //     _logger.e('Multipart request failed', e);
  //     throw AppError('Multipart request failed: $e');
  //   }
  // }

  Future<dynamic> multipartRequest(
    String endpoint, {
    required Map<String, dynamic> body,
    required Map<String, dynamic> files, // Changed from Map<String, String>
  }) async {
    if (!await _networkInfo.isConnected) {
      _logger.e('No internet connection');
      throw AppError('No internet connection');
    }

    try {
      FormData formData = FormData.fromMap(body);

      for (var entry in files.entries) {
        if (entry.value is String) {
          // Single file
          String fileName = entry.value.split('/').last;
          formData.files.add(
            MapEntry(
              entry.key,
              await MultipartFile.fromFile(entry.value, filename: fileName),
            ),
          );
        } else if (entry.value is List<String>) {
          // Multiple files
          for (String filePath in entry.value) {
            String fileName = filePath.split('/').last;
            formData.files.add(
              MapEntry(
                entry.key,
                await MultipartFile.fromFile(filePath, filename: fileName),
              ),
            );
          }
        }
      }

      _logger.d('Sending multipart request to $endpoint');
      Response response = await _dio.post(endpoint, data: formData);
      _logger.i('Multipart request successful');
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    } catch (e) {
      _logger.e('Multipart request failed', e);
      throw AppError('Multipart request failed: $e');
    }
  }

  /// Signs the device out locally and returns to the login screen.
  /// Idempotent: authToken is cleared first so a burst of parallel 401s
  /// results in exactly one navigation.
  Future<void> _forceSessionExpired() async {
    if (authToken.isEmpty) return;
    authToken = '';
    try {
      await SecurePrefs.clear();
    } catch (_) {
      // Storage clear failing must not block the redirect.
    }
    try {
      NavigationHelper.navigator?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    } catch (_) {
      // No navigator yet (very early startup) - harmless.
    }
  }

  void _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        _logger.e('Network timeout', e);
        throw AppError('Network timeout. Please try again.');
      case DioExceptionType.connectionError:
        _logger.e('Connection error', e);
        throw AppError(
          'Connection error. Please check your internet connection.',
          isNetworkError: true,
        );
      case DioExceptionType.badResponse:
        _logger.e('Server error: ${e.response?.statusCode}', e);
        // throw AppError('Server error: ${e.response?.statusCode ?? "Unknown"}');
        final responseData = e.response?.data;
        final printResponse = responseData;
        _logger.d('printResponse: $printResponse');

        final statusCode = e.response?.statusCode;
        String message = 'Server error: ${statusCode ?? "Unknown"}';
        List<dynamic>? errors;
        String? code;

        if (responseData is Map<String, dynamic>) {
          // NestJS's ValidationPipe (e.g. an unknown/rejected field on a
          // DTO-backed endpoint) reports `message` as a List<String>, not a
          // single string like the app's own GlobalExceptionFilter does for
          // everything else — normalize both shapes here.
          final rawMessage = responseData['message'];
          if (rawMessage is List) {
            message = rawMessage.join(', ');
          } else if (rawMessage != null) {
            message = rawMessage.toString();
          }

          final rawErrors = responseData['errors'];
          if (rawErrors is List) {
            errors = rawErrors;
          }

          final rawCode = responseData['code'];
          if (rawCode != null) code = rawCode.toString();
        }

        // Any 401 on an authenticated call means this device's session
        // is dead (revoked, or signed with a rotated secret). Clear it
        // and go to login; otherwise the app keeps showing cached UI
        // while every request fails, which looks like a broken feature.
        if (statusCode == 401 && authToken.isNotEmpty) {
          unawaited(_forceSessionExpired());
        }

        throw AppError(
          message,
          statusCode: statusCode,
          errors: errors,
          code: code,
        );
      case DioExceptionType.badCertificate:
        _logger.e('Bad certificate', e);
        throw AppError('Security error. Invalid certificate.');
      case DioExceptionType.cancel:
        _logger.e('Request cancelled', e);
        throw AppError('Request cancelled');
      default:
        _logger.e('Network error', e);
        throw AppError('Network error: ${e.message}');
    }
  }
}
