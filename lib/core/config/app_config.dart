/// Global configuration for General POS Mobile Application.
/// Handles centralized backend server endpoint for Multi-Tenant Cloud Sync.
class AppConfig {
  /// Default backend server base URL.
  /// Can be overridden at build-time using `--dart-define=API_URL=https://your-domain.com`
  /// or modified dynamically when server endpoint is assigned.
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:5000',
  );

  /// Helper to normalize server URLs by stripping trailing slashes.
  static String normalizeUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
