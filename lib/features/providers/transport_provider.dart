// =============================================================================
// TRANSPORT PROVIDER - Avec support des routes (CORRIGÉ)
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/overpass_service.dart';
import '../../core/services/cache_service.dart';

class TransportProvider with ChangeNotifier {
  final OverpassService overpassService;
  final CacheService cacheService;

  TransportProvider({
    required this.overpassService,
    required this.cacheService,
  });

  List<TransportStop> _stops = [];
  List<TransportRoute> _routes = [];
  bool _isLoading = false;
  String? _error;
  TransportType _selectedType = TransportType.all;
  double _searchRadius = 2000;
  bool _showRoutes = true;

  List<TransportStop> get stops => _stops;
  List<TransportRoute> get routes => _routes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  TransportType get selectedType => _selectedType;
  double get searchRadius => _searchRadius;
  bool get showRoutes => _showRoutes;

  /// Charge les arrêts et routes autour d'une position
  Future<void> loadStops(LatLng position, {bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await overpassService.getTransportData(
        center: position,
        radiusMeters: _searchRadius,
        type: _selectedType,
        forceRefresh: forceRefresh,
      );

      _stops = data['stops'] as List<TransportStop>;
      _routes = data['routes'] as List<TransportRoute>;
      _error = null;
    } catch (e) {
      _error = 'Erreur lors du chargement: $e';
      _stops = [];
      _routes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filtre par type de transport
  void setTransportType(TransportType type) {
    _selectedType = type;
    notifyListeners();
  }

  /// Change le rayon de recherche
  void setSearchRadius(double radius) {
    _searchRadius = radius;
    notifyListeners();
  }

  /// Toggle affichage des routes
  void toggleShowRoutes() {
    _showRoutes = !_showRoutes;
    notifyListeners();
  }

  /// Filtre les arrêts affichés
  List<TransportStop> get filteredStops {
    if (_selectedType == TransportType.all) {
      return _stops;
    }
    return _stops.where((stop) {
      return stop.availableTransports.contains(_selectedType);
    }).toList();
  }

  /// Filtre les routes affichées
  List<TransportRoute> get filteredRoutes {
    if (!_showRoutes) return [];
    
    if (_selectedType == TransportType.all) {
      return _routes;
    }
    
    return _routes.where((route) {
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

    return counts;
  }

  /// Toggle favori
  Future<void> toggleFavorite(TransportStop stop) async {
    if (cacheService.isFavorite(stop.id)) {
      await cacheService.removeFavorite(stop.id);
    } else {
      await cacheService.addFavorite(stop.id, stop.toJson());
    }
    notifyListeners();
  }

  bool isFavorite(String stopId) {
    return cacheService.isFavorite(stopId);
  }
}