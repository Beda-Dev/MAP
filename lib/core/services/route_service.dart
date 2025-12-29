// =============================================================================
// ROUTE SERVICE - Calcul d'itinéraires avec OSRM
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Mode de transport pour le calcul d'itinéraire
enum RouteMode {
  driving,
  walking,
  cycling,
}

/// Étape de navigation
class RouteStep {
  final double distance;
  final double duration;
  final String instruction;
  final String name;
  final LatLng location;
  final String maneuver;

  RouteStep({
    required this.distance,
    required this.duration,
    required this.instruction,
    required this.name,
    required this.location,
    required this.maneuver,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'] as Map<String, dynamic>;
    final location = maneuver['location'] as List;

    return RouteStep(
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      instruction: maneuver['instruction'] as String? ?? '',
      name: json['name'] as String? ?? '',
      location: LatLng(location[1], location[0]),
      maneuver: maneuver['type'] as String? ?? '',
    );
  }
}

/// Tronçon d'itinéraire
class RouteLeg {
  final double distance;
  final double duration;
  final String summary;
  final List<RouteStep> steps;

  RouteLeg({
    required this.distance,
    required this.duration,
    required this.summary,
    required this.steps,
  });

  factory RouteLeg.fromJson(Map<String, dynamic> json) {
    final steps = (json['steps'] as List)
        .map((step) => RouteStep.fromJson(step))
        .toList();

    return RouteLeg(
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      summary: json['summary'] as String? ?? '',
      steps: steps,
    );
  }
}

/// Itinéraire complet
class Route {
  final double distance;
  final double duration;
  final List<LatLng> geometry;
  final List<RouteLeg> legs;
  final String summary;

