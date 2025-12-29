// =============================================================================
// TRANSPORT PROVIDER - Avec gestion optimisée (CORRIGÉ)
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math';

import '../../core/services/overpass_service.dart';
import '../../core/services/cache_service.dart';
import '../../core/config/env_config.dart';

class TransportProvider with ChangeNotifier {
  final OverpassService overpassService;
  final CacheService cacheService;

  TransportProvider({
    required this.overpassService,
    required this.cacheService,
  }) {
    Logger.info('TransportProvider initialisé', 'TransportProvider');
    Logger.debug('Configuration - Rayon: ${EnvConfig.searchRadiusMeters}m', 'TransportProvider');
    Logger.debug('Configuration - Distance reload: ${EnvConfig.minDistanceForReload}m', 'TransportProvider');
  }

  List<TransportStop> _stops = [];
  List<TransportRoute> _routes = [];
  bool _isLoading = false;
  String? _error;
  TransportType _selectedType = TransportType.all;
  double _searchRadius = EnvConfig.searchRadiusMeters;
  bool _showRoutes = false;
  
  // Cache de position pour éviter les rechargements inutiles
  LatLng? _lastLoadedPosition;
  DateTime? _lastLoadTime;
  static const _minLoadInterval = Duration(seconds: 10);
  static const _minDistanceForReload = 500.0; // mètres - valeur constante

  List<TransportStop> get stops => _stops;
  List<TransportRoute> get routes => _routes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  TransportType get selectedType => _selectedType;
  double get searchRadius => _searchRadius;
  bool get showRoutes => _showRoutes;

