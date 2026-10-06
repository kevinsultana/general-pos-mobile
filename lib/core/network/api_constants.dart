class ApiConstants {
  // Fixed Production Endpoint (mendukung override saat build via --dart-define=API_BASE_URL=...)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pos-api.kevinsultana.online/api',
  );

  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String syncInitialUpload = '/sync/initial-upload';
  static const String syncPush = '/sync/push';
  static const String syncPull = '/sync/pull';
}
