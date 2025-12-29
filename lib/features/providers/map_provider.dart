// =============================================================================
// MAP PROVIDER - Gestion d'état de la carte (Optimisé)
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

import '../../core/services/location_service.dart';
import 'transport_provider.dart';

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
  bool _isLoading = false;

  StreamSubscription<LatLng>? _positionSubscription;
  Timer? _loadDebounceTimer;

  LatLng get center => _center;
  double get zoom => _zoom;
  bool get followLocation => _followLocation;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  /// Initialise la carte avec la position actuelle (non bloquant)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Utiliser la position par défaut immédiatement
      _center = LocationService.defaultPosition;
      _isInitialized = true;
      notifyListeners();

      // Charger la position réelle en arrière-plan
      _loadCurrentPositionAsync();

      // Charger les arrêts initiaux (limité)
      await _loadStopsDebounced(_center);
    } catch (e) {
      debugPrint('Erreur initialisation carte: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Charge la position actuelle de manière asynchrone
  void _loadCurrentPositionAsync() {
    locationService.getCurrentPosition().then((position) {
      if (_center.latitude == LocationService.defaultPosition.latitude &&
          _center.longitude == LocationService.defaultPosition.longitude) {
        _center = position;
        mapController.move(position, _zoom);
        notifyListeners();
        
        // Recharger les arrêts à la vraie position
        _loadStopsDebounced(position);
      }
    }).catchError((error) {
      debugPrint('Erreur récupération position: $error');
    });
  }

  /// Centre la carte sur une position
  void centerOn(LatLng position, {double? zoom}) {
    _center = position;
    if (zoom != null) _zoom = zoom;

    try {
      mapController.move(position, zoom ?? _zoom);
    } catch (e) {
      debugPrint('Erreur centrage carte: $e');
    }
    
    notifyListeners();
  }

  /// Active/désactive le suivi de position
  void toggleFollowLocation() {
    _followLocation = !_followLocation;

    if (_followLocation) {
      locationService.startTracking();

      // Annuler l'ancienne souscription
      _positionSubscription?.cancel();

      // Écouter les changements de position
      _positionSubscription = locationService.positionStream.listen((position) {
        if (_followLocation) {
          _center = position;
          try {
            mapController.move(position, _zoom);
          } catch (e) {
            debugPrint('Erreur suivi position: $e');
          }
          notifyListeners();
        }
      });
    } else {
      locationService.stopTracking();
      _positionSubscription?.cancel();
      _positionSubscription = null;
    }

    notifyListeners();
  }

  /// Centre la carte sur la position actuelle
  Future<void> centerOnCurrentLocation() async {
    try {
      final position = await locationService.getCurrentPosition();
      centerOn(position, zoom: 15.0);

      // Recharger les arrêts
      await _loadStopsDebounced(position);
    } catch (e) {
      debugPrint('Erreur centrage position actuelle: $e');
    }
  }

  /// Zoom in
  void zoomIn() {
    _zoom = (_zoom + 1).clamp(3.0, 19.0);
    try {
      mapController.move(_center, _zoom);
    } catch (e) {
      debugPrint('Erreur zoom in: $e');
    }
    notifyListeners();
  }

  /// Zoom out
  void zoomOut() {
    _zoom = (_zoom - 1).clamp(3.0, 19.0);
    try {
      mapController.move(_center, _zoom);
    } catch (e) {
      debugPrint('Erreur zoom out: $e');
    }
    notifyListeners();
  }

  /// Mise à jour du centre et zoom (appelé par la carte)
  void updatePosition(LatLng newCenter, double newZoom) {
    _center = newCenter;
    _zoom = newZoom;
    
    // Charger les arrêts avec debounce
    _loadStopsDebounced(newCenter);
    
    notifyListeners();
  }

  /// Charge les arrêts avec debounce pour éviter trop de requêtes
  Future<void> _loadStopsDebounced(LatLng position) async {
    // Annuler le timer précédent
    _loadDebounceTimer?.cancel();

    // Créer un nouveau timer
    _loadDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadStops(position);
    });
  }

  /// Charge les arrêts (interne)
  Future<void> _loadStops(LatLng position) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      await transportProvider.loadStops(position, forceRefresh: false);
    } catch (e) {
      debugPrint('Erreur chargement arrêts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recharge les arrêts à la position actuelle
  Future<void> refreshStops({bool forceRefresh = false}) async {
    await transportProvider.loadStops(_center, forceRefresh: forceRefresh);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _loadDebounceTimer?.cancel();
    super.dispose();
  }
}