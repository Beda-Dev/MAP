// =============================================================================
// OVERPASS SERVICE - Avec support des routes de transport
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/env_config.dart';

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

  OverpassService() {
    Logger.info('OverpassService initialisé', 'OverpassService');
    Logger.debug('URL API: $_baseUrl', 'OverpassService');
    Logger.debug('Timeout: ${_timeout.inSeconds}s', 'OverpassService');
    Logger.debug('Durée cache: ${_cacheDuration.inHours}h', 'OverpassService');
  }

  /// Récupère les arrêts ET les routes de transport
  Future<Map<String, dynamic>> getTransportData({
    required LatLng center,
    required double radiusMeters,
    TransportType type = TransportType.all,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${center.latitude},${center.longitude},$radiusMeters,$type';
    
    Logger.debug('Début getTransportData', 'OverpassService');
    Logger.debug('Position: ${center.latitude}, ${center.longitude}', 'OverpassService');
    Logger.debug('Rayon: ${radiusMeters}m', 'OverpassService');
    Logger.debug('Type: $type', 'OverpassService');
    Logger.debug('Force refresh: $forceRefresh', 'OverpassService');
    Logger.debug('Cache key: $cacheKey', 'OverpassService');

    if (!forceRefresh && _isCacheValid(cacheKey)) {
      final cachedStops = _stopCache[cacheKey] ?? [];
      final cachedRoutes = _routeCache[cacheKey] ?? [];
      Logger.info('Données récupérées depuis le cache', 'OverpassService');
      Logger.debug('Arrêts en cache: ${cachedStops.length}', 'OverpassService');
      Logger.debug('Routes en cache: ${cachedRoutes.length}', 'OverpassService');
      return {
        'stops': cachedStops,
        'routes': cachedRoutes,
      };
    }

    // Réduire le rayon pour éviter les requêtes trop lourdes
    final adjustedRadius = radiusMeters > 2000 ? 2000.0 : radiusMeters;
    if (adjustedRadius != radiusMeters) {
      Logger.info('Rayon réduit pour éviter timeout: ${radiusMeters}m -> ${adjustedRadius}m', 'OverpassService');
    }

    final query = _buildOptimizedOverpassQuery(
      lat: center.latitude,
      lon: center.longitude,
      radius: adjustedRadius,
      type: type,
    );

    Logger.debug('Requête Overpass générée', 'OverpassService');
    Logger.debug('Taille requête: ${query.length} caractères', 'OverpassService');

    try {
      final url = Uri.parse(EnvConfig.overpassApiUrl);
      Logger.api('POST', url.toString(), {'query_length': query.length});
      
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'GbakaMap/1.0 Flutter App',
        },
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(Duration(seconds: 15)); // Timeout plus court pour éviter les blocages

      Logger.apiResponse(url.toString(), {
        'statusCode': response.statusCode,
        'contentLength': response.body.length,
        'contentType': response.headers['content-type'],
      }, response.statusCode);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Logger.debug('JSON reçu: ${data.toString()}', 'OverpassService');
        
        final result = _parseOverpassResponseWithRoutes(data);
        final stops = result['stops'] as List<TransportStop>;
        final routes = result['routes'] as List<TransportRoute>;

        _stopCache[cacheKey] = stops;
        _routeCache[cacheKey] = routes;
        _cacheExpiry[cacheKey] = DateTime.now().add(_cacheDuration);

        Logger.info('Données Overpass récupérées avec succès', 'OverpassService');
        Logger.info('Arrêts trouvés: ${stops.length}', 'OverpassService');
        Logger.info('Routes trouvées: ${routes.length}', 'OverpassService');
        Logger.cache('SET', cacheKey, {
          'stops_count': stops.length,
          'routes_count': routes.length,
          'expiry': _cacheExpiry[cacheKey]!.toIso8601String(),
        });

        return result;
      } else if (response.statusCode == 504) {
        Logger.error('Timeout serveur Overpass (504)', 'OverpassService', response.body);
        // Retourner des données vides plutôt que de planter
        return {
          'stops': <TransportStop>[],
          'routes': <TransportRoute>[],
        };
      } else if (response.statusCode == 429) {
        Logger.error('Rate limit Overpass (429)', 'OverpassService', response.body);
        // Retourner des données vides plutôt que de planter
        return {
          'stops': <TransportStop>[],
          'routes': <TransportRoute>[],
        };
      } else {
        Logger.error('Erreur Overpass: ${response.statusCode}', 'OverpassService', response.body);
        throw Exception('Erreur Overpass: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      Logger.error('Exception getTransportData', 'OverpassService', e);
      Logger.debug('Stack trace: $stackTrace', 'OverpassService');
      
      if (_stopCache.containsKey(cacheKey)) {
        Logger.info('Tentative de récupération depuis le cache après erreur', 'OverpassService');
        return {
          'stops': _stopCache[cacheKey] ?? [],
          'routes': _routeCache[cacheKey] ?? [],
        };
      }
      Logger.error('Aucun cache disponible, retour données vides', 'OverpassService');
      // Retourner des données vides plutôt que de planter
      return {
        'stops': <TransportStop>[],
        'routes': <TransportRoute>[],
      };
    }
  }

  /// Requête Overpass optimisée pour éviter les timeouts
  String _buildOptimizedOverpassQuery({
    required double lat,
    required double lon,
    required double radius,
    required TransportType type,
  }) {
    // Simplifier la requête pour éviter les timeouts
    return '''
[out:json][timeout:30];
(
  node(around:$radius,$lat,$lon)["highway"="bus_stop"];
  node(around:$radius,$lat,$lon)["public_transport"="platform"];
  node(around:$radius,$lat,$lon)["amenity"="taxi"];
  node(around:$radius,$lat,$lon)["minibus"="yes"];
  node(around:$radius,$lat,$lon)["gbaka"="yes"];
  node(around:$radius,$lat,$lon)["woro_woro"="yes"];
  node(around:$radius,$lat,$lon)["motorcycle_taxi"="yes"];
);
out body;
>;
out skel qt;
''';
  }

  /// Parse la réponse incluant routes et arrêts
  Map<String, dynamic> _parseOverpassResponseWithRoutes(Map<String, dynamic> data) {
    Logger.debug('Début parsing réponse Overpass', 'OverpassService');
    
    final elements = data['elements'] as List? ?? [];
    Logger.debug('Éléments à parser: ${elements.length}', 'OverpassService');
    
    final stops = <TransportStop>[];
    final routes = <TransportRoute>[];
    final ways = <String, List<LatLng>>{};
    final routeMembers = <String, List<String>>{};
    
    int nodeCount = 0, wayCount = 0, relationCount = 0;
    
    // Premier passage: collecter ways et relations
    for (final element in elements) {
      if (element['type'] == 'way' && element['nodes'] != null) {
        ways[element['id'].toString()] = [];
        wayCount++;
      } else if (element['type'] == 'relation') {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        if (tags['type'] == 'route') {
          final route = TransportRoute.fromJson(element);
          routes.add(route);
          relationCount++;
          
          // Stocker les membres
          final members = element['members'] as List? ?? [];
          routeMembers[route.id] = members
              .where((m) => m['type'] == 'way')
              .map((m) => m['ref'].toString())
              .toList();
          
          Logger.debug('Route trouvée: ${route.name} (${route.id})', 'OverpassService');
          Logger.debug('Membres de la route: ${routeMembers[route.id]?.length ?? 0}', 'OverpassService');
        }
      } else if (element['type'] == 'node' && element['lat'] != null) {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        if (tags['highway'] == 'bus_stop' || 
            tags['public_transport'] != null ||
            tags['amenity'] == 'taxi') {
          try {
            stops.add(TransportStop.fromJson(element));
            nodeCount++;
          } catch (e) {
            Logger.warning('Erreur parsing arrêt: $e', 'OverpassService');
            continue;
          }
        }
      }
    }
    
    Logger.debug('Comptage initial - Nodes: $nodeCount, Ways: $wayCount, Relations: $relationCount', 'OverpassService');
    Logger.debug('Arrêts extraits: ${stops.length}', 'OverpassService');
    Logger.debug('Routes extraites: ${routes.length}', 'OverpassService');
    
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
      
      Logger.debug('Géométrie route ${route.name}: ${geometry.length} points', 'OverpassService');
    }

    final result = {
      'stops': _removeDuplicatesByProximity(stops),
      'routes': routes,
    };
    
    final finalStops = result['stops'] as List<TransportStop>;
    Logger.info('Parsing terminé - Arrêts finaux: ${finalStops.length}, Routes: ${routes.length}', 'OverpassService');
    
    return result;
  }

  /// Supprime les doublons par proximité
  List<TransportStop> _removeDuplicatesByProximity(List<TransportStop> stops) {
    if (stops.isEmpty) return stops;

    Logger.debug('Suppression doublons - ${stops.length} arrêts initiaux', 'OverpassService');
    
    final filtered = <TransportStop>[];
    const Distance distance = Distance();
    int duplicatesRemoved = 0;

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
          duplicatesRemoved++;
          Logger.debug('Doublon détecté: ${stop.name} (${dist.toStringAsFixed(1)}m)', 'OverpassService');
          break;
        }
      }

      if (!isDuplicate) {
        filtered.add(stop);
      }
    }

    Logger.info('Doublons supprimés: $duplicatesRemoved, restants: ${filtered.length}', 'OverpassService');
    return filtered;
  }

  bool _isCacheValid(String key) {
    if (!_cacheExpiry.containsKey(key)) {
      Logger.debug('Cache non trouvé pour clé: $key', 'OverpassService');
      return false;
    }
    final isValid = DateTime.now().isBefore(_cacheExpiry[key]!);
    final timeUntilExpiry = _cacheExpiry[key]!.difference(DateTime.now());
    Logger.debug('Cache $key: valide=$isValid, expire dans ${timeUntilExpiry.inMinutes}min', 'OverpassService');
    return isValid;
  }

  void clearCache() {
    final stopCount = _stopCache.length;
    final routeCount = _routeCache.length;
    _stopCache.clear();
    _routeCache.clear();
    _cacheExpiry.clear();
    Logger.info('Cache vidé - $stopCount arrêts, $routeCount routes supprimés', 'OverpassService');
  }

  void dispose() {
    Logger.info('OverpassService disposé', 'OverpassService');
    _client.close();
    clearCache();
  }
}