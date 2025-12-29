import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/weather_service.dart';

// =============================================================================
// WEATHER PROVIDER - Gestion des données météo
// =============================================================================

class WeatherProvider with ChangeNotifier {
  final WeatherService weatherService;

  WeatherProvider({required this.weatherService});

  WeatherConditions? _currentWeather;
  bool _isLoading = false;
  String? _error;

  WeatherConditions? get currentWeather => _currentWeather;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charge la météo pour une position
  Future<void> loadWeather(LatLng position) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentWeather = await weatherService.getCurrentWeather(position);
      _error = null;
    } catch (e) {
      _error = 'Erreur météo: $e';
      _currentWeather = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Analyse l'impact sur les transports
  TransportWeatherImpact? analyzeImpact(double distanceMeters) {
    if (_currentWeather == null) return null;

    return weatherService.analyzeWeatherForTransport(
      _currentWeather!,
      distanceMeters,
    );
  }

  /// Obtient les conseils horaires
  List<String> getTimeAdvice() {
    return weatherService.getTimeBasedAdvice();
  }

  /// Rafraîchit la météo
  Future<void> refresh(LatLng position) async {
    await loadWeather(position);
  }
}