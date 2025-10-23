import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration class for Google Maps API
class MapsConfig {
  /// Get Google Maps API Key from environment variables
  static String get apiKey {
    final key = dotenv.env['GOOGLE_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GOOGLE_API_KEY not found in .env file');
    }
    // Remove any quotes from the key
    return key.replaceAll("'", "").replaceAll('"', "").trim();
  }
}
