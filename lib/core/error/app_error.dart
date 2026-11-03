import 'dart:convert';

class AppError implements Exception {
  final String message;
  final bool isNetworkError;
  // The real HTTP status code, when available. The NEW backend reuses the
  // same status for different meanings per endpoint (e.g. verify-OTP failure
  // is 401 now, was 400 on OLD), so callers need this to branch correctly
  // instead of parsing it back out of the message string.
  final int? statusCode;
  // Field-level validation messages from NEW's `errors` array, when present.
  final List<dynamic>? errors;
  // Machine-readable error code from the API envelope (e.g.
  // STATE_GROUP_RESTRICTED), so callers do not parse message text.
  final String? code;

  AppError(
    this.message, {
    this.isNetworkError = false,
    this.statusCode,
    this.errors,
    this.code,
  });

  @override
  String toString() => 'AppError: $message';
}

Map<String, dynamic>? extractErrorData(AppError error) {
  String errorBody = error.toString();

  if (error.isNetworkError) {
    return {
      'success': false,
      'message': 'No internet connection. Please check your internet settings.',
      'isNetworkError': true,
    };
  }

  // Extract JSON from response body if present
  if (errorBody.contains('Response Body:')) {
    try {
      String jsonStr = errorBody.split('Response Body:')[1].trim();
      return jsonDecode(jsonStr);
    } catch (_) {
      // If JSON parsing fails, return the raw error message
      return {'success': false, 'message': error.message, 'statusCode': error.statusCode};
    }
  }

  // Default case: return the error message
  return {'success': false, 'message': error.message, 'statusCode': error.statusCode};
}