  Route({
    required this.distance,
    required this.duration,
    required this.geometry,
    required this.legs,
    required this.summary,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    final geometry = _decodePolyline(json['geometry'] as String);
    final legs = (json['legs'] as List)
        .map((leg) => RouteLeg.fromJson(leg))
        .toList();

    return Route(
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      geometry: geometry,
      legs: legs,
      summary: legs.isNotEmpty ? legs.first.summary : '',
    );
  }

  /// Decode polyline (format Google/OSRM)
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  String get formattedDistance {
    if (distance < 1000) {
      return '${distance.round()} m';
    }
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final minutes = (duration / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours h $remainingMinutes min';
  }
}

/// Suggestion de transport
class TransportSuggestion {
  final String mode;
  final String reason;
  final Map<String, int> priceRange;
  final int duration;
  final double distance;
  final List<String> pros;
  final List<String> cons;
  final String availability;
  final int weatherScore;
  final int overallScore;
  final List<String> advice;
  final int rank;

  TransportSuggestion({
    required this.mode,
    required this.reason,
    required this.priceRange,
    required this.duration,
    required this.distance,
    required this.pros,
    required this.cons,
    required this.availability,
    required this.weatherScore,
    required this.overallScore,
    required this.advice,
    required this.rank,
  });

  String get modeIcon {
    switch (mode.toLowerCase()) {
      case 'bus':
        return '🚌';
      case 'gbaka':
        return '🚐';
      case 'woro_woro':
        return '🚕';
      case 'taxi':
        return '🚖';
      case 'moto_taxi':
        return '🏍️';
      case 'walking':
        return '🚶';
      default:
        return '🚗';
    }
  }

  String get formattedPrice {
    return '${priceRange['min']} - ${priceRange['max']} FCFA';
  }
}

/// Service de calcul d'itinéraires
class RouteService {
  static const String _osrmUrl = 'https://router.project-osrm.org';
  final http.Client _client = http.Client();

  /// Calcule un itinéraire entre deux points
  Future<List<Route>> calculateRoute({
    required LatLng from,
    required LatLng to,
    RouteMode mode = RouteMode.driving,
    bool alternatives = false,
    List<LatLng>? waypoints,
  }) async {
    try {
      final profile = _getModeProfile(mode);

      // Construire les coordonnées
      final coords = <LatLng>[from, ...?waypoints, to];
      final coordsStr = coords
          .map((point) => '${point.longitude},${point.latitude}')
          .join(';');

      final url = Uri.parse(
          '$_osrmUrl/route/v1/$profile/$coordsStr'
              '?overview=full'
              '&geometries=polyline'
              '&steps=true'
              '&alternatives=${alternatives ? 'true' : 'false'}'
      );

      final response = await _client.get(url).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok') {
          final routes = (data['routes'] as List)
              .map((route) => Route.fromJson(route))
              .toList();

          return routes;
        } else {
          throw Exception('OSRM Error: ${data['code']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur calcul itinéraire: $e');
    }
  }

  /// Génère des suggestions de transport
  List<TransportSuggestion> generateTransportSuggestions({
    required double distanceMeters,
    required int durationSeconds,
    required bool isRaining,
    required double temperature,
  }) {
    final suggestions = <TransportSuggestion>[];

    // Moto-taxi
    if (distanceMeters < 10000) {
      final score = _calculateScore(
        distanceMeters: distanceMeters,
        baseScore: 85,
        isRaining: isRaining,
        rainPenalty: 60,
      );

      suggestions.add(TransportSuggestion(
        mode: 'moto_taxi',
        reason: 'Évite les embouteillages efficacement',
        priceRange: {
          'min': _estimatePrice(distanceMeters, 0.04),
          'max': _estimatePrice(distanceMeters, 0.08),
        },
        duration: (durationSeconds * 0.6).toInt(),
        distance: distanceMeters,
        pros: ['Très rapide', 'Évite embouteillages', 'Disponible partout'],
        cons: ['Moins sûr', 'Dépend météo', 'Pas de confort'],
        availability: 'high',
        weatherScore: isRaining ? 25 : 80,
        overallScore: score,
        advice: [
          'Négociez le prix avant',
          'Portez un casque',
          if (isRaining) 'Déconseillé sous la pluie',
        ],
        rank: isRaining ? 4 : 1,
      ));
    }

    // Gbaka
    if (distanceMeters > 1000 && distanceMeters < 20000) {
      final score = _calculateScore(
        distanceMeters: distanceMeters,
        baseScore: 78,
        isRaining: isRaining,
        rainPenalty: 20,
      );

      suggestions.add(TransportSuggestion(
        mode: 'gbaka',
        reason: 'Bon compromis prix/confort',
        priceRange: {
          'min': 100,
          'max': 250,
        },
        duration: (durationSeconds * 1.5).toInt(),
        distance: distanceMeters,
        pros: ['Économique', 'Fréquent', 'Dessert bien les quartiers'],
        cons: ['Plus lent', 'Bondé', 'Confort minimal'],
        availability: 'high',
        weatherScore: isRaining ? 60 : 70,
        overallScore: score,
        advice: [
          'Préparez la monnaie',
          'Évitez heures de pointe',
        ],
        rank: 2,
      ));
    }

    // Bus SOTRA
    if (distanceMeters > 2000) {
      final score = _calculateScore(
        distanceMeters: distanceMeters,
        baseScore: 75,
        isRaining: isRaining,
        rainPenalty: 0,
      );

      suggestions.add(TransportSuggestion(
        mode: 'bus',
        reason: 'Transport public climatisé',
        priceRange: {
          'min': 200,
          'max': 500,
        },
        duration: (durationSeconds * 1.3).toInt(),
        distance: distanceMeters,
        pros: ['Climatisé', 'Confortable', 'Prix fixe', 'Sécurisé'],
        cons: ['Couverture limitée', 'Horaires contraints'],
        availability: 'medium',
        weatherScore: 85,
        overallScore: score,
        advice: [
          'Vérifiez les horaires',
          'Idéal sous la pluie',
        ],
        rank: isRaining ? 1 : 3,
      ));
    }

    // Taxi
    if (distanceMeters > 1000) {
      final score = _calculateScore(
        distanceMeters: distanceMeters,
        baseScore: 70,
        isRaining: isRaining,
        rainPenalty: 10,
      );

      suggestions.add(TransportSuggestion(
        mode: 'taxi',
        reason: 'Confort et flexibilité',
        priceRange: {
          'min': _estimatePrice(distanceMeters, 0.06),
          'max': _estimatePrice(distanceMeters, 0.12),
        },
        duration: durationSeconds,
        distance: distanceMeters,
        pros: ['Confortable', 'Direct', 'Flexible'],
        cons: ['Plus cher', 'Négociation nécessaire'],
        availability: 'medium',
        weatherScore: 75,
        overallScore: score,
        advice: [
          'Négociez le prix',
          'Vérifiez le compteur',
        ],
        rank: 4,
      ));
    }

    // Marche
    if (distanceMeters < 2000) {
      final score = _calculateScore(
        distanceMeters: distanceMeters,
        baseScore: 80,
        isRaining: isRaining,
        rainPenalty: 50,
      );

      suggestions.add(TransportSuggestion(
        mode: 'walking',
        reason: 'Gratuit et bon pour la santé',
        priceRange: {'min': 0, 'max': 0},
        duration: (distanceMeters / 1.4).toInt(),
        distance: distanceMeters,
        pros: ['Gratuit', 'Santé', 'Pas d\'attente'],
        cons: ['Lent', 'Fatiguant', 'Dépend météo'],
        availability: 'high',
        weatherScore: isRaining ? 30 : (temperature > 35 ? 50 : 85),
        overallScore: score,
        advice: [
          if (temperature > 32) 'Hydratez-vous bien',
          if (isRaining) 'Prenez un parapluie',
          'Utilisez les passages piétons',
        ],
        rank: (isRaining || temperature > 35) ? 5 : 3,
      ));
    }

    // Trier par score
    suggestions.sort((a, b) => b.overallScore.compareTo(a.overallScore));

    // Mettre à jour les rangs
    for (var i = 0; i < suggestions.length; i++) {
      suggestions[i] = TransportSuggestion(
        mode: suggestions[i].mode,
        reason: suggestions[i].reason,
        priceRange: suggestions[i].priceRange,
        duration: suggestions[i].duration,
        distance: suggestions[i].distance,
        pros: suggestions[i].pros,
        cons: suggestions[i].cons,
        availability: suggestions[i].availability,
        weatherScore: suggestions[i].weatherScore,
        overallScore: suggestions[i].overallScore,
        advice: suggestions[i].advice,
        rank: i + 1,
      );
    }

    return suggestions;
  }

  int _calculateScore({
    required double distanceMeters,
    required int baseScore,
    required bool isRaining,
    required int rainPenalty,
  }) {
    var score = baseScore;

    if (isRaining) {
      score -= rainPenalty;
    }

    return score.clamp(0, 100);
  }

  int _estimatePrice(double distanceMeters, double ratePerMeter) {
    return (distanceMeters * ratePerMeter).round();
  }

  String _getModeProfile(RouteMode mode) {
    switch (mode) {
      case RouteMode.driving:
        return 'driving';
      case RouteMode.walking:
        return 'foot';
      case RouteMode.cycling:
        return 'bike';
    }
  }

  void dispose() {
    _client.close();
  }
}