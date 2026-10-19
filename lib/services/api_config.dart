import 'package:flutter/foundation.dart';

class ApiConfig {
  // Allow build-time override via: flutter run --dart-define=API_URL=https://your-api.com
  static const String _envApiUrl = String.fromEnvironment('API_URL', defaultValue: '');

  static String get baseUrl {
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl;
    }

    // Smart local development defaults across platforms:
    if (kIsWeb) {
      // In web browser, localhost refers to the local dev host machine
      return 'http://localhost:5000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // In standard Android emulator, 10.0.2.2 maps to the host machine's localhost
      return 'http://10.0.2.2:5000';
    }

    // Default for iOS simulator, macOS, Windows, Linux desktop
    return 'http://localhost:5000';
  }

  static String get socketUrl => baseUrl;
}
