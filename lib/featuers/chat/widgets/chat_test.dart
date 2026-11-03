// app_progress_indicator.dart
import 'package:flutter/material.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

/// A custom progress indicator widget that can be used throughout the app.
/// Displays a centered circular progress indicator with optional custom color.

// no_data_found.dart

/// A widget to display when no data is available.
/// Shows a centered icon and message to inform the user.
class NoDataFound extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? iconColor;
  final Color? textColor;
  final double iconSize;
  final double fontSize;
  final VoidCallback? onRefresh;

  const NoDataFound({
    super.key,
    required this.message,
    required this.icon,
    this.iconColor,
    this.textColor,
    this.iconSize = 48.0,
    this.fontSize = 16.0,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: iconColor ?? Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: fontSize,
              color: textColor ?? Theme.of(context).textTheme.bodyLarge?.color,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(AppString.refresh),
            ),
          ],
        ],
      ),
    );
  }
}

/// A message box for displaying errors or important messages to the user.
/// Includes a retry button for error scenarios.
class AppMessageBox extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final String? retryText;

  const AppMessageBox({
    super.key,
    required this.message,
    this.onRetry,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.retryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              backgroundColor != null
                  ? backgroundColor!.withValues(alpha: 0.3)
                  : Colors.red.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, color: textColor ?? Colors.red, size: 28),
          if (icon != null) const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: textColor ?? Colors.red.shade800,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    backgroundColor != null
                        ? Theme.of(context).primaryColor
                        : Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
              child: Text(retryText ?? 'Try Again'),
            ),
          ],
        ],
      ),
    );
  }
}