  /// Charge les arrêts et routes autour d'une position
  Future<void> loadStops(LatLng position, {bool forceRefresh = false}) async {
    Logger.debug('Début loadStops', 'TransportProvider');
    Logger.debug('Position: ${position.latitude}, ${position.longitude}', 'TransportProvider');
    Logger.debug('Force refresh: $forceRefresh', 'TransportProvider');
    
    // Éviter les rechargements trop fréquents
    if (!forceRefresh && _shouldSkipLoad(position)) {
      Logger.info('Chargement ignoré (trop récent ou trop proche)', 'TransportProvider');
      return;
    }

    if (_isLoading) {
      Logger.warning('Chargement déjà en cours', 'TransportProvider');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    
    Logger.info('Début chargement des données de transport', 'TransportProvider');

    try {
      // Utiliser compute pour éviter de bloquer le thread principal
      final data = await compute(_loadTransportDataInBackground, {
        'position': position,
        'radius': _searchRadius,
        'type': _selectedType,
        'forceRefresh': forceRefresh,
        'timeout': EnvConfig.apiTimeoutSeconds,
      });

      _stops = data['stops'] as List<TransportStop>;
      _routes = data['routes'] as List<TransportRoute>;
      _error = null;
      _lastLoadedPosition = position;
      _lastLoadTime = DateTime.now();

      Logger.info('Chargé ${_stops.length} arrêts et ${_routes.length} routes', 'TransportProvider');
      Logger.debug('Types de transport disponibles: ${_getAvailableTransportTypes()}', 'TransportProvider');
    } catch (e, stackTrace) {
      _error = 'Erreur: $e';
      Logger.error('Erreur chargement transport', 'TransportProvider', e);
      Logger.debug('Stack trace: $stackTrace', 'TransportProvider');
      
      // En cas d'erreur, ne pas vider les données existantes
      if (_stops.isEmpty) {
        _stops = [];
        _routes = [];
        Logger.warning('Données vidées suite à erreur', 'TransportProvider');
      } else {
        Logger.info('Conservation des données existantes (${_stops.length} arrêts)', 'TransportProvider');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
      Logger.debug('loadStops terminé, notifyListeners appelé', 'TransportProvider');
    }
  }

  /// Fonction isolée pour le chargement des données (évite de bloquer le thread principal)
  static Future<Map<String, dynamic>> _loadTransportDataInBackground(Map<String, dynamic> params) async {
    final position = params['position'] as LatLng;
    final radius = params['radius'] as double;
    final type = params['type'] as TransportType;
    final forceRefresh = params['forceRefresh'] as bool;
    final timeout = params['timeout'] as int;

    // Créer les services dans l'isolat
    final overpassService = OverpassService();
    
    try {
      final data = await overpassService.getTransportData(
        center: position,
        radiusMeters: radius,
        type: type,
        forceRefresh: forceRefresh,
      ).timeout(Duration(seconds: timeout));
      
      return data;
    } finally {
      overpassService.dispose();
    }
  }

  /// Vérifie si on doit ignorer le chargement
  bool _shouldSkipLoad(LatLng newPosition) {
    Logger.debug('Vérification skip load', 'TransportProvider');
    
    // Si pas de position précédente, charger
    if (_lastLoadedPosition == null || _lastLoadTime == null) {
      Logger.debug('Premier chargement - pas de position précédente', 'TransportProvider');
      return false;
    }

    // Vérifier l'intervalle de temps
    final timeSinceLastLoad = DateTime.now().difference(_lastLoadTime!);
    Logger.debug('Temps depuis dernier chargement: ${timeSinceLastLoad.inSeconds}s', 'TransportProvider');
    
    if (timeSinceLastLoad < _minLoadInterval) {
      Logger.info('Intervalle trop court: ${timeSinceLastLoad.inSeconds}s < ${_minLoadInterval.inSeconds}s', 'TransportProvider');
      return true;
    }

    // Vérifier la distance
    final distance = _calculateDistance(_lastLoadedPosition!, newPosition);
    Logger.debug('Distance depuis dernière position: ${distance.toStringAsFixed(1)}m', 'TransportProvider');
    
    if (distance < _minDistanceForReload) {
      Logger.info('Distance trop courte: ${distance.toStringAsFixed(1)}m < ${_minDistanceForReload}m', 'TransportProvider');
      return true;
    }

    Logger.debug('Chargement nécessaire', 'TransportProvider');
    return false;
  }

  /// Calcule la distance entre deux points (approximatif)
  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000; // mètres
    
    final lat1 = p1.latitude * (3.14159265359 / 180);
    final lat2 = p2.latitude * (3.14159265359 / 180);
    final dLat = (p2.latitude - p1.latitude) * (3.14159265359 / 180);
    final dLon = (p2.longitude - p1.longitude) * (3.14159265359 / 180);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    final distance = earthRadius * c;
    Logger.debug('Distance calculée: ${distance.toStringAsFixed(1)}m', 'TransportProvider');
    
    return distance;
  }

  /// Filtre par type de transport
  void setTransportType(TransportType type) {
    Logger.debug('setTransportType: $type -> $_selectedType', 'TransportProvider');
    
    if (_selectedType == type) {
      Logger.debug('Type inchangé, annulation', 'TransportProvider');
      return;
    }
    
    _selectedType = type;
    Logger.info('Type de transport changé: $type', 'TransportProvider');
    notifyListeners();
    
    // Recharger si nécessaire
    if (_lastLoadedPosition != null) {
      Logger.info('Rechargement avec nouveau type', 'TransportProvider');
      loadStops(_lastLoadedPosition!, forceRefresh: true);
    } else {
      Logger.debug('Pas de position précédente, pas de rechargement', 'TransportProvider');
    }
  }

  /// Change le rayon de recherche
  void setSearchRadius(double radius) {
    Logger.debug('setSearchRadius: ${radius}m -> ${_searchRadius}m', 'TransportProvider');
    
    if (_searchRadius == radius) {
      Logger.debug('Rayon inchangé, annulation', 'TransportProvider');
      return;
    }
    
    _searchRadius = radius;
    Logger.info('Rayon de recherche changé: ${radius}m', 'TransportProvider');
    notifyListeners();
    
    // Recharger avec le nouveau rayon
    if (_lastLoadedPosition != null) {
      Logger.info('Rechargement avec nouveau rayon', 'TransportProvider');
      loadStops(_lastLoadedPosition!, forceRefresh: true);
    } else {
      Logger.debug('Pas de position précédente, pas de rechargement', 'TransportProvider');
    }
  }

  /// Toggle affichage des routes
  void toggleShowRoutes() {
    final oldValue = _showRoutes;
    _showRoutes = !_showRoutes;
    Logger.info('Toggle showRoutes: $oldValue -> $_showRoutes', 'TransportProvider');
    notifyListeners();
    
    // Si on active les routes et qu'elles ne sont pas chargées
    if (_showRoutes && _routes.isEmpty && _lastLoadedPosition != null) {
      Logger.info('Activation routes + chargement', 'TransportProvider');
      loadStops(_lastLoadedPosition!, forceRefresh: true);
    } else if (_showRoutes && !_routes.isEmpty) {
      Logger.info('Routes activées (${_routes.length} disponibles)', 'TransportProvider');
    } else {
      Logger.info('Routes désactivées', 'TransportProvider');
    }
  }

  /// Filtre les arrêts affichés
  List<TransportStop> get filteredStops {
    if (_selectedType == TransportType.all) {
      Logger.debug('Filtrage: tous les types (${_stops.length} arrêts)', 'TransportProvider');
      return _stops;
    }
    
    final filtered = _stops.where((stop) {
      return stop.availableTransports.contains(_selectedType);
    }).toList();
    
    Logger.debug('Filtrage: $_selectedType (${filtered.length}/${_stops.length} arrêts)', 'TransportProvider');
    return filtered;
  }

  /// Filtre les routes affichées
  List<TransportRoute> get filteredRoutes {
    if (!_showRoutes) {
      Logger.debug('Routes masquées', 'TransportProvider');
      return [];
    }
    
    if (_selectedType == TransportType.all) {
      Logger.debug('Routes: tous les types (${_routes.length} routes)', 'TransportProvider');
      return _routes;
    }
    
    final filtered = _routes.where((route) {
      switch (_selectedType) {
        case TransportType.bus:
          return route.type == 'bus';
        case TransportType.gbaka:
          return route.type == 'minibus' || route.name.toLowerCase().contains('gbaka');
        case TransportType.woroworo:
          return route.name.toLowerCase().contains('woro');
        case TransportType.taxi:
          return route.type == 'share_taxi';
        default:
          return true;
      }
    }).toList();
    
    Logger.debug('Routes filtrées: $_selectedType (${filtered.length}/${_routes.length} routes)', 'TransportProvider');
    return filtered;
  }

  /// Compte les arrêts par type
  Map<TransportType, int> getStopCounts() {
    final counts = <TransportType, int>{
      TransportType.bus: 0,
      TransportType.gbaka: 0,
      TransportType.woroworo: 0,
      TransportType.taxi: 0,
      TransportType.mototaxi: 0,
    };

    for (final stop in _stops) {
      for (final type in stop.availableTransports) {
        counts[type] = (counts[type] ?? 0) + 1;
      }
    }

    Logger.debug('Comptage arrêts: $counts', 'TransportProvider');
    return counts;
  }

  /// Toggle favori
  Future<void> toggleFavorite(TransportStop stop) async {
    Logger.debug('Toggle favori: ${stop.name} (${stop.id})', 'TransportProvider');
    
    try {
      final isCurrentlyFavorite = cacheService.isFavorite(stop.id);
      
      if (isCurrentlyFavorite) {
        await cacheService.removeFavorite(stop.id);
        Logger.info('Favori supprimé: ${stop.name}', 'TransportProvider');
      } else {
        await cacheService.addFavorite(stop.id, stop.toJson());
        Logger.info('Favori ajouté: ${stop.name}', 'TransportProvider');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('Erreur toggle favori', 'TransportProvider', e);
      Logger.debug('Stack trace: $stackTrace', 'TransportProvider');
    }
  }

  bool isFavorite(String stopId) {
    final result = cacheService.isFavorite(stopId);
    Logger.debug('Check favori $stopId: $result', 'TransportProvider');
    return result;
  }

  /// Force le rechargement
  void forceReload() {
    Logger.info('Force reload demandé', 'TransportProvider');
    _lastLoadedPosition = null;
    _lastLoadTime = null;
    Logger.debug('Cache position vidé', 'TransportProvider');
  }
  
  /// Helper pour obtenir les types de transport disponibles
  String _getAvailableTransportTypes() {
    final types = <String>[];
    for (final stop in _stops) {
      for (final type in stop.availableTransports) {
        if (!types.contains(type.name)) {
          types.add(type.name);
        }
      }
    }
    return types.join(', ');
  }
}