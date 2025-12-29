// =============================================================================
// CACHE SERVICE - Gestion du stockage local avec Hive
// =============================================================================

import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class CacheService {
  static const String _stopsBoxName = 'transport_stops';
  static const String _weatherBoxName = 'weather_cache';
  static const String _preferencesBoxName = 'user_preferences';

  static Box? _stopsBox;
  static Box? _weatherBox;
  static Box? _preferencesBox;

  /// Initialise Hive et ouvre les boxes
  static Future<void> init() async {
    await Hive.initFlutter();

    _stopsBox = await Hive.openBox(_stopsBoxName);
    _weatherBox = await Hive.openBox(_weatherBoxName);
    _preferencesBox = await Hive.openBox(_preferencesBoxName);
  }

  // ============= ARRÊTS DE TRANSPORT =============

  /// Sauvegarde les arrêts en cache
  Future<void> cacheStops(String key, List<Map<String, dynamic>> stops) async {
    await _stopsBox?.put(key, {
      'data': json.encode(stops),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Récupère les arrêts du cache
  Future<List<Map<String, dynamic>>?> getCachedStops(String key, Duration maxAge) async {
    final cached = _stopsBox?.get(key);
    if (cached == null) return null;

    final timestamp = cached['timestamp'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;

    if (age > maxAge.inMilliseconds) {
      await _stopsBox?.delete(key);
      return null;
    }

    final data = json.decode(cached['data']) as List;
    return data.cast<Map<String, dynamic>>();
  }

  // ============= MÉTÉO =============

  /// Sauvegarde la météo en cache
  Future<void> cacheWeather(String key, Map<String, dynamic> weather) async {
    await _weatherBox?.put(key, {
      'data': json.encode(weather),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Récupère la météo du cache
  Future<Map<String, dynamic>?> getCachedWeather(String key, Duration maxAge) async {
    final cached = _weatherBox?.get(key);
    if (cached == null) return null;

    final timestamp = cached['timestamp'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;

    if (age > maxAge.inMilliseconds) {
      await _weatherBox?.delete(key);
      return null;
    }

    return json.decode(cached['data']) as Map<String, dynamic>;
  }

  // ============= PRÉFÉRENCES UTILISATEUR =============

  /// Sauvegarde une préférence
  Future<void> setPreference(String key, dynamic value) async {
    await _preferencesBox?.put(key, value);
  }

  /// Récupère une préférence
  T? getPreference<T>(String key, {T? defaultValue}) {
    return _preferencesBox?.get(key, defaultValue: defaultValue) as T?;
  }

  /// Supprime une préférence
  Future<void> removePreference(String key) async {
    await _preferencesBox?.delete(key);
  }

  // ============= FAVORIS =============

  /// Ajoute un arrêt aux favoris
  Future<void> addFavorite(String stopId, Map<String, dynamic> stopData) async {
    final favorites = getFavorites();
    favorites[stopId] = stopData;
    await setPreference('favorites', favorites);
  }

  /// Supprime un favori
  Future<void> removeFavorite(String stopId) async {
    final favorites = getFavorites();
    favorites.remove(stopId);
    await setPreference('favorites', favorites);
  }

  /// Récupère tous les favoris
  Map<String, dynamic> getFavorites() {
    final favorites = getPreference<Map>('favorites', defaultValue: {});
    return Map<String, dynamic>.from(favorites ?? {});
  }

  /// Vérifie si un arrêt est en favori
  bool isFavorite(String stopId) {
    return getFavorites().containsKey(stopId);
  }

  // ============= HISTORIQUE =============

  /// Ajoute une recherche à l'historique
  Future<void> addToHistory(Map<String, dynamic> searchData) async {
    final history = getHistory();
    history.insert(0, searchData);

    // Limiter à 50 entrées
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }

    await setPreference('search_history', history);
  }

  /// Récupère l'historique
  List<Map<String, dynamic>> getHistory() {
    final history = getPreference<List>('search_history', defaultValue: []);
    return (history ?? []).cast<Map<String, dynamic>>();
  }

  /// Efface l'historique
  Future<void> clearHistory() async {
    await removePreference('search_history');
  }

  // ============= NETTOYAGE =============

  /// Nettoie tous les caches
  Future<void> clearAllCaches() async {
    await _stopsBox?.clear();
    await _weatherBox?.clear();
  }

  /// Nettoie les caches expirés
  Future<void> cleanExpiredCaches() async {
    // Nettoyer les arrêts de plus de 24h
    final stopsKeys = _stopsBox?.keys.toList() ?? [];
    for (final key in stopsKeys) {
      final cached = _stopsBox?.get(key);
      if (cached != null) {
        final timestamp = cached['timestamp'] as int;
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age > const Duration(hours: 24).inMilliseconds) {
          await _stopsBox?.delete(key);
        }
      }
    }

    // Nettoyer la météo de plus de 30min
    final weatherKeys = _weatherBox?.keys.toList() ?? [];
    for (final key in weatherKeys) {
      final cached = _weatherBox?.get(key);
      if (cached != null) {
        final timestamp = cached['timestamp'] as int;
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age > const Duration(minutes: 30).inMilliseconds) {
          await _weatherBox?.delete(key);
        }
      }
    }
  }

  /// Obtient la taille du cache
  Future<Map<String, int>> getCacheSizes() async {
    return {
      'stops': _stopsBox?.length ?? 0,
      'weather': _weatherBox?.length ?? 0,
      'preferences': _preferencesBox?.length ?? 0,
    };
  }
}