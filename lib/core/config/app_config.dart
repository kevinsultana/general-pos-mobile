import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Global configuration for General POS Mobile Application.
/// Handles centralized backend server endpoint for Multi-Tenant Cloud Sync.
class AppConfig {
  /// Default backend server base URL.
  /// Dynamically selects local development server in debug mode,
  /// or remote production server in release builds, unless overridden by --dart-define=API_URL=...
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) {
      return normalizeUrl(fromEnv);
    }

    if (kDebugMode) {
      try {
        if (!kIsWeb && Platform.isAndroid) {
          // Android Emulator connects to host machine via 10.0.2.2
          return 'http://10.0.2.2:5000';
        }
      } catch (_) {}
      // Windows Desktop, Web, or macOS localhost
      return 'http://localhost:5000';
    }

    return 'https://pos-api.kevinsultana.online';
  }

  /// Helper to normalize server URLs by stripping trailing slashes.
  static String normalizeUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
