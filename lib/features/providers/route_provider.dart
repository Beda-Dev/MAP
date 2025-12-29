// =============================================================================
// ROUTE PROVIDER - Gestion des itinéraires (CORRIGÉ)
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/route_service.dart';

class RouteProvider with ChangeNotifier {
  final RouteService routeService;

  RouteProvider({required this.routeService});

  // État de l'itinéraire
  LatLng? _from;
  LatLng? _to;
  String _fromAddress = '';

  String _toAddress = '';
  Route? _currentRoute;
  List<TransportSuggestion> _suggestions = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  LatLng? get from => _from;
  LatLng? get to => _to;
  String get fromAddress => _fromAddress;
  String get toAddress => _toAddress;
  Route? get currentRoute => _currentRoute;
  List<TransportSuggestion> get suggestions => _suggestions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get canCalculateRoute => _from != null && _to != null;

  // Définir le point de départ
  void setFrom(LatLng position, {String? address}) {
    _from = position;
    _fromAddress = address ?? 'Position sélectionnée';
    _error = null;
    notifyListeners();
  }

  // Définir le point d'arrivée
  void setTo(LatLng position, {String? address}) {
    _to = position;
    _toAddress = address ?? 'Destination sélectionnée';
    _error = null;
    notifyListeners();
  }

  // Effacer le départ
  void clearFrom() {
    _from = null;
    _fromAddress = '';
    _currentRoute = null;
    _suggestions = [];
    notifyListeners();
  }

  // Effacer l'arrivée
  void clearTo() {
    _to = null;
    _toAddress = '';
    _currentRoute = null;
    _suggestions = [];
    notifyListeners();
  }

  // Inverser départ et arrivée
  void swapLocations() {
    if (_from == null || _to == null) return;

    final tempPos = _from;
    final tempAddr = _fromAddress;

    _from = _to;
    _fromAddress = _toAddress;
    _to = tempPos;
    _toAddress = tempAddr;

    notifyListeners();
  }

  // Calculer l'itinéraire
  Future<void> calculateRoute() async {
    if (!canCalculateRoute) {
      _error = 'Veuillez définir un point de départ et d\'arrivée';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final routes = await routeService.calculateRoute(
        from: _from!,
        to: _to!,
        mode: RouteMode.driving,
        alternatives: false,
      );

      if (routes.isNotEmpty) {
        _currentRoute = routes.first;
        _error = null;
      } else {
        _error = 'Aucun itinéraire trouvé';
        _currentRoute = null;
      }
    } catch (e) {
      _error = 'Erreur lors du calcul: ${e.toString()}';
      _currentRoute = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Générer les suggestions de transport
  void generateSuggestions({
    required bool isRaining,
    required double temperature,
  }) {
    if (_currentRoute == null) return;

    _suggestions = routeService.generateTransportSuggestions(
      distanceMeters: _currentRoute!.distance,
      durationSeconds: _currentRoute!.duration.toInt(),
      isRaining: isRaining,
      temperature: temperature,
    );

    notifyListeners();
  }

  // Nettoyer l'état
  void clear() {
    _from = null;
    _to = null;
    _fromAddress = '';
    _toAddress = '';
    _currentRoute = null;
    _suggestions = [];
    _error = null;
    notifyListeners();
  }
}