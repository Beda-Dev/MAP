// =============================================================================
// LOCATION SERVICE - Gestion de la géolocalisation
// =============================================================================

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  final _positionController = StreamController<LatLng>.broadcast();

  Stream<LatLng> get positionStream => _positionController.stream;
  LatLng? get currentPosition => _currentPosition != null
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : null;

  /// Position par défaut (Abidjan, Côte d'Ivoire)
  static const LatLng defaultPosition = LatLng(5.3566, -4.0315);

  /// Initialise le service de localisation
  Future<void> initialize() async {
    await checkPermissions();
    await getCurrentPosition();
  }

  /// Vérifie et demande les permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Obtient la position actuelle
  Future<LatLng> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        return defaultPosition;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final position = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      _positionController.add(position);
      return position;
    } catch (e) {
      return defaultPosition;
    }
  }

  /// Démarre le suivi de position
  void startTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _currentPosition = position;
      _positionController.add(
        LatLng(position.latitude, position.longitude),
      );
    });
  }

  /// Arrête le suivi de position
  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Calcule la distance entre deux points
  double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}