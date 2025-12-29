// =============================================================================
// OVERPASS SERVICE - Avec support des routes de transport
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum TransportType {
  bus,
  gbaka,
  woroworo,
  taxi,
  mototaxi,
  all,
}

/// Représente une route de transport OSM
class TransportRoute {
  final String id;
  final String name;
  final String type;
  final String operator;
  final List<LatLng> geometry;
  final List<TransportStop> stops;
  final Map<String, dynamic> tags;

  TransportRoute({
    required this.id,
    required this.name,
    required this.type,
    required this.operator,
    required this.geometry,
    required this.stops,
    required this.tags,
  });

  factory TransportRoute.fromJson(Map<String, dynamic> json) {
    final tags = json['tags'] as Map<String, dynamic>? ?? {};
    
    return TransportRoute(
      id: 'route-${json['id']}',
      name: tags['name'] ?? tags['ref'] ?? 'Ligne sans nom',
      type: tags['route'] ?? 'bus',
      operator: tags['operator'] ?? 'Inconnu',
      geometry: [],
      stops: [],
      tags: tags,
    );
  }
}

class TransportStop {
  final String id;
  final String osmId;
  final String name;
  final LatLng position;
  final String type;
  final Map<String, dynamic> tags;
  final List<TransportType> availableTransports;
  final bool hasShelter;
  final bool hasBench;
  final bool isAccessible;

  TransportStop({
    required this.id,
    required this.osmId,
    required this.name,
    required this.position,
    required this.type,
    required this.tags,
    required this.availableTransports,
    this.hasShelter = false,
    this.hasBench = false,
    this.isAccessible = false,
  });

  factory TransportStop.fromJson(Map<String, dynamic> json) {
    final tags = json['tags'] as Map<String, dynamic>? ?? {};

    return TransportStop(
      id: 'stop-${json['id']}',
      osmId: json['id'].toString(),
      name: tags['name'] ?? 'Arrêt sans nom',
      position: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['lon'] as num?)?.toDouble() ?? 0.0,
      ),
      type: _determineStopType(tags),
      tags: tags,
      availableTransports: _detectTransportTypes(tags),
      hasShelter: tags['shelter'] == 'yes',
      hasBench: tags['bench'] == 'yes',
      isAccessible: tags['wheelchair'] == 'yes',
    );
  }

  static String _determineStopType(Map<String, dynamic> tags) {
    if (tags['woro_woro'] == 'yes' || tags['woro-woro'] == 'yes') {
      return 'WORO_WORO_STOP';
    }
    if (tags['gbaka'] == 'yes' || tags['minibus'] == 'yes') {
      return 'GBAKA_STOP';
    }
    if (tags['amenity'] == 'taxi') {
      return 'TAXI_STAND';
    }
    if (tags['motorcycle_taxi'] == 'yes' || tags['moto_taxi'] == 'yes') {
      return 'MOTO_TAXI_STAND';
    }
    if (tags['public_transport'] == 'station') {
      return 'STATION';
    }
    return 'BUS_STOP';
  }

  static List<TransportType> _detectTransportTypes(Map<String, dynamic> tags) {
    final types = <TransportType>[];
    final name = tags['name']?.toString().toLowerCase() ?? '';

    if (tags['highway'] == 'bus_stop' || tags['public_transport'] != null) {
      types.add(TransportType.bus);
    }
    if (tags['gbaka'] == 'yes' || tags['minibus'] == 'yes' || name.contains('gbaka')) {
      types.add(TransportType.gbaka);
    }
    if (tags['woro_woro'] == 'yes' || tags['woro-woro'] == 'yes' || name.contains('woro')) {
      types.add(TransportType.woroworo);
    }
    if (tags['amenity'] == 'taxi' || tags['taxi'] == 'yes' || name.contains('taxi')) {
      types.add(TransportType.taxi);
    }
    if (tags['motorcycle_taxi'] == 'yes' || tags['moto_taxi'] == 'yes' || name.contains('moto')) {
      types.add(TransportType.mototaxi);
    }

    return types.isEmpty ? [TransportType.bus] : types;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'osmId': osmId,
    'name': name,
    'lat': position.latitude,
    'lon': position.longitude,
    'type': type,
    'tags': tags,
    'availableTransports': availableTransports.map((e) => e.name).toList(),
    'hasShelter': hasShelter,
    'hasBench': hasBench,
    'isAccessible': isAccessible,
  };
}

class OverpassService {
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';
  static const Duration _timeout = Duration(seconds: 60);

  final http.Client _client = http.Client();
  final _stopCache = <String, List<TransportStop>>{};
  final _routeCache = <String, List<TransportRoute>>{};
  final _cacheExpiry = <String, DateTime>{};
  static const _cacheDuration = Duration(hours: 6);

