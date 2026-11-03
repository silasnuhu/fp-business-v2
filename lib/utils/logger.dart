// *****************************************************************************************
// * Filename: logger.dart.                                                                *
// * Developer: Deval Joshi                                                                *
// * Date: 11 October 2024                                                                 *                      *
// * Description: This file handle the app log                                             *
// *****************************************************************************************

import 'dart:developer' as developer;

enum LogLevel { verbose, debug, info, warning, error, wtf }

class ConsoleAppLogger {
  static final ConsoleAppLogger _instance = ConsoleAppLogger._internal();
  String _module = 'App'; // Default module name

  factory ConsoleAppLogger() {
    return _instance;
  }

  // Factory constructor that accepts a module name
  factory ConsoleAppLogger.forModule(String moduleName) {
    _instance._module = moduleName;
    return _instance;
  }

  ConsoleAppLogger._internal();

  // ANSI color codes for terminal output
  static const String _resetColor = '\x1B[0m';
  static const String _grayColor = '\x1B[90m';
  static const String _greenColor = '\x1B[32m';
  static const String _cyanColor = '\x1B[36m';
  static const String _yellowColor = '\x1B[33m';
  static const String _redColor = '\x1B[31m';
  static const String _magentaColor = '\x1B[35m';
  static const String _boldText = '\x1B[1m';

  String _getColorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return _grayColor;
      case LogLevel.debug:
        return _cyanColor;
      case LogLevel.info:
        return _greenColor;
      case LogLevel.warning:
        return _yellowColor;
      case LogLevel.error:
        return _redColor;
      case LogLevel.wtf:
        return _magentaColor;
    }
  }

  void _log(
    LogLevel level,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    final timestamp = DateTime.now().toIso8601String();
    final levelString = level.toString().split('.').last.toUpperCase();
    final color = _getColorForLevel(level);

    // Include module name in the log message
    final colorizedMessage =
        '$color$timestamp [$levelString] $_boldText[$_module]$_resetColor$color $message$_resetColor';

    developer.log(
      colorizedMessage,
      name: 'ConsoleAppLogger',
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Set a new module name dynamically
  void setModule(String moduleName) {
    _module = moduleName;
  }

  void v(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.verbose, message, error, stackTrace);
  }

  void d(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  void i(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.wtf, message, error, stackTrace);
  }
}

// // *****************************************************************************************
// // * Filename: logger.dart                                                                 *
// // * Developer: Deval Joshi                                                                *
// // * Date: 11 October 2024                                                                 *
// // * Description: Professional log formatter with excellent readability                    *
// // *****************************************************************************************

// import 'dart:developer' as developer;

// enum LogLevel { verbose, debug, info, warning, error, wtf }

// class ConsoleAppLogger {
//   static final ConsoleAppLogger _instance = ConsoleAppLogger._internal();

//   factory ConsoleAppLogger() {
//     return _instance;
//   }

//   ConsoleAppLogger._internal();

//   // Custom symbols for different log levels to improve scanability
//   static const Map<LogLevel, String> _logSymbols = {
//     LogLevel.verbose: '•',
//     LogLevel.debug: '⚙',
//     LogLevel.info: 'ℹ',
//     LogLevel.warning: '⚠',
//     LogLevel.error: '✕',
//     LogLevel.wtf: '⚡',
//   };

//   void _log(
//       LogLevel level,
//       String message, [
//         dynamic error,
//         StackTrace? stackTrace,
//       ]) {
//     final levelName = level.toString().split('.').last.toUpperCase();
//     final timestamp = DateTime.now().toString().split('.').first;
//     final symbol = _logSymbols[level] ?? '•';

//     // Format the log entry with consistent spacing and clear hierarchy
//     // Create a standardized header with consistent length
//     final headerLine = '[ConsoleAppLogger] [LOGLEVEL.$levelName] ' +
//         '${'-' * (85 - levelName.length)}';

//     // Format the level line with clear spacing and timestamp
//     final levelLine = '[ $levelName${_getPadding(levelName)} ] | $timestamp';

//     // Format the message line with level indicator
//     final shortLabel = levelName.substring(0, 1);
//     final messageLine = '┌─ $shortLabel ─┐ $symbol $message';

//     // Complete log message with consistent format
//     final logMessage = '$headerLine\n$levelLine\n$messageLine';

//     developer.log(
//       logMessage,
//       name: 'ConsoleAppLogger',
//       error: error,
//       stackTrace: stackTrace,
//     );
//   }

//   // Helper to ensure consistent spacing in the log level indicator
//   String _getPadding(String levelStr) {
//     // Calculate spaces needed to make all level strings occupy the same width
//     const int targetWidth = 7;  // Based on your screenshot formatting
//     final int spaces = targetWidth - levelStr.length;
//     return ' ' * spaces;
//   }

//   void v(String message, [dynamic error, StackTrace? stackTrace]) {
//     _log(LogLevel.verbose, message, error, stackTrace);
//   }

//   void d(String message, [dynamic error, StackTrace? stackTrace]) {
//     _log(LogLevel.debug, message, error, stackTrace);
//   }

//   void i(String message, [dynamic error, StackTrace? stackTrace]) {
//     _log(LogLevel.info, message, error, stackTrace);
//   }

//   void w(String message, [dynamic error, StackTrace? stackTrace]) {
//     _log(LogLevel.warning, message, error, stackTrace);
//   }

//   void e(String message, [dynamic error, StackTrace? stackTrace]) {
//     _log(LogLevel.error, message, error, stackTrace);
//   }

//   void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
//     _log(LogLevel.wtf, message, error, stackTrace);
//   }
// }
