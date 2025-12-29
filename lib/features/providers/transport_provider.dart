
// =============================================================================
// PROVIDERS - Gestion d'état avec Provider
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/overpass_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/cache_service.dart';

// =============================================================================
// TRANSPORT PROVIDER - Gestion des données de transport
// =============================================================================

class TransportProvider with ChangeNotifier {
  final OverpassService overpassService;
  final CacheService cacheService;

  TransportProvider({
    required this.overpassService,
    required this.cacheService,
  });

  List<TransportStop> _stops = [];
  bool _isLoading = false;
  String? _error;
  TransportType _selectedType = TransportType.all;
  double _searchRadius = 2000;

  List<TransportStop> get stops => _stops;
  bool get isLoading => _isLoading;
  String? get error => _error;
  TransportType get selectedType => _selectedType;
  double get searchRadius => _searchRadius;

  /// Charge les arrêts autour d'une position
  Future<void> loadStops(LatLng position, {bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stops = await overpassService.getStopsInArea(
        center: position,
        radiusMeters: _searchRadius,
        type: _selectedType,
        forceRefresh: forceRefresh,
      );
      _error = null;
    } catch (e) {
      _error = 'Erreur lors du chargement des arrêts: $e';
      _stops = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filtre les arrêts par type
  void setTransportType(TransportType type) {
    _selectedType = type;
    notifyListeners();
  }

  /// Change le rayon de recherche
  void setSearchRadius(double radius) {
    _searchRadius = radius;
    notifyListeners();
  }

  /// Filtre les arrêts affichés selon le type sélectionné
  List<TransportStop> get filteredStops {
    if (_selectedType == TransportType.all) {
      return _stops;
    }

    return _stops.where((stop) {
      return stop.availableTransports.contains(_selectedType);
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