  /// Récupère les arrêts ET les routes de transport
  Future<Map<String, dynamic>> getTransportData({
    required LatLng center,
    required double radiusMeters,
    TransportType type = TransportType.all,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${center.latitude},${center.longitude},$radiusMeters,$type';

    if (!forceRefresh && _isCacheValid(cacheKey)) {
      return {
        'stops': _stopCache[cacheKey] ?? [],
        'routes': _routeCache[cacheKey] ?? [],
      };
    }

    final query = _buildOverpassQueryWithRoutes(
      lat: center.latitude,
      lon: center.longitude,
      radius: radiusMeters,
      type: type,
    );

    try {
      final response = await _client.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'GbakaMap/1.0 Flutter App',
        },
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = _parseOverpassResponseWithRoutes(data);

        _stopCache[cacheKey] = result['stops'] as List<TransportStop>;
        _routeCache[cacheKey] = result['routes'] as List<TransportRoute>;
        _cacheExpiry[cacheKey] = DateTime.now().add(_cacheDuration);

        return result;
      } else {
        throw Exception('Erreur Overpass: ${response.statusCode}');
      }
    } catch (e) {
      if (_stopCache.containsKey(cacheKey)) {
        return {
          'stops': _stopCache[cacheKey] ?? [],
          'routes': _routeCache[cacheKey] ?? [],
        };
      }
      rethrow;
    }
  }

  /// Requête Overpass incluant les routes de transport
  String _buildOverpassQueryWithRoutes({
    required double lat,
    required double lon,
    required double radius,
    required TransportType type,
  }) {
    return '''
[out:json][timeout:60][maxsize:1073741824];
// Définir la zone de recherche
(
  node(around:$radius,$lat,$lon);
  way(around:$radius,$lat,$lon);
  relation(around:$radius,$lat,$lon);
)->.searchArea;

// === RELATIONS DE ROUTES DE BUS ===
(
  relation(area.searchArea)
    ["type"="route"]
    ["route"="bus"];
  relation(area.searchArea)
    ["type"="route"]
    ["route"="minibus"];
  relation(area.searchArea)
    ["type"="route"]
    ["route"="share_taxi"];
)->.busRoutes;

// Extraire les arrêts et segments
(
  // Arrêts de bus référencés
  node(r.busRoutes)["highway"="bus_stop"];
  node(r.busRoutes)["public_transport"="platform"];
  node(r.busRoutes)["public_transport"="stop_position"];
  
  // Segments de trajet
  way(r.busRoutes);
  
  // Les relations elles-mêmes
  .busRoutes;
  
  // === ARRÊTS SUPPLÉMENTAIRES ===
  node(around:$radius,$lat,$lon)["highway"="bus_stop"];
  node(around:$radius,$lat,$lon)["public_transport"="platform"];
  node(around:$radius,$lat,$lon)["public_transport"="station"];
  node(around:$radius,$lat,$lon)["amenity"="taxi"];
  node(around:$radius,$lat,$lon)["minibus"="yes"];
  node(around:$radius,$lat,$lon)["gbaka"="yes"];
  node(around:$radius,$lat,$lon)["woro_woro"="yes"];
  node(around:$radius,$lat,$lon)["motorcycle_taxi"="yes"];
);

out meta;
>;
out skel qt;
''';
  }

  /// Parse la réponse incluant routes et arrêts
  Map<String, dynamic> _parseOverpassResponseWithRoutes(Map<String, dynamic> data) {
    final elements = data['elements'] as List? ?? [];
    final stops = <TransportStop>[];
    final routes = <TransportRoute>[];
    final ways = <String, List<LatLng>>{};
    final routeMembers = <String, List<String>>{};
    
    // Premier passage: collecter ways et relations
    for (final element in elements) {
      if (element['type'] == 'way' && element['nodes'] != null) {
        ways[element['id'].toString()] = [];
      } else if (element['type'] == 'relation') {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        if (tags['type'] == 'route') {
          final route = TransportRoute.fromJson(element);
          routes.add(route);
          
          // Stocker les membres
          final members = element['members'] as List? ?? [];
          routeMembers[route.id] = members
              .where((m) => m['type'] == 'way')
              .map((m) => m['ref'].toString())
              .toList();
        }
      } else if (element['type'] == 'node' && element['lat'] != null) {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        if (tags['highway'] == 'bus_stop' || 
            tags['public_transport'] != null ||
            tags['amenity'] == 'taxi') {
          try {
            stops.add(TransportStop.fromJson(element));
          } catch (e) {
            continue;
          }
        }
      }
    }
    
    // Second passage: construire géométries des ways
    for (final element in elements) {
      if (element['type'] == 'node' && element['lat'] != null) {
        final nodeId = element['id'].toString();
        final lat = (element['lat'] as num).toDouble();
        final lon = (element['lon'] as num).toDouble();
        
        // Ajouter aux ways qui le référencent
        for (final wayEntry in ways.entries) {
          ways[wayEntry.key]!.add(LatLng(lat, lon));
        }
      }
    }
    
    // Associer géométries aux routes
    for (final route in routes) {
      final memberIds = routeMembers[route.id] ?? [];
      final geometry = <LatLng>[];
      
      for (final wayId in memberIds) {
        if (ways.containsKey(wayId)) {
          geometry.addAll(ways[wayId]!);
        }
      }
      
      // Mise à jour avec la géométrie
      routes[routes.indexOf(route)] = TransportRoute(
        id: route.id,
        name: route.name,
        type: route.type,
        operator: route.operator,
        geometry: geometry,
        stops: route.stops,
        tags: route.tags,
      );
    }

    return {
      'stops': _removeDuplicatesByProximity(stops),
      'routes': routes,
    };
  }

  /// Supprime les doublons par proximité
  List<TransportStop> _removeDuplicatesByProximity(List<TransportStop> stops) {
    if (stops.isEmpty) return stops;

    final filtered = <TransportStop>[];
    const Distance distance = Distance();

    for (final stop in stops) {
      bool isDuplicate = false;

      for (final existing in filtered) {
        final dist = distance.as(
          LengthUnit.Meter,
          stop.position,
          existing.position,
        );

        if (dist < 50) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        filtered.add(stop);
      }
    }

    return filtered;
  }

  bool _isCacheValid(String key) {
    if (!_cacheExpiry.containsKey(key)) return false;
    return DateTime.now().isBefore(_cacheExpiry[key]!);
  }

  void clearCache() {
    _stopCache.clear();
    _routeCache.clear();
    _cacheExpiry.clear();
  }

  void dispose() {
    _client.close();
    clearCache();
  }
}