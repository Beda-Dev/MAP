// =============================================================================
// PROVIDERS - Gestion d'état avec Provider
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/overpass_service.dart';
import '../../core/services/weather_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/cache_service.dart';
import 'transport_provider.dart';


// =============================================================================
// MAP PROVIDER - Gestion de l'état de la carte
// =============================================================================

class MapProvider with ChangeNotifier {
  final LocationService locationService;
  final TransportProvider transportProvider;

  MapProvider({
    required this.locationService,
    required this.transportProvider,
  });

  final MapController mapController = MapController();
  LatLng _center = LocationService.defaultPosition;
  double _zoom = 13.0;
  bool _followLocation = false;
  bool _isInitialized = false;

  LatLng get center => _center;
  double get zoom => _zoom;
  bool get followLocation => _followLocation;
  bool get isInitialized => _isInitialized;

  /// Initialise la carte avec la position actuelle
  Future<void> initialize() async {
    if (_isInitialized) return;

    final position = await locationService.getCurrentPosition();
    _center = position;
    _isInitialized = true;

    // Charger les arrêts initiaux
    await transportProvider.loadStops(position);

    notifyListeners();
  }

  /// Centre la carte sur une position
  void centerOn(LatLng position, {double? zoom}) {
    _center = position;
    if (zoom != null) _zoom = zoom;

    mapController.move(position, zoom ?? _zoom);
    notifyListeners();
  }

  /// Active/désactive le suivi de position
  void toggleFollowLocation() {
    _followLocation = !_followLocation;

    if (_followLocation) {
      locationService.startTracking();

      // Écouter les changements de position
      locationService.positionStream.listen((position) {
        if (_followLocation) {
          centerOn(position);
        }
      });
    } else {
      locationService.stopTracking();
    }

    notifyListeners();
  }

  /// Centre la carte sur la position actuelle
  Future<void> centerOnCurrentLocation() async {
    final position = await locationService.getCurrentPosition();
    centerOn(position, zoom: 15.0);

    // Recharger les arrêts
    await transportProvider.loadStops(position);
  }

  /// Zoom in
  void zoomIn() {
    _zoom = (_zoom + 1).clamp(3.0, 19.0);
    mapController.move(_center, _zoom);
    notifyListeners();
  }

  /// Zoom out
  void zoomOut() {
    _zoom = (_zoom - 1).clamp(3.0, 19.0);
    mapController.move(_center, _zoom);
    notifyListeners();
  }

  /// Mise à jour du centre et zoom (appelé par la carte)
  void updatePosition(LatLng newCenter, double newZoom) {
    _center = newCenter;
    _zoom = newZoom;
    notifyListeners();
  }

  /// Recharge les arrêts à la position actuelle
  Future<void> refreshStops({bool forceRefresh = false}) async {
    await transportProvider.loadStops(_center, forceRefresh: forceRefresh);
  }
}

