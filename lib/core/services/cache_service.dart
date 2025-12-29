// =============================================================================
// CACHE SERVICE - Gestion du stockage local avec Hive
// =============================================================================

import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../config/env_config.dart';

class CacheService {
  static const String _stopsBoxName = 'transport_stops';
  static const String _weatherBoxName = 'weather_cache';
  static const String _preferencesBoxName = 'user_preferences';

  static Box? _stopsBox;
  static Box? _weatherBox;
  static Box? _preferencesBox;

  /// Initialise Hive et ouvre les boxes
  static Future<void> init() async {
    Logger.info('Initialisation CacheService', 'CacheService');
    
    try {
      await Hive.initFlutter();
      Logger.debug('Hive initialisé', 'CacheService');

      _stopsBox = await Hive.openBox(_stopsBoxName);
      _weatherBox = await Hive.openBox(_weatherBoxName);
      _preferencesBox = await Hive.openBox(_preferencesBoxName);
      
      Logger.info('Boxes Hive ouvertes avec succès', 'CacheService');
      Logger.debug('Box $_stopsBoxName: ${_stopsBox?.length} éléments', 'CacheService');
      Logger.debug('Box $_weatherBoxName: ${_weatherBox?.length} éléments', 'CacheService');
      Logger.debug('Box $_preferencesBoxName: ${_preferencesBox?.length} éléments', 'CacheService');
    } catch (e, stackTrace) {
      Logger.error('Erreur initialisation CacheService', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
      rethrow;
    }
  }

  // ============= ARRÊTS DE TRANSPORT =============

  /// Sauvegarde les arrêts en cache
  Future<void> cacheStops(String key, List<Map<String, dynamic>> stops) async {
    Logger.debug('Cache stops - clé: $key, nombre: ${stops.length}', 'CacheService');
    
    try {
      final cacheData = {
        'data': json.encode(stops),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await _stopsBox?.put(key, cacheData);
      Logger.cache('SET', key, {'stops_count': stops.length});
      Logger.debug('Arrêts mis en cache avec succès', 'CacheService');
    } catch (e, stackTrace) {
      Logger.error('Erreur cacheStops', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
    }
  }

  /// Récupère les arrêts du cache
  Future<List<Map<String, dynamic>>?> getCachedStops(String key, Duration maxAge) async {
    Logger.debug('Récupération stops cache - clé: $key, maxAge: ${maxAge.inMinutes}min', 'CacheService');
    
    final cached = _stopsBox?.get(key);
    if (cached == null) {
      Logger.debug('Aucune donnée trouvée pour clé: $key', 'CacheService');
      return null;
    }

    final timestamp = cached['timestamp'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    final ageMinutes = age / (1000 * 60);

    Logger.debug('Âge du cache: ${ageMinutes.toStringAsFixed(1)}min', 'CacheService');

    if (age > maxAge.inMilliseconds) {
      Logger.info('Cache expiré pour clé: $key (âge: ${ageMinutes.toStringAsFixed(1)}min)', 'CacheService');
      await _stopsBox?.delete(key);
      Logger.cache('DELETE', key, 'expired');
      return null;
    }

    try {
      final data = json.decode(cached['data']) as List;
      final result = data.cast<Map<String, dynamic>>();
      Logger.cache('GET', key, {'stops_count': result.length, 'age_min': ageMinutes.toStringAsFixed(1)});
      Logger.debug('Arrêts récupérés depuis cache: ${result.length}', 'CacheService');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Erreur décodage JSON stops cache', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
      // Supprimer le cache corrompu
      await _stopsBox?.delete(key);
      Logger.cache('DELETE', key, 'corrupted');
      return null;
    }
  }

  // ============= MÉTÉO =============

  /// Sauvegarde la météo en cache
  Future<void> cacheWeather(String key, Map<String, dynamic> weather) async {
    Logger.debug('Cache météo - clé: $key', 'CacheService');
    
    try {
      final cacheData = {
        'data': json.encode(weather),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await _weatherBox?.put(key, cacheData);
      Logger.cache('SET', key, weather);
      Logger.debug('Météo mise en cache avec succès', 'CacheService');
    } catch (e, stackTrace) {
      Logger.error('Erreur cacheWeather', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
    }
  }

  /// Récupère la météo du cache
  Future<Map<String, dynamic>?> getCachedWeather(String key, Duration maxAge) async {
    Logger.debug('Récupération météo cache - clé: $key, maxAge: ${maxAge.inMinutes}min', 'CacheService');
    
    final cached = _weatherBox?.get(key);
    if (cached == null) {
      Logger.debug('Aucune météo trouvée pour clé: $key', 'CacheService');
      return null;
    }

    final timestamp = cached['timestamp'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    final ageMinutes = age / (1000 * 60);

    Logger.debug('Âge du cache météo: ${ageMinutes.toStringAsFixed(1)}min', 'CacheService');

    if (age > maxAge.inMilliseconds) {
      Logger.info('Cache météo expiré pour clé: $key (âge: ${ageMinutes.toStringAsFixed(1)}min)', 'CacheService');
      await _weatherBox?.delete(key);
      Logger.cache('DELETE', key, 'expired');
      return null;
    }

    try {
      final result = json.decode(cached['data']) as Map<String, dynamic>;
      Logger.cache('GET', key, {'age_min': ageMinutes.toStringAsFixed(1)});
      Logger.debug('Météo récupérée depuis cache', 'CacheService');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Erreur décodage JSON météo cache', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
      // Supprimer le cache corrompu
      await _weatherBox?.delete(key);
      Logger.cache('DELETE', key, 'corrupted');
      return null;
    }
  }

  // ============= PRÉFÉRENCES UTILISATEUR =============

  /// Sauvegarde une préférence
  Future<void> setPreference(String key, dynamic value) async {
    Logger.debug('Set préférence - clé: $key', 'CacheService');
    
    try {
      await _preferencesBox?.put(key, value);
      Logger.cache('SET', 'pref_$key', value);
      Logger.debug('Préférence sauvegardée: $key', 'CacheService');
    } catch (e, stackTrace) {
      Logger.error('Erreur setPreference', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
    }
  }

  /// Récupère une préférence
  T? getPreference<T>(String key, {T? defaultValue}) {
    Logger.debug('Get préférence - clé: $key, défaut: $defaultValue', 'CacheService');
    
    try {
      final value = _preferencesBox?.get(key, defaultValue: defaultValue) as T?;
      Logger.cache('GET', 'pref_$key', value);
      Logger.debug('Préférence récupérée: $key = $value', 'CacheService');
      return value;
    } catch (e, stackTrace) {
      Logger.error('Erreur getPreference', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
      return defaultValue;
    }
  }

  /// Supprime une préférence
  Future<void> removePreference(String key) async {
    Logger.debug('Remove préférence - clé: $key', 'CacheService');
    
    try {
      await _preferencesBox?.delete(key);
      Logger.cache('DELETE', 'pref_$key', 'user_request');
      Logger.debug('Préférence supprimée: $key', 'CacheService');
    } catch (e, stackTrace) {
      Logger.error('Erreur removePreference', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
    }
  }

  // ============= FAVORIS =============

  /// Ajoute un arrêt aux favoris
  Future<void> addFavorite(String stopId, Map<String, dynamic> stopData) async {
    Logger.debug('Add favori - stopId: $stopId', 'CacheService');
    
    try {
      final favorites = getFavorites();
      favorites[stopId] = stopData;
      await setPreference('favorites', favorites);
      Logger.info('Favori ajouté: $stopId', 'CacheService');
      Logger.debug('Total favoris: ${favorites.length}', 'CacheService');
    } catch (e, stackTrace) {
      Logger.error('Erreur addFavorite', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
    }
  }

  /// Supprime un favori
  Future<void> removeFavorite(String stopId) async {
    Logger.debug('Remove favori - stopId: $stopId', 'CacheService');
    
    try {
      final favorites = getFavorites();
      favorites.remove(stopId);
      await setPreference('favorites', favorites);
      Logger.info('Favori supprimé: $stopId', 'CacheService');
      Logger.debug('Total favoris restants: ${favorites.length}', 'CacheService');
    } catch (e, stackTrace) {
      Logger.error('Erreur removeFavorite', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
    }
  }

  /// Récupère tous les favoris
  Map<String, dynamic> getFavorites() {
    try {
      final favorites = getPreference<Map>('favorites', defaultValue: {});
      final result = Map<String, dynamic>.from(favorites ?? {});
      Logger.debug('Favoris récupérés: ${result.length}', 'CacheService');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Erreur getFavorites', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
      return {};
    }
  }

  /// Vérifie si un arrêt est en favori
  bool isFavorite(String stopId) {
    try {
      final favorites = getFavorites();
      final isFav = favorites.containsKey(stopId);
      Logger.debug('Check favori $stopId: $isFav', 'CacheService');
      return isFav;
    } catch (e, stackTrace) {
      Logger.error('Erreur isFavorite', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
      return false;
    }
  }

  // ============= HISTORIQUE =============

  /// Ajoute une recherche à l'historique
  Future<void> addToHistory(Map<String, dynamic> searchData) async {
    Logger.debug('Add to history', 'CacheService');
    
    try {
      final history = getHistory();
      history.insert(0, searchData);

      // Limiter à 50 entrées
      if (history.length > 50) {
        final removed = history.length - 50;
        history.removeRange(50, history.length);
        Logger.debug('Historique limité - $removed entrées supprimées', 'CacheService');
      }

      await setPreference('search_history', history);
      Logger.info('Recherche ajoutée à l\'historique', 'CacheService');
      Logger.debug('Total historique: ${history.length}', 'CacheService');
    } catch (e, stackTrace) {
      Logger.error('Erreur addToHistory', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
    }
  }

  /// Récupère l'historique
  List<Map<String, dynamic>> getHistory() {
    try {
      final history = getPreference<List>('search_history', defaultValue: []);
      final result = (history ?? []).cast<Map<String, dynamic>>();
      Logger.debug('Historique récupéré: ${result.length} entrées', 'CacheService');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Erreur getHistory', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
      return [];
    }
  }

  /// Efface l'historique
  Future<void> clearHistory() async {
    Logger.info('Effacement historique', 'CacheService');
    
    try {
      final history = getHistory();
      await removePreference('search_history');
      Logger.info('Historique effacé - ${history.length} entrées supprimées', 'CacheService');
    } catch (e, stackTrace) {
      Logger.error('Erreur clearHistory', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
    }
  }

  // ============= NETTOYAGE =============

  /// Nettoie tous les caches
  Future<void> clearAllCaches() async {
    Logger.info('Nettoyage complet des caches', 'CacheService');
    
    try {
      final stopsCount = _stopsBox?.length ?? 0;
      final weatherCount = _weatherBox?.length ?? 0;
      
      await _stopsBox?.clear();
      await _weatherBox?.clear();
      
      Logger.info('Caches vidés - Stops: $stopsCount, Weather: $weatherCount', 'CacheService');
    } catch (e, stackTrace) {
      Logger.error('Erreur clearAllCaches', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
    }
  }

  /// Nettoie les caches expirés
  Future<void> cleanExpiredCaches() async {
    Logger.info('Nettoyage caches expirés', 'CacheService');
    int stopsDeleted = 0;
    int weatherDeleted = 0;
    
    try {
      // Nettoyer les arrêts de plus de 24h
      final stopsKeys = _stopsBox?.keys.toList() ?? [];
      for (final key in stopsKeys) {
        final cached = _stopsBox?.get(key);
        if (cached != null) {
          final timestamp = cached['timestamp'] as int;
          final age = DateTime.now().millisecondsSinceEpoch - timestamp;
          if (age > const Duration(hours: 24).inMilliseconds) {
            await _stopsBox?.delete(key);
            stopsDeleted++;
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
            weatherDeleted++;
          }
        }
      }
      
      Logger.info('Nettoyage terminé - Stops: $stopsDeleted, Weather: $weatherDeleted supprimés', 'CacheService');
    } catch (e, stackTrace) {
      Logger.error('Erreur cleanExpiredCaches', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
    }
  }

  /// Obtient la taille du cache
  Future<Map<String, int>> getCacheSizes() async {
    try {
      final sizes = {
        'stops': _stopsBox?.length ?? 0,
        'weather': _weatherBox?.length ?? 0,
        'preferences': _preferencesBox?.length ?? 0,
      };
      
      Logger.info('Taille des caches - Stops: ${sizes['stops']}, Weather: ${sizes['weather']}, Preferences: ${sizes['preferences']}', 'CacheService');
      return sizes;
    } catch (e, stackTrace) {
      Logger.error('Erreur getCacheSizes', 'CacheService', e);
      Logger.debug('Stack trace: $stackTrace', 'CacheService');
      return {'stops': 0, 'weather': 0, 'preferences': 0};
    }
  }
}