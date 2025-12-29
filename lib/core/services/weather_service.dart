// =============================================================================
// WEATHER SERVICE - Intégration API météo OpenWeatherMap
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/env_config.dart';

/// Conditions météorologiques actuelles
class WeatherConditions {
  final double temp;
  final double feelsLike;
  final int humidity;
  final String description;
  final String main;
  final String icon;
  final bool isRaining;
  final double windSpeed;
  final int visibility;
  final int cloudCover;
  final DateTime timestamp;

  WeatherConditions({
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.description,
    required this.main,
    required this.icon,
    required this.isRaining,
    required this.windSpeed,
    required this.visibility,
    required this.cloudCover,
    required this.timestamp,
  });

  factory WeatherConditions.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final weather = (json['weather'] as List).first as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>;
    final clouds = json['clouds'] as Map<String, dynamic>;

    return WeatherConditions(
      temp: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      humidity: main['humidity'] as int,
      description: weather['description'] as String,
      main: weather['main'] as String,
      icon: weather['icon'] as String,
      isRaining: (weather['main'] as String).toLowerCase().contains('rain'),
      windSpeed: (wind['speed'] as num).toDouble(),
      visibility: json['visibility'] as int,
      cloudCover: clouds['all'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['dt'] as int) * 1000,
      ),
    );
  }

  String getIconUrl() => 'https://openweathermap.org/img/wn/$icon@2x.png';

  String getEmoji() {
    if (main.toLowerCase().contains('rain')) return '🌧️';
    if (main.toLowerCase().contains('thunder')) return '⛈️';
    if (main.toLowerCase().contains('snow')) return '🌨️';
    if (main.toLowerCase().contains('mist') || main.toLowerCase().contains('fog')) return '🌫️';
    if (main.toLowerCase().contains('cloud')) return '☁️';
    if (icon.contains('n')) return '🌙';
    return '☀️';
  }

  Map<String, dynamic> toJson() => {
    'temp': temp,
    'feelsLike': feelsLike,
    'humidity': humidity,
    'description': description,
    'main': main,
    'icon': icon,
    'isRaining': isRaining,
    'windSpeed': windSpeed,
    'visibility': visibility,
    'cloudCover': cloudCover,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Impact de la météo sur les transports
class TransportWeatherImpact {
  final int walkingScore;
  final int mototaxiScore;
  final int publicTransportScore;
  final int openTransportScore;
  final List<String> recommendations;

  TransportWeatherImpact({
    required this.walkingScore,
    required this.mototaxiScore,
    required this.publicTransportScore,
    required this.openTransportScore,
    required this.recommendations,
  });
}

/// Service de météo avec OpenWeatherMap
class WeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  final http.Client _client = http.Client();
  WeatherConditions? _cachedWeather;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 10);

  WeatherService() {
    Logger.info('WeatherService initialisé', 'WeatherService');
    Logger.debug('URL API: $_baseUrl', 'WeatherService');
    Logger.debug('Clé API configurée: ${EnvConfig.hasValidWeatherKey ? "Oui" : "Non (mode démo)"}', 'WeatherService');
  }

  /// Récupère la météo actuelle par coordonnées
  Future<WeatherConditions?> getCurrentWeather(LatLng position) async {
    Logger.debug('Début getCurrentWeather pour position: ${position.latitude}, ${position.longitude}', 'WeatherService');
    
    // Vérifier le cache
    if (_cachedWeather != null && _cacheTime != null) {
      final cacheAge = DateTime.now().difference(_cacheTime!);
      if (cacheAge < _cacheDuration) {
        Logger.debug('Météo récupérée depuis le cache (âge: ${cacheAge.inMinutes}min)', 'WeatherService');
        return _cachedWeather;
      } else {
        Logger.debug('Cache expiré (âge: ${cacheAge.inMinutes}min)', 'WeatherService');
      }
    }

    if (!EnvConfig.hasValidWeatherKey) {
      Logger.warning('Mode démo - clé API non configurée', 'WeatherService');
      return _getDemoWeather();
    }

    try {
      final apiKey = EnvConfig.openWeatherApiKey;
      final url = Uri.parse(
          '$_baseUrl/weather?lat=${position.latitude}&lon=${position.longitude}'
              '&units=metric&lang=fr&appid=$apiKey'
      );

      Logger.api('GET', url.toString());
      
      final response = await _client.get(url).timeout(
        Duration(seconds: EnvConfig.apiTimeoutSeconds),
      );

      Logger.apiResponse(url.toString(), {
        'statusCode': response.statusCode,
        'contentLength': response.body.length,
      }, response.statusCode);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Logger.debug('JSON reçu: ${data.toString()}', 'WeatherService');
        
        _cachedWeather = WeatherConditions.fromJson(data);
        _cacheTime = DateTime.now();
        
        Logger.info('Météo récupérée avec succès: ${_cachedWeather!.description}', 'WeatherService');
        Logger.cache('SET', 'weather', _cachedWeather!.toJson());
        
        return _cachedWeather;
      } else {
        Logger.error('Erreur API météo: ${response.statusCode}', 'WeatherService', response.body);
      }
    } catch (e, stackTrace) {
      Logger.error('Exception getCurrentWeather', 'WeatherService', e);
      Logger.debug('Stack trace: $stackTrace', 'WeatherService');
      Logger.info('Retour aux données démo', 'WeatherService');
      return _getDemoWeather();
    }

    return null;
  }

  /// Récupère la météo par nom de ville
  Future<WeatherConditions?> getWeatherByCity(String city) async {
    Logger.debug('Début getWeatherByCity pour: $city', 'WeatherService');
    
    if (!EnvConfig.hasValidWeatherKey) {
      Logger.warning('Mode démo - clé API non configurée', 'WeatherService');
      return _getDemoWeather();
    }

    try {
      final apiKey = EnvConfig.openWeatherApiKey;
      final url = Uri.parse(
          '$_baseUrl/weather?q=$city&units=metric&lang=fr&appid=$apiKey'
      );

      Logger.api('GET', url.toString());
      
      final response = await _client.get(url).timeout(
        Duration(seconds: EnvConfig.apiTimeoutSeconds),
      );

      Logger.apiResponse(url.toString(), {
        'statusCode': response.statusCode,
        'contentLength': response.body.length,
      }, response.statusCode);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Logger.debug('JSON reçu: ${data.toString()}', 'WeatherService');
        
        final weather = WeatherConditions.fromJson(data);
        Logger.info('Météo pour $city récupérée: ${weather.description}', 'WeatherService');
        
        return weather;
      } else {
        Logger.error('Erreur API météo pour $city: ${response.statusCode}', 'WeatherService', response.body);
      }
    } catch (e, stackTrace) {
      Logger.error('Exception getWeatherByCity', 'WeatherService', e);
      Logger.debug('Stack trace: $stackTrace', 'WeatherService');
      Logger.info('Retour aux données démo', 'WeatherService');
      return _getDemoWeather();
    }

    return null;
  }

  /// Analyse l'impact de la météo sur les transports
  TransportWeatherImpact analyzeWeatherForTransport(
      WeatherConditions weather,
      double distanceMeters,
      ) {
    Logger.debug('Analyse impact météo pour distance: ${distanceMeters}m', 'WeatherService');
    Logger.debug('Conditions: ${weather.description}, Temp: ${weather.temp}°C', 'WeatherService');
    
    int walkingScore = 100;
    int mototaxiScore = 100;
    int publicTransportScore = 100;
    int openTransportScore = 100;
    final recommendations = <String>[];

    // Impact température
    if (weather.temp > 35 || weather.feelsLike > 38) {
      walkingScore -= 40;
      mototaxiScore -= 30;
      openTransportScore -= 25;
      recommendations.add('🌡️ Très chaud - Privilégiez les transports climatisés');
    } else if (weather.temp > 30 || weather.feelsLike > 33) {
      walkingScore -= 20;
      mototaxiScore -= 15;
      openTransportScore -= 10;
      recommendations.add('☀️ Chaud - Évitez l\'exposition prolongée');
    } else if (weather.temp < 18) {
      walkingScore += 10;
      recommendations.add('🌤️ Temps agréable pour la marche');
    }

    // Impact pluie
    if (weather.isRaining) {
      walkingScore -= 50;
      mototaxiScore -= 60;
      openTransportScore -= 40;
      publicTransportScore += 20;
      recommendations.add('🌧️ Pluie - Transports couverts recommandés');
      recommendations.add('⚠️ Routes glissantes - Prudence');
    }

    // Impact humidité
    if (weather.humidity > 85) {
      walkingScore -= 15;
      mototaxiScore -= 10;
      openTransportScore -= 20;
      publicTransportScore += 15;
      recommendations.add('💨 Humidité élevée - Climatisation appréciable');
    }

    // Impact vent
    if (weather.windSpeed > 8) {
      walkingScore -= 10;
      mototaxiScore -= 25;
      openTransportScore -= 15;
      recommendations.add('💨 Vent fort - Attention moto-taxis');
    }

    // Impact visibilité
    if (weather.visibility < 5000) {
      walkingScore -= 20;
      mototaxiScore -= 30;
      openTransportScore -= 15;
      recommendations.add('🌫️ Visibilité réduite - Prudence');
    }

    // Ajustement distance
    if (distanceMeters > 2000) {
      walkingScore -= ((distanceMeters - 2000) / 100).clamp(0, 30).toInt();
    } else if (distanceMeters < 500) {
      walkingScore += 20;
    }

    // Normaliser les scores
    walkingScore = walkingScore.clamp(0, 100);
    mototaxiScore = mototaxiScore.clamp(0, 100);
    publicTransportScore = publicTransportScore.clamp(0, 100);
    openTransportScore = openTransportScore.clamp(0, 100);

    final impact = TransportWeatherImpact(
      walkingScore: walkingScore,
      mototaxiScore: mototaxiScore,
      publicTransportScore: publicTransportScore,
      openTransportScore: openTransportScore,
      recommendations: recommendations,
    );

    Logger.debug('Scores finaux - Marche: $walkingScore, Moto: $mototaxiScore, Bus: $publicTransportScore, Ouvert: $openTransportScore', 'WeatherService');
    Logger.debug('Recommandations: ${recommendations.length}', 'WeatherService');
    
    return impact;
  }

  /// Conseils basés sur l'heure
  List<String> getTimeBasedAdvice() {
    final now = DateTime.now();
    final hour = now.hour;
    final advice = <String>[];

    if (hour >= 6 && hour <= 9) {
      advice.add('🌅 Heure de pointe - Embouteillages probables');
      advice.add('🏍️ Moto-taxis recommandés pour éviter bouchons');
    } else if (hour >= 16 && hour <= 19) {
      advice.add('🌆 Heure de pointe soir - Circulation dense');
      advice.add('⏱️ Prévoyez plus de temps');
    } else if (hour >= 22 || hour <= 5) {
      advice.add('🌙 Transport nocturne limité');
      advice.add('🚕 Taxis et moto-taxis plus rares');
    } else {
      advice.add('✅ Circulation fluide');
    }

    return advice;
  }

  /// Données météo de démonstration
  WeatherConditions _getDemoWeather() {
    Logger.debug('Génération données météo démo', 'WeatherService');
    
    return WeatherConditions(
      temp: 28.0,
      feelsLike: 30.0,
      humidity: 75,
      description: 'Ciel dégagé',
      main: 'Clear',
      icon: '01d',
      isRaining: false,
      windSpeed: 3.5,
      visibility: 10000,
      cloudCover: 10,
      timestamp: DateTime.now(),
    );
  }

  void dispose() {
    Logger.info('WeatherService disposé', 'WeatherService');
    _client.close();
  }
}