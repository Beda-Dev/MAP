import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/weather_service.dart';
import '../../core/config/env_config.dart';

// =============================================================================
// WEATHER PROVIDER - Gestion des données météo
// =============================================================================

class WeatherProvider with ChangeNotifier {
  final WeatherService weatherService;

  WeatherProvider({required this.weatherService}) {
    Logger.info('WeatherProvider initialisé', 'WeatherProvider');
    Logger.debug('Service météo configuré: ${EnvConfig.hasValidWeatherKey ? "Oui" : "Non (mode démo)"}', 'WeatherProvider');
  }

  WeatherConditions? _currentWeather;
  bool _isLoading = false;
  String? _error;

  WeatherConditions? get currentWeather => _currentWeather;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charge la météo pour une position
  Future<void> loadWeather(LatLng position) async {
    Logger.debug('Début loadWeather', 'WeatherProvider');
    Logger.debug('Position: ${position.latitude}, ${position.longitude}', 'WeatherProvider');
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    Logger.info('Début chargement météo', 'WeatherProvider');

    try {
      _currentWeather = await weatherService.getCurrentWeather(position);
      _error = null;
      
      if (_currentWeather != null) {
        Logger.info('Météo chargée: ${_currentWeather!.description}', 'WeatherProvider');
        Logger.debug('Température: ${_currentWeather!.temp}°C (ressenti: ${_currentWeather!.feelsLike}°C)', 'WeatherProvider');
        Logger.debug('Humidité: ${_currentWeather!.humidity}%', 'WeatherProvider');
        Logger.debug('Vent: ${_currentWeather!.windSpeed} m/s', 'WeatherProvider');
        Logger.debug('Visibilité: ${_currentWeather!.visibility}m', 'WeatherProvider');
      } else {
        Logger.warning('Aucune donnée météo reçue', 'WeatherProvider');
      }
    } catch (e, stackTrace) {
      _error = 'Erreur météo: $e';
      _currentWeather = null;
      Logger.error('Erreur chargement météo', 'WeatherProvider', e);
      Logger.debug('Stack trace: $stackTrace', 'WeatherProvider');
    } finally {
      _isLoading = false;
      notifyListeners();
      Logger.debug('loadWeather terminé, notifyListeners appelé', 'WeatherProvider');
    }
  }

  /// Analyse l'impact sur les transports
  TransportWeatherImpact? analyzeImpact(double distanceMeters) {
    Logger.debug('Analyse impact météo pour distance: ${distanceMeters}m', 'WeatherProvider');
    
    if (_currentWeather == null) {
      Logger.warning('Aucune donnée météo disponible pour l\'analyse', 'WeatherProvider');
      return null;
    }

    try {
      final impact = weatherService.analyzeWeatherForTransport(
        _currentWeather!,
        distanceMeters,
      );
      
      Logger.info('Impact météo analysé', 'WeatherProvider');
      Logger.debug('Scores - Marche: ${impact.walkingScore}, Moto: ${impact.mototaxiScore}', 'WeatherProvider');
      Logger.debug('Scores - Bus: ${impact.publicTransportScore}, Ouvert: ${impact.openTransportScore}', 'WeatherProvider');
      Logger.debug('Recommandations: ${impact.recommendations.length}', 'WeatherProvider');
      
      return impact;
    } catch (e, stackTrace) {
      Logger.error('Erreur analyse impact', 'WeatherProvider', e);
      Logger.debug('Stack trace: $stackTrace', 'WeatherProvider');
      return null;
    }
  }

  /// Obtient les conseils horaires
  List<String> getTimeAdvice() {
    Logger.debug('Génération conseils horaires', 'WeatherProvider');
    
    try {
      final advice = weatherService.getTimeBasedAdvice();
      Logger.debug('Conseils générés: ${advice.length}', 'WeatherProvider');
      return advice;
    } catch (e, stackTrace) {
      Logger.error('Erreur génération conseils', 'WeatherProvider', e);
      Logger.debug('Stack trace: $stackTrace', 'WeatherProvider');
      return [];
    }
  }

  /// Rafraîchit la météo
  Future<void> refresh(LatLng position) async {
    Logger.info('Rafraîchissement météo demandé', 'WeatherProvider');
    await loadWeather(position);
  }
  
  /// Obtient l'emoji météo actuel
  String getWeatherEmoji() {
    if (_currentWeather == null) {
      Logger.debug('Aucun emoji météo disponible', 'WeatherProvider');
      return '❓';
    }
    
    final emoji = _currentWeather!.getEmoji();
    Logger.debug('Emoji météo: $emoji', 'WeatherProvider');
    return emoji;
  }
  
  /// Vérifie si la météo est favorable pour la marche
  bool isGoodForWalking() {
    if (_currentWeather == null) {
      Logger.debug('Impossible d\'évaluer la marche - pas de données météo', 'WeatherProvider');
      return false;
    }
    
    final impact = analyzeImpact(1000); // Analyse pour 1km
    final walkingScore = impact?.walkingScore ?? 0;
    final isGood = walkingScore > 70;
    
    Logger.debug('Météo favorable pour la marche: $isGood (score: $walkingScore)', 'WeatherProvider');
    return isGood;
  }
}