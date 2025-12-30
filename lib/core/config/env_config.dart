// =============================================================================
// CONFIGURATION ENVIRONNEMENT
// =============================================================================

import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static final bool _initialized = false;

  // Initialise la configuration depuis le fichier .env
  static Future<void> init() async {
    try {
      Logger.info('Chargement du fichier .env', 'EnvConfig');
      await dotenv.load(fileName: '.env');
      Logger.info('Fichier .env chargé avec succès', 'EnvConfig');
    } catch (e) {
      Logger.error('Erreur chargement .env', 'EnvConfig', e);
      Logger.info('Utilisation des valeurs par défaut', 'EnvConfig');
      // Utiliser des valeurs par défaut si le fichier n'existe pas
    }
    
    // Afficher les valeurs chargées (en masquant la clé API)
    Logger.info('Configuration:', 'EnvConfig');
    Logger.info('- Mode debug: $debugMode', 'EnvConfig');
    Logger.info('- URL Overpass: $overpassApiUrl', 'EnvConfig');
    Logger.info('- Timeout API: ${apiTimeoutSeconds}s', 'EnvConfig');
    Logger.info('- Rayon recherche: ${searchRadiusMeters}m', 'EnvConfig');
    Logger.info('- Distance reload: ${minDistanceForReload}m', 'EnvConfig');
    Logger.info('- Clé API météo: ${hasValidWeatherKey ? "Configurée" : "Non configurée"}', 'EnvConfig');
  }

  // API Keys
  static String get openWeatherApiKey => 
      dotenv.env['OPENWEATHER_API_KEY'] ?? 'VOTRE_CLE_API_OPENWEATHERMAP_ICI';

  // URLs
  static String get overpassApiUrl => 
      dotenv.env['OVERPASS_API_URL'] ?? 'https://overpass-api.de/api/interpreter';
  static String get weatherApiUrl => 
      dotenv.env['WEATHER_API_URL'] ?? 'https://api.openweathermap.org/data/2.5';

  // Configuration
  static bool get debugMode => 
      dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';
  static String get logLevel => 
      dotenv.env['LOG_LEVEL'] ?? 'info';
  static int get apiTimeoutSeconds => 
      int.tryParse(dotenv.env['API_TIMEOUT_SECONDS'] ?? '') ?? 30;
  static int get cacheDurationMinutes => 
      int.tryParse(dotenv.env['CACHE_DURATION_MINUTES'] ?? '') ?? 10;

  // Transport
  static double get searchRadiusMeters => 
      double.tryParse(dotenv.env['SEARCH_RADIUS_METERS'] ?? '') ?? 1500.0;
  static double get minDistanceForReload => 
      double.tryParse(dotenv.env['MIN_DISTANCE_FOR_RELOAD'] ?? '') ?? 500.0;

  // Vérification
  static bool get hasValidWeatherKey => 
      openWeatherApiKey.isNotEmpty && openWeatherApiKey != 'VOTRE_CLE_API_OPENWEATHERMAP_ICI';
}

// Utilitaire de logging
class Logger {
  static void debug(String message, [String? tag]) {
    if (EnvConfig.debugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final prefix = tag != null ? '[$tag] ' : '';
      print('🐛 DEBUG $timestamp $prefix$message');
    }
  }

  static void info(String message, [String? tag]) {
    final timestamp = DateTime.now().toIso8601String();
    final prefix = tag != null ? '[$tag] ' : '';
    print('ℹ️ INFO $timestamp $prefix$message');
  }

  static void warning(String message, [String? tag]) {
    final timestamp = DateTime.now().toIso8601String();
    final prefix = tag != null ? '[$tag] ' : '';
    print('⚠️ WARNING $timestamp $prefix$message');
  }

  static void error(String message, [String? tag, dynamic error]) {
    final timestamp = DateTime.now().toIso8601String();
    final prefix = tag != null ? '[$tag] ' : '';
    print('❌ ERROR $timestamp $prefix$message');
    if (error != null) {
      print('   Details: $error');
    }
  }

  static void api(String method, String url, [dynamic data]) {
    if (EnvConfig.debugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('🌐 API $timestamp $method $url');
      if (data != null) {
        print('   Data: ${_formatJson(data)}');
      }
    }
  }

  static void apiResponse(String url, dynamic response, [int? statusCode]) {
    if (EnvConfig.debugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final status = statusCode != null ? ' [$statusCode]' : '';
      print('📡 API Response $timestamp$url$status');
      print('   Response: ${_formatJson(response)}');
    }
  }

  static void cache(String operation, String key, [dynamic data]) {
    if (EnvConfig.debugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('💾 CACHE $timestamp $operation $key');
      if (data != null) {
        print('   Data: ${_formatJson(data)}');
      }
    }
  }

  static String _formatJson(dynamic data) {
    try {
      if (data is String) {
        // Si c'est déjà une chaîne JSON, essayer de la formater
        if (data.trim().startsWith('{') || data.trim().startsWith('[')) {
          return data;
        }
        return data;
      }
      return data.toString();
    } catch (e) {
      return data.toString();
    }
  }
}
