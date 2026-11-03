# rabtah

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


//logger usage
// For a specific module/API
final logger = ConsoleAppLogger.forModule('AuthAPI');
logger.i('User authenticated successfully');  // Will show "[AuthAPI]" in logs

// Change module within a class
void someOtherFunction() {
  logger.setModule('PaymentAPI');
  logger.d('Processing payment');  // Will show "[PaymentAPI]" in logs
}

// Default logger (will show "[App]")
final defaultLogger = ConsoleAppLogger();
defaultLogger.w('Something might be wrong